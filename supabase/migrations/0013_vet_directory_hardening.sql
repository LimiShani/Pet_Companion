-- PetLoop: Find a vet, security advisor clean-up. Run after 0012.
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query >
-- paste > Run). Safe to run more than once.
--
-- No behaviour changes: the app, the Edge Functions and every RPC keep
-- their names, arguments and results. What changes is WHERE the code that
-- runs with the owner's rights lives:
--
-- 1. Errors "Security Definer View" (vet_directory_public,
--    vet_intake_current). The two owner-rights views move to the schema
--    vet_private, which the Data API does not expose. In public, views of
--    the same names now run with the caller's rights (security_invoker)
--    and simply read the private ones. Anyone can still read exactly the
--    same rows and columns; the base tables stay closed.
--
-- 2. Warnings "SECURITY DEFINER function callable by signed-in users /
--    without signing in". The admin, reporter and case-status RPCs move to
--    vet_private unchanged (they still check the caller themselves: admins
--    only, reporters only). In public, thin wrappers with the same
--    signatures run with the caller's rights and call them, so the API
--    surface no longer exposes an owner-rights function directly.
--    vet_case_status stays callable without signing in on purpose: the
--    reference is the secret shared between the owner and the facility.
--
-- 3. Warnings from 0001: touch_updated_at gets a fixed search_path, and
--    handle_new_user (the sign-up trigger) can no longer be called as an
--    RPC. A trigger does not need EXECUTE to fire.
--
-- 4. Info "RLS enabled, no policy" on the service-role-only tables: an
--    explicit "nobody through the API" policy states the intent. The
--    service role bypasses RLS, so the Edge Functions are unaffected.

begin;

create schema if not exists vet_private;
comment on schema vet_private is
  'Find a vet: owner-rights views and functions. Not exposed by the Data API; reached only through public wrappers.';
revoke all on schema vet_private from public;
grant usage on schema vet_private to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1. The two public views
-- ---------------------------------------------------------------------------

do $$
begin
  -- Move the owner-rights views once; on a rerun they are already private.
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'vet_directory_public' and c.relkind = 'v'
      and coalesce(c.reloptions, '{}') @> array['security_invoker=false']
  ) then
    alter view public.vet_directory_public set schema vet_private;
  end if;
  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'vet_intake_current' and c.relkind = 'v'
      and coalesce(c.reloptions, '{}') @> array['security_invoker=false']
  ) then
    alter view public.vet_intake_current set schema vet_private;
  end if;
end;
$$;

revoke all on vet_private.vet_directory_public, vet_private.vet_intake_current from public, anon, authenticated;
grant select on vet_private.vet_directory_public, vet_private.vet_intake_current
  to anon, authenticated, service_role;

create or replace view public.vet_directory_public
with (security_invoker = true) as
select * from vet_private.vet_directory_public;

comment on view public.vet_directory_public is
  'Find a vet: shown facilities with their emergency claim summary and sourced facts. Readable by anyone.';

create or replace view public.vet_intake_current
with (security_invoker = true) as
select * from vet_private.vet_intake_current;

comment on view public.vet_intake_current is
  'Find a vet: unexpired intake status of shown facilities. Readable by anyone.';

revoke all on public.vet_directory_public, public.vet_intake_current from public, anon, authenticated;
grant select on public.vet_directory_public, public.vet_intake_current to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Owner-rights RPCs behind caller-rights wrappers
-- ---------------------------------------------------------------------------

do $$
declare
  fn text;
begin
  -- Each function moves once: only while public still holds the
  -- owner-rights version (a rerun finds the wrapper there instead).
  foreach fn in array array[
    'vet_is_admin()',
    'vet_admin_review_items()',
    'vet_admin_facilities()',
    'vet_admin_resolve(uuid, text, text)',
    'vet_admin_set_status(uuid, text, text)',
    'vet_admin_set_claim(uuid, text, jsonb, text, text, text)',
    'vet_admin_withdraw_claim(uuid, text, text)',
    'vet_admin_link_place(uuid, text)',
    'vet_report_intake(uuid, text, text[], integer)',
    'vet_confirm_case(uuid, text, boolean, integer)',
    'vet_case_status(text)'
  ] loop
    if exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure('public.' || fn) and p.prosecdef
    ) then
      execute format('alter function public.%s set schema vet_private', fn);
    end if;
  end loop;
end;
$$;

-- The private functions keep their own grants; nobody else may call them.
revoke execute on all functions in schema vet_private from public, anon;
grant execute on function
  vet_private.vet_is_admin(),
  vet_private.vet_admin_review_items(),
  vet_private.vet_admin_facilities(),
  vet_private.vet_admin_resolve(uuid, text, text),
  vet_private.vet_admin_set_status(uuid, text, text),
  vet_private.vet_admin_set_claim(uuid, text, jsonb, text, text, text),
  vet_private.vet_admin_withdraw_claim(uuid, text, text),
  vet_private.vet_admin_link_place(uuid, text),
  vet_private.vet_report_intake(uuid, text, text[], integer),
  vet_private.vet_confirm_case(uuid, text, boolean, integer),
  vet_private.vet_case_status(text)
  to authenticated, service_role;
grant execute on function vet_private.vet_case_status(text) to anon;

-- The wrappers: same names, arguments, defaults and results as in 0012.

create or replace function public.vet_is_admin()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select vet_private.vet_is_admin() $$;

create or replace function public.vet_admin_review_items()
returns table (
  id uuid, facility_id uuid, facility_name text, kind text, severity text,
  details jsonb, status text, created_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$ select * from vet_private.vet_admin_review_items() $$;

create or replace function public.vet_admin_facilities()
returns table (
  id uuid, name text, name_he text, address text, city text, phone text, website text,
  facility_type text, review_status text, last_checked_at timestamptz, last_confirmed_at timestamptz,
  claims jsonb, country_code text)
language sql
stable
security invoker
set search_path = ''
as $$ select * from vet_private.vet_admin_facilities() $$;

create or replace function public.vet_admin_resolve(p_item uuid, p_action text, p_note text default null)
returns void
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_admin_resolve(p_item, p_action, p_note) $$;

create or replace function public.vet_admin_set_status(p_facility uuid, p_status text, p_note text default null)
returns void
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_admin_set_status(p_facility, p_status, p_note) $$;

create or replace function public.vet_admin_set_claim(
  p_facility uuid, p_key text, p_value jsonb, p_source_url text, p_source_kind text, p_note text default null)
returns uuid
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_admin_set_claim(p_facility, p_key, p_value, p_source_url, p_source_kind, p_note) $$;

create or replace function public.vet_admin_withdraw_claim(p_facility uuid, p_key text, p_note text default null)
returns void
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_admin_withdraw_claim(p_facility, p_key, p_note) $$;

create or replace function public.vet_admin_link_place(p_facility uuid, p_place_id text)
returns void
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_admin_link_place(p_facility, p_place_id) $$;

create or replace function public.vet_report_intake(
  p_facility uuid, p_status text, p_species text[] default '{}', p_ttl_minutes integer default 120)
returns timestamptz
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_report_intake(p_facility, p_status, p_species, p_ttl_minutes) $$;

create or replace function public.vet_confirm_case(
  p_facility uuid, p_reference text, p_accepted boolean, p_ttl_minutes integer default 120)
returns uuid
language sql
security invoker
set search_path = ''
as $$ select vet_private.vet_confirm_case(p_facility, p_reference, p_accepted, p_ttl_minutes) $$;

create or replace function public.vet_case_status(p_reference text)
returns table (facility_id uuid, accepted boolean, confirmed_at timestamptz, expires_at timestamptz)
language sql
stable
security invoker
set search_path = ''
as $$ select * from vet_private.vet_case_status(p_reference) $$;

revoke execute on function
  public.vet_is_admin(),
  public.vet_admin_review_items(),
  public.vet_admin_facilities(),
  public.vet_admin_resolve(uuid, text, text),
  public.vet_admin_set_status(uuid, text, text),
  public.vet_admin_set_claim(uuid, text, jsonb, text, text, text),
  public.vet_admin_withdraw_claim(uuid, text, text),
  public.vet_admin_link_place(uuid, text),
  public.vet_report_intake(uuid, text, text[], integer),
  public.vet_confirm_case(uuid, text, boolean, integer),
  public.vet_case_status(text)
  from public, anon;
grant execute on function
  public.vet_is_admin(),
  public.vet_admin_review_items(),
  public.vet_admin_facilities(),
  public.vet_admin_resolve(uuid, text, text),
  public.vet_admin_set_status(uuid, text, text),
  public.vet_admin_set_claim(uuid, text, jsonb, text, text, text),
  public.vet_admin_withdraw_claim(uuid, text, text),
  public.vet_admin_link_place(uuid, text),
  public.vet_report_intake(uuid, text, text[], integer),
  public.vet_confirm_case(uuid, text, boolean, integer),
  public.vet_case_status(text)
  to authenticated, service_role;
grant execute on function public.vet_case_status(text) to anon;

-- ---------------------------------------------------------------------------
-- 3. Older warnings (0001)
-- ---------------------------------------------------------------------------

alter function public.touch_updated_at() set search_path = '';
revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Service-role-only tables: say so explicitly
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'vet_facilities', 'vet_facility_provider_ids', 'vet_provider_link_candidates',
    'vet_facility_claims', 'vet_intake_status', 'vet_case_confirmations',
    'vet_review_items', 'vet_admin_actions', 'vet_job_runs', 'vet_search_quota'
  ] loop
    execute format('drop policy if exists "%s: no direct API access" on public.%I', t, t);
    execute format(
      'create policy "%s: no direct API access" on public.%I for all to anon, authenticated using (false) with check (false)',
      t, t);
  end loop;
end;
$$;

commit;
