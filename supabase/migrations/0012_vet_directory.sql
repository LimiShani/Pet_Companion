-- PetLoop: "Find a vet" - the curated vet directory, live intake status,
-- the admins' review queue, the weekly job's bookkeeping and the search
-- rate limits. Design and API contract: docs/find_a_vet.md.
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001
-- (public.touch_updated_at). Safe to run more than once.
--
-- Purely additive: no existing table, column, row or file is touched.
--   vet_facilities                our curated facilities (any country, by country_code)
--   vet_facility_provider_ids     (facility, provider, place_id) links - IDs only
--   vet_provider_link_candidates  heuristic matches waiting for an admin
--   vet_facility_claims           sourced claims (emergency, schedule, species...)
--   vet_intake_status             live, short-lived intake status sent by a facility
--   vet_case_confirmations        case-specific acceptances (future API)
--   vet_intake_reporters          who may report for which facility
--   vet_directory_admins          who may review the directory
--   vet_review_items              the review queue
--   vet_admin_actions             audit trail of every admin action
--   vet_job_runs                  one row per weekly job run (ISO week)
--   vet_search_quota              hashed rate-limit counters, auto-pruned
--
-- Who can do what (the publishable key in the app can do nothing else):
--   anon + authenticated  read the views vet_directory_public and
--                         vet_intake_current, call vet_case_status
--   authenticated         call vet_is_admin; admins call vet_admin_*;
--                         registered reporters call vet_report_intake and
--                         vet_confirm_case
--   service_role          everything (Edge Functions), incl. vet_search_take,
--                         vet_upsert_review_item, vet_record_link_candidate
-- No base table is readable by anon or authenticated: RLS is on with no
-- policies for them, and their table privileges are revoked.
--
-- Provider content (Google Places) is never stored here: only place IDs.

begin;

-- ---------------------------------------------------------------------------
-- vet_facilities
-- ---------------------------------------------------------------------------
create table if not exists public.vet_facilities (
  id uuid primary key default gen_random_uuid(),
  -- ISO 3166-1 alpha-2; picks the region module (bounds, phones, words) in the functions.
  country_code char(2) not null default 'IL' check (country_code ~ '^[A-Z]{2}$'),
  name text not null check (char_length(name) between 1 and 160),
  name_he text check (name_he is null or char_length(name_he) between 1 and 160),
  address text check (address is null or char_length(address) <= 300),
  city text check (city is null or char_length(city) <= 120),
  lat double precision check (lat is null or lat between -90 and 90),
  lng double precision check (lng is null or lng between -180 and 180),
  -- E.164 (+97239688588), or a short star number (*8818).
  phone text check (phone is null or phone ~ '^(\+[1-9][0-9]{6,14}|\*[0-9]{3,5})$'),
  website text check (website is null or website ~* '^https?://'),
  facility_type text not null default 'clinic'
    check (facility_type in ('hospital', 'clinic', 'emergency_center', 'mobile', 'other')),
  -- pending: added, not shown; approved / needs_review: shown; withdrawn: hidden.
  review_status text not null default 'pending'
    check (review_status in ('pending', 'approved', 'needs_review', 'withdrawn')),
  -- Last successful weekly check of any of its pages.
  last_checked_at timestamptz,
  -- Last time an admin approved it.
  last_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((lat is null) = (lng is null))
);

comment on table public.vet_facilities is
  'Find a vet: curated facilities. Shown (via vet_directory_public) when approved or needs_review.';
comment on column public.vet_facilities.country_code is
  'ISO 3166-1 alpha-2; selects the region module in the Edge Functions.';

create index if not exists vet_facilities_country_status_idx
  on public.vet_facilities (country_code, review_status);
create index if not exists vet_facilities_country_lat_idx
  on public.vet_facilities (country_code, lat);

drop trigger if exists vet_facilities_touch_updated_at on public.vet_facilities;
create trigger vet_facilities_touch_updated_at
  before update on public.vet_facilities
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- vet_facility_provider_ids: confirmed links to a provider's place.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_facility_provider_ids (
  facility_id uuid not null references public.vet_facilities (id) on delete cascade,
  provider text not null default 'google' check (provider in ('google')),
  place_id text not null check (char_length(place_id) between 1 and 300),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  primary key (provider, place_id)
);

comment on table public.vet_facility_provider_ids is
  'Find a vet: confirmed facility <-> provider place links (place IDs only; Google allows storing them).';

create index if not exists vet_facility_provider_ids_facility_idx
  on public.vet_facility_provider_ids (facility_id);

-- ---------------------------------------------------------------------------
-- vet_provider_link_candidates: heuristic matches for an admin to confirm.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_provider_link_candidates (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.vet_facilities (id) on delete cascade,
  provider text not null default 'google' check (provider in ('google')),
  place_id text not null check (char_length(place_id) between 1 and 300),
  -- Which second rule held besides distance + name ('phone' or 'address').
  matched_on text not null check (matched_on in ('phone', 'address')),
  status text not null default 'open' check (status in ('open', 'linked', 'rejected')),
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  seen_count integer not null default 1 check (seen_count >= 1),
  unique (facility_id, provider, place_id)
);

comment on table public.vet_provider_link_candidates is
  'Find a vet: heuristic matches seen by searches (place IDs only), waiting for an admin.';

-- ---------------------------------------------------------------------------
-- vet_facility_claims: one row per sourced claim.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_facility_claims (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.vet_facilities (id) on delete cascade,
  claim_key text not null
    check (claim_key in ('emergency', 'schedule', 'phone', 'address', 'website', 'species', 'services')),
  -- emergency: {"schedule": "24/7"}; species / services: ["dog", "cat"]; others free.
  value jsonb not null default '{}'::jsonb,
  source_url text check (source_url is null or (source_url ~* '^https?://' and char_length(source_url) <= 1000)),
  source_kind text not null default 'facility_site' check (source_kind in ('facility_site', 'partner', 'manual')),
  status text not null default 'current' check (status in ('current', 'unverified', 'conflict', 'withdrawn')),
  -- What the weekly check looks for on source_url (empty: the region's defaults for the key).
  evidence_patterns text[] not null default '{}' check (cardinality(evidence_patterns) <= 20),
  -- Last successful check (evidence found) by the weekly job, or admin confirmation.
  checked_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- An emergency claim always cites an https page.
  check (claim_key <> 'emergency' or (source_url is not null and source_url ~* '^https://'))
);

comment on table public.vet_facility_claims is
  'Find a vet: sourced claims per facility. Only the weekly job (downgrade only) and admins change status.';

-- One claim per facility, key and source (two pages may back the same claim).
create unique index if not exists vet_facility_claims_source_uidx
  on public.vet_facility_claims (facility_id, claim_key, (coalesce(source_url, '')));

drop trigger if exists vet_facility_claims_touch_updated_at on public.vet_facility_claims;
create trigger vet_facility_claims_touch_updated_at
  before update on public.vet_facility_claims
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- vet_intake_status: the facility's own live status, at most 6 hours.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_intake_status (
  facility_id uuid primary key references public.vet_facilities (id) on delete cascade,
  status text not null check (status in ('accepting', 'limited', 'diverting')),
  species text[] not null default '{}' check (cardinality(species) <= 20),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  reported_by uuid references auth.users (id) on delete set null,
  check (expires_at > updated_at and expires_at <= updated_at + interval '6 hours')
);

comment on table public.vet_intake_status is
  'Find a vet: live intake status sent by the facility (vet_report_intake); never seeded or simulated.';

-- ---------------------------------------------------------------------------
-- vet_case_confirmations: "we accept this case" for one reference.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_case_confirmations (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.vet_facilities (id) on delete cascade,
  -- Shared secret between the user and the facility (at least 8 characters).
  reference text not null check (char_length(reference) between 8 and 64),
  accepted boolean not null,
  confirmed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  confirmed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  check (expires_at > confirmed_at and expires_at <= confirmed_at + interval '6 hours')
);

comment on table public.vet_case_confirmations is
  'Find a vet: case-specific acceptances by a facility (future API; read through vet_case_status).';

create index if not exists vet_case_confirmations_reference_idx
  on public.vet_case_confirmations (reference, confirmed_at desc);

-- ---------------------------------------------------------------------------
-- vet_intake_reporters / vet_directory_admins
-- ---------------------------------------------------------------------------
create table if not exists public.vet_intake_reporters (
  facility_id uuid not null references public.vet_facilities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (facility_id, user_id)
);

comment on table public.vet_intake_reporters is
  'Find a vet: accounts allowed to report intake / confirm cases for a facility. Added by the owner.';

create table if not exists public.vet_directory_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

comment on table public.vet_directory_admins is
  'Find a vet: accounts allowed to review the directory. Added by the owner in the SQL editor.';

-- ---------------------------------------------------------------------------
-- vet_review_items: the review queue.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_review_items (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid references public.vet_facilities (id) on delete cascade,
  kind text not null check (kind in (
    'emergency_evidence_missing', 'claim_evidence_missing', 'source_unreachable',
    'phone_conflict', 'closure', 'new_emergency_evidence', 'evidence_restored',
    'robots_disallowed', 'source_refused', 'link_candidate', 'verify_coordinates', 'other')),
  severity text not null check (severity in ('high', 'medium', 'low')),
  details jsonb not null default '{}'::jsonb,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  -- e.g. 'emergency_evidence_missing:<claim id>': one open item per problem.
  dedupe_key text not null check (char_length(dedupe_key) between 1 and 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id) on delete set null,
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 2000)
);

comment on table public.vet_review_items is
  'Find a vet: review queue (weekly job findings, link candidates). Unique dedupe_key while open.';

create unique index if not exists vet_review_items_open_dedupe_uidx
  on public.vet_review_items (dedupe_key) where status = 'open';
create index if not exists vet_review_items_status_idx
  on public.vet_review_items (status, created_at desc);

drop trigger if exists vet_review_items_touch_updated_at on public.vet_review_items;
create trigger vet_review_items_touch_updated_at
  before update on public.vet_review_items
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- vet_admin_actions: who did what, when.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_admin_actions (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users (id) on delete set null,
  action text not null,
  target_type text not null check (target_type in ('facility', 'claim', 'review_item', 'provider_link')),
  target_id text not null,
  note text check (note is null or char_length(note) <= 2000),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.vet_admin_actions is
  'Find a vet: audit trail, one row per admin action (written by the vet_admin_* functions).';

create index if not exists vet_admin_actions_created_idx on public.vet_admin_actions (created_at desc);

-- ---------------------------------------------------------------------------
-- vet_job_runs: one row per job and period (ISO week for the weekly job).
-- ---------------------------------------------------------------------------
create table if not exists public.vet_job_runs (
  id uuid primary key default gen_random_uuid(),
  job text not null,
  period_key text not null,
  status text not null check (status in ('running', 'succeeded', 'failed')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  stats jsonb not null default '{}'::jsonb,
  errors jsonb not null default '[]'::jsonb,
  unique (job, period_key)
);

comment on table public.vet_job_runs is
  'Find a vet: weekly job runs (period_key = ISO week, UTC). A finished week is not redone unless forced.';

-- ---------------------------------------------------------------------------
-- vet_search_quota: rate-limit counters. Buckets are hashed client keys
-- ('client:<sha256>') or provider names; '#day' rows count per UTC day.
-- ---------------------------------------------------------------------------
create table if not exists public.vet_search_quota (
  bucket text not null check (char_length(bucket) between 1 and 140),
  window_start timestamptz not null,
  count integer not null default 0 check (count >= 0),
  primary key (bucket, window_start)
);

comment on table public.vet_search_quota is
  'Find a vet: hashed rate-limit counters (no IPs), pruned after 2 days by vet_search_take.';

create index if not exists vet_search_quota_window_idx on public.vet_search_quota (window_start);

-- ---------------------------------------------------------------------------
-- Row level security and privileges: base tables are service-role only.
-- ---------------------------------------------------------------------------
alter table public.vet_facilities enable row level security;
alter table public.vet_facility_provider_ids enable row level security;
alter table public.vet_provider_link_candidates enable row level security;
alter table public.vet_facility_claims enable row level security;
alter table public.vet_intake_status enable row level security;
alter table public.vet_case_confirmations enable row level security;
alter table public.vet_intake_reporters enable row level security;
alter table public.vet_directory_admins enable row level security;
alter table public.vet_review_items enable row level security;
alter table public.vet_admin_actions enable row level security;
alter table public.vet_job_runs enable row level security;
alter table public.vet_search_quota enable row level security;

revoke all on table
  public.vet_facilities, public.vet_facility_provider_ids, public.vet_provider_link_candidates,
  public.vet_facility_claims, public.vet_intake_status, public.vet_case_confirmations,
  public.vet_intake_reporters, public.vet_directory_admins, public.vet_review_items,
  public.vet_admin_actions, public.vet_job_runs, public.vet_search_quota
  from anon, authenticated;

grant select, insert, update, delete on table
  public.vet_facilities, public.vet_facility_provider_ids, public.vet_provider_link_candidates,
  public.vet_facility_claims, public.vet_intake_status, public.vet_case_confirmations,
  public.vet_intake_reporters, public.vet_directory_admins, public.vet_review_items,
  public.vet_admin_actions, public.vet_job_runs, public.vet_search_quota
  to service_role;

-- A signed-in user may see their own admin / reporter rows (nothing else).
grant select on public.vet_directory_admins, public.vet_intake_reporters to authenticated;

drop policy if exists "vet_directory_admins: read own row" on public.vet_directory_admins;
create policy "vet_directory_admins: read own row" on public.vet_directory_admins
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "vet_intake_reporters: read own rows" on public.vet_intake_reporters;
create policy "vet_intake_reporters: read own rows" on public.vet_intake_reporters
  for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- vet_directory_public: what the app (and the search function) may read.
-- Runs with the owner's rights (security_invoker = false) so anon can read
-- it while the base tables stay closed. Only shown facilities, only the
-- columns below, no provider content.
--   emergency: null without a (non-withdrawn) emergency claim; else
--     state 'advertised' when EVERY such claim is current, sourced and
--     checked or confirmed, otherwise 'unverified' (one page losing the
--     evidence is enough to stop calling it advertised);
--     schedule / sourceUrl from the oldest claim (the primary source);
--     checkedAt = the OLDEST successful check among them (honest staleness).
--   facts: current species / services claims.
-- ---------------------------------------------------------------------------
drop view if exists public.vet_directory_public;
create view public.vet_directory_public
with (security_invoker = false) as
select
  f.id,
  f.country_code,
  f.name,
  f.name_he,
  f.address,
  f.city,
  f.lat,
  f.lng,
  f.phone,
  f.website,
  f.facility_type,
  f.review_status,
  f.last_checked_at,
  f.last_confirmed_at,
  (
    select case when count(*) = 0 then null else jsonb_build_object(
      'state', case when bool_and(
          c.status = 'current' and c.source_url is not null
          and coalesce(c.checked_at, c.confirmed_at) is not null)
        then 'advertised' else 'unverified' end,
      'schedule', (array_agg(
          case jsonb_typeof(c.value)
            when 'object' then c.value ->> 'schedule'
            when 'string' then c.value #>> '{}'
          end order by c.created_at, c.source_url))[1],
      'sourceUrl', (array_agg(c.source_url order by c.created_at, c.source_url))[1],
      'checkedAt', min(c.checked_at),
      'confirmedAt', max(c.confirmed_at)
    ) end
    from public.vet_facility_claims c
    where c.facility_id = f.id and c.claim_key = 'emergency' and c.status <> 'withdrawn'
  ) as emergency,
  coalesce((
    select jsonb_agg(jsonb_build_object(
        'key', c.claim_key,
        'value', c.value,
        'sourceUrl', c.source_url,
        'checkedAt', c.checked_at)
      order by c.claim_key, c.created_at)
    from public.vet_facility_claims c
    where c.facility_id = f.id and c.claim_key in ('species', 'services') and c.status = 'current'
  ), '[]'::jsonb) as facts
from public.vet_facilities f
where f.review_status in ('approved', 'needs_review');

comment on view public.vet_directory_public is
  'Find a vet: shown facilities with their emergency claim summary and sourced facts. Readable by anyone.';

-- The view would otherwise be auto-updatable through the owner's rights.
revoke all on public.vet_directory_public from public, anon, authenticated;
grant select on public.vet_directory_public to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- vet_intake_current: live intake, expired rows filtered out.
-- ---------------------------------------------------------------------------
drop view if exists public.vet_intake_current;
create view public.vet_intake_current
with (security_invoker = false) as
select s.facility_id, s.status, s.species, s.updated_at, s.expires_at
from public.vet_intake_status s
join public.vet_facilities f on f.id = s.facility_id
where s.expires_at > now()
  and f.review_status in ('approved', 'needs_review');

comment on view public.vet_intake_current is
  'Find a vet: unexpired intake status of shown facilities. Readable by anyone.';

revoke all on public.vet_intake_current from public, anon, authenticated;
grant select on public.vet_intake_current to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- True when the caller is a directory admin.
create or replace function public.vet_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.vet_directory_admins a where a.user_id = auth.uid());
$$;

revoke execute on function public.vet_is_admin() from public, anon;
grant execute on function public.vet_is_admin() to authenticated, service_role;

-- Internal: one audit row. Not callable by clients.
create or replace function public.vet_log_admin_action(
  p_action text, p_target_type text, p_target_id text, p_note text, p_details jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.vet_admin_actions (admin_id, action, target_type, target_id, note, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, nullif(btrim(coalesce(p_note, '')), ''),
          coalesce(p_details, '{}'::jsonb));
$$;

revoke execute on function public.vet_log_admin_action(text, text, text, text, jsonb) from public, anon, authenticated;

-- Internal: raises unless the caller is an admin.
create or replace function public.vet_require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.vet_is_admin() then
    raise exception 'directory admins only' using errcode = 'insufficient_privilege';
  end if;
end;
$$;

revoke execute on function public.vet_require_admin() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Admin RPCs (signed-in admins; every action audited)
-- ---------------------------------------------------------------------------

-- Open review items, most severe first, newest first within a severity.
create or replace function public.vet_admin_review_items()
returns table (
  id uuid, facility_id uuid, facility_name text, kind text, severity text,
  details jsonb, status text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.vet_require_admin();
  return query
    select i.id, i.facility_id, f.name, i.kind, i.severity, i.details, i.status, i.created_at
    from public.vet_review_items i
    left join public.vet_facilities f on f.id = i.facility_id
    where i.status = 'open'
    order by case i.severity when 'high' then 0 when 'medium' then 1 else 2 end, i.created_at desc;
end;
$$;

-- Every facility (any status) with all its claims.
create or replace function public.vet_admin_facilities()
returns table (
  id uuid, name text, name_he text, address text, city text, phone text, website text,
  facility_type text, review_status text, last_checked_at timestamptz, last_confirmed_at timestamptz,
  claims jsonb, country_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.vet_require_admin();
  return query
    select f.id, f.name, f.name_he, f.address, f.city, f.phone, f.website, f.facility_type,
           f.review_status, f.last_checked_at, f.last_confirmed_at,
           coalesce((
             select jsonb_agg(jsonb_build_object(
                 'key', c.claim_key, 'value', c.value, 'status', c.status,
                 'sourceUrl', c.source_url, 'sourceKind', c.source_kind,
                 'checkedAt', c.checked_at, 'confirmedAt', c.confirmed_at)
               order by c.claim_key, c.created_at)
             from public.vet_facility_claims c where c.facility_id = f.id
           ), '[]'::jsonb),
           f.country_code::text
    from public.vet_facilities f
    order by f.country_code, f.name;
end;
$$;

-- Resolve or dismiss an open review item.
create or replace function public.vet_admin_resolve(p_item uuid, p_action text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.vet_require_admin();
  if p_action not in ('resolve', 'dismiss') then
    raise exception 'action must be resolve or dismiss' using errcode = '22023';
  end if;
  update public.vet_review_items
     set status = case p_action when 'resolve' then 'resolved' else 'dismissed' end,
         resolved_at = now(), resolved_by = auth.uid(),
         resolution_note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_item and status = 'open';
  if not found then
    raise exception 'no open review item %', p_item using errcode = 'no_data_found';
  end if;
  perform public.vet_log_admin_action('review_' || p_action, 'review_item', p_item::text, p_note);
end;
$$;

-- Approve, flag or withdraw a facility. Approving records last_confirmed_at.
create or replace function public.vet_admin_set_status(p_facility uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.vet_require_admin();
  if p_status not in ('approved', 'needs_review', 'withdrawn') then
    raise exception 'status must be approved, needs_review or withdrawn' using errcode = '22023';
  end if;
  update public.vet_facilities
     set review_status = p_status,
         last_confirmed_at = case when p_status = 'approved' then now() else last_confirmed_at end
   where id = p_facility;
  if not found then
    raise exception 'no facility %', p_facility using errcode = 'no_data_found';
  end if;
  perform public.vet_log_admin_action('set_status', 'facility', p_facility::text, p_note,
                                      jsonb_build_object('status', p_status));
end;
$$;

-- Add or correct a claim from a source the admin checked: it becomes
-- current, checked and confirmed now. Emergency needs an https source.
create or replace function public.vet_admin_set_claim(
  p_facility uuid, p_key text, p_value jsonb, p_source_url text, p_source_kind text, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text := nullif(btrim(coalesce(p_source_url, '')), '');
  v_id uuid;
begin
  perform public.vet_require_admin();
  if p_key not in ('emergency', 'schedule', 'phone', 'address', 'website', 'species', 'services') then
    raise exception 'unknown claim key %', p_key using errcode = '22023';
  end if;
  if p_source_kind not in ('facility_site', 'partner', 'manual') then
    raise exception 'source kind must be facility_site, partner or manual' using errcode = '22023';
  end if;
  if p_key = 'emergency' and (v_url is null or v_url !~* '^https://') then
    raise exception 'an emergency claim needs an https source URL' using errcode = '22023';
  end if;
  if not exists (select 1 from public.vet_facilities where id = p_facility) then
    raise exception 'no facility %', p_facility using errcode = 'no_data_found';
  end if;
  insert into public.vet_facility_claims as c
    (facility_id, claim_key, value, source_url, source_kind, status, checked_at, confirmed_at)
  values (p_facility, p_key, coalesce(p_value, '{}'::jsonb), v_url, p_source_kind, 'current', now(), now())
  on conflict (facility_id, claim_key, (coalesce(source_url, ''))) do update
    set value = excluded.value, source_kind = excluded.source_kind, status = 'current',
        checked_at = now(), confirmed_at = now()
  returning c.id into v_id;
  perform public.vet_log_admin_action('set_claim', 'claim', v_id::text, p_note,
    jsonb_build_object('facility', p_facility, 'key', p_key, 'value', p_value,
                       'sourceUrl', v_url, 'sourceKind', p_source_kind));
  return v_id;
end;
$$;

-- Withdraw every claim of a key for a facility (e.g. stop showing emergency).
create or replace function public.vet_admin_withdraw_claim(p_facility uuid, p_key text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.vet_require_admin();
  update public.vet_facility_claims set status = 'withdrawn'
   where facility_id = p_facility and claim_key = p_key and status <> 'withdrawn';
  if not found then
    raise exception 'no claim % for facility %', p_key, p_facility using errcode = 'no_data_found';
  end if;
  perform public.vet_log_admin_action('withdraw_claim', 'facility', p_facility::text, p_note,
                                      jsonb_build_object('key', p_key));
end;
$$;

-- Link a facility to a Google place ID (moving the link if the place was
-- linked elsewhere), and settle the link candidates for that place.
create or replace function public.vet_admin_link_place(p_facility uuid, p_place_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_place text := btrim(coalesce(p_place_id, ''));
begin
  perform public.vet_require_admin();
  if v_place = '' or char_length(v_place) > 300 then
    raise exception 'place id required' using errcode = '22023';
  end if;
  if not exists (select 1 from public.vet_facilities where id = p_facility) then
    raise exception 'no facility %', p_facility using errcode = 'no_data_found';
  end if;
  insert into public.vet_facility_provider_ids (facility_id, provider, place_id, created_by)
  values (p_facility, 'google', v_place, auth.uid())
  on conflict (provider, place_id) do update
    set facility_id = excluded.facility_id, created_by = excluded.created_by, created_at = now();
  update public.vet_provider_link_candidates
     set status = case when facility_id = p_facility then 'linked' else 'rejected' end
   where provider = 'google' and place_id = v_place and status = 'open';
  update public.vet_review_items
     set status = 'resolved', resolved_at = now(), resolved_by = auth.uid(),
         resolution_note = 'linked to ' || p_facility::text
   where kind = 'link_candidate' and status = 'open' and details ->> 'placeId' = v_place;
  perform public.vet_log_admin_action('link_place', 'provider_link', v_place, null,
                                      jsonb_build_object('facility', p_facility));
end;
$$;

revoke execute on function
  public.vet_admin_review_items(),
  public.vet_admin_facilities(),
  public.vet_admin_resolve(uuid, text, text),
  public.vet_admin_set_status(uuid, text, text),
  public.vet_admin_set_claim(uuid, text, jsonb, text, text, text),
  public.vet_admin_withdraw_claim(uuid, text, text),
  public.vet_admin_link_place(uuid, text)
  from public, anon;
grant execute on function
  public.vet_admin_review_items(),
  public.vet_admin_facilities(),
  public.vet_admin_resolve(uuid, text, text),
  public.vet_admin_set_status(uuid, text, text),
  public.vet_admin_set_claim(uuid, text, jsonb, text, text, text),
  public.vet_admin_withdraw_claim(uuid, text, text),
  public.vet_admin_link_place(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Reporter RPCs (signed-in accounts listed in vet_intake_reporters)
-- ---------------------------------------------------------------------------

-- The facility's live intake status, valid for p_ttl_minutes (capped at 360).
create or replace function public.vet_report_intake(
  p_facility uuid, p_status text, p_species text[] default '{}', p_ttl_minutes integer default 120)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ttl integer := least(coalesce(p_ttl_minutes, 120), 360);
  v_now timestamptz := now();
  v_expires timestamptz;
begin
  if not exists (select 1 from public.vet_intake_reporters r
                 where r.facility_id = p_facility and r.user_id = auth.uid()) then
    raise exception 'not a reporter for this facility' using errcode = 'insufficient_privilege';
  end if;
  if p_status not in ('accepting', 'limited', 'diverting') then
    raise exception 'status must be accepting, limited or diverting' using errcode = '22023';
  end if;
  if v_ttl < 1 then
    raise exception 'ttl must be at least one minute' using errcode = '22023';
  end if;
  v_expires := v_now + make_interval(mins => v_ttl);
  insert into public.vet_intake_status (facility_id, status, species, updated_at, expires_at, reported_by)
  values (p_facility, p_status, coalesce(p_species, '{}'), v_now, v_expires, auth.uid())
  on conflict (facility_id) do update
    set status = excluded.status, species = excluded.species, updated_at = excluded.updated_at,
        expires_at = excluded.expires_at, reported_by = excluded.reported_by;
  return v_expires;
end;
$$;

-- A case-specific answer for one reference, valid for p_ttl_minutes (capped at 360).
create or replace function public.vet_confirm_case(
  p_facility uuid, p_reference text, p_accepted boolean, p_ttl_minutes integer default 120)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ttl integer := least(coalesce(p_ttl_minutes, 120), 360);
  v_ref text := btrim(coalesce(p_reference, ''));
  v_now timestamptz := now();
  v_id uuid;
begin
  if not exists (select 1 from public.vet_intake_reporters r
                 where r.facility_id = p_facility and r.user_id = auth.uid()) then
    raise exception 'not a reporter for this facility' using errcode = 'insufficient_privilege';
  end if;
  if char_length(v_ref) < 8 or char_length(v_ref) > 64 then
    raise exception 'reference must be 8-64 characters' using errcode = '22023';
  end if;
  if p_accepted is null then
    raise exception 'accepted is required' using errcode = '22023';
  end if;
  if v_ttl < 1 then
    raise exception 'ttl must be at least one minute' using errcode = '22023';
  end if;
  insert into public.vet_case_confirmations (facility_id, reference, accepted, confirmed_at, expires_at, confirmed_by)
  values (p_facility, v_ref, p_accepted, v_now, v_now + make_interval(mins => v_ttl), auth.uid())
  returning id into v_id;
  return v_id;
end;
$$;

-- The latest unexpired answer for a reference. Callable without sign-in:
-- the reference itself is the shared secret between user and facility.
create or replace function public.vet_case_status(p_reference text)
returns table (facility_id uuid, accepted boolean, confirmed_at timestamptz, expires_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select c.facility_id, c.accepted, c.confirmed_at, c.expires_at
  from public.vet_case_confirmations c
  where c.reference = btrim(coalesce(p_reference, ''))
    and char_length(btrim(coalesce(p_reference, ''))) >= 8
    and c.expires_at > now()
  order by c.confirmed_at desc
  limit 1;
$$;

revoke execute on function
  public.vet_report_intake(uuid, text, text[], integer),
  public.vet_confirm_case(uuid, text, boolean, integer)
  from public, anon;
grant execute on function
  public.vet_report_intake(uuid, text, text[], integer),
  public.vet_confirm_case(uuid, text, boolean, integer)
  to authenticated;
revoke execute on function public.vet_case_status(text) from public;
grant execute on function public.vet_case_status(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Service-role RPCs (Edge Functions only)
-- ---------------------------------------------------------------------------

-- Atomically counts one use of p_bucket and answers whether it was allowed:
--   p_bucket_limit  uses per window of p_window_minutes (null = no window limit)
--   p_global_limit  uses of this bucket per UTC day (null = no daily limit)
-- Both counters move together or not at all. Rows older than 2 days are
-- pruned on the way. Used for the per-client limit
-- ('client:<hash>', 30, 10, null) and the daily provider caps
-- ('provider:places', null, 1440, VET_DAILY_PROVIDER_CAP).
create or replace function public.vet_search_take(
  p_bucket text, p_bucket_limit integer, p_window_minutes integer, p_global_limit integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_day timestamptz := date_trunc('day', now() at time zone 'utc') at time zone 'utc';
  v_count integer;
begin
  if p_bucket is null or char_length(p_bucket) not between 1 and 128 then
    raise exception 'bucket required' using errcode = '22023';
  end if;
  if p_window_minutes is null or p_window_minutes not between 1 and 1440 then
    raise exception 'window must be 1-1440 minutes' using errcode = '22023';
  end if;

  delete from public.vet_search_quota where window_start < now() - interval '2 days';

  v_window := to_timestamp(floor(extract(epoch from now()) / (p_window_minutes * 60)) * (p_window_minutes * 60));

  if p_global_limit is not null then
    v_count := null;
    insert into public.vet_search_quota as q (bucket, window_start, count)
    values (p_bucket || '#day', v_day, 1)
    on conflict (bucket, window_start) do update set count = q.count + 1
      where q.count < p_global_limit
    returning q.count into v_count;
    if v_count is null or v_count > p_global_limit then
      return false;
    end if;
  end if;

  if p_bucket_limit is not null then
    v_count := null;
    insert into public.vet_search_quota as q (bucket, window_start, count)
    values (p_bucket, v_window, 1)
    on conflict (bucket, window_start) do update set count = q.count + 1
      where q.count < p_bucket_limit
    returning q.count into v_count;
    if v_count is null or v_count > p_bucket_limit then
      -- Give the daily unit back: this use did not happen.
      if p_global_limit is not null then
        update public.vet_search_quota set count = greatest(count - 1, 0)
         where bucket = p_bucket || '#day' and window_start = v_day;
      end if;
      return false;
    end if;
  end if;

  return true;
end;
$$;

-- Opens a review item, or refreshes the open one with the same dedupe key.
-- Returns true when a new item was opened.
create or replace function public.vet_upsert_review_item(
  p_facility uuid, p_kind text, p_severity text, p_details jsonb, p_dedupe_key text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted boolean;
begin
  insert into public.vet_review_items as i (facility_id, kind, severity, details, dedupe_key)
  values (p_facility, p_kind, p_severity, coalesce(p_details, '{}'::jsonb), p_dedupe_key)
  on conflict (dedupe_key) where status = 'open' do update
    set details = excluded.details, severity = excluded.severity
  returning (i.xmax = 0) into v_inserted;
  return coalesce(v_inserted, false);
end;
$$;

-- Records a heuristic match seen by a search (place ID only) and, while it
-- is open, keeps one 'link_candidate' review item for it.
create or replace function public.vet_record_link_candidate(
  p_facility uuid, p_place_id text, p_matched_on text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  insert into public.vet_provider_link_candidates as c (facility_id, provider, place_id, matched_on)
  values (p_facility, 'google', p_place_id, p_matched_on)
  on conflict (facility_id, provider, place_id) do update
    set last_seen_at = now(), seen_count = c.seen_count + 1, matched_on = excluded.matched_on
  returning c.status into v_status;
  -- Already linked by ID elsewhere? Then there is nothing to review.
  if v_status = 'open' and not exists (
       select 1 from public.vet_facility_provider_ids p
       where p.provider = 'google' and p.place_id = p_place_id) then
    perform public.vet_upsert_review_item(
      p_facility, 'link_candidate', 'low',
      jsonb_build_object('placeId', p_place_id, 'matchedOn', p_matched_on),
      'link_candidate:' || p_facility::text || ':' || p_place_id);
  end if;
end;
$$;

revoke execute on function
  public.vet_search_take(text, integer, integer, integer),
  public.vet_upsert_review_item(uuid, text, text, jsonb, text),
  public.vet_record_link_candidate(uuid, text, text)
  from public, anon, authenticated;
grant execute on function
  public.vet_search_take(text, integer, integer, integer),
  public.vet_upsert_review_item(uuid, text, text, jsonb, text),
  public.vet_record_link_candidate(uuid, text, text)
  to service_role;

commit;
