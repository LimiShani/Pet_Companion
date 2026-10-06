\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values('99999999-9999-4999-8999-999999999999','persistent-admin@example.test');
insert into public.access_admins(user_id) values('99999999-9999-4999-8999-999999999999');
select set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
set local role authenticated;
select public.access_admin_change('feature','{"id":"care","enabled":false}');
commit;
