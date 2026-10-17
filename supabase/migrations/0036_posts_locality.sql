-- PetLoop: the neighbourhood, part 2 (Community). Apply after 0022. Design
-- and owner steps: docs/community.md ("Near me").
--
--   * community_posts.locality_code: where a post is about (a code of the
--     app's localities list, "petah-tikva"), or null for everywhere. The
--     app fills it from the author's member-page city and lets them change
--     it ("Near Petah Tikva" / "Everywhere"); posts written before, and
--     posts written by other functions (lost and found, 0034), stay null.
--   * community_posts.place_name: the place a recommendation is about
--     ("Dr. Levi's clinic"), up to 80 characters; only recommendations
--     carry one.
--   * community_feed gains both columns, appended, so the app filters the
--     feed by the localities around the member ("Near me") and groups the
--     recommended places in search.
--
-- Additive and idempotent: running it again changes nothing. Both columns
-- are nullable without defaults, so every existing insert keeps working.
begin;

do $$
begin
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'community_posts' and column_name = 'kind') then
    raise exception 'Run 0022_community_feed_profiles.sql first.';
  end if;
end
$$;

alter table public.community_posts add column if not exists locality_code text;
alter table public.community_posts drop constraint if exists community_posts_locality_code_check;
alter table public.community_posts add constraint community_posts_locality_code_check
  check (locality_code is null or locality_code ~ '^[a-z0-9-]{2,60}$');

alter table public.community_posts add column if not exists place_name text;
alter table public.community_posts drop constraint if exists community_posts_place_name_check;
alter table public.community_posts add constraint community_posts_place_name_check
  check (place_name is null or (char_length(btrim(place_name)) between 1 and 80 and kind = 'recommendation'));

create index if not exists community_posts_locality_idx on public.community_posts (locality_code, created_at desc)
  where locality_code is not null;

-- 0022's feed with the two new columns, appended so the view can be
-- replaced.
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
  p.helpful_comment_id,
  p.locality_code,
  p.place_name
from public.community_posts p
left join public.profiles pr on pr.id = p.author_id;

revoke all on public.community_feed from anon;
grant select on public.community_feed to authenticated;

commit;
