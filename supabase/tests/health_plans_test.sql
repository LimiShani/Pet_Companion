\set ON_ERROR_STOP on
-- Disposable database only. The yearly plan and insights (0038): the
-- plan_item column of health_events and its check, the two capabilities
-- for the beta testers only, and running the migration again.
\i /tests/migrations/0038_health_plans.sql
begin;
update rewards_private.settings set beta_auto_join = false;
insert into auth.users(id,email,raw_user_meta_data) values
 ('a8888888-8888-4888-8888-888888888881','plan-beta@example.test','{"display_name":"Bea"}'),
 ('a8888888-8888-4888-8888-888888888882','plan-standard@example.test','{"display_name":"Sam"}');
insert into public.access_group_members(group_id,user_id) values
 ('acc35500-0000-4000-8000-000000000002','a8888888-8888-4888-8888-888888888881')
on conflict do nothing;

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;

do $$ begin
 assert (select count(*) from public.access_capabilities
         where id in ('health.plans.view','health.insights.view') and feature_id='health' and requires_view is null)=2,
  'Both capabilities are in the catalog';
 assert (select count(*) from public.group_capability_rules
         where group_id='acc35500-0000-4000-8000-000000000002'
           and capability in ('health.plans.view','health.insights.view') and allowed)=2,
  'The beta testers have both';
 assert not exists (select 1 from public.group_capability_rules
         where group_id='acc35500-0000-4000-8000-000000000001'
           and capability in ('health.plans.view','health.insights.view')),
  'Standard owners do not';
end $$;

-- A beta tester sees the plan and the insights; an ordinary owner does not.
select pg_temp.act_as('a8888888-8888-4888-8888-888888888881');
do $$ begin
 assert public.can_use('health.plans.view'), 'A beta tester sees the yearly plan';
 assert public.can_use('health.insights.view'), 'and the insights';
end $$;
reset role;
select pg_temp.act_as('a8888888-8888-4888-8888-888888888882');
do $$ begin
 assert not public.can_use('health.plans.view'), 'An ordinary owner does not see the yearly plan';
 assert not public.can_use('health.insights.view'), 'nor the insights';
 assert public.can_use('health.records.edit'), 'but still keeps records';
end $$;

-- Any owner's records may carry a plan item; the check keeps its shape.
with p as (insert into public.pets(name, species) values ('Kelly','dog') returning id)
insert into public.health_events(pet_id, kind, title, scheduled_at, plan_item)
select p.id, k, t, now() + interval '30 days', i from p,
 (values ('vaccination','Rabies vaccine','dog.rabies'),
         ('vaccination','Combined vaccine, puppy dose 2 of 3','dog.combined#2'),
         ('preventive','Flea and tick treatment','dog.flea@3m'),
         ('checkup','General check',null)) as v(k, t, i);
do $$
declare
 bad text;
begin
 assert (select count(*) from public.health_events where plan_item is not null)=3, 'Plan items are stored';
 foreach bad in array array['DROP TABLE', 'dog', 'dog.rabies#0', 'dog.flea@0m', 'dog.flea@100m', 'dog.rabies;', ''] loop
  begin
   update public.health_events set plan_item=bad where plan_item='dog.rabies';
   raise exception 'A malformed plan item was stored: %', bad;
  exception when check_violation then null; end;
 end loop;
end $$;
reset role;

-- The other owner never sees them.
select pg_temp.act_as('a8888888-8888-4888-8888-888888888881');
do $$ begin
 assert (select count(*) from public.health_events where plan_item is not null)=0, 'Records stay private';
end $$;
reset role;
rollback;

-- Running the migration once more changes nothing.
\i /tests/migrations/0038_health_plans.sql
do $$ begin
 assert (select count(*) from public.access_capabilities where id in ('health.plans.view','health.insights.view'))=2,
  'Still two capabilities';
end $$;
