\set ON_ERROR_STOP on
-- Disposable database only. Dog parks (0027_dog_parks.sql): who reads and
-- writes what, member suggestions and their limits, the reviewers' queue
-- and decisions, the monthly import's merge rules, favourites.

-- Running the migration again changes nothing.
\i /tests/migrations/0027_dog_parks.sql

begin;
insert into auth.users(id,email) values
 ('d1111111-1111-4111-8111-111111111111','reviewer@example.test'),
 ('d2222222-2222-4222-8222-222222222222','member@example.test'),
 ('d3333333-3333-4333-8333-333333333333','other@example.test');
-- Reviewers are appointed per person, as the permissions screen does.
insert into public.user_capability_rules(user_id,capability,allowed)
values ('d1111111-1111-4111-8111-111111111111','community.parks.review',true);

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
create function pg_temp.park(p_source_id text) returns public.dog_parks language sql as $$
 select * from public.dog_parks where source='osm' and source_id=p_source_id
$$;

-- ---------------------------------------------------------------------------
-- The first import (service role, as the Edge Function).
-- ---------------------------------------------------------------------------
set local role service_role;
do $$
declare stats jsonb;
begin
 stats := public.dog_parks_import('2026-10', '[
  {"source_id":"way/1","street_he":"אחוזה","street_en":"Ahuza","lat":32.186,"lng":34.872,"locality_code":"raanana","fenced":"yes","water":"unknown"},
  {"source_id":"way/2","name_he":"גינת הכלבים בפארק","lat":32.180,"lng":34.880,"locality_code":"raanana","lighting":"no","opening_hours":"24/7"},
  {"source_id":"node/3","lat":32.175,"lng":34.907,"locality_code":"kfar-saba","small_dogs":"maybe"},
  {"source_id":"bogus","lat":32.1,"lng":34.8},
  {"source_id":"way/4","lat":31.77,"lng":35.21,"locality_code":"jerusalem"}
 ]'::jsonb);
 assert (stats->>'added')::int = 4, 'Four parks added: ' || stats::text;
 assert (stats->>'received')::int = 5 and (stats->>'accepted')::int = 4, 'A row without an OpenStreetMap id is skipped';
 assert (select small_dogs from pg_temp.park('node/3')) = 'unknown', 'Unknown values become unknown';
 assert (select status from public.dog_park_import_runs where period_key='2026-10') = 'succeeded', 'The run is recorded';
 begin
  perform public.dog_parks_import('October', '[]'::jsonb);
  raise exception 'A malformed period was accepted';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;

-- Nobody else may import.
select pg_temp.act_as('d1111111-1111-4111-8111-111111111111');
do $$ begin
 begin
  perform public.dog_parks_import('2026-10', '[]'::jsonb);
  raise exception 'A member ran the import';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin
  perform count(*) from public.dog_parks;
  raise exception 'Anonymous visitors read parks';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Members read, never write.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('d2222222-2222-4222-8222-222222222222');
do $$ begin
 assert public.can_use('community.parks.view') and public.can_use('community.parks.suggest'), 'Everyone may look and suggest';
 assert not public.can_use('community.parks.review'), 'Members are not reviewers';
 assert (select count(*) from public.dog_parks where lat between 32.1 and 32.2 and lng between 34.8 and 34.95) = 3,
  'A box of latitudes and longitudes finds the parks inside';
 begin
  insert into public.dog_parks(source,source_id,lat,lng) values('admin','x',32,34.8);
  raise exception 'A member added a park';
 exception when insufficient_privilege then null; end;
 begin
  update public.dog_parks set fenced='no';
  raise exception 'A member changed a park';
 exception when insufficient_privilege then null; end;
 begin
  perform public.dog_park_review_queue();
  raise exception 'A member read the review queue';
 exception when insufficient_privilege then null; end;
end $$;

-- Favourites are private; the meetups flag starts off.
insert into public.dog_park_favorites(park_id) select id from pg_temp.park('way/1');
do $$ begin
 assert (select notify_meetups from public.dog_park_favorites) = false, 'Meetup alerts start off';
 begin
  insert into public.dog_park_favorites(user_id,park_id)
   select 'd3333333-3333-4333-8333-333333333333', id from pg_temp.park('way/2');
  raise exception 'Saved a park for someone else';
 exception when insufficient_privilege then null; end;
end $$;

-- Suggestions: details of a park, and a new park.
insert into public.dog_park_suggestions(kind,park_id,changes)
 select 'details', id, '{"water":"yes","closed":true}' from pg_temp.park('way/1');
insert into public.dog_park_suggestions(kind,name,lat,lng,location_kind,changes) values
 ('new_park','גינת הכלבים החדשה',32.19,34.88,'device','{"fenced":"yes"}');
insert into public.dog_park_suggestions(kind,lat,lng,location_kind,locality_code,place_note) values
 ('new_park',32.0853,34.7818,'locality','tel-aviv-yafo','Behind the community centre');
do $$ begin
 assert (select count(*) from public.dog_park_suggestions) = 3, 'The author reads their suggestions';
 begin
  insert into public.dog_park_suggestions(kind,park_id,changes)
   select 'details', id, '{"fenced":"sometimes"}' from public.dog_parks limit 1;
  raise exception 'An unknown value was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  insert into public.dog_park_suggestions(kind,park_id,changes)
   select 'details', id, '{"colour":"green"}' from public.dog_parks limit 1;
  raise exception 'An unknown detail was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  insert into public.dog_park_suggestions(kind,park_id,changes)
   select 'details', id, '{}' from public.dog_parks limit 1;
  raise exception 'A change without changes was accepted';
 exception when check_violation then null; end;
 begin
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind,locality_code) values
   ('new_park',32.0853,34.7818,'locality','tel-aviv-yafo');
  raise exception 'A park picked by city alone was accepted without a place';
 exception when check_violation then null; end;
 begin
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind) values('new_park',51.5,-0.12,'device');
  raise exception 'A park outside Israel was accepted';
 exception when check_violation then null; end;
 begin
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind,status) values('new_park',32,34.8,'device','approved');
  raise exception 'A member approved their own suggestion';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind,author_id)
   values('new_park',32,34.8,'device','d3333333-3333-4333-8333-333333333333');
  raise exception 'Suggested in someone else''s name';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Another member sees none of them.
select pg_temp.act_as('d3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.dog_park_suggestions) = 0, 'Suggestions are private';
end $$;
-- Ten a day.
do $$ begin
 for i in 1..10 loop
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind) values('new_park',32,34.8,'device');
 end loop;
 begin
  insert into public.dog_park_suggestions(kind,lat,lng,location_kind) values('new_park',32,34.8,'device');
  raise exception 'The eleventh suggestion of the day was accepted';
 exception when raise_exception then
  if sqlerrm <> 'rate_limited' then raise; end if;
 end;
end $$;
reset role;
delete from public.dog_park_suggestions where author_id='d3333333-3333-4333-8333-333333333333';

-- Without the capability, nothing.
insert into public.user_capability_rules(user_id,capability,allowed)
values ('d3333333-3333-4333-8333-333333333333','community.parks.view',false);
select pg_temp.act_as('d3333333-3333-4333-8333-333333333333');
do $$ begin
 assert (select count(*) from public.dog_parks) = 0, 'No parks without the view capability';
 assert not public.can_use('community.parks.suggest'), 'No suggesting without viewing';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- Reviewers decide.
-- ---------------------------------------------------------------------------
select pg_temp.act_as('d1111111-1111-4111-8111-111111111111');
do $$
declare
 queue jsonb := public.dog_park_review_queue();
 details uuid;
 fresh uuid;
 by_city uuid;
 park uuid;
begin
 assert jsonb_array_length(queue->'suggestions') = 3, 'Three suggestions wait: ' || queue::text;
 assert jsonb_array_length(queue->'parks') = 0, 'No park waits yet';
 assert (select x->'park'->>'source_id' from jsonb_array_elements(queue->'suggestions') x where x->>'kind'='details') = 'way/1',
  'A detail change carries its park';
 select (x->>'id')::uuid into details from jsonb_array_elements(queue->'suggestions') x where x->>'kind'='details';
 select (x->>'id')::uuid into fresh from jsonb_array_elements(queue->'suggestions') x where x->>'location_kind'='device';
 select (x->>'id')::uuid into by_city from jsonb_array_elements(queue->'suggestions') x where x->>'location_kind'='locality';

 -- Details: applied, and locked against the import.
 perform public.dog_park_decide(details, 'approve');
 assert (select water from pg_temp.park('way/1')) = 'yes', 'Approved water';
 assert (select status from pg_temp.park('way/1')) = 'closed', 'Approved "closed for renovation"';
 assert (select locked_fields from pg_temp.park('way/1')) = array['status','water'], 'Approved fields are locked';
 begin
  perform public.dog_park_decide(details, 'reject');
  raise exception 'A suggestion was decided twice';
 exception when raise_exception then
  if sqlerrm <> 'already_decided' then raise; end if;
 end;

 -- A new park, with the reviewer's correction.
 park := public.dog_park_decide(fresh, 'approve', '{"water":"yes"}');
 assert (select source from public.dog_parks where id=park) = 'member', 'A member park';
 assert (select name_he from public.dog_parks where id=park) = 'גינת הכלבים החדשה', 'Hebrew name kept as Hebrew';
 assert (select fenced||water from public.dog_parks where id=park) = 'yesyes', 'Suggested and corrected details';
 assert not exists(select 1 from jsonb_array_elements(public.dog_park_review_queue()->'suggestions') x
  where (x->>'id')::uuid = fresh), 'A decided suggestion leaves the queue';

 -- Picked by city: the reviewer moves it to the real spot.
 park := public.dog_park_decide(by_city, 'approve', '{"lat":32.09,"lng":34.79,"name":"Community garden dog run"}');
 assert (select lat from public.dog_parks where id=park) = 32.09, 'The reviewer''s location wins';
 assert (select name_en||street_en from public.dog_parks where id=park) = 'Community garden dog runBehind the community centre',
  'English name and place text';

 begin
  perform public.dog_park_decide(by_city, 'maybe');
  raise exception 'An unknown action was accepted';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.dog_park_suggestions
  where status='approved' and reviewer_id='d1111111-1111-4111-8111-111111111111' and decided_at is not null) = 3,
  'Each decision records the reviewer and the time';
end $$;

-- ---------------------------------------------------------------------------
-- The next import respects what reviewers decided.
-- ---------------------------------------------------------------------------
set local role service_role;
do $$
declare stats jsonb;
begin
 stats := public.dog_parks_import('2026-11', '[
  {"source_id":"way/1","street_he":"אחוזה","lat":32.186,"lng":34.872,"locality_code":"raanana","fenced":"no","water":"no"},
  {"source_id":"way/2","name_he":"גינת הכלבים בפארק רעננה","lat":32.180,"lng":34.880,"locality_code":"raanana"},
  {"source_id":"way/4","lat":31.77,"lng":35.21,"locality_code":"jerusalem"},
  {"source_id":"way/5","lat":31.25,"lng":34.79,"locality_code":"beersheba"}
 ]'::jsonb);
 assert (stats->>'added')::int = 1 and (stats->>'refreshed')::int = 3 and (stats->>'vanished')::int = 1,
  'One new, three refreshed, one gone: ' || stats::text;
 assert (select water from pg_temp.park('way/1')) = 'yes', 'A locked detail stays';
 assert (select fenced from pg_temp.park('way/1')) = 'no', 'An unlocked detail follows the map';
 assert (select status from pg_temp.park('way/1')) = 'closed', 'A locked status stays';
 assert (select name_he from pg_temp.park('way/2')) = 'גינת הכלבים בפארק רעננה', 'Names follow the map';
 assert (select status||review_reason from pg_temp.park('node/3')) = 'pending_reviewosm_vanished',
  'A park gone from the map waits for review';
 assert exists(select 1 from public.dog_parks where source='member'), 'Member parks are not the import''s';
 assert (select count(*) from public.dog_parks) = 7, 'Nothing is ever deleted';
end $$;
reset role;

select pg_temp.act_as('d2222222-2222-4222-8222-222222222222');
do $$ begin
 assert not exists(select 1 from public.dog_parks where source_id='node/3'), 'Members do not see a park in review';
 assert exists(select 1 from public.dog_parks where source_id='way/1'), 'Members see a closed park';
end $$;
reset role;

-- Back on the map: out of review by itself.
set local role service_role;
do $$
declare stats jsonb;
begin
 stats := public.dog_parks_import('2026-12', '[
  {"source_id":"way/1","lat":32.186,"lng":34.872},{"source_id":"way/2","lat":32.18,"lng":34.88},
  {"source_id":"node/3","lat":32.175,"lng":34.907},{"source_id":"way/4","lat":31.77,"lng":35.21},
  {"source_id":"way/5","lat":31.25,"lng":34.79}]'::jsonb);
 assert (stats->>'reappeared')::int = 1, 'One park came back: ' || stats::text;
 assert (select status from pg_temp.park('node/3')) = 'active', 'It is shown again';
 stats := public.dog_parks_import('2027-01', '[
  {"source_id":"way/1","lat":32.186,"lng":34.872},{"source_id":"way/2","lat":32.18,"lng":34.88},
  {"source_id":"way/4","lat":31.77,"lng":35.21},{"source_id":"way/5","lat":31.25,"lng":34.79}]'::jsonb);
 assert (select status from pg_temp.park('node/3')) = 'pending_review', 'Gone again';
end $$;
reset role;

-- The reviewer keeps it: the import leaves it alone from then on.
select pg_temp.act_as('d1111111-1111-4111-8111-111111111111');
do $$
declare queue jsonb := public.dog_park_review_queue();
begin
 assert queue->'parks'->0->>'source_id' = 'node/3', 'The vanished park is in the queue';
 perform public.dog_park_set_status((queue->'parks'->0->>'id')::uuid, 'active');
 begin
  perform public.dog_park_set_status((queue->'parks'->0->>'id')::uuid, 'deleted');
  raise exception 'An unknown status was accepted';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;
set local role service_role;
do $$ begin
 perform public.dog_parks_import('2027-02', '[
  {"source_id":"way/1","lat":32.186,"lng":34.872},{"source_id":"way/2","lat":32.18,"lng":34.88},
  {"source_id":"way/4","lat":31.77,"lng":35.21},{"source_id":"way/5","lat":31.25,"lng":34.79}]'::jsonb);
 assert (select status from pg_temp.park('node/3')) = 'active', 'A kept park stays active';
end $$;

-- A download with less than half of the known parks is refused unless forced.
insert into public.dog_parks(source,source_id,lat,lng)
 select 'osm','node/'||(1000+g),32,34.8 from generate_series(1,20) g;
do $$ begin
 begin
  perform public.dog_parks_import('2027-03', '[{"source_id":"way/1","lat":32.186,"lng":34.872}]'::jsonb);
  raise exception 'A suspiciously small import was accepted';
 exception when raise_exception then
  if sqlerrm <> 'suspicious_import' then raise; end if;
 end;
 assert (select count(*) from public.dog_parks where status='pending_review') = 0, 'A refused import changes nothing';
 perform public.dog_parks_import('2027-03', '[{"source_id":"way/1","lat":32.186,"lng":34.872}]'::jsonb, true);
 assert (select count(*) from public.dog_parks where status='pending_review') >= 20, 'Forced, it goes through';
end $$;
reset role;

-- Deleting an account takes its suggestions and favourites, not the parks.
delete from auth.users where id='d2222222-2222-4222-8222-222222222222';
do $$ begin
 assert not exists(select 1 from public.dog_park_favorites where user_id='d2222222-2222-4222-8222-222222222222'),
  'Favourites go with the account';
 assert not exists(select 1 from public.dog_park_suggestions where author_id='d2222222-2222-4222-8222-222222222222'),
  'Suggestions go with the account';
 assert (select count(*) from public.dog_parks where source='member') = 2, 'Approved parks stay';
end $$;
rollback;
\echo 'Dog park tests passed.'
