-- PetLoop: the neighbourhood, part 1 (Outside). Apply after 0028 and 0030.
-- Design and owner steps: docs/meetups.md ("Going out now") and
-- docs/hazards.md.
--
--   * Going out now: a partner ad of the kinds 'walk_now' / 'play_now'
--     ("I'm leaving for Yarkon park in 25 min"). It leaves within 90
--     minutes from a park (or a city and a place) and ends by itself at
--     its ends_at, at most 90 minutes after leaving. meetup_save takes
--     "now": true with the kind 'walk' or 'play'. Three a day per account,
--     apart from the planned ads' limits; a new one closes the author's
--     earlier open one. It cannot be edited or renewed. A new one at a
--     park reaches the members who saved the park and asked to hear about
--     it, through the existing 'meetup' push (three a day per member); the
--     claim now also carries the leaving time ('leaves_at') so the push
--     says "Dana is going to Yarkon park in 25 min".
--   * Hazard reports: hazard_reports (a city, an optional park, the kind:
--     caterpillars, bait, glass, inspector, other; a note of up to 140
--     characters; seven days by default) and hazard_votes ("Still there" /
--     "Not there any more"). Two "not there any more" from others hide a
--     report; its author deletes it. Five reports a day per account.
--     Members with community.hazards.view read reports that are neither
--     hidden nor expired (never a blocked member's); every write is a
--     function. Expired reports are deleted 30 days after they expire, by
--     community_private.hazards_housekeeping() (on every new report and
--     from supabase/scheduling/hazards_housekeeping.sql).
--   * Capabilities community.hazards.view and community.hazards.post, for
--     everyone (Standard owners).
--
-- Additive and idempotent: running it again changes nothing. It replaces
-- public.meetup_save (0028, with 0030's household condition) and patches
-- one line of public.push_claim: if 0028 is run again later, run this one
-- again after it (as for 0030).
begin;

do $$
begin
  if to_regclass('public.community_meetups') is null or to_regprocedure('public.health_owns_pet(uuid)') is null then
    raise exception 'Run 0028_meetups.sql and 0030_household.sql first.';
  end if;
end
$$;

create schema if not exists community_private;

-- ---------------------------------------------------------------------------
-- Going out now: two more kinds of ad.
-- ---------------------------------------------------------------------------
alter table public.community_meetups drop constraint if exists community_meetups_kind_check;
alter table public.community_meetups add constraint community_meetups_kind_check
  check (kind in ('walk', 'play', 'walk_now', 'play_now'));
-- A "now" ad is always one-off.
alter table public.community_meetups drop constraint if exists community_meetups_now_one_off;
alter table public.community_meetups add constraint community_meetups_now_one_off
  check (kind not in ('walk_now', 'play_now') or (starts_at is not null and weekdays is null));

-- 0028's meetup_save (with 0030's household condition on the pet) and the
-- "now" ads. p as in 0028, plus "now": true (kind 'walk' or 'play'): then
-- starts_at is the leaving time, from 5 minutes ago to 90 minutes ahead,
-- and ends_at at most 90 minutes after it.
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
  v_now boolean := coalesce((p->>'now')::boolean, false);
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
    -- A "now" ad is closed and posted again, never edited.
    if v_now or old.kind in ('walk_now', 'play_now') then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'a now ad is not edited';
    end if;
  end if;

  if v_kind is null or v_kind not in ('walk','play') then
    raise exception 'invalid_meetup' using errcode = '22023', detail = 'kind';
  end if;

  -- The pet: one of the household's, not archived (0030).
  if v_pet is not null then
    select * into pet from public.pets where id = v_pet and public.health_owns_pet(id) and archived_at is null;
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
  if v_now then
    if v_starts is null or v_ends is null or v_days is not null or v_part is not null
       or v_starts < now() - interval '5 minutes' or v_starts > now() + interval '90 minutes'
       or v_ends <= v_starts or v_ends > v_starts + interval '90 minutes' then
      raise exception 'invalid_meetup' using errcode = '22023', detail = 'time';
    end if;
    v_expires := v_ends;
  elsif v_starts is not null or v_ends is not null then
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
    if v_now then
      -- Three "now" ads a day; the planned ads' limits do not count them.
      select count(*) into recent from public.community_meetups
       where author_id = me and kind in ('walk_now', 'play_now') and created_at > now() - interval '1 day';
      if recent >= 3 then
        raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
      end if;
      -- One at a time: the earlier one is closed.
      update public.community_meetups set status = 'closed', closed_at = now(), updated_at = now()
      where author_id = me and kind in ('walk_now', 'play_now') and status = 'open';
      v_kind := v_kind || '_now';
    else
      select count(*) into recent from public.community_meetups
       where author_id = me and kind in ('walk', 'play') and created_at > now() - interval '1 day';
      if recent >= 3 then
        raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
      end if;
      select count(*) into open_count from public.community_meetups
       where author_id = me and kind in ('walk', 'play') and status = 'open' and expires_at > now();
      if open_count >= 5 then
        raise exception 'too_many_open' using errcode = 'P0001';
      end if;
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

-- The claim of 0028 (or a later one) also carries the leaving time of a
-- "now" ad, for "in 25 min". One line is patched, once.
do $$
declare def text;
begin
  def := pg_get_functiondef('public.push_claim(integer)'::regprocedure);
  if position('''leaves_at''' in def) = 0 and position('''place'', mu.place_text,' in def) > 0 then
    execute replace(def, '''place'', mu.place_text,', '''place'', mu.place_text, ''leaves_at'', mu.starts_at,');
  end if;
end
$$;
revoke all on function public.push_claim(integer) from public, anon, authenticated;
grant execute on function public.push_claim(integer) to service_role;

-- ---------------------------------------------------------------------------
-- Hazard reports: capabilities, for everyone.
-- ---------------------------------------------------------------------------
update public.access_revision set revision = revision + 1
where singleton and not exists (select 1 from public.access_capabilities where id = 'community.hazards.view');
insert into public.access_capabilities(id, feature_id) values ('community.hazards.view', 'community')
on conflict (id) do nothing;
insert into public.access_capabilities(id, feature_id, requires_view)
values ('community.hazards.post', 'community', 'community.hazards.view')
on conflict (id) do nothing;
insert into public.group_capability_rules(group_id, capability, allowed)
select g.id, c.capability, true
from public.access_groups g
cross join (values ('community.hazards.view'), ('community.hazards.post')) as c(capability)
where g.id = 'acc35500-0000-4000-8000-000000000001'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Hazard reports: tables.
-- ---------------------------------------------------------------------------
create table if not exists public.hazard_reports (
  id uuid primary key default gen_random_uuid(),
  locality_code text not null check (locality_code ~ '^[a-z0-9-]{2,60}$'),
  park_id uuid references public.dog_parks(id) on delete set null,
  kind text not null check (kind in ('caterpillars', 'bait', 'glass', 'inspector', 'other')),
  note text not null default '' check (char_length(note) <= 140),
  created_by uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  hidden boolean not null default false
);
create index if not exists hazard_reports_area_idx on public.hazard_reports (locality_code, expires_at) where not hidden;
create index if not exists hazard_reports_park_idx on public.hazard_reports (park_id) where park_id is not null;
create index if not exists hazard_reports_author_idx on public.hazard_reports (created_by, created_at);
create index if not exists hazard_reports_expiry_idx on public.hazard_reports (expires_at);

create table if not exists public.hazard_votes (
  report_id uuid not null references public.hazard_reports(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  gone boolean not null,
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);
create index if not exists hazard_votes_user_idx on public.hazard_votes (user_id);

alter table public.hazard_reports enable row level security;
alter table public.hazard_votes enable row level security;
revoke all on public.hazard_reports, public.hazard_votes from anon, authenticated;
grant select on public.hazard_reports, public.hazard_votes to authenticated;
grant all on public.hazard_reports, public.hazard_votes to service_role;

-- Reports that are neither hidden nor expired; one's own always.
drop policy if exists "hazard_reports: members read current reports" on public.hazard_reports;
create policy "hazard_reports: members read current reports" on public.hazard_reports
  for select to authenticated using (
    created_by = (select auth.uid())
    or (not hidden and expires_at > now())
  );
-- Never a report of someone the reader blocked.
drop policy if exists community_safety_read on public.hazard_reports;
create policy community_safety_read on public.hazard_reports as restrictive for select to authenticated using (
  created_by = (select auth.uid())
  or not exists (select 1 from public.user_blocks b
                 where b.blocker_id = (select auth.uid()) and b.blocked_id = hazard_reports.created_by)
);
-- One's own votes.
drop policy if exists "hazard_votes: voter reads" on public.hazard_votes;
create policy "hazard_votes: voter reads" on public.hazard_votes
  for select to authenticated using (user_id = (select auth.uid()));

-- Feature permissions, restrictive, as 0014 adds them to every table.
do $$ declare t text; begin
 foreach t in array array['hazard_reports', 'hazard_votes'] loop
  execute format('drop policy if exists feature_read on public.%I', t);
  execute format('drop policy if exists feature_insert on public.%I', t);
  execute format('drop policy if exists feature_update on public.%I', t);
  execute format('drop policy if exists feature_delete on public.%I', t);
  execute format('create policy feature_read on public.%I as restrictive for select to authenticated using((select public.can_use(''community.hazards.view'')))', t);
  execute format('create policy feature_insert on public.%I as restrictive for insert to authenticated with check(false)', t);
  execute format('create policy feature_update on public.%I as restrictive for update to authenticated using(false) with check(false)', t);
  execute format('create policy feature_delete on public.%I as restrictive for delete to authenticated using(false)', t);
 end loop;
end $$;

-- What the app reads: a report with its votes, the reader's own vote and
-- its park's names (when the reader may see the park). The reader's
-- rights, so every rule above applies.
create or replace view public.hazard_board
with (security_invoker = true) as
select
  h.id, h.locality_code, h.park_id, h.kind, h.note, h.created_by, h.created_at, h.expires_at, h.hidden,
  h.created_by = (select auth.uid()) as mine,
  (select count(*) from public.hazard_votes v where v.report_id = h.id and not v.gone)::integer as still_count,
  (select count(*) from public.hazard_votes v where v.report_id = h.id and v.gone)::integer as gone_count,
  (select v.gone from public.hazard_votes v where v.report_id = h.id and v.user_id = (select auth.uid())) as my_vote,
  p.name_he as park_name_he, p.name_en as park_name_en,
  p.street_he as park_street_he, p.street_en as park_street_en,
  p.lat as park_lat, p.lng as park_lng
from public.hazard_reports h
left join public.dog_parks p on p.id = h.park_id;
revoke all on public.hazard_board from anon;
grant select on public.hazard_board to authenticated;

-- ---------------------------------------------------------------------------
-- Hazard reports: housekeeping and writes.
-- ---------------------------------------------------------------------------
create or replace function community_private.hazards_housekeeping()
returns void language plpgsql security definer set search_path='' as $$
begin
  delete from public.hazard_reports where expires_at < now() - interval '30 days';
end $$;
revoke all on function community_private.hazards_housekeeping() from public, anon, authenticated;

create or replace function community_private.require_hazards(p_capability text)
returns uuid language plpgsql stable security definer set search_path='' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, p_capability) then
    raise exception 'Hazard reports access required' using errcode = '42501';
  end if;
  return me;
end $$;
revoke all on function community_private.require_hazards(text) from public, anon, authenticated;

-- A new report. p: {"kind": "bait", "park_id": uuid|null,
-- "locality_code": "petah-tikva" (without a park), "note": "..."}.
-- Refusals: invalid_hazard (22023), rate_limited (P0001).
create or replace function public.hazard_report(p jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  me uuid := community_private.require_hazards('community.hazards.post');
  park public.dog_parks;
  v_kind text := p->>'kind';
  v_park uuid := nullif(p->>'park_id', '')::uuid;
  v_locality text := nullif(btrim(coalesce(p->>'locality_code', '')), '');
  v_note text := btrim(coalesce(p->>'note', ''));
  recent integer;
  new_id uuid;
begin
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'invalid_hazard' using errcode = '22023';
  end if;
  if v_kind is null or v_kind not in ('caterpillars', 'bait', 'glass', 'inspector', 'other') then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'kind';
  end if;
  if v_park is not null then
    select * into park from public.dog_parks where id = v_park and status in ('active', 'closed');
    if not found then
      raise exception 'invalid_hazard' using errcode = '22023', detail = 'unknown park';
    end if;
    v_locality := coalesce(park.locality_code, v_locality);
  end if;
  if v_locality is null or v_locality !~ '^[a-z0-9-]{2,60}$' then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'locality';
  end if;
  if char_length(v_note) > 140 then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'note';
  end if;
  -- "Other" says what it is.
  if v_kind = 'other' and v_note = '' then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'note';
  end if;

  perform community_private.hazards_housekeeping();
  select count(*) into recent from public.hazard_reports
   where created_by = me and created_at > now() - interval '1 day';
  if recent >= 5 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  insert into public.hazard_reports(locality_code, park_id, kind, note, created_by)
  values (v_locality, v_park, v_kind, v_note, me)
  returning id into new_id;
  return new_id;
end $$;
revoke all on function public.hazard_report(jsonb) from public, anon;
grant execute on function public.hazard_report(jsonb) to authenticated;

-- "Still there" (false) / "Not there any more" (true) on someone else's
-- current report; voting again changes the vote. Two "not there any
-- more" hide it. Answers whether it is still shown.
-- Refusals: invalid_hazard (22023), not_open (P0001: gone or hidden).
create or replace function public.hazard_vote(p_id uuid, p_gone boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  me uuid := community_private.require_hazards('community.hazards.view');
  report public.hazard_reports;
  gone_votes integer;
begin
  if p_gone is null then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'vote';
  end if;
  select * into report from public.hazard_reports where id = p_id for update;
  if not found or report.hidden or report.expires_at <= now() then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if report.created_by = me then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'your own report';
  end if;
  if exists (select 1 from public.user_blocks b
             where (b.blocker_id = me and b.blocked_id = report.created_by)
                or (b.blocker_id = report.created_by and b.blocked_id = me)) then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  insert into public.hazard_votes(report_id, user_id, gone) values (p_id, me, p_gone)
  on conflict (report_id, user_id) do update set gone = excluded.gone, created_at = now();
  select count(*) into gone_votes from public.hazard_votes
   where report_id = p_id and gone and user_id <> report.created_by;
  if gone_votes >= 2 then
    update public.hazard_reports set hidden = true where id = p_id;
    return false;
  end if;
  return true;
end $$;
revoke all on function public.hazard_vote(uuid, boolean) from public, anon;
grant execute on function public.hazard_vote(uuid, boolean) to authenticated;

-- The author takes their report down.
create or replace function public.hazard_delete(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare me uuid := community_private.require_hazards('community.hazards.view');
begin
  delete from public.hazard_reports where id = p_id and created_by = me;
  if not found then
    raise exception 'invalid_hazard' using errcode = '22023', detail = 'not your report';
  end if;
end $$;
revoke all on function public.hazard_delete(uuid) from public, anon;
grant execute on function public.hazard_delete(uuid) to authenticated;

commit;
