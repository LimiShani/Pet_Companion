\set ON_ERROR_STOP on
-- Disposable database only. Deleting an account that has stored files must
-- succeed (dashboard, auth.admin.deleteUser, erasure requests) and must leave
-- the account's files queued for the storage clean-up worker.
begin;
insert into auth.users(id,email) values
 ('88888888-8888-4888-8888-888888888881','leaving@example.test');
insert into public.pets(id,owner_id,name,photo_path) values
 ('88888888-8888-4888-8888-888888888882','88888888-8888-4888-8888-888888888881','Kelly',
  '88888888-8888-4888-8888-888888888881/pet.jpg');
insert into public.health_events(id,pet_id,owner_id,title,scheduled_at) values
 ('88888888-8888-4888-8888-888888888883','88888888-8888-4888-8888-888888888882',
  '88888888-8888-4888-8888-888888888881','Check-up',now());
insert into public.health_documents(pet_id,owner_id,record_id,storage_path,file_name,mime_type,size_bytes) values
 ('88888888-8888-4888-8888-888888888882','88888888-8888-4888-8888-888888888881',
  '88888888-8888-4888-8888-888888888883','88888888-8888-4888-8888-888888888881/doc.pdf',
  'doc.pdf','application/pdf',10);
insert into public.community_posts(author_id,body,photo_path) values
 ('88888888-8888-4888-8888-888888888881','Hello',
  '88888888-8888-4888-8888-888888888881/post.jpg');

delete from auth.users where id='88888888-8888-4888-8888-888888888881';

do $$ begin
 assert not exists(select 1 from auth.users where id='88888888-8888-4888-8888-888888888881'),
  'The account is deleted';
 assert not exists(select 1 from public.pets where owner_id='88888888-8888-4888-8888-888888888881'),
  'The account''s pets are deleted with it';
 assert (select count(*) from public.storage_cleanup_jobs
  where owner_id='88888888-8888-4888-8888-888888888881')=3,
  'Every stored file of the deleted account stays queued for clean-up';
 assert (select bool_and(access_private.file_is_orphan(bucket,path)) from public.storage_cleanup_jobs
  where owner_id='88888888-8888-4888-8888-888888888881'),
  'The worker sees the deleted account''s files as orphans';
end $$;
rollback;
\echo 'Account deletion with stored files passed.'
