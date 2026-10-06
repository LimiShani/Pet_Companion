\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','pixel123@gmail.com'),
 ('22222222-2222-4222-8222-222222222222','other@example.test');
insert into public.access_admins(user_id) values('11111111-1111-4111-8111-111111111111');
insert into public.pets(id,owner_id,name) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Alice pet'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Bob pet');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
set local role authenticated;
do $$ begin
 assert public.can_use('care.edit'), 'Default owners retain care';
 assert public.can_use('access.admin'), 'Initial administrator recognized';
 assert not public.can_use('findvet.admin'), 'Permission admin does not become a vet reviewer';
 assert not public.can_use('unknown.edit'), 'Unknown capability fails closed';
 assert (select count(*) from public.pets)=1, 'Grants never bypass ownership';
end $$;
select public.access_admin_change('group','{"id":"33333333-3333-4333-8333-333333333333","name":"Restricted"}');
select public.access_admin_change('member','{"group_id":"33333333-3333-4333-8333-333333333333","user_id":"11111111-1111-4111-8111-111111111111","member":true}');
select public.access_admin_change('group_rule','{"group_id":"33333333-3333-4333-8333-333333333333","capability":"care.edit","allowed":false}');
do $$ begin assert not public.can_use('care.edit'), 'Group deny beats group allow'; end $$;
select public.access_admin_change('user_rule','{"user_id":"11111111-1111-4111-8111-111111111111","capability":"care.edit","allowed":true}');
do $$ begin assert public.can_use('care.edit'), 'Individual allow overrides group deny'; end $$;
do $$ begin assert public.get_my_access()->'reasons'->>'care.edit'='Individual override', 'Administrator preview explains the effective rule'; end $$;
select public.access_admin_change('feature','{"id":"care","enabled":false}');
do $$ begin assert not public.can_use('care.edit'), 'Global off beats individual grant'; end $$;
select public.access_admin_change('feature','{"id":"care","enabled":true}');
select public.access_admin_change('user_rule','{"user_id":"11111111-1111-4111-8111-111111111111","capability":"care.view","allowed":false}');
do $$ begin assert not public.can_use('care.edit'), 'Write requires read'; end $$;
select public.access_admin_change('user_rule','{"user_id":"11111111-1111-4111-8111-111111111111","capability":"care.view","allowed":null}');
select public.access_admin_change('feature','{"id":"health","enabled":false}');
insert into public.care_plan_items(id,pet_id,kind,title,time_of_day) values
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','feeding','Breakfast','09:00');
do $$ begin
 assert (select count(*) from public.care_plan_items)=1, 'Care schedule works with Health off';
 begin
  insert into public.health_events(pet_id,kind,title,scheduled_at) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','checkup','Denied',now());
  raise exception 'Health write bypassed permission';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.care_plan_items(pet_id,kind,title,time_of_day,access_domain)
  values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','grooming','Spoofed health routine','10:00','care');
  raise exception 'Schedule domain spoof succeeded';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.care_logs(pet_id,plan_item_id,due_on,status,done_at)
 values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','cccccccc-cccc-4ccc-8ccc-cccccccccccc',current_date,'done',now());
delete from public.care_plan_items where id='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
do $$ begin assert (select count(*) from public.care_logs where access_domain='care' and plan_item_id is null)=1,
 'Deleting a feeding routine preserves its log with Health disabled'; end $$;
insert into public.basket_items(id,pet_id,name,kind,package_size) values
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Food','food',1);
select public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',40,current_date,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
select public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',40,current_date,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
do $$ begin
 assert (select count(*) from public.expenses)=1, 'Retried purchase creates exactly one expense';
 begin
  perform public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',41,current_date,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
  raise exception 'Reused operation accepted different request';
 exception when check_violation then null; end;
end $$;
select public.access_admin_change('feature','{"id":"budget","enabled":false}');
select public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',50,current_date,'ffffffff-ffff-4fff-8fff-ffffffffffff',false);
do $$ begin
 assert (select last_price from public.basket_items where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd')=50, 'Basket works with Budget off';
 begin
  perform public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',60,current_date,'ffffffff-ffff-4fff-8fff-fffffffffffe',true);
  raise exception 'Budget permission bypassed';
 exception when insufficient_privilege then null; end;
end $$;
insert into public.pet_first_days(pet_id,arrived_on) values('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',current_date);
select public.set_first_days_task('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','one',true);
select public.set_first_days_task('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','two',true);
do $$ begin assert (select done_tasks @> array['one','two'] from public.pet_first_days), 'Atomic task patches preserve both tasks'; end $$;
select public.queue_storage_cleanup('pet-photos','11111111-1111-4111-8111-111111111111/unattached.jpg',true);
select public.access_admin_change('feature','{"id":"pets","enabled":false}');
do $$ begin
 assert jsonb_array_length(public.get_my_pet_context())=1, 'Minimal pet identity survives profile feature revocation';
 assert public.get_my_pet_context()->0->>'name'='Alice pet', 'Only caller pet identity is returned';
 assert not (public.get_my_pet_context()->0 ? 'owner_id'), 'Full profile fields remain withheld';
 assert public.cleanup_file_is_orphan('pet-photos','11111111-1111-4111-8111-111111111111/unattached.jpg'), 'Orphan cleanup survives feature revocation';
 assert (select count(*) from public.storage_cleanup_jobs)=1, 'Cleanup is durable';
end $$;
reset role;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
set local role authenticated;
do $$ begin
 assert not public.can_use('access.admin'), 'Regular owner cannot administer';
 assert (select count(*) from public.storage_cleanup_jobs)=0, 'Cleanup jobs are owner isolated';
 begin perform public.access_admin_state(); raise exception 'Regular owner read administrator state';
 exception when insufficient_privilege then null; end;
 begin perform public.record_basket_purchase('dddddddd-dddd-4ddd-8ddd-dddddddddddd',40,current_date,'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',false);
  raise exception 'Cross-owner purchase succeeded'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 assert public.can_use('findvet.search'), 'Public emergency search is explicit';
 assert not public.can_use('care.view'), 'Guests cannot read private features';
end $$;
reset role;
update public.feature_catalog set public_enabled=false where id='findvet';
set local role anon;
do $$ begin assert not public.can_use('findvet.search'), 'Public search can be disabled'; end $$;
reset role;
rollback;
\echo 'All permission, ownership, independent schedule, atomic purchase and cleanup assertions passed.'
