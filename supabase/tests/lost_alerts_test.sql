\set ON_ERROR_STOP on
-- Disposable database only. The safety hub and Lost mode
-- (0034_lost_alerts.sql): the beta-only capabilities, starting an alert
-- (the post, the alert, the lost card, the pushes to members nearby and
-- their limits), what is refused, sightings, the household's and the
-- neighbours' reads, found and cancel, the push kind list.

-- Running the migration again changes nothing.
\i /tests/migrations/0034_lost_alerts.sql

begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('c1111111-1111-4111-8111-111111111111','owner@example.test','{"display_name":"Noa"}'),
 ('c2222222-2222-4222-8222-222222222222','carer@example.test','{"display_name":"Eli"}'),
 ('c3333333-3333-4333-8333-333333333333','parkfan@example.test','{"display_name":"Maya"}'),
 ('c4444444-4444-4444-8444-444444444444','walker@example.test','{"display_name":"Tom"}'),
 ('c5555555-5555-4555-8555-555555555555','blocker@example.test','{"display_name":"Gil"}'),
 ('c6666666-6666-4666-8666-666666666666','quiet@example.test','{"display_name":"Rina"}'),
 ('c7777777-7777-4777-8777-777777777777','standard@example.test','{"display_name":"Omer"}');

-- Omer is a standard owner only: not in the beta.
delete from public.access_group_members
where user_id = 'c7777777-7777-4777-8777-777777777777' and group_id = 'acc35500-0000-4000-8000-000000000002';

-- Noa's dog Kelly (with a lost card draft), Eli joins Noa's household.
insert into public.pets(id,owner_id,name,species,breed) values
 ('dddddd01-0000-4000-8000-000000000001','c1111111-1111-4111-8111-111111111111','Kelly','dog','Labrador'),
 ('dddddd01-0000-4000-8000-000000000002','c1111111-1111-4111-8111-111111111111','Soya','cat',null),
 ('dddddd01-0000-4000-8000-000000000003','c4444444-4444-4444-8444-444444444444','Rex','dog',null),
 ('dddddd01-0000-4000-8000-000000000004','c7777777-7777-4777-8777-777777777777','Pip','rabbit',null);
insert into public.household_members(household_id,user_id,role)
select h.id,'c2222222-2222-4222-8222-222222222222','carer' from public.households h
where h.owner_id='c1111111-1111-4111-8111-111111111111';
insert into public.lost_pet_cards(pet_id,owner_id,description,phone)
values ('dddddd01-0000-4000-8000-000000000001','c1111111-1111-4111-8111-111111111111','Light brown, white chest, red collar','050 123 4567');

-- A park in Ra'anana: Maya, Gil and Rina saved it; Tom has an open ad in
-- Ra'anana; Gil blocked Noa; Rina switched lost pets off; Omer saved it too
-- but has no phone registered. Phones for everyone else.
insert into public.dog_parks(id,source,source_id,name_en,name_he,lat,lng,locality_code,fenced) values
 ('eeeeee01-0000-4000-8000-000000000001','admin','park-lost-1','Ahuza dog park','גינת אחוזה',32.186,34.872,'raanana','yes');
insert into public.dog_park_favorites(user_id,park_id,notify_meetups) values
 ('c3333333-3333-4333-8333-333333333333','eeeeee01-0000-4000-8000-000000000001',false),
 ('c5555555-5555-4555-8555-555555555555','eeeeee01-0000-4000-8000-000000000001',false),
 ('c6666666-6666-4666-8666-666666666666','eeeeee01-0000-4000-8000-000000000001',false),
 ('c7777777-7777-4777-8777-777777777777','eeeeee01-0000-4000-8000-000000000001',false),
 ('c2222222-2222-4222-8222-222222222222','eeeeee01-0000-4000-8000-000000000001',false);
insert into public.user_blocks(blocker_id,blocked_id) values
 ('c5555555-5555-4555-8555-555555555555','c1111111-1111-4111-8111-111111111111');
insert into public.push_preferences(user_id,lost_nearby) values ('c6666666-6666-4666-8666-666666666666',false);
insert into public.push_devices(token,user_id,platform,language) values
 ('lost-owner-token-01','c1111111-1111-4111-8111-111111111111','android','he'),
 ('lost-carer-token-01','c2222222-2222-4222-8222-222222222222','android','he'),
 ('lost-fan-token-0001','c3333333-3333-4333-8333-333333333333','android','en'),
 ('lost-walker-token-1','c4444444-4444-4444-8444-444444444444','android','he'),
 ('lost-blocker-token1','c5555555-5555-4555-8555-555555555555','android','he'),
 ('lost-quiet-token-01','c6666666-6666-4666-8666-666666666666','android','he');

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
create temp table ids(name text primary key, id uuid);
grant all on ids to authenticated, service_role;

-- Tom's walk ad in Ra'anana (as Tom, through the meetups rules).
select pg_temp.act_as('c4444444-4444-4444-8444-444444444444');
select public.meetup_save(null, jsonb_build_object('kind','walk','locality_code','raanana','place_text','By the lake',
  'starts_at', now() + interval '1 day', 'ends_at', now() + interval '1 day 1 hour'));
reset role;

-- ---------------------------------------------------------------------------
-- Capabilities: the beta testers have them, a standard owner does not.
-- ---------------------------------------------------------------------------
do $$ begin
 assert (select requires_view from public.access_capabilities where id='safety.lists')='safety.view', 'lists needs view';
 assert (select requires_view from public.access_capabilities where id='safety.lost')='safety.view', 'lost needs view';
 assert not exists (select 1 from public.group_capability_rules
                    where group_id='acc35500-0000-4000-8000-000000000001' and capability like 'safety.%'),
   'Standard owners get no safety capability';
 assert pg_get_constraintdef((select oid from pg_constraint where conname='push_outbox_kind_check'))
   like '%lost_nearby%', 'The push kind list has lost_nearby';
 assert pg_get_constraintdef((select oid from pg_constraint where conname='push_outbox_kind_check'))
   like '%meetup_renew%', 'and keeps the kinds before it';
end $$;
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
do $$ begin
 assert public.can_use('safety.view') and public.can_use('safety.lists') and public.can_use('safety.lost'), 'A beta tester has them';
end $$;
reset role;
select pg_temp.act_as('c7777777-7777-4777-8777-777777777777');
do $$ begin
 assert not public.can_use('safety.view') and not public.can_use('safety.lists') and not public.can_use('safety.lost'),
   'A standard owner has none';
end $$;
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000004','raanana','Park',now())$$,
  '42501', null, 'no safety.lost');
select pg_temp.refused($$select public.lost_alerts_mine()$$, '42501', null, 'no safety.view');
reset role;
set local role anon;
select pg_temp.refused($$select public.lost_alerts_near('raanana')$$, '42501', null, 'anonymous');
select pg_temp.refused($$select count(*) from public.lost_alerts$$, '42501', null, 'anonymous read');
reset role;

-- ---------------------------------------------------------------------------
-- What is refused.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000003','raanana','Park',now())$$, '22023', 'invalid_alert', 'someone else''s pet');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','Ra anana','Park',now())$$, '22023', 'invalid_alert', 'a malformed locality');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana',repeat('x',121),now())$$, '22023', 'invalid_alert', 'a long place');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now() + interval '1 hour')$$, '22023', 'invalid_alert', 'seen in the future');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now() - interval '40 days')$$, '22023', 'invalid_alert', 'seen long ago');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now(),'','fr')$$, '22023', 'invalid_alert', 'an unknown language');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now(),repeat('x',301))$$, '22023', 'invalid_alert', 'a long note');
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now(),'','en','c4444444-4444-4444-8444-444444444444/kelly.jpg')$$, '22023', 'invalid_alert', 'someone else''s photo');
-- Never by hand.
select pg_temp.refused($$insert into public.lost_alerts(pet_id,pet_name,locality_code,last_seen_at) values ('dddddd01-0000-4000-8000-000000000001','Kelly','raanana',now())$$, '42501', null, 'direct insert');
select pg_temp.refused($$update public.lost_alerts set note = 'x'$$, '42501', null, 'direct update');
select pg_temp.refused($$delete from public.lost_alerts$$, '42501', null, 'direct delete');

-- ---------------------------------------------------------------------------
-- Starting: the post, the alert, the lost card, the pushes.
-- ---------------------------------------------------------------------------
do $$
declare alert jsonb; post public.community_posts; a public.lost_alerts; card public.lost_pet_cards;
begin
 alert := public.lost_start('dddddd01-0000-4000-8000-000000000001', 'raanana', '  Ahuza park gate  ',
   now() - interval '1 hour', 'Shy, do not chase her', 'en', 'c1111111-1111-4111-8111-111111111111/lost-kelly.jpg', 'Ra''anana');
 insert into ids values ('kelly_alert', (alert->>'id')::uuid), ('kelly_post', (alert->>'post_id')::uuid);
 assert alert->>'status' = 'active' and (alert->>'sightings')::int = 0, 'Open, no sightings yet: ' || alert::text;
 select * into a from public.lost_alerts where id = (alert->>'id')::uuid;
 assert a.pet_name = 'Kelly' and a.pet_species = 'dog' and a.locality_code = 'raanana'
   and a.last_seen_place = 'Ahuza park gate' and a.owner_id = 'c1111111-1111-4111-8111-111111111111', 'The alert: ' || row_to_json(a)::text;
 select * into post from public.community_posts where id = a.post_id;
 assert post.kind = 'lost_found' and post.audience = 'dog' and post.pet_name = 'Kelly'
   and post.author_id = 'c1111111-1111-4111-8111-111111111111'
   and post.photo_path = 'c1111111-1111-4111-8111-111111111111/lost-kelly.jpg', 'A lost and found post with the photo';
 assert post.body like 'Kelly is missing%', 'The post opens with the name: ' || post.body;
 assert position('Dog · Labrador' in post.body) > 0, 'its kind and breed';
 assert position('Light brown, white chest, red collar' in post.body) > 0, 'its looks, from the lost card';
 assert position('Ahuza park gate, Ra''anana' in post.body) > 0, 'where it was last seen';
 assert position('Shy, do not chase her' in post.body) > 0, 'the owner''s note';
 assert position('050' in post.body) = 0, 'never the phone number';
 select * into card from public.lost_pet_cards where pet_id = a.pet_id;
 assert card.found_at is null and card.area = 'Ahuza park gate' and card.last_seen_at = a.last_seen_at
   and card.description = 'Light brown, white chest, red collar', 'The lost card follows';
 -- Pushes: Maya (a saved park there) and Tom (an ad there); not Noa, not
 -- Eli (the household), not Gil (blocked Noa), not Rina (switched off),
 -- not Omer (no phone).
 assert (select array_agg(recipient_id::text order by recipient_id) from public.push_outbox
         where kind = 'lost_nearby' and target = 'post:' || a.post_id)
   = array['c3333333-3333-4333-8333-333333333333','c4444444-4444-4444-8444-444444444444'],
   'Members nearby are told: ' || coalesce((select string_agg(recipient_id::text, ',') from public.push_outbox where kind='lost_nearby'), 'nobody');
 assert (select preview from public.push_outbox where kind = 'lost_nearby' limit 1) = 'Kelly · Ahuza park gate', 'The push names the pet and the place';
 -- One open alert per pet.
 begin
  perform public.lost_start('dddddd01-0000-4000-8000-000000000001', 'raanana', 'Park', now());
  raise exception 'A second alert for Kelly was accepted';
 exception when others then
  if sqlerrm <> 'lost_active' then raise; end if;
 end;
end $$;

-- Hebrew words, no photo, no place.
do $$
declare alert jsonb; body text;
begin
 alert := public.lost_start('dddddd01-0000-4000-8000-000000000002', 'raanana', '', now(), '', 'he');
 insert into ids values ('soya_alert', (alert->>'id')::uuid), ('soya_post', (alert->>'post_id')::uuid);
 select p.body into body from public.community_posts p where p.id = (alert->>'post_id')::uuid;
 assert body like 'מחפשים את %Soya%', 'Hebrew words: ' || body;
 assert position('חתול' in body) > 0, 'The kind in Hebrew';
 assert (select photo_path from public.community_posts where id = (alert->>'post_id')::uuid) is null, 'No photo';
 assert (select audience from public.community_posts where id = (alert->>'post_id')::uuid) = 'cat', 'For the cats chip';
 -- A second alert is a second push, each alert once.
 assert (select count(*) from public.push_outbox where kind = 'lost_nearby'
         and recipient_id = 'c3333333-3333-4333-8333-333333333333') = 2, 'One push per alert';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Reads: the household (with sightings), a neighbour, a stranger.
-- ---------------------------------------------------------------------------
-- Maya comments: a sighting. Eli (household) comments: not one.
select pg_temp.act_as('c3333333-3333-4333-8333-333333333333');
insert into public.community_comments(post_id, body) select id, 'Saw her by the school at 10' from ids where name='kelly_post';
do $$
declare near jsonb := public.lost_alerts_near('raanana');
begin
 assert jsonb_array_length(near) = 2, 'A neighbour sees the open alerts of the town: ' || near::text;
 assert near->0 ? 'pet_name' and not (near->0 ? 'owner_id') and not (near->0 ? 'note'), 'minimal columns';
 assert jsonb_array_length(public.lost_alerts_near('tel-aviv-yafo')) = 0, 'nothing elsewhere';
 assert not exists (select 1 from public.lost_alerts), 'A neighbour cannot read the table';
end $$;
reset role;
select pg_temp.act_as('c2222222-2222-4222-8222-222222222222');
insert into public.community_comments(post_id, body) select id, 'Looking around the park now' from ids where name='kelly_post';
do $$
declare mine jsonb := public.lost_alerts_mine();
begin
 assert jsonb_array_length(mine) = 2, 'The household reads its open alerts: ' || mine::text;
 assert (select (x->>'sightings')::int from jsonb_array_elements(mine) x where x->>'pet_name' = 'Kelly') = 1,
   'Only comments from outside the household are sightings';
 assert (select count(*) from public.lost_alerts) = 2, 'The household reads the table';
end $$;
reset role;
select pg_temp.act_as('c5555555-5555-4555-8555-555555555555');
do $$ begin
 assert jsonb_array_length(public.lost_alerts_near('raanana')) = 0, 'Never across a block';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Closing: found by the carer, cancel by the owner.
-- ---------------------------------------------------------------------------
-- An unsent push for Kelly is waiting for someone else; found removes it.
select pg_temp.act_as('c7777777-7777-4777-8777-777777777777');
select pg_temp.refused($$select public.lost_found((select id from ids where name='kelly_alert'))$$, '22023', 'invalid_alert', 'not the household');
reset role;
select pg_temp.act_as('c2222222-2222-4222-8222-222222222222');
do $$
declare alert jsonb := public.lost_found((select id from ids where name='kelly_alert'));
begin
 assert alert->>'status' = 'found' and alert->>'closed_at' is not null, 'Found: ' || alert::text;
 assert exists (select 1 from public.community_comments c where c.post_id = (select id from ids where name='kelly_post')
                and c.body like 'Good news: Kelly is home%'), 'A closing comment in the post''s language';
 assert (select found_at from public.lost_pet_cards where pet_id = 'dddddd01-0000-4000-8000-000000000001') is not null,
   'The lost card knows Kelly is home';
 assert not exists (select 1 from public.push_outbox where kind = 'lost_nearby' and sent_at is null
                    and target = 'post:' || (select id from ids where name='kelly_post')), 'No push is left to send';
 -- Closing twice changes nothing.
 assert public.lost_found((select id from ids where name='kelly_alert'))->>'status' = 'found', 'Found again: no change';
 assert (select count(*) from public.community_comments c where c.post_id = (select id from ids where name='kelly_post')
         and c.body like 'Good news%') = 1, 'One closing comment';
end $$;
reset role;
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
do $$
declare alert jsonb := public.lost_cancel((select id from ids where name='soya_alert'));
begin
 assert alert->>'status' = 'cancelled', 'Cancelled';
 assert not exists (select 1 from public.community_posts where id = (select id from ids where name='soya_post')),
   'A cancelled alert nobody answered takes its post with it';
 assert jsonb_array_length(public.lost_alerts_mine()) = 0, 'Nothing open any more';
 -- A new alert for Kelly can start again now (third today).
 perform public.lost_start('dddddd01-0000-4000-8000-000000000001', 'raanana', 'Park', now());
end $$;
-- Three alerts a day per account.
select public.lost_cancel((select id from public.lost_alerts where status = 'active' limit 1));
select pg_temp.refused($$select public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now())$$, 'P0001', 'rate_limited', 'a fourth alert today');
reset role;

-- A cancelled alert someone answered keeps its post, with a comment.
update public.lost_alerts set created_at = now() - interval '2 days';
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
insert into ids select 'third', (public.lost_start('dddddd01-0000-4000-8000-000000000001','raanana','Park',now(),'','he')->>'id')::uuid;
reset role;
select pg_temp.act_as('c3333333-3333-4333-8333-333333333333');
insert into public.community_comments(post_id, body)
select post_id, 'Is she still missing?' from public.lost_alerts where id = (select id from ids where name='third');
reset role;
select pg_temp.act_as('c1111111-1111-4111-8111-111111111111');
do $$
declare alert jsonb := public.lost_cancel((select id from ids where name='third'));
begin
 assert alert->>'post_id' is not null and exists (select 1 from public.community_posts where id = (alert->>'post_id')::uuid),
   'The answered post stays';
 assert exists (select 1 from public.community_comments where post_id = (alert->>'post_id')::uuid and body like 'ההתראה על %נסגרה.'),
   'with a closing comment';
end $$;
reset role;

-- Push preferences: the new switch is on by default.
do $$ begin
 assert (select column_default from information_schema.columns
         where table_name = 'push_preferences' and column_name = 'lost_nearby') = 'true', 'lost_nearby defaults on';
end $$;

rollback;
\echo 'Lost mode tests passed.'
