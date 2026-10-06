-- Run as database owner after 0014. Fails if the intended account is absent.
begin;
do $$ declare initial_user uuid; begin
 select id into initial_user from auth.users where lower(email)='pixel123@gmail.com';
 if initial_user is null then raise exception 'Create/sign in the pixel123@gmail.com account before bootstrapping permissions'; end if;
 insert into public.access_admins(user_id) values(initial_user) on conflict do nothing;
end $$;
commit;
