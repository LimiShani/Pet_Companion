\set ON_ERROR_STOP on
-- Crash reports (0024): who may write, who may read, the rate limit and
-- the prune. Runs in the disposable test database only.
begin;
insert into auth.users(id,email) values
 ('a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1','admin@example.test'),
 ('b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2','owner@example.test');
insert into public.access_admins(user_id) values('a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1');

-- An ordinary signed-in owner.
select set_config('request.jwt.claim.sub','b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2',true);
set local role authenticated;
insert into public.crash_reports(user_id,session_id,occurred_at,kind,fatal,message,stack,app_version,build_number,platform,os_version,locale)
 values('b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2','run-1',now(),'dart',true,'Null check operator used on a null value','#0 main','0.1.0','1','android','Android 15','he-IL');
insert into public.crash_reports(user_id,session_id,occurred_at,kind,fatal,message,app_version,build_number,platform)
 values(null,'run-1',now(),'flutter',false,'RenderFlex overflowed','0.1.0','1','android');
do $$ begin
 begin
  insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform)
   values('a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1','run-1',now(),'dart','Forged owner','0.1.0','1','android');
  raise exception 'A report was written in another account''s name';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform)
   values(null,'run-1',now(),'native','Unknown kind','0.1.0','1','android');
  raise exception 'An unknown kind was accepted';
 exception when check_violation then null; end;
 assert (select count(*) from public.crash_reports)=0, 'Owners cannot read crash reports';
 begin
  update public.crash_reports set message='changed';
  raise exception 'An owner changed a report';
 exception when insufficient_privilege then null; end;
 begin
  delete from public.crash_reports;
  raise exception 'An owner deleted reports';
 exception when insufficient_privilege then null; end;
 begin
  perform public.crash_reports_prune(1);
  raise exception 'An owner pruned reports';
 exception when insufficient_privilege then null; end;
end $$;

-- The per-account limit: 60 rows an hour, the rest dropped quietly.
do $$ begin
 for i in 1..70 loop
  insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform)
   values('b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2','run-2',now(),'dart','Loop '||i,'0.1.0','1','android');
 end loop;
end $$;
reset role;
do $$ begin
 assert (select count(*) from public.crash_reports where user_id='b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2')=60,
  'An account writes at most 60 reports an hour';
 assert (select count(*) from public.crash_reports where user_id is null)=1, 'The ownerless report was kept';
end $$;

-- A signed-out app.
select set_config('request.jwt.claim.sub','',true);
set local role anon;
insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform)
 values(null,'run-3',now(),'dart','Crash before sign-in','0.1.0','1','ios');
do $$ begin
 begin
  insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform)
   values('a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1','run-3',now(),'dart','Forged owner','0.1.0','1','ios');
  raise exception 'A signed-out app wrote in an account''s name';
 exception when insufficient_privilege then null; end;
 begin
  perform (select count(*) from public.crash_reports);
  raise exception 'A signed-out app read reports';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- A permission administrator reads everything and prunes old rows.
insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform,created_at)
 values(null,'run-0',now()-interval '100 days','dart','Old','0.0.9','1','android',now()-interval '100 days');
select set_config('request.jwt.claim.sub','a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1',true);
set local role authenticated;
do $$ begin
 assert (select count(*) from public.crash_reports)=63, 'Administrators read every report';
 assert (select message from public.crash_reports where kind='dart' and fatal order by id limit 1)
  ='Null check operator used on a null value', 'The report keeps its message';
 assert public.crash_reports_prune(90)=1, 'Prune removes the rows older than the given days';
 assert public.crash_reports_prune(1)=0, 'Prune never goes under seven days';
 assert (select count(*) from public.crash_reports)=62, 'Fresh reports stay';
end $$;
reset role;
rollback;
\echo 'Crash report tests passed.'
