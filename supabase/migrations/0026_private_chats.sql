-- PetLoop: private chats in the Community. Apply after 0025.
--
--   * chat_channels: a channel is a topic room (as before) or a private
--     chat (kind 'private', a UUID id, made by a member). A private chat of
--     two people without a name is a direct chat (direct_key names the two
--     accounts, so the same two never get a second one).
--   * chat_channel_members: who is in a private chat, as admin or member,
--     invited or joined, and whether they muted it. Written only by the
--     functions below, which enforce the rules:
--       - an invitee accepts first; until then they see nothing of the chat;
--       - only admins invite, rename, remove and make admins; the creator
--         is the first admin; anyone can leave;
--       - up to 30 participants (invited and joined);
--       - the last admin leaving makes the earliest-joined member admin;
--         the last member leaving deletes the chat;
--       - nobody invites a member they blocked or who blocked them;
--       - a direct chat with a block between the two is closed;
--       - 10 new chats and 30 invitations per account per day.
--   * Visibility: messages, reactions, read markers and reports of a
--     private chat are for its joined members, and only from the moment
--     they were brought in (the invitation, so a first message written
--     before the other person accepted reaches them). Someone who left or
--     was removed sees nothing of it. Topic rooms are unchanged. Realtime,
--     the room summaries and the push triggers follow the same rules.
--   * System lines ("Dana added Ron") are chat messages with `system` set;
--     only the functions below write them.
--   * Push: kinds 'message' (private messages, on by default; consecutive
--     messages of a chat count up in one notification; a muted chat sends
--     nothing) and 'invite' (on by default).
--   * The capability community.chat.private ("Private chats"), allowed for
--     every account through the Standard owners group, so an
--     administrator can switch it off for one account.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.push_outbox') is null or to_regclass('public.chat_message_reactions') is null then
    raise exception 'Run 0021_community_chat_safety.sql and 0023_community_push.sql first.';
  end if;
end
$$;

create schema if not exists community_private;

-- ---------------------------------------------------------------------------
-- The capability, allowed for everyone by default.
-- ---------------------------------------------------------------------------
insert into public.access_capabilities(id,feature_id,requires_view)
values ('community.chat.private','community','community.chat.view')
on conflict(id) do nothing;
insert into public.group_capability_rules(group_id,capability,allowed)
values ('acc35500-0000-4000-8000-000000000001','community.chat.private',true)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Channels: topic rooms and private chats.
-- ---------------------------------------------------------------------------
alter table public.chat_channels add column if not exists kind text not null default 'topic';
alter table public.chat_channels drop constraint if exists chat_channels_kind_check;
alter table public.chat_channels add constraint chat_channels_kind_check check (kind in ('topic', 'private'));
alter table public.chat_channels add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.chat_channels add column if not exists direct_key text;
create unique index if not exists chat_channels_direct_key_idx on public.chat_channels (direct_key) where direct_key is not null;
create index if not exists chat_channels_kind_idx on public.chat_channels (kind);

-- A private chat may have no name (a direct chat shows the other person).
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.chat_channels'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%name%'
      and conname <> 'chat_channels_name_length'
  loop
    execute format('alter table public.chat_channels drop constraint %I', c.conname);
  end loop;
end
$$;
alter table public.chat_channels drop constraint if exists chat_channels_name_length;
alter table public.chat_channels add constraint chat_channels_name_length check (
  char_length(name) <= 40 and (char_length(name) >= 1 or kind = 'private')
);
alter table public.chat_channels drop constraint if exists chat_channels_direct_private;
alter table public.chat_channels add constraint chat_channels_direct_private check (
  direct_key is null or kind = 'private'
);

-- ---------------------------------------------------------------------------
-- Members of private chats.
-- ---------------------------------------------------------------------------
create table if not exists public.chat_channel_members (
  channel_id text not null references public.chat_channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  status text not null default 'invited' check (status in ('invited', 'joined')),
  invited_by uuid references auth.users(id) on delete set null,
  -- When the member was brought in: their history starts here.
  invited_at timestamptz not null default now(),
  joined_at timestamptz,
  muted boolean not null default false,
  primary key (channel_id, user_id),
  check ((status = 'joined') = (joined_at is not null))
);
create index if not exists chat_channel_members_user_idx on public.chat_channel_members (user_id, status);
alter table public.chat_channel_members enable row level security;
revoke insert, update, delete on public.chat_channel_members from anon, authenticated;

-- What happened, for the daily limits (kept two days).
create table if not exists community_private.private_chat_log (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  action text not null check (action in ('create', 'invite')),
  created_at timestamptz not null default now()
);
create index if not exists private_chat_log_user_idx on community_private.private_chat_log (user_id, action, created_at);
alter table community_private.private_chat_log enable row level security;
revoke all on community_private.private_chat_log from public, anon, authenticated;

-- System lines: who created, added, joined, left, was removed, became
-- admin, or what the chat was renamed to.
alter table public.chat_messages add column if not exists system jsonb;
alter table public.chat_messages drop constraint if exists chat_messages_system_shape;
alter table public.chat_messages add constraint chat_messages_system_shape check (
  system is null or (jsonb_typeof(system) = 'object' and system ? 'event')
);
alter table public.chat_messages drop constraint if exists chat_messages_body_or_photo;
alter table public.chat_messages add constraint chat_messages_body_or_photo check (
  char_length(body) <= 1000 and (char_length(body) >= 1 or photo_path is not null or system is not null)
);

-- ---------------------------------------------------------------------------
-- Helpers for the rules. Security definer, so the policies can ask about
-- membership without reading chat_channel_members through its own rules.
-- ---------------------------------------------------------------------------

-- From when the signed-in member may read [p_channel]: '-infinity' for a
-- topic room; for a private chat the moment a joined member was brought in
-- (null when not joined, or when private chats are switched off for them).
create or replace function community_private.chat_visible_from(p_channel text, p_private boolean)
returns timestamptz language sql stable security definer set search_path = '' as $$
  select case
    when c.kind = 'topic' then '-infinity'::timestamptz
    when not coalesce(p_private, false) then null
    else (select m.invited_at from public.chat_channel_members m
          where m.channel_id = c.id and m.user_id = auth.uid() and m.status = 'joined')
  end
  from public.chat_channels c where c.id = p_channel
$$;
revoke all on function community_private.chat_visible_from(text, boolean) from public, anon;
grant execute on function community_private.chat_visible_from(text, boolean) to authenticated, service_role;

-- Whether the signed-in member may read [p_message] under the private chat
-- rules (the other safety rules are applied by chat_messages' policies).
create or replace function community_private.chat_message_open(p_message uuid, p_private boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select m.created_at >= community_private.chat_visible_from(m.channel_id, p_private)
    from public.chat_messages m where m.id = p_message
  ), false)
$$;
revoke all on function community_private.chat_message_open(uuid, boolean) from public, anon;
grant execute on function community_private.chat_message_open(uuid, boolean) to authenticated, service_role;

-- The other person of a direct chat, seen from [p_user].
create or replace function community_private.direct_other(p_key text, p_user uuid)
returns uuid language sql immutable set search_path = '' as $$
  select case
    when p_key is null then null
    when split_part(p_key, ':', 1) = p_user::text then split_part(p_key, ':', 2)::uuid
    else split_part(p_key, ':', 1)::uuid
  end
$$;
revoke all on function community_private.direct_other(text, uuid) from public, anon;
grant execute on function community_private.direct_other(text, uuid) to authenticated, service_role;

create or replace function community_private.blocked_between(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a)
  )
$$;
revoke all on function community_private.blocked_between(uuid, uuid) from public, anon, authenticated;

-- A direct chat with a block between the two is closed.
create or replace function community_private.chat_closed(p_channel text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select c.direct_key is not null and community_private.blocked_between(
      split_part(c.direct_key, ':', 1)::uuid, split_part(c.direct_key, ':', 2)::uuid)
    from public.chat_channels c where c.id = p_channel
  ), false)
$$;
revoke all on function community_private.chat_closed(text) from public, anon;
grant execute on function community_private.chat_closed(text) to authenticated, service_role;

-- Whether the signed-in member may write in [p_channel]: anyone in a topic
-- room, a joined member in an open private chat.
create or replace function community_private.chat_can_post(p_channel text, p_private boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when c.kind = 'topic' then true
      else coalesce(p_private, false)
        and exists (select 1 from public.chat_channel_members m
                    where m.channel_id = c.id and m.user_id = auth.uid() and m.status = 'joined')
        and not community_private.chat_closed(c.id)
    end
    from public.chat_channels c where c.id = p_channel
  ), false)
$$;
revoke all on function community_private.chat_can_post(text, boolean) from public, anon;
grant execute on function community_private.chat_can_post(text, boolean) to authenticated, service_role;

-- The signed-in member's place in a private chat: 'joined', 'invited' or
-- null.
create or replace function community_private.chat_status(p_channel text)
returns text language sql stable security definer set search_path = '' as $$
  select m.status from public.chat_channel_members m
  where m.channel_id = p_channel and m.user_id = auth.uid()
$$;
revoke all on function community_private.chat_status(text) from public, anon;
grant execute on function community_private.chat_status(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Row level security.
-- ---------------------------------------------------------------------------

-- Channels: a private chat only for its joined members.
drop policy if exists private_chat_read on public.chat_channels;
create policy private_chat_read on public.chat_channels as restrictive for select to authenticated using (
  chat_channels.kind = 'topic'
  or community_private.chat_visible_from(chat_channels.id, (select public.can_use('community.chat.private'))) is not null
);

-- Members: your own rows (an invitation), and everyone in a chat you joined.
drop policy if exists "chat_channel_members: own and fellow members" on public.chat_channel_members;
create policy "chat_channel_members: own and fellow members" on public.chat_channel_members
  for select to authenticated using (
    chat_channel_members.user_id = (select auth.uid())
    or community_private.chat_status(chat_channel_members.channel_id) = 'joined'
  );
drop policy if exists feature_read on public.chat_channel_members;
create policy feature_read on public.chat_channel_members as restrictive for select to authenticated
  using ((select public.can_use('community.chat.private')));

-- Messages: a private chat's from the moment the reader was brought in;
-- only joined members of an open chat write there; system lines only
-- through the functions below.
drop policy if exists private_chat_read on public.chat_messages;
create policy private_chat_read on public.chat_messages as restrictive for select to authenticated using (
  chat_messages.created_at >= coalesce(
    community_private.chat_visible_from(chat_messages.channel_id, (select public.can_use('community.chat.private'))),
    'infinity'::timestamptz)
);
drop policy if exists private_chat_write on public.chat_messages;
create policy private_chat_write on public.chat_messages as restrictive for insert to authenticated with check (
  chat_messages.system is null
  and community_private.chat_can_post(chat_messages.channel_id, (select public.can_use('community.chat.private')))
);
drop policy if exists private_chat_update on public.chat_messages;
create policy private_chat_update on public.chat_messages as restrictive for update to authenticated
  using (chat_messages.system is null) with check (chat_messages.system is null);
drop policy if exists private_chat_delete on public.chat_messages;
create policy private_chat_delete on public.chat_messages as restrictive for delete to authenticated
  using (chat_messages.system is null);

-- Reactions and reports follow their message.
drop policy if exists private_chat_read on public.chat_message_reactions;
create policy private_chat_read on public.chat_message_reactions as restrictive for select to authenticated using (
  community_private.chat_message_open(chat_message_reactions.message_id, (select public.can_use('community.chat.private')))
);
drop policy if exists private_chat_write on public.chat_message_reactions;
create policy private_chat_write on public.chat_message_reactions as restrictive for insert to authenticated with check (
  community_private.chat_message_open(chat_message_reactions.message_id, (select public.can_use('community.chat.private')))
);
drop policy if exists private_chat_write on public.chat_message_reports;
create policy private_chat_write on public.chat_message_reports as restrictive for insert to authenticated with check (
  community_private.chat_message_open(chat_message_reports.message_id, (select public.can_use('community.chat.private')))
);

-- Read markers: only for a room the member can read.
drop policy if exists private_chat_reads on public.chat_reads;
create policy private_chat_reads on public.chat_reads as restrictive for all to authenticated
  using (community_private.chat_visible_from(chat_reads.channel_id, (select public.can_use('community.chat.private'))) is not null)
  with check (community_private.chat_visible_from(chat_reads.channel_id, (select public.can_use('community.chat.private'))) is not null);

-- ---------------------------------------------------------------------------
-- System lines do not count against the message rate limit (0021).
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
    if new.system is not null then return new; end if;
    select count(*) into recent from public.chat_messages
    where author_id = new.author_id and system is null and created_at > now() - interval '1 minute';
    if recent >= 15 then raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down'; end if;
  end if;
  return new;
end $$;
revoke all on function community_private.rate_limit() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Room list (0021) with the channel's kind and a system line as the last
-- message; system lines are not unread messages.
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
       and u.system is null
       and u.created_at > coalesce(
         (select r.last_read_at from public.chat_reads r where r.user_id = (select auth.uid()) and r.channel_id = c.id),
         now() - interval '3 days')
     limit 100) s)::integer as unread_count,
  c.kind,
  m.system as last_system
from public.chat_channels c
left join lateral (
  select x.id, x.author_id, x.body, x.photo_path, x.created_at, x.system
  from public.chat_messages x where x.channel_id = c.id
  order by x.created_at desc limit 1
) m on true
left join public.profiles pr on pr.id = m.author_id;
revoke all on public.chat_room_summaries from anon;
grant select on public.chat_room_summaries to authenticated;

-- ---------------------------------------------------------------------------
-- What the functions share.
-- ---------------------------------------------------------------------------
create or replace function community_private.require_private_chats()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  if not access_private.evaluate(me, 'community.chat.private') then
    raise exception 'Private chats are not available for this account' using errcode = '42501';
  end if;
  return me;
end $$;
revoke all on function community_private.require_private_chats() from public, anon, authenticated;

-- The signed-in member must be a joined admin of the private chat.
create or replace function community_private.require_chat_admin(p_channel text)
returns public.chat_channels language plpgsql stable security definer set search_path = '' as $$
declare me uuid := community_private.require_private_chats(); channel public.chat_channels;
begin
  select * into channel from public.chat_channels where id = p_channel and kind = 'private';
  if not found or not exists (
    select 1 from public.chat_channel_members m
    where m.channel_id = p_channel and m.user_id = me and m.status = 'joined'
  ) then
    raise exception 'Not a member of this chat' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.chat_channel_members m
    where m.channel_id = p_channel and m.user_id = me and m.status = 'joined' and m.role = 'admin'
  ) then
    raise exception 'not_chat_admin' using errcode = '42501', hint = 'not_chat_admin';
  end if;
  return channel;
end $$;
revoke all on function community_private.require_chat_admin(text) from public, anon, authenticated;

create or replace function community_private.system_line(p_channel text, p_actor uuid, p_line jsonb)
returns void language sql security definer set search_path = '' as $$
  insert into public.chat_messages(channel_id, author_id, body, system)
  values (p_channel, p_actor, '', p_line)
$$;
revoke all on function community_private.system_line(text, uuid, jsonb) from public, anon, authenticated;

-- Counts against the daily limits; refuses beyond them.
create or replace function community_private.chat_limit(p_user uuid, p_action text, p_count integer)
returns void language plpgsql security definer set search_path = '' as $$
declare used integer; allowed integer := case p_action when 'create' then 10 else 30 end;
begin
  delete from community_private.private_chat_log where created_at < now() - interval '2 days';
  select count(*) into used from community_private.private_chat_log
  where user_id = p_user and action = p_action and created_at > now() - interval '1 day';
  if used + p_count > allowed then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  insert into community_private.private_chat_log(user_id, action)
  select p_user, p_action from generate_series(1, p_count);
end $$;
revoke all on function community_private.chat_limit(uuid, text, integer) from public, anon, authenticated;

-- Adds invitations to a chat, after checking each person. Returns who was
-- invited.
create or replace function community_private.invite_people(p_channel text, p_me uuid, p_users uuid[])
returns uuid[] language plpgsql security definer set search_path = '' as $$
declare person uuid; invited uuid[] := '{}'; present integer;
begin
  foreach person in array coalesce(p_users, '{}') loop
    if person is null or person = p_me or person = any(invited) then continue; end if;
    if exists (select 1 from public.chat_channel_members m where m.channel_id = p_channel and m.user_id = person) then
      continue;
    end if;
    if not exists (select 1 from auth.users u where u.id = person) then
      raise exception 'cannot_invite' using errcode = '42501', hint = 'cannot_invite';
    end if;
    if community_private.blocked_between(p_me, person)
       or not access_private.evaluate(person, 'community.chat.private') then
      raise exception 'cannot_invite' using errcode = '42501', hint = 'cannot_invite';
    end if;
    invited := invited || person;
  end loop;
  select count(*) into present from public.chat_channel_members m where m.channel_id = p_channel;
  if present + coalesce(array_length(invited, 1), 0) > 30 then
    raise exception 'chat_full' using errcode = '23514', hint = 'chat_full';
  end if;
  if coalesce(array_length(invited, 1), 0) > 0 then
    perform community_private.chat_limit(p_me, 'invite', array_length(invited, 1));
    insert into public.chat_channel_members(channel_id, user_id, role, status, invited_by, invited_at)
    select p_channel, u, 'member', 'invited', p_me, now() from unnest(invited) as u;
  end if;
  return invited;
end $$;
revoke all on function community_private.invite_people(text, uuid, uuid[]) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The functions the app calls.
-- ---------------------------------------------------------------------------

-- Starts a chat with [p_invitees]. One person and no name: the direct chat
-- of the two, reopened when it exists (whoever left is brought back).
-- Returns the chat's id.
create or replace function public.create_private_chat(p_invitees uuid[], p_name text default '')
returns text language plpgsql security definer set search_path = '' as $$
declare
  me uuid := community_private.require_private_chats();
  people uuid[];
  chat_name text := btrim(coalesce(p_name, ''));
  other uuid;
  key text;
  existing public.chat_channels;
  channel text;
  added uuid[];
begin
  select coalesce(array_agg(distinct u), '{}') into people
  from unnest(coalesce(p_invitees, '{}')) as u where u is not null and u <> me;
  if coalesce(array_length(people, 1), 0) = 0 then
    raise exception 'Choose someone to chat with' using errcode = '22023';
  end if;
  if char_length(chat_name) > 40 then
    raise exception 'The name is too long' using errcode = '23514';
  end if;
  if array_length(people, 1) + 1 > 30 then
    raise exception 'chat_full' using errcode = '23514', hint = 'chat_full';
  end if;

  if array_length(people, 1) = 1 and chat_name = '' then
    other := people[1];
    key := least(me::text, other::text) || ':' || greatest(me::text, other::text);
    select * into existing from public.chat_channels where direct_key = key;
    if found then
      if community_private.blocked_between(me, other) then
        raise exception 'cannot_invite' using errcode = '42501', hint = 'cannot_invite';
      end if;
      -- Back in it: my own invitation is accepted, or I return after
      -- leaving; the other person is invited again if they left.
      update public.chat_channel_members set status = 'joined', joined_at = now()
      where channel_id = existing.id and user_id = me and status = 'invited';
      if not exists (select 1 from public.chat_channel_members where channel_id = existing.id and user_id = me) then
        insert into public.chat_channel_members(channel_id, user_id, role, status, invited_by, invited_at, joined_at)
        values (existing.id, me, 'admin', 'joined', me, now(), now());
      end if;
      perform community_private.invite_people(existing.id, me, array[other]);
      return existing.id;
    end if;
  end if;

  perform community_private.chat_limit(me, 'create', 1);
  channel := gen_random_uuid()::text;
  insert into public.chat_channels(id, name, description, kind, created_by, direct_key, sort_order)
  values (channel, case when key is null then chat_name else '' end, '', 'private', me, key, 0);
  insert into public.chat_channel_members(channel_id, user_id, role, status, invited_by, invited_at, joined_at)
  values (channel, me, 'admin', 'joined', me, now(), now());
  added := community_private.invite_people(channel, me, people);
  if key is null then
    perform community_private.system_line(channel, me, jsonb_build_object('event', 'created'));
    perform community_private.system_line(channel, me, jsonb_build_object('event', 'added', 'users', to_jsonb(added)));
  end if;
  return channel;
end $$;
revoke all on function public.create_private_chat(uuid[], text) from public, anon;
grant execute on function public.create_private_chat(uuid[], text) to authenticated;

-- An admin invites more people to a group chat.
create or replace function public.invite_to_private_chat(p_channel text, p_users uuid[])
returns void language plpgsql security definer set search_path = '' as $$
declare channel public.chat_channels := community_private.require_chat_admin(p_channel); added uuid[];
begin
  if channel.direct_key is not null then
    raise exception 'A chat of two cannot take more people' using errcode = '22023';
  end if;
  added := community_private.invite_people(p_channel, auth.uid(), p_users);
  if coalesce(array_length(added, 1), 0) > 0 then
    perform community_private.system_line(p_channel, auth.uid(), jsonb_build_object('event', 'added', 'users', to_jsonb(added)));
  end if;
end $$;
revoke all on function public.invite_to_private_chat(text, uuid[]) from public, anon;
grant execute on function public.invite_to_private_chat(text, uuid[]) to authenticated;

-- The invitee joins, or says no thanks (the invitation is dropped).
create or replace function public.answer_chat_invitation(p_channel text, p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := community_private.require_private_chats(); is_direct boolean;
begin
  if not exists (
    select 1 from public.chat_channel_members m
    where m.channel_id = p_channel and m.user_id = me and m.status = 'invited'
  ) then
    raise exception 'No invitation to this chat' using errcode = '42501';
  end if;
  if not coalesce(p_accept, false) then
    delete from public.chat_channel_members where channel_id = p_channel and user_id = me;
    return;
  end if;
  update public.chat_channel_members set status = 'joined', joined_at = now()
  where channel_id = p_channel and user_id = me;
  select c.direct_key is not null into is_direct from public.chat_channels c where c.id = p_channel;
  if not is_direct then
    perform community_private.system_line(p_channel, me, jsonb_build_object('event', 'joined'));
  end if;
end $$;
revoke all on function public.answer_chat_invitation(text, boolean) from public, anon;
grant execute on function public.answer_chat_invitation(text, boolean) to authenticated;

-- Leaves a chat. Whoever leaves loses the whole chat.
create or replace function public.leave_private_chat(p_channel text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); place text;
begin
  if me is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  select m.status into place from public.chat_channel_members m where m.channel_id = p_channel and m.user_id = me;
  if place is null then
    raise exception 'Not a member of this chat' using errcode = '42501';
  end if;
  if place = 'joined' then
    perform community_private.system_line(p_channel, me, jsonb_build_object('event', 'left'));
  end if;
  delete from public.chat_reads where channel_id = p_channel and user_id = me;
  delete from public.chat_channel_members where channel_id = p_channel and user_id = me;
end $$;
revoke all on function public.leave_private_chat(text) from public, anon;
grant execute on function public.leave_private_chat(text) to authenticated;

-- An admin removes a member, or takes back an invitation.
create or replace function public.remove_from_private_chat(p_channel text, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare channel public.chat_channels := community_private.require_chat_admin(p_channel); place text;
begin
  if p_user = auth.uid() then
    raise exception 'Leave the chat instead' using errcode = '22023';
  end if;
  if channel.direct_key is not null then
    raise exception 'Nobody is removed from a chat of two' using errcode = '22023';
  end if;
  select m.status into place from public.chat_channel_members m where m.channel_id = p_channel and m.user_id = p_user;
  if place is null then return; end if;
  if place = 'joined' then
    perform community_private.system_line(p_channel, auth.uid(),
      jsonb_build_object('event', 'removed', 'users', jsonb_build_array(p_user)));
  end if;
  delete from public.chat_reads where channel_id = p_channel and user_id = p_user;
  delete from public.chat_channel_members where channel_id = p_channel and user_id = p_user;
end $$;
revoke all on function public.remove_from_private_chat(text, uuid) from public, anon;
grant execute on function public.remove_from_private_chat(text, uuid) to authenticated;

-- An admin makes a joined member admin too.
create or replace function public.make_private_chat_admin(p_channel text, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare channel public.chat_channels := community_private.require_chat_admin(p_channel);
begin
  update public.chat_channel_members set role = 'admin'
  where channel_id = channel.id and user_id = p_user and status = 'joined' and role <> 'admin';
  if found then
    perform community_private.system_line(p_channel, auth.uid(),
      jsonb_build_object('event', 'admin', 'users', jsonb_build_array(p_user)));
  elsif not exists (
    select 1 from public.chat_channel_members
    where channel_id = channel.id and user_id = p_user and status = 'joined'
  ) then
    raise exception 'Only a member who joined can be admin' using errcode = '22023';
  end if;
end $$;
revoke all on function public.make_private_chat_admin(text, uuid) from public, anon;
grant execute on function public.make_private_chat_admin(text, uuid) to authenticated;

-- An admin renames a group chat.
create or replace function public.rename_private_chat(p_channel text, p_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare channel public.chat_channels := community_private.require_chat_admin(p_channel); chat_name text := btrim(coalesce(p_name, ''));
begin
  if channel.direct_key is not null then
    raise exception 'A chat of two has no name' using errcode = '22023';
  end if;
  if char_length(chat_name) not between 1 and 40 then
    raise exception 'A name of 1 to 40 characters' using errcode = '23514';
  end if;
  if chat_name = channel.name then return; end if;
  update public.chat_channels set name = chat_name where id = channel.id;
  perform community_private.system_line(p_channel, auth.uid(), jsonb_build_object('event', 'renamed', 'name', chat_name));
end $$;
revoke all on function public.rename_private_chat(text, text) from public, anon;
grant execute on function public.rename_private_chat(text, text) to authenticated;

-- Mutes or unmutes a chat for the signed-in member: no pushes from it.
create or replace function public.set_private_chat_muted(p_channel text, p_muted boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := community_private.require_private_chats();
begin
  update public.chat_channel_members set muted = coalesce(p_muted, false)
  where channel_id = p_channel and user_id = me and status = 'joined';
  if not found then
    raise exception 'Not a member of this chat' using errcode = '42501';
  end if;
end $$;
revoke all on function public.set_private_chat_muted(text, boolean) from public, anon;
grant execute on function public.set_private_chat_muted(text, boolean) to authenticated;

-- The signed-in member's private chats with their members, newest activity
-- first; `closed` for a direct chat with a block between the two.
create or replace function public.my_private_chats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, 'community.chat.private') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(item order by active desc)
    from (
      select greatest(c.created_at, mine.invited_at,
               coalesce((select max(x.created_at) from public.chat_messages x where x.channel_id = c.id), '-infinity')) as active,
        jsonb_build_object(
          'id', c.id, 'name', c.name, 'created_by', c.created_by, 'created_at', c.created_at,
          'direct_with', community_private.direct_other(c.direct_key, me),
          'direct_name', coalesce((select p.display_name from public.profiles p
                                   where p.id = community_private.direct_other(c.direct_key, me)), ''),
          'muted', mine.muted,
          'closed', community_private.chat_closed(c.id),
          'members', (
            select jsonb_agg(jsonb_build_object(
              'user_id', m.user_id, 'name', coalesce(p.display_name, ''), 'role', m.role,
              'status', m.status, 'invited_by', m.invited_by, 'invited_at', m.invited_at,
              'joined_at', m.joined_at) order by m.joined_at nulls last, m.invited_at)
            from public.chat_channel_members m left join public.profiles p on p.id = m.user_id
            where m.channel_id = c.id)
        ) as item
      from public.chat_channel_members mine
      join public.chat_channels c on c.id = mine.channel_id
      where mine.user_id = me and mine.status = 'joined'
    ) chats
  ), '[]'::jsonb);
end $$;
revoke all on function public.my_private_chats() from public, anon;
grant execute on function public.my_private_chats() to authenticated;

-- Invitations waiting for the signed-in member: what the card shows, and
-- nothing else of the chat. Not from someone they blocked.
create or replace function public.my_chat_invitations()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null or not access_private.evaluate(me, 'community.chat.private') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'channel_id', c.id, 'name', c.name, 'direct', c.direct_key is not null,
      'inviter_id', m.invited_by, 'inviter_name', coalesce(p.display_name, ''),
      'participants', (select count(*) from public.chat_channel_members x where x.channel_id = c.id),
      'invited_at', m.invited_at) order by m.invited_at desc)
    from public.chat_channel_members m
    join public.chat_channels c on c.id = m.channel_id
    left join public.profiles p on p.id = m.invited_by
    where m.user_id = me and m.status = 'invited'
      and not exists (select 1 from public.user_blocks b where b.blocker_id = me and b.blocked_id = m.invited_by)
  ), '[]'::jsonb);
end $$;
revoke all on function public.my_chat_invitations() from public, anon;
grant execute on function public.my_chat_invitations() to authenticated;

-- People to start a chat with: those the member talked with recently
-- first (private chats, answers either way), then everyone by name. Never
-- the member, anyone blocked either way, or anyone without private chats.
create or replace function public.chat_people(p_search text default '', p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  me uuid := community_private.require_private_chats();
  words text := btrim(coalesce(p_search, ''));
  pattern text := '%' || replace(replace(replace(btrim(coalesce(p_search, '')), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  return coalesce((
    with recent as (
      select o.user_id as id,
             greatest(c.created_at, coalesce((select max(x.created_at) from public.chat_messages x where x.channel_id = c.id), '-infinity')) as at
      from public.chat_channel_members mine
      join public.chat_channel_members o on o.channel_id = mine.channel_id and o.user_id <> me
      join public.chat_channels c on c.id = mine.channel_id
      where mine.user_id = me and mine.status = 'joined'
      union all
      select x.author_id, x.created_at from public.chat_messages x
      join public.chat_messages o on o.id = x.reply_to
      where o.author_id = me and x.author_id <> me and x.system is null and x.created_at > now() - interval '60 days'
      union all
      select o.author_id, x.created_at from public.chat_messages x
      join public.chat_messages o on o.id = x.reply_to
      where x.author_id = me and o.author_id <> me and o.system is null and x.created_at > now() - interval '60 days'
    ), latest as (
      select id, max(at) as at from recent group by id
    ), matches as (
      select p.id, coalesce(p.display_name, '') as name, coalesce(p.city, '') as city, l.at
      from public.profiles p
      left join latest l on l.id = p.id
      where p.id <> me
        and (words = '' or p.display_name ilike pattern escape '\')
        and not community_private.blocked_between(me, p.id)
        and access_private.evaluate(p.id, 'community.chat.private')
      order by l.at desc nulls last, lower(coalesce(p.display_name, '')), p.id
      limit greatest(1, least(coalesce(p_limit, 40), 100))
    )
    select jsonb_agg(jsonb_build_object('id', f.id, 'name', f.name, 'city', f.city, 'recent', f.at is not null)
                     order by f.at desc nulls last, lower(f.name), f.id)
    from matches f
  ), '[]'::jsonb);
end $$;
revoke all on function public.chat_people(text, integer) from public, anon;
grant execute on function public.chat_people(text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- After someone leaves, is removed or deletes their account: the last
-- member leaving deletes the chat; the last admin leaving makes the
-- earliest-joined member admin.
-- ---------------------------------------------------------------------------
create or replace function community_private.after_member_gone()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.chat_channels where id = old.channel_id) then
    return null;
  end if;
  if not exists (select 1 from public.chat_channel_members where channel_id = old.channel_id and status = 'joined') then
    delete from public.chat_channels where id = old.channel_id and kind = 'private';
    return null;
  end if;
  if not exists (
    select 1 from public.chat_channel_members
    where channel_id = old.channel_id and status = 'joined' and role = 'admin'
  ) then
    update public.chat_channel_members set role = 'admin'
    where (channel_id, user_id) = (
      select m.channel_id, m.user_id from public.chat_channel_members m
      where m.channel_id = old.channel_id and m.status = 'joined'
      order by m.joined_at, m.invited_at, m.user_id limit 1
    );
  end if;
  return null;
end $$;
revoke all on function community_private.after_member_gone() from public, anon, authenticated;
drop trigger if exists after_member_gone on public.chat_channel_members;
create trigger after_member_gone after delete on public.chat_channel_members
  for each row execute function community_private.after_member_gone();

-- ---------------------------------------------------------------------------
-- Push: private messages and invitations.
-- ---------------------------------------------------------------------------
alter table public.push_preferences add column if not exists private_messages boolean not null default true;
alter table public.push_preferences add column if not exists chat_invites boolean not null default true;

alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('comment', 'like', 'reply', 'message', 'invite'));
-- How many unread messages a 'message' notification stands for.
alter table public.push_outbox add column if not exists count integer not null default 1;

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
       else 'community.feed.view' end) then
    return;
  end if;
  select case p_kind
      when 'reply' then p.replies when 'comment' then p.comments
      when 'message' then p.private_messages when 'invite' then p.chat_invites
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

create or replace function community_private.push_on_insert()
returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid; preview text; channel_kind text; member record;
begin
  if tg_table_name = 'community_comments' then
    select p.author_id into recipient from public.community_posts p where p.id = new.post_id;
    perform community_private.enqueue_push(recipient, 'comment', new.author_id, 'post:' || new.post_id, new.body);
  elsif tg_table_name = 'community_post_likes' then
    select p.author_id, p.body into recipient, preview from public.community_posts p where p.id = new.post_id;
    perform community_private.enqueue_push(recipient, 'like', new.user_id, 'post:' || new.post_id, preview);
  elsif tg_table_name = 'chat_channel_members' then
    if new.status = 'invited' then
      select c.name into preview from public.chat_channels c where c.id = new.channel_id;
      perform community_private.enqueue_push(new.user_id, 'invite', new.invited_by, 'room:' || new.channel_id, preview);
    end if;
  else
    if new.system is not null then return null; end if;
    select c.kind into channel_kind from public.chat_channels c where c.id = new.channel_id;
    if channel_kind = 'private' then
      -- Every joined member but the author, unless they muted the chat.
      for member in
        select m.user_id from public.chat_channel_members m
        where m.channel_id = new.channel_id and m.status = 'joined'
          and m.user_id <> new.author_id and not m.muted
      loop
        perform community_private.enqueue_push(member.user_id, 'message', new.author_id, 'room:' || new.channel_id, new.body);
      end loop;
    elsif new.reply_to is not null then
      select m.author_id into recipient from public.chat_messages m where m.id = new.reply_to;
      perform community_private.enqueue_push(recipient, 'reply', new.author_id, 'room:' || new.channel_id, new.body);
    end if;
  end if;
  return null;
end $$;
revoke all on function community_private.push_on_insert() from public, anon, authenticated;

-- Every chat message now (private chats notify without a reply).
drop trigger if exists push_on_reply on public.chat_messages;
drop trigger if exists push_on_chat_message on public.chat_messages;
create trigger push_on_chat_message after insert on public.chat_messages
  for each row execute function community_private.push_on_insert();
drop trigger if exists push_on_invite on public.chat_channel_members;
create trigger push_on_invite after insert on public.chat_channel_members
  for each row when (new.status = 'invited') execute function community_private.push_on_insert();

-- The claim (0023) also carries the count, and the chat's name and whether
-- it is a chat of two, for the words of 'message' and 'invite'.
create or replace function public.push_claim(p_limit integer default 100)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
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
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object('token', d.token, 'platform', d.platform, 'language', d.language))
      from public.push_devices d where d.user_id = c.recipient_id), '[]'::jsonb)
  ) order by c.id), '[]'::jsonb)
  into result
  from claimed c
  left join public.profiles pr on pr.id = c.actor_id
  left join public.chat_channels ch on c.kind in ('message', 'invite') and ch.id = substr(c.target, 6);
  return result;
end $$;
revoke all on function public.push_claim(integer) from public, anon, authenticated;
grant execute on function public.push_claim(integer) to service_role;

commit;
