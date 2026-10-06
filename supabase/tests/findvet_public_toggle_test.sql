\set ON_ERROR_STOP on
-- Disposable database only. "Public vet search off" means signed-in users
-- only: the find-vet Edge Function checks the caller's findvet.search first,
-- then reads the directory views with the service role, which has no auth
-- user. Those reads must not fall back to the anonymous policy.
begin;
insert into public.vet_facilities(id,name,review_status,lat,lng) values
 ('99999999-9999-4999-8999-999999999991','Test vet','approved',32.08,34.78);
insert into public.vet_intake_status(facility_id,status,species,expires_at) values
 ('99999999-9999-4999-8999-999999999991','accepting','{dogs}',now()+interval '1 hour');
insert into auth.users(id,email) values
 ('99999999-9999-4999-8999-999999999992','member@example.test');
update public.feature_catalog set enabled=true,public_enabled=false where id='findvet';

select set_config('request.jwt.claim.sub','',true);
set local role service_role;
do $$ begin
 assert (select count(*) from public.vet_directory_public
  where id='99999999-9999-4999-8999-999999999991')=1,
  'The Edge Function (service role) still reads curated vets when public search is off';
 assert (select count(*) from public.vet_intake_current
  where facility_id='99999999-9999-4999-8999-999999999991')=1,
  'The Edge Function (service role) still reads intake when public search is off';
end $$;
reset role;

set local role anon;
do $$ begin
 assert (select count(*) from public.vet_directory_public)=0,
  'Anonymous callers see no curated vets when public search is off';
 assert (select count(*) from public.vet_intake_current)=0,
  'Anonymous callers see no intake when public search is off';
end $$;
reset role;

select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999992',true);
set local role authenticated;
do $$ begin
 assert (select count(*) from public.vet_directory_public
  where id='99999999-9999-4999-8999-999999999991')=1,
  'Signed-in members with findvet.search see curated vets';
end $$;
reset role;

update public.feature_catalog set public_enabled=true where id='findvet';
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 assert (select count(*) from public.vet_directory_public
  where id='99999999-9999-4999-8999-999999999991')=1,
  'Anonymous callers see curated vets when public search is on';
end $$;
reset role;
rollback;
\echo 'Find-a-vet public switch keeps curated vets for signed-in searches passed.'
