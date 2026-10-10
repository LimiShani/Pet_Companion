\set ON_ERROR_STOP on
-- Disposable database only. Private chats: invitations, admins, history
-- from the moment a member is brought in, leaving, direct chats, blocking,
-- limits, row level security and push (0026_private_chats.sql).
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('e1111111-1111-4111-8111-111111111111','ana@example.test','{"display_name":"Ana"}'),
 ('e2222222-2222-4222-8222-222222222222','ben@example.test','{"display_name":"Ben"}'),
 ('e3333333-3333-4333-8333-333333333333','cleo@example.test','{"display_name":"Cleo"}'),
 ('e4444444-4444-4444-8444-444444444444','dov@example.test','{"display_name":"Dov"}'),
 ('e5555555-5555-4555-8555-555555555555','eve@example.test','{"display_name":"Eve"}'),
 ('e6666666-6666-4666-8666-666666666666','mod@example.test','{"display_name":"Mod"}');
-- Eve's private chats are switched off by an administrator; Mod moderates.
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('e5555555-5555-4555-8555-555555555555','community.chat.private',false),
 ('e6666666-6666-4666-8666-666666666666','community.moderate',true);

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
create table pg_temp.ids(name text primary key, id text);
grant all on pg_temp.ids to authenticated;

-- Everyone may use private chats by default.
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.can_use('community.chat.private'), 'Private chats are allowed by default';
end $$;
reset role;
select pg_temp.act_as('e5555555-5555-4555-8555-555555555555');
do $$ begin
 assert not public.can_use('community.chat.private'), 'An administrator can switch private chats off';
 begin
  perform public.create_private_chat(array['e1111111-1111-4111-8111-111111111111']::uuid[], '');
  raise exception 'An account without private chats started one';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Ana starts a group with Ben and Cleo.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into pg_temp.ids values ('walks', public.create_private_chat(
 array['e2222222-2222-4222-8222-222222222222','e3333333-3333-4333-8333-333333333333']::uuid[], ' Morning walks '));
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 assert walks ~ '^[a-f0-9-]{36}$', 'A private chat''s id is a UUID';
 assert (select name from public.chat_channels where id=walks)='Morning walks', 'The name is trimmed';
 assert (select count(*) from public.chat_channel_members where channel_id=walks)=3, 'Members are visible to a joined member';
 assert (select role from public.chat_channel_members where channel_id=walks and user_id=auth.uid())='admin', 'The creator is the first admin';
 assert (select count(*) from public.chat_messages where channel_id=walks and system is not null)=2, 'Created and added lines';
 assert (select system->>'event' from public.chat_messages where channel_id=walks and system->>'event'='added')='added'
   and (select jsonb_array_length(system->'users') from public.chat_messages where channel_id=walks and system->>'event'='added')=2,
  'The added line names both invitees';
 -- Nobody writes membership or system lines directly.
 begin
  insert into public.chat_channel_members(channel_id,user_id,status) values(walks,'e4444444-4444-4444-8444-444444444444','joined');
  raise exception 'A member wrote a membership row';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.chat_messages(channel_id,author_id,body,system) values(walks,auth.uid(),'','{"event":"left"}');
  raise exception 'A member wrote a system line';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.chat_channels(id,name,kind) values(gen_random_uuid()::text,'Mine','private');
  raise exception 'A member created a channel directly';
 exception when insufficient_privilege then null; end;
 -- System lines cannot be deleted by their author.
 delete from public.chat_messages where channel_id=walks and system is not null;
 assert (select count(*) from public.chat_messages where channel_id=walks and system is not null)=2, 'System lines stay';
end $$;
-- An earlier message (before anyone else was brought in) and one now.
insert into public.chat_messages(id,channel_id,author_id,body,created_at)
select 'f0000000-0000-4000-8000-000000000001', id, 'e1111111-1111-4111-8111-111111111111', 'Before the invitations', now() - interval '1 hour'
from pg_temp.ids where name='walks';
insert into public.chat_messages(id,channel_id,author_id,body)
select 'f0000000-0000-4000-8000-000000000002', id, 'e1111111-1111-4111-8111-111111111111', 'Out at seven?'
from pg_temp.ids where name='walks';
reset role;

-- Ben is invited: he sees the invitation card and nothing else of the chat.
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$
declare walks text := (select id from pg_temp.ids where name='walks'); card jsonb := public.my_chat_invitations();
begin
 assert jsonb_array_length(card)=1, format('One invitation, got %s', card);
 assert card->0->>'name'='Morning walks' and card->0->>'inviter_name'='Ana' and (card->0->>'participants')::int=3
   and not (card->0->>'direct')::boolean, format('The card names the chat, the inviter and the count: %s', card);
 assert (select count(*) from public.chat_channels where id=walks)=0, 'An invitee does not see the chat';
 assert (select count(*) from public.chat_messages where channel_id=walks)=0, 'An invitee sees no message';
 assert (select count(*) from public.chat_channel_members where channel_id=walks)=1, 'An invitee sees only their own row';
 assert jsonb_array_length(public.my_private_chats())=0, 'An invitation is not a chat yet';
 begin
  insert into public.chat_messages(channel_id,author_id,body) values(walks,auth.uid(),'Hi');
  raise exception 'An invitee wrote in the chat';
 exception when insufficient_privilege then null; end;
 begin
  perform public.invite_to_private_chat(walks, array['e4444444-4444-4444-8444-444444444444']::uuid[]);
  raise exception 'An invitee invited someone';
 exception when insufficient_privilege then null; end;
 begin
  perform public.mark_chat_read(walks);
  raise exception 'An invitee marked the chat read';
 exception when insufficient_privilege then null; end;
 perform public.answer_chat_invitation(walks, true);
 assert (select count(*) from public.chat_channels where id=walks)=1, 'A joined member sees the chat';
 assert (select count(*) from public.chat_messages where channel_id=walks and system is null)=1
   and exists(select 1 from public.chat_messages where id='f0000000-0000-4000-8000-000000000002'),
  'History starts when the member was brought in';
 assert (select count(*) from public.chat_messages where channel_id=walks and system->>'event'='joined' and author_id=auth.uid())=1, 'A joined line';
 assert (select count(*) from public.chat_channel_members where channel_id=walks)=3, 'Joined members see everyone, invited included';
 assert (select status from public.chat_channel_members where channel_id=walks and user_id='e3333333-3333-4333-8333-333333333333')='invited',
  'Cleo shows as invited';
 assert (select unread_count from public.chat_room_summaries where channel_id=walks)=1, 'The room list counts the message, not the system lines';
 assert (select kind from public.chat_room_summaries where channel_id=walks)='private', 'The room list says it is private';
 perform public.mark_chat_read(walks);
 insert into public.chat_messages(id,channel_id,author_id,body) values('f0000000-0000-4000-8000-000000000003',walks,auth.uid(),'Count me in');
 insert into public.chat_message_reactions(message_id,emoji) values('f0000000-0000-4000-8000-000000000002','👍');
 -- A member, not an admin.
 begin
  perform public.rename_private_chat(walks, 'Ben''s walks');
  raise exception 'A member renamed the chat';
 exception when insufficient_privilege then null; end;
 begin
  perform public.remove_from_private_chat(walks, 'e3333333-3333-4333-8333-333333333333');
  raise exception 'A member removed someone';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Cleo says no thanks: the invitation is gone.
select pg_temp.act_as('e3333333-3333-4333-8333-333333333333');
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 perform public.answer_chat_invitation(walks, false);
 assert jsonb_array_length(public.my_chat_invitations())=0, 'A declined invitation is gone';
 assert (select count(*) from public.chat_channel_members where channel_id=walks)=0, 'Cleo is not in the chat';
end $$;
reset role;

-- Dov blocked Ana: she cannot invite him, and he is not among her people.
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
insert into public.user_blocks(blocked_id) values('e1111111-1111-4111-8111-111111111111');
reset role;
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$
declare walks text := (select id from pg_temp.ids where name='walks'); people jsonb := public.chat_people('', 40);
begin
 assert not exists(select 1 from jsonb_array_elements(people) p where p->>'id' in
   ('e4444444-4444-4444-8444-444444444444','e5555555-5555-4555-8555-555555555555','e1111111-1111-4111-8111-111111111111')),
  format('No one blocked, switched off or oneself among the people: %s', people);
 assert people->0->>'id'='e2222222-2222-4222-8222-222222222222' and (people->0->>'recent')::boolean,
  format('Ben, talked with recently, comes first: %s', people);
 assert jsonb_array_length(public.chat_people('cle', 40))=1, 'People are found by name';
 assert jsonb_array_length(public.chat_people('%', 40))=0, 'A percent sign is a letter, not a wildcard';
 begin
  perform public.invite_to_private_chat(walks, array['e4444444-4444-4444-8444-444444444444']::uuid[]);
  raise exception 'Ana invited someone who blocked her';
 exception when insufficient_privilege then null; end;
 begin
  perform public.invite_to_private_chat(walks, array['e5555555-5555-4555-8555-555555555555']::uuid[]);
  raise exception 'Ana invited someone without private chats';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
delete from public.user_blocks where blocked_id='e1111111-1111-4111-8111-111111111111';
reset role;

-- Ana invites Dov and makes Ben admin; Dov joins and sees only what came
-- after he was brought in.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 perform public.invite_to_private_chat(walks, array['e4444444-4444-4444-8444-444444444444']::uuid[]);
 perform public.make_private_chat_admin(walks, 'e2222222-2222-4222-8222-222222222222');
 assert (select role from public.chat_channel_members where channel_id=walks and user_id='e2222222-2222-4222-8222-222222222222')='admin',
  'Ben is admin';
 begin
  perform public.make_private_chat_admin(walks, 'e4444444-4444-4444-8444-444444444444');
  raise exception 'An invitee was made admin';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;
-- Messages written before Dov's invitation.
update public.chat_messages set created_at = now() - interval '10 minutes'
where id in ('f0000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000003');
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 perform public.answer_chat_invitation(walks, true);
 assert not exists(select 1 from public.chat_messages where id in
   ('f0000000-0000-4000-8000-000000000001','f0000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000003')),
  'A new member does not see earlier messages';
 assert (select count(*) from public.chat_message_reactions where message_id='f0000000-0000-4000-8000-000000000002')=0,
  'Nor their reactions';
 begin
  insert into public.chat_message_reactions(message_id,emoji) values('f0000000-0000-4000-8000-000000000002','❤️');
  raise exception 'Dov reacted to a message before his time';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.chat_message_reports(message_id,reason) values('f0000000-0000-4000-8000-000000000002','spam');
  raise exception 'Dov reported a message before his time';
 exception when insufficient_privilege then null; end;
 assert (select count(*) from public.chat_messages where channel_id=walks and system->>'event' in ('added','admin','joined'))>=1,
  'Dov sees the lines from his time on';
 insert into public.chat_messages(id,channel_id,author_id,body) values('f0000000-0000-4000-8000-000000000004',walks,auth.uid(),'Hello all');
end $$;
reset role;

-- Ben renames; Cleo, outside, sees nothing of it; Ben reports a message
-- and the moderator sees that message only.
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 perform public.rename_private_chat(walks, 'Park walks');
 assert (select name from public.chat_channels where id=walks)='Park walks', 'An admin renames';
 assert exists(select 1 from public.chat_messages where channel_id=walks and system->>'event'='renamed' and system->>'name'='Park walks'),
  'A renamed line';
 insert into public.chat_message_reports(message_id,reason) values('f0000000-0000-4000-8000-000000000004','spam');
end $$;
reset role;
select pg_temp.act_as('e6666666-6666-4666-8666-666666666666');
do $$
declare walks text := (select id from pg_temp.ids where name='walks'); queue jsonb := public.community_moderation_queue();
begin
 assert (select count(*) from public.chat_messages where channel_id=walks)=0, 'A moderator does not read private chats';
 assert exists(select 1 from jsonb_array_elements(queue) q where q->>'id'='f0000000-0000-4000-8000-000000000004'),
  'The reported message reaches the moderators';
 assert (select count(*) from jsonb_array_elements(queue) q where q->>'context'=walks)=1, 'Only that message';
end $$;
reset role;

-- Ana, the creator, leaves: she loses the whole chat. Ben stays admin.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 perform public.leave_private_chat(walks);
 assert (select count(*) from public.chat_channels where id=walks)=0, 'Who left does not see the chat';
 assert (select count(*) from public.chat_messages where channel_id=walks)=0, 'Who left sees no message';
end $$;
reset role;
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 assert exists(select 1 from public.chat_messages where channel_id=walks and system->>'event'='left'
               and author_id='e1111111-1111-4111-8111-111111111111'), 'A left line';
end $$;

-- The last admin leaving: the earliest-joined member becomes admin.
update public.chat_channel_members set role='member' where user_id='e2222222-2222-4222-8222-222222222222';
update public.chat_channel_members set role='admin' where user_id='e4444444-4444-4444-8444-444444444444';
update public.chat_channel_members set joined_at = now() - interval '5 minutes' where user_id='e2222222-2222-4222-8222-222222222222';
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
select public.leave_private_chat((select id from pg_temp.ids where name='walks'));
reset role;
do $$
declare walks text := (select id from pg_temp.ids where name='walks');
begin
 assert (select role from public.chat_channel_members where channel_id=walks and user_id='e2222222-2222-4222-8222-222222222222')='admin',
  'The earliest-joined member became admin';
end $$;
-- Everyone left: the chat is deleted.
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.leave_private_chat((select id from pg_temp.ids where name='walks'));
reset role;
do $$ begin
 assert not exists(select 1 from public.chat_channels where id=(select id from pg_temp.ids where name='walks')), 'An empty chat is deleted';
 assert not exists(select 1 from public.chat_messages where id='f0000000-0000-4000-8000-000000000003'), 'With its messages';
end $$;

-- A direct chat: the same two never get a second one.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into pg_temp.ids values ('direct', public.create_private_chat(array['e2222222-2222-4222-8222-222222222222']::uuid[], ''));
do $$
declare direct text := (select id from pg_temp.ids where name='direct');
begin
 assert public.create_private_chat(array['e2222222-2222-4222-8222-222222222222']::uuid[], '')=direct, 'Starting it again reopens it';
 assert (select name from public.chat_channels where id=direct)='', 'A direct chat has no name';
 assert (select count(*) from public.chat_messages where channel_id=direct)=0, 'No system lines in a chat of two';
 assert (public.my_private_chats()->0->>'direct_with')='e2222222-2222-4222-8222-222222222222', 'The list names the other person';
 begin
  perform public.invite_to_private_chat(direct, array['e3333333-3333-4333-8333-333333333333']::uuid[]);
  raise exception 'A third person joined a chat of two';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.rename_private_chat(direct, 'Us');
  raise exception 'A chat of two was named';
 exception when invalid_parameter_value then null; end;
end $$;
-- Ana's first message is written before Ben accepts, and reaches him.
insert into public.chat_messages(id,channel_id,author_id,body)
select 'f0000000-0000-4000-8000-000000000010', id, 'e1111111-1111-4111-8111-111111111111', 'Hi Ben, about the walk'
from pg_temp.ids where name='direct';
reset role;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$
declare direct text := (select id from pg_temp.ids where name='direct');
begin
 assert (public.my_chat_invitations()->0->>'direct')::boolean, 'Ben is invited to a chat of two';
 -- Ben starting a chat with Ana joins the one that exists.
 assert public.create_private_chat(array['e1111111-1111-4111-8111-111111111111']::uuid[], '')=direct, 'The same chat';
 assert exists(select 1 from public.chat_messages where id='f0000000-0000-4000-8000-000000000010'), 'The first message reached Ben';
 -- Ben blocks Ana: the chat closes for both.
 insert into public.user_blocks(blocked_id) values('e1111111-1111-4111-8111-111111111111');
 assert (public.my_private_chats()->0->>'closed')::boolean, 'A chat of two with a block is closed';
 begin
  insert into public.chat_messages(channel_id,author_id,body) values(direct,auth.uid(),'Bye');
  raise exception 'Ben wrote in a closed chat';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$
declare direct text := (select id from pg_temp.ids where name='direct');
begin
 begin
  insert into public.chat_messages(channel_id,author_id,body) values(direct,auth.uid(),'Still there?');
  raise exception 'Ana wrote in a closed chat';
 exception when insufficient_privilege then null; end;
 begin
  perform public.create_private_chat(array['e2222222-2222-4222-8222-222222222222']::uuid[], '');
  raise exception 'Ana reopened a closed chat';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
delete from public.user_blocks where blocked_id='e1111111-1111-4111-8111-111111111111';
reset role;

-- Limits: 10 new chats a day, 30 invitations a day, 30 people a chat.
insert into auth.users(id,email)
select ('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'crowd' || n || '@example.test'
from generate_series(1, 31) n;
select pg_temp.act_as('e3333333-3333-4333-8333-333333333333');
do $$
declare crowd uuid[] := (select array_agg(('a0000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid) from generate_series(1, 30) n);
begin
 begin
  perform public.create_private_chat(crowd, 'Too many');
  raise exception 'A chat took 31 people';
 exception when check_violation then null; end;
 perform public.create_private_chat(crowd[1:29], 'Full house');
 begin
  perform public.create_private_chat(crowd[30:30] || crowd[1:1], 'Over the limit');
  raise exception 'More than 30 invitations a day';
 exception when raise_exception then null; end;
end $$;
reset role;
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
do $$
begin
 for n in 1..10 loop
  perform public.create_private_chat(array['e3333333-3333-4333-8333-333333333333']::uuid[], 'Chat ' || n);
 end loop;
 begin
  perform public.create_private_chat(array['e3333333-3333-4333-8333-333333333333']::uuid[], 'Chat 11');
  raise exception 'More than 10 new chats a day';
 exception when raise_exception then null; end;
end $$;
reset role;

-- Push: private messages to every joined member (not the author, not who
-- muted it), counted up in one waiting notification; invitations.
delete from public.push_outbox;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.register_push_device('ben-token-000001', 'android', 'en');
reset role;
select pg_temp.act_as('e3333333-3333-4333-8333-333333333333');
select public.register_push_device('cleo-token-00001', 'android', 'he');
reset role;
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
select public.register_push_device('dov-token-000001', 'android', 'he');
reset role;
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into pg_temp.ids values ('pushy', public.create_private_chat(
 array['e2222222-2222-4222-8222-222222222222','e3333333-3333-4333-8333-333333333333','e4444444-4444-4444-8444-444444444444']::uuid[], 'Pushy'));
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind='invite' and target='room:' || (select id from pg_temp.ids where name='pushy'))=3,
  'Each invitee is told';
 assert (select preview from public.push_outbox where kind='invite' limit 1)='Pushy', 'The invitation names the chat';
end $$;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.answer_chat_invitation((select id from pg_temp.ids where name='pushy'), true);
reset role;
select pg_temp.act_as('e3333333-3333-4333-8333-333333333333');
select public.answer_chat_invitation((select id from pg_temp.ids where name='pushy'), true);
select public.set_private_chat_muted((select id from pg_temp.ids where name='pushy'), true);
reset role;
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
select public.answer_chat_invitation((select id from pg_temp.ids where name='pushy'), true);
insert into public.push_preferences(private_messages) values(false);
reset role;
delete from public.push_outbox;
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into public.chat_messages(id,channel_id,author_id,body)
select 'f0000000-0000-4000-8000-000000000020', id, 'e1111111-1111-4111-8111-111111111111', 'First' from pg_temp.ids where name='pushy';
insert into public.chat_messages(channel_id,author_id,body,reply_to)
select id, 'e1111111-1111-4111-8111-111111111111', 'Second', 'f0000000-0000-4000-8000-000000000020' from pg_temp.ids where name='pushy';
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox)=1, format('One waiting notification, got %s', (select jsonb_agg(to_jsonb(o)) from public.push_outbox o));
 assert (select recipient_id from public.push_outbox)='e2222222-2222-4222-8222-222222222222', 'Only Ben: Cleo muted it, Dov switched it off';
 assert (select kind||' '||count||' '||preview from public.push_outbox)='message 2 Second', 'It counts two and shows the latest';
end $$;
set local role service_role;
do $$
declare claimed jsonb := public.push_claim(10);
begin
 assert claimed->0->>'chat_name'='Pushy' and (claimed->0->>'count')::int=2 and not (claimed->0->>'direct')::boolean,
  format('The claim carries the chat''s name and the count: %s', claimed);
end $$;
reset role;
-- After a claim, a new message starts a new notification that still
-- counts what Ben has not read.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into public.chat_messages(channel_id,author_id,body) select id, 'e1111111-1111-4111-8111-111111111111', 'Third' from pg_temp.ids where name='pushy';
reset role;
do $$ begin
 assert (select count from public.push_outbox where preview='Third')=3, 'The new one counts three unread';
end $$;
-- Ben read the chat: the count starts again.
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.mark_chat_read((select id from pg_temp.ids where name='pushy'));
reset role;
update public.chat_reads set last_read_at = now() where user_id='e2222222-2222-4222-8222-222222222222';
update public.chat_messages set created_at = now() - interval '1 minute' where body in ('First','Second','Third');
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
insert into public.chat_messages(channel_id,author_id,body,created_at) select id, 'e1111111-1111-4111-8111-111111111111', 'Fourth', now() + interval '1 second' from pg_temp.ids where name='pushy';
reset role;
do $$ begin
 assert (select count from public.push_outbox where preview='Fourth')=1, 'After reading, the count starts again';
end $$;
rollback;
\echo 'Private chat tests passed.'
