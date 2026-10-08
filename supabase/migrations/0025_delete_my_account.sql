-- PetLoop: an account deletes itself from the app. Apply after 0024.
--
--   * delete_my_account(): the signed-in account deletes its own
--     auth.users row. Everything the account owns goes with it through
--     the existing cascades (pets, records, documents, community content,
--     chat, push devices), and the stored files are queued for the clean-up
--     worker as 0018 arranged. Crash reports keep their row and lose the
--     account (on delete set null).
--
-- Runs as the owner because clients have no rights on auth.users. Only a
-- signed-in account may call it, and it can only delete itself.
--
-- Additive and idempotent.
begin;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'Sign in first' using errcode = 'insufficient_privilege';
  end if;
  delete from auth.users where id = me;
end
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

commit;
