\set ON_ERROR_STOP on
-- Disposable database only. What community activity queues a push
-- notification, and what the Edge Function's claim and finish do
-- (0023_community_push.sql).
begin;
insert into auth.users(id,email) values
 ('b1111111-1111-4111-8111-111111111111','author@example.test'),
 ('b2222222-2222-4222-8222-222222222222','reader@example.test'),
 ('b3333333-3333-4333-8333-333333333333','nophone@example.test');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;

-- The author has a phone; the third member does not.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
select public.register_push_device('author-token-0001', 'android', 'he');
insert into public.community_posts(id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000001','b1111111-1111-4111-8111-111111111111','My first post');
insert into public.chat_messages(id,channel_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000002','general','b1111111-1111-4111-8111-111111111111','Any tips?');
-- Commenting on one's own post is no news.
insert into public.community_comments(post_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000001','b1111111-1111-4111-8111-111111111111','Adding a detail');
do $$ begin
 assert (select count(*) from public.push_devices)=1, 'The owner sees their phone';
 begin
  perform count(*) from public.push_outbox;
  raise exception 'A member read the outbox';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox)=0, 'One''s own comment queues nothing';
end $$;

-- The reader comments, likes twice over, and answers the message.
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
insert into public.community_comments(post_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000001','b2222222-2222-4222-8222-222222222222','Lovely!');
reset role;
-- Likes are off unless switched on.
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
insert into public.community_post_likes(post_id) values('c0000000-0000-4000-8000-000000000001');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind='comment' and preview='Lovely!' and target='post:c0000000-0000-4000-8000-000000000001')=1,
  'A comment on someone''s post is queued for its author';
 assert (select count(*) from public.push_outbox where kind='like')=0, 'Likes are off by default';
end $$;

select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
insert into public.push_preferences(likes) values(true);
reset role;
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
delete from public.community_post_likes where post_id='c0000000-0000-4000-8000-000000000001';
insert into public.community_post_likes(post_id) values('c0000000-0000-4000-8000-000000000001');
delete from public.community_post_likes where post_id='c0000000-0000-4000-8000-000000000001';
insert into public.community_post_likes(post_id) values('c0000000-0000-4000-8000-000000000001');
insert into public.chat_messages(channel_id,author_id,body,reply_to) values
 ('general','b2222222-2222-4222-8222-222222222222','Short walks first.','c0000000-0000-4000-8000-000000000002');
-- A message that answers nobody queues nothing.
insert into public.chat_messages(channel_id,author_id,body) values
 ('general','b2222222-2222-4222-8222-222222222222','Hello all');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind='like')=1, 'Likes of one post are told once an hour';
 assert (select count(*) from public.push_outbox where kind='reply' and target='room:general' and preview='Short walks first.')=1,
  'An answer to a chat message is queued for its author';
 assert (select count(*) from public.push_outbox)=3, 'Nothing else was queued';
end $$;

-- Switched off: comments.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
update public.push_preferences set comments=false;
reset role;
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
insert into public.community_comments(post_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000001','b2222222-2222-4222-8222-222222222222','Another one');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind='comment')=1, 'A switched-off kind is not queued';
end $$;

-- Blocked: nothing from the blocked member.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
update public.push_preferences set comments=true;
insert into public.user_blocks(blocked_id) values('b2222222-2222-4222-8222-222222222222');
reset role;
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
insert into public.community_comments(post_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000001','b2222222-2222-4222-8222-222222222222','Still here');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind='comment')=1, 'A blocked member''s comment is not queued';
end $$;

-- No phone: nothing queued for the member without one.
select pg_temp.act_as('b3333333-3333-4333-8333-333333333333');
insert into public.community_posts(id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000003','b3333333-3333-4333-8333-333333333333','No phone here');
reset role;
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
insert into public.community_comments(post_id,author_id,body) values
 ('c0000000-0000-4000-8000-000000000003','b1111111-1111-4111-8111-111111111111','Hi');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where target='post:c0000000-0000-4000-8000-000000000003')=0,
  'Nothing is queued for an account without a phone';
end $$;

-- A phone signed in to another account moves with it.
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
select public.register_push_device('author-token-0001', 'android', 'en');
reset role;
do $$ begin
 assert (select user_id from public.push_devices where token='author-token-0001')='b2222222-2222-4222-8222-222222222222',
  'The token now belongs to the account signed in on the phone';
end $$;
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
select public.unregister_push_device('author-token-0001');
do $$ begin
 assert (select count(*) from public.push_devices)=0, 'Signing out removes the phone';
end $$;
select public.register_push_device('author-token-0001', 'android', 'he');
reset role;
update public.push_devices set user_id='b1111111-1111-4111-8111-111111111111';

-- Members cannot claim; the service role claims, sends and finishes.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
do $$ begin
 begin
  perform public.push_claim(10);
  raise exception 'A member claimed the outbox';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role service_role;
do $$
declare claimed jsonb := public.push_claim(10);
begin
 assert jsonb_array_length(claimed)=3, format('Three rows are claimed, got %s', claimed);
 assert claimed->0->>'kind'='comment' and claimed->0->'devices'->0->>'token'='author-token-0001'
   and claimed->0->'devices'->0->>'language'='he', 'A claimed row carries the recipient''s phones';
 assert jsonb_array_length(public.push_claim(10))=0, 'A claimed row is not claimed again at once';
 perform public.push_finish(array[(claimed->0->>'id')::bigint, (claimed->1->>'id')::bigint], array['author-token-0001']);
 assert (select count(*) from public.push_outbox where sent_at is not null)=2, 'Sent rows are marked';
 assert (select count(*) from public.push_devices)=0, 'A dead token is forgotten';
end $$;
reset role;
rollback;
\echo 'Community push tests passed.'
