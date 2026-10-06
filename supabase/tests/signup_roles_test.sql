\set ON_ERROR_STOP on
-- Disposable database only: Supabase Auth inserts auth.users using a
-- privileged role, but signup metadata is controlled by the user.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('77777777-7777-4777-8777-777777777771','new-owner@example.test','{"display_name":"Owner"}'),
 ('77777777-7777-4777-8777-777777777772','claimed-admin@example.test',
  '{"display_name":"Administrator","role":"admin","is_admin":true,"access.admin":true,"groups":["administrators"]}');

do $$ declare new_user uuid; begin
 foreach new_user in array array[
  '77777777-7777-4777-8777-777777777771'::uuid,
  '77777777-7777-4777-8777-777777777772'::uuid
 ] loop
  assert (select count(*) from public.access_group_members where user_id=new_user)=1,
   'Signup creates exactly one group membership';
  assert exists(select 1 from public.access_group_members where user_id=new_user
   and group_id='acc35500-0000-4000-8000-000000000001'), 'Signup joins Standard owners';
  assert not exists(select 1 from public.access_admins where user_id=new_user),
   'Signup must never provision a permission administrator';
  assert not exists(select 1 from public.vet_directory_admins where user_id=new_user),
   'Signup must never provision a directory reviewer';
  perform set_config('request.jwt.claim.sub',new_user::text,true);
  assert public.can_use('pets.edit') and public.can_use('care.edit'), 'New account has normal owner access';
  assert not public.can_use('access.admin') and not public.can_use('findvet.admin'),
   'Neither normal nor forged signup metadata grants administration';
 end loop;
end $$;

-- Even mistakenly provisioned capability rules cannot replace role membership.
update auth.users set raw_user_meta_data='{"role":"administrator","is_admin":true}'
 where id='77777777-7777-4777-8777-777777777772';
insert into public.user_capability_rules(user_id,capability,allowed) values
 ('77777777-7777-4777-8777-777777777772','access.admin',true),
 ('77777777-7777-4777-8777-777777777772','findvet.admin',true);
insert into public.group_capability_rules(group_id,capability,allowed) values
 ('acc35500-0000-4000-8000-000000000001','access.admin',true),
 ('acc35500-0000-4000-8000-000000000001','findvet.admin',true);
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777772',true);
set local role authenticated;
do $$ declare protected_table text; statement text; begin
 assert not public.can_use('access.admin') and not public.can_use('findvet.admin'),
  'Metadata edits and feature rules cannot substitute for administrator membership';
 foreach protected_table in array array['access_admins','vet_directory_admins',
  'access_group_members','group_capability_rules','user_capability_rules'] loop
  assert not has_table_privilege(current_user,'public.'||protected_table,'INSERT'),
   'Ordinary accounts cannot insert into '||protected_table;
  assert not has_table_privilege(current_user,'public.'||protected_table,'UPDATE'),
   'Ordinary accounts cannot update '||protected_table;
  assert not has_table_privilege(current_user,'public.'||protected_table,'DELETE'),
   'Ordinary accounts cannot delete from '||protected_table;
 end loop;
 foreach statement in array array[
  'insert into public.access_admins(user_id) values(auth.uid())',
  'insert into public.vet_directory_admins(user_id) values(auth.uid())',
  'select public.access_admin_change(''user_rule'',jsonb_build_object(''user_id'',auth.uid(),''capability'',''access.admin'',''allowed'',true))',
  'select public.access_admin_state()',
  'select public.access_admin_history()',
  'select access_private.evaluate(auth.uid(),''access.admin'')'
 ] loop
  begin
   execute statement;
   raise exception 'Regular account bypassed administrator protection: %',statement;
  exception when insufficient_privilege then null;
  end;
 end loop;
end $$;
reset role;
rollback;
\echo 'New-account defaults, forged metadata and self-promotion protection passed.'
