\set ON_ERROR_STOP on
-- Disposable database only. Walk and play partners (0028_meetups.sql): who
-- reads and writes ads, the pet snapshot, places and times, the daily and
-- open limits, answers and the responders' group, blocks and reports,
-- moderation, expiry and clean-up, and the pushes.

-- Running the migration again changes nothing.
\i /tests/migrations/0028_meetups.sql

begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('e1111111-1111-4111-8111-111111111111','author@example.test','{"display_name":"Ron"}'),
 ('e2222222-2222-4222-8222-222222222222','reader@example.test','{"display_name":"Shira"}'),
 ('e3333333-3333-4333-8333-333333333333','fan@example.test','{"display_name":"Michal"}'),
 ('e4444444-4444-4444-8444-444444444444','blocked@example.test','{"display_name":"Yoav"}'),
 ('e5555555-5555-4555-8555-555555555555','moderator@example.test','{"display_name":"Mod"}'),
 ('e6666666-6666-4666-8666-666666666666','other@example.test','{"display_name":"Dana"}');
insert into public.user_capability_rules(user_id,capability,allowed)
values ('e5555555-5555-4555-8555-555555555555','community.moderate',true);

-- Ron's dog Bonnie (18 kg: medium), and a cat; a park; Michal saved it and
-- asked to hear about meetups there; phones for Michal and Ron.
insert into public.pets(id,owner_id,name,species,breed,birth_date,birth_date_approx,weight_kg,icon_key) values
 ('aaaaaaa1-0000-4000-8000-000000000001','e1111111-1111-4111-8111-111111111111','Bonnie','dog','Mixed','2023-05-01',true,18,'dog_floppy:sage'),
 ('aaaaaaa1-0000-4000-8000-000000000002','e1111111-1111-4111-8111-111111111111','Mitzi','cat',null,null,false,4,null),
 ('aaaaaaa1-0000-4000-8000-000000000003','e2222222-2222-4222-8222-222222222222','Lola','dog','Poodle',null,false,6,null);
insert into public.dog_parks(id,source,source_id,name_en,name_he,lat,lng,locality_code,fenced) values
 ('bbbbbbb1-0000-4000-8000-000000000001','admin','park-1','Ahuza dog park','גינת אחוזה',32.186,34.872,'raanana','yes'),
 ('bbbbbbb1-0000-4000-8000-000000000002','admin','park-2','Hidden park',null,32.18,34.88,'raanana','unknown');
update public.dog_parks set status='removed' where id='bbbbbbb1-0000-4000-8000-000000000002';
insert into public.dog_park_favorites(user_id,park_id,notify_meetups) values
 ('e3333333-3333-4333-8333-333333333333','bbbbbbb1-0000-4000-8000-000000000001',true),
 ('e2222222-2222-4222-8222-222222222222','bbbbbbb1-0000-4000-8000-000000000001',false);
insert into public.push_devices(token,user_id,platform,language) values
 ('fan-token-00000001','e3333333-3333-4333-8333-333333333333','android','he'),
 ('reader-token-000001','e2222222-2222-4222-8222-222222222222','android','en'),
 ('author-token-00001','e1111111-1111-4111-8111-111111111111','android','en');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
-- Runs [statement] and checks it is refused with [code] (an SQLSTATE) and,
-- when given, a message containing [words].
create function pg_temp.refused(statement text, code text, words text default null, why text default '')
returns void language plpgsql as $$
begin
 execute statement;
 raise exception 'Accepted, expected a refusal: % (%)', why, statement;
exception when others then
 if sqlerrm like 'Accepted, expected a refusal%' then raise; end if;
 if sqlstate <> code or (words is not null and position(words in sqlerrm) = 0) then
  raise exception 'Expected % % for "%" (%), got % %', code, coalesce(words,''), statement, why, sqlstate, sqlerrm;
 end if;
end $$;
create function pg_temp.walk_at_park() returns jsonb language sql as $$
 select '{"kind":"walk","pet_id":"aaaaaaa1-0000-4000-8000-000000000001","park_id":"bbbbbbb1-0000-4000-8000-000000000001",
          "weekdays":[7,1,2,3,4],"day_part":"morning","suits":["medium","small"],"note":"An hour in the morning"}'::jsonb
$$;
create function pg_temp.play_elsewhere() returns jsonb language sql as $$
 select jsonb_build_object('kind','play','locality_code','tel-aviv-yafo','place_text','  Yarkon Park, by the boats  ',
   'starts_at', now() + interval '1 day', 'ends_at', now() + interval '1 day 2 hours', 'note', 'Puppies only')
$$;

-- ---------------------------------------------------------------------------
-- Capabilities: everyone may look and post.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.can_use('community.meetups.view') and public.can_use('community.meetups.post'), 'Everyone may look and post';
end $$;
reset role;
set local role anon;
select pg_temp.refused('select count(*) from public.community_meetups', '42501', null, 'anonymous read');
select pg_temp.refused('select count(*) from public.community_meetup_board', '42501', null, 'anonymous board');
reset role;

-- ---------------------------------------------------------------------------
-- Posting: the pet's public facts, the park's city, the rules.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
create temp table ids(name text primary key, id uuid);
grant all on ids to authenticated, service_role;
do $$
declare walk uuid; play uuid; m public.community_meetups;
begin
 walk := public.meetup_save(null, pg_temp.walk_at_park());
 select * into m from public.community_meetups where id = walk;
 assert m.pet_name = 'Bonnie' and m.pet_species = 'dog' and m.pet_breed = 'Mixed' and m.pet_born_on = '2023-05-01'
   and m.pet_born_approx and m.pet_icon = 'dog_floppy:sage', 'The pet''s public facts are kept: ' || row_to_json(m)::text;
 assert m.pet_size = 'medium', 'An 18 kg dog is medium';
 assert m.audience = 'dog', 'A dog''s ad is for the dogs chip';
 assert m.locality_code = 'raanana' and m.place_text is null, 'A park gives the city';
 assert m.weekdays = '{1,2,3,4,7}' and m.day_part = 'morning', 'Weekdays are kept in order';
 assert m.suits = '{medium,small}', 'Sizes are kept';
 assert m.expires_at between now() + interval '29 days' and now() + interval '31 days', 'A recurring ad is up for 30 days';
 assert m.status = 'open' and m.author_id = 'e1111111-1111-4111-8111-111111111111', 'Open, by its author';

 play := public.meetup_save(null, pg_temp.play_elsewhere());
 select * into m from public.community_meetups where id = play;
 assert m.pet_id is null and m.pet_name is null and m.audience = 'all', 'No pet: for everyone';
 assert m.place_text = 'Yarkon Park, by the boats', 'The place is trimmed';
 assert m.expires_at = m.ends_at, 'A one-off ad ends with its time';
 insert into ids values ('walk', walk), ('play', play);

 -- Every size is the same as no size.
 walk := public.meetup_save(null,
   pg_temp.walk_at_park() || '{"suits":["small","medium","large"],"pet_id":"aaaaaaa1-0000-4000-8000-000000000002"}'::jsonb);
 assert (select suits from public.community_meetups where id = walk) = '{}', 'All three sizes are stored as every size';
 assert (select audience from public.community_meetups where pet_name = 'Mitzi') = 'cat', 'A cat''s ad is for the cats chip';
 assert (select pet_size from public.community_meetups where pet_name = 'Mitzi') is null, 'Only dogs get a size';
end $$;

-- What is refused.
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || '{"kind":"run"}')$$, '22023', 'invalid_meetup', 'unknown kind');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || '{"pet_id":"aaaaaaa1-0000-4000-8000-000000000003"}')$$, '22023', 'invalid_meetup', 'someone else''s pet');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || '{"park_id":"bbbbbbb1-0000-4000-8000-000000000002"}')$$, '22023', 'invalid_meetup', 'a removed park');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere() - 'place_text')$$, '22023', 'invalid_meetup', 'no place');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere() || '{"locality_code":"Tel Aviv"}')$$, '22023', 'invalid_meetup', 'a malformed city code');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere() || jsonb_build_object('ends_at', now() - interval '1 hour', 'starts_at', now() - interval '2 hours'))$$, '22023', 'invalid_meetup', 'already over');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere() || jsonb_build_object('ends_at', now() + interval '2 days'))$$, '22023', 'invalid_meetup', 'longer than 12 hours');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || '{"weekdays":[0,8]}')$$, '22023', 'invalid_meetup', 'no such weekday');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() - 'day_part')$$, '22023', 'invalid_meetup', 'no part of the day');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || jsonb_build_object('note', repeat('x', 201)))$$, '22023', 'invalid_meetup', 'a long note');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.walk_at_park() || '{"suits":["huge"]}')$$, '22023', 'invalid_meetup', 'unknown size');
-- Never by hand.
select pg_temp.refused($$insert into public.community_meetups(kind,locality_code,place_text,weekdays,day_part,expires_at) values ('walk','raanana','x','{1}','morning',now()+interval '1 day')$$, '42501', null, 'direct insert');
select pg_temp.refused($$update public.community_meetups set note = 'x'$$, '42501', null, 'direct update');
select pg_temp.refused($$delete from public.community_meetups$$, '42501', null, 'direct delete');
select pg_temp.refused($$insert into public.community_meetup_answers(meetup_id) select id from ids where name = 'walk'$$, '42501', null, 'direct answer');

-- Three new ads a day.
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere())$$, 'P0001', 'rate_limited', 'a fourth ad today');
reset role;
-- (Yesterday's ads do not count against today.)
update public.community_meetups set created_at = now() - interval '2 days';
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
select public.meetup_save(null, pg_temp.play_elsewhere());
select public.meetup_save(null, pg_temp.play_elsewhere());
-- Five open at once.
reset role;
update public.community_meetups set created_at = now() - interval '2 days';
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.play_elsewhere())$$, 'P0001', 'too_many_open', 'a sixth open ad');
do $$ begin
 assert (select count(*) from public.community_meetups where status = 'open') = 5, 'Five open ads';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Reading.
-- ---------------------------------------------------------------------------
-- One of Ron's one-off ads is over, one he closed.
update public.community_meetups set starts_at = now() - interval '3 hours', ends_at = now() - interval '1 hour', expires_at = now() - interval '1 hour'
where id = (select id from public.community_meetups where kind = 'play' and id <> (select id from ids where name='play') order by id limit 1);
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$ begin
 perform public.meetup_close((select id from public.community_meetups where pet_name = 'Mitzi'));
 assert (select status from public.community_meetups where pet_name = 'Mitzi') = 'closed', 'Closed by its author';
 assert (select count(*) from public.community_meetups) = 5, 'The author sees all of their ads';
end $$;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$
declare b record;
begin
 assert (select count(*) from public.community_meetups) = 3, 'Members see only open ads';
 select * into b from public.community_meetup_board where id = (select id from ids where name = 'walk');
 assert b.author_name = 'Ron' and b.park_name_en = 'Ahuza dog park' and b.park_fenced = 'yes' and b.pet_id is null
   and not b.answered and not b.hidden, 'The board carries the author, the park, no pet id: ' || row_to_json(b)::text;
 assert (select count(*) from public.community_meetup_board where locality_code = any(array['raanana'])) = 1, 'Ads by city codes';
 perform pg_temp.refused('select public.meetup_close((select id from ids where name = ''walk''))', '22023', 'invalid_meetup', 'closing someone else''s ad');
 perform pg_temp.refused('select public.meetup_save((select id from ids where name = ''walk''), pg_temp.walk_at_park())', '22023', 'invalid_meetup', 'editing someone else''s ad');
 perform pg_temp.refused('select public.meetup_responders((select id from ids where name = ''walk''))', '22023', 'invalid_meetup', 'someone else''s responders');
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Answers and the group.
-- ---------------------------------------------------------------------------
insert into public.user_blocks(blocker_id, blocked_id) values ('e1111111-1111-4111-8111-111111111111','e4444444-4444-4444-8444-444444444444');
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.meetup_answer((select id from ids where name = 'walk')) = 1, 'One answered';
 assert public.meetup_answer((select id from ids where name = 'walk')) = 1, 'Answering twice counts once';
 assert (select answered from public.community_meetup_board where id = (select id from ids where name = 'walk')), 'The reader answered';
 assert (select count(*) from public.community_meetup_answers) = 1, 'A member reads their own answers';
end $$;
select pg_temp.act_as('e6666666-6666-4666-8666-666666666666');
select public.meetup_answer((select id from ids where name = 'walk'));
do $$ begin
 assert (select count(*) from public.community_meetup_answers) = 1, 'Not the answers of others';
end $$;
-- Yoav, whom Ron blocked, cannot see nor answer Ron's ads.
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
do $$ begin
 assert (select count(*) from public.community_meetups) = 3, 'The block hides nothing from the blocked one''s view of open ads';
end $$;
select pg_temp.refused($$select public.meetup_answer((select id from ids where name = 'walk'))$$, 'P0001', 'blocked', 'answering across a block');
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
select pg_temp.refused($$select public.meetup_answer((select id from ids where name = 'walk'))$$, '22023', 'invalid_meetup', 'answering one''s own ad');
do $$
declare names text[];
begin
 assert (select answer_count from public.community_meetups where id = (select id from ids where name = 'walk')) = 2, 'Two answered';
 assert (select count(*) from public.community_meetup_answers) = 2, 'The author reads the answers to their ad';
 select array_agg(display_name order by display_name) into names from public.meetup_responders((select id from ids where name = 'walk'));
 assert names = '{Dana,Shira}', 'The responders: ' || names::text;
end $$;
-- Someone the author blocks later drops out of the group.
reset role;
insert into public.user_blocks(blocker_id, blocked_id) values ('e6666666-6666-4666-8666-666666666666','e1111111-1111-4111-8111-111111111111');
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$ begin
 assert (select count(*) from public.meetup_responders((select id from ids where name = 'walk'))) = 1, 'Nobody across a block';
end $$;
reset role;
delete from public.user_blocks where blocker_id = 'e6666666-6666-4666-8666-666666666666';
-- Shira blocks Ron: his ads disappear for her.
insert into public.user_blocks(blocker_id, blocked_id) values ('e2222222-2222-4222-8222-222222222222','e1111111-1111-4111-8111-111111111111');
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
do $$ begin
 assert (select count(*) from public.community_meetup_board) = 0, 'A blocked member''s ads are hidden';
end $$;
reset role;
delete from public.user_blocks where blocker_id = 'e2222222-2222-4222-8222-222222222222';

-- ---------------------------------------------------------------------------
-- Editing, closing, renewing.
-- ---------------------------------------------------------------------------
update public.community_meetups set expires_at = now() + interval '3 days' where id = (select id from ids where name = 'walk');
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$
declare m public.community_meetups;
begin
 perform public.meetup_save((select id from ids where name = 'walk'), pg_temp.walk_at_park() || '{"kind":"play","note":"Changed"}');
 select * into m from public.community_meetups where id = (select id from ids where name = 'walk');
 assert m.kind = 'play' and m.note = 'Changed', 'Edited';
 assert m.expires_at < now() + interval '4 days', 'An edit keeps the 30 days running';
 perform pg_temp.refused('select public.meetup_renew((select id from ids where name = ''play''))', '22023', 'invalid_meetup', 'renewing a one-off ad');
 perform public.meetup_renew((select id from ids where name = 'walk'));
 select * into m from public.community_meetups where id = (select id from ids where name = 'walk');
 assert m.expires_at > now() + interval '29 days', 'Renewed for 30 days';
 -- The closed cat ad comes back only while fewer than five are open.
 perform public.meetup_renew((select id from public.community_meetups where pet_name = 'Mitzi'));
 assert (select status from public.community_meetups where pet_name = 'Mitzi') = 'open', 'A closed recurring ad renews';
 -- A closed ad cannot be edited.
 perform public.meetup_close((select id from ids where name = 'play'));
 perform pg_temp.refused('select public.meetup_save((select id from ids where name = ''play''), pg_temp.play_elsewhere())', 'P0001', 'not_open', 'editing a closed ad');
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Reports and moderation.
-- ---------------------------------------------------------------------------
do $$
declare reporter uuid;
begin
 foreach reporter in array array['e2222222-2222-4222-8222-222222222222','e3333333-3333-4333-8333-333333333333']::uuid[] loop
  perform pg_temp.act_as(reporter);
  insert into public.community_meetup_reports(meetup_id, reason) select id, 'spam' from ids where name = 'walk';
  assert not exists (select 1 from public.community_meetup_board where id = (select id from ids where name = 'walk')),
   'The reporter no longer sees it';
 end loop;
 perform pg_temp.act_as('e6666666-6666-4666-8666-666666666666');
 assert exists (select 1 from public.community_meetups where id = (select id from ids where name = 'walk')), 'Two reports hide nothing';
end $$;
select pg_temp.act_as('e6666666-6666-4666-8666-666666666666');
insert into public.community_meetup_reports(meetup_id, reason) select id, 'abusive' from ids where name = 'walk';
select pg_temp.refused($$insert into public.community_meetup_reports(meetup_id, reporter_id, reason) select id, 'e3333333-3333-4333-8333-333333333333', 'spam' from ids where name = 'play'$$, '42501', null, 'reporting as someone else');
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
do $$ begin
 assert not exists (select 1 from public.community_meetups where id = (select id from ids where name = 'walk')), 'Three reports hide the ad';
end $$;
select pg_temp.refused($$select public.meetup_answer((select id from ids where name = 'walk'))$$, 'P0001', 'not_open', 'answering a hidden ad');
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
do $$ begin
 assert (select hidden from public.community_meetup_board where id = (select id from ids where name = 'walk')), 'Its author sees it, marked hidden';
end $$;
select pg_temp.act_as('e5555555-5555-4555-8555-555555555555');
do $$
declare item jsonb;
begin
 select x into item from jsonb_array_elements(public.community_moderation_queue()) x where x->>'kind' = 'meetup';
 assert item->>'id' = (select id::text from ids where name = 'walk') and (item->>'report_count')::int = 3
   and (item->>'hidden')::boolean and item->>'body' = 'Changed' and item->>'context' = 'raanana' and item->>'author_name' = 'Ron',
   'The queue shows the ad: ' || coalesce(item::text, 'nothing');
 perform public.community_moderate('meetup', (select id from ids where name = 'walk'), 'keep');
 assert not exists (select 1 from jsonb_array_elements(public.community_moderation_queue()) x where x->>'kind' = 'meetup'),
  'Kept: out of the queue with a fresh count';
end $$;
select pg_temp.act_as('e4444444-4444-4444-8444-444444444444');
do $$ begin
 assert exists (select 1 from public.community_meetups where id = (select id from ids where name = 'walk')), 'Kept: shown again';
end $$;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select pg_temp.refused($$select public.community_moderate('meetup', (select id from ids where name = 'walk'), 'remove')$$, '42501', null, 'a member moderating');
select pg_temp.act_as('e5555555-5555-4555-8555-555555555555');
select public.community_moderate('meetup', (select id from ids where name = 'play'), 'remove');
reset role;
do $$ begin
 assert not exists (select 1 from public.community_meetups where id = (select id from ids where name = 'play')), 'Removed: deleted';
end $$;

-- ---------------------------------------------------------------------------
-- Pushes: a new ad at a saved park, at most three a day; the renewal
-- reminder; the clean-up.
-- ---------------------------------------------------------------------------
delete from public.push_outbox;
update public.community_meetups set created_at = now() - interval '2 days';
delete from public.community_meetups where id not in (select id from ids where name = 'walk');
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.meetup_save(null, pg_temp.walk_at_park() || '{"pet_id":"aaaaaaa1-0000-4000-8000-000000000003","note":"Lola too"}');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox) = 1, 'One push: ' || (select coalesce(jsonb_agg(o)::text,'') from public.push_outbox o);
 assert (select recipient_id from public.push_outbox where kind = 'meetup') = 'e3333333-3333-4333-8333-333333333333',
  'The member who asked to hear about the park (not the one who did not, not the author)';
 assert (select preview from public.push_outbox) = 'Lola too', 'With the note';
end $$;
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.meetup_save(null, pg_temp.walk_at_park() || '{"pet_id":null}');
select public.meetup_save(null, pg_temp.play_elsewhere());
reset role;
update public.community_meetups set created_at = now() - interval '2 days';
select pg_temp.act_as('e2222222-2222-4222-8222-222222222222');
select public.meetup_save(null, pg_temp.walk_at_park() || '{"pet_id":null}');
select public.meetup_save(null, pg_temp.walk_at_park() || '{"pet_id":null}');
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind = 'meetup') = 3, 'Three a day at most (and none for another place)';
end $$;
-- A member blocked by the fan reaches them no more.
delete from public.push_outbox;
update public.community_meetups set created_at = now() - interval '2 days';
insert into public.user_blocks(blocker_id, blocked_id) values ('e3333333-3333-4333-8333-333333333333','e1111111-1111-4111-8111-111111111111');
update public.community_meetups set status = 'closed', closed_at = now() where author_id = 'e1111111-1111-4111-8111-111111111111';
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
select public.meetup_save(null, pg_temp.walk_at_park());
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox) = 0, 'Nothing across a block';
end $$;

-- The claim (service role): the housekeeping runs first, and a meetup
-- push carries its kind and park.
delete from public.user_blocks where blocker_id = 'e3333333-3333-4333-8333-333333333333';
delete from public.push_outbox;
insert into public.push_outbox(recipient_id, kind, actor_id, target, preview)
select 'e3333333-3333-4333-8333-333333333333', 'meetup', author_id, 'meetup:' || id, note
from public.community_meetups where author_id = 'e1111111-1111-4111-8111-111111111111' and status = 'open';
-- Ron's walk ended yesterday; Shira has an ad closed three months ago and
-- one that ended 100 days ago.
update public.community_meetups set status = 'open', closed_at = null, expires_at = now() - interval '1 day'
 where id = (select id from ids where name = 'walk');
update public.community_meetups set status = 'closed', closed_at = now() - interval '91 days'
 where id = (select id from public.community_meetups where author_id = 'e2222222-2222-4222-8222-222222222222' and park_id is not null order by created_at, id limit 1);
update public.community_meetups set starts_at = now() - interval '100 days 2 hours', ends_at = now() - interval '100 days',
 expires_at = now() - interval '100 days'
 where author_id = 'e2222222-2222-4222-8222-222222222222' and kind = 'play';
set local role service_role;
do $$
declare items jsonb; meetup jsonb; renew jsonb;
begin
 items := public.push_claim(100);
 select x into meetup from jsonb_array_elements(items) x where x->>'kind' = 'meetup';
 select x into renew from jsonb_array_elements(items) x where x->>'kind' = 'meetup_renew';
 assert meetup->>'meetup_kind' = 'walk' and meetup->>'park_name_en' = 'Ahuza dog park' and meetup->>'park_name_he' = 'גינת אחוזה'
   and meetup->>'actor_name' = 'Ron', 'A meetup push names the park: ' || coalesce(meetup::text, 'nothing');
 assert renew->>'target' = 'meetup:' || (select id from ids where name = 'walk')
   and renew->'devices'->0->>'token' = 'author-token-00001', 'The author hears their ad ended: ' || coalesce(renew::text, 'nothing');
 assert (select renew_notified_at from public.community_meetups where id = (select id from ids where name = 'walk')) is not null, 'Once';
 assert jsonb_array_length(public.push_claim(100)) = 0, 'Not twice';
 assert (select count(*) from public.community_meetups where author_id = 'e2222222-2222-4222-8222-222222222222') = 3,
  'A closed ad from three months ago is deleted';
 assert not exists (select 1 from public.community_meetups where kind = 'play' and author_id = 'e2222222-2222-4222-8222-222222222222'),
  'An ad that ended more than 90 days ago is deleted';
 assert exists (select 1 from public.community_meetups where id = (select id from ids where name = 'walk')), 'A recent one stays';
end $$;
reset role;

-- Renewing reopens the reminder.
select pg_temp.act_as('e1111111-1111-4111-8111-111111111111');
select public.meetup_renew((select id from ids where name = 'walk'));
reset role;
do $$ begin
 assert (select renew_notified_at from public.community_meetups where id = (select id from ids where name = 'walk')) is null, 'Renewed: a new reminder later';
end $$;

-- An account that goes takes its ads and answers with it.
delete from auth.users where id = 'e1111111-1111-4111-8111-111111111111';
do $$ begin
 assert not exists (select 1 from public.community_meetups where author_id = 'e1111111-1111-4111-8111-111111111111'), 'Ads go with the account';
end $$;
rollback;
\echo 'Meetups tests passed.'
