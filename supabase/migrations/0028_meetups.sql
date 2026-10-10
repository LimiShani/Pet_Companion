-- PetLoop: walk and play partners (Community > Outside > Partners). Apply
-- after 0027. Design and owner steps: docs/meetups.md.
--
--   * community_meetups: an ad ("looking for a walk partner in the
--     morning"): its author, an optional pet (the public facts are copied
--     from the author's pet when the ad is saved: name, kind, breed, birth
--     date, size from the weight, icon; members cannot read pets rows),
--     walk or play, a dog park or a city with a short public place text
--     (never an address), one-off (from / to) or recurring (weekdays and a
--     part of the day), the sizes it suits, a note of up to 200 characters.
--     Written only by the functions below, which hold the rules:
--       - 3 new ads a day per account, at most 5 open at once;
--       - a one-off ad ends with its time; a recurring ad is up for 30 days
--         and can be renewed for 30 more;
--       - ads that ended more than 90 days ago are deleted.
--   * community_meetup_answers: who answered an ad ("I want to join"); the
--     author reads them (to open one group for everyone), each member their
--     own. The ad keeps the count.
--   * community_meetup_reports: reports, with the community rule: three
--     since the last moderator decision hide the ad until a moderator keeps
--     or removes it; the moderators' queue (0021) shows ads too.
--   * Members never see ads of someone they blocked, nor ones they
--     reported. Nobody answers across a block.
--   * Push (0023/0026 pipeline): 'meetup' tells members who saved the park
--     and switched on "Tell me about new meetups here"
--     (dog_park_favorites.notify_meetups) about a new ad there (three a day
--     at most); 'meetup_renew' tells an author their recurring ad has
--     ended. The answer itself reaches the author as the private-chat
--     message push. push_claim() also runs the meetups housekeeping.
--   * Capabilities community.meetups.view and community.meetups.post, for
--     everyone (Standard owners).
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.dog_park_favorites') is null or to_regclass('public.chat_channel_members') is null then
    raise exception 'Run 0026_private_chats.sql and 0027_dog_parks.sql first.';
  end if;
end
$$;

create schema if not exists community_private;

-- ---------------------------------------------------------------------------
-- Capabilities, allowed for everyone by default.
-- ---------------------------------------------------------------------------
-- Clients refresh their permissions when the revision moves (first run only).
update public.access_revision set revision=revision+1
where singleton and not exists (select 1 from public.access_capabilities where id='community.meetups.view');
insert into public.access_capabilities(id,feature_id) values ('community.meetups.view','community')
on conflict(id) do nothing;
insert into public.access_capabilities(id,feature_id,requires_view)
values ('community.meetups.post','community','community.meetups.view')
on conflict(id) do nothing;
insert into public.group_capability_rules(group_id,capability,allowed)
select g.id, c.capability, true
from public.access_groups g
cross join (values ('community.meetups.view'),('community.meetups.post')) as c(capability)
where g.id='acc35500-0000-4000-8000-000000000001'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Tables.
-- ---------------------------------------------------------------------------
create table if not exists public.community_meetups (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('walk','play')),
  -- The pet, as it was when the ad was saved (null: "no pet").
  pet_id uuid references public.pets(id) on delete set null,
  pet_name text check (char_length(pet_name) between 1 and 60),
  pet_species text check (pet_species in ('dog','cat','bird','rabbit','reptile','other')),
  pet_breed text check (char_length(pet_breed) <= 60),
  pet_born_on date,
  pet_born_approx boolean not null default false,
  pet_size text check (pet_size in ('small','medium','large')),
  pet_icon text check (char_length(pet_icon) <= 60),
  -- Which animal chips show it: the pet's kind, 'all' without a pet.
  audience text not null default 'all' check (audience in ('all','dog','cat','other')),
  -- A park, or a city and a public place ("the bridge in Yarkon Park").
  park_id uuid references public.dog_parks(id) on delete cascade,
  locality_code text not null check (locality_code ~ '^[a-z0-9-]{2,60}$'),
  place_text text check (char_length(place_text) <= 80),
  -- One-off: starts_at and ends_at. Recurring: weekdays (ISO, 1 = Monday)
  -- and the part of the day.
  starts_at timestamptz,
  ends_at timestamptz,
  weekdays smallint[],
  day_part text check (day_part in ('morning','noon','evening')),
  -- The sizes of dog it suits; empty: every size.
  suits text[] not null default '{}' check (suits <@ array['small','medium','large']::text[]),
  note text not null default '' check (char_length(note) <= 200),
  status text not null default 'open' check (status in ('open','closed')),
  answer_count integer not null default 0,
  expires_at timestamptz not null,
  renew_notified_at timestamptz,
  hidden_at timestamptz,
  moderated_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (starts_at is not null and ends_at is not null and ends_at > starts_at and weekdays is null and day_part is null)
    or (starts_at is null and ends_at is null and weekdays is not null and day_part is not null
        and cardinality(weekdays) between 1 and 7 and weekdays <@ array[1,2,3,4,5,6,7]::smallint[])
  ),
  check (park_id is not null or coalesce(char_length(btrim(place_text)), 0) > 0)
);
create index if not exists community_meetups_open_idx on public.community_meetups (locality_code, expires_at) where status = 'open';
create index if not exists community_meetups_park_idx on public.community_meetups (park_id) where park_id is not null;
create index if not exists community_meetups_author_idx on public.community_meetups (author_id, created_at);
create index if not exists community_meetups_expiry_idx on public.community_meetups (expires_at);

create table if not exists public.community_meetup_answers (
  meetup_id uuid not null references public.community_meetups(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (meetup_id, user_id)
);
create index if not exists community_meetup_answers_user_idx on public.community_meetup_answers (user_id);

create table if not exists public.community_meetup_reports (
  meetup_id uuid not null references public.community_meetups(id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reason text not null check (reason in ('spam','abusive','inappropriate','other')),
  created_at timestamptz not null default now(),
  primary key (meetup_id, reporter_id)
);
create index if not exists community_meetup_reports_reporter_idx on public.community_meetup_reports (reporter_id);

-- ---------------------------------------------------------------------------
-- Row level security. Ads and answers are read only; every change goes
-- through the functions below. Reports are written by their reporter.
-- ---------------------------------------------------------------------------
alter table public.community_meetups enable row level security;
alter table public.community_meetup_answers enable row level security;
alter table public.community_meetup_reports enable row level security;

revoke all on public.community_meetups, public.community_meetup_answers, public.community_meetup_reports from anon, authenticated;
grant select on public.community_meetups, public.community_meetup_answers to authenticated;
grant select, insert on public.community_meetup_reports to authenticated;
grant all on public.community_meetups, public.community_meetup_answers, public.community_meetup_reports to service_role;

-- Open ads for everyone; one's own ads always; moderators also see hidden
-- ones.
drop policy if exists "community_meetups: members read open ads" on public.community_meetups;
create policy "community_meetups: members read open ads" on public.community_meetups
  for select to authenticated using (
    author_id = (select auth.uid())
    or (status = 'open' and expires_at > now() and hidden_at is null)
    or (select public.can_use('community.moderate'))
  );
-- Never someone the reader blocked, never what they reported (their own
-- ads always).
drop policy if exists community_safety_read on public.community_meetups;
create policy community_safety_read on public.community_meetups as restrictive for select to authenticated using (
  author_id = (select auth.uid())
  or (
    not exists (select 1 from public.user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = community_meetups.author_id)
    and not exists (select 1 from public.community_meetup_reports r where r.meetup_id = community_meetups.id and r.reporter_id = (select auth.uid()))
  )
);

-- An answer: the one who answered, and the ad's author.
drop policy if exists "community_meetup_answers: responder and author read" on public.community_meetup_answers;
create policy "community_meetup_answers: responder and author read" on public.community_meetup_answers
  for select to authenticated using (
    user_id = (select auth.uid())
    or exists (select 1 from public.community_meetups m where m.id = meetup_id and m.author_id = (select auth.uid()))
  );

drop policy if exists "community_meetup_reports: reporter can read" on public.community_meetup_reports;
create policy "community_meetup_reports: reporter can read" on public.community_meetup_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
drop policy if exists "community_meetup_reports: report as yourself" on public.community_meetup_reports;
create policy "community_meetup_reports: report as yourself" on public.community_meetup_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

-- Feature permissions, restrictive, as 0014 adds them to every table.
do $$ declare row record; begin
 for row in select * from (values
  ('community_meetups','(select public.can_use(''community.meetups.view''))','false'),
  ('community_meetup_answers','(select public.can_use(''community.meetups.view''))','false'),
  ('community_meetup_reports','(select public.can_use(''community.meetups.view''))','(select public.can_use(''community.meetups.view''))')
 ) as rules(tbl,read_rule,write_rule) loop
  execute format('drop policy if exists feature_read on public.%I',row.tbl);
  execute format('drop policy if exists feature_insert on public.%I',row.tbl);
  execute format('drop policy if exists feature_update on public.%I',row.tbl);
  execute format('drop policy if exists feature_delete on public.%I',row.tbl);
  execute format('create policy feature_read on public.%I as restrictive for select to authenticated using(%s)',row.tbl,row.read_rule);
  execute format('create policy feature_insert on public.%I as restrictive for insert to authenticated with check(%s)',row.tbl,row.write_rule);
  execute format('create policy feature_update on public.%I as restrictive for update to authenticated using(%s) with check(%s)',row.tbl,row.write_rule,row.write_rule);
  execute format('create policy feature_delete on public.%I as restrictive for delete to authenticated using(%s)',row.tbl,row.write_rule);
 end loop;
end $$;

-- ---------------------------------------------------------------------------
-- What the app reads: the ad, its author's name, its park (when the reader
-- may see the park) and whether the reader answered. Runs with the
-- reader's rights, so every rule above applies.
-- ---------------------------------------------------------------------------
create or replace view public.community_meetup_board
with (security_invoker = true) as
select
  m.id, m.author_id, coalesce(pr.display_name, '') as author_name, m.kind,
  case when m.author_id = (select auth.uid()) then m.pet_id end as pet_id,
  m.pet_name, m.pet_species, m.pet_breed, m.pet_born_on, m.pet_born_approx, m.pet_size, m.pet_icon,
  m.audience, m.park_id, m.locality_code, m.place_text,
  m.starts_at, m.ends_at, m.weekdays, m.day_part, m.suits, m.note,
  m.status, m.answer_count, m.expires_at, m.hidden_at is not null as hidden,
  m.created_at, m.updated_at,
  exists (select 1 from public.community_meetup_answers a
          where a.meetup_id = m.id and a.user_id = (select auth.uid())) as answered,
  p.source as park_source, p.name_he as park_name_he, p.name_en as park_name_en,
  p.street_he as park_street_he, p.street_en as park_street_en,
  p.lat as park_lat, p.lng as park_lng, p.locality_code as park_locality_code,
  p.fenced as park_fenced, p.water as park_water, p.shade as park_shade,
  p.lighting as park_lighting, p.small_dogs as park_small_dogs, p.benches as park_benches,
  p.status as park_status
from public.community_meetups m
left join public.profiles pr on pr.id = m.author_id
left join public.dog_parks p on p.id = m.park_id;
revoke all on public.community_meetup_board from anon;
grant select on public.community_meetup_board to authenticated;

-- ---------------------------------------------------------------------------
-- Housekeeping: ads that ended more than 90 days ago are deleted, and an
-- author hears once that their recurring ad has ended (when they have a
-- phone for it). Run by push_claim() (every run of community-push) and on
-- every new ad, so nothing needs a schedule of its own.
-- ---------------------------------------------------------------------------
create or replace function community_private.meetups_housekeeping()
returns void language plpgsql security definer set search_path='' as $$
begin
  with due as (
    update public.community_meetups m
    set renew_notified_at = now()
    where m.weekdays is not null and m.status = 'open' and m.hidden_at is null
      and m.renew_notified_at is null
      and m.expires_at <= now() and m.expires_at > now() - interval '7 days'
    returning m.id, m.author_id, m.note
  )
  insert into public.push_outbox(recipient_id, kind, actor_id, target, preview)
  select d.author_id, 'meetup_renew', d.author_id, 'meetup:' || d.id, left(d.note, 140)
  from due d
  where exists (select 1 from public.push_devices x where x.user_id = d.author_id)
    and access_private.evaluate(d.author_id, 'community.meetups.post');

  delete from public.community_meetups
  where expires_at < now() - interval '90 days'
     or (status = 'closed' and closed_at < now() - interval '90 days');
end $$;
revoke all on function community_private.meetups_housekeeping() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Writing an ad.
-- ---------------------------------------------------------------------------
create or replace function community_private.require_meetups(p_capability text)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, p_capability) then
    raise exception 'Meetups access required' using errcode = '42501';
  end if;
  return me;
end $$;
revoke all on function community_private.require_meetups(text) from public, anon, authenticated;

-- Creates (p_id null) or edits the signed-in member's ad. p:
--   {"kind": "walk"|"play", "pet_id": uuid|null,
--    "park_id": uuid|null, "locality_code": "raanana", "place_text": "...",
--    "starts_at": iso, "ends_at": iso          (one-off), or
--    "weekdays": [1..7], "day_part": "morning" (recurring),
--    "suits": ["small", ...], "note": "..."}
-- Refusals: invalid_meetup (22023), rate_limited / too_many_open /
-- not_open (P0001).
create or replace function public.meetup_save(p_id uuid, p jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  me uuid := community_private.require_meetups('community.meetups.post');
  old public.community_meetups;
  pet public.pets;
  park public.dog_parks;
  v_kind text := p->>'kind';
  v_pet uuid := nullif(p->>'pet_id', '')::uuid;
  v_park uuid := nullif(p->>'park_id', '')::uuid;
  v_locality text := nullif(btrim(coalesce(p->>'locality_code', '')), '');
  v_place text := nullif(btrim(coalesce(p->>'place_text', '')), '');
  v_starts timestamptz := nullif(p->>'starts_at', '')::timestamptz;
  v_ends timestamptz := nullif(p->>'ends_at', '')::timestamptz;
  v_days smallint[];
  v_part text := nullif(p->>'day_part', '');
  v_suits text[];
  v_note text := btrim(coalesce(p->>'note', ''));
  v_size text;
  v_expires timestamptz;
  recent integer;
  open_count integer;
  new_id uuid;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'invalid_meetup' using errcode = '22023';
  end if;
  if p_id is not null then
    select * into old from public.community_meetups where id = p_id and author_id = me for update;
    if not found then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'not your ad';
    end if;
    if old.status <> 'open' or old.expires_at <= now() then
      raise exception 'not_open' using errcode = 'P0001';
    end if;
  end if;

  if v_kind is null or v_kind not in ('walk','play') then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'kind';
  end if;

  -- The pet: one of the author's own, not archived.
  if v_pet is not null then
    select * into pet from public.pets where id = v_pet and owner_id = me and archived_at is null;
    if not found then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'unknown pet';
    end if;
    if pet.species = 'dog' and pet.weight_kg is not null then
      v_size := case when pet.weight_kg < 10 then 'small' when pet.weight_kg < 25 then 'medium' else 'large' end;
    end if;
  end if;

  -- The place: a park members can see, or a city and a public place.
  if v_park is not null then
    select * into park from public.dog_parks where id = v_park and status = 'active';
    if not found then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'unknown park';
    end if;
    v_locality := coalesce(park.locality_code, v_locality);
    v_place := null;
  elsif v_place is null or char_length(v_place) > 80 then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'place';
  end if;
  if v_locality is null or v_locality !~ '^[a-z0-9-]{2,60}$' then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'locality';
  end if;

  -- When.
  if p ? 'weekdays' and jsonb_typeof(p->'weekdays') = 'array' then
    select array_agg(distinct d::smallint order by d::smallint) into v_days
    from jsonb_array_elements_text(p->'weekdays') d;
  end if;
  if v_starts is not null or v_ends is not null then
    if v_starts is null or v_ends is null or v_days is not null or v_part is not null
       or v_ends <= v_starts or v_ends - v_starts > interval '12 hours'
       or v_ends <= now() or v_starts > now() + interval '60 days' then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'time';
    end if;
    v_expires := v_ends;
  else
    if v_days is null or cardinality(v_days) = 0 or not v_days <@ array[1,2,3,4,5,6,7]::smallint[]
       or v_part is null or v_part not in ('morning','noon','evening') then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'days';
    end if;
    -- A recurring ad keeps its 30 days when it is edited.
    v_expires := case when p_id is not null and old.weekdays is not null then old.expires_at
                      else now() + interval '30 days' end;
  end if;

  if p ? 'suits' and jsonb_typeof(p->'suits') = 'array' then
    select coalesce(array_agg(distinct s order by s), '{}') into v_suits
    from jsonb_array_elements_text(p->'suits') s;
  else
    v_suits := '{}';
  end if;
  if not v_suits <@ array['small','medium','large']::text[] then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'suits';
  end if;
  if cardinality(v_suits) = 3 then v_suits := '{}'; end if;
  if char_length(v_note) > 200 then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'note';
  end if;

  if p_id is null then
    perform community_private.meetups_housekeeping();
    select count(*) into recent from public.community_meetups
     where author_id = me and created_at > now() - interval '1 day';
    if recent >= 3 then
      raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
    end if;
    select count(*) into open_count from public.community_meetups
     where author_id = me and status = 'open' and expires_at > now();
    if open_count >= 5 then
      raise exception 'too_many_open' using errcode = 'P0001';
    end if;
    insert into public.community_meetups(
      author_id, kind, pet_id, pet_name, pet_species, pet_breed, pet_born_on, pet_born_approx,
      pet_size, pet_icon, audience, park_id, locality_code, place_text, starts_at, ends_at,
      weekdays, day_part, suits, note, expires_at)
    values (
      me, v_kind, pet.id, pet.name, pet.species, left(nullif(btrim(pet.breed), ''), 60), pet.birth_date,
      coalesce(pet.birth_date_approx, false), v_size, pet.icon_key,
      case when pet.id is null then 'all' when pet.species in ('dog','cat') then pet.species else 'other' end,
      v_park, v_locality, v_place, v_starts, v_ends, v_days, v_part, v_suits, v_note, v_expires)
    returning id into new_id;
    return new_id;
  end if;

  update public.community_meetups set
    kind = v_kind, pet_id = pet.id, pet_name = pet.name, pet_species = pet.species,
    pet_breed = left(nullif(btrim(pet.breed), ''), 60), pet_born_on = pet.birth_date,
    pet_born_approx = coalesce(pet.birth_date_approx, false), pet_size = v_size, pet_icon = pet.icon_key,
    audience = case when pet.id is null then 'all' when pet.species in ('dog','cat') then pet.species else 'other' end,
    park_id = v_park, locality_code = v_locality, place_text = v_place,
    starts_at = v_starts, ends_at = v_ends, weekdays = v_days, day_part = v_part,
    suits = v_suits, note = v_note, expires_at = v_expires, updated_at = now()
  where id = p_id;
  return p_id;
end $$;
revoke all on function public.meetup_save(uuid, jsonb) from public, anon;
grant execute on function public.meetup_save(uuid, jsonb) to authenticated;

-- "Found someone, close it".
create or replace function public.meetup_close(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid := community_private.require_meetups('community.meetups.view');
begin
  update public.community_meetups set status = 'closed', closed_at = now(), updated_at = now()
  where id = p_id and author_id = me and status = 'open';
  if not found and not exists (select 1 from public.community_meetups where id = p_id and author_id = me) then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'not your ad';
  end if;
end $$;
revoke all on function public.meetup_close(uuid) from public, anon;
grant execute on function public.meetup_close(uuid) to authenticated;

-- Another 30 days for a recurring ad (open, ended or closed). Counts
-- against the five open ads when it was not open.
create or replace function public.meetup_renew(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare
  me uuid := community_private.require_meetups('community.meetups.post');
  ad public.community_meetups;
  open_count integer;
begin
  select * into ad from public.community_meetups where id = p_id and author_id = me for update;
  if not found or ad.weekdays is null or ad.hidden_at is not null then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'only your recurring ads';
  end if;
  if not (ad.status = 'open' and ad.expires_at > now()) then
    select count(*) into open_count from public.community_meetups
     where author_id = me and status = 'open' and expires_at > now();
    if open_count >= 5 then
      raise exception 'too_many_open' using errcode = 'P0001';
    end if;
  end if;
  update public.community_meetups
  set status = 'open', closed_at = null, expires_at = now() + interval '30 days',
      renew_notified_at = null, updated_at = now()
  where id = p_id;
end $$;
revoke all on function public.meetup_renew(uuid) from public, anon;
grant execute on function public.meetup_renew(uuid) to authenticated;

-- "I want to join": records that the signed-in member answered an open ad
-- of someone else, with no block either way. Answers the ad's count.
create or replace function public.meetup_answer(p_id uuid)
returns integer language plpgsql security definer set search_path='' as $$
declare
  me uuid := community_private.require_meetups('community.meetups.view');
  ad public.community_meetups;
begin
  select * into ad from public.community_meetups where id = p_id;
  if not found or ad.status <> 'open' or ad.expires_at <= now() or ad.hidden_at is not null then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if ad.author_id = me then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'your own ad';
  end if;
  if exists (select 1 from public.user_blocks b
             where (b.blocker_id = me and b.blocked_id = ad.author_id)
                or (b.blocker_id = ad.author_id and b.blocked_id = me)) then
    raise exception 'blocked' using errcode = 'P0001';
  end if;
  insert into public.community_meetup_answers(meetup_id, user_id) values (p_id, me)
  on conflict do nothing;
  return (select answer_count from public.community_meetups where id = p_id);
end $$;
revoke all on function public.meetup_answer(uuid) from public, anon;
grant execute on function public.meetup_answer(uuid) to authenticated;

-- Who answered the signed-in member's ad (newest first), without anyone
-- blocked either way: the people of "Group for everyone who answered".
create or replace function public.meetup_responders(p_id uuid)
returns table(user_id uuid, display_name text, answered_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare me uuid := community_private.require_meetups('community.meetups.view');
begin
  if not exists (select 1 from public.community_meetups m where m.id = p_id and m.author_id = me) then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'not your ad';
  end if;
  return query
  select a.user_id, coalesce(pr.display_name, ''), a.created_at
  from public.community_meetup_answers a
  left join public.profiles pr on pr.id = a.user_id
  where a.meetup_id = p_id
    and not exists (select 1 from public.user_blocks b
                    where (b.blocker_id = me and b.blocked_id = a.user_id)
                       or (b.blocker_id = a.user_id and b.blocked_id = me))
  order by a.created_at desc;
end $$;
revoke all on function public.meetup_responders(uuid) from public, anon;
grant execute on function public.meetup_responders(uuid) to authenticated;

-- The ad keeps how many answered.
create or replace function community_private.count_meetup_answers()
returns trigger language plpgsql security definer set search_path='' as $$
declare target uuid := coalesce(new.meetup_id, old.meetup_id);
begin
  update public.community_meetups
  set answer_count = (select count(*) from public.community_meetup_answers a where a.meetup_id = target)
  where id = target;
  return null;
end $$;
revoke all on function community_private.count_meetup_answers() from public, anon, authenticated;
drop trigger if exists count_meetup_answers on public.community_meetup_answers;
create trigger count_meetup_answers after insert or delete on public.community_meetup_answers
  for each row execute function community_private.count_meetup_answers();

-- ---------------------------------------------------------------------------
-- Reports: three since the last moderator decision hide the ad.
-- ---------------------------------------------------------------------------
create or replace function community_private.hide_reported_meetup()
returns trigger language plpgsql security definer set search_path='' as $$
declare reports integer;
begin
  select count(*) into reports from public.community_meetup_reports r
  join public.community_meetups m on m.id = r.meetup_id
  where r.meetup_id = new.meetup_id and r.created_at > coalesce(m.moderated_at, '-infinity');
  if reports >= 3 then
    update public.community_meetups set hidden_at = coalesce(hidden_at, now()) where id = new.meetup_id;
  end if;
  return null;
end $$;
revoke all on function community_private.hide_reported_meetup() from public, anon, authenticated;
drop trigger if exists hide_when_reported on public.community_meetup_reports;
create trigger hide_when_reported after insert on public.community_meetup_reports
  for each row execute function community_private.hide_reported_meetup();

-- ---------------------------------------------------------------------------
-- Moderation (0021): the queue shows reported ads, and a moderator keeps or
-- removes them.
-- ---------------------------------------------------------------------------
create or replace function community_private.moderation_queue()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform community_private.require_moderator();
  return coalesce((
    select jsonb_agg(q.item order by q.last_report_at desc)
    from (
      select r.last_at as last_report_at, jsonb_build_object(
        'kind', 'post', 'id', p.id, 'author_id', p.author_id,
        'author_name', coalesce(pr.display_name, ''), 'body', p.body,
        'photo_path', p.photo_path, 'created_at', p.created_at,
        'hidden', p.hidden_at is not null, 'context', null,
        'report_count', r.n, 'reasons', r.reasons, 'last_report_at', r.last_at) as item
      from public.community_posts p
      join lateral (
        select count(*)::integer as n, jsonb_agg(distinct x.reason) as reasons, max(x.created_at) as last_at
        from public.community_reports x
        where x.post_id = p.id and x.created_at > coalesce(p.moderated_at, '-infinity')
      ) r on r.n > 0
      left join public.profiles pr on pr.id = p.author_id
      union all
      select r.last_at, jsonb_build_object(
        'kind', 'comment', 'id', c.id, 'author_id', c.author_id,
        'author_name', coalesce(pr.display_name, ''), 'body', c.body,
        'photo_path', null, 'created_at', c.created_at,
        'hidden', c.hidden_at is not null, 'context', c.post_id,
        'report_count', r.n, 'reasons', r.reasons, 'last_report_at', r.last_at)
      from public.community_comments c
      join lateral (
        select count(*)::integer as n, jsonb_agg(distinct x.reason) as reasons, max(x.created_at) as last_at
        from public.community_comment_reports x
        where x.comment_id = c.id and x.created_at > coalesce(c.moderated_at, '-infinity')
      ) r on r.n > 0
      left join public.profiles pr on pr.id = c.author_id
      union all
      select r.last_at, jsonb_build_object(
        'kind', 'message', 'id', m.id, 'author_id', m.author_id,
        'author_name', coalesce(pr.display_name, ''), 'body', m.body,
        'photo_path', m.photo_path, 'created_at', m.created_at,
        'hidden', m.hidden_at is not null, 'context', m.channel_id,
        'report_count', r.n, 'reasons', r.reasons, 'last_report_at', r.last_at)
      from public.chat_messages m
      join lateral (
        select count(*)::integer as n, jsonb_agg(distinct x.reason) as reasons, max(x.created_at) as last_at
        from public.chat_message_reports x
        where x.message_id = m.id and x.created_at > coalesce(m.moderated_at, '-infinity')
      ) r on r.n > 0
      left join public.profiles pr on pr.id = m.author_id
      union all
      -- A partner ad: its note (or its place) as the text, its city as the
      -- context.
      select r.last_at, jsonb_build_object(
        'kind', 'meetup', 'id', a.id, 'author_id', a.author_id,
        'author_name', coalesce(pr.display_name, ''),
        'body', coalesce(nullif(a.note, ''), a.place_text, ''),
        'photo_path', null, 'created_at', a.created_at,
        'hidden', a.hidden_at is not null, 'context', a.locality_code,
        'report_count', r.n, 'reasons', r.reasons, 'last_report_at', r.last_at)
      from public.community_meetups a
      join lateral (
        select count(*)::integer as n, jsonb_agg(distinct x.reason) as reasons, max(x.created_at) as last_at
        from public.community_meetup_reports x
        where x.meetup_id = a.id and x.created_at > coalesce(a.moderated_at, '-infinity')
      ) r on r.n > 0
      left join public.profiles pr on pr.id = a.author_id
    ) q
  ), '[]'::jsonb);
end $$;
revoke all on function community_private.moderation_queue() from public, anon;
grant execute on function community_private.moderation_queue() to authenticated;

create or replace function community_private.moderate(p_kind text, p_id uuid, p_action text)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform community_private.require_moderator();
  if p_action not in ('keep', 'remove') or p_kind not in ('post', 'comment', 'message', 'meetup') then
    raise exception 'Unknown moderation action' using errcode = '22023';
  end if;
  if p_kind = 'post' then
    if p_action = 'keep' then update public.community_posts set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.community_posts where id = p_id; end if;
  elsif p_kind = 'comment' then
    if p_action = 'keep' then update public.community_comments set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.community_comments where id = p_id; end if;
  elsif p_kind = 'meetup' then
    if p_action = 'keep' then update public.community_meetups set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.community_meetups where id = p_id; end if;
  else
    if p_action = 'keep' then update public.chat_messages set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.chat_messages where id = p_id; end if;
  end if;
  insert into community_private.moderation_log(moderator_id, kind, target_id, action)
  values (auth.uid(), p_kind, p_id, p_action);
end $$;
revoke all on function community_private.moderate(text, uuid, text) from public, anon;
grant execute on function community_private.moderate(text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Push: new ads at a saved park, and the renewal reminder.
-- ---------------------------------------------------------------------------
alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('comment', 'like', 'reply', 'message', 'invite', 'meetup', 'meetup_renew'));

-- 0026's enqueue_push, with 'meetup': members with community.meetups.view,
-- on by default (the park's own switch is the choice), three a day at
-- most.
create or replace function community_private.enqueue_push(
  p_recipient uuid, p_kind text, p_actor uuid, p_target text, p_preview text)
returns void language plpgsql security definer set search_path='' as $$
declare wanted boolean; unread integer; waiting bigint; channel text;
begin
  if p_recipient is null or p_actor is null or p_recipient = p_actor then return; end if;
  if exists (select 1 from public.user_blocks b where b.blocker_id = p_recipient and b.blocked_id = p_actor) then
    return;
  end if;
  if not access_private.evaluate(p_recipient, case
       when p_kind = 'reply' then 'community.chat.view'
       when p_kind in ('message', 'invite') then 'community.chat.private'
       when p_kind = 'meetup' then 'community.meetups.view'
       else 'community.feed.view' end) then
    return;
  end if;
  select case p_kind
      when 'reply' then p.replies when 'comment' then p.comments
      when 'message' then p.private_messages when 'invite' then p.chat_invites
      when 'meetup' then true
      else p.likes end
    into wanted from public.push_preferences p where p.user_id = p_recipient;
  if not coalesce(wanted, p_kind <> 'like') then return; end if;
  if not exists (select 1 from public.push_devices d where d.user_id = p_recipient) then return; end if;
  if p_kind = 'like' and exists (
    select 1 from public.push_outbox o
    where o.recipient_id = p_recipient and o.kind = 'like' and o.target = p_target
      and o.created_at > now() - interval '1 hour'
  ) then
    return;
  end if;
  if p_kind = 'meetup' and (
    select count(*) from public.push_outbox o
    where o.recipient_id = p_recipient and o.kind = 'meetup' and o.created_at > now() - interval '1 day'
  ) >= 3 then
    return;
  end if;
  if p_kind = 'message' then
    -- One notification a chat: it says how many messages are unread, and
    -- a waiting one is brought up to date instead of queueing another.
    channel := substr(p_target, 6);
    select count(*) into unread from (
      select 1 from public.chat_messages x
      join public.chat_channel_members m on m.channel_id = x.channel_id and m.user_id = p_recipient
      where x.channel_id = channel and x.author_id <> p_recipient and x.system is null
        and x.created_at >= m.invited_at
        and x.created_at > coalesce((select r.last_read_at from public.chat_reads r
                                     where r.user_id = p_recipient and r.channel_id = channel), '-infinity')
        and not exists (select 1 from public.user_blocks b where b.blocker_id = p_recipient and b.blocked_id = x.author_id)
      limit 99) u;
    select o.id into waiting from public.push_outbox o
    where o.recipient_id = p_recipient and o.kind = 'message' and o.target = p_target
      and o.sent_at is null and o.claimed_at is null
    order by o.id desc limit 1;
    if waiting is not null then
      update public.push_outbox
      set actor_id = p_actor, preview = left(coalesce(p_preview, ''), 140), count = greatest(unread, 1)
      where id = waiting;
      return;
    end if;
    insert into public.push_outbox(recipient_id, kind, actor_id, target, preview, count)
    values (p_recipient, p_kind, p_actor, p_target, left(coalesce(p_preview, ''), 140), greatest(unread, 1));
  else
    insert into public.push_outbox(recipient_id, kind, actor_id, target, preview)
    values (p_recipient, p_kind, p_actor, p_target, left(coalesce(p_preview, ''), 140));
  end if;
  perform community_private.poke_push();
end $$;
revoke all on function community_private.enqueue_push(uuid, text, uuid, text, text) from public, anon, authenticated;

-- A new ad at a park: everyone who saved it and asked to hear about it
-- (not the author; nobody across a block either way).
create or replace function community_private.push_new_meetup()
returns trigger language plpgsql security definer set search_path='' as $$
declare fan record;
begin
  for fan in
    select f.user_id from public.dog_park_favorites f
    where f.park_id = new.park_id and f.notify_meetups and f.user_id <> new.author_id
      and not exists (select 1 from public.user_blocks b
                      where b.blocker_id = new.author_id and b.blocked_id = f.user_id)
  loop
    perform community_private.enqueue_push(fan.user_id, 'meetup', new.author_id, 'meetup:' || new.id, new.note);
  end loop;
  return null;
end $$;
revoke all on function community_private.push_new_meetup() from public, anon, authenticated;
drop trigger if exists push_new_meetup on public.community_meetups;
create trigger push_new_meetup after insert on public.community_meetups
  for each row when (new.park_id is not null) execute function community_private.push_new_meetup();

-- 0026's claim, which first runs the meetups housekeeping (never failing
-- the claim) and also carries what the words of a meetup push need: its
-- kind, its park's names and its place.
create or replace function public.push_claim(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  begin
    perform community_private.meetups_housekeeping();
  exception when others then
    null;
  end;
  with claimed as (
    update public.push_outbox o
    set claimed_at = now(), attempts = o.attempts + 1
    where o.id in (
      select x.id from public.push_outbox x
      where x.sent_at is null and x.attempts < 5
        and (x.claimed_at is null or x.claimed_at < now() - interval '2 minutes')
      order by x.id
      limit greatest(1, least(coalesce(p_limit, 100), 500))
      for update skip locked
    )
    returning o.*
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'kind', c.kind, 'target', c.target, 'preview', c.preview,
    'actor_name', coalesce(pr.display_name, ''),
    'count', c.count,
    'chat_name', coalesce(ch.name, ''),
    'direct', ch.direct_key is not null,
    'meetup_kind', mu.kind,
    'park_name_he', pk.name_he, 'park_name_en', pk.name_en,
    'park_street_he', pk.street_he, 'park_street_en', pk.street_en,
    'place', mu.place_text,
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object('token', d.token, 'platform', d.platform, 'language', d.language))
      from public.push_devices d where d.user_id = c.recipient_id), '[]'::jsonb)
  ) order by c.id), '[]'::jsonb)
  into result
  from claimed c
  left join public.profiles pr on pr.id = c.actor_id
  left join public.chat_channels ch on c.kind in ('message', 'invite') and ch.id = substr(c.target, 6)
  left join public.community_meetups mu on c.kind in ('meetup', 'meetup_renew') and mu.id::text = substr(c.target, 8)
  left join public.dog_parks pk on pk.id = mu.park_id;
  return result;
end $$;
revoke all on function public.push_claim(integer) from public, anon, authenticated;
grant execute on function public.push_claim(integer) to service_role;

commit;
