-- PetLoop: community chat and safety. Apply after 0020.
--
-- Chat:
--   * a message can answer another one (reply_to) and carry a photo
--     (photo_path, in the community-photos bucket, in the author's folder);
--   * emoji reactions (chat_message_reactions, live through Realtime);
--   * read markers per member and room (chat_reads, mark_chat_read()) and
--     a room list with the last message and the unread count
--     (chat_room_summaries).
-- Safety:
--   * blocking a member (user_blocks) hides their posts, comments and
--     messages from the blocker, enforced by row level security;
--   * reports on comments and chat messages, as posts already have; what
--     you reported disappears for you at once;
--   * three reports hide a post, comment or message for everyone until a
--     moderator decides (hidden_at); moderators (capability
--     community.moderate, granted in the permissions screen) see a review
--     queue and keep or remove each item;
--   * a gentle rate limit on posts, comments and messages.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.chat_messages') is null or to_regclass('public.storage_cleanup_jobs') is null then
    raise exception 'Run 0003_community.sql and 0015_reliable_operations.sql first.';
  end if;
end
$$;

create schema if not exists community_private;
revoke all on schema community_private from public;
grant usage on schema community_private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- The moderator capability. Not in the Standard owners group: the owner
-- grants it to people in the permissions screen. Permission administrators
-- get it now.
-- ---------------------------------------------------------------------------
insert into public.access_capabilities(id,feature_id,requires_view)
values ('community.moderate','community','community.feed.view')
on conflict(id) do nothing;
insert into public.user_capability_rules(user_id,capability,allowed)
select user_id,'community.moderate',true from public.access_admins
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Chat messages: replies, photos, moderation state.
-- ---------------------------------------------------------------------------
alter table public.chat_messages add column if not exists reply_to uuid references public.chat_messages(id) on delete set null;
alter table public.chat_messages add column if not exists photo_path text;
alter table public.chat_messages add column if not exists hidden_at timestamptz;
alter table public.chat_messages add column if not exists moderated_at timestamptz;

-- A message may be a photo alone: the text may then be empty.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid='public.chat_messages'::regclass and contype='c'
      and pg_get_constraintdef(oid) ilike '%body%'
      and conname <> 'chat_messages_body_or_photo'
  loop
    execute format('alter table public.chat_messages drop constraint %I', c.conname);
  end loop;
end
$$;
alter table public.chat_messages drop constraint if exists chat_messages_body_or_photo;
alter table public.chat_messages add constraint chat_messages_body_or_photo check (
  char_length(body) <= 1000 and (char_length(body) >= 1 or photo_path is not null)
);
alter table public.chat_messages drop constraint if exists chat_messages_photo_in_own_folder;
alter table public.chat_messages add constraint chat_messages_photo_in_own_folder check (
  photo_path is null or photo_path like (author_id::text || '/%')
);
create index if not exists chat_messages_reply_to_idx on public.chat_messages (reply_to);

alter table public.community_posts add column if not exists hidden_at timestamptz;
alter table public.community_posts add column if not exists moderated_at timestamptz;
alter table public.community_comments add column if not exists hidden_at timestamptz;
alter table public.community_comments add column if not exists moderated_at timestamptz;

-- ---------------------------------------------------------------------------
-- Reactions. channel_id is copied from the message so a room can follow
-- its reactions live with one filter.
-- ---------------------------------------------------------------------------
create table if not exists public.chat_message_reactions (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  channel_id text not null references public.chat_channels(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  emoji text not null check (emoji in ('👍','❤️','😂','😮','😢','🐾')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);
create index if not exists chat_message_reactions_channel_idx on public.chat_message_reactions (channel_id);
create index if not exists chat_message_reactions_user_idx on public.chat_message_reactions (user_id);

create or replace function community_private.reaction_channel()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  select m.channel_id into new.channel_id from public.chat_messages m where m.id = new.message_id;
  if new.channel_id is null then
    raise exception 'Message not found' using errcode='23503';
  end if;
  return new;
end $$;
revoke all on function community_private.reaction_channel() from public, anon, authenticated;
drop trigger if exists chat_reaction_channel on public.chat_message_reactions;
create trigger chat_reaction_channel before insert on public.chat_message_reactions
  for each row execute function community_private.reaction_channel();

-- ---------------------------------------------------------------------------
-- Read markers.
-- ---------------------------------------------------------------------------
create table if not exists public.chat_reads (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  channel_id text not null references public.chat_channels(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (user_id, channel_id)
);

-- ---------------------------------------------------------------------------
-- Blocks and reports.
-- ---------------------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

create table if not exists public.community_comment_reports (
  comment_id uuid not null references public.community_comments(id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reason text not null check (reason in ('spam','abusive','inappropriate','other')),
  created_at timestamptz not null default now(),
  primary key (comment_id, reporter_id)
);
create index if not exists community_comment_reports_reporter_idx on public.community_comment_reports (reporter_id);

create table if not exists public.chat_message_reports (
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reason text not null check (reason in ('spam','abusive','inappropriate','other')),
  created_at timestamptz not null default now(),
  primary key (message_id, reporter_id)
);
create index if not exists chat_message_reports_reporter_idx on public.chat_message_reports (reporter_id);

-- ---------------------------------------------------------------------------
-- Row level security of the new tables.
-- ---------------------------------------------------------------------------
alter table public.chat_message_reactions enable row level security;
alter table public.chat_reads enable row level security;
alter table public.user_blocks enable row level security;
alter table public.community_comment_reports enable row level security;
alter table public.chat_message_reports enable row level security;

drop policy if exists "chat_message_reactions: members can read" on public.chat_message_reactions;
create policy "chat_message_reactions: members can read" on public.chat_message_reactions
  for select to authenticated using (true);
drop policy if exists "chat_message_reactions: react as yourself" on public.chat_message_reactions;
create policy "chat_message_reactions: react as yourself" on public.chat_message_reactions
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "chat_message_reactions: remove your own" on public.chat_message_reactions;
create policy "chat_message_reactions: remove your own" on public.chat_message_reactions
  for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "chat_reads: owner" on public.chat_reads;
create policy "chat_reads: owner" on public.chat_reads
  for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "user_blocks: blocker" on public.user_blocks;
create policy "user_blocks: blocker" on public.user_blocks
  for all to authenticated using (blocker_id = (select auth.uid())) with check (blocker_id = (select auth.uid()));

-- Reports: you see and file only your own; they are kept for review.
drop policy if exists "community_comment_reports: reporter can read" on public.community_comment_reports;
create policy "community_comment_reports: reporter can read" on public.community_comment_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
drop policy if exists "community_comment_reports: report as yourself" on public.community_comment_reports;
create policy "community_comment_reports: report as yourself" on public.community_comment_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));
drop policy if exists "chat_message_reports: reporter can read" on public.chat_message_reports;
create policy "chat_message_reports: reporter can read" on public.chat_message_reports
  for select to authenticated using (reporter_id = (select auth.uid()));
drop policy if exists "chat_message_reports: report as yourself" on public.chat_message_reports;
create policy "chat_message_reports: report as yourself" on public.chat_message_reports
  for insert to authenticated with check (reporter_id = (select auth.uid()));

-- Feature permissions, as 0014 adds them to every community table.
do $$ declare row record; begin
 for row in select * from (values
  ('chat_message_reactions','(select public.can_use(''community.chat.view''))','(select public.can_use(''community.chat.send''))'),
  ('chat_message_reports','(select public.can_use(''community.chat.view''))','(select public.can_use(''community.chat.send''))'),
  ('chat_reads','(select public.can_use(''community.chat.view''))','(select public.can_use(''community.chat.view''))'),
  ('community_comment_reports','(select public.can_use(''community.feed.view''))','(select public.can_use(''community.feed.post''))')
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
-- What a member sees: never content of someone they blocked, never what
-- they reported, and content hidden by reports only when it is their own
-- (or they moderate). Restrictive, so it narrows every existing read rule;
-- community_feed and chat_room_summaries run with the caller's rights and
-- follow it too, counts included.
-- ---------------------------------------------------------------------------
drop policy if exists community_safety_read on public.community_posts;
create policy community_safety_read on public.community_posts as restrictive for select to authenticated using (
  not exists (select 1 from public.user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = community_posts.author_id)
  and (community_posts.hidden_at is null or community_posts.author_id = (select auth.uid()) or (select public.can_use('community.moderate')))
);

drop policy if exists community_safety_read on public.community_comments;
create policy community_safety_read on public.community_comments as restrictive for select to authenticated using (
  not exists (select 1 from public.user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = community_comments.author_id)
  and not exists (select 1 from public.community_comment_reports r where r.comment_id = community_comments.id and r.reporter_id = (select auth.uid()))
  and (community_comments.hidden_at is null or community_comments.author_id = (select auth.uid()) or (select public.can_use('community.moderate')))
);

drop policy if exists community_safety_read on public.chat_messages;
create policy community_safety_read on public.chat_messages as restrictive for select to authenticated using (
  not exists (select 1 from public.user_blocks b where b.blocker_id = (select auth.uid()) and b.blocked_id = chat_messages.author_id)
  and not exists (select 1 from public.chat_message_reports r where r.message_id = chat_messages.id and r.reporter_id = (select auth.uid()))
  and (chat_messages.hidden_at is null or chat_messages.author_id = (select auth.uid()) or (select public.can_use('community.moderate')))
);

-- ---------------------------------------------------------------------------
-- Three reports since the last moderator decision hide an item for
-- everyone until a moderator looks at it.
-- ---------------------------------------------------------------------------
create or replace function community_private.hide_when_reported()
returns trigger language plpgsql security definer set search_path='' as $$
declare reports integer;
begin
  if tg_table_name = 'community_reports' then
    select count(*) into reports from public.community_reports r join public.community_posts p on p.id = r.post_id
     where r.post_id = new.post_id and r.created_at > coalesce(p.moderated_at, '-infinity');
    if reports >= 3 then update public.community_posts set hidden_at = coalesce(hidden_at, now()) where id = new.post_id; end if;
  elsif tg_table_name = 'community_comment_reports' then
    select count(*) into reports from public.community_comment_reports r join public.community_comments c on c.id = r.comment_id
     where r.comment_id = new.comment_id and r.created_at > coalesce(c.moderated_at, '-infinity');
    if reports >= 3 then update public.community_comments set hidden_at = coalesce(hidden_at, now()) where id = new.comment_id; end if;
  else
    select count(*) into reports from public.chat_message_reports r join public.chat_messages m on m.id = r.message_id
     where r.message_id = new.message_id and r.created_at > coalesce(m.moderated_at, '-infinity');
    if reports >= 3 then update public.chat_messages set hidden_at = coalesce(hidden_at, now()) where id = new.message_id; end if;
  end if;
  return null;
end $$;
revoke all on function community_private.hide_when_reported() from public, anon, authenticated;
drop trigger if exists hide_when_reported on public.community_reports;
create trigger hide_when_reported after insert on public.community_reports for each row execute function community_private.hide_when_reported();
drop trigger if exists hide_when_reported on public.community_comment_reports;
create trigger hide_when_reported after insert on public.community_comment_reports for each row execute function community_private.hide_when_reported();
drop trigger if exists hide_when_reported on public.chat_message_reports;
create trigger hide_when_reported after insert on public.chat_message_reports for each row execute function community_private.hide_when_reported();

-- ---------------------------------------------------------------------------
-- Rate limit: a few posts, many comments, more messages. The app words the
-- refusal ("rate_limited") as "slow down".
-- ---------------------------------------------------------------------------
create or replace function community_private.rate_limit()
returns trigger language plpgsql security definer set search_path='' as $$
declare recent integer;
begin
  if tg_table_name = 'community_posts' then
    select count(*) into recent from public.community_posts where author_id = new.author_id and created_at > now() - interval '10 minutes';
    if recent >= 6 then raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down'; end if;
  elsif tg_table_name = 'community_comments' then
    select count(*) into recent from public.community_comments where author_id = new.author_id and created_at > now() - interval '5 minutes';
    if recent >= 20 then raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down'; end if;
  else
    select count(*) into recent from public.chat_messages where author_id = new.author_id and created_at > now() - interval '1 minute';
    if recent >= 15 then raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down'; end if;
  end if;
  return new;
end $$;
revoke all on function community_private.rate_limit() from public, anon, authenticated;
drop trigger if exists community_rate_limit on public.community_posts;
create trigger community_rate_limit before insert on public.community_posts for each row execute function community_private.rate_limit();
drop trigger if exists community_rate_limit on public.community_comments;
create trigger community_rate_limit before insert on public.community_comments for each row execute function community_private.rate_limit();
drop trigger if exists community_rate_limit on public.chat_messages;
create trigger community_rate_limit before insert on public.chat_messages for each row execute function community_private.rate_limit();

-- ---------------------------------------------------------------------------
-- Room list: each room's last message and how many messages from others
-- arrived since the member last read it (rooms never opened count the last
-- three days; at most 100 are counted).
-- ---------------------------------------------------------------------------
create or replace view public.chat_room_summaries with (security_invoker = true) as
select
  c.id as channel_id,
  m.id as last_message_id,
  m.author_id as last_author_id,
  coalesce(pr.display_name, '') as last_author_name,
  m.body as last_body,
  (m.photo_path is not null) as last_has_photo,
  m.created_at as last_message_at,
  (select count(*) from (
     select 1 from public.chat_messages u
     where u.channel_id = c.id
       and u.author_id <> (select auth.uid())
       and u.created_at > coalesce(
         (select r.last_read_at from public.chat_reads r where r.user_id = (select auth.uid()) and r.channel_id = c.id),
         now() - interval '3 days')
     limit 100) s)::integer as unread_count
from public.chat_channels c
left join lateral (
  select x.id, x.author_id, x.body, x.photo_path, x.created_at
  from public.chat_messages x where x.channel_id = c.id
  order by x.created_at desc limit 1
) m on true
left join public.profiles pr on pr.id = m.author_id;
revoke all on public.chat_room_summaries from anon;
grant select on public.chat_room_summaries to authenticated;

create or replace function public.mark_chat_read(p_channel text)
returns void language sql security invoker set search_path='' as $$
  insert into public.chat_reads(user_id, channel_id, last_read_at)
  values ((select auth.uid()), p_channel, now())
  on conflict (user_id, channel_id) do update set last_read_at = excluded.last_read_at
$$;
revoke all on function public.mark_chat_read(text) from public, anon;
grant execute on function public.mark_chat_read(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Moderation: the review queue and the decision. Moderators only.
-- ---------------------------------------------------------------------------
create table if not exists community_private.moderation_log (
  id bigint generated always as identity primary key,
  moderator_id uuid not null,
  kind text not null,
  target_id uuid not null,
  action text not null,
  created_at timestamptz not null default now()
);
alter table community_private.moderation_log enable row level security;
revoke all on community_private.moderation_log from public, anon, authenticated;

create or replace function community_private.require_moderator()
returns void language plpgsql stable security definer set search_path='' as $$
begin
  if not access_private.evaluate(auth.uid(), 'community.moderate') then
    raise exception 'Moderator access required' using errcode = '42501';
  end if;
end $$;
revoke all on function community_private.require_moderator() from public, anon, authenticated;

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
    ) q
  ), '[]'::jsonb);
end $$;
revoke all on function community_private.moderation_queue() from public, anon;
grant execute on function community_private.moderation_queue() to authenticated;

-- 'keep' clears the hiding and starts a fresh report count; 'remove'
-- deletes the item (its photo is queued for the storage clean-up).
create or replace function community_private.moderate(p_kind text, p_id uuid, p_action text)
returns void language plpgsql security definer set search_path='' as $$
begin
  perform community_private.require_moderator();
  if p_action not in ('keep', 'remove') or p_kind not in ('post', 'comment', 'message') then
    raise exception 'Unknown moderation action' using errcode = '22023';
  end if;
  if p_kind = 'post' then
    if p_action = 'keep' then update public.community_posts set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.community_posts where id = p_id; end if;
  elsif p_kind = 'comment' then
    if p_action = 'keep' then update public.community_comments set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.community_comments where id = p_id; end if;
  else
    if p_action = 'keep' then update public.chat_messages set hidden_at = null, moderated_at = now() where id = p_id;
    else delete from public.chat_messages where id = p_id; end if;
  end if;
  insert into community_private.moderation_log(moderator_id, kind, target_id, action)
  values (auth.uid(), p_kind, p_id, p_action);
end $$;
revoke all on function community_private.moderate(text, uuid, text) from public, anon;
grant execute on function community_private.moderate(text, uuid, text) to authenticated;

create or replace function public.community_moderation_queue()
returns jsonb language sql stable security invoker set search_path='' as $$ select community_private.moderation_queue() $$;
revoke all on function public.community_moderation_queue() from public, anon;
grant execute on function public.community_moderation_queue() to authenticated;
create or replace function public.community_moderate(p_kind text, p_id uuid, p_action text)
returns void language sql security invoker set search_path='' as $$ select community_private.moderate(p_kind, p_id, p_action) $$;
revoke all on function public.community_moderate(text, uuid, text) from public, anon;
grant execute on function public.community_moderate(text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Chat photos share the community-photos bucket: members who may chat may
-- read and upload there too, and the storage clean-up knows chat messages.
-- ---------------------------------------------------------------------------
drop policy if exists feature_storage_read on storage.objects;
create policy feature_storage_read on storage.objects as restrictive for select to authenticated using(
 bucket_id not in ('pet-documents','community-photos') or
 (bucket_id='pet-documents' and (select public.can_use('health.records.view'))) or
 (bucket_id='community-photos' and ((select public.can_use('community.feed.view')) or (select public.can_use('community.chat.view')))));
drop policy if exists feature_storage_upload on storage.objects;
create policy feature_storage_upload on storage.objects as restrictive for insert to authenticated with check(
 (bucket_id='pet-photos' and (select public.can_use('pets.edit'))) or
 (bucket_id='pet-documents' and (select public.can_use('health.records.edit'))) or
 (bucket_id='community-photos' and ((select public.can_use('community.feed.post')) or (select public.can_use('community.chat.send')))) or
 bucket_id not in ('pet-photos','pet-documents','community-photos'));
drop policy if exists feature_storage_update on storage.objects;
create policy feature_storage_update on storage.objects as restrictive for update to authenticated using(
 (bucket_id='pet-photos' and (select public.can_use('pets.edit'))) or
 (bucket_id='pet-documents' and (select public.can_use('health.records.edit'))) or
 (bucket_id='community-photos' and ((select public.can_use('community.feed.post')) or (select public.can_use('community.chat.send')))) or
 bucket_id not in ('pet-photos','pet-documents','community-photos')) with check(
 (bucket_id='pet-photos' and (select public.can_use('pets.edit'))) or
 (bucket_id='pet-documents' and (select public.can_use('health.records.edit'))) or
 (bucket_id='community-photos' and ((select public.can_use('community.feed.post')) or (select public.can_use('community.chat.send')))) or
 bucket_id not in ('pet-photos','pet-documents','community-photos'));

create or replace function access_private.file_is_orphan(p_bucket text,p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select case p_bucket
 when 'pet-photos' then not exists(select 1 from public.pets where photo_path=p_path)
 when 'pet-documents' then not exists(select 1 from public.health_documents where storage_path=p_path)
 when 'community-photos' then not exists(select 1 from public.community_posts where photo_path=p_path)
   and not exists(select 1 from public.chat_messages where photo_path=p_path)
 else false end
$$;

create or replace function access_private.queue_storage_cleanup(p_bucket text,p_path text,p_upload boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare job uuid;
begin
 if auth.uid() is null or p_path not like auth.uid()::text||'/%' or p_bucket not in ('pet-photos','pet-documents','community-photos') then
  raise exception 'Invalid cleanup path' using errcode='42501'; end if;
 if not access_private.file_is_orphan(p_bucket,p_path) then raise exception 'File is still in use' using errcode='23514'; end if;
 if p_upload and not (case p_bucket
   when 'pet-photos' then access_private.evaluate(auth.uid(),'pets.edit')
   when 'pet-documents' then access_private.evaluate(auth.uid(),'health.records.edit')
   else access_private.evaluate(auth.uid(),'community.feed.post') or access_private.evaluate(auth.uid(),'community.chat.send') end) then
  raise exception 'Upload permission required' using errcode='42501'; end if;
 insert into public.storage_cleanup_jobs(owner_id,bucket,path,not_before) values(auth.uid(),p_bucket,p_path,now()+case when p_upload then interval '1 hour' else interval '0' end)
 on conflict(bucket,path) do update set not_before=excluded.not_before returning id into job;
 return job;
end $$;

create or replace function access_private.queue_deleted_files()
returns trigger language plpgsql security definer set search_path='' as $$
declare bucket_name text; file_name text; owner uuid;
begin
 if tg_table_name='health_documents' then bucket_name:='pet-documents';file_name:=old.storage_path;owner:=old.owner_id;
 elsif tg_table_name='community_posts' then bucket_name:='community-photos';file_name:=old.photo_path;owner:=old.author_id;
 elsif tg_table_name='chat_messages' then bucket_name:='community-photos';file_name:=old.photo_path;owner:=old.author_id;
 else
  if tg_op='UPDATE' and new.photo_path is not distinct from old.photo_path then return null; end if;
  bucket_name:='pet-photos';file_name:=old.photo_path;owner:=old.owner_id;
 end if;
 if file_name is not null and file_name<>'' then
  insert into public.storage_cleanup_jobs(owner_id,bucket,path) values(owner,bucket_name,file_name)
  on conflict(bucket,path) do update set not_before=now();
 end if;
 return null;
end $$;
drop trigger if exists cleanup_deleted_message on public.chat_messages;
create trigger cleanup_deleted_message after delete on public.chat_messages for each row execute function access_private.queue_deleted_files();

-- ---------------------------------------------------------------------------
-- Realtime: rooms follow their reactions live.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_message_reactions'
     )
  then
    alter publication supabase_realtime add table public.chat_message_reactions;
  end if;
end
$$;

commit;
