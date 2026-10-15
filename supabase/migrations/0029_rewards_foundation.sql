-- PetLoop: rewards foundation (gamification Phase 0) and community
-- hardening. Apply after 0028. Design and threat model: docs/gamification.md.
--
-- Hardening (fixes found in the 13 October 2026 security review):
--   * Server time. Members can no longer choose created_at on posts,
--     comments, messages, reports, likes, reactions, health records and
--     park suggestions, nor posted_at on deals (a post dated 2099 stayed on
--     top of the feed, a deal likewise; a
--     backdated row escaped the rate limits; a pre-dated report re-hid an
--     item a moderator had kept). care_logs gets server_logged_at, which
--     the app cannot set; rewards count from it.
--   * Bulk inserts. A request carrying an array of rows is one statement,
--     and the per-row rate limit could not see the other rows in it. A
--     statement-level check now enforces the same limits, and caps care
--     logs at 500 an hour per account.
--   * Auto-hide. A report counts toward the three that hide an item only
--     when the reporter's account is at least 3 days old (or the reporter
--     moderates). Newer accounts' reports still reach the moderators'
--     queue. Moderators can see the age of the reporting accounts
--     (community_report_reporters), never who they are.
--
-- Rewards foundation (no screens yet; nothing here limits anyone today):
--   * Feature 'rewards' with rewards.view, rewards.mark_helped,
--     rewards.claim_coupons and rewards.report_purchase for everyone
--     (Standard owners).
--   * Capabilities that community standing will unlock later:
--     community.chat.rooms_create, community.parks.suggest_direct,
--     store.deals.share_extra. No code uses them yet. Groups "Standing:
--     Regular / Helper / Guide" hold them, maintained only by the rollup.
--   * Group "Beta testers": every capability except the roles (permission
--     admin, directory admin, moderator, park reviewer), including any
--     capability added later. Every account joins it while
--     rewards_private.settings.beta_auto_join is true (backfilled now).
--   * Pet layer: milestone_catalog, pet_milestones (sticky), care_rhythm.
--   * Community layer: helped_marks ("This helped", by the asker only),
--     member_standing (Member / Regular / Helper / Guide), shown to others
--     only as the level (community_standing()).
--   * Shopper layer: partners, coupon_offers, coupon_claims (unique random
--     codes), purchase_events, shopper_standing (Shopper / Regular shopper /
--     Trusted shopper), early access on store_deals.early_until, partner
--     redemptions by an administrator's batch or a signed postback (service
--     role only), an append-only audit of partners and offers.
--   * The rollup (rewards_private.rollup_step) runs in short, resumable
--     batches under an advisory lock; schedule it with
--     supabase/scheduling/rewards_rollup.sql.
--
-- Anti-abuse rules, all on the server: standing and coupons need a
-- "trusted" account (14 days old, confirmed email, a pet with a done care
-- log); helped marks count once per asker per 30 days, from trusted askers,
-- minus reciprocal rings; an upheld moderator removal caps standing at
-- Member for 90 days, a report never does; care logs count only when
-- logged within 7 days of their date, at most 6 walks and 8 meals a day.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.community_meetups') is null or to_regclass('public.access_capabilities') is null then
    raise exception 'Run 0014_feature_access.sql and 0028_meetups.sql first.';
  end if;
end
$$;

create schema if not exists rewards_private;
revoke all on schema rewards_private from public;
grant usage on schema rewards_private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Settings (owner-tunable from the SQL editor).
-- ---------------------------------------------------------------------------
create table if not exists rewards_private.settings (
  singleton boolean primary key default true check (singleton),
  beta_auto_join boolean not null default true,
  trusted_account_age interval not null default interval '14 days',
  reporter_account_age interval not null default interval '3 days'
);
insert into rewards_private.settings(singleton) values (true) on conflict do nothing;
alter table rewards_private.settings enable row level security;
revoke all on rewards_private.settings from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Account checks.
-- ---------------------------------------------------------------------------
create or replace function rewards_private.account_established(p_user uuid, p_age interval)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from auth.users u where u.id = p_user and u.created_at <= now() - p_age)
$$;
revoke all on function rewards_private.account_established(uuid, interval) from public, anon, authenticated;

-- Old enough, a confirmed email, and a pet with at least one done care log.
create or replace function rewards_private.account_trusted(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u, rewards_private.settings s
    where u.id = p_user and u.created_at <= now() - s.trusted_account_age and u.email_confirmed_at is not null
  ) and exists (
    select 1 from public.care_logs l where l.owner_id = p_user and l.status = 'done'
  )
$$;
revoke all on function rewards_private.account_trusted(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Hardening 1: server time on member-written rows.
-- Security invoker on purpose: current_user is the caller's role, so rows
-- written by the server's own functions (postgres) keep their values.
-- ---------------------------------------------------------------------------
create or replace function rewards_private.server_created_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.created_at := now();
    else
      new.created_at := old.created_at;
    end if;
  end if;
  return new;
end $$;
revoke all on function rewards_private.server_created_at() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array[
    'community_posts', 'community_comments', 'chat_messages', 'community_reports',
    'community_comment_reports', 'chat_message_reports', 'community_meetup_reports',
    'community_post_likes', 'chat_message_reactions', 'store_deals', 'store_reports',
    'health_events', 'health_observations', 'dog_park_suggestions'
  ] loop
    if exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = t and column_name = 'created_at') then
      execute format('drop trigger if exists server_created_at on public.%I', t);
      execute format('create trigger server_created_at before insert or update on public.%I '
                     'for each row execute function rewards_private.server_created_at()', t);
      -- Rows already dated in the future come back to now.
      execute format('update public.%I set created_at = now() where created_at > now() + interval ''1 minute''', t);
    end if;
  end loop;
end
$$;

-- store_deals carries posted_at (newest first in the Store) instead.
create or replace function rewards_private.server_posted_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.posted_at := now();
    else
      new.posted_at := old.posted_at;
    end if;
  end if;
  return new;
end $$;
revoke all on function rewards_private.server_posted_at() from public, anon, authenticated;
drop trigger if exists server_posted_at on public.store_deals;
create trigger server_posted_at before insert or update on public.store_deals
  for each row execute function rewards_private.server_posted_at();
update public.store_deals set posted_at = now() where posted_at > now() + interval '1 minute';

-- care_logs: server_logged_at is when the server received the log.
alter table public.care_logs add column if not exists server_logged_at timestamptz;
update public.care_logs set server_logged_at = least(logged_at, now()) where server_logged_at is null;
alter table public.care_logs alter column server_logged_at set default now();
alter table public.care_logs alter column server_logged_at set not null;
create index if not exists care_logs_owner_server_logged_idx on public.care_logs (owner_id, server_logged_at);
comment on column public.care_logs.server_logged_at is
  'When the server received the log. Set by the server; rewards count from it.';

create or replace function rewards_private.care_log_server_time()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    if tg_op = 'INSERT' then
      new.server_logged_at := now();
    else
      new.server_logged_at := old.server_logged_at;
    end if;
  end if;
  return new;
end $$;
revoke all on function rewards_private.care_log_server_time() from public, anon, authenticated;
drop trigger if exists care_log_server_time on public.care_logs;
create trigger care_log_server_time before insert or update on public.care_logs
  for each row execute function rewards_private.care_log_server_time();

-- ---------------------------------------------------------------------------
-- Hardening 2: rate limits that also hold for one request with many rows.
-- After the statement every inserted row is visible, so the count is exact.
-- ---------------------------------------------------------------------------
create or replace function community_private.rate_limit_statement()
returns trigger language plpgsql security definer set search_path = '' as $$
declare over_limit boolean;
begin
  if tg_table_name = 'community_posts' then
    select exists (
      select 1 from (select distinct author_id from new_rows) n
      where (select count(*) from public.community_posts p
             where p.author_id = n.author_id and p.created_at > clock_timestamp() - interval '10 minutes') > 6
    ) into over_limit;
  elsif tg_table_name = 'community_comments' then
    select exists (
      select 1 from (select distinct author_id from new_rows) n
      where (select count(*) from public.community_comments c
             where c.author_id = n.author_id and c.created_at > clock_timestamp() - interval '5 minutes') > 20
    ) into over_limit;
  elsif tg_table_name = 'chat_messages' then
    select exists (
      select 1 from (select distinct author_id from new_rows where system is null) n
      where (select count(*) from public.chat_messages m
             where m.author_id = n.author_id and m.system is null
               and m.created_at > clock_timestamp() - interval '1 minute') > 15
    ) into over_limit;
  else
    select exists (
      select 1 from (select distinct owner_id from new_rows) n
      where (select count(*) from public.care_logs l
             where l.owner_id = n.owner_id and l.server_logged_at > clock_timestamp() - interval '1 hour') > 500
    ) into over_limit;
  end if;
  if over_limit then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  return null;
end $$;
revoke all on function community_private.rate_limit_statement() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['community_posts', 'community_comments', 'chat_messages', 'care_logs'] loop
    execute format('drop trigger if exists rate_limit_statement on public.%I', t);
    execute format('create trigger rate_limit_statement after insert on public.%I '
                   'referencing new table as new_rows for each statement '
                   'execute function community_private.rate_limit_statement()', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Hardening 3: a report hides only with established reporters.
-- ---------------------------------------------------------------------------
create or replace function community_private.report_counts(p_reporter uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u, rewards_private.settings s
    where u.id = p_reporter and u.created_at <= now() - s.reporter_account_age
  ) or access_private.evaluate(p_reporter, 'community.moderate')
$$;
revoke all on function community_private.report_counts(uuid) from public, anon, authenticated;

create or replace function community_private.hide_when_reported()
returns trigger language plpgsql security definer set search_path = '' as $$
declare reports integer;
begin
  if tg_table_name = 'community_reports' then
    select count(*) into reports from public.community_reports r join public.community_posts p on p.id = r.post_id
     where r.post_id = new.post_id and r.created_at > coalesce(p.moderated_at, '-infinity')
       and community_private.report_counts(r.reporter_id);
    if reports >= 3 then update public.community_posts set hidden_at = coalesce(hidden_at, now()) where id = new.post_id; end if;
  elsif tg_table_name = 'community_comment_reports' then
    select count(*) into reports from public.community_comment_reports r join public.community_comments c on c.id = r.comment_id
     where r.comment_id = new.comment_id and r.created_at > coalesce(c.moderated_at, '-infinity')
       and community_private.report_counts(r.reporter_id);
    if reports >= 3 then update public.community_comments set hidden_at = coalesce(hidden_at, now()) where id = new.comment_id; end if;
  else
    select count(*) into reports from public.chat_message_reports r join public.chat_messages m on m.id = r.message_id
     where r.message_id = new.message_id and r.created_at > coalesce(m.moderated_at, '-infinity')
       and community_private.report_counts(r.reporter_id);
    if reports >= 3 then update public.chat_messages set hidden_at = coalesce(hidden_at, now()) where id = new.message_id; end if;
  end if;
  return null;
end $$;
revoke all on function community_private.hide_when_reported() from public, anon, authenticated;

create or replace function community_private.hide_reported_meetup()
returns trigger language plpgsql security definer set search_path = '' as $$
declare reports integer;
begin
  select count(*) into reports from public.community_meetup_reports r
  join public.community_meetups m on m.id = r.meetup_id
  where r.meetup_id = new.meetup_id and r.created_at > coalesce(m.moderated_at, '-infinity')
    and community_private.report_counts(r.reporter_id);
  if reports >= 3 then
    update public.community_meetups set hidden_at = coalesce(hidden_at, now()) where id = new.meetup_id;
  end if;
  return null;
end $$;
revoke all on function community_private.hide_reported_meetup() from public, anon, authenticated;

-- For moderators: how old the reporting accounts are, and whether each
-- report counted toward hiding. Never who reported.
create or replace function community_private.report_reporters(p_kind text, p_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform community_private.require_moderator();
  if p_kind not in ('post', 'comment', 'message', 'meetup') then
    raise exception 'Unknown kind' using errcode = '22023';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'account_age_days', floor(extract(epoch from now() - u.created_at) / 86400)::integer,
      'counts', community_private.report_counts(r.reporter_id),
      'reason', r.reason, 'reported_at', r.created_at) order by r.created_at)
    from (
      select reporter_id, reason, created_at from public.community_reports where p_kind = 'post' and post_id = p_id
      union all
      select reporter_id, reason, created_at from public.community_comment_reports where p_kind = 'comment' and comment_id = p_id
      union all
      select reporter_id, reason, created_at from public.chat_message_reports where p_kind = 'message' and message_id = p_id
      union all
      select reporter_id, reason, created_at from public.community_meetup_reports where p_kind = 'meetup' and meetup_id = p_id
    ) r join auth.users u on u.id = r.reporter_id
  ), '[]'::jsonb);
end $$;
revoke all on function community_private.report_reporters(text, uuid) from public, anon;
grant execute on function community_private.report_reporters(text, uuid) to authenticated;
create or replace function public.community_report_reporters(p_kind text, p_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select community_private.report_reporters(p_kind, p_id)
$$;
revoke all on function public.community_report_reporters(text, uuid) from public, anon;
grant execute on function public.community_report_reporters(text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Feature, capabilities, groups.
-- ---------------------------------------------------------------------------
insert into public.feature_catalog(id) values ('rewards') on conflict (id) do nothing;
insert into public.access_capabilities(id, feature_id, requires_view) values
  ('rewards.view', 'rewards', null),
  ('rewards.mark_helped', 'rewards', 'rewards.view'),
  ('rewards.claim_coupons', 'rewards', 'rewards.view'),
  ('rewards.report_purchase', 'rewards', 'rewards.view'),
  ('community.chat.rooms_create', 'community', 'community.chat.view'),
  ('community.parks.suggest_direct', 'community', 'community.parks.view'),
  ('store.deals.share_extra', 'store', 'store.deals.view')
on conflict (id) do nothing;

-- Everyone takes part in rewards.
insert into public.group_capability_rules(group_id, capability, allowed)
select 'acc35500-0000-4000-8000-000000000001', c, true
from unnest(array['rewards.view', 'rewards.mark_helped', 'rewards.claim_coupons', 'rewards.report_purchase']) c
on conflict do nothing;

insert into public.access_groups(id, name) values
  ('acc35500-0000-4000-8000-000000000002', 'Beta testers'),
  ('acc35500-0000-4000-8000-000000000003', 'Standing: Regular'),
  ('acc35500-0000-4000-8000-000000000004', 'Standing: Helper'),
  ('acc35500-0000-4000-8000-000000000005', 'Standing: Guide')
on conflict (id) do nothing;

-- Roles are given to people, never by a group of everyone.
create or replace function rewards_private.capability_is_role(p_capability text)
returns boolean language sql immutable set search_path = '' as $$
  select p_capability in ('access.admin', 'findvet.admin', 'community.moderate', 'community.parks.review')
$$;

insert into public.group_capability_rules(group_id, capability, allowed)
select 'acc35500-0000-4000-8000-000000000002', id, true from public.access_capabilities
where not rewards_private.capability_is_role(id)
on conflict do nothing;

-- Standing unlocks, cumulative per level.
insert into public.group_capability_rules(group_id, capability, allowed)
select g, c, true from (values
  ('acc35500-0000-4000-8000-000000000003'::uuid, 'community.chat.rooms_create'),
  ('acc35500-0000-4000-8000-000000000004'::uuid, 'community.chat.rooms_create'),
  ('acc35500-0000-4000-8000-000000000004'::uuid, 'community.parks.suggest_direct'),
  ('acc35500-0000-4000-8000-000000000005'::uuid, 'community.chat.rooms_create'),
  ('acc35500-0000-4000-8000-000000000005'::uuid, 'community.parks.suggest_direct'),
  ('acc35500-0000-4000-8000-000000000005'::uuid, 'store.deals.share_extra')
) as rules(g, c)
on conflict do nothing;

create or replace function rewards_private.standing_group(p_level text)
returns uuid language sql immutable set search_path = '' as $$
  select case p_level
    when 'regular' then 'acc35500-0000-4000-8000-000000000003'::uuid
    when 'helper' then 'acc35500-0000-4000-8000-000000000004'::uuid
    when 'guide' then 'acc35500-0000-4000-8000-000000000005'::uuid
  end
$$;

-- A capability added later reaches the beta testers too.
create or replace function rewards_private.beta_gets_new_capability()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not rewards_private.capability_is_role(new.id) then
    insert into public.group_capability_rules(group_id, capability, allowed)
    values ('acc35500-0000-4000-8000-000000000002', new.id, true) on conflict do nothing;
  end if;
  return null;
end $$;
revoke all on function rewards_private.beta_gets_new_capability() from public, anon, authenticated;
drop trigger if exists beta_gets_new_capability on public.access_capabilities;
create trigger beta_gets_new_capability after insert on public.access_capabilities
  for each row execute function rewards_private.beta_gets_new_capability();

-- Every account joins the beta while it is open.
create or replace function rewards_private.join_beta()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select beta_auto_join from rewards_private.settings) then
    insert into public.access_group_members(group_id, user_id)
    values ('acc35500-0000-4000-8000-000000000002', new.id) on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function rewards_private.join_beta() from public, anon, authenticated;
drop trigger if exists petloop_beta_member on auth.users;
create trigger petloop_beta_member after insert on auth.users
  for each row execute function rewards_private.join_beta();
insert into public.access_group_members(group_id, user_id)
select 'acc35500-0000-4000-8000-000000000002', u.id from auth.users u
where (select beta_auto_join from rewards_private.settings)
on conflict do nothing;

-- Ranks used by the tier checks.
create or replace function rewards_private.tier_rank(p_tier text)
returns integer language sql immutable set search_path = '' as $$
  select case p_tier when 'trusted' then 3 when 'regular' then 2 else 1 end
$$;
grant execute on function rewards_private.tier_rank(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Pet layer.
-- ---------------------------------------------------------------------------
create table if not exists public.milestone_catalog (
  id text primary key check (id ~ '^[a-z0-9_]{1,40}$'),
  layer text not null check (layer in ('pet', 'member')),
  sort_order integer not null default 0,
  active boolean not null default true
);
insert into public.milestone_catalog(id, layer, sort_order) values
  ('first_days_done', 'pet', 10),
  ('emergency_card_ready', 'pet', 20),
  ('health_profile_ready', 'pet', 30),
  ('vet_visit_recorded', 'pet', 40),
  ('walks_30', 'pet', 50),
  ('walks_100', 'pet', 60),
  ('walks_365', 'pet', 70),
  ('meals_100', 'pet', 80),
  ('meds_course_done', 'pet', 90),
  ('weight_tracked_3m', 'pet', 100)
on conflict (id) do nothing;

create table if not exists public.pet_milestones (
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  milestone_id text not null references public.milestone_catalog (id),
  reached_at timestamptz not null default now(),
  seen_at timestamptz,
  primary key (pet_id, milestone_id)
);
create index if not exists pet_milestones_owner_idx on public.pet_milestones (owner_id);

create table if not exists public.care_rhythm (
  pet_id uuid primary key references public.pets (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  state text not null check (state in ('settling', 'steady', 'thriving', 'paused')),
  on_time_rate numeric(4, 3) not null default 0 check (on_time_rate between 0 and 1),
  counted_days integer not null default 0,
  paused_since date,
  computed_at timestamptz not null default now()
);
create index if not exists care_rhythm_owner_idx on public.care_rhythm (owner_id);

-- ---------------------------------------------------------------------------
-- Community layer.
-- ---------------------------------------------------------------------------
-- kind 'comment': answer = a comment, thread = its post, asker = the post's
-- author. kind 'message': answer = a chat reply, thread = the message it
-- replies to, asker = that message's author. Once per thread per asker.
create table if not exists public.helped_marks (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('comment', 'message')),
  answer_id uuid not null,
  thread_id uuid not null,
  answerer_id uuid not null references auth.users (id) on delete cascade,
  -- Kept when the asker deletes their account: the mark stays evidence.
  asker_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint helped_marks_once_per_thread unique (kind, thread_id, asker_id),
  constraint helped_marks_not_self check (asker_id is null or asker_id <> answerer_id)
);
create index if not exists helped_marks_answerer_idx on public.helped_marks (answerer_id, created_at);
create index if not exists helped_marks_asker_idx on public.helped_marks (asker_id, created_at);
create index if not exists helped_marks_answer_idx on public.helped_marks (kind, answer_id);

create table if not exists public.member_standing (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level text not null default 'member' check (level in ('member', 'regular', 'helper', 'guide')),
  qualifying_marks integer not null default 0,
  distinct_askers integer not null default 0,
  capped_until timestamptz,
  computed_at timestamptz not null default now()
);

-- Removals a moderator upheld (another member's item deleted by a
-- moderator). Never written by reports or by auto-hide.
create table if not exists rewards_private.upheld_removals (
  id bigint generated always as identity primary key,
  author_id uuid not null references auth.users (id) on delete cascade,
  kind text not null,
  target_id uuid not null,
  moderator_id uuid,
  removed_at timestamptz not null default now()
);
create index if not exists upheld_removals_author_idx on rewards_private.upheld_removals (author_id, removed_at);
alter table rewards_private.upheld_removals enable row level security;
revoke all on rewards_private.upheld_removals from public, anon, authenticated;

create or replace function rewards_private.record_upheld_removal()
returns trigger language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  -- Depth 1: the item itself was deleted, not swept away by a cascade.
  if actor is not null and pg_trigger_depth() = 1 and old.author_id is not null
     and old.author_id <> actor and access_private.evaluate(actor, 'community.moderate') then
    insert into rewards_private.upheld_removals(author_id, kind, target_id, moderator_id)
    values (old.author_id, tg_table_name, old.id, actor);
  end if;
  return null;
end $$;
revoke all on function rewards_private.record_upheld_removal() from public, anon, authenticated;

create or replace function rewards_private.drop_marks_for_answer()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  delete from public.helped_marks
  where answer_id = old.id and kind = case tg_table_name when 'community_comments' then 'comment' else 'message' end;
  return null;
end $$;
revoke all on function rewards_private.drop_marks_for_answer() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array['community_posts', 'community_comments', 'chat_messages', 'community_meetups'] loop
    execute format('drop trigger if exists record_upheld_removal on public.%I', t);
    execute format('create trigger record_upheld_removal after delete on public.%I '
                   'for each row execute function rewards_private.record_upheld_removal()', t);
  end loop;
  foreach t in array array['community_comments', 'chat_messages'] loop
    execute format('drop trigger if exists drop_marks_for_answer on public.%I', t);
    execute format('create trigger drop_marks_for_answer after delete on public.%I '
                   'for each row execute function rewards_private.drop_marks_for_answer()', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Shopper layer.
-- ---------------------------------------------------------------------------
-- No secrets here: a partner's postback secret lives in the Edge Function's
-- secrets (or Vault), never in a table or a migration.
create table if not exists public.partners (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  active boolean not null default true,
  daily_redemption_cap integer not null default 200 check (daily_redemption_cap between 1 and 100000),
  -- Set by the rollup when redemptions jump; offers close and redemptions
  -- stop until an administrator clears it.
  review_needed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.coupon_offers (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners (id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  terms text not null check (char_length(terms) between 1 and 2000),
  -- 'unique': each claim gets its own code (verifiable, the default);
  -- 'shared': one printed code (cannot be verified per member).
  code_kind text not null default 'unique' check (code_kind in ('unique', 'shared')),
  min_tier text not null default 'shopper' check (min_tier in ('shopper', 'regular', 'trusted')),
  valid_from timestamptz not null default now(),
  valid_until timestamptz not null,
  max_claims integer not null check (max_claims between 1 and 1000000),
  claims_count integer not null default 0 check (claims_count >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint coupon_offers_window check (valid_until > valid_from),
  constraint coupon_offers_within_cap check (claims_count <= max_claims)
);
create index if not exists coupon_offers_partner_idx on public.coupon_offers (partner_id);

-- A shared offer's printed code is handed out only by claim_coupon().
create table if not exists rewards_private.offer_codes (
  offer_id uuid primary key references public.coupon_offers (id) on delete cascade,
  shared_code text not null check (char_length(shared_code) between 3 and 40)
);
alter table rewards_private.offer_codes enable row level security;
revoke all on rewards_private.offer_codes from public, anon, authenticated;

create table if not exists public.coupon_claims (
  offer_id uuid not null references public.coupon_offers (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- 64 random bits; null for a shared offer.
  code text unique check (code is null or code ~ '^PL(-[0-9A-F]{4}){4}$'),
  claimed_at timestamptz not null default now(),
  redeemed_at timestamptz,
  verified_by text check (verified_by in ('partner_postback', 'partner_csv')),
  primary key (offer_id, user_id)
);
create index if not exists coupon_claims_user_idx on public.coupon_claims (user_id, claimed_at);
create index if not exists coupon_claims_redeemed_idx on public.coupon_claims (redeemed_at) where redeemed_at is not null;

create table if not exists public.purchase_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  source text not null check (source in ('coupon', 'affiliate', 'self')),
  offer_id uuid references public.coupon_offers (id) on delete set null,
  deal_id uuid references public.store_deals (id) on delete set null,
  amount numeric(10, 2) check (amount is null or amount between 0 and 100000),
  currency text check (currency is null or currency ~ '^[A-Z]{3}$'),
  verified boolean not null default false,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists purchase_events_user_idx on public.purchase_events (user_id, occurred_at);
create unique index if not exists purchase_events_one_self_report_per_deal
  on public.purchase_events (user_id, deal_id) where source = 'self';

create table if not exists public.shopper_standing (
  user_id uuid primary key references auth.users (id) on delete cascade,
  tier text not null default 'shopper' check (tier in ('shopper', 'regular', 'trusted')),
  verified_count integer not null default 0,
  self_reported_count integer not null default 0,
  tier_since timestamptz not null default now(),
  -- A tier above Shopper is kept until this date, then re-evaluated.
  tier_until timestamptz,
  computed_at timestamptz not null default now()
);

-- Raw partner postbacks, kept 90 days; one per partner and external id.
create table if not exists rewards_private.partner_postbacks (
  partner_id uuid not null references public.partners (id) on delete cascade,
  external_id text not null check (char_length(external_id) between 1 and 100),
  payload jsonb not null,
  result text,
  received_at timestamptz not null default now(),
  primary key (partner_id, external_id)
);
alter table rewards_private.partner_postbacks enable row level security;
revoke all on rewards_private.partner_postbacks from public, anon, authenticated;

-- Early access: a deal can be held back for Regular and Trusted shoppers,
-- for at most a week. Only administrators set it.
alter table public.store_deals add column if not exists early_until timestamptz;
alter table public.store_deals drop constraint if exists store_deals_early_access_window;
alter table public.store_deals add constraint store_deals_early_access_window
  check (early_until is null or early_until <= posted_at + interval '7 days');

create or replace function rewards_private.early_access_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') and not public.can_use('access.admin') then
    new.early_until := case when tg_op = 'UPDATE' then old.early_until end;
  end if;
  return new;
end $$;
revoke all on function rewards_private.early_access_guard() from public, anon, authenticated;
drop trigger if exists early_access_guard on public.store_deals;
create trigger early_access_guard before insert or update on public.store_deals
  for each row execute function rewards_private.early_access_guard();

-- The caller's current tier rank (1 Shopper, 2 Regular, 3 Trusted).
create or replace function rewards_private.my_tier_rank()
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce((
    select rewards_private.tier_rank(s.tier) from public.shopper_standing s
    where s.user_id = auth.uid() and (s.tier = 'shopper' or s.tier_until is null or s.tier_until > now())
  ), 1)
$$;
revoke all on function rewards_private.my_tier_rank() from public, anon;
grant execute on function rewards_private.my_tier_rank() to authenticated;

create or replace function rewards_private.partner_open(p_partner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.partners p where p.id = p_partner and p.active and p.review_needed_at is null)
$$;
revoke all on function rewards_private.partner_open(uuid) from public, anon;
grant execute on function rewards_private.partner_open(uuid) to authenticated;

-- Append-only audit of partners and offers.
create table if not exists rewards_private.audit (
  id bigint generated always as identity primary key,
  actor_id uuid,
  table_name text not null,
  op text not null,
  before_value jsonb,
  after_value jsonb,
  created_at timestamptz not null default now()
);
alter table rewards_private.audit enable row level security;
revoke all on rewards_private.audit from public, anon, authenticated;

create or replace function rewards_private.audit_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  -- A claim only moves the counter: not an administrative change.
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'claims_count') = (to_jsonb(old) - 'claims_count') then
    return null;
  end if;
  insert into rewards_private.audit(actor_id, table_name, op, before_value, after_value)
  values (auth.uid(), tg_table_name, tg_op,
          case when tg_op = 'INSERT' then null else to_jsonb(old) end,
          case when tg_op = 'DELETE' then null else to_jsonb(new) end);
  return null;
end $$;
revoke all on function rewards_private.audit_change() from public, anon, authenticated;

create or replace function rewards_private.append_only()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'The rewards audit is append-only' using errcode = '42501';
end $$;
revoke all on function rewards_private.append_only() from public, anon, authenticated;

drop trigger if exists rewards_audit on public.partners;
create trigger rewards_audit after insert or update or delete on public.partners
  for each row execute function rewards_private.audit_change();
drop trigger if exists rewards_audit on public.coupon_offers;
create trigger rewards_audit after insert or update or delete on public.coupon_offers
  for each row execute function rewards_private.audit_change();
drop trigger if exists append_only on rewards_private.audit;
create trigger append_only before update or delete on rewards_private.audit
  for each row execute function rewards_private.append_only();

-- ---------------------------------------------------------------------------
-- Row level security. Members read their own rows; the server writes them.
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['milestone_catalog', 'pet_milestones', 'care_rhythm', 'helped_marks',
                           'member_standing', 'partners', 'coupon_offers', 'coupon_claims',
                           'purchase_events', 'shopper_standing'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end
$$;
grant delete on public.helped_marks to authenticated;

drop policy if exists "milestone_catalog: members read" on public.milestone_catalog;
create policy "milestone_catalog: members read" on public.milestone_catalog
  for select to authenticated using ((select public.can_use('rewards.view')));

drop policy if exists "pet_milestones: owner reads" on public.pet_milestones;
create policy "pet_milestones: owner reads" on public.pet_milestones
  for select to authenticated using (owner_id = (select auth.uid()) and (select public.can_use('rewards.view')));

drop policy if exists "care_rhythm: owner reads" on public.care_rhythm;
create policy "care_rhythm: owner reads" on public.care_rhythm
  for select to authenticated using (owner_id = (select auth.uid()) and (select public.can_use('rewards.view')));

drop policy if exists "helped_marks: asker and answerer read" on public.helped_marks;
create policy "helped_marks: asker and answerer read" on public.helped_marks
  for select to authenticated using (
    ((select auth.uid()) in (asker_id, answerer_id)) and (select public.can_use('rewards.view')));
drop policy if exists "helped_marks: asker takes it back" on public.helped_marks;
create policy "helped_marks: asker takes it back" on public.helped_marks
  for delete to authenticated using (asker_id = (select auth.uid()));

drop policy if exists "member_standing: own row" on public.member_standing;
create policy "member_standing: own row" on public.member_standing
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "partners: administrators read" on public.partners;
create policy "partners: administrators read" on public.partners
  for select to authenticated using ((select public.can_use('access.admin')));

drop policy if exists "coupon_offers: open offers for your tier" on public.coupon_offers;
create policy "coupon_offers: open offers for your tier" on public.coupon_offers
  for select to authenticated using (
    active and now() >= valid_from and now() < valid_until
    and rewards_private.tier_rank(min_tier) <= (select rewards_private.my_tier_rank())
    and rewards_private.partner_open(partner_id)
    and (select public.can_use('rewards.claim_coupons')));
drop policy if exists "coupon_offers: administrators read" on public.coupon_offers;
create policy "coupon_offers: administrators read" on public.coupon_offers
  for select to authenticated using ((select public.can_use('access.admin')));

drop policy if exists "coupon_claims: own claims" on public.coupon_claims;
create policy "coupon_claims: own claims" on public.coupon_claims
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "purchase_events: own events" on public.purchase_events;
create policy "purchase_events: own events" on public.purchase_events
  for select to authenticated using (user_id = (select auth.uid()));

-- A tier is private: only its holder reads it.
drop policy if exists "shopper_standing: own row" on public.shopper_standing;
create policy "shopper_standing: own row" on public.shopper_standing
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists rewards_early_access on public.store_deals;
create policy rewards_early_access on public.store_deals as restrictive for select to authenticated using (
  early_until is null or early_until <= now() or shared_by = (select auth.uid())
  or (select rewards_private.my_tier_rank()) >= 2 or (select public.can_use('access.admin')));

-- ---------------------------------------------------------------------------
-- Member actions.
-- ---------------------------------------------------------------------------
create or replace function rewards_private.mark_seen(p_pet uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if not access_private.evaluate(auth.uid(), 'rewards.view') then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  update public.pet_milestones set seen_at = now()
  where pet_id = p_pet and owner_id = auth.uid() and seen_at is null;
  get diagnostics changed = row_count;
  return changed;
end $$;

-- "This helped": the asker marks one answer in a thread.
create or replace function rewards_private.mark_helped(p_kind text, p_answer uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  answerer uuid;
  thread uuid;
  asker uuid;
  inserted integer;
begin
  if me is null or not access_private.evaluate(me, 'rewards.mark_helped') then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  if p_kind = 'comment' then
    select c.author_id, c.post_id, p.author_id into answerer, thread, asker
    from public.community_comments c join public.community_posts p on p.id = c.post_id
    where c.id = p_answer and c.hidden_at is null and p.hidden_at is null;
  elsif p_kind = 'message' then
    select m.author_id, q.id, q.author_id into answerer, thread, asker
    from public.chat_messages m join public.chat_messages q on q.id = m.reply_to
    where m.id = p_answer and m.hidden_at is null and q.hidden_at is null
      and m.system is null and q.system is null and m.channel_id = q.channel_id;
  else
    raise exception 'Unknown kind' using errcode = '22023';
  end if;
  if asker is null or asker <> me then
    raise exception 'not_the_asker' using errcode = 'P0001';
  end if;
  if answerer is null or answerer = me then
    raise exception 'not_an_answer' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.user_blocks b
             where (b.blocker_id = me and b.blocked_id = answerer) or (b.blocker_id = answerer and b.blocked_id = me)) then
    raise exception 'not_an_answer' using errcode = 'P0001';
  end if;
  if (select count(*) from public.helped_marks h where h.asker_id = me and h.created_at > now() - interval '1 day') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  insert into public.helped_marks(kind, answer_id, thread_id, answerer_id, asker_id)
  values (p_kind, p_answer, thread, answerer, me)
  on conflict on constraint helped_marks_once_per_thread do nothing;
  get diagnostics inserted = row_count;
  return inserted = 1;
end $$;

-- Levels to show next to names. Only Regular and above are returned.
create or replace function rewards_private.community_standing(p_users uuid[])
returns table (user_id uuid, level text) language plpgsql stable security definer set search_path = '' as $$
begin
  if not (access_private.evaluate(auth.uid(), 'community.feed.view') or access_private.evaluate(auth.uid(), 'community.chat.view')) then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  if cardinality(p_users) > 200 then
    raise exception 'Too many members' using errcode = '22023';
  end if;
  return query select s.user_id, s.level from public.member_standing s
    where s.user_id = any(p_users) and s.level <> 'member';
end $$;

create or replace function rewards_private.claim_json(p_offer public.coupon_offers, p_claim public.coupon_claims)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'offer_id', p_offer.id, 'title', p_offer.title, 'terms', p_offer.terms,
    'valid_until', p_offer.valid_until, 'claimed_at', p_claim.claimed_at,
    'redeemed', p_claim.redeemed_at is not null,
    'code', coalesce(p_claim.code, (select c.shared_code from rewards_private.offer_codes c where c.offer_id = p_offer.id)))
$$;
revoke all on function rewards_private.claim_json(public.coupon_offers, public.coupon_claims) from public, anon, authenticated;

create or replace function rewards_private.claim_coupon(p_offer uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  offer public.coupon_offers;
  claim public.coupon_claims;
  raw text;
  new_code text;
begin
  if me is null or not access_private.evaluate(me, 'rewards.claim_coupons') then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  select * into claim from public.coupon_claims where offer_id = p_offer and user_id = me;
  if found then
    select * into offer from public.coupon_offers where id = p_offer;
    return rewards_private.claim_json(offer, claim);
  end if;
  if not rewards_private.account_trusted(me) then
    raise exception 'not_eligible' using errcode = 'P0001', hint = 'account';
  end if;
  if (select count(*) from public.coupon_claims c where c.user_id = me and c.claimed_at > now() - interval '1 day') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  select * into offer from public.coupon_offers where id = p_offer for update;
  if not found or not offer.active or now() < offer.valid_from or now() >= offer.valid_until
     or not rewards_private.partner_open(offer.partner_id) then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if rewards_private.tier_rank(offer.min_tier) > rewards_private.my_tier_rank() then
    raise exception 'not_eligible' using errcode = 'P0001', hint = 'tier';
  end if;
  if offer.claims_count >= offer.max_claims then
    raise exception 'sold_out' using errcode = 'P0001';
  end if;
  if offer.code_kind = 'unique' then
    loop
      -- The first 8 hex digits of a version 4 UUID are random: 64 bits.
      raw := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)
                || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
      new_code := 'PL-' || substr(raw, 1, 4) || '-' || substr(raw, 5, 4) || '-' || substr(raw, 9, 4) || '-' || substr(raw, 13, 4);
      exit when not exists (select 1 from public.coupon_claims where code = new_code);
    end loop;
  end if;
  insert into public.coupon_claims(offer_id, user_id, code) values (offer.id, me, new_code) returning * into claim;
  update public.coupon_offers set claims_count = claims_count + 1 where id = offer.id;
  return rewards_private.claim_json(offer, claim);
end $$;

-- "I bought it": counts at low weight, four a month, once per deal, and
-- never enough on its own for the top tier.
create or replace function rewards_private.report_purchase(p_deal uuid, p_amount numeric default null)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); deal public.store_deals; inserted integer;
begin
  if me is null or not access_private.evaluate(me, 'rewards.report_purchase') then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  if not rewards_private.account_trusted(me) then
    raise exception 'not_eligible' using errcode = 'P0001', hint = 'account';
  end if;
  select * into deal from public.store_deals where id = p_deal;
  if not found then raise exception 'not_found' using errcode = 'P0001'; end if;
  if p_amount is not null and (p_amount < 0 or p_amount > 100000) then
    raise exception 'Amount out of range' using errcode = '22023';
  end if;
  if (select count(*) from public.purchase_events e
      where e.user_id = me and e.source = 'self' and e.created_at >= date_trunc('month', now())) >= 4 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'monthly_cap';
  end if;
  insert into public.purchase_events(user_id, source, deal_id, amount, currency, verified)
  values (me, 'self', deal.id, p_amount, case when p_amount is not null then deal.currency end, false)
  on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then raise exception 'already_reported' using errcode = 'P0001'; end if;
end $$;

-- ---------------------------------------------------------------------------
-- Partner redemptions: one code at a time, under the partner's daily cap.
-- ---------------------------------------------------------------------------
create or replace function rewards_private.redeem_code(p_partner uuid, p_code text, p_source text)
returns text language plpgsql security definer set search_path = '' as $$
declare claim record; cap integer; today integer;
begin
  if not rewards_private.partner_open(p_partner) then return 'paused'; end if;
  if p_code is null or upper(trim(p_code)) !~ '^PL(-[0-9A-F]{4}){4}$' then return 'invalid'; end if;
  select c.offer_id, c.user_id, c.redeemed_at into claim
  from public.coupon_claims c join public.coupon_offers o on o.id = c.offer_id
  where c.code = upper(trim(p_code)) and o.partner_id = p_partner
  for update of c;
  if not found then return 'unknown'; end if;
  if claim.redeemed_at is not null then return 'duplicate'; end if;
  select daily_redemption_cap into cap from public.partners where id = p_partner for update;
  select count(*) into today from public.coupon_claims c join public.coupon_offers o on o.id = c.offer_id
  where o.partner_id = p_partner and c.redeemed_at > now() - interval '1 day';
  if today >= cap then return 'cap'; end if;
  update public.coupon_claims set redeemed_at = now(), verified_by = p_source
  where offer_id = claim.offer_id and user_id = claim.user_id;
  insert into public.purchase_events(user_id, source, offer_id, verified)
  values (claim.user_id, 'coupon', claim.offer_id, true);
  return 'redeemed';
end $$;
revoke all on function rewards_private.redeem_code(uuid, text, text) from public, anon, authenticated;

-- An administrator records a partner's list of redeemed codes (a CSV read
-- on the device). Up to 500 codes a call; every code must be a claim of
-- that partner's offers.
create or replace function rewards_private.admin_record_redemptions(p_partner uuid, p_codes text[])
returns jsonb language plpgsql security definer set search_path = '' as $$
declare code text; outcome text; tally jsonb := '{}'::jsonb;
begin
  perform access_private.require_admin();
  if p_codes is null or cardinality(p_codes) not between 1 and 500 then
    raise exception 'Between 1 and 500 codes' using errcode = '22023';
  end if;
  foreach code in array p_codes loop
    outcome := rewards_private.redeem_code(p_partner, code, 'partner_csv');
    tally := jsonb_set(tally, array[outcome], to_jsonb(coalesce((tally ->> outcome)::integer, 0) + 1));
  end loop;
  return tally;
end $$;

-- A partner's signed postback, verified by the Edge Function first. One
-- per partner and external id; the raw body is kept 90 days.
create or replace function rewards_private.partner_postback(p_partner uuid, p_external_id text, p_code text, p_payload jsonb)
returns text language plpgsql security definer set search_path = '' as $$
declare inserted integer; outcome text;
begin
  if p_external_id is null or char_length(p_external_id) not between 1 and 100 then return 'invalid'; end if;
  if p_payload is null or octet_length(p_payload::text) > 8192 then return 'invalid'; end if;
  insert into rewards_private.partner_postbacks(partner_id, external_id, payload)
  values (p_partner, p_external_id, p_payload)
  on conflict do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then return 'duplicate'; end if;
  outcome := rewards_private.redeem_code(p_partner, p_code, 'partner_postback');
  update rewards_private.partner_postbacks set result = outcome
  where partner_id = p_partner and external_id = p_external_id;
  return outcome;
end $$;
revoke all on function rewards_private.partner_postback(uuid, text, text, jsonb) from public, anon, authenticated;
grant execute on function rewards_private.partner_postback(uuid, text, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- Public wrappers (the app calls these through the API).
-- ---------------------------------------------------------------------------
revoke all on function rewards_private.mark_seen(uuid), rewards_private.mark_helped(text, uuid),
  rewards_private.community_standing(uuid[]), rewards_private.claim_coupon(uuid),
  rewards_private.report_purchase(uuid, numeric), rewards_private.admin_record_redemptions(uuid, text[])
  from public, anon;
grant execute on function rewards_private.mark_seen(uuid), rewards_private.mark_helped(text, uuid),
  rewards_private.community_standing(uuid[]), rewards_private.claim_coupon(uuid),
  rewards_private.report_purchase(uuid, numeric), rewards_private.admin_record_redemptions(uuid, text[])
  to authenticated;

create or replace function public.rewards_mark_seen(p_pet uuid)
returns integer language sql security invoker set search_path = '' as $$ select rewards_private.mark_seen(p_pet) $$;
create or replace function public.mark_helped(p_kind text, p_answer uuid)
returns boolean language sql security invoker set search_path = '' as $$ select rewards_private.mark_helped(p_kind, p_answer) $$;
create or replace function public.community_standing(p_users uuid[])
returns table (user_id uuid, level text) language sql stable security invoker set search_path = '' as $$
  select * from rewards_private.community_standing(p_users) $$;
create or replace function public.claim_coupon(p_offer uuid)
returns jsonb language sql security invoker set search_path = '' as $$ select rewards_private.claim_coupon(p_offer) $$;
create or replace function public.report_purchase(p_deal uuid, p_amount numeric default null)
returns void language sql security invoker set search_path = '' as $$ select rewards_private.report_purchase(p_deal, p_amount) $$;
create or replace function public.rewards_admin_record_redemptions(p_partner uuid, p_codes text[])
returns jsonb language sql security invoker set search_path = '' as $$ select rewards_private.admin_record_redemptions(p_partner, p_codes) $$;
revoke all on function public.rewards_mark_seen(uuid), public.mark_helped(text, uuid), public.community_standing(uuid[]),
  public.claim_coupon(uuid), public.report_purchase(uuid, numeric), public.rewards_admin_record_redemptions(uuid, text[])
  from public, anon;
grant execute on function public.rewards_mark_seen(uuid), public.mark_helped(text, uuid), public.community_standing(uuid[]),
  public.claim_coupon(uuid), public.report_purchase(uuid, numeric), public.rewards_admin_record_redemptions(uuid, text[])
  to authenticated;

-- Service role only (the partner-postback Edge Function).
create or replace function public.rewards_partner_postback(p_partner uuid, p_external_id text, p_code text, p_payload jsonb)
returns text language sql security invoker set search_path = '' as $$
  select rewards_private.partner_postback(p_partner, p_external_id, p_code, p_payload) $$;
revoke all on function public.rewards_partner_postback(uuid, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.rewards_partner_postback(uuid, text, text, jsonb) to service_role;

-- ---------------------------------------------------------------------------
-- The rollup.
-- ---------------------------------------------------------------------------
create or replace function rewards_private.compute_pets(p_pets uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- Milestones: sticky, once reached never taken back.
  with logs as (
    select l.pet_id, coalesce(l.kind, pi.kind) as kind, l.due_on
    from public.care_logs l
    left join public.care_plan_items pi on pi.id = l.plan_item_id
    where l.pet_id = any(p_pets) and l.status = 'done' and l.access_domain = 'care'
      -- Logged within a week of its date (by the server's clock).
      and l.due_on between (l.server_logged_at at time zone 'UTC')::date - 7
                       and (l.server_logged_at at time zone 'UTC')::date + 1
  ), daily as (
    select pet_id, kind, due_on,
           least(count(*), case kind when 'walk' then 6 else 8 end) as n
    from logs where kind in ('walk', 'feeding')
    group by pet_id, kind, due_on
  ), totals as (
    select pet_id,
           coalesce(sum(n) filter (where kind = 'walk'), 0) as walks,
           coalesce(sum(n) filter (where kind = 'feeding'), 0) as meals
    from daily group by pet_id
  ), reached as (
    select pet_id, 'walks_30' as milestone from totals where walks >= 30
    union all select pet_id, 'walks_100' from totals where walks >= 100
    union all select pet_id, 'walks_365' from totals where walks >= 365
    union all select pet_id, 'meals_100' from totals where meals >= 100
    union all
    select f.pet_id, 'first_days_done' from public.pet_first_days f
    where f.pet_id = any(p_pets) and f.arrived_on <= current_date - 30
    union all
    select h.pet_id, 'emergency_card_ready' from public.health_profiles h
    where h.pet_id = any(p_pets) and (h.regular_vet_id is not null or h.emergency_vet_id is not null)
      and h.contact_phone <> '' and (h.microchip <> '' or h.not_chipped)
    union all
    select h.pet_id, 'health_profile_ready' from public.health_profiles h
    where h.pet_id = any(p_pets) and (cardinality(h.allergies) > 0 or h.allergies_none_known)
      and (cardinality(h.conditions) > 0 or h.conditions_none_known)
    union all
    select distinct m.pet_id, 'meds_course_done' from public.medications m
    where m.pet_id = any(p_pets) and m.ends_on < current_date
      and exists (select 1 from public.care_logs l where l.medication_id = m.id and l.status = 'done')
    union all
    select o.pet_id, 'weight_tracked_3m' from public.health_observations o
    where o.pet_id = any(p_pets) and o.category = 'weight'
    group by o.pet_id having count(*) >= 3 and max(o.created_at) - min(o.created_at) >= interval '90 days'
    union all
    select distinct e.pet_id, 'vet_visit_recorded' from public.health_events e
    where e.pet_id = any(p_pets) and e.kind = 'checkup' and e.done_at is not null
  )
  insert into public.pet_milestones(pet_id, owner_id, milestone_id)
  select distinct r.pet_id, p.owner_id, r.milestone
  from reached r
  join public.pets p on p.id = r.pet_id
  join public.milestone_catalog c on c.id = r.milestone and c.active
  on conflict (pet_id, milestone_id) do nothing;

  -- Care rhythm over the last 28 days. A day counts as cared when a done
  -- meal or walk was logged by the next day. Runs of 3 or more days with no
  -- log at all are a break (holiday, illness): left out, never a failure.
  with plans as (
    select pi.pet_id, min(coalesce(pi.starts_on, (pi.created_at at time zone 'UTC')::date)) as since
    from public.care_plan_items pi
    where pi.pet_id = any(p_pets) and pi.access_domain = 'care' and pi.active
    group by pi.pet_id
  ), days as (
    select p.pet_id, d::date as day
    from plans p
    cross join lateral generate_series(greatest(current_date - 28, p.since), current_date - 1, interval '1 day') d
  ), logged as (
    select l.pet_id, l.due_on as day,
           bool_or(l.status = 'done' and (l.server_logged_at at time zone 'UTC')::date <= l.due_on + 1) as cared
    from public.care_logs l
    where l.pet_id = any(p_pets) and l.access_domain = 'care'
      and l.due_on between current_date - 28 and current_date - 1
    group by l.pet_id, l.due_on
  ), flags as (
    select d.pet_id, d.day, coalesce(g.cared, false) as cared, g.day is not null as active
    from days d left join logged g on g.pet_id = d.pet_id and g.day = d.day
  ), runs as (
    select f.*, f.day - (row_number() over (partition by f.pet_id, f.active order by f.day))::integer as grp
    from flags f
  ), sized as (
    select r.*, count(*) over (partition by r.pet_id, r.active, r.grp) as len from runs r
  ), summary as (
    select p.pet_id,
           count(s.day) filter (where s.active or s.len < 3) as counted,
           count(s.day) filter (where s.cared) as cared,
           (select max((l.server_logged_at at time zone 'UTC')::date) from public.care_logs l
            where l.pet_id = p.pet_id and l.access_domain = 'care') as last_logged
    from plans p left join sized s on s.pet_id = p.pet_id
    group by p.pet_id
  )
  insert into public.care_rhythm(pet_id, owner_id, state, on_time_rate, counted_days, paused_since, computed_at)
  select s.pet_id, pt.owner_id,
         case
           when s.last_logged is null or s.last_logged < current_date - 2 then 'paused'
           when s.counted < 7 then 'settling'
           when s.cared::numeric / s.counted >= 0.7 then 'thriving'
           when s.cared::numeric / s.counted >= 0.4 then 'steady'
           else 'settling'
         end,
         case when s.counted > 0 then round(least(s.cared, s.counted)::numeric / s.counted, 3) else 0 end,
         s.counted,
         case when s.last_logged is null then current_date
              when s.last_logged < current_date - 2 then s.last_logged + 1 end,
         now()
  from summary s join public.pets pt on pt.id = s.pet_id
  on conflict (pet_id) do update set
    state = excluded.state,
    on_time_rate = excluded.on_time_rate,
    counted_days = excluded.counted_days,
    paused_since = case when excluded.state = 'paused'
                        then coalesce(public.care_rhythm.paused_since, excluded.paused_since) end,
    computed_at = excluded.computed_at;

  delete from public.care_rhythm r
  where r.pet_id = any(p_pets)
    and not exists (select 1 from public.care_plan_items pi
                    where pi.pet_id = r.pet_id and pi.access_domain = 'care' and pi.active);
end $$;
revoke all on function rewards_private.compute_pets(uuid[]) from public, anon, authenticated;

create or replace function rewards_private.compute_members(p_users uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  with marks as (
    select h.answerer_id, h.asker_id, h.created_at
    from public.helped_marks h
    where h.answerer_id = any(p_users) and h.asker_id is not null
      and h.created_at > now() - interval '365 days'
  ), pairs as (
    select m.answerer_id, m.asker_id, count(*) as given,
           (select count(*) from public.helped_marks r
            where r.answerer_id = m.asker_id and r.asker_id = m.answerer_id
              and r.created_at > now() - interval '365 days') as given_back
    from marks m group by m.answerer_id, m.asker_id
  ), honest as (
    select m.* from marks m
    join pairs p on p.answerer_id = m.answerer_id and p.asker_id = m.asker_id
    -- A pair marking each other about equally often is a ring: neither counts.
    where not (p.given_back > 0 and greatest(p.given, p.given_back) >= 2
               and least(p.given, p.given_back)::numeric / greatest(p.given, p.given_back) > 0.6)
      and rewards_private.account_trusted(m.asker_id)
  ), tallies as (
    select answerer_id,
           -- Once per asker per 30 days.
           count(distinct (asker_id, floor(extract(epoch from created_at) / 2592000))) as qualifying,
           count(distinct asker_id) as askers
    from honest group by answerer_id
  ), computed as (
    select u.id as user_id,
           coalesce(t.qualifying, 0) as qualifying,
           coalesce(t.askers, 0) as askers,
           (select max(x.removed_at) from rewards_private.upheld_removals x
            where x.author_id = u.id and x.removed_at > now() - interval '90 days') as last_removal,
           (u.created_at <= now() - (select s.trusted_account_age from rewards_private.settings s)
            and u.email_confirmed_at is not null) as old_enough
    from auth.users u left join tallies t on t.answerer_id = u.id
    where u.id = any(p_users)
  )
  insert into public.member_standing(user_id, level, qualifying_marks, distinct_askers, capped_until, computed_at)
  select c.user_id,
         case
           when c.last_removal is not null or not c.old_enough then 'member'
           when c.qualifying >= 25 and c.askers >= 10 then 'guide'
           when c.qualifying >= 10 and c.askers >= 5 then 'helper'
           when c.qualifying >= 3 and c.askers >= 2 then 'regular'
           else 'member'
         end,
         c.qualifying, c.askers, c.last_removal + interval '90 days', now()
  from computed c
  on conflict (user_id) do update set
    level = excluded.level,
    qualifying_marks = excluded.qualifying_marks,
    distinct_askers = excluded.distinct_askers,
    capped_until = excluded.capped_until,
    computed_at = excluded.computed_at;

  -- Standing groups follow the level; the rollup is their only writer.
  delete from public.access_group_members gm
  using public.member_standing s
  where gm.user_id = s.user_id and s.user_id = any(p_users)
    and gm.group_id in ('acc35500-0000-4000-8000-000000000003', 'acc35500-0000-4000-8000-000000000004',
                        'acc35500-0000-4000-8000-000000000005')
    and gm.group_id is distinct from rewards_private.standing_group(s.level);
  insert into public.access_group_members(group_id, user_id)
  select rewards_private.standing_group(s.level), s.user_id
  from public.member_standing s
  where s.user_id = any(p_users) and s.level <> 'member'
  on conflict do nothing;
end $$;
revoke all on function rewards_private.compute_members(uuid[]) from public, anon, authenticated;

create or replace function rewards_private.compute_shoppers(p_users uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  with events as (
    select e.user_id,
           count(*) filter (where e.verified) as verified,
           count(*) filter (where not e.verified and e.source = 'self') as self_reported
    from public.purchase_events e
    where e.user_id = any(p_users) and e.occurred_at > now() - interval '365 days'
    group by e.user_id
  ), computed as (
    select u.user_id,
           coalesce(e.verified, 0) as verified,
           coalesce(e.self_reported, 0) as self_reported,
           case
             when coalesce(e.verified, 0) >= 8 then 'trusted'
             when coalesce(e.verified, 0) + 0.25 * least(coalesce(e.self_reported, 0), 12) >= 3 then 'regular'
             else 'shopper'
           end as tier
    from unnest(p_users) as u(user_id)
    left join events e on e.user_id = u.user_id
  ), merged as (
    select c.user_id, c.verified, c.self_reported,
           case
             when s.user_id is null then c.tier
             when rewards_private.tier_rank(c.tier) > rewards_private.tier_rank(s.tier) then c.tier
             -- A tier reached is kept for its whole year.
             when s.tier_until is not null and s.tier_until > now() then s.tier
             else c.tier
           end as tier,
           s.tier as old_tier, s.tier_since as old_since, s.tier_until as old_until
    from computed c
    left join public.shopper_standing s on s.user_id = c.user_id
    where s.user_id is not null or c.verified > 0 or c.self_reported > 0
  )
  insert into public.shopper_standing(user_id, tier, verified_count, self_reported_count, tier_since, tier_until, computed_at)
  select m.user_id, m.tier, m.verified, m.self_reported,
         case when m.old_tier is not distinct from m.tier then coalesce(m.old_since, now()) else now() end,
         case when m.tier = 'shopper' then null
              when m.old_tier is not distinct from m.tier and m.old_until > now() then m.old_until
              else now() + interval '365 days' end,
         now()
  from merged m
  on conflict (user_id) do update set
    tier = excluded.tier,
    verified_count = excluded.verified_count,
    self_reported_count = excluded.self_reported_count,
    tier_since = excluded.tier_since,
    tier_until = excluded.tier_until,
    computed_at = excluded.computed_at;
end $$;
revoke all on function rewards_private.compute_shoppers(uuid[]) from public, anon, authenticated;

create or replace function rewards_private.housekeeping()
returns void language plpgsql security definer set search_path = '' as $$
begin
  -- A partner whose redemptions jump (more than 20 in a day and three times
  -- its usual day) is paused for review.
  update public.partners p set review_needed_at = now()
  where p.review_needed_at is null and p.active
    and (select count(*) from public.coupon_claims c join public.coupon_offers o on o.id = c.offer_id
         where o.partner_id = p.id and c.redeemed_at > now() - interval '1 day')
        > greatest(20, 3 * (select count(*)::numeric / 28 from public.coupon_claims c
                             join public.coupon_offers o on o.id = c.offer_id
                             where o.partner_id = p.id
                               and c.redeemed_at between now() - interval '29 days' and now() - interval '1 day'));
  delete from rewards_private.partner_postbacks where received_at < now() - interval '90 days';
  delete from rewards_private.upheld_removals where removed_at < now() - interval '365 days';
end $$;
revoke all on function rewards_private.housekeeping() from public, anon, authenticated;

create table if not exists rewards_private.rollup_state (
  singleton boolean primary key default true check (singleton),
  run_on date,
  phase text not null default 'done' check (phase in ('pets', 'members', 'housekeeping', 'done')),
  cursor_id uuid,
  updated_at timestamptz not null default now()
);
insert into rewards_private.rollup_state(singleton) values (true) on conflict do nothing;
alter table rewards_private.rollup_state enable row level security;
revoke all on rewards_private.rollup_state from public, anon, authenticated;

-- One step: batches of pets, then of members, then housekeeping, until the
-- time budget runs out. Resumes where it stopped; once a day's run is done
-- it does nothing until the next UTC day.
create or replace function rewards_private.rollup_step(p_batch integer default 200,
                                                       p_budget interval default interval '25 seconds')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  st rewards_private.rollup_state;
  started timestamptz := clock_timestamp();
  ids uuid[];
  batches integer := 0;
begin
  if p_batch not between 1 and 2000 then
    raise exception 'Batch size out of range' using errcode = '22023';
  end if;
  if not pg_try_advisory_xact_lock(hashtext('petloop.rewards.rollup')) then
    return jsonb_build_object('skipped', true);
  end if;
  select * into st from rewards_private.rollup_state where singleton for update;
  if st.run_on is distinct from current_date then
    st.run_on := current_date; st.phase := 'pets'; st.cursor_id := null;
  end if;
  -- At least one batch per call, then as many as the time budget allows.
  loop
    exit when st.phase = 'done' or (batches > 0 and clock_timestamp() - started >= p_budget);
    batches := batches + 1;
    if st.phase = 'pets' then
      select coalesce(array_agg(x.id order by x.id), '{}') into ids
      from (select p.id from public.pets p where st.cursor_id is null or p.id > st.cursor_id order by p.id limit p_batch) x;
      if cardinality(ids) = 0 then
        st.phase := 'members'; st.cursor_id := null;
      else
        perform rewards_private.compute_pets(ids);
        st.cursor_id := ids[cardinality(ids)];
      end if;
    elsif st.phase = 'members' then
      select coalesce(array_agg(x.id order by x.id), '{}') into ids
      from (select u.id from auth.users u where st.cursor_id is null or u.id > st.cursor_id order by u.id limit p_batch) x;
      if cardinality(ids) = 0 then
        st.phase := 'housekeeping'; st.cursor_id := null;
      else
        perform rewards_private.compute_members(ids);
        perform rewards_private.compute_shoppers(ids);
        st.cursor_id := ids[cardinality(ids)];
      end if;
    else
      perform rewards_private.housekeeping();
      st.phase := 'done';
    end if;
  end loop;
  update rewards_private.rollup_state
  set run_on = st.run_on, phase = st.phase, cursor_id = st.cursor_id, updated_at = now()
  where singleton;
  return jsonb_build_object('run_on', st.run_on, 'phase', st.phase, 'batches', batches);
end $$;
revoke all on function rewards_private.rollup_step(integer, interval) from public, anon, authenticated;
grant execute on function rewards_private.rollup_step(integer, interval) to service_role;

commit;
