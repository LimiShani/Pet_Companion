\set ON_ERROR_STOP on
-- Usage counts (0031): no direct access, usage_add's checks, caps and rate
-- limit, the administrators' summary, housekeeping and account deletion.
-- Runs in the disposable test database only.
begin;
insert into auth.users(id,email) values
 ('d1d1d1d1-d1d1-4d1d-8d1d-d1d1d1d1d1d1','usage-admin@example.test'),
 ('e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2','usage-owner@example.test'),
 ('f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3','usage-other@example.test');
insert into public.access_admins(user_id) values('d1d1d1d1-d1d1-4d1d-8d1d-d1d1d1d1d1d1');

-- An ordinary signed-in owner.
select set_config('request.jwt.claim.sub','e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2',true);
set local role authenticated;
do $$ begin
 begin
  perform count(*) from public.usage_counts;
  raise exception 'A member read usage counts';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.usage_counts(user_id,day,kind,count)
   values('e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2',current_date,'app_opened',1);
  raise exception 'A member inserted a row directly';
 exception when insufficient_privilege then null; end;
 begin
  update public.usage_counts set count=500;
  raise exception 'A member changed rows';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.usage_counts;
  raise exception 'A member deleted rows';
 exception when insufficient_privilege then null; end;
 begin
  perform public.usage_summary(28);
  raise exception 'A member read the summary';
 exception when insufficient_privilege then null; end;
 begin
  perform usage_private.housekeeping();
  raise exception 'A member ran the housekeeping';
 exception when insufficient_privilege then null; end;

 -- Call 1 and 2: counts add up, capped at 500 a row.
 assert public.usage_add(current_date, '{"care_logged": 3, "app_opened": 1}'::jsonb)=2, 'Two kinds stored';
 assert public.usage_add(current_date, '{"care_logged": 600}'::jsonb)=1, 'One kind stored';
 -- Calls 3 to 5: yesterday and two days ago (the phone's day) are accepted, and tomorrow.
 assert public.usage_add(current_date - 1, '{"deal_opened": 2}'::jsonb)=1, 'Yesterday accepted';
 assert public.usage_add(current_date - 2, '{"deal_opened": 1}'::jsonb)=1, 'Two days ago accepted';
 assert public.usage_add(current_date + 1, '{"today_tick": 1}'::jsonb)=1, 'Tomorrow (a phone east of the server) accepted';

 begin
  perform public.usage_add(current_date, '{"screen_viewed": 1}'::jsonb);
  raise exception 'An unknown kind was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date - 3, '{"app_opened": 1}'::jsonb);
  raise exception 'A day three days ago was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date + 2, '{"app_opened": 1}'::jsonb);
  raise exception 'A day after tomorrow was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(null, '{"app_opened": 1}'::jsonb);
  raise exception 'A missing day was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date, '{"app_opened": 0}'::jsonb);
  raise exception 'A zero count was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date, '{"app_opened": 1.5}'::jsonb);
  raise exception 'A fraction was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date, '{"app_opened": "7"}'::jsonb);
  raise exception 'A text count was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date, '{}'::jsonb);
  raise exception 'Empty counts were accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_add(current_date, '[1, 2]'::jsonb);
  raise exception 'A list was accepted';
 exception when invalid_parameter_value then null; end;
end $$;
reset role;
do $$ begin
 assert (select count from public.usage_counts
         where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2' and day=current_date and kind='care_logged')=500,
  'Counts add up and stop at 500';
 assert (select count from public.usage_counts
         where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2' and day=current_date and kind='app_opened')=1,
  'Each kind has its own row';
 assert (select count(*) from public.usage_counts where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2')=5,
  'A refused call stores nothing';
 assert (select calls from usage_private.calls
         where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2' and day=current_date)=5,
  'Only accepted calls count toward the limit';
end $$;

-- The rate limit: 30 calls an account a day (5 made above).
select set_config('request.jwt.claim.sub','e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2',true);
set local role authenticated;
do $$ begin
 for i in 6..30 loop
  perform public.usage_add(current_date, '{"post_created": 1}'::jsonb);
 end loop;
 begin
  perform public.usage_add(current_date, '{"post_created": 1}'::jsonb);
  raise exception 'A 31st call in a day was accepted';
 exception when raise_exception then
  if sqlerrm <> 'rate_limited' then raise; end if;
 end;
end $$;
reset role;
do $$ begin
 assert (select count from public.usage_counts
         where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2' and day=current_date and kind='post_created')=25,
  'The calls over the limit stored nothing';
end $$;

-- A signed-out app cannot add anything.
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 begin
  perform public.usage_add(current_date, '{"app_opened": 1}'::jsonb);
  raise exception 'A signed-out app added counts';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- A second account, then the administrators' summary.
select set_config('request.jwt.claim.sub','f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3',true);
set local role authenticated;
select public.usage_add(current_date, '{"app_opened": 1, "today_tick": 4}'::jsonb);
reset role;
insert into public.usage_counts(user_id,day,kind,count) values
 ('f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3',current_date - 30,'app_opened',1),
 ('f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3',current_date - 401,'app_opened',1);

select set_config('request.jwt.claim.sub','d1d1d1d1-d1d1-4d1d-8d1d-d1d1d1d1d1d1',true);
set local role authenticated;
do $$
declare
 summary jsonb := public.usage_summary(28);
 today jsonb := summary -> 0;
begin
 assert jsonb_array_length(summary)=28, 'One element a day for 28 days';
 assert (today ->> 'day')::date=current_date, 'Newest day first';
 assert (today ->> 'active')::integer=2, 'Two active accounts today';
 assert (today ->> 'today_tick_share')::numeric=0.5, 'Half of them ticked a Today row';
 assert (today #>> '{kinds,care_logged,accounts}')::integer=1, 'One account logged care';
 assert (today #>> '{kinds,care_logged,total}')::integer=500, 'The capped total';
 assert (today #>> '{kinds,app_opened,accounts}')::integer=2, 'Both opened the app';
 assert (today #>> '{kinds,post_created,total}')::integer=25, 'Posts counted';
 assert ((summary -> 1) #>> '{kinds,deal_opened,total}')::integer=2, 'Yesterday is the second element';
 assert ((summary -> 27) ->> 'active')::integer=0, 'A day without counts has no active accounts';
 assert ((summary -> 27) ->> 'today_tick_share')::numeric=0, 'and a share of 0';
 assert jsonb_array_length(public.usage_summary(31))=31, 'A longer window';
 assert ((public.usage_summary(31) -> 30) ->> 'active')::integer=1, 'The row 30 days ago is in it';
 assert jsonb_array_length(public.usage_summary(null))=28, 'The default is 28 days';
 begin
  perform public.usage_summary(0);
  raise exception 'A zero-day summary was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform public.usage_summary(401);
  raise exception 'A summary over 400 days was accepted';
 exception when invalid_parameter_value then null; end;
 begin
  perform count(*) from public.usage_counts;
  raise exception 'An administrator read the rows directly';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Housekeeping: rows older than 400 days go.
do $$ begin
 assert usage_private.housekeeping()=1, 'Housekeeping removes the row older than 400 days';
 assert exists(select 1 from public.usage_counts where day=current_date - 30), 'Recent rows stay';
end $$;

-- Deleting an account deletes its counts and its call counters.
delete from auth.users where id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2';
do $$ begin
 assert not exists(select 1 from public.usage_counts where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2'),
  'The deleted account''s counts are gone';
 assert not exists(select 1 from usage_private.calls where user_id='e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2'),
  'and its call counters';
 assert exists(select 1 from public.usage_counts where user_id='f3f3f3f3-f3f3-4f3f-8f3f-f3f3f3f3f3f3'),
  'Other accounts keep theirs';
end $$;
rollback;
\echo 'Usage count tests passed.'
