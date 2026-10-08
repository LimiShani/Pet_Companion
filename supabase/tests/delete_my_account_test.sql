\set ON_ERROR_STOP on
-- Disposable database only. An account deletes itself through
-- delete_my_account() (0025): only when signed in, only itself, and what
-- it owned goes with it.
begin;
insert into auth.users(id,email) values
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1','leaver@example.test'),
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c2','stayer@example.test');
insert into public.pets(id,owner_id,name,photo_path) values
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3d1','c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1','Kelly',
  'c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1/pet.jpg'),
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3d2','c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c2','Soya',null);
insert into public.community_posts(author_id,body) values
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1','Leaving soon');
insert into public.crash_reports(user_id,session_id,occurred_at,kind,message,app_version,build_number,platform) values
 ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1','run-x',now(),'dart','Before leaving','0.1.0','1','android');

-- Signed out: nothing happens.
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 begin
  perform public.delete_my_account();
  raise exception 'A signed-out call was allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- The leaver deletes itself.
select set_config('request.jwt.claim.sub','c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1',true);
set local role authenticated;
select public.delete_my_account();
reset role;

do $$ begin
 assert not exists(select 1 from auth.users where id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1'),
  'The account is gone';
 assert exists(select 1 from auth.users where id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c2'),
  'Other accounts stay';
 assert not exists(select 1 from public.pets where owner_id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1'),
  'The account''s pets go with it';
 assert exists(select 1 from public.pets where owner_id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c2'),
  'Other accounts'' pets stay';
 assert not exists(select 1 from public.community_posts where author_id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1'),
  'The account''s posts go with it';
 assert exists(select 1 from public.storage_cleanup_jobs where owner_id='c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c1'),
  'The account''s files are queued for clean-up';
 assert (select user_id is null from public.crash_reports where message='Before leaving'),
  'Crash reports stay without the account';
end $$;
rollback;
\echo 'Self-service account deletion tests passed.'
