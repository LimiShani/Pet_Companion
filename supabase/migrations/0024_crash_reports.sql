-- PetLoop: crash reports from the app. Apply after 0023.
--
--   * crash_reports: one row per error the app did not handle (a Flutter
--     framework error, an uncaught Dart error, or one a feature reported),
--     with the app version, the phone's system and what the app was doing.
--     The app writes rows as the signed-in account or as nobody; only
--     permission administrators (access.admin) read them; nobody updates
--     or deletes them through the API;
--   * a rate limit: at most 60 rows an hour per account and 300 an hour
--     from signed-out apps. Rows over the limit are dropped quietly, so a
--     crash loop or a stranger with the publishable key cannot fill the
--     free plan;
--   * crash_reports_prune(days): an administrator deletes rows older than
--     the given number of days (at least 7).
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regprocedure('public.can_use(text)') is null then
    raise exception 'Run 0014_feature_access.sql first.';
  end if;
end
$$;

create table if not exists public.crash_reports (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  session_id text not null check (char_length(session_id) between 1 and 64),
  occurred_at timestamptz not null,
  kind text not null check (kind in ('flutter', 'dart', 'caught')),
  fatal boolean not null default false,
  message text not null check (char_length(message) between 1 and 2000),
  stack text check (char_length(stack) <= 8000),
  context text check (char_length(context) <= 500),
  app_version text not null check (char_length(app_version) between 1 and 40),
  build_number text not null check (char_length(build_number) <= 20),
  platform text not null check (char_length(platform) between 1 and 20),
  os_version text check (char_length(os_version) <= 200),
  locale text check (char_length(locale) <= 20),
  created_at timestamptz not null default now()
);

create index if not exists crash_reports_created_at_idx
  on public.crash_reports (created_at desc);
create index if not exists crash_reports_user_created_idx
  on public.crash_reports (user_id, created_at);

-- ---------------------------------------------------------------------------
-- Who may do what. Writes: own rows or ownerless rows. Reads: permission
-- administrators. Changes and deletions: nobody through the API.
-- ---------------------------------------------------------------------------
alter table public.crash_reports enable row level security;
revoke all on table public.crash_reports from public, anon, authenticated;
grant insert on table public.crash_reports to anon, authenticated;
grant select on table public.crash_reports to authenticated;
grant usage on sequence public.crash_reports_id_seq to anon, authenticated;

drop policy if exists crash_reports_insert_own on public.crash_reports;
create policy crash_reports_insert_own on public.crash_reports
  for insert to authenticated
  with check (user_id = auth.uid() or user_id is null);

drop policy if exists crash_reports_insert_anonymous on public.crash_reports;
create policy crash_reports_insert_anonymous on public.crash_reports
  for insert to anon
  with check (user_id is null);

drop policy if exists crash_reports_admin_read on public.crash_reports;
create policy crash_reports_admin_read on public.crash_reports
  for select to authenticated
  using ((select public.can_use('access.admin')));

-- ---------------------------------------------------------------------------
-- The rate limit. Runs as the owner so it counts rows the writer may not
-- read; a row over the limit is skipped, not an error, so the app does not
-- keep retrying it.
-- ---------------------------------------------------------------------------
create or replace function public.crash_reports_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent integer;
begin
  if new.user_id is not null then
    select count(*) into recent from public.crash_reports
      where user_id = new.user_id and created_at > now() - interval '1 hour';
    if recent >= 60 then return null; end if;
  else
    select count(*) into recent from public.crash_reports
      where user_id is null and created_at > now() - interval '1 hour';
    if recent >= 300 then return null; end if;
  end if;
  return new;
end
$$;
revoke all on function public.crash_reports_rate_limit() from public;

drop trigger if exists crash_reports_rate_limit on public.crash_reports;
create trigger crash_reports_rate_limit
  before insert on public.crash_reports
  for each row execute function public.crash_reports_rate_limit();

-- ---------------------------------------------------------------------------
-- Housekeeping: an administrator deletes old rows. Returns how many went.
-- ---------------------------------------------------------------------------
create or replace function public.crash_reports_prune(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  removed integer;
begin
  if not public.can_use('access.admin') then
    raise exception 'Permission administrators only'
      using errcode = 'insufficient_privilege';
  end if;
  delete from public.crash_reports
    where created_at < now() - make_interval(days => greatest(coalesce(p_days, 90), 7));
  get diagnostics removed = row_count;
  return removed;
end
$$;
revoke all on function public.crash_reports_prune(integer) from public, anon;
grant execute on function public.crash_reports_prune(integer) to authenticated;

commit;
