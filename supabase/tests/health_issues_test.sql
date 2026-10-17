\set ON_ERROR_STOP on
-- Disposable database only. Following a problem (0033_health_issues.sql):
-- household members share a pet's problems, entries link to a problem of
-- the same pet, deleting a problem keeps its entries, photos of an entry
-- (photos only, four at most) go with the entry, the pet and the account,
-- and at most 20 new problems per pet per day. Running the migration again
-- changes nothing.
\i /tests/migrations/0033_health_issues.sql
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('b1111111-1111-4111-8111-111111111111','hana@example.test','{"display_name":"Hana"}'),
 ('b2222222-2222-4222-8222-222222222222','omer@example.test','{"display_name":"Omer"}'),
 ('b3333333-3333-4333-8333-333333333333','tal@example.test','{"display_name":"Tal"}');

create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
 perform set_config('request.jwt.claim.sub',p::text,true);
 perform set_config('role','authenticated',true);
end $$;
create table pg_temp.ids(name text primary key, id text);
grant all on pg_temp.ids to authenticated;

-- Hana adds Kelly and Soya, and invites Omer, who joins as a carer.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
with r as (insert into public.pets(name, species) values ('Kelly','dog') returning id)
insert into pg_temp.ids select 'kelly', id::text from r;
with r as (insert into public.pets(name, species) values ('Soya','cat') returning id)
insert into pg_temp.ids select 'soya', id::text from r;
insert into pg_temp.ids select 'code', public.create_household_invite(
 (select id from public.households where owner_id='b1111111-1111-4111-8111-111111111111'))->>'code';
reset role;
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
select public.accept_household_invite((select id from pg_temp.ids where name='code'));
reset role;

-- Omer, a carer, starts following a problem of Kelly's.
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
with r as (
 insert into public.health_issues(pet_id, title, body_area, started_on)
 values ((select id::uuid from pg_temp.ids where name='kelly'), '  Limping, right front leg ', '  ', current_date - 7)
 returning id)
insert into pg_temp.ids select 'limp', id::text from r;
do $$
declare
 kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
 limp uuid := (select id::uuid from pg_temp.ids where name='limp');
 row public.health_issues;
begin
 select * into row from public.health_issues where id=limp;
 assert row.owner_id='b1111111-1111-4111-8111-111111111111', 'The problem is owned by the pet''s owner';
 assert row.created_by='b2222222-2222-4222-8222-222222222222', 'and was started by Omer';
 assert row.title='Limping, right front leg', 'The title is trimmed';
 assert row.body_area is null, 'An empty body area is no body area';
 assert row.status='open' and row.resolved_on is null, 'A new problem is open';
 -- Nobody changes who started it or which pet it is about.
 update public.health_issues set created_by='b1111111-1111-4111-8111-111111111111',
   pet_id=(select id::uuid from pg_temp.ids where name='soya'), title='Limping'
 where id=limp;
 select * into row from public.health_issues where id=limp;
 assert row.created_by='b2222222-2222-4222-8222-222222222222' and row.pet_id=kelly and row.title='Limping',
  'The pet and the starter stay; the title changes';
 -- Resolving fills the day; reopening clears it.
 update public.health_issues set status='resolved' where id=limp;
 assert (select resolved_on from public.health_issues where id=limp)=current_date, 'Resolved today';
 update public.health_issues set status='open', resolved_on=current_date where id=limp;
 assert (select resolved_on from public.health_issues where id=limp) is null, 'Open again';
 begin
  update public.health_issues set status='resolved', resolved_on=current_date - 30 where id=limp;
  raise exception 'Resolved before it started';
 exception when check_violation then null; end;
 begin
  insert into public.health_issues(pet_id, title) values (kelly, '');
  raise exception 'A problem without a title';
 exception when check_violation then null; end;
end $$;

-- Entries: Omer logs two for the problem; one of them has photos.
with r as (
 insert into public.health_observations(pet_id, category, level, note, issue_id)
 values ((select id::uuid from pg_temp.ids where name='kelly'), 'mobility', 'less', 'Holds the paw up',
         (select id::uuid from pg_temp.ids where name='limp'))
 returning id)
insert into pg_temp.ids select 'entry1', id::text from r;
with r as (
 insert into public.health_observations(pet_id, category, level, issue_id)
 values ((select id::uuid from pg_temp.ids where name='kelly'), 'mobility', 'usual',
         (select id::uuid from pg_temp.ids where name='limp'))
 returning id)
insert into pg_temp.ids select 'entry2', id::text from r;
do $$
declare
 kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
 soya uuid := (select id::uuid from pg_temp.ids where name='soya');
 limp uuid := (select id::uuid from pg_temp.ids where name='limp');
 entry1 uuid := (select id::uuid from pg_temp.ids where name='entry1');
 folder text := 'b2222222-2222-4222-8222-222222222222/' || kelly || '/' || entry1 || '/';
begin
 -- An entry of Soya cannot belong to Kelly's problem.
 begin
  insert into public.health_observations(pet_id, category, level, issue_id) values (soya, 'appetite', 'less', limp);
  raise exception 'An entry joined another pet''s problem';
 exception when foreign_key_violation then null; end;
 -- Four photos, in Omer's own folder.
 for i in 1..4 loop
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, entry1, folder || i || '.jpg', 'paw.jpg', 'image/jpeg', 1000);
 end loop;
 begin
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, entry1, folder || '5.jpg', 'paw.jpg', 'image/jpeg', 1000);
  raise exception 'A fifth photo';
 exception when raise_exception then
  assert sqlerrm='too_many_photos', sqlerrm;
 end;
 assert (select count(*) from public.health_documents where observation_id=entry1)=4, 'Four photos';
 assert (select count(*) from public.health_documents where observation_id=entry1 and record_id is null)=4,
  'An entry''s photo belongs to no record';
end $$;
reset role;

-- An entry's documents are photos, in the uploader's folder, for one parent.
select pg_temp.act_as('b2222222-2222-4222-8222-222222222222');
do $$
declare
 kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
 soya uuid := (select id::uuid from pg_temp.ids where name='soya');
 entry2 uuid := (select id::uuid from pg_temp.ids where name='entry2');
 folder text := 'b2222222-2222-4222-8222-222222222222/' || kelly || '/' || entry2 || '/';
 record uuid;
begin
 begin
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, entry2, folder || 'x.pdf', 'x.pdf', 'application/pdf', 1000);
  raise exception 'A PDF on an entry';
 exception when check_violation then null; end;
 begin
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, entry2, folder || 'big.jpg', 'big.jpg', 'image/jpeg', 6000000);
  raise exception 'A photo over 5 MB';
 exception when check_violation then null; end;
 begin
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (soya, entry2, 'b2222222-2222-4222-8222-222222222222/' || soya || '/' || entry2 || '/a.jpg',
          'a.jpg', 'image/jpeg', 1000);
  raise exception 'A photo of Kelly''s entry filed under Soya';
 exception when foreign_key_violation then null; end;
 begin
  insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, entry2, 'b1111111-1111-4111-8111-111111111111/' || kelly || '/' || entry2 || '/a.jpg',
          'a.jpg', 'image/jpeg', 1000);
  raise exception 'A photo in somebody else''s folder';
 exception when insufficient_privilege then null; end;
 insert into public.health_events(pet_id, kind, title, scheduled_at) values (kelly, 'checkup', 'Vet', now())
 returning id into record;
 begin
  insert into public.health_documents(pet_id, record_id, observation_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, record, entry2, folder || 'both.jpg', 'both.jpg', 'image/jpeg', 1000);
  raise exception 'A document of a record and of an entry';
 exception when check_violation then null; end;
 begin
  insert into public.health_documents(pet_id, storage_path, file_name, mime_type, size_bytes)
  values (kelly, folder || 'none.jpg', 'none.jpg', 'image/jpeg', 1000);
  raise exception 'A document of nothing';
 exception when check_violation then null; end;
 -- Record documents work as before.
 insert into public.health_documents(pet_id, record_id, storage_path, file_name, mime_type, size_bytes)
 values (kelly, record, 'b2222222-2222-4222-8222-222222222222/' || kelly || '/' || record || '/letter.pdf',
         'letter.pdf', 'application/pdf', 1000);
end $$;
reset role;

-- Hana, the owner, sees what Omer started; Tal, a stranger, sees nothing.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
do $$ begin
 assert (select count(*) from public.health_issues)=1, 'The owner sees the carer''s problem';
 assert (select count(*) from public.health_observations where issue_id=(select id::uuid from pg_temp.ids where name='limp'))=2,
  'and its two entries';
end $$;
reset role;
select pg_temp.act_as('b3333333-3333-4333-8333-333333333333');
do $$
declare kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
begin
 assert not exists(select 1 from public.health_issues), 'A stranger sees no problem';
 begin
  insert into public.health_issues(pet_id, title) values (kelly, 'Coughing');
  raise exception 'A stranger started a problem';
 exception when insufficient_privilege then null; end;
 update public.health_issues set title='Mine';
 delete from public.health_issues;
end $$;
reset role;
do $$ begin
 assert (select title from public.health_issues where id=(select id::uuid from pg_temp.ids where name='limp'))='Limping',
  'A stranger''s update and delete change nothing';
end $$;

-- Deleting an entry removes its photos and queues their files.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
delete from public.health_observations where id=(select id::uuid from pg_temp.ids where name='entry1');
reset role;
do $$
declare entry1 uuid := (select id::uuid from pg_temp.ids where name='entry1');
begin
 assert not exists(select 1 from public.health_documents where observation_id=entry1), 'The entry''s photos are gone';
 assert (select count(*) from public.storage_cleanup_jobs
         where bucket='pet-documents' and path like '%/' || entry1 || '/%'
           and owner_id='b2222222-2222-4222-8222-222222222222')=4,
  'Their files are queued for the uploader''s clean-up';
end $$;

-- Deleting the problem keeps its entries.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
delete from public.health_issues where id=(select id::uuid from pg_temp.ids where name='limp');
reset role;
do $$
declare entry2 uuid := (select id::uuid from pg_temp.ids where name='entry2');
begin
 assert exists(select 1 from public.health_observations where id=entry2 and issue_id is null),
  'The entry stays, without its problem';
end $$;

-- At most 20 new problems per pet per day.
select pg_temp.act_as('b1111111-1111-4111-8111-111111111111');
do $$
declare soya uuid := (select id::uuid from pg_temp.ids where name='soya');
begin
 for i in 1..20 loop
  insert into public.health_issues(pet_id, title) values (soya, 'Problem ' || i);
 end loop;
 begin
  insert into public.health_issues(pet_id, title) values (soya, 'One too many');
  raise exception 'A 21st problem in a day';
 exception when raise_exception then
  assert sqlerrm='rate_limited', sqlerrm;
 end;
 -- Kelly has her own count.
 insert into public.health_issues(pet_id, title) values ((select id::uuid from pg_temp.ids where name='kelly'), 'Coughing');
end $$;
reset role;

-- Deleting the pet removes its problems, entries and photos; deleting the
-- account removes the rest.
with r as (
 insert into public.health_observations(pet_id, category, level, issue_id)
 select p.id, 'mobility', 'less', i.id from public.pets p join public.health_issues i on i.pet_id=p.id
 where p.id=(select id::uuid from pg_temp.ids where name='kelly') limit 1
 returning id)
insert into pg_temp.ids select 'entry3', id::text from r;
insert into public.health_documents(pet_id, observation_id, storage_path, file_name, mime_type, size_bytes)
select (select id::uuid from pg_temp.ids where name='kelly'), (select id::uuid from pg_temp.ids where name='entry3'),
 'b1111111-1111-4111-8111-111111111111/' || (select id from pg_temp.ids where name='kelly') || '/'
   || (select id from pg_temp.ids where name='entry3') || '/p.webp', 'p.webp', 'image/webp', 1000;
delete from public.pets where id=(select id::uuid from pg_temp.ids where name='kelly');
do $$
declare kelly uuid := (select id::uuid from pg_temp.ids where name='kelly');
begin
 assert not exists(select 1 from public.health_issues where pet_id=kelly), 'The pet''s problems are gone';
 assert not exists(select 1 from public.health_observations where pet_id=kelly), 'and its entries';
 assert not exists(select 1 from public.health_documents where pet_id=kelly), 'and its photos';
 assert exists(select 1 from public.storage_cleanup_jobs where path like '%/p.webp'), 'whose files are queued';
end $$;
delete from auth.users where id='b1111111-1111-4111-8111-111111111111';
do $$ begin
 assert not exists(select 1 from public.health_issues where owner_id='b1111111-1111-4111-8111-111111111111'),
  'Deleting the account deletes its problems';
end $$;
rollback;
\echo 'Health issue tests passed.'
