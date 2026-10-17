\set ON_ERROR_STOP on
-- Disposable database only. The neighbourhood (0035_neighbourhood.sql):
-- "going out now" ads (the time rules, their own daily limit, one at a
-- time, no edits, the push to a saved park and the leaving time in the
-- claim) and hazard reports (who reads and writes, the daily limit, votes
-- that hide, the author's delete, blocks, the clean-up, account deletion).
-- Running the migration again changes nothing (and puts back its
-- meetup_save and push_claim line, which the meetups test re-applied 0028
-- over).
\i /tests/migrations/0035_neighbourhood.sql

begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('f1111111-1111-4111-8111-111111111111','dana@example.test','{"display_name":"Dana"}'),
 ('f2222222-2222-4222-8222-222222222222','fan@example.test','{"display_name":"Omer"}'),
 ('f3333333-3333-4333-8333-333333333333','third@example.test','{"display_name":"Tal"}'),
 ('f4444444-4444-4444-8444-444444444444','fourth@example.test','{"display_name":"Gal"}'),
 ('f5555555-5555-4555-8555-555555555555','off@example.test','{"display_name":"Off"}');
-- Gal's hazard reports are switched off by an administrator.
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('f5555555-5555-4555-8555-555555555555','community.hazards.view',false);

insert into public.pets(id,owner_id,name,species,weight_kg) values
 ('ccccccc1-0000-4000-8000-000000000001','f1111111-1111-4111-8111-111111111111','Max','dog',14);
insert into public.dog_parks(id,source,source_id,name_en,name_he,lat,lng,locality_code,fenced) values
 ('ddddddd1-0000-4000-8000-000000000001','admin','nb-park-1','Yarkon park','פארק הירקון',32.1,34.8,'tel-aviv-yafo','yes');
insert into public.dog_park_favorites(user_id,park_id,notify_meetups) values
 ('f2222222-2222-4222-8222-222222222222','ddddddd1-0000-4000-8000-000000000001',true);
insert into public.push_devices(token,user_id,platform,language) values
 ('nb-fan-token-0001','f2222222-2222-4222-8222-222222222222','android','en');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
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
-- Leaving for the park in 25 minutes; the ad lasts 90 minutes.
create function pg_temp.going_now() returns jsonb language sql as $$
 select jsonb_build_object('kind','walk','now',true,'pet_id','ccccccc1-0000-4000-8000-000000000001',
   'park_id','ddddddd1-0000-4000-8000-000000000001',
   'starts_at', now() + interval '25 minutes', 'ends_at', now() + interval '90 minutes', 'note', 'Slow one')
$$;
create temp table ids(name text primary key, id uuid);
grant all on ids to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Going out now.
-- ---------------------------------------------------------------------------
delete from public.push_outbox;
select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
do $$
declare first uuid; m public.community_meetups;
begin
 first := public.meetup_save(null, pg_temp.going_now());
 select * into m from public.community_meetups where id = first;
 assert m.kind = 'walk_now', 'A now walk: ' || m.kind;
 assert m.expires_at = m.ends_at and m.starts_at = now() + interval '25 minutes', 'It ends by itself at its end';
 assert m.locality_code = 'tel-aviv-yafo' and m.pet_size = 'medium', 'The park''s city and the pet''s facts';
 insert into ids values ('first', first);
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.push_outbox where kind = 'meetup'
          and recipient_id = 'f2222222-2222-4222-8222-222222222222') = 1,
  'The member who saved the park hears about it: ' || (select coalesce(jsonb_agg(o)::text, '') from public.push_outbox o);
end $$;

-- The claim carries the leaving time and the now kind.
set local role service_role;
do $$
declare items jsonb; item jsonb;
begin
 items := public.push_claim(100);
 select x into item from jsonb_array_elements(items) x where x->>'kind' = 'meetup';
 assert item->>'meetup_kind' = 'walk_now' and (item->>'leaves_at')::timestamptz = now() + interval '25 minutes'
   and item->>'park_name_en' = 'Yarkon park' and item->>'actor_name' = 'Dana',
   'The claim says where and when: ' || coalesce(item::text, 'nothing');
end $$;
reset role;

-- The time rules, no edits.
select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now() || jsonb_build_object('starts_at', now() + interval '2 hours', 'ends_at', now() + interval '3 hours'))$$, '22023', 'invalid_meetup', 'leaving in two hours');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now() || jsonb_build_object('starts_at', now() - interval '1 hour'))$$, '22023', 'invalid_meetup', 'left an hour ago');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now() || jsonb_build_object('ends_at', now() + interval '3 hours'))$$, '22023', 'invalid_meetup', 'longer than 90 minutes after leaving');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now() - 'ends_at')$$, '22023', 'invalid_meetup', 'no end');
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now() || '{"weekdays":[1],"day_part":"morning"}')$$, '22023', 'invalid_meetup', 'a recurring now ad');
select pg_temp.refused($$select public.meetup_save((select id from ids where name = 'first'), pg_temp.going_now())$$, '22023', 'invalid_meetup', 'editing a now ad');
select pg_temp.refused($$select public.meetup_renew((select id from ids where name = 'first'))$$, '22023', 'invalid_meetup', 'renewing a now ad');

-- One at a time: a second one closes the first. Three a day, apart from
-- the planned ads.
do $$
declare second uuid;
begin
 second := public.meetup_save(null, pg_temp.going_now() || '{"kind":"play"}');
 assert (select kind from public.community_meetups where id = second) = 'play_now', 'A now playdate';
 assert (select status from public.community_meetups where id = (select id from ids where name = 'first')) = 'closed',
  'The earlier one is closed';
 assert (select count(*) from public.community_meetups where author_id = auth.uid() and status = 'open') = 1, 'One open';
 perform public.meetup_save(null, pg_temp.going_now());
end $$;
select pg_temp.refused($$select public.meetup_save(null, pg_temp.going_now())$$, 'P0001', 'rate_limited', 'a fourth now ad today');
-- A planned ad is still allowed (its own three a day).
select public.meetup_save(null, jsonb_build_object('kind','walk','park_id','ddddddd1-0000-4000-8000-000000000001',
  'starts_at', now() + interval '1 day', 'ends_at', now() + interval '1 day 1 hour'));
reset role;

-- Members read it on the board as any open ad.
select pg_temp.act_as('f3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.community_meetup_board where kind in ('walk_now','play_now')) = 1,
  'The open now ad is on the board (closed ones are not)';
 assert public.meetup_answer((select id from public.community_meetup_board where kind = 'walk_now')) = 1, 'I want to join';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Hazard reports.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('f3333333-3333-4333-8333-333333333333');
do $$ begin
 assert public.can_use('community.hazards.view') and public.can_use('community.hazards.post'), 'Everyone may read and report';
end $$;
reset role;
set local role anon;
select pg_temp.refused('select count(*) from public.hazard_reports', '42501', null, 'anonymous read');
select pg_temp.refused('select count(*) from public.hazard_board', '42501', null, 'anonymous board');
reset role;

select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
do $$
declare at_park uuid; elsewhere uuid; h public.hazard_reports;
begin
 at_park := public.hazard_report('{"kind":"caterpillars","park_id":"ddddddd1-0000-4000-8000-000000000001","note":"  By the gate  "}');
 select * into h from public.hazard_reports where id = at_park;
 assert h.locality_code = 'tel-aviv-yafo' and h.note = 'By the gate' and not h.hidden, 'The park''s city, the note trimmed';
 assert h.expires_at = now() + interval '7 days', 'A week';
 elsewhere := public.hazard_report('{"kind":"bait","locality_code":"petah-tikva","note":"River path"}');
 insert into ids values ('at_park', at_park), ('elsewhere', elsewhere);
end $$;
select pg_temp.refused($$select public.hazard_report('{"kind":"wolves","locality_code":"petah-tikva"}')$$, '22023', 'invalid_hazard', 'unknown kind');
select pg_temp.refused($$select public.hazard_report('{"kind":"glass"}')$$, '22023', 'invalid_hazard', 'no place');
select pg_temp.refused($$select public.hazard_report('{"kind":"glass","locality_code":"Petah Tikva"}')$$, '22023', 'invalid_hazard', 'a malformed city code');
select pg_temp.refused($$select public.hazard_report('{"kind":"glass","park_id":"ddddddd1-0000-4000-8000-00000000dead"}')$$, '22023', 'invalid_hazard', 'an unknown park');
select pg_temp.refused($$select public.hazard_report(jsonb_build_object('kind','glass','locality_code','petah-tikva','note',repeat('x',141)))$$, '22023', 'invalid_hazard', 'a long note');
select pg_temp.refused($$select public.hazard_report('{"kind":"other","locality_code":"petah-tikva"}')$$, '22023', 'invalid_hazard', '"other" without a word');
-- Never by hand.
select pg_temp.refused($$insert into public.hazard_reports(locality_code,kind) values ('petah-tikva','glass')$$, '42501', null, 'direct insert');
select pg_temp.refused($$update public.hazard_reports set hidden = true$$, '42501', null, 'direct update');
select pg_temp.refused($$delete from public.hazard_reports$$, '42501', null, 'direct delete');
select pg_temp.refused($$insert into public.hazard_votes(report_id,gone) select id, true from ids where name = 'at_park'$$, '42501', null, 'direct vote');
-- Five a day.
select public.hazard_report('{"kind":"glass","locality_code":"petah-tikva"}');
select public.hazard_report('{"kind":"glass","locality_code":"petah-tikva"}');
select public.hazard_report('{"kind":"inspector","locality_code":"petah-tikva"}');
select pg_temp.refused($$select public.hazard_report('{"kind":"glass","locality_code":"petah-tikva"}')$$, 'P0001', 'rate_limited', 'a sixth report today');
-- The author does not vote on their own report.
select pg_temp.refused($$select public.hazard_vote((select id from ids where name = 'at_park'), true)$$, '22023', 'invalid_hazard', 'own report');
reset role;

-- Reading: members see current reports with the votes; not Gal (off).
select pg_temp.act_as('f2222222-2222-4222-8222-222222222222');
do $$ begin
 assert (select count(*) from public.hazard_board) = 5, 'Every current report';
 assert (select park_name_en from public.hazard_board where id = (select id from ids where name = 'at_park')) = 'Yarkon park', 'With its park';
 assert not (select mine from public.hazard_board where id = (select id from ids where name = 'at_park')), 'Not mine';
 -- "Still there", then changed to "Not there any more".
 assert public.hazard_vote((select id from ids where name = 'at_park'), false), 'Still shown';
 assert (select still_count from public.hazard_board where id = (select id from ids where name = 'at_park')) = 1, 'One "still there"';
 assert (select my_vote from public.hazard_board where id = (select id from ids where name = 'at_park')) = false, 'My vote';
 assert public.hazard_vote((select id from ids where name = 'at_park'), true), 'One "not there any more" keeps it';
 assert (select still_count + gone_count from public.hazard_board where id = (select id from ids where name = 'at_park')) = 1, 'A vote is changed, not added';
end $$;
reset role;
select pg_temp.act_as('f5555555-5555-4555-8555-555555555555');
select pg_temp.refused($$select public.hazard_vote((select id from ids where name = 'at_park'), true)$$, '42501', null, 'switched off');
do $$ begin
 assert (select count(*) from public.hazard_board) = 0, 'Switched off: nothing to read';
end $$;
reset role;

-- A second "not there any more" hides it (its author still sees it).
select pg_temp.act_as('f3333333-3333-4333-8333-333333333333');
do $$ begin
 assert not public.hazard_vote((select id from ids where name = 'at_park'), true), 'Two gone votes hide it';
 assert not exists (select 1 from public.hazard_board where id = (select id from ids where name = 'at_park')), 'Hidden from members';
end $$;
select pg_temp.refused($$select public.hazard_vote((select id from ids where name = 'at_park'), false)$$, 'P0001', 'not_open', 'voting on a hidden report');
reset role;
select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
do $$ begin
 assert (select hidden from public.hazard_board where id = (select id from ids where name = 'at_park')), 'Its author sees it, hidden';
end $$;
reset role;

-- Blocks: a member who blocked the author no longer sees their reports.
insert into public.user_blocks(blocker_id, blocked_id) values ('f4444444-4444-4444-8444-444444444444','f1111111-1111-4111-8111-111111111111');
select pg_temp.act_as('f4444444-4444-4444-8444-444444444444');
do $$ begin
 assert (select count(*) from public.hazard_board) = 0, 'Nothing of someone I blocked';
end $$;
select pg_temp.refused($$select public.hazard_vote((select id from ids where name = 'elsewhere'), true)$$, 'P0001', 'not_open', 'voting across a block');
reset role;

-- The author deletes their report; nobody else can.
select pg_temp.act_as('f2222222-2222-4222-8222-222222222222');
select pg_temp.refused($$select public.hazard_delete((select id from ids where name = 'elsewhere'))$$, '22023', 'invalid_hazard', 'someone else''s report');
reset role;
select pg_temp.act_as('f1111111-1111-4111-8111-111111111111');
select public.hazard_delete((select id from ids where name = 'elsewhere'));
reset role;
do $$ begin
 assert not exists (select 1 from public.hazard_reports where id = (select id from ids where name = 'elsewhere')), 'Deleted';
end $$;

-- Expired: hidden from members at once, deleted 30 days later.
update public.hazard_reports set expires_at = now() - interval '1 day' where id = (select id from ids where name = 'at_park');
update public.hazard_reports set expires_at = now() - interval '31 days'
 where id = (select id from public.hazard_reports where kind = 'inspector');
select community_private.hazards_housekeeping();
do $$ begin
 assert exists (select 1 from public.hazard_reports where id = (select id from ids where name = 'at_park')), 'Expired yesterday: kept';
 assert not exists (select 1 from public.hazard_reports where kind = 'inspector'), 'Expired a month ago: deleted';
end $$;
select pg_temp.act_as('f3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.hazard_board where kind = 'glass') = 2, 'Current ones still show';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Posts near me (0036): a city and, for a recommendation, a place.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('f3333333-3333-4333-8333-333333333333');
insert into public.community_posts(author_id, body, kind, locality_code, place_name)
values ('f3333333-3333-4333-8333-333333333333', 'Gentle with seniors', 'recommendation', 'petah-tikva', 'Dr. Levi''s clinic');
insert into public.community_posts(author_id, body) values ('f3333333-3333-4333-8333-333333333333', 'Everywhere');
do $$ begin
 assert (select count(*) from public.community_feed where locality_code = 'petah-tikva'
          and place_name = 'Dr. Levi''s clinic') = 1, 'The feed carries the city and the place';
 assert (select locality_code from public.community_feed where body = 'Everywhere') is null, 'No city: everywhere';
end $$;
select pg_temp.refused($$insert into public.community_posts(author_id, body, kind, place_name) values (auth.uid(), 'x', 'moment', 'A shop')$$, '23514', null, 'a place on a moment');
select pg_temp.refused($$insert into public.community_posts(author_id, body, kind, place_name) values (auth.uid(), 'x', 'recommendation', repeat('x', 81))$$, '23514', null, 'a long place');
select pg_temp.refused($$insert into public.community_posts(author_id, body, locality_code) values (auth.uid(), 'x', 'Petah Tikva')$$, '23514', null, 'a malformed city code');
reset role;

-- An account that goes takes its reports and votes with it.
delete from auth.users where id = 'f1111111-1111-4111-8111-111111111111';
delete from auth.users where id = 'f2222222-2222-4222-8222-222222222222';
do $$ begin
 assert not exists (select 1 from public.hazard_reports where created_by = 'f1111111-1111-4111-8111-111111111111'), 'Reports go with the account';
 assert not exists (select 1 from public.hazard_votes where user_id = 'f2222222-2222-4222-8222-222222222222'), 'Votes go with the account';
end $$;
rollback;
\echo 'Neighbourhood tests passed.'
