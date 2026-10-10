-- PetLoop: dog parks (Community > Outside > Parks). Apply after 0025.
-- Design and owner steps: docs/dog_parks.md.
--
--   * dog_parks: the parks. Imported once a month from OpenStreetMap
--     (leisure=dog_park) by the Edge Function parks-import through
--     dog_parks_import() (service role only), or added by a park reviewer
--     approving a member's suggestion. Members read the active and closed
--     ones; nobody but the import and the reviewer functions writes.
--   * dog_park_suggestions: what members send ("Suggest a park", "Update
--     details"). Nothing is published until a reviewer approves it.
--     Ten suggestions a day per account.
--   * dog_park_favorites: "My parks". notify_meetups is kept for the
--     meetups feature (0028) and not shown yet.
--   * capabilities community.parks.view and community.parks.suggest for
--     everyone (Standard owners), community.parks.review for reviewers
--     (permission administrators get it now; the owner appoints others in
--     the permissions screen).
--
-- A park is never deleted: the import moves a park that vanished from
-- OpenStreetMap to 'pending_review', and a reviewer keeps, closes or
-- removes it. Fields a reviewer approved or set are listed in locked_fields
-- and the import never overwrites them.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.access_capabilities') is null or to_regnamespace('community_private') is null then
    raise exception 'Run 0014_feature_access.sql and 0021_community_chat_safety.sql first.';
  end if;
end
$$;

create schema if not exists dog_parks_private;
revoke all on schema dog_parks_private from public;
grant usage on schema dog_parks_private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Capabilities.
-- ---------------------------------------------------------------------------
-- Clients refresh their permissions when the revision moves (first run only).
update public.access_revision set revision=revision+1
where singleton and not exists (select 1 from public.access_capabilities where id='community.parks.view');
insert into public.access_capabilities(id,feature_id) values ('community.parks.view','community')
on conflict(id) do nothing;
insert into public.access_capabilities(id,feature_id,requires_view) values
 ('community.parks.suggest','community','community.parks.view'),
 ('community.parks.review','community','community.parks.view')
on conflict(id) do nothing;
-- Everyone (the Standard owners group) may look and suggest.
insert into public.group_capability_rules(group_id,capability,allowed)
select g.id, c.capability, true
from public.access_groups g
cross join (values ('community.parks.view'),('community.parks.suggest')) as c(capability)
where g.id='acc35500-0000-4000-8000-000000000001'
on conflict do nothing;
-- Permission administrators review, as they moderate.
insert into public.user_capability_rules(user_id,capability,allowed)
select user_id,'community.parks.review',true from public.access_admins
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Parks.
-- ---------------------------------------------------------------------------
create table if not exists public.dog_parks (
  id uuid primary key default gen_random_uuid(),
  -- 'osm': OpenStreetMap ('node/1', 'way/2', 'relation/3');
  -- 'member': an approved suggestion (its id); 'admin': added by hand.
  source text not null check (source in ('osm','member','admin')),
  source_id text not null check (char_length(source_id) between 1 and 80),
  name_he text check (char_length(name_he) <= 120),
  name_en text check (char_length(name_en) <= 120),
  -- The nearest named street (OpenStreetMap), or the member's place text:
  -- an unnamed park shows as "Dog park · <street>".
  street_he text check (char_length(street_he) <= 120),
  street_en text check (char_length(street_en) <= 120),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  -- The nearest locality of the app's list (tool/data/il_localities.json).
  locality_code text check (char_length(locality_code) <= 60),
  fenced text not null default 'unknown' check (fenced in ('yes','no','unknown')),
  water text not null default 'unknown' check (water in ('yes','no','unknown')),
  shade text not null default 'unknown' check (shade in ('yes','no','unknown')),
  lighting text not null default 'unknown' check (lighting in ('yes','no','unknown')),
  small_dogs text not null default 'unknown' check (small_dogs in ('yes','no','unknown')),
  benches text not null default 'unknown' check (benches in ('yes','no','unknown')),
  opening_hours text check (char_length(opening_hours) <= 200),
  -- active and closed (for renovation) are shown; pending_review and
  -- removed are for reviewers only.
  status text not null default 'active' check (status in ('active','pending_review','closed','removed')),
  -- Why a park waits for review ('osm_vanished').
  review_reason text check (char_length(review_reason) <= 40),
  -- Columns the import must not change: names, street, location,
  -- locality, the six details, opening_hours, status.
  locked_fields text[] not null default '{}',
  osm_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source, source_id)
);
-- Lists ask for a box of latitudes and longitudes.
create index if not exists dog_parks_lat_lng_idx on public.dog_parks (lat, lng);
create index if not exists dog_parks_locality_idx on public.dog_parks (locality_code);

create table if not exists public.dog_park_suggestions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('new_park','details')),
  park_id uuid references public.dog_parks(id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  -- A new park: an optional name, the location (the phone's position at the
  -- park, or the centre of the chosen locality with a place text).
  name text check (char_length(name) <= 80),
  lat double precision check (lat between 29.3 and 33.5),
  lng double precision check (lng between 34.2 and 35.95),
  location_kind text check (location_kind in ('device','locality')),
  locality_code text check (char_length(locality_code) <= 60),
  place_note text check (char_length(place_note) <= 200),
  -- {"fenced":"yes", ..., "closed": true}
  changes jsonb not null default '{}'::jsonb check (jsonb_typeof(changes) = 'object'),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewer_id uuid references auth.users(id) on delete set null,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (kind = 'new_park' and park_id is null and lat is not null and lng is not null and location_kind is not null
      and (location_kind = 'device' or (locality_code is not null and coalesce(char_length(btrim(place_note)), 0) > 0)))
    or (kind = 'details' and park_id is not null and changes <> '{}'::jsonb)
  )
);
create index if not exists dog_park_suggestions_author_idx on public.dog_park_suggestions (author_id, created_at);
create index if not exists dog_park_suggestions_pending_idx on public.dog_park_suggestions (created_at) where status = 'pending';
create index if not exists dog_park_suggestions_park_idx on public.dog_park_suggestions (park_id);

create table if not exists public.dog_park_favorites (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  park_id uuid not null references public.dog_parks(id) on delete cascade,
  -- For the meetups feature: tell me about new meetups at this park.
  notify_meetups boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, park_id)
);
create index if not exists dog_park_favorites_park_idx on public.dog_park_favorites (park_id);

create table if not exists public.dog_park_import_runs (
  period_key text primary key,
  status text not null check (status in ('running','succeeded','failed')),
  stats jsonb not null default '{}'::jsonb,
  error text,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Row level security. Clients only read parks; suggestions are written by
-- their author and read by them; favourites belong to their owner.
-- ---------------------------------------------------------------------------
alter table public.dog_parks enable row level security;
alter table public.dog_park_suggestions enable row level security;
alter table public.dog_park_favorites enable row level security;
alter table public.dog_park_import_runs enable row level security;

revoke all on public.dog_parks, public.dog_park_suggestions, public.dog_park_favorites, public.dog_park_import_runs from anon;
revoke all on public.dog_parks, public.dog_park_suggestions, public.dog_park_import_runs from authenticated;
revoke all on public.dog_park_favorites from authenticated;
grant select on public.dog_parks to authenticated;
grant select, insert on public.dog_park_suggestions to authenticated;
grant select, insert, update, delete on public.dog_park_favorites to authenticated;
grant all on public.dog_parks, public.dog_park_suggestions, public.dog_park_favorites, public.dog_park_import_runs to service_role;

drop policy if exists "dog_parks: members read shown parks" on public.dog_parks;
create policy "dog_parks: members read shown parks" on public.dog_parks
  for select to authenticated using (status in ('active','closed'));

drop policy if exists "dog_park_suggestions: author reads own" on public.dog_park_suggestions;
create policy "dog_park_suggestions: author reads own" on public.dog_park_suggestions
  for select to authenticated using (author_id = (select auth.uid()));
drop policy if exists "dog_park_suggestions: suggest as yourself" on public.dog_park_suggestions;
create policy "dog_park_suggestions: suggest as yourself" on public.dog_park_suggestions
  for insert to authenticated with check (
    author_id = (select auth.uid()) and status = 'pending' and reviewer_id is null and decided_at is null
  );

drop policy if exists "dog_park_favorites: owner" on public.dog_park_favorites;
create policy "dog_park_favorites: owner" on public.dog_park_favorites
  for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Feature permissions, restrictive, as 0014 adds them to every table.
do $$ declare row record; begin
 for row in select * from (values
  ('dog_parks','(select public.can_use(''community.parks.view''))','false'),
  ('dog_park_favorites','(select public.can_use(''community.parks.view''))','(select public.can_use(''community.parks.view''))'),
  ('dog_park_suggestions','(select public.can_use(''community.parks.view''))','(select public.can_use(''community.parks.suggest''))')
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
-- A suggestion is checked before it is stored: only known details with
-- yes / no / unknown (and "closed" as true / false), a park members can
-- see, a location in Israel, and at most ten a day per account.
-- ---------------------------------------------------------------------------
create or replace function dog_parks_private.check_suggestion()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  k text;
  v jsonb;
  recent integer;
begin
  for k, v in select * from jsonb_each(new.changes) loop
    if k = 'closed' then
      if jsonb_typeof(v) <> 'boolean' then
        raise exception 'invalid_suggestion' using errcode = '22023', detail = 'closed must be true or false';
      end if;
    elsif k in ('fenced','water','shade','lighting','small_dogs','benches') then
      if jsonb_typeof(v) <> 'string' or v #>> '{}' not in ('yes','no','unknown') then
        raise exception 'invalid_suggestion' using errcode = '22023', detail = k || ' must be yes, no or unknown';
      end if;
    else
      raise exception 'invalid_suggestion' using errcode = '22023', detail = 'unknown detail ' || k;
    end if;
  end loop;
  if new.kind = 'details' and not exists (
    select 1 from public.dog_parks p where p.id = new.park_id and p.status in ('active','closed')
  ) then
    raise exception 'invalid_suggestion' using errcode = '22023', detail = 'unknown park';
  end if;
  if new.kind = 'new_park' and new.changes ? 'closed' then
    raise exception 'invalid_suggestion' using errcode = '22023', detail = 'a new park cannot be closed';
  end if;
  select count(*) into recent from public.dog_park_suggestions s
   where s.author_id = new.author_id and s.created_at > now() - interval '1 day';
  if recent >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  return new;
end $$;
revoke all on function dog_parks_private.check_suggestion() from public, anon, authenticated;
drop trigger if exists dog_park_suggestion_check on public.dog_park_suggestions;
create trigger dog_park_suggestion_check before insert on public.dog_park_suggestions
  for each row execute function dog_parks_private.check_suggestion();

-- ---------------------------------------------------------------------------
-- Review: the queue and the decisions, for park reviewers only.
-- ---------------------------------------------------------------------------
create or replace function dog_parks_private.require_reviewer()
returns void language plpgsql stable security definer set search_path='' as $$
begin
  if not access_private.evaluate(auth.uid(), 'community.parks.review') then
    raise exception 'Park reviewer access required' using errcode = '42501';
  end if;
end $$;
revoke all on function dog_parks_private.require_reviewer() from public, anon, authenticated;

create or replace function dog_parks_private.park_json(p public.dog_parks)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'id', p.id, 'source', p.source, 'source_id', p.source_id,
    'name_he', p.name_he, 'name_en', p.name_en, 'street_he', p.street_he, 'street_en', p.street_en,
    'lat', p.lat, 'lng', p.lng, 'locality_code', p.locality_code,
    'fenced', p.fenced, 'water', p.water, 'shade', p.shade, 'lighting', p.lighting,
    'small_dogs', p.small_dogs, 'benches', p.benches, 'opening_hours', p.opening_hours,
    'status', p.status, 'review_reason', p.review_reason, 'locked_fields', to_jsonb(p.locked_fields),
    'updated_at', p.updated_at)
$$;
revoke all on function dog_parks_private.park_json(public.dog_parks) from public, anon, authenticated;

-- {"suggestions": [oldest first, each with "park" for detail changes],
--  "parks": [parks waiting for review: vanished from OpenStreetMap]}
create or replace function dog_parks_private.review_queue()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform dog_parks_private.require_reviewer();
  return jsonb_build_object(
    'suggestions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'kind', s.kind, 'park_id', s.park_id, 'name', s.name,
        'lat', s.lat, 'lng', s.lng, 'location_kind', s.location_kind,
        'locality_code', s.locality_code, 'place_note', s.place_note,
        'changes', s.changes, 'created_at', s.created_at,
        'park', case when p.id is null then null else dog_parks_private.park_json(p) end
      ) order by s.created_at)
      from public.dog_park_suggestions s
      left join public.dog_parks p on p.id = s.park_id
      where s.status = 'pending'
    ), '[]'::jsonb),
    'parks', coalesce((
      select jsonb_agg(dog_parks_private.park_json(p) order by p.updated_at)
      from public.dog_parks p where p.status = 'pending_review'
    ), '[]'::jsonb)
  );
end $$;
revoke all on function dog_parks_private.review_queue() from public, anon;
grant execute on function dog_parks_private.review_queue() to authenticated;

-- p_action 'approve' or 'reject'. p_edits (approve only) may correct the
-- suggestion first: "name", "lat", "lng", "locality_code", "street", and
-- any detail. Returns the park's id (null when rejected).
create or replace function dog_parks_private.decide(p_suggestion uuid, p_action text, p_edits jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  s public.dog_park_suggestions;
  edits jsonb := coalesce(p_edits, '{}'::jsonb);
  details jsonb;
  park uuid;
  k text;
  v text;
  name text;
  street text;
  hebrew constant text := '[א-ת]';
  attr constant text[] := array['fenced','water','shade','lighting','small_dogs','benches'];
begin
  perform dog_parks_private.require_reviewer();
  if p_action not in ('approve','reject') or jsonb_typeof(edits) <> 'object' then
    raise exception 'Unknown review action' using errcode = '22023';
  end if;
  select * into s from public.dog_park_suggestions where id = p_suggestion for update;
  if not found then
    raise exception 'Suggestion not found' using errcode = 'P0002';
  end if;
  if s.status <> 'pending' then
    raise exception 'already_decided' using errcode = 'P0001';
  end if;
  if p_action = 'reject' then
    update public.dog_park_suggestions set status = 'rejected', reviewer_id = auth.uid(), decided_at = now()
     where id = s.id;
    return null;
  end if;

  details := s.changes || (edits - array['name','lat','lng','locality_code','street']);
  for k, v in select key, value #>> '{}' from jsonb_each(details) loop
    if (k = any(attr) and v not in ('yes','no','unknown')) or (k = 'closed' and v not in ('true','false'))
       or not (k = any(attr) or k = 'closed') then
      raise exception 'invalid_edit' using errcode = '22023', detail = k;
    end if;
  end loop;

  if s.kind = 'new_park' then
    name := nullif(btrim(coalesce(edits->>'name', s.name, '')), '');
    street := nullif(btrim(coalesce(edits->>'street', s.place_note, '')), '');
    insert into public.dog_parks(source, source_id, name_he, name_en, street_he, street_en, lat, lng, locality_code,
      fenced, water, shade, lighting, small_dogs, benches, status)
    values ('member', s.id::text,
      case when name ~ hebrew then name end, case when name !~ hebrew then name end,
      case when street ~ hebrew then street end, case when street !~ hebrew then street end,
      coalesce((edits->>'lat')::double precision, s.lat), coalesce((edits->>'lng')::double precision, s.lng),
      coalesce(edits->>'locality_code', s.locality_code),
      coalesce(details->>'fenced','unknown'), coalesce(details->>'water','unknown'),
      coalesce(details->>'shade','unknown'), coalesce(details->>'lighting','unknown'),
      coalesce(details->>'small_dogs','unknown'), coalesce(details->>'benches','unknown'), 'active')
    returning id into park;
  else
    park := s.park_id;
    update public.dog_parks p set
      fenced = coalesce(details->>'fenced', p.fenced),
      water = coalesce(details->>'water', p.water),
      shade = coalesce(details->>'shade', p.shade),
      lighting = coalesce(details->>'lighting', p.lighting),
      small_dogs = coalesce(details->>'small_dogs', p.small_dogs),
      benches = coalesce(details->>'benches', p.benches),
      status = case when details->>'closed' = 'true' then 'closed'
                    when details->>'closed' = 'false' then 'active' else p.status end,
      review_reason = case when details ? 'closed' then null else p.review_reason end,
      -- What a reviewer approved stays: the monthly import keeps it.
      locked_fields = (
        select array_agg(distinct f order by f) from unnest(
          p.locked_fields
          || array(select x from jsonb_object_keys(details) x where x = any(attr))
          || case when details ? 'closed' then array['status'] else array[]::text[] end
        ) f
      ),
      updated_at = now()
    where p.id = park;
  end if;
  update public.dog_park_suggestions set status = 'approved', reviewer_id = auth.uid(), decided_at = now()
   where id = s.id;
  return park;
end $$;
revoke all on function dog_parks_private.decide(uuid, text, jsonb) from public, anon;
grant execute on function dog_parks_private.decide(uuid, text, jsonb) to authenticated;

-- A reviewer's word on a park: 'active' (keep), 'closed' or 'removed'
-- (hidden, never deleted). The import keeps the status from then on.
create or replace function dog_parks_private.set_status(p_park uuid, p_status text)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform dog_parks_private.require_reviewer();
  if p_status not in ('active','closed','removed') then
    raise exception 'Unknown park status' using errcode = '22023';
  end if;
  update public.dog_parks p set
    status = p_status,
    review_reason = null,
    locked_fields = (select array_agg(distinct f order by f) from unnest(p.locked_fields || array['status']) f),
    updated_at = now()
  where p.id = p_park;
  if not found then
    raise exception 'Park not found' using errcode = 'P0002';
  end if;
end $$;
revoke all on function dog_parks_private.set_status(uuid, text) from public, anon;
grant execute on function dog_parks_private.set_status(uuid, text) to authenticated;

create or replace function public.dog_park_review_queue()
returns jsonb language sql stable security invoker set search_path='' as $$ select dog_parks_private.review_queue() $$;
revoke all on function public.dog_park_review_queue() from public, anon;
grant execute on function public.dog_park_review_queue() to authenticated;

create or replace function public.dog_park_decide(p_suggestion uuid, p_action text, p_edits jsonb default '{}'::jsonb)
returns uuid language sql security invoker set search_path='' as $$ select dog_parks_private.decide(p_suggestion, p_action, p_edits) $$;
revoke all on function public.dog_park_decide(uuid, text, jsonb) from public, anon;
grant execute on function public.dog_park_decide(uuid, text, jsonb) to authenticated;

create or replace function public.dog_park_set_status(p_park uuid, p_status text)
returns void language sql security invoker set search_path='' as $$ select dog_parks_private.set_status(p_park, p_status) $$;
revoke all on function public.dog_park_set_status(uuid, text) from public, anon;
grant execute on function public.dog_park_set_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- The monthly import (Edge Function parks-import, service role only).
--
-- p_parks: [{"source_id": "way/123", "name_he", "name_en", "street_he",
-- "street_en", "lat", "lng", "locality_code", "fenced", "water", "shade",
-- "lighting", "small_dogs", "benches", "opening_hours"}, ...] = every
-- leisure=dog_park OpenStreetMap has in Israel today.
--
-- New parks are added; known ones are refreshed except their locked
-- fields; a park that came back to the map leaves review; a park that is
-- gone moves to 'pending_review' (never deleted). An answer with less than
-- half of the parks we know is refused unless p_force: a broken download
-- must not send every park to review.
-- ---------------------------------------------------------------------------
create or replace function dog_parks_private.import(p_period text, p_parks jsonb, p_force boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  incoming integer;
  known integer;
  added integer := 0;
  refreshed integer := 0;
  reappeared integer := 0;
  vanished integer := 0;
  result jsonb;
begin
  if jsonb_typeof(p_parks) is distinct from 'array' then
    raise exception 'invalid_import' using errcode = '22023', detail = 'p_parks must be an array';
  end if;
  if p_period is null or p_period !~ '^\d{4}-\d{2}$' then
    raise exception 'invalid_import' using errcode = '22023', detail = 'p_period must be YYYY-MM';
  end if;

  create temporary table if not exists dog_park_incoming (
    source_id text primary key, name_he text, name_en text, street_he text, street_en text,
    lat double precision, lng double precision, locality_code text,
    fenced text, water text, shade text, lighting text, small_dogs text, benches text, opening_hours text
  ) on commit drop;
  truncate pg_temp.dog_park_incoming;
  insert into pg_temp.dog_park_incoming
  select distinct on (x.source_id)
    x.source_id, left(nullif(btrim(x.name_he),''),120), left(nullif(btrim(x.name_en),''),120),
    left(nullif(btrim(x.street_he),''),120), left(nullif(btrim(x.street_en),''),120),
    x.lat, x.lng, left(nullif(x.locality_code,''),60),
    case when x.fenced in ('yes','no') then x.fenced else 'unknown' end,
    case when x.water in ('yes','no') then x.water else 'unknown' end,
    case when x.shade in ('yes','no') then x.shade else 'unknown' end,
    case when x.lighting in ('yes','no') then x.lighting else 'unknown' end,
    case when x.small_dogs in ('yes','no') then x.small_dogs else 'unknown' end,
    case when x.benches in ('yes','no') then x.benches else 'unknown' end,
    left(nullif(btrim(x.opening_hours),''),200)
  from jsonb_to_recordset(p_parks) as x(
    source_id text, name_he text, name_en text, street_he text, street_en text,
    lat double precision, lng double precision, locality_code text,
    fenced text, water text, shade text, lighting text, small_dogs text, benches text, opening_hours text)
  where x.source_id ~ '^(node|way|relation)/\d+$'
    and x.lat between -90 and 90 and x.lng between -180 and 180;

  select count(*) into incoming from pg_temp.dog_park_incoming;
  select count(*) into known from public.dog_parks where source = 'osm' and status in ('active','closed');
  if not coalesce(p_force, false) and known >= 20 and incoming * 2 < known then
    raise exception 'suspicious_import' using errcode = 'P0001',
      detail = format('%s parks offered, %s known', incoming, known);
  end if;

  -- Back on the map: out of review (unless a reviewer decided its status).
  update public.dog_parks p set status = 'active', review_reason = null, updated_at = now()
  from pg_temp.dog_park_incoming i
  where p.source = 'osm' and p.source_id = i.source_id
    and p.status = 'pending_review' and p.review_reason = 'osm_vanished'
    and not ('status' = any(p.locked_fields));
  get diagnostics reappeared = row_count;

  with up as (
    insert into public.dog_parks as p (source, source_id, name_he, name_en, street_he, street_en, lat, lng,
      locality_code, fenced, water, shade, lighting, small_dogs, benches, opening_hours, osm_seen_at)
    select 'osm', i.source_id, i.name_he, i.name_en, i.street_he, i.street_en, i.lat, i.lng,
      i.locality_code, i.fenced, i.water, i.shade, i.lighting, i.small_dogs, i.benches, i.opening_hours, now()
    from pg_temp.dog_park_incoming i
    on conflict (source, source_id) do update set
      name_he = case when 'name' = any(p.locked_fields) then p.name_he else excluded.name_he end,
      name_en = case when 'name' = any(p.locked_fields) then p.name_en else excluded.name_en end,
      street_he = case when 'street' = any(p.locked_fields) then p.street_he else excluded.street_he end,
      street_en = case when 'street' = any(p.locked_fields) then p.street_en else excluded.street_en end,
      lat = case when 'location' = any(p.locked_fields) then p.lat else excluded.lat end,
      lng = case when 'location' = any(p.locked_fields) then p.lng else excluded.lng end,
      locality_code = case when 'locality_code' = any(p.locked_fields) then p.locality_code else excluded.locality_code end,
      fenced = case when 'fenced' = any(p.locked_fields) then p.fenced else excluded.fenced end,
      water = case when 'water' = any(p.locked_fields) then p.water else excluded.water end,
      shade = case when 'shade' = any(p.locked_fields) then p.shade else excluded.shade end,
      lighting = case when 'lighting' = any(p.locked_fields) then p.lighting else excluded.lighting end,
      small_dogs = case when 'small_dogs' = any(p.locked_fields) then p.small_dogs else excluded.small_dogs end,
      benches = case when 'benches' = any(p.locked_fields) then p.benches else excluded.benches end,
      opening_hours = case when 'opening_hours' = any(p.locked_fields) then p.opening_hours else excluded.opening_hours end,
      osm_seen_at = excluded.osm_seen_at,
      updated_at = now()
    returning (xmax = 0) as inserted
  )
  select count(*) filter (where inserted), count(*) filter (where not inserted) into added, refreshed from up;

  -- Gone from the map: a reviewer decides (keep, closed, removed).
  update public.dog_parks p set status = 'pending_review', review_reason = 'osm_vanished', updated_at = now()
  where p.source = 'osm' and p.status in ('active','closed')
    and not ('status' = any(p.locked_fields))
    and not exists (select 1 from pg_temp.dog_park_incoming i where i.source_id = p.source_id);
  get diagnostics vanished = row_count;

  result := jsonb_build_object('received', jsonb_array_length(p_parks), 'accepted', incoming,
    'added', added, 'refreshed', refreshed, 'reappeared', reappeared, 'vanished', vanished);
  insert into public.dog_park_import_runs(period_key, status, stats, error, started_at, finished_at)
  values (p_period, 'succeeded', result, null, now(), now())
  on conflict (period_key) do update set status = 'succeeded', stats = excluded.stats, error = null,
    finished_at = excluded.finished_at;
  drop table if exists pg_temp.dog_park_incoming;
  return result;
end $$;
revoke all on function dog_parks_private.import(text, jsonb, boolean) from public, anon, authenticated;
grant execute on function dog_parks_private.import(text, jsonb, boolean) to service_role;

create or replace function public.dog_parks_import(p_period text, p_parks jsonb, p_force boolean default false)
returns jsonb language sql security invoker set search_path='' as $$ select dog_parks_private.import(p_period, p_parks, p_force) $$;
revoke all on function public.dog_parks_import(text, jsonb, boolean) from public, anon, authenticated;
grant execute on function public.dog_parks_import(text, jsonb, boolean) to service_role;

commit;
