-- Evaluate feature permissions once per query, not once per row.
-- Apply after 0019.
--
-- public.can_use() pins its search_path, so PostgreSQL cannot inline it and
-- called it, with its several lookups, for every row a policy checked:
-- counting 20,000 likes in community_feed took seconds. Wrapped in a scalar
-- subquery, a call with a constant capability becomes an InitPlan that runs
-- once per statement. ALTER POLICY keeps each policy's name, roles and
-- restrictive/permissive mode. Policies already wrapped are left alone, so
-- the file can be applied again.
begin;
do $$
declare
 p record;
 call_pattern constant text := '(public\.)?can_use\(''([a-z.]+)''(::text)?\)';
 wrapped text := '(select public.can_use(''\2''))';
 using_expr text;
 check_expr text;
 sql text;
begin
 for p in
  select schemaname,tablename,policyname,cmd,qual,with_check
  from pg_policies
  where schemaname in ('public','storage')
   and tablename not in ('care_plan_items','care_logs')
   and coalesce(qual,'')||coalesce(with_check,'') ~ call_pattern
   and coalesce(qual,'')||coalesce(with_check,'') !~* 'select\s+(public\.)?can_use\('
 loop
  using_expr := regexp_replace(p.qual,call_pattern,wrapped,'g');
  check_expr := regexp_replace(p.with_check,call_pattern,wrapped,'g');
  sql := format('alter policy %I on %I.%I',p.policyname,p.schemaname,p.tablename);
  if using_expr is not null then sql := sql||format(' using (%s)',using_expr); end if;
  if check_expr is not null then sql := sql||format(' with check (%s)',check_expr); end if;
  execute sql;
 end loop;
end $$;

-- The shared schedule tables pick the capability from each row's domain:
-- one constant check per branch.
do $$
declare
 t text;
 read_rule constant text := 'case when access_domain=''care'' then (select public.can_use(''care.view'')) else (select public.can_use(''health.schedule.view'')) end';
 write_rule constant text := 'case when access_domain=''care'' then (select public.can_use(''care.edit'')) else (select public.can_use(''health.schedule.edit'')) end';
begin
 foreach t in array array['care_plan_items','care_logs'] loop
  execute format('alter policy feature_read on public.%I using (%s)',t,read_rule);
  execute format('alter policy feature_insert on public.%I with check (%s)',t,write_rule);
  execute format('alter policy feature_update on public.%I using (%s) with check (%s)',t,write_rule,write_rule);
  execute format('alter policy feature_delete on public.%I using (%s)',t,write_rule);
 end loop;
end $$;

create or replace view public.vet_directory_public with(security_invoker=true) as
 select * from vet_private.vet_directory_public
 where current_user='service_role' or (select public.can_use('findvet.search'));
create or replace view public.vet_intake_current with(security_invoker=true) as
 select * from vet_private.vet_intake_current
 where current_user='service_role' or (select public.can_use('findvet.search'));
commit;
