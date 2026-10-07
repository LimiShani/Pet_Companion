-- PetLoop: push notifications for community activity. Apply after 0022.
--
--   * push_devices: the phones an account receives notifications on (an
--     FCM token, the phone's platform and the app's language), written
--     through register_push_device() / unregister_push_device();
--   * push_preferences: what a member wants to hear about (answers to
--     their chat messages and comments on their posts are on, likes are
--     off unless switched on);
--   * push_outbox: what is waiting to be sent, filled by triggers on new
--     comments, likes and chat answers, and emptied by the Edge Function
--     `community-push` (service role) through push_claim() / push_finish().
--
-- Nothing is queued for one's own doings, for someone the recipient
-- blocked, for a kind the recipient switched off, without access to the
-- feature, or for an account without a phone. Likes of one post are told
-- at most once an hour.
--
-- Each queued row pokes the function at once through pg_net when the Vault
-- holds `push_project_url` and `push_job_secret` (see
-- supabase/scheduling/community_push.sql); without them rows wait for the
-- next scheduled run. A failed poke never fails the comment, like or
-- message that caused it.
--
-- Additive and idempotent.
begin;

do $$
begin
  if to_regclass('public.chat_message_reactions') is null then
    raise exception 'Run 0021_community_chat_safety.sql first.';
  end if;
end
$$;

create schema if not exists community_private;

-- ---------------------------------------------------------------------------
-- Devices.
-- ---------------------------------------------------------------------------
create table if not exists public.push_devices (
  token text primary key check (char_length(token) between 10 and 4096),
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('android', 'ios')),
  language text not null default 'he' check (language in ('en', 'he')),
  updated_at timestamptz not null default now()
);
create index if not exists push_devices_user_idx on public.push_devices (user_id);
alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon;
drop policy if exists "push_devices: owner reads" on public.push_devices;
create policy "push_devices: owner reads" on public.push_devices
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "push_devices: owner removes" on public.push_devices;
create policy "push_devices: owner removes" on public.push_devices
  for delete to authenticated using (user_id = (select auth.uid()));

-- A phone moves to the account signed in on it: the token is one row.
create or replace function community_private.register_push_device(p_token text, p_platform text, p_language text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in first' using errcode = '42501';
  end if;
  insert into public.push_devices(token, user_id, platform, language, updated_at)
  values (p_token, auth.uid(), p_platform, coalesce(p_language, 'he'), now())
  on conflict (token) do update
    set user_id = excluded.user_id, platform = excluded.platform,
        language = excluded.language, updated_at = now();
end $$;
revoke all on function community_private.register_push_device(text, text, text) from public, anon;
grant execute on function community_private.register_push_device(text, text, text) to authenticated;
create or replace function public.register_push_device(p_token text, p_platform text, p_language text)
returns void language sql security invoker set search_path='' as $$
  select community_private.register_push_device(p_token, p_platform, p_language)
$$;
revoke all on function public.register_push_device(text, text, text) from public, anon;
grant execute on function public.register_push_device(text, text, text) to authenticated;

create or replace function public.unregister_push_device(p_token text)
returns void language sql security invoker set search_path='' as $$
  delete from public.push_devices where token = p_token and user_id = (select auth.uid())
$$;
revoke all on function public.unregister_push_device(text) from public, anon;
grant execute on function public.unregister_push_device(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Preferences.
-- ---------------------------------------------------------------------------
create table if not exists public.push_preferences (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  replies boolean not null default true,
  comments boolean not null default true,
  likes boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.push_preferences enable row level security;
revoke all on public.push_preferences from anon;
drop policy if exists "push_preferences: owner" on public.push_preferences;
create policy "push_preferences: owner" on public.push_preferences
  for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Outbox: server only.
-- ---------------------------------------------------------------------------
create table if not exists public.push_outbox (
  id bigint generated always as identity primary key,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('comment', 'like', 'reply')),
  actor_id uuid not null references auth.users(id) on delete cascade,
  -- Where a tap leads: 'post:<id>' or 'room:<id>'.
  target text not null,
  preview text not null default '',
  created_at timestamptz not null default now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  attempts integer not null default 0
);
create index if not exists push_outbox_pending_idx on public.push_outbox (id) where sent_at is null;
create index if not exists push_outbox_recent_idx on public.push_outbox (recipient_id, kind, target, created_at);
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;
grant all on public.push_outbox to service_role;

-- Tells the function there is something to send. Never fails the caller.
create or replace function community_private.poke_push()
returns void language plpgsql security definer set search_path='' as $$
declare url text; secret text;
begin
  if to_regclass('vault.decrypted_secrets') is null or to_regnamespace('net') is null then
    return;
  end if;
  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1' into url using 'push_project_url';
  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1' into secret using 'push_job_secret';
  if url is null or secret is null then return; end if;
  execute 'select net.http_post(url := $1, headers := $2, body := $3, timeout_milliseconds := 10000)'
    using url || '/functions/v1/community-push',
          jsonb_build_object('Content-Type', 'application/json', 'x-job-secret', secret),
          '{}'::jsonb;
exception when others then
  -- The next scheduled run sends it.
  return;
end $$;
revoke all on function community_private.poke_push() from public, anon, authenticated;

create or replace function community_private.enqueue_push(
  p_recipient uuid, p_kind text, p_actor uuid, p_target text, p_preview text)
returns void language plpgsql security definer set search_path='' as $$
declare wanted boolean;
begin
  if p_recipient is null or p_actor is null or p_recipient = p_actor then return; end if;
  if exists (select 1 from public.user_blocks b where b.blocker_id = p_recipient and b.blocked_id = p_actor) then
    return;
  end if;
  if not access_private.evaluate(p_recipient,
       case when p_kind = 'reply' then 'community.chat.view' else 'community.feed.view' end) then
    return;
  end if;
  select case p_kind when 'reply' then p.replies when 'comment' then p.comments else p.likes end
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
  insert into public.push_outbox(recipient_id, kind, actor_id, target, preview)
  values (p_recipient, p_kind, p_actor, p_target, left(coalesce(p_preview, ''), 140));
  perform community_private.poke_push();
end $$;
revoke all on function community_private.enqueue_push(uuid, text, uuid, text, text) from public, anon, authenticated;

create or replace function community_private.push_on_insert()
returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid; preview text;
begin
  if tg_table_name = 'community_comments' then
    select p.author_id into recipient from public.community_posts p where p.id = new.post_id;
    perform community_private.enqueue_push(recipient, 'comment', new.author_id, 'post:' || new.post_id, new.body);
  elsif tg_table_name = 'community_post_likes' then
    select p.author_id, p.body into recipient, preview from public.community_posts p where p.id = new.post_id;
    perform community_private.enqueue_push(recipient, 'like', new.user_id, 'post:' || new.post_id, preview);
  elsif new.reply_to is not null then
    select m.author_id into recipient from public.chat_messages m where m.id = new.reply_to;
    perform community_private.enqueue_push(recipient, 'reply', new.author_id, 'room:' || new.channel_id, new.body);
  end if;
  return null;
end $$;
revoke all on function community_private.push_on_insert() from public, anon, authenticated;

drop trigger if exists push_on_comment on public.community_comments;
create trigger push_on_comment after insert on public.community_comments
  for each row execute function community_private.push_on_insert();
drop trigger if exists push_on_like on public.community_post_likes;
create trigger push_on_like after insert on public.community_post_likes
  for each row execute function community_private.push_on_insert();
drop trigger if exists push_on_reply on public.chat_messages;
create trigger push_on_reply after insert on public.chat_messages
  for each row when (new.reply_to is not null) execute function community_private.push_on_insert();

-- ---------------------------------------------------------------------------
-- For the Edge Function (service role only).
-- ---------------------------------------------------------------------------
-- Claims up to p_limit waiting rows (a claim lapses after two minutes; five
-- attempts at most) and returns them with the actor's name and the
-- recipient's phones.
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
    'devices', coalesce((
      select jsonb_agg(jsonb_build_object('token', d.token, 'platform', d.platform, 'language', d.language))
      from public.push_devices d where d.user_id = c.recipient_id), '[]'::jsonb)
  ) order by c.id), '[]'::jsonb)
  into result
  from claimed c left join public.profiles pr on pr.id = c.actor_id;
  return result;
end $$;
revoke all on function public.push_claim(integer) from public, anon, authenticated;
grant execute on function public.push_claim(integer) to service_role;

-- Marks rows sent, forgets tokens FCM no longer knows, and drops sent rows
-- older than a week.
create or replace function public.push_finish(p_sent bigint[], p_dead_tokens text[])
returns void language plpgsql security definer set search_path='' as $$
begin
  update public.push_outbox set sent_at = now() where id = any(coalesce(p_sent, '{}'));
  delete from public.push_devices where token = any(coalesce(p_dead_tokens, '{}'));
  delete from public.push_outbox where sent_at < now() - interval '7 days';
end $$;
revoke all on function public.push_finish(bigint[], text[]) from public, anon, authenticated;
grant execute on function public.push_finish(bigint[], text[]) to service_role;

commit;
