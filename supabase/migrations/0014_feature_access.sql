-- PetLoop feature policy. Additive; run after 0013. No application secrets.
begin;
create schema if not exists access_private;
revoke all on schema access_private from public;
grant usage on schema access_private to anon, authenticated, service_role;

create table if not exists public.feature_catalog (
  id text primary key,
  enabled boolean not null default true,
  public_enabled boolean not null default false
);
create table if not exists public.access_capabilities (
  id text primary key,
  feature_id text not null references public.feature_catalog(id),
  requires_view text references public.access_capabilities(id)
);
create table if not exists public.access_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 1 and 80)
);
create table if not exists public.access_group_members (
  group_id uuid not null references public.access_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (group_id, user_id)
);
create index if not exists access_members_user_idx on public.access_group_members(user_id);
create table if not exists public.group_capability_rules (
  group_id uuid not null references public.access_groups(id) on delete cascade,
  capability text not null references public.access_capabilities(id),
  allowed boolean not null,
  primary key (group_id, capability)
);
create table if not exists public.user_capability_rules (
  user_id uuid not null references auth.users(id) on delete cascade,
  capability text not null references public.access_capabilities(id),
  allowed boolean not null,
  primary key (user_id, capability)
);
create table if not exists public.access_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create table if not exists public.access_revision (
  singleton boolean primary key default true check (singleton),
  revision bigint not null default 1
);
create table if not exists public.access_audit (
  id bigint generated always as identity primary key,
  actor_id uuid,
  action text not null,
  before_value jsonb,
  after_value jsonb,
  created_at timestamptz not null default now()
);

insert into public.feature_catalog(id, public_enabled) values
 ('pets', false), ('care', false), ('health', false), ('community', false),
 ('store', false), ('budget', false), ('basket', false), ('firstdays', false),
 ('findvet', true), ('access', false)
on conflict(id) do nothing;

insert into public.access_capabilities(id,feature_id) values
 ('pets.view','pets'), ('care.view','care'),
 ('health.records.view','health'), ('health.schedule.view','health'), ('health.emergency.view','health'),
 ('community.feed.view','community'), ('community.chat.view','community'), ('community.guides.view','community'),
 ('store.deals.view','store'), ('budget.view','budget'), ('basket.view','basket'), ('firstdays.view','firstdays'),
 ('findvet.search','findvet'), ('access.admin','access')
on conflict(id) do nothing;
insert into public.access_capabilities(id,feature_id,requires_view) values
 ('pets.edit','pets','pets.view'), ('care.edit','care','care.view'),
 ('health.records.edit','health','health.records.view'), ('health.records.export','health','health.records.view'),
 ('health.schedule.edit','health','health.schedule.view'),
 ('health.emergency.edit','health','health.emergency.view'), ('health.emergency.export','health','health.emergency.view'),
 ('community.feed.post','community','community.feed.view'), ('community.feed.edit','community','community.feed.view'),
 ('community.chat.send','community','community.chat.view'),
 ('store.deals.share','store','store.deals.view'), ('store.deals.edit','store','store.deals.view'),
 ('budget.edit','budget','budget.view'), ('basket.edit','basket','basket.view'),
 ('firstdays.edit','firstdays','firstdays.view'), ('findvet.admin','findvet','findvet.search')
on conflict(id) do nothing;
insert into public.access_revision(singleton) values(true) on conflict do nothing;
insert into public.access_groups(id,name) values('acc35500-0000-4000-8000-000000000001','Standard owners') on conflict do nothing;
insert into public.group_capability_rules(group_id,capability,allowed)
 select 'acc35500-0000-4000-8000-000000000001',id,true from public.access_capabilities
 where id not in ('access.admin','findvet.admin') on conflict do nothing;
insert into public.access_group_members(group_id,user_id)
 select 'acc35500-0000-4000-8000-000000000001',id from auth.users on conflict do nothing;
-- Existing directory reviewers keep review access; this never makes them
-- administrators of permissions.
insert into public.user_capability_rules(user_id,capability,allowed)
 select user_id,'findvet.admin',true from public.vet_directory_admins on conflict do nothing;

create or replace function access_private.evaluate(p_user uuid,p_capability text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare feature public.feature_catalog; prerequisite text; rule boolean;
begin
 select f.* into feature from public.feature_catalog f join public.access_capabilities c on c.feature_id=f.id where c.id=p_capability;
 if not found or not feature.enabled then return false; end if;
 if p_capability='access.admin' then
   return p_user is not null and exists(select 1 from public.access_admins where user_id=p_user);
 end if;
 if p_user is null then return p_capability='findvet.search' and feature.public_enabled; end if;
 if p_capability='findvet.admin' and not exists(select 1 from public.vet_directory_admins where user_id=p_user) then return false; end if;
 select requires_view into prerequisite from public.access_capabilities where id=p_capability;
 if prerequisite is not null and not access_private.evaluate(p_user,prerequisite) then return false; end if;
 select allowed into rule from public.user_capability_rules where user_id=p_user and capability=p_capability;
 if found then return rule; end if;
 if exists(select 1 from public.group_capability_rules r join public.access_group_members m using(group_id)
   where m.user_id=p_user and r.capability=p_capability and not r.allowed) then return false; end if;
 return exists(select 1 from public.group_capability_rules r join public.access_group_members m using(group_id)
   where m.user_id=p_user and r.capability=p_capability and r.allowed);
end $$;
revoke all on function access_private.evaluate(uuid,text) from public,anon,authenticated;

create or replace function access_private.can_use(p_capability text)
returns boolean language sql stable security definer set search_path = '' as $$
 select access_private.evaluate(auth.uid(),p_capability)
$$;
revoke all on function access_private.can_use(text) from public;
grant execute on function access_private.can_use(text) to anon,authenticated,service_role;
create or replace function public.can_use(p_capability text)
returns boolean language sql stable security invoker set search_path = '' as $$
 select access_private.can_use(p_capability)
$$;
revoke all on function public.can_use(text) from public;
grant execute on function public.can_use(text) to anon,authenticated,service_role;

create or replace function access_private.reason(p_user uuid,p_capability text)
returns text language plpgsql stable security definer set search_path = '' as $$
declare feature public.feature_catalog; prerequisite text; rule boolean;
begin
 select f.* into feature from public.feature_catalog f join public.access_capabilities c on c.feature_id=f.id where c.id=p_capability;
 if not found then return 'Unknown capability'; end if;
 if not feature.enabled then return 'Feature disabled'; end if;
 if p_capability='access.admin' then return case when access_private.evaluate(p_user,p_capability) then 'Administrator' else 'Administrator role required' end; end if;
 if p_user is null then return 'Public policy'; end if;
 if p_capability='findvet.admin' and not exists(select 1 from public.vet_directory_admins where user_id=p_user) then return 'Directory reviewer role required'; end if;
 select requires_view into prerequisite from public.access_capabilities where id=p_capability;
 if prerequisite is not null and not access_private.evaluate(p_user,prerequisite) then return 'View access required'; end if;
 select allowed into rule from public.user_capability_rules where user_id=p_user and capability=p_capability;
 if found then return 'Individual override'; end if;
 if exists(select 1 from public.group_capability_rules r join public.access_group_members m using(group_id)
   where m.user_id=p_user and r.capability=p_capability and not r.allowed) then return 'Group deny'; end if;
 return case when access_private.evaluate(p_user,p_capability) then 'Group allow' else 'No grant' end;
end $$;
revoke all on function access_private.reason(uuid,text) from public,anon,authenticated;

create or replace function access_private.snapshot(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
 select jsonb_build_object('user_id',p_user,'revision',(select revision from public.access_revision where singleton),
 'allowed',coalesce((select jsonb_agg(id order by id) from public.access_capabilities where access_private.evaluate(p_user,id)),'[]'::jsonb),
 'enabled',(select jsonb_object_agg(id,enabled) from public.feature_catalog),
 'reasons',(select jsonb_object_agg(id,access_private.reason(p_user,id)) from public.access_capabilities))
$$;
revoke all on function access_private.snapshot(uuid) from public,anon,authenticated;
create or replace function access_private.get_my_access()
returns jsonb language sql stable security definer set search_path = '' as $$ select access_private.snapshot(auth.uid()) $$;
revoke all on function access_private.get_my_access() from public;
grant execute on function access_private.get_my_access() to anon,authenticated,service_role;
create or replace function public.get_my_access()
returns jsonb language sql stable security invoker set search_path = '' as $$ select access_private.get_my_access() $$;
revoke all on function public.get_my_access() from public;
grant execute on function public.get_my_access() to anon,authenticated,service_role;

create or replace function access_private.require_admin()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
 if not access_private.evaluate(auth.uid(),'access.admin') then raise exception 'Permission administrator required' using errcode='42501'; end if;
end $$;
revoke all on function access_private.require_admin() from public,anon,authenticated;

create or replace function access_private.admin_state()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
 perform access_private.require_admin();
 return jsonb_build_object(
 'users',coalesce((select jsonb_agg(jsonb_build_object('id',id,'email',email) order by email) from auth.users),'[]'::jsonb),
 'groups',coalesce((select jsonb_agg(to_jsonb(g) order by name) from public.access_groups g),'[]'::jsonb),
 'members',coalesce((select jsonb_agg(to_jsonb(m)) from public.access_group_members m),'[]'::jsonb),
 'group_rules',coalesce((select jsonb_agg(to_jsonb(r)) from public.group_capability_rules r),'[]'::jsonb),
 'user_rules',coalesce((select jsonb_agg(to_jsonb(r)) from public.user_capability_rules r),'[]'::jsonb),
 'features',coalesce((select jsonb_agg(to_jsonb(f) order by id) from public.feature_catalog f),'[]'::jsonb),
 'audit',coalesce((select jsonb_agg(to_jsonb(a)) from (select * from public.access_audit order by id desc limit 100) a),'[]'::jsonb));
end $$;
create or replace function access_private.admin_preview(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin perform access_private.require_admin(); return access_private.snapshot(p_user); end $$;
create or replace function access_private.admin_change(p_action text,p_values jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare grp uuid; requested_capability text;
begin
 perform access_private.require_admin();
 case p_action
 when 'feature' then
   if p_values->>'id'='access' then raise exception 'Permission administration cannot be disabled'; end if;
   update public.feature_catalog set enabled=(p_values->>'enabled')::boolean,
    public_enabled=coalesce((p_values->>'public_enabled')::boolean,public_enabled) where id=p_values->>'id';
   if not found then raise exception 'Unknown feature'; end if;
 when 'group' then
   grp:=coalesce(nullif(p_values->>'id','')::uuid,gen_random_uuid());
   insert into public.access_groups(id,name) values(grp,p_values->>'name') on conflict(id) do update set name=excluded.name;
 when 'member' then
   if (p_values->>'member')::boolean then
     insert into public.access_group_members(group_id,user_id) values((p_values->>'group_id')::uuid,(p_values->>'user_id')::uuid) on conflict do nothing;
   else delete from public.access_group_members where group_id=(p_values->>'group_id')::uuid and user_id=(p_values->>'user_id')::uuid; end if;
 when 'user_rule' then
   requested_capability:=p_values->>'capability';
   if requested_capability='access.admin' then raise exception 'Administrator membership is provisioned separately'; end if;
   if p_values->>'allowed' is null then
     delete from public.user_capability_rules where user_id=(p_values->>'user_id')::uuid and capability=requested_capability;
   else insert into public.user_capability_rules(user_id,capability,allowed) values((p_values->>'user_id')::uuid,requested_capability,(p_values->>'allowed')::boolean)
     on conflict(user_id,capability) do update set allowed=excluded.allowed; end if;
 when 'group_rule' then
   requested_capability:=p_values->>'capability';
   if requested_capability='access.admin' then raise exception 'Administrator membership is provisioned separately'; end if;
   if p_values->>'allowed' is null then
     delete from public.group_capability_rules where group_id=(p_values->>'group_id')::uuid and capability=requested_capability;
   else insert into public.group_capability_rules(group_id,capability,allowed) values((p_values->>'group_id')::uuid,requested_capability,(p_values->>'allowed')::boolean)
     on conflict(group_id,capability) do update set allowed=excluded.allowed; end if;
 else raise exception 'Unknown permission action'; end case;
end $$;
revoke all on function access_private.admin_state(),access_private.admin_preview(uuid),access_private.admin_change(text,jsonb) from public,anon;
grant execute on function access_private.admin_state(),access_private.admin_preview(uuid),access_private.admin_change(text,jsonb) to authenticated;
create or replace function public.access_admin_state() returns jsonb language sql stable security invoker set search_path='' as $$ select access_private.admin_state() $$;
create or replace function public.access_admin_preview(p_user uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select access_private.admin_preview(p_user) $$;
create or replace function public.access_admin_change(p_action text,p_values jsonb) returns void language sql security invoker set search_path='' as $$ select access_private.admin_change(p_action,p_values) $$;
revoke all on function public.access_admin_state(),public.access_admin_preview(uuid),public.access_admin_change(text,jsonb) from public,anon;
grant execute on function public.access_admin_state(),public.access_admin_preview(uuid),public.access_admin_change(text,jsonb) to authenticated;

create or replace function access_private.audit_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.access_audit(actor_id,action,before_value,after_value) values(auth.uid(),tg_table_name||':'||tg_op,
  case when tg_op='INSERT' then null else to_jsonb(old) end,case when tg_op='DELETE' then null else to_jsonb(new) end);
 update public.access_revision set revision=revision+1 where singleton;
 return null;
end $$;
create or replace function access_private.add_standard_member()
returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.access_group_members(group_id,user_id) values('acc35500-0000-4000-8000-000000000001',new.id) on conflict do nothing; return new; end $$;
drop trigger if exists petloop_standard_member on auth.users;
create trigger petloop_standard_member after insert on auth.users for each row execute function access_private.add_standard_member();
revoke all on function access_private.audit_change(),access_private.add_standard_member() from public,anon,authenticated;

do $$ declare t text; begin
 foreach t in array array['feature_catalog','access_capabilities','access_groups','access_group_members','group_capability_rules','user_capability_rules','access_admins','access_revision','access_audit'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('drop policy if exists access_admin_read on public.%I',t);
  execute format('create policy access_admin_read on public.%I for select to authenticated using(public.can_use(''access.admin''))',t);
  if t not in ('access_capabilities','access_revision','access_audit') then
   execute format('drop trigger if exists access_change_audit on public.%I',t);
   execute format('create trigger access_change_audit after insert or update or delete on public.%I for each row execute function access_private.audit_change()',t);
  end if;
 end loop;
end $$;

-- Shared schedule domain belongs to Care or Health, never to arbitrary
-- client metadata. Classification is derived, backfilled and immutable.
alter table public.care_plan_items add column if not exists access_domain text;
update public.care_plan_items set access_domain=case when medication_id is null and kind in ('feeding','walk') then 'care' else 'health' end where access_domain is null;
alter table public.care_plan_items alter column access_domain set not null;
alter table public.care_logs add column if not exists access_domain text;
update public.care_logs l set access_domain=coalesce((select p.access_domain from public.care_plan_items p where p.id=l.plan_item_id),
 case when l.medication_id is null and l.kind in ('feeding','walk') then 'care' else 'health' end) where l.access_domain is null;
alter table public.care_logs alter column access_domain set not null;
create or replace function access_private.schedule_domain()
returns trigger language plpgsql security definer set search_path='' as $$
declare domain text; plan public.care_plan_items;
begin
 if tg_table_name='care_plan_items' then
  domain:=case when new.kind in ('feeding','walk') and new.medication_id is null then 'care' else 'health' end;
 else
  if new.plan_item_id is not null then
   select * into plan from public.care_plan_items where id=new.plan_item_id;
   if not found or plan.pet_id<>new.pet_id or plan.owner_id<>new.owner_id then raise exception 'Invalid plan relationship' using errcode='23514'; end if;
   domain:=plan.access_domain;
  elsif tg_op='UPDATE' and old.plan_item_id is not null and new.medication_id is not distinct from old.medication_id
    and new.kind is not distinct from old.kind and new.pet_id=old.pet_id and new.owner_id=old.owner_id then
   -- ON DELETE SET NULL preserves the original log's classification.
   domain:=old.access_domain;
  else domain:=case when new.medication_id is null and new.kind in ('feeding','walk') then 'care' else 'health' end; end if;
 end if;
 if new.medication_id is not null and not exists(select 1 from public.medications where id=new.medication_id and pet_id=new.pet_id and owner_id=new.owner_id) then
  raise exception 'Invalid medication relationship' using errcode='23514';
 end if;
 if tg_op='UPDATE' and old.access_domain<>domain then raise exception 'Schedule domain cannot be changed' using errcode='42501'; end if;
 new.access_domain:=domain; return new;
end $$;
revoke all on function access_private.schedule_domain() from public,anon,authenticated;
drop trigger if exists schedule_domain_guard on public.care_plan_items;
create trigger schedule_domain_guard before insert or update on public.care_plan_items for each row execute function access_private.schedule_domain();
drop trigger if exists schedule_domain_guard on public.care_logs;
create trigger schedule_domain_guard before insert or update on public.care_logs for each row execute function access_private.schedule_domain();

-- Restrictive policy checks combine with all existing ownership policies
-- using AND. Pets SELECT is foundational identity; only its management UI
-- and writes are optional. Profiles remain shared account identity.
do $$ declare row record; read_expr text; write_expr text; begin
 for row in select * from (values
  ('pets','true','public.can_use(''pets.edit'')'),
  ('health_events','public.can_use(''health.records.view'')','public.can_use(''health.records.edit'')'),
  ('health_documents','public.can_use(''health.records.view'')','public.can_use(''health.records.edit'')'),
  ('health_observations','public.can_use(''health.records.view'')','public.can_use(''health.records.edit'')'),
  ('medications','public.can_use(''health.schedule.view'')','public.can_use(''health.schedule.edit'')'),
  ('vets','public.can_use(''health.emergency.view'')','public.can_use(''health.emergency.edit'')'),
  ('health_profiles','public.can_use(''health.emergency.view'')','public.can_use(''health.emergency.edit'')'),
  ('emergency_kit_items','public.can_use(''health.emergency.view'')','public.can_use(''health.emergency.edit'')'),
  ('lost_pet_cards','public.can_use(''health.emergency.view'')','public.can_use(''health.emergency.edit'')'),
  ('pet_care_settings','public.can_use(''care.view'')','public.can_use(''care.edit'')'),
  ('care_plan_items','public.can_use(case when access_domain=''care'' then ''care.view'' else ''health.schedule.view'' end)','public.can_use(case when access_domain=''care'' then ''care.edit'' else ''health.schedule.edit'' end)'),
  ('care_logs','public.can_use(case when access_domain=''care'' then ''care.view'' else ''health.schedule.view'' end)','public.can_use(case when access_domain=''care'' then ''care.edit'' else ''health.schedule.edit'' end)'),
  ('community_posts','public.can_use(''community.feed.view'')','public.can_use(''community.feed.post'')'),
  ('community_post_likes','public.can_use(''community.feed.view'')','public.can_use(''community.feed.post'')'),
  ('community_comments','public.can_use(''community.feed.view'')','public.can_use(''community.feed.post'')'),
  ('community_reports','public.can_use(''community.feed.view'')','public.can_use(''community.feed.post'')'),
  ('chat_channels','public.can_use(''community.chat.view'')','false'),
  ('chat_messages','public.can_use(''community.chat.view'')','public.can_use(''community.chat.send'')'),
  ('store_deals','public.can_use(''store.deals.view'')','public.can_use(''store.deals.share'')'),
  ('store_favourites','public.can_use(''store.deals.view'')','public.can_use(''store.deals.view'')'),
  ('store_reports','public.can_use(''store.deals.view'')','public.can_use(''store.deals.view'')'),
  ('expenses','public.can_use(''budget.view'')','public.can_use(''budget.edit'')'),
  ('basket_items','public.can_use(''basket.view'')','public.can_use(''basket.edit'')'),
  ('pet_first_days','public.can_use(''firstdays.view'')','public.can_use(''firstdays.edit'')')
 ) as rules(tbl,read_rule,write_rule) loop
  execute format('drop policy if exists feature_read on public.%I',row.tbl);
  execute format('drop policy if exists feature_insert on public.%I',row.tbl);
  execute format('drop policy if exists feature_update on public.%I',row.tbl);
  execute format('drop policy if exists feature_delete on public.%I',row.tbl);
  execute format('create policy feature_read on public.%I as restrictive for select to authenticated using(%s)',row.tbl,row.read_rule);
  execute format('create policy feature_insert on public.%I as restrictive for insert to authenticated with check(%s)',row.tbl,row.write_rule);
  execute format('create policy feature_update on public.%I as restrictive for update to authenticated using(%s) with check(%s)',row.tbl,row.write_rule,row.write_rule);
  execute format('create policy feature_delete on public.%I as restrictive for delete to authenticated using(%s)',row.tbl,row.write_rule);
 end loop;
end $$;

-- Feature access is additional to the private buckets' ownership policy.
drop policy if exists feature_storage_read on storage.objects;
create policy feature_storage_read on storage.objects as restrictive for select to authenticated using(
 bucket_id not in ('pet-documents','community-photos') or
 (bucket_id='pet-documents' and public.can_use('health.records.view')) or
 (bucket_id='community-photos' and public.can_use('community.feed.view')));
drop policy if exists feature_storage_upload on storage.objects;
create policy feature_storage_upload on storage.objects as restrictive for insert to authenticated with check(
 (bucket_id='pet-photos' and public.can_use('pets.edit')) or
 (bucket_id='pet-documents' and public.can_use('health.records.edit')) or
 (bucket_id='community-photos' and public.can_use('community.feed.post')) or
 bucket_id not in ('pet-photos','pet-documents','community-photos'));
drop policy if exists feature_storage_update on storage.objects;
create policy feature_storage_update on storage.objects as restrictive for update to authenticated using(
 (bucket_id='pet-photos' and public.can_use('pets.edit')) or
 (bucket_id='pet-documents' and public.can_use('health.records.edit')) or
 (bucket_id='community-photos' and public.can_use('community.feed.post')) or
 bucket_id not in ('pet-photos','pet-documents','community-photos')) with check(
 (bucket_id='pet-photos' and public.can_use('pets.edit')) or
 (bucket_id='pet-documents' and public.can_use('health.records.edit')) or
 (bucket_id='community-photos' and public.can_use('community.feed.post')) or
 bucket_id not in ('pet-photos','pet-documents','community-photos'));
-- DELETE keeps ownership protection but allows cleanup after revocation.

-- Caller-rights directory views also filter service-only private views.
create or replace view public.vet_directory_public with(security_invoker=true) as
 select * from vet_private.vet_directory_public where public.can_use('findvet.search');
create or replace view public.vet_intake_current with(security_invoker=true) as
 select * from vet_private.vet_intake_current where public.can_use('findvet.search');

-- The existing reviewer checks resolve through vet_is_admin. Both the
-- reviewer role and the feature grant are now required.
create or replace function vet_private.vet_is_admin()
returns boolean language sql stable security definer set search_path='' as $$
 select access_private.evaluate(auth.uid(),'findvet.admin')
 and exists(select 1 from public.vet_directory_admins where user_id=auth.uid())
$$;
revoke all on function vet_private.vet_is_admin() from public,anon;
grant execute on function vet_private.vet_is_admin() to authenticated,service_role;

-- Posting and modifying content are distinct permissions.
drop policy feature_update on public.community_posts;
drop policy feature_delete on public.community_posts;
create policy feature_update on public.community_posts as restrictive for update to authenticated
 using(public.can_use('community.feed.edit')) with check(public.can_use('community.feed.edit'));
create policy feature_delete on public.community_posts as restrictive for delete to authenticated using(public.can_use('community.feed.edit'));
drop policy feature_update on public.community_comments;
drop policy feature_delete on public.community_comments;
create policy feature_update on public.community_comments as restrictive for update to authenticated
 using(public.can_use('community.feed.edit')) with check(public.can_use('community.feed.edit'));
create policy feature_delete on public.community_comments as restrictive for delete to authenticated using(public.can_use('community.feed.edit'));
drop policy feature_update on public.store_deals;
drop policy feature_delete on public.store_deals;
create policy feature_update on public.store_deals as restrictive for update to authenticated
 using(public.can_use('store.deals.edit')) with check(public.can_use('store.deals.edit'));
create policy feature_delete on public.store_deals as restrictive for delete to authenticated using(public.can_use('store.deals.edit'));

commit;
