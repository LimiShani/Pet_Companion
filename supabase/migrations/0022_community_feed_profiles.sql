-- PetLoop: community feed, member profiles and activity. Apply after 0021.
--
-- Feed:
--   * a post has a kind (moment, question, tip, recommendation, lost and
--     found) and says which animal it is about (audience, as chat rooms),
--     so the feed can be filtered like the rooms and the guides;
--   * authors can edit their posts (edited_at is stamped by the database)
--     and mark one comment under their question as the helpful answer;
--   * the feed view carries the new columns and can be paged and searched.
-- Members:
--   * a short public "about me" line and a city on the profile;
--   * community_activity: what happened to the member's posts and
--     messages (comments, likes, replies), newest first.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.chat_message_reactions') is null then
    raise exception 'Run 0021_community_chat_safety.sql first.';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Posts: kind, audience, edits, the helpful answer.
-- ---------------------------------------------------------------------------
alter table public.community_posts add column if not exists kind text not null default 'moment';
alter table public.community_posts drop constraint if exists community_posts_kind_check;
alter table public.community_posts add constraint community_posts_kind_check
  check (kind in ('moment', 'question', 'tip', 'recommendation', 'lost_found'));

alter table public.community_posts add column if not exists audience text not null default 'all';
alter table public.community_posts drop constraint if exists community_posts_audience_check;
alter table public.community_posts add constraint community_posts_audience_check
  check (audience in ('all', 'dog', 'cat', 'bird', 'rabbit', 'reptile', 'other'));

alter table public.community_posts add column if not exists edited_at timestamptz;
alter table public.community_posts add column if not exists helpful_comment_id uuid
  references public.community_comments(id) on delete set null;

create index if not exists community_posts_kind_idx on public.community_posts (kind, created_at desc);

-- What an edit may change: the text, the kind, the animal and the helpful
-- answer (which must be a comment under this question). Who wrote it,
-- when, and its photo stay as they were; a changed text is stamped.
create or replace function community_private.guard_post_update()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.author_id <> old.author_id or new.created_at <> old.created_at
     or new.photo_path is distinct from old.photo_path then
    raise exception 'Only the text, kind and animal of a post can change' using errcode = '42501';
  end if;
  if new.helpful_comment_id is not null and new.helpful_comment_id is distinct from old.helpful_comment_id then
    if new.kind <> 'question' or not exists (
      select 1 from public.community_comments c
      where c.id = new.helpful_comment_id and c.post_id = new.id
    ) then
      raise exception 'The helpful answer must be a comment under this question' using errcode = '23514';
    end if;
  end if;
  if new.body <> old.body then
    new.edited_at := now();
  end if;
  return new;
end $$;
revoke all on function community_private.guard_post_update() from public, anon, authenticated;
drop trigger if exists guard_post_update on public.community_posts;
create trigger guard_post_update before update on public.community_posts
  for each row execute function community_private.guard_post_update();

-- The feed with the new columns, appended so the view can be replaced.
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
  (select count(*) from public.community_comments c where c.post_id = p.id)::integer as comment_count,
  p.kind,
  p.audience,
  p.edited_at,
  p.helpful_comment_id
from public.community_posts p
left join public.profiles pr on pr.id = p.author_id;

revoke all on public.community_feed from anon;
grant select on public.community_feed to authenticated;

-- ---------------------------------------------------------------------------
-- Profiles: a public line about the member and their city.
-- ---------------------------------------------------------------------------
alter table public.profiles add column if not exists bio text not null default '';
alter table public.profiles drop constraint if exists profiles_bio_length;
alter table public.profiles add constraint profiles_bio_length check (char_length(bio) <= 160);
alter table public.profiles add column if not exists city text not null default '';
alter table public.profiles drop constraint if exists profiles_city_length;
alter table public.profiles add constraint profiles_city_length check (char_length(city) <= 40);

-- What members see of each other: no e-mail, nothing private.
create or replace view public.community_members
with (security_invoker = true) as
select
  pr.id,
  pr.display_name,
  pr.bio,
  pr.city,
  pr.created_at as member_since,
  (select count(*) from public.community_posts p where p.author_id = pr.id)::integer as post_count
from public.profiles pr;
revoke all on public.community_members from anon;
grant select on public.community_members to authenticated;

-- ---------------------------------------------------------------------------
-- Activity: comments on my posts, likes of my posts, answers to my chat
-- messages. Runs with the caller's rights, so blocked members, hidden and
-- reported content stay out.
-- ---------------------------------------------------------------------------
create or replace view public.community_activity
with (security_invoker = true) as
select 'comment'::text as kind, c.id, c.post_id::text as target_id, c.author_id as actor_id,
       coalesce(pr.display_name, '') as actor_name, left(c.body, 140) as preview, c.created_at
from public.community_comments c
join public.community_posts p on p.id = c.post_id
left join public.profiles pr on pr.id = c.author_id
where p.author_id = (select auth.uid()) and c.author_id <> (select auth.uid())
union all
select 'like', p.id, p.id::text, l.user_id, coalesce(pr.display_name, ''), left(p.body, 140), l.created_at
from public.community_post_likes l
join public.community_posts p on p.id = l.post_id
left join public.profiles pr on pr.id = l.user_id
where p.author_id = (select auth.uid()) and l.user_id <> (select auth.uid())
union all
select 'reply', m.id, m.channel_id, m.author_id, coalesce(pr.display_name, ''), left(m.body, 140), m.created_at
from public.chat_messages m
join public.chat_messages o on o.id = m.reply_to
left join public.profiles pr on pr.id = m.author_id
where o.author_id = (select auth.uid()) and m.author_id <> (select auth.uid());
revoke all on public.community_activity from anon;
grant select on public.community_activity to authenticated;

commit;
