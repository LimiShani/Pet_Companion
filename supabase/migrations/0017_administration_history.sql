-- Durable administration history and cursor-based access to older entries.
-- Apply after 0016. History is never removed by an app action or user deletion.
begin;
drop trigger if exists access_audit_immutable on public.access_audit;
drop trigger if exists access_audit_no_truncate on public.access_audit;
alter table public.access_audit add column if not exists actor_email text;
alter table public.access_audit add column if not exists source_event_id uuid;
create unique index if not exists access_audit_source_idx
  on public.access_audit(source_event_id) where source_event_id is not null;
create index if not exists access_audit_actor_idx on public.access_audit(actor_id,id desc);
create index if not exists access_audit_time_idx on public.access_audit(created_at,id desc);

-- Snapshot the actor's identity rather than depending on their current account.
update public.access_audit a set actor_email=u.email
from auth.users u where a.actor_id=u.id and a.actor_email is null;

create or replace function access_private.audit_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.access_audit(actor_id,actor_email,action,before_value,after_value)
 values(auth.uid(),(select email from auth.users where id=auth.uid()),tg_table_name||':'||tg_op,
  case when tg_op='INSERT' then null else to_jsonb(old) end,
  case when tg_op='DELETE' then null else to_jsonb(new) end);
 update public.access_revision set revision=revision+1 where singleton;
 return null;
end $$;
revoke all on function access_private.audit_change() from public,anon,authenticated;
drop trigger if exists access_change_audit on public.access_capabilities;
create trigger access_change_audit after insert or update or delete on public.access_capabilities
 for each row execute function access_private.audit_change();

-- Bring existing directory review actions into the same browsable history.
insert into public.access_audit(actor_id,actor_email,action,after_value,created_at,source_event_id)
select v.admin_id,u.email,'vet_directory:'||v.action,to_jsonb(v),v.created_at,v.id
from public.vet_admin_actions v left join auth.users u on u.id=v.admin_id
where not exists(select 1 from public.access_audit a where a.source_event_id=v.id);

create or replace function access_private.audit_directory_action()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.access_audit(actor_id,actor_email,action,after_value,created_at,source_event_id)
 values(new.admin_id,(select email from auth.users where id=new.admin_id),
  'vet_directory:'||new.action,to_jsonb(new),new.created_at,new.id);
 return null;
end $$;
revoke all on function access_private.audit_directory_action() from public,anon,authenticated;
drop trigger if exists access_directory_audit on public.vet_admin_actions;
create trigger access_directory_audit after insert on public.vet_admin_actions
 for each row execute function access_private.audit_directory_action();

-- Keep history append-only even if table grants are later broadened.
create or replace function access_private.keep_audit_history()
returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Administration history is append-only' using errcode='42501'; end $$;
revoke all on function access_private.keep_audit_history() from public,anon,authenticated;
drop trigger if exists access_audit_immutable on public.access_audit;
create trigger access_audit_immutable before update or delete on public.access_audit
 for each row execute function access_private.keep_audit_history();
drop trigger if exists access_audit_no_truncate on public.access_audit;
create trigger access_audit_no_truncate before truncate on public.access_audit
 for each statement execute function access_private.keep_audit_history();
revoke insert,update,delete,truncate on public.access_audit from anon,authenticated;

create or replace function access_private.admin_history(
 p_before_id bigint default null,p_limit integer default 50,p_actor text default null,
 p_action text default null,p_from timestamptz default null,p_until timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform access_private.require_admin();
 if p_limit is null or p_limit<1 or p_limit>100 then
  raise exception 'History page size must be between 1 and 100' using errcode='22023';
 end if;
 if p_from is not null and p_until is not null and p_from>=p_until then
  raise exception 'Invalid history date range' using errcode='22023';
 end if;
 with matching as (
  select a.* from public.access_audit a
  where (p_before_id is null or a.id<p_before_id)
   and (nullif(trim(p_actor),'') is null or
    strpos(lower(coalesce(a.actor_email,'')||' '||coalesce(a.actor_id::text,'')),lower(trim(p_actor)))>0)
   and (p_action is null or split_part(a.action,':',1)=p_action)
   and (p_from is null or a.created_at>=p_from)
   and (p_until is null or a.created_at<p_until)
  order by a.id desc limit p_limit+1
 ), page as (select * from matching order by id desc limit p_limit)
 select jsonb_build_object(
  'entries',coalesce((select jsonb_agg(to_jsonb(p) order by p.id desc) from page p),'[]'::jsonb),
  'next_cursor',case when (select count(*) from matching)>p_limit
   then (select min(id) from page) else null end)
 into result;
 return result;
end $$;
revoke all on function access_private.admin_history(bigint,integer,text,text,timestamptz,timestamptz) from public,anon;
grant execute on function access_private.admin_history(bigint,integer,text,text,timestamptz,timestamptz) to authenticated;
create or replace function public.access_admin_history(
 p_before_id bigint default null,p_limit integer default 50,p_actor text default null,
 p_action text default null,p_from timestamptz default null,p_until timestamptz default null)
returns jsonb language sql stable security invoker set search_path='' as $$
 select access_private.admin_history(p_before_id,p_limit,p_actor,p_action,p_from,p_until)
$$;
revoke all on function public.access_admin_history(bigint,integer,text,text,timestamptz,timestamptz) from public,anon;
grant execute on function public.access_admin_history(bigint,integer,text,text,timestamptz,timestamptz) to authenticated;
commit;
