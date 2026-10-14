\set ON_ERROR_STOP on
-- Disposable database only. Households (0030_household.sql): every account
-- owns one, invitations, a carer's rights over the owner's pets, what only
-- the owner may do, files, vets, leaving, removing, deleting an account.
-- Running the migration again changes nothing (and redoes its two patches
-- of 0028 and 0015 functions, which the meetups test re-applied).
\i /tests/migrations/0030_household.sql
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('a1111111-1111-4111-8111-111111111111','ana@example.test','{"display_name":"Ana"}'),
 ('a2222222-2222-4222-8222-222222222222','ben@example.test','{"display_name":"Ben"}'),
 ('a3333333-3333-4333-8333-333333333333','cleo@example.test','{"display_name":"Cleo"}'),
 ('a4444444-4444-4444-8444-444444444444','dov@example.test','{"display_name":"Dov"}');
-- Dov's households are switched off by an administrator.
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('a4444444-4444-4444-8444-444444444444','household.view',false);

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
create table pg_temp.ids(name text primary key, id text);
grant all on pg_temp.ids to authenticated;

-- Every account owns a household of one, made at sign-up.
do $$ begin
 assert (select count(*) from public.households h join auth.users u on u.id=h.owner_id
         where u.email like '%@example.test' and u.id::text like 'a%')=4, 'Every new account owns a household';
 assert (select count(*) from public.household_members m
         where m.user_id='a1111111-1111-4111-8111-111111111111' and m.role='owner')=1, 'The owner is its member';
end $$;
insert into pg_temp.ids select 'ana_home', id::text from public.households where owner_id='a1111111-1111-4111-8111-111111111111';
insert into pg_temp.ids select 'ben_home', id::text from public.households where owner_id='a2222222-2222-4222-8222-222222222222';

-- Ana adds Kelly: into her own household, owned by her.
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
with r as (insert into public.pets(name, species) values ('Kelly','dog') returning id)
insert into pg_temp.ids select 'kelly', id::text from r;
do $$
declare kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
begin
 assert (select household_id::text from public.pets where id=kelly)=(select id from pg_temp.ids where name='ana_home'), 'A new pet joins the adder''s household';
 assert public.pet_role(kelly)='owner', 'Ana owns Kelly';
 assert (select jsonb_array_length(public.get_my_pet_context()))=1, 'Ana''s pets: Kelly';
 assert (select public.get_my_pet_context()->0->>'my_role')='owner', 'The pet context carries the role';
end $$;
-- Ana's vet goes on Kelly's health profile.
with r as (insert into public.vets(name) values ('Dr. Paws') returning id)
insert into pg_temp.ids select 'ana_vet', id::text from r;
insert into public.health_profiles(pet_id, regular_vet_id)
select (select id::uuid from pg_temp.ids where name='kelly'), (select id::uuid from pg_temp.ids where name='ana_vet');
reset role;

-- Ben is not in the household yet: he sees nothing of Kelly.
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$
declare kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
begin
 assert not exists(select 1 from public.pets where id=kelly), 'A stranger does not see the pet';
 assert public.pet_role(kelly) is null, 'A stranger has no role';
 begin
  insert into public.care_logs(pet_id,title,due_on,status) values (kelly,'Walk',current_date,'done');
  raise exception 'A stranger logged a walk';
 exception when insufficient_privilege then null; end;
 assert not exists(select 1 from public.vets where id=(select id::uuid from pg_temp.ids where name='ana_vet')), 'A stranger does not see the vet';
end $$;
reset role;

-- Ana invites; Ben previews and joins.
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
insert into pg_temp.ids select 'code1', public.create_household_invite((select id::uuid from pg_temp.ids where name='ana_home'))->>'code';
do $$
declare code text := (select id from pg_temp.ids where name='code1');
begin
 assert code ~ '^[A-HJ-NP-Z2-9]{8}$', 'A code of 8 unambiguous letters and digits';
 assert jsonb_array_length(public.my_households()->0->'invites')=1, 'The open invitation is listed';
 begin
  insert into public.household_members(household_id,user_id,role)
  values ((select id::uuid from pg_temp.ids where name='ana_home'),'a3333333-3333-4333-8333-333333333333','carer');
  raise exception 'A member wrote a membership row';
 exception when insufficient_privilege then null; end;
 begin
  update public.households set name='Mine' where owner_id=auth.uid();
  raise exception 'A member wrote the household row';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$
declare
 code text := (select id from pg_temp.ids where name='code1');
 preview jsonb;
 joined uuid;
begin
 preview := public.preview_household_invite(lower(substr(code,1,4))||'-'||substr(code,5));
 assert preview->>'status'='open', 'The code is typed in any case, with a dash';
 assert preview->>'inviter_name'='Ana', 'Who invited';
 assert preview->'pets'->0->>'name'='Kelly', 'The pets';
 assert (preview->>'member_count')::int=1, 'How many people';
 assert preview ? 'household_id' and not (preview ? 'members'), 'Nothing more of the household';
 joined := public.accept_household_invite(code);
 assert joined::text=(select id from pg_temp.ids where name='ana_home'), 'Ben joins Ana''s household';
 assert public.pet_role((select id::uuid from pg_temp.ids where name='kelly'))='carer', 'Ben is a carer';
 assert (select public.preview_household_invite(code)->>'status')='member', 'Already a member';
 begin
  perform public.accept_household_invite(code);
  raise exception 'Joined twice';
 exception when unique_violation then null; end;
 assert jsonb_array_length(public.my_households())=2, 'Ben is in his own household and in Ana''s';
 assert (public.my_households()->0->>'owner_id')=auth.uid()::text, 'His own household comes first';
 assert (select jsonb_array_length(h->'members') from jsonb_array_elements(public.my_households()) h
         where h->>'id'=joined::text)=2, 'Ana''s household has two members';
 assert exists(select 1 from jsonb_array_elements(public.my_households()) h, jsonb_array_elements(h->'members') m
         where m->>'name'='Ana' and m->>'role'='owner'), 'Fellow members have names';
end $$;
reset role;

-- The invitation was for one person.
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 begin
  perform public.accept_household_invite((select id from pg_temp.ids where name='code1'));
  raise exception 'A used invitation worked again';
 exception when insufficient_privilege then
  assert sqlerrm='invite_used', sqlerrm;
 end;
 assert public.preview_household_invite('ZZZZ2222')->>'status'='not_found', 'An unknown code';
end $$;
reset role;

-- A carer's rights over the owner's pet.
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$
declare
 kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
 ben uuid := 'a2222222-2222-4222-8222-222222222222';
 ana uuid := 'a1111111-1111-4111-8111-111111111111';
 plan uuid; med uuid; log uuid;
begin
 assert exists(select 1 from public.pets where id=kelly), 'Ben sees Kelly';
 assert (select count(*) from jsonb_array_elements(public.get_my_pet_context()) p where p->>'my_role'='carer')=1, 'Kelly is in Ben''s pets as a carer';
 -- Reminders, medicines and logs: the pet's owner owns them, Ben wrote them.
 insert into public.care_plan_items(pet_id,kind,title,time_of_day) values (kelly,'walk','Evening walk','19:00') returning id into plan;
 assert (select owner_id from public.care_plan_items where id=plan)=ana, 'A carer''s reminder belongs to the pet''s owner';
 insert into public.care_logs(pet_id,plan_item_id,title,due_on,status,owner_id) values (kelly,plan,'Evening walk',current_date,'done',ben) returning id into log;
 assert (select owner_id from public.care_logs where id=log)=ana, 'The log belongs to the pet''s owner whatever the app sends';
 assert (select logged_by from public.care_logs where id=log)=ben, 'and records who logged it';
 begin
  update public.care_logs set logged_by=ana where id=log;
  assert (select logged_by from public.care_logs where id=log)=ben, 'Who logged it cannot be changed';
 end;
 insert into public.medications(pet_id,name) values (kelly,'Rimadyl') returning id into med;
 insert into public.care_plan_items(pet_id,kind,title,time_of_day,medication_id) values (kelly,'medication','Rimadyl','08:00',med);
 insert into public.health_observations(pet_id,category,level) values (kelly,'appetite','less');
 assert (select logged_by from public.health_observations where pet_id=kelly)=ben, 'An observation records who noted it';
 insert into public.health_events(pet_id,title,scheduled_at) values (kelly,'Check-up',now() + interval '2 days');
 insert into public.emergency_kit_items(pet_id,item) values (kelly,'water');
 -- The pet's profile, yes; archiving, deleting or moving it, no.
 update public.pets set name='Kelly B.' where id=kelly;
 assert (select name from public.pets where id=kelly)='Kelly B.', 'A carer edits the pet';
 update public.pets set household_id=(select id::uuid from pg_temp.ids where name='ben_home'), owner_id=ben where id=kelly;
 assert (select owner_id from public.pets where id=kelly)=ana
    and (select household_id::text from public.pets where id=kelly)=(select id from pg_temp.ids where name='ana_home'),
  'The household and the owner do not change from the app';
 begin
  update public.pets set archived_at=now() where id=kelly;
  raise exception 'A carer archived the pet';
 exception when insufficient_privilege then null; end;
 delete from public.pets where id=kelly;
 assert exists(select 1 from public.pets where id=kelly), 'A carer cannot delete the pet';
 -- The vet on the shared profile, and his own vets; not a stranger's.
 assert exists(select 1 from public.vets where id=(select id::uuid from pg_temp.ids where name='ana_vet')), 'Ben sees Kelly''s vet';
 update public.health_profiles set emergency_vet_id=(select id::uuid from pg_temp.ids where name='ana_vet') where pet_id=kelly;
 assert found, 'Ben may pick the vet already on the profile';
end $$;
reset role;

-- A new pet of Ben's goes to his own household unless he names Ana's.
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
with r as (insert into public.pets(name, species) values ('Mitzi','cat') returning id)
insert into pg_temp.ids select 'mitzi', id::text from r;
with r as (insert into public.pets(name, species, household_id, owner_id)
 values ('Soya','dog',(select id::uuid from pg_temp.ids where name='ana_home'),'a2222222-2222-4222-8222-222222222222') returning id)
insert into pg_temp.ids select 'soya', id::text from r;
do $$ begin
 assert (select household_id::text from public.pets where id=(select id::uuid from pg_temp.ids where name='mitzi'))=(select id from pg_temp.ids where name='ben_home'), 'Ben''s own household by default';
 assert (select owner_id from public.pets where id=(select id::uuid from pg_temp.ids where name='soya'))='a1111111-1111-4111-8111-111111111111', 'A pet added to Ana''s household is Ana''s';
end $$;
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 begin
  insert into public.pets(name, household_id) values ('Intruder',(select id::uuid from pg_temp.ids where name='ana_home'));
  raise exception 'A stranger added a pet to someone''s household';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Files: Ben's photo of Kelly, in his own folder; Ana reads it, Cleo not.
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
insert into storage.objects(bucket_id,name) values ('pet-photos','a2222222-2222-4222-8222-222222222222/'||(select id from pg_temp.ids where name='kelly')||'/avatar_1.jpg');
update public.pets set photo_path='a2222222-2222-4222-8222-222222222222/'||(select id from pg_temp.ids where name='kelly')||'/avatar_1.jpg'
where id=(select id::uuid from pg_temp.ids where name='kelly');
do $$ begin
 begin
  update public.pets set photo_path='a1111111-1111-4111-8111-111111111111/x/avatar.jpg' where id=(select id::uuid from pg_temp.ids where name='kelly');
  raise exception 'A row pointed at someone else''s file';
 exception when insufficient_privilege then null; end;
end $$;
-- A document of Kelly's check-up, in Ben's folder.
insert into storage.objects(bucket_id,name) values ('pet-documents','a2222222-2222-4222-8222-222222222222/'||(select id from pg_temp.ids where name='kelly')||'/report.pdf');
insert into public.health_documents(pet_id,record_id,storage_path,file_name,mime_type,size_bytes)
select p.id, e.id, 'a2222222-2222-4222-8222-222222222222/'||p.id||'/report.pdf', 'report.pdf', 'application/pdf', 1000
from public.pets p join public.health_events e on e.pet_id=p.id where p.id=(select id::uuid from pg_temp.ids where name='kelly');
reset role;
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
do $$ begin
 assert exists(select 1 from storage.objects where bucket_id='pet-photos' and name like 'a2222222-2222-4222-8222-222222222222/%'), 'Ana reads Ben''s photo of Kelly';
 assert exists(select 1 from storage.objects where bucket_id='pet-documents' and name like 'a2222222-2222-4222-8222-222222222222/%'), 'Ana reads Ben''s document';
 assert exists(select 1 from public.health_documents where file_name='report.pdf'), 'and its row';
 assert (select count(*) from public.care_logs where pet_id=(select id::uuid from pg_temp.ids where name='kelly'))=1, 'Ana sees Ben''s log';
 assert (select count(*) from public.health_observations)=1, 'and his observation';
 -- Ana replaces the photo: Ben, whose folder it is, gets the clean-up job.
 update public.pets set photo_path=null where id=(select id::uuid from pg_temp.ids where name='kelly');
end $$;
reset role;
do $$ begin
 assert (select owner_id from public.storage_cleanup_jobs where path like 'a2222222-2222-4222-8222-222222222222/%avatar_1.jpg')='a2222222-2222-4222-8222-222222222222',
  'The uploader cleans up a replaced file';
end $$;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 assert not exists(select 1 from storage.objects where bucket_id in ('pet-photos','pet-documents')), 'A stranger reads no file';
 assert not exists(select 1 from public.care_logs), 'nor any log';
 assert not exists(select 1 from public.health_documents), 'nor any document';
 assert jsonb_array_length(public.get_my_pet_context())=0, 'nor any pet';
end $$;
reset role;

-- Server functions that asked "is it the caller's pet?" now ask "is it in
-- the caller's household?".
do $$ begin
 assert pg_get_functiondef('public.meetup_save'::regproc) like '%public.health_owns_pet(id)%', 'Walk ads take a shared pet';
 assert pg_get_functiondef('access_private.record_basket_purchase'::regproc) like '%public.health_owns_pet(product.pet_id)%', 'Basket purchases take a shared pet';
 assert pg_get_functiondef('community_private.rate_limit_statement'::regproc) like '%coalesce(logged_by, owner_id)%', 'Care logs are limited per person who logs';
end $$;
insert into public.pet_first_days(pet_id, owner_id, arrived_on)
values ((select id::uuid from pg_temp.ids where name='kelly'),'a1111111-1111-4111-8111-111111111111',current_date);
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$ begin
 assert 'bed' = any(array(select jsonb_array_elements_text(
   public.set_first_days_task((select id::uuid from pg_temp.ids where name='kelly'),'bed',true)->'done_tasks'))),
  'A carer ticks the first days list';
end $$;
reset role;

-- Rules: only the owner renames and removes; anyone but the owner leaves.
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$
declare home uuid := (select id::uuid from pg_temp.ids where name='ana_home');
begin
 begin perform public.rename_household(home,'Ours'); raise exception 'A carer renamed';
 exception when insufficient_privilege then null; end;
 begin perform public.remove_household_member(home,'a1111111-1111-4111-8111-111111111111'); raise exception 'A carer removed the owner';
 exception when insufficient_privilege then null; end;
 -- A carer may invite, and take back an invitation.
 insert into pg_temp.ids select 'code2', public.create_household_invite(home)->>'code';
 perform public.revoke_household_invite((select id from pg_temp.ids where name='code2'));
 assert jsonb_array_length((select h->'invites' from jsonb_array_elements(public.my_households()) h where h->>'id'=home::text))=0, 'Taken back';
end $$;
reset role;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 begin perform public.accept_household_invite((select id from pg_temp.ids where name='code2')); raise exception 'A revoked invitation worked';
 exception when insufficient_privilege then assert sqlerrm='invite_used', sqlerrm; end;
end $$;
reset role;
-- An expired invitation.
update public.household_invites set expires_at=now() - interval '1 minute' where code=(select id from pg_temp.ids where name='code2');
update public.household_invites set revoked_at=null where code=(select id from pg_temp.ids where name='code2');
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 begin perform public.accept_household_invite((select id from pg_temp.ids where name='code2')); raise exception 'An expired invitation worked';
 exception when insufficient_privilege then assert sqlerrm='invite_expired', sqlerrm; end;
end $$;
reset role;

select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
do $$
declare home uuid := (select id::uuid from pg_temp.ids where name='ana_home');
begin
 perform public.rename_household(home,'  The Shanis  ');
 assert (select name from public.households where id=home)='The Shanis', 'The owner renames; the name is trimmed';
 begin perform public.rename_household(home,repeat('x',41)); raise exception 'A long name';
 exception when check_violation then null; end;
 begin perform public.leave_household(home); raise exception 'The owner left';
 exception when insufficient_privilege then null; end;
 begin perform public.remove_household_member(home,auth.uid()); raise exception 'The owner removed themself';
 exception when insufficient_privilege then null; end;
 -- Ten people at most, open invitations included (Ana and Ben + 8).
 for i in 1..8 loop perform public.create_household_invite(home); end loop;
 begin perform public.create_household_invite(home); raise exception 'An eleventh place';
 exception when check_violation then assert sqlerrm='household_full', sqlerrm; end;
end $$;
reset role;
update public.household_invites set revoked_at=now()
where household_id=(select id::uuid from pg_temp.ids where name='ana_home') and accepted_at is null;
-- The owner removes Ben: he loses Kelly at once; what he logged stays.
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
select public.remove_household_member((select id::uuid from pg_temp.ids where name='ana_home'),'a2222222-2222-4222-8222-222222222222');
reset role;
select pg_temp.act_as('a2222222-2222-4222-8222-222222222222');
do $$ begin
 assert not exists(select 1 from public.pets where id=(select id::uuid from pg_temp.ids where name='kelly')), 'A removed carer sees nothing';
 assert jsonb_array_length(public.my_households())=1, 'Only his own household is left';
 assert exists(select 1 from public.pets where id=(select id::uuid from pg_temp.ids where name='mitzi')), 'His own pets stay his';
end $$;
reset role;
do $$ begin
 assert (select logged_by from public.care_logs where title='Evening walk')='a2222222-2222-4222-8222-222222222222', 'His logs stay';
end $$;

-- Too many wrong codes in an hour.
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
do $$ begin
 for i in 1..19 loop perform public.preview_household_invite('WRONG'||i); end loop;
 begin perform public.preview_household_invite('WRONGER'); raise exception 'Guessing went on';
 exception when raise_exception then assert sqlerrm='rate_limited', sqlerrm; end;
end $$;
reset role;

-- An account without households: nothing works.
select pg_temp.act_as('a4444444-4444-4444-8444-444444444444');
do $$ begin
 assert not public.can_use('household.view'), 'Switched off';
 begin perform public.my_households(); raise exception 'Households without the capability';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

-- A carer deletes his account: Ana's records keep his logs, nameless.
select pg_temp.act_as('a1111111-1111-4111-8111-111111111111');
insert into pg_temp.ids select 'code3', public.create_household_invite((select id::uuid from pg_temp.ids where name='ana_home'))->>'code';
reset role;
-- (Cleo's wrong guesses above are forgotten.)
delete from household_private.join_attempts;
select pg_temp.act_as('a3333333-3333-4333-8333-333333333333');
select public.accept_household_invite((select id from pg_temp.ids where name='code3'));
insert into public.care_logs(pet_id,title,due_on,status) values ((select id::uuid from pg_temp.ids where name='kelly'),'Breakfast',current_date,'done');
reset role;
delete from auth.users where id='a3333333-3333-4333-8333-333333333333';
do $$ begin
 assert exists(select 1 from public.care_logs where title='Breakfast' and logged_by is null), 'A deleted carer''s log stays, nameless';
 assert not exists(select 1 from public.household_members where user_id='a3333333-3333-4333-8333-333333333333'), 'and the membership goes';
end $$;
-- The owner deletes her account: the household and its pets go with it.
delete from auth.users where id='a1111111-1111-4111-8111-111111111111';
do $$ begin
 assert not exists(select 1 from public.households where id=(select id::uuid from pg_temp.ids where name='ana_home')), 'The household goes with its owner';
 assert not exists(select 1 from public.pets where id=(select id::uuid from pg_temp.ids where name='kelly')), 'and its pets';
end $$;

rollback;
\echo 'Household tests passed.'
