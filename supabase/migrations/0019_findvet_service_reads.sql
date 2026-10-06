-- Find a vet: "public search off" must not hide the directory from signed-in
-- searches. Apply after 0018.
--
-- The find-vet Edge Function authorises the caller (findvet.search through
-- the caller's own token) and only then reads these views with the service
-- role. That read has no auth user, so can_use() answered with the anonymous
-- policy: turning public search off emptied every search, signed-in or not.
-- The service role is trusted server code and already bypasses row level
-- security; it reads the views unfiltered. Every other caller keeps its own
-- policy.
begin;
create or replace view public.vet_directory_public with(security_invoker=true) as
 select * from vet_private.vet_directory_public
 where current_user='service_role' or public.can_use('findvet.search');
create or replace view public.vet_intake_current with(security_invoker=true) as
 select * from vet_private.vet_intake_current
 where current_user='service_role' or public.can_use('findvet.search');
commit;
