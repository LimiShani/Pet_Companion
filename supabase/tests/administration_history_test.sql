\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
 ('77777777-7777-4777-8777-777777777777','history-admin@example.test'),
 ('88888888-8888-4888-8888-888888888888','history-owner@example.test');
insert into public.access_admins(user_id) values('77777777-7777-4777-8777-777777777777');
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777777',true);
set local role authenticated;
do $$ declare page jsonb; second_page jsonb; third_page jsonb; first_id bigint; baseline bigint; begin
 for i in 1..145 loop
  perform public.access_admin_change('feature',jsonb_build_object('id','care','enabled',i%2=0));
 end loop;
 page:=public.access_admin_history(p_limit=>50,p_actor=>'HISTORY-ADMIN',p_action=>'feature_catalog');
 assert jsonb_array_length(page->'entries')=50, 'History is paged';
 assert page->>'next_cursor' is not null, 'Older entries are reachable';
 second_page:=public.access_admin_history(p_before_id=>(page->>'next_cursor')::bigint,p_actor=>'history-admin',p_action=>'feature_catalog');
 third_page:=public.access_admin_history(p_before_id=>(second_page->>'next_cursor')::bigint,p_actor=>'history-admin',p_action=>'feature_catalog');
 assert jsonb_array_length(second_page->'entries')=50, 'Second history page';
 assert jsonb_array_length(third_page->'entries')=45, 'History older than latest 100 retained';
 assert third_page->>'next_cursor' is null, 'Last page stops';
 assert (page->'entries'->49->>'id')::bigint>(second_page->'entries'->0->>'id')::bigint, 'Pages do not overlap';
 assert (second_page->'entries'->49->>'id')::bigint>(third_page->'entries'->0->>'id')::bigint, 'Third page does not overlap';
 assert page->'entries'->0->>'actor_email'='history-admin@example.test', 'Actor identity saved';
 assert page->'entries'->0->'before_value'->>'enabled'='true', 'Previous state saved';
 assert page->'entries'->0->'after_value'->>'enabled'='false', 'Result saved';
 assert jsonb_array_length(public.access_admin_history(p_actor=>'missing-admin')->'entries')=0, 'Actor filter';
 assert jsonb_array_length(public.access_admin_history(p_actor=>'77777777',p_action=>'access_groups')->'entries')=0, 'Action filter';
 assert jsonb_array_length(public.access_admin_history(p_actor=>'history-admin',p_from=>now(),p_until=>now()+interval '1 second')->'entries')>0, 'Inclusive start';
 assert jsonb_array_length(public.access_admin_history(p_actor=>'history-admin',p_until=>now())->'entries')=0, 'Exclusive end';
 baseline:=(select count(*) from public.access_audit);
 begin
  perform public.access_admin_change('feature','{"id":"access","enabled":false}');
  raise exception 'Forbidden change accepted';
 exception when raise_exception then
  if sqlerrm='Forbidden change accepted' then raise; end if;
 end;
 assert (select count(*) from public.access_audit)=baseline, 'Failed changes leave no success record';
 begin perform public.access_admin_history(p_limit=>101); raise exception 'Unbounded page accepted';
 exception when invalid_parameter_value then null; end;
 begin perform public.access_admin_history(p_from=>now(),p_until=>now()); raise exception 'Invalid date range accepted';
 exception when invalid_parameter_value then null; end;
 begin delete from public.access_audit; raise exception 'Administrator deleted history';
 exception when insufficient_privilege then null; end;
 begin update public.access_audit set action='forged'; raise exception 'Administrator modified history';
 exception when insufficient_privilege then null; end;
 begin insert into public.access_audit(action) values('forged'); raise exception 'Client fabricated history';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Server-owned directory events are mirrored with the reviewer and details.
insert into public.vet_admin_actions(admin_id,action,target_type,target_id,note,details)
 values('77777777-7777-4777-8777-777777777777','test_review','facility','saved-facility','Reviewed', '{"decision":"approved"}');
-- Later email changes and account deletion must not erase historical identity.
update auth.users set email='renamed@example.test' where id='77777777-7777-4777-8777-777777777777';
do $$ begin
 assert exists(select 1 from public.access_audit where action='vet_directory:test_review'
  and actor_email='history-admin@example.test' and after_value->>'note'='Reviewed'), 'Directory action saved';
 begin update public.access_audit set action='changed'; raise exception 'Append-only update bypassed';
 exception when insufficient_privilege then null; end;
 begin delete from public.access_audit; raise exception 'Append-only deletion bypassed';
 exception when insufficient_privilege then null; end;
 begin truncate public.access_audit; raise exception 'Append-only truncate bypassed';
 exception when insufficient_privilege then null; end;
end $$;
delete from auth.users where id='77777777-7777-4777-8777-777777777777';
do $$ begin
 assert (select count(*) from public.access_audit where actor_email='history-admin@example.test' and action='feature_catalog:UPDATE')=145, 'Saved history survives account deletion';
end $$;
select set_config('request.jwt.claim.sub','88888888-8888-4888-8888-888888888888',true);
set local role authenticated;
do $$ begin
 assert (select count(*) from public.access_audit)=0, 'Non-admin direct reads hidden';
 begin perform public.access_admin_history(); raise exception 'Non-admin read history';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role anon;
do $$ begin
 begin perform public.access_admin_history(); raise exception 'Guest read history';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
\echo 'Saved administration history, paging, filters, snapshots and access protection passed.'
