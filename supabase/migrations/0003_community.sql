-- PetLoop: community (feed, topic chat).
-- Run after 0001 in the Supabase SQL editor (Dashboard > SQL Editor > New
-- query > paste > Run) or with the Supabase CLI: `supabase db push`.
--
-- The file is idempotent: running it again changes nothing.
--
-- Every table has row level security on. The rule throughout: signed-in
-- members read community content; you create only as yourself
-- (`auth.uid()`), and you change or delete only what is yours. People who
-- are not signed in see nothing. Guides are bundled in the app and have no
-- table.

-- ---------------------------------------------------------------------------
-- profiles: let members see each other's names.
-- 0001 lets only the owner read a profile. Posts, comments and chat
-- messages show the author's display name, which lives only here, so
-- signed-in members may now read profiles (display name, avatar path).
-- Updating stays owner-only.
-- ---------------------------------------------------------------------------
drop policy if exists "profiles: members can read" on public.profiles;
create policy "profiles: members can read" on public.profiles
  for select to authenticated using (true);

-- Accounts created before the sign-up trigger existed have no profile row.
insert into public.profiles (id, display_name)
select u.id, coalesce(u.raw_user_meta_data ->> 'display_name', '')
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Tables.
-- ---------------------------------------------------------------------------

-- A post in the feed. The pet is a plain name, not a link to public.pets:
-- pets are private to their owner.
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  pet_name text check (pet_name is null or char_length(pet_name) between 1 and 60),
  body text not null check (char_length(body) between 1 and 2000),
  -- Path inside the community-photos bucket; always in the author's folder.
  photo_path text check (photo_path is null or photo_path like (author_id::text || '/%')),
  created_at timestamptz not null default now()
);

create index if not exists community_posts_created_at_idx on public.community_posts (created_at desc);
create index if not exists community_posts_author_id_idx on public.community_posts (author_id);

-- One like per member per post: the primary key enforces it.
create table if not exists public.community_post_likes (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create index if not exists community_post_likes_user_id_idx on public.community_post_likes (user_id);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts (id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists community_comments_post_id_idx on public.community_comments (post_id, created_at);
create index if not exists community_comments_author_id_idx on public.community_comments (author_id);

-- A member's report of a post, kept for review in the dashboard
-- (Table editor > community_reports). One per member per post.
create table if not exists public.community_reports (
  post_id uuid not null references public.community_posts (id) on delete cascade,
  reporter_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  reason text not null check (reason in ('spam', 'abusive', 'inappropriate', 'other')),
  created_at timestamptz not null default now(),
  primary key (post_id, reporter_id)
);

create index if not exists community_reports_reporter_id_idx on public.community_reports (reporter_id);

-- Topic chat rooms. The id is a short slug the app also uses for the icon.
create table if not exists public.chat_channels (
  id text primary key check (id ~ '^[a-z0-9-]{1,40}$'),
  name text not null check (char_length(name) between 1 and 40),
  description text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.chat_channels (id, name, description, sort_order)
values
  ('general', 'General', 'Say hello and share your day', 10),
  ('puppies', 'Puppies', 'First weeks, teething and sleep', 20),
  ('training', 'Training tips', 'What works, one small step at a time', 30),
  ('seniors', 'Senior dogs', 'Comfort and care for older friends', 40),
  ('health', 'Health questions', 'Ask other owners. For anything urgent, call your vet', 50)
on conflict (id) do nothing;

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  channel_id text not null references public.chat_channels (id) on delete cascade,
  author_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_channel_idx on public.chat_messages (channel_id, created_at desc);
create index if not exists chat_messages_author_id_idx on public.chat_messages (author_id);

-- ---------------------------------------------------------------------------
-- Row level security.
-- ---------------------------------------------------------------------------
alter table public.community_posts enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_reports enable row level security;
alter table public.chat_channels enable row level security;
alter table public.chat_messages enable row level security;

-- Posts: members read every post except the ones they reported, so a
-- reported post disappears for its reporter everywhere at once.
drop policy if exists "community_posts: members can read" on public.community_posts;
create policy "community_posts: members can read" on public.community_posts
  for select to authenticated using (
    not exists (
      select 1 from public.community_reports r
      where r.post_id = community_posts.id and r.reporter_id = auth.uid()
    )
  );

drop policy if exists "community_posts: insert as yourself" on public.community_posts;
create policy "community_posts: insert as yourself" on public.community_posts
  for insert to authenticated with check (author_id = auth.uid());

drop policy if exists "community_posts: author can update" on public.community_posts;
create policy "community_posts: author can update" on public.community_posts
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists "community_posts: author can delete" on public.community_posts;
create policy "community_posts: author can delete" on public.community_posts
  for delete to authenticated using (author_id = auth.uid());

-- Likes: there is nothing to update, so no update policy.
drop policy if exists "community_post_likes: members can read" on public.community_post_likes;
create policy "community_post_likes: members can read" on public.community_post_likes
  for select to authenticated using (true);

drop policy if exists "community_post_likes: like as yourself" on public.community_post_likes;
create policy "community_post_likes: like as yourself" on public.community_post_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "community_post_likes: remove your own" on public.community_post_likes;
create policy "community_post_likes: remove your own" on public.community_post_likes
  for delete to authenticated using (user_id = auth.uid());

-- Comments.
drop policy if exists "community_comments: members can read" on public.community_comments;
create policy "community_comments: members can read" on public.community_comments
  for select to authenticated using (true);

drop policy if exists "community_comments: insert as yourself" on public.community_comments;
create policy "community_comments: insert as yourself" on public.community_comments
  for insert to authenticated with check (author_id = auth.uid());

drop policy if exists "community_comments: author can update" on public.community_comments;
create policy "community_comments: author can update" on public.community_comments
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists "community_comments: author can delete" on public.community_comments;
create policy "community_comments: author can delete" on public.community_comments
  for delete to authenticated using (author_id = auth.uid());

-- Reports: you see and file only your own; nobody changes or deletes one
-- from the app (they are kept for review).
drop policy if exists "community_reports: reporter can read" on public.community_reports;
create policy "community_reports: reporter can read" on public.community_reports
  for select to authenticated using (reporter_id = auth.uid());

drop policy if exists "community_reports: report as yourself" on public.community_reports;
create policy "community_reports: report as yourself" on public.community_reports
  for insert to authenticated with check (reporter_id = auth.uid());

-- Chat rooms: read-only from the app; add rooms here or in the dashboard.
drop policy if exists "chat_channels: members can read" on public.chat_channels;
create policy "chat_channels: members can read" on public.chat_channels
  for select to authenticated using (true);

-- Chat messages.
drop policy if exists "chat_messages: members can read" on public.chat_messages;
create policy "chat_messages: members can read" on public.chat_messages
  for select to authenticated using (true);

drop policy if exists "chat_messages: insert as yourself" on public.chat_messages;
create policy "chat_messages: insert as yourself" on public.chat_messages
  for insert to authenticated with check (author_id = auth.uid());

drop policy if exists "chat_messages: author can update" on public.chat_messages;
create policy "chat_messages: author can update" on public.chat_messages
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());

drop policy if exists "chat_messages: author can delete" on public.chat_messages;
create policy "chat_messages: author can delete" on public.chat_messages
  for delete to authenticated using (author_id = auth.uid());

-- ---------------------------------------------------------------------------
-- community_feed: each post with its author's name and counts, for the
-- feed screen. `security_invoker` makes the view run with the caller's
-- permissions, so every policy above still applies.
-- ---------------------------------------------------------------------------
create or replace view public.community_feed
with (security_invoker = true) as
select
  p.id,
  p.author_id,
  coalesce(pr.display_name, '') as author_name,
  p.pet_name,
  p.body,
  p.photo_path,
  p.created_at,
  (select count(*) from public.community_post_likes l where l.post_id = p.id)::integer as like_count,
  exists (
    select 1 from public.community_post_likes l
    where l.post_id = p.id and l.user_id = auth.uid()
  ) as liked_by_me,
  (select count(*) from public.community_comments c where c.post_id = p.id)::integer as comment_count
from public.community_posts p
left join public.profiles pr on pr.id = p.author_id;

revoke all on public.community_feed from anon;
grant select on public.community_feed to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: a conversation screen subscribes to new chat messages.
-- Realtime applies the select policy above to every subscriber.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_messages'
     )
  then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Storage: private bucket for post photos. Files live under
-- <user id>/<file>; any signed-in member can view them (the app uses
-- short-lived signed URLs), and you upload and delete only in your folder.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-photos', 'community-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists "community-photos: members can read" on storage.objects;
create policy "community-photos: members can read" on storage.objects
  for select to authenticated using (bucket_id = 'community-photos');

drop policy if exists "community-photos: owner can upload" on storage.objects;
create policy "community-photos: owner can upload" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'community-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "community-photos: owner can delete" on storage.objects;
create policy "community-photos: owner can delete" on storage.objects
  for delete to authenticated using (
    bucket_id = 'community-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
