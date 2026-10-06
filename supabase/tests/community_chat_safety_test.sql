\set ON_ERROR_STOP on
-- Disposable database only. Chat replies, photos, reactions, read markers,
-- blocking, reports, hiding by reports, moderation and the rate limit
-- (0021_community_chat_safety.sql).
begin;
insert into auth.users(id,email) values
 ('c1111111-1111-4111-8111-111111111111','moderator@example.test'),
 ('c2222222-2222-4222-8222-222222222222','bea@example.test'),
 ('c3333333-3333-4333-8333-333333333333','carl@example.test'),
 ('c4444444-4444-4444-8444-444444444444','dana@example.test'),
 ('c5555555-5555-4555-8555-555555555555','eli@example.test');
-- The moderator capability is granted per person, as the permissions
-- screen does.
insert into public.user_capability_rules(user_id,capability,allowed)
values ('c1111111-1111-4111-8111-111111111111','community.moderate',true);

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;

-- Bea writes; Carl answers her with a photo-only reply.
select pg_temp.act_as('c2222222-2222-4222-8222-222222222222');
insert into public.chat_messages(id,channel_id,author_id,body,created_at) values
 ('d0000000-0000-4000-8000-000000000001','general','c2222222-2222-4222-8222-222222222222','Hello from Bea',now()-interval '1 minute');
do $$ begin
 assert not public.can_use('community.moderate'), 'Members are not moderators by default';
 begin
  insert into public.chat_messages(channel_id,author_id,body) values('general','c2222222-2222-4222-8222-222222222222','');
  raise exception 'An empty message without a photo was accepted';
 exception when check_violation then null; end;
 begin
  perform public.community_moderation_queue();
  raise exception 'A member read the moderation queue';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select pg_temp.act_as('c3333333-3333-4333-8333-333333333333');
insert into public.chat_messages(id,channel_id,author_id,body,photo_path,reply_to) values
 ('d0000000-0000-4000-8000-000000000002','general','c3333333-3333-4333-8333-333333333333','',
  'c3333333-3333-4333-8333-333333333333/photo.jpg','d0000000-0000-4000-8000-000000000001');
-- A reaction takes its room from the message.
insert into public.chat_message_reactions(message_id,emoji,channel_id) values
 ('d0000000-0000-4000-8000-000000000001','🐾','health');
do $$ begin
 assert (select channel_id from public.chat_message_reactions where message_id='d0000000-0000-4000-8000-000000000001')='general',
  'A reaction belongs to the room of its message';
 begin
  insert into public.chat_messages(channel_id,author_id,body,photo_path) values
   ('general','c3333333-3333-4333-8333-333333333333','x','c2222222-2222-4222-8222-222222222222/not-mine.jpg');
  raise exception 'A message pointed at a photo in someone else''s folder';
 exception when check_violation then null; end;
end $$;
reset role;

-- Unread counts follow the read marker.
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
do $$ begin
 assert (select unread_count from public.chat_room_summaries where channel_id='general')=2, 'Two unread messages in General';
 assert (select last_message_id from public.chat_room_summaries where channel_id='general')='d0000000-0000-4000-8000-000000000002',
  'The room list shows the latest message';
 assert (select last_has_photo from public.chat_room_summaries where channel_id='general'), 'The latest message is a photo';
end $$;
select public.mark_chat_read('general');
do $$ begin
 assert (select unread_count from public.chat_room_summaries where channel_id='general')=0, 'Reading the room clears its count';
end $$;
reset role;

-- Dana blocks Carl: his message disappears for her only.
select pg_temp.act_as('c4444444-4444-4444-8444-444444444444');
insert into public.user_blocks(blocked_id) values('c3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.chat_messages where channel_id='general')=1, 'A blocked member''s message is hidden';
 assert (select last_message_id from public.chat_room_summaries where channel_id='general')='d0000000-0000-4000-8000-000000000001',
  'The room list skips a blocked member';
 begin
  insert into public.user_blocks(blocker_id,blocked_id) values('c2222222-2222-4222-8222-222222222222','c5555555-5555-4555-8555-555555555555');
  raise exception 'Blocked on someone else''s behalf';
 exception when insufficient_privilege then null; end;
end $$;
-- Dana reports Bea's message: it disappears for Dana at once.
insert into public.chat_message_reports(message_id,reason) values('d0000000-0000-4000-8000-000000000001','spam');
do $$ begin
 assert (select count(*) from public.chat_messages where channel_id='general')=0, 'A reported message is hidden for its reporter';
end $$;
reset role;

select pg_temp.act_as('c3333333-3333-4333-8333-333333333333');
insert into public.chat_message_reports(message_id,reason) values('d0000000-0000-4000-8000-000000000001','abusive');
reset role;
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
do $$ begin
 assert (select count(*) from public.chat_messages where id='d0000000-0000-4000-8000-000000000001')=1, 'Two reports do not hide a message';
end $$;
reset role;
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
insert into public.chat_message_reports(message_id,reason) values('d0000000-0000-4000-8000-000000000001','spam');
reset role;

-- Three reports hide it for everyone but its author and moderators.
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
do $$ begin
 assert (select count(*) from public.chat_messages where id='d0000000-0000-4000-8000-000000000001')=0, 'Three reports hide a message';
end $$;
reset role;
select pg_temp.act_as('c2222222-2222-4222-8222-222222222222');
do $$ begin
 assert (select count(*) from public.chat_messages where id='d0000000-0000-4000-8000-000000000001')=1, 'The author still sees it';
end $$;
reset role;

select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
do $$
declare queue jsonb := public.community_moderation_queue();
begin
 assert jsonb_array_length(queue)=1, 'One item waits for review';
 assert queue->0->>'kind'='message' and (queue->0->>'report_count')::int=3 and (queue->0->>'hidden')::boolean,
  'The queue says what, how often and that it is hidden';
end $$;
select public.community_moderate('message','d0000000-0000-4000-8000-000000000001','keep');
do $$ begin
 assert jsonb_array_length(public.community_moderation_queue())=0, 'A kept item leaves the queue';
end $$;
reset role;
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
do $$ begin
 assert (select count(*) from public.chat_messages where id='d0000000-0000-4000-8000-000000000001')=1, 'A kept message is back';
end $$;
reset role;

-- A removed message is deleted, and its photo queued for clean-up.
select pg_temp.act_as('c4444444-4444-4444-8444-444444444444');
delete from public.user_blocks;
insert into public.chat_message_reports(message_id,reason) values('d0000000-0000-4000-8000-000000000002','inappropriate');
reset role;
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
select public.community_moderate('message','d0000000-0000-4000-8000-000000000002','remove');
reset role;
do $$ begin
 assert not exists(select 1 from public.chat_messages where id='d0000000-0000-4000-8000-000000000002'), 'A removed message is deleted';
 assert exists(select 1 from public.storage_cleanup_jobs where path='c3333333-3333-4333-8333-333333333333/photo.jpg'),
  'A removed message''s photo is queued for clean-up';
end $$;

-- Comment reports hide the comment for the reporter.
select pg_temp.act_as('c2222222-2222-4222-8222-222222222222');
insert into public.community_posts(id,author_id,body) values('e0000000-0000-4000-8000-000000000001','c2222222-2222-4222-8222-222222222222','A post');
insert into public.community_comments(id,post_id,author_id,body) values
 ('e0000000-0000-4000-8000-000000000002','e0000000-0000-4000-8000-000000000001','c2222222-2222-4222-8222-222222222222','A comment');
reset role;
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
insert into public.community_comment_reports(comment_id,reason) values('e0000000-0000-4000-8000-000000000002','abusive');
do $$ begin
 assert (select count(*) from public.community_comments where post_id='e0000000-0000-4000-8000-000000000001')=0, 'A reported comment is hidden for its reporter';
 assert (select comment_count from public.community_feed where id='e0000000-0000-4000-8000-000000000001')=0, 'The feed counts only visible comments';
end $$;
-- Blocking the author hides the post from the feed.
insert into public.user_blocks(blocked_id) values('c2222222-2222-4222-8222-222222222222');
do $$ begin
 assert (select count(*) from public.community_feed where id='e0000000-0000-4000-8000-000000000001')=0, 'A blocked member''s post leaves the feed';
end $$;
reset role;

-- The rate limit: fifteen messages a minute.
select pg_temp.act_as('c4444444-4444-4444-8444-444444444444');
insert into public.chat_messages(channel_id,author_id,body)
select 'general','c4444444-4444-4444-8444-444444444444','Message '||n from generate_series(1,15) n;
do $$
declare refused boolean := false;
begin
 begin
  insert into public.chat_messages(channel_id,author_id,body) values('general','c4444444-4444-4444-8444-444444444444','One too many');
 exception when raise_exception then
  refused := sqlerrm = 'rate_limited';
 end;
 assert refused, 'The rate limit let a sixteenth message through';
end $$;
reset role;
rollback;
\echo 'Community chat and safety tests passed.'
