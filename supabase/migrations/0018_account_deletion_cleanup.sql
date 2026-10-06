-- Account deletion with stored files. Apply after 0017.
--
-- Deleting an auth.users row cascades to pets, health documents and posts,
-- whose triggers queue the files for the storage clean-up worker with the
-- deleted account as owner_id. A foreign key from the queue to auth.users
-- made that insert fail, rolling back the whole account deletion. The queue
-- must outlive the account so the worker can still remove its files; the
-- path check keeps every job inside its owner's folder.
begin;
do $$
declare constraint_name text;
begin
 for constraint_name in
  select conname from pg_constraint
  where conrelid='public.storage_cleanup_jobs'::regclass
   and contype='f' and confrelid='auth.users'::regclass
 loop
  execute format('alter table public.storage_cleanup_jobs drop constraint %I',constraint_name);
 end loop;
end $$;
comment on column public.storage_cleanup_jobs.owner_id is
 'Account whose folder holds the file. Not a foreign key: jobs outlive a deleted account until the worker removes its files.';
commit;
