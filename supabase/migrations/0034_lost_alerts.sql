-- PetLoop: the safety hub and Lost mode. Apply after 0031. Design and owner
-- steps: docs/lost_mode.md and docs/safety.md.
--
--   * Feature 'safety' with three capabilities, for the Beta testers group
--     only (0029) until the owner says a vet has reviewed the lists:
--       - safety.view   the safety tools at all;
--       - safety.lists  "Is it urgent?" and "Can they eat this?" (the
--                       content ships in the app; this only shows it);
--       - safety.lost   Lost mode (starting an alert).
--   * lost_alerts: one row per time a pet went missing. Started by a
--     member of the pet's household with lost_start(), which in one go:
--       - writes a 'lost_found' community post with the pet's public facts
--         (kind, breed, what the lost card says about its looks), when and
--         where it was last seen and the owner's note, through the usual
--         post rules (the post rate limit, reports, blocks); the pet's
--         photo only when the app uploaded one for the post;
--       - keeps the alert (the locality code of the app's list, the place
--         text, the time) and the lost card's draft in step;
--       - tells members in that locality ('lost_nearby' push): people who
--         saved a dog park there, have an open partner ad there, or (once
--         posts carry a locality, 0036) posted there in the last 60 days.
--         One push per member per alert, three a day at most, members can
--         switch it off (push_preferences.lost_nearby, on by default),
--         never across a block, never to the pet's own household.
--     Sightings are comments on the post. lost_found() and lost_cancel()
--     close the alert, its unsent pushes and the post (a closing comment;
--     a cancelled alert nobody answered takes its post with it).
--   * Three alerts a day per account; one open alert per pet.
--   * Members read open alerts of a locality (minimal columns) with
--     lost_alerts_near(); the household reads its own with
--     lost_alerts_mine() (with the number of sightings).
--
-- It works whether or not 0036 (posts locality) has run: the post's
-- locality column is filled when it exists.
--
-- Additive and idempotent: running it again changes nothing. It adds
-- 'lost_nearby' to push_outbox_kind_check; a later file that rewrites that
-- check must keep it (this one reads the current list and adds to it).
begin;

do $$
begin
  if to_regclass('public.community_meetups') is null or to_regclass('public.household_members') is null
     or to_regclass('public.push_outbox') is null then
    raise exception 'Run 0028_meetups.sql and 0030_household.sql first.';
  end if;
end
$$;

create schema if not exists safety_private;
revoke all on schema safety_private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Feature and capabilities: Beta testers only.
-- ---------------------------------------------------------------------------
-- Clients refresh their permissions when the revision moves (first run only).
update public.access_revision set revision = revision + 1
where singleton and not exists (select 1 from public.access_capabilities where id = 'safety.view');
insert into public.feature_catalog(id) values ('safety') on conflict (id) do nothing;
insert into public.access_capabilities(id, feature_id, requires_view) values
  ('safety.view', 'safety', null)
on conflict (id) do nothing;
insert into public.access_capabilities(id, feature_id, requires_view) values
  ('safety.lists', 'safety', 'safety.view'),
  ('safety.lost', 'safety', 'safety.view')
on conflict (id) do nothing;
-- 0029's trigger already gives a new capability to the beta testers; said
-- again so this file does not depend on it.
insert into public.group_capability_rules(group_id, capability, allowed)
select 'acc35500-0000-4000-8000-000000000002', c, true
from unnest(array['safety.view', 'safety.lists', 'safety.lost']) c
where exists (select 1 from public.access_groups g where g.id = 'acc35500-0000-4000-8000-000000000002')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- The table.
-- ---------------------------------------------------------------------------
create table if not exists public.lost_alerts (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  -- The account that started the alert (and wrote the post).
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  -- What members may see without reading the pet: copied at the start.
  pet_name text not null check (char_length(pet_name) between 1 and 60),
  pet_species text not null default 'other',
  locality_code text not null check (locality_code ~ '^[a-z0-9-]{2,60}$'),
  last_seen_at timestamptz not null,
  -- A public place ("the bridge in Yarkon Park"), never an address.
  last_seen_place text not null default '' check (char_length(last_seen_place) <= 120),
  note text not null default '' check (char_length(note) <= 300),
  -- The language of the post's fixed words and closing comment.
  language text not null default 'he' check (language in ('he', 'en')),
  post_id uuid references public.community_posts(id) on delete set null,
  status text not null default 'active' check (status in ('active', 'found', 'cancelled')),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  check ((status = 'active') = (closed_at is null))
);
comment on table public.lost_alerts is
  'Lost mode: a missing pet''s alert. Written only by lost_start / lost_found / lost_cancel (0034).';
create unique index if not exists lost_alerts_one_open_idx on public.lost_alerts (pet_id) where status = 'active';
create index if not exists lost_alerts_locality_idx on public.lost_alerts (locality_code, created_at desc) where status = 'active';
create index if not exists lost_alerts_owner_idx on public.lost_alerts (owner_id, created_at);
create index if not exists lost_alerts_post_idx on public.lost_alerts (post_id);

alter table public.lost_alerts enable row level security;
revoke all on public.lost_alerts from anon, authenticated;
grant select on public.lost_alerts to authenticated;
grant all on public.lost_alerts to service_role;

-- The pet's household reads its alerts; nobody writes them by hand.
drop policy if exists "lost_alerts: household reads" on public.lost_alerts;
create policy "lost_alerts: household reads" on public.lost_alerts
  for select to authenticated
  using ((select public.can_use('safety.view')) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- Push: the new kind and its switch.
-- ---------------------------------------------------------------------------
alter table public.push_preferences add column if not exists lost_nearby boolean not null default true;

-- The current list of kinds plus 'lost_nearby', whatever file wrote it last.
do $$
declare kinds text[];
begin
  select coalesce(array_agg(distinct k order by k), '{}') into kinds
  from (
    select (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as k
    from pg_constraint c
    where c.conrelid = 'public.push_outbox'::regclass and c.conname = 'push_outbox_kind_check'
  ) current_kinds;
  if cardinality(kinds) = 0 then
    raise exception 'push_outbox_kind_check is missing: run 0028_meetups.sql first.';
  end if;
  if not ('lost_nearby' = any(kinds)) then
    kinds := kinds || 'lost_nearby';
    alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
    execute format('alter table public.push_outbox add constraint push_outbox_kind_check check (kind = any (%L::text[]))', kinds);
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Helpers.
-- ---------------------------------------------------------------------------
create or replace function safety_private.require(p_capability text)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, p_capability) then
    raise exception 'Safety access required' using errcode = '42501';
  end if;
  return me;
end $$;
revoke all on function safety_private.require(text) from public, anon, authenticated;

-- Whether [p_user] belongs to the household of [p_pet].
create or replace function safety_private.in_household(p_pet uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pets p
    join public.household_members m on m.household_id = p.household_id
    where p.id = p_pet and m.user_id = p_user
  )
$$;
revoke all on function safety_private.in_household(uuid, uuid) from public, anon, authenticated;

-- The alert as the app reads it, with its sightings (comments on the post
-- by people outside the pet's household that are not hidden).
create or replace function safety_private.alert_json(a public.lost_alerts)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'pet_id', a.pet_id, 'owner_id', a.owner_id, 'pet_name', a.pet_name,
    'pet_species', a.pet_species, 'locality_code', a.locality_code,
    'last_seen_at', a.last_seen_at, 'last_seen_place', a.last_seen_place, 'note', a.note,
    'language', a.language, 'post_id', a.post_id, 'status', a.status,
    'created_at', a.created_at, 'closed_at', a.closed_at,
    'sightings', coalesce((
      select count(*) from public.community_comments c
      where a.post_id is not null and c.post_id = a.post_id and c.hidden_at is null
        and not safety_private.in_household(a.pet_id, c.author_id)), 0))
$$;
revoke all on function safety_private.alert_json(public.lost_alerts) from public, anon, authenticated;

-- The words of the post, in [lang]. No phone number, no address: sightings
-- come as comments.
create or replace function safety_private.post_body(
  p_lang text, p_name text, p_species text, p_breed text, p_looks text,
  p_seen_at timestamptz, p_place text, p_area text, p_note text)
returns text language plpgsql stable set search_path = '' as $$
declare
  he boolean := p_lang = 'he';
  fsi text := chr(8296);
  pdi text := chr(8297);
  kind text;
  facts text;
  seen text;
  lines text[] := '{}';
  place text := concat_ws(', ', nullif(btrim(p_place), ''), nullif(btrim(p_area), ''));
begin
  kind := case p_species
    when 'dog' then case when he then 'כלב' else 'Dog' end
    when 'cat' then case when he then 'חתול' else 'Cat' end
    when 'bird' then case when he then 'ציפור' else 'Bird' end
    when 'rabbit' then case when he then 'ארנב' else 'Rabbit' end
    when 'reptile' then case when he then 'זוחל' else 'Reptile' end
    else null end;
  facts := concat_ws(' · ', kind, nullif(btrim(coalesce(p_breed, '')), ''));
  seen := to_char(p_seen_at at time zone 'Asia/Jerusalem', 'DD.MM HH24:MI');
  if he then
    lines := lines || ('מחפשים את ' || fsi || p_name || pdi);
    if facts <> '' then lines := lines || facts; end if;
    if btrim(coalesce(p_looks, '')) <> '' then lines := lines || btrim(p_looks); end if;
    lines := lines || ('הפעם האחרונה שראינו: ' || seen || case when place <> '' then ' · ' || fsi || place || pdi else '' end);
    if btrim(coalesce(p_note, '')) <> '' then lines := lines || btrim(p_note); end if;
    lines := lines || ('כל מראה של ' || fsi || p_name || pdi || ' עוזר: אפשר לכתוב בתגובה איפה ומתי.');
  else
    lines := lines || (p_name || ' is missing');
    if facts <> '' then lines := lines || facts; end if;
    if btrim(coalesce(p_looks, '')) <> '' then lines := lines || btrim(p_looks); end if;
    lines := lines || ('Last seen ' || seen || case when place <> '' then ' · ' || place else '' end);
    if btrim(coalesce(p_note, '')) <> '' then lines := lines || btrim(p_note); end if;
    lines := lines || ('Seen ' || p_name || '? Please comment with where and when.');
  end if;
  return left(array_to_string(lines, chr(10)), 2000);
end $$;
revoke all on function safety_private.post_body(text, text, text, text, text, timestamptz, text, text, text) from public, anon, authenticated;

-- Who hears about a new alert: members whose area is the locality, as far
-- as the server knows it (a saved park there, an open partner ad there, a
-- recent post there once posts carry a locality).
create or replace function safety_private.members_near(p_locality text)
returns setof uuid language plpgsql stable security definer set search_path = '' as $$
begin
  return query
    select f.user_id from public.dog_park_favorites f
    join public.dog_parks p on p.id = f.park_id
    where p.locality_code = p_locality
    union
    select m.author_id from public.community_meetups m
    where m.locality_code = p_locality and m.status = 'open' and m.expires_at > now();
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'community_posts' and column_name = 'locality_code') then
    return query execute
      'select distinct p.author_id from public.community_posts p
       where p.locality_code = $1 and p.created_at > now() - interval ''60 days'''
      using p_locality;
  end if;
end $$;
revoke all on function safety_private.members_near(text) from public, anon, authenticated;

-- Queues the 'lost_nearby' pushes of [a] (its post must exist). At most
-- 500 members, one push each per alert, three a day each.
create or replace function safety_private.push_alert(a public.lost_alerts)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_target text := 'post:' || a.post_id;
  v_preview text := left(a.pet_name || case when a.last_seen_place <> '' then ' · ' || a.last_seen_place else '' end, 140);
  queued integer;
begin
  if a.post_id is null then return 0; end if;
  insert into public.push_outbox(recipient_id, kind, actor_id, target, preview)
  select r.id, 'lost_nearby', a.owner_id, v_target, v_preview
  from (select distinct n.id from safety_private.members_near(a.locality_code) as n(id)) r
  where r.id <> a.owner_id
    and not safety_private.in_household(a.pet_id, r.id)
    and not exists (select 1 from public.user_blocks b
                    where (b.blocker_id = r.id and b.blocked_id = a.owner_id)
                       or (b.blocker_id = a.owner_id and b.blocked_id = r.id))
    and exists (select 1 from public.push_devices d where d.user_id = r.id)
    and coalesce((select p.lost_nearby from public.push_preferences p where p.user_id = r.id), true)
    and not exists (select 1 from public.push_outbox o
                    where o.recipient_id = r.id and o.kind = 'lost_nearby' and o.target = v_target)
    and (select count(*) from public.push_outbox o
         where o.recipient_id = r.id and o.kind = 'lost_nearby' and o.created_at > now() - interval '1 day') < 3
    and access_private.evaluate(r.id, 'community.feed.view')
  limit 500;
  get diagnostics queued = row_count;
  if queued > 0 then perform community_private.poke_push(); end if;
  return queued;
end $$;
revoke all on function safety_private.push_alert(public.lost_alerts) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Starting an alert.
-- ---------------------------------------------------------------------------
-- p_language: the post's fixed words ('he' or 'en'). p_photo_path: a photo
-- the app uploaded to community-photos for this post (in the caller's
-- folder), or null. p_area_name: the locality's name in that language,
-- for the post's text only.
create or replace function public.lost_start(
  p_pet uuid,
  p_locality text,
  p_place text,
  p_seen_at timestamptz,
  p_note text default '',
  p_language text default 'he',
  p_photo_path text default null,
  p_area_name text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := safety_private.require('safety.lost');
  pet public.pets;
  card public.lost_pet_cards;
  v_locality text := lower(btrim(coalesce(p_locality, '')));
  v_place text := btrim(coalesce(p_place, ''));
  v_note text := btrim(coalesce(p_note, ''));
  v_lang text := coalesce(nullif(btrim(p_language), ''), 'he');
  v_photo text := nullif(btrim(coalesce(p_photo_path, '')), '');
  v_area text := left(btrim(coalesce(p_area_name, '')), 60);
  v_post uuid;
  a public.lost_alerts;
begin
  if not access_private.evaluate(me, 'community.feed.post') then
    raise exception 'Community posting required' using errcode = '42501';
  end if;
  select * into pet from public.pets where id = p_pet;
  if not found or not safety_private.in_household(p_pet, me) then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'pet';
  end if;
  if pet.archived_at is not null then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'pet';
  end if;
  if v_locality !~ '^[a-z0-9-]{2,60}$' then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'locality';
  end if;
  if char_length(v_place) > 120 then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'place';
  end if;
  if char_length(v_note) > 300 then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'note';
  end if;
  if v_lang not in ('he', 'en') then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'language';
  end if;
  if p_seen_at is null or p_seen_at > now() + interval '5 minutes' or p_seen_at < now() - interval '30 days' then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'seen_at';
  end if;
  if v_photo is not null and (v_photo not like (me::text || '/%') or char_length(v_photo) > 300) then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'photo';
  end if;
  if exists (select 1 from public.lost_alerts x where x.pet_id = p_pet and x.status = 'active') then
    raise exception 'lost_active' using errcode = 'P0001', detail = 'An alert for this pet is open';
  end if;
  if (select count(*) from public.lost_alerts x
      where x.owner_id = me and x.created_at > now() - interval '1 day') >= 3 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;

  select * into card from public.lost_pet_cards c where c.pet_id = p_pet;

  -- The post, through the community's own rules (its rate limit trigger).
  insert into public.community_posts(author_id, pet_name, body, photo_path, kind, audience)
  values (
    me, left(pet.name, 60),
    safety_private.post_body(v_lang, pet.name, pet.species, pet.breed, card.description,
      p_seen_at, v_place, v_area, v_note),
    v_photo, 'lost_found',
    case when pet.species in ('dog', 'cat', 'bird', 'rabbit', 'reptile') then pet.species else 'other' end)
  returning id into v_post;
  -- Posts with a locality (0036): this one is in the alert's.
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'community_posts' and column_name = 'locality_code') then
    execute 'update public.community_posts set locality_code = $1 where id = $2' using v_locality, v_post;
  end if;

  insert into public.lost_alerts(pet_id, owner_id, pet_name, pet_species, locality_code,
    last_seen_at, last_seen_place, note, language, post_id)
  values (p_pet, me, left(pet.name, 60), coalesce(pet.species, 'other'), v_locality,
    least(p_seen_at, now()), v_place, v_note, v_lang, v_post)
  returning * into a;

  -- The lost card's draft follows: last seen when and where, not found.
  insert into public.lost_pet_cards(pet_id, owner_id, area, last_seen_at, language, found_at)
  values (p_pet, pet.owner_id, left(v_place, 120), a.last_seen_at, v_lang, null)
  on conflict (pet_id) do update
    set area = case when excluded.area <> '' then excluded.area else public.lost_pet_cards.area end,
        last_seen_at = excluded.last_seen_at, found_at = null;

  perform safety_private.push_alert(a);
  return safety_private.alert_json(a);
end $$;
revoke all on function public.lost_start(uuid, text, text, timestamptz, text, text, text, text) from public, anon;
grant execute on function public.lost_start(uuid, text, text, timestamptz, text, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Closing an alert. Any member of the pet's household may close it, even
-- without the capabilities (an alert never stays open for lack of them).
-- ---------------------------------------------------------------------------
create or replace function safety_private.close_alert(p_alert uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  a public.lost_alerts;
  fsi text := chr(8296);
  pdi text := chr(8297);
  answered boolean;
  words text;
begin
  if me is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  select * into a from public.lost_alerts where id = p_alert for update;
  if not found or not safety_private.in_household(a.pet_id, me) then
    raise exception 'invalid_alert' using errcode = '22023', detail = 'alert';
  end if;
  if a.status <> 'active' then
    -- Closed already (by someone else of the household): nothing to do.
    return safety_private.alert_json(a);
  end if;

  update public.lost_alerts set status = p_status, closed_at = now()
  where id = a.id returning * into a;

  -- Nobody is told about it any more.
  if a.post_id is not null then
    delete from public.push_outbox o
    where o.kind = 'lost_nearby' and o.target = 'post:' || a.post_id and o.sent_at is null;
  end if;

  if p_status = 'found' then
    update public.lost_pet_cards set found_at = now() where pet_id = a.pet_id;
  end if;

  if a.post_id is not null then
    answered := exists (select 1 from public.community_comments c
                        where c.post_id = a.post_id and not safety_private.in_household(a.pet_id, c.author_id));
    if p_status = 'cancelled' and not answered then
      -- Started by mistake and nobody answered: the post goes too.
      delete from public.community_posts where id = a.post_id;
      select * into a from public.lost_alerts where id = p_alert;
    else
      words := case
        when p_status = 'found' and a.language = 'he' then
          'חדשות טובות: ' || fsi || a.pet_name || pdi || ' בבית. תודה לכל מי שעזר לחפש.'
        when p_status = 'found' then
          'Good news: ' || a.pet_name || ' is home. Thank you all for looking.'
        when a.language = 'he' then
          'ההתראה על ' || fsi || a.pet_name || pdi || ' נסגרה.'
        else
          'This alert for ' || a.pet_name || ' was closed.'
      end;
      insert into public.community_comments(post_id, author_id, body) values (a.post_id, me, words);
    end if;
  end if;
  return safety_private.alert_json(a);
end $$;
revoke all on function safety_private.close_alert(uuid, text) from public, anon, authenticated;

create or replace function public.lost_found(p_alert uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select safety_private.close_alert(p_alert, 'found')
$$;
revoke all on function public.lost_found(uuid) from public, anon;
grant execute on function public.lost_found(uuid) to authenticated;

create or replace function public.lost_cancel(p_alert uuid)
returns jsonb language sql security definer set search_path = '' as $$
  select safety_private.close_alert(p_alert, 'cancelled')
$$;
revoke all on function public.lost_cancel(uuid) from public, anon;
grant execute on function public.lost_cancel(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Reading.
-- ---------------------------------------------------------------------------
-- The open alerts of the caller's households, with their sightings.
create or replace function public.lost_alerts_mine()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me uuid := safety_private.require('safety.view');
begin
  return coalesce((
    select jsonb_agg(safety_private.alert_json(a) order by a.created_at desc)
    from public.lost_alerts a
    where a.status = 'active' and safety_private.in_household(a.pet_id, me)), '[]'::jsonb);
end $$;
revoke all on function public.lost_alerts_mine() from public, anon;
grant execute on function public.lost_alerts_mine() to authenticated;

-- The open alerts of a locality, as any member may see them (the post's
-- own reading rules apply: never across a block, never a hidden post).
create or replace function public.lost_alerts_near(p_locality text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, 'community.feed.view') then
    raise exception 'Community access required' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
        'id', n.id, 'pet_name', n.pet_name, 'pet_species', n.pet_species,
        'locality_code', n.locality_code, 'last_seen_at', n.last_seen_at,
        'last_seen_place', n.last_seen_place, 'post_id', n.post_id, 'created_at', n.created_at)
      order by n.created_at desc)
    from (
      select a.* from public.lost_alerts a
      join public.community_posts p on p.id = a.post_id
      where a.status = 'active' and a.locality_code = lower(btrim(coalesce(p_locality, '')))
        and p.hidden_at is null
        and not exists (select 1 from public.user_blocks b
                        where (b.blocker_id = me and b.blocked_id = a.owner_id)
                           or (b.blocker_id = a.owner_id and b.blocked_id = me))
        and not exists (select 1 from public.community_reports r where r.post_id = p.id and r.reporter_id = me)
      order by a.created_at desc
      limit 20) n), '[]'::jsonb);
end $$;
revoke all on function public.lost_alerts_near(text) from public, anon;
grant execute on function public.lost_alerts_near(text) to authenticated;

commit;
