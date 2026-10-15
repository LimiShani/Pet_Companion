-- PetLoop: usage counts (improvement plan, phase 1c). Apply after 0030.
-- What is counted and how to read it: docs/usage_counts.md.
--
--   * usage_counts: one row per account, day and kind of action (a care log
--     recorded, a deal opened, ...) with how many times it happened. No
--     device ids, no screens, no text, no pet: only the fixed kinds below.
--   * usage_add(p_day, p_counts): the app adds one day's counts for the
--     signed-in account, once a day. Only the kinds below, only a day
--     between two days ago and tomorrow (the phone's day, whatever its time
--     zone), counts added and capped at 500 a row, at most 30 calls an
--     account a day.
--   * Members cannot read, insert, change or delete rows through the API,
--     not even their own; usage_add is the only way in.
--   * usage_summary(p_days): permission administrators (access.admin) read
--     the daily totals: active accounts, accounts and total per kind, and
--     the share of active accounts that ticked a Today row.
--   * usage_private.housekeeping(): deletes rows older than 400 days (and
--     the call counters after a week). Schedule it once with
--     supabase/scheduling/usage_housekeeping.sql.
--   * Deleting an account deletes its rows (foreign keys, on delete cascade).
--
-- A new kind is added here first (the check and usage_private.kinds()),
-- then in the app: the app's calls carrying an unknown kind are refused.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regprocedure('access_private.require_admin()') is null then
    raise exception 'Run 0014_feature_access.sql first.';
  end if;
end
$$;

create schema if not exists usage_private;
revoke all on schema usage_private from public;
grant usage on schema usage_private to authenticated, service_role;

-- The kinds of action counted. Keep in step with the check below and with
-- UsageKind in lib/platform/usage.dart.
create or replace function usage_private.kinds()
returns text[] language sql immutable set search_path = '' as $$
  select array[
    'today_tick', 'care_logged', 'dose_recorded', 'record_added', 'quick_log',
    'meetup_joined', 'meetup_posted', 'post_created', 'comment_created',
    'chat_message_sent', 'deal_opened', 'deal_shared', 'basket_bought_again',
    'expense_added', 'emergency_opened', 'find_vet_opened',
    'household_invite_sent', 'app_opened'
  ]::text[]
$$;
revoke all on function usage_private.kinds() from public, anon, authenticated;

create table if not exists public.usage_counts (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  kind text not null check (kind in (
    'today_tick', 'care_logged', 'dose_recorded', 'record_added', 'quick_log',
    'meetup_joined', 'meetup_posted', 'post_created', 'comment_created',
    'chat_message_sent', 'deal_opened', 'deal_shared', 'basket_bought_again',
    'expense_added', 'emergency_opened', 'find_vet_opened',
    'household_invite_sent', 'app_opened'
  )),
  count integer not null check (count between 1 and 500),
  primary key (user_id, day, kind)
);

-- The summary and the housekeeping read by day.
create index if not exists usage_counts_day_idx on public.usage_counts (day);

-- How many times each account called usage_add on a (server) day.
create table if not exists usage_private.calls (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  calls integer not null default 0,
  primary key (user_id, day)
);
create index if not exists usage_calls_day_idx on usage_private.calls (day);

-- ---------------------------------------------------------------------------
-- Who may do what: nobody through the API. The functions below run as the
-- owner and are the only way in or out.
-- ---------------------------------------------------------------------------
alter table public.usage_counts enable row level security;
revoke all on table public.usage_counts from public, anon, authenticated;

drop policy if exists usage_counts_no_direct_access on public.usage_counts;
create policy usage_counts_no_direct_access on public.usage_counts
  as restrictive for all to anon, authenticated
  using (false) with check (false);

alter table usage_private.calls enable row level security;
revoke all on table usage_private.calls from public, anon, authenticated;

drop policy if exists usage_calls_no_direct_access on usage_private.calls;
create policy usage_calls_no_direct_access on usage_private.calls
  as restrictive for all to anon, authenticated
  using (false) with check (false);

-- ---------------------------------------------------------------------------
-- The app adds one day's counts: {"care_logged": 3, "app_opened": 1}.
-- Returns how many kinds were stored.
-- ---------------------------------------------------------------------------
create or replace function usage_private.add(p_day date, p_counts jsonb)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  entry record;
  amount integer;
  used integer;
  stored integer := 0;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if p_day is null or p_day not between current_date - 2 and current_date + 1 then
    raise exception 'Day out of range' using errcode = '22023';
  end if;
  if p_counts is null or jsonb_typeof(p_counts) <> 'object' or p_counts = '{}'::jsonb then
    raise exception 'Counts must be a non-empty object' using errcode = '22023';
  end if;
  for entry in select key, value from jsonb_each(p_counts) loop
    if not (entry.key = any (usage_private.kinds())) then
      raise exception 'Unknown kind: %', left(entry.key, 40) using errcode = '22023';
    end if;
    if jsonb_typeof(entry.value) <> 'number'
       or (entry.value #>> '{}')::numeric <> trunc((entry.value #>> '{}')::numeric)
       or (entry.value #>> '{}')::numeric < 1 then
      raise exception 'Counts must be whole numbers from 1' using errcode = '22023';
    end if;
  end loop;

  -- The rate limit: 30 calls an account a day.
  insert into usage_private.calls as c (user_id, day, calls)
  values (me, current_date, 1)
  on conflict (user_id, day) do update set calls = c.calls + 1
  returning c.calls into used;
  if used > 30 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;

  for entry in select key, value from jsonb_each(p_counts) loop
    amount := least((entry.value #>> '{}')::numeric, 500)::integer;
    insert into public.usage_counts as u (user_id, day, kind, count)
    values (me, p_day, entry.key, amount)
    on conflict (user_id, day, kind) do update set count = least(u.count + excluded.count, 500);
    stored := stored + 1;
  end loop;
  return stored;
end $$;
revoke all on function usage_private.add(date, jsonb) from public, anon;
grant execute on function usage_private.add(date, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- The administrators' summary of the last p_days days (1 to 400), newest
-- first, one element a day (days without any count included):
--   {"day": "2026-10-15", "active": 12, "today_tick_share": 0.42,
--    "kinds": {"care_logged": {"accounts": 8, "total": 30}, ...}}
-- ---------------------------------------------------------------------------
create or replace function usage_private.summary(p_days integer default 28)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  days integer := coalesce(p_days, 28);
begin
  perform access_private.require_admin();
  if days not between 1 and 400 then
    raise exception 'Between 1 and 400 days' using errcode = '22023';
  end if;
  return coalesce((
    select jsonb_agg(
             jsonb_build_object(
               'day', d.day,
               'active', coalesce(a.active, 0),
               'today_tick_share', case when coalesce(a.active, 0) = 0 then 0
                                        else round(coalesce(t.accounts, 0)::numeric / a.active, 4) end,
               'kinds', coalesce(k.kinds, '{}'::jsonb))
             order by d.day desc)
    from (select (current_date - n)::date as day from generate_series(0, days - 1) as n) d
    left join (select u.day, count(distinct u.user_id) as active
               from public.usage_counts u
               where u.day > current_date - days
               group by u.day) a on a.day = d.day
    left join (select u.day, count(*) as accounts
               from public.usage_counts u
               where u.day > current_date - days and u.kind = 'today_tick'
               group by u.day) t on t.day = d.day
    left join (select x.day, jsonb_object_agg(x.kind, jsonb_build_object('accounts', x.accounts, 'total', x.total)) as kinds
               from (select u.day, u.kind, count(*) as accounts, sum(u.count) as total
                     from public.usage_counts u
                     where u.day > current_date - days
                     group by u.day, u.kind) x
               group by x.day) k on k.day = d.day
  ), '[]'::jsonb);
end $$;
revoke all on function usage_private.summary(integer) from public, anon;
grant execute on function usage_private.summary(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- Housekeeping (pg_cron, or the SQL editor). Returns how many rows went.
-- ---------------------------------------------------------------------------
create or replace function usage_private.housekeeping()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  removed integer;
begin
  delete from public.usage_counts where day < current_date - 400;
  get diagnostics removed = row_count;
  delete from usage_private.calls where day < current_date - 7;
  return removed;
end $$;
revoke all on function usage_private.housekeeping() from public, anon, authenticated;
grant execute on function usage_private.housekeeping() to service_role;

-- ---------------------------------------------------------------------------
-- Public wrappers (the app calls these through the API).
-- ---------------------------------------------------------------------------
create or replace function public.usage_add(p_day date, p_counts jsonb)
returns integer language sql security invoker set search_path = '' as $$
  select usage_private.add(p_day, p_counts) $$;
create or replace function public.usage_summary(p_days integer default 28)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select usage_private.summary(p_days) $$;
revoke all on function public.usage_add(date, jsonb), public.usage_summary(integer) from public, anon;
grant execute on function public.usage_add(date, jsonb), public.usage_summary(integer) to authenticated;

commit;
