\set ON_ERROR_STOP on
-- Disposable database only. Post kinds and animals, edits, the helpful
-- answer, member profiles and activity (0022_community_feed_profiles.sql).
begin;
insert into auth.users(id,email) values
 ('f1111111-1111-4111-8111-111111111111','asker@example.test'),
 ('f2222222-2222-4222-8222-222222222222','helper@example.test');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;

select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
update public.profiles set display_name='Asker', bio='Two cats and a balcony', city='Haifa'
 where id='f1111111-1111-4111-8111-111111111111';
insert into public.community_posts(id,author_id,body,kind,audience) values
 ('a0000000-0000-4000-8000-000000000001','f1111111-1111-4111-8111-111111111111','Which litter clumps best?','question','cat');
do $$ begin
 begin
  insert into public.community_posts(author_id,body,kind) values('f1111111-1111-4111-8111-111111111111','x','advert');
  raise exception 'An unknown kind of post was accepted';
 exception when check_violation then null; end;
 begin
  update public.profiles set bio=repeat('x',161) where id='f1111111-1111-4111-8111-111111111111';
  raise exception 'A bio over 160 characters was accepted';
 exception when check_violation then null; end;
 assert (select kind from public.community_feed where id='a0000000-0000-4000-8000-000000000001')='question', 'The feed says what kind a post is';
 assert (select audience from public.community_feed where id='a0000000-0000-4000-8000-000000000001')='cat', 'The feed says which animal';
end $$;
reset role;

select pg_temp.act_as('f2222222-2222-4222-8222-222222222222');
insert into public.community_comments(id,post_id,author_id,body) values
 ('a0000000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000001','f2222222-2222-4222-8222-222222222222','Plain bentonite.');
insert into public.community_post_likes(post_id) values('a0000000-0000-4000-8000-000000000001');
do $$ begin
 assert (select city from public.community_members where id='f1111111-1111-4111-8111-111111111111')='Haifa', 'Members see each other''s city';
 assert (select post_count from public.community_members where id='f1111111-1111-4111-8111-111111111111')=1, 'And how many posts';
 -- Someone else cannot mark the answer or edit the post.
 update public.community_posts set helpful_comment_id='a0000000-0000-4000-8000-000000000002', body='Hacked'
  where id='a0000000-0000-4000-8000-000000000001';
end $$;
reset role;

select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
do $$
declare activity int;
begin
 assert (select body from public.community_posts where id='a0000000-0000-4000-8000-000000000001')='Which litter clumps best?',
  'Only the author edits a post';
 select count(*) into activity from public.community_activity;
 assert activity=2, format('A comment and a like are activity, got %s', activity);
 assert exists(select 1 from public.community_activity where kind='comment' and preview='Plain bentonite.'), 'The comment is there';
end $$;
update public.community_posts set helpful_comment_id='a0000000-0000-4000-8000-000000000002', body='Which litter clumps best for two cats?'
 where id='a0000000-0000-4000-8000-000000000001';
do $$ begin
 assert (select edited_at is not null from public.community_posts where id='a0000000-0000-4000-8000-000000000001'), 'A changed text is stamped';
 assert (select helpful_comment_id from public.community_feed where id='a0000000-0000-4000-8000-000000000001')='a0000000-0000-4000-8000-000000000002',
  'The helpful answer is marked';
 begin
  update public.community_posts set author_id='f2222222-2222-4222-8222-222222222222' where id='a0000000-0000-4000-8000-000000000001';
  raise exception 'A post changed hands';
 exception when insufficient_privilege then null; end;
end $$;
-- A helpful answer must belong to a question.
insert into public.community_posts(id,author_id,body) values
 ('a0000000-0000-4000-8000-000000000003','f1111111-1111-4111-8111-111111111111','Just a moment');
do $$ begin
 begin
  update public.community_posts set helpful_comment_id='a0000000-0000-4000-8000-000000000002'
   where id='a0000000-0000-4000-8000-000000000003';
  raise exception 'A comment under another post became the helpful answer';
 exception when check_violation then null; end;
end $$;
reset role;

-- Activity follows blocks: once the asker blocks the helper, it is gone.
select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
insert into public.user_blocks(blocked_id) values('f2222222-2222-4222-8222-222222222222');
do $$ begin
 assert (select count(*) from public.community_activity where kind='comment')=0, 'A blocked member''s comment is no activity';
end $$;
reset role;
rollback;
\echo 'Community feed, profiles and activity tests passed.'
