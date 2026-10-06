\set ON_ERROR_STOP on
-- Disposable database only. Every feature permission check in a policy or
-- directory view runs once per statement (a scalar subquery, planned as an
-- InitPlan), never once per row.
do $$
declare
 p record;
 calls int;
 once int;
begin
 for p in
  select schemaname||'.'||tablename||' '||policyname as name,
         coalesce(qual,'')||' '||coalesce(with_check,'') as expr
  from pg_policies where schemaname in ('public','storage')
  union all
  select 'view '||viewname, definition from pg_views
  where schemaname='public' and viewname in ('vet_directory_public','vet_intake_current')
 loop
  calls := (select count(*) from regexp_matches(p.expr,'can_use\(','g'));
  once := (select count(*) from regexp_matches(p.expr,'SELECT\s+(public\.)?can_use\(','gi'));
  assert calls=once, format('%s checks a permission once per row: %s',p.name,p.expr);
 end loop;
end $$;

-- The plan shows the check as an InitPlan on a large table's read.
select set_config('request.jwt.claim.sub','77777777-7777-4777-8777-777777777771',true);
set role authenticated;
do $$
declare plan text;
begin
 -- EXPLAIN returns several lines; any of them naming an InitPlan will do.
 for plan in execute 'explain select count(*) from public.community_post_likes' loop
  if plan ~ 'InitPlan' then return; end if;
 end loop;
 raise exception 'community_post_likes reads do not evaluate permissions once';
end $$;
reset role;
\echo 'Permission checks run once per statement passed.'
