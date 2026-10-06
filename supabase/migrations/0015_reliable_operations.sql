-- Apply after 0014. Transactional purchases and durable file maintenance.
begin;
create table if not exists public.basket_purchase_operations (
 owner_id uuid not null references auth.users(id) on delete cascade,
 operation_id uuid not null,
 request jsonb not null,
 result jsonb not null,
 created_at timestamptz not null default now(),
 primary key(owner_id,operation_id)
);
alter table public.basket_purchase_operations enable row level security;
revoke all on public.basket_purchase_operations from anon,authenticated;

create or replace function access_private.record_basket_purchase(p_item uuid,p_price numeric,p_on date,p_operation uuid,p_record_expense boolean default true)
returns jsonb language plpgsql security definer set search_path='' as $$
declare owner uuid:=auth.uid(); product public.basket_items; cost public.expenses;
 previous public.basket_purchase_operations; request_value jsonb; result_value jsonb;
begin
 if owner is null or not access_private.evaluate(owner,'basket.edit') then raise exception 'Basket permission required' using errcode='42501'; end if;
 if p_record_expense and not access_private.evaluate(owner,'budget.edit') then raise exception 'Budget permission required' using errcode='42501'; end if;
 if p_price is null or p_price<0 or p_price>1000000 or p_on is null or p_operation is null or p_record_expense is null then
  raise exception 'Invalid purchase' using errcode='23514'; end if;
 request_value:=jsonb_build_object('item',p_item,'price',p_price,'on',p_on,'record_expense',p_record_expense);
 -- Serialize even retries with a different product ID. Account IDs are
 -- part of the lock and primary key; another owner cannot replay a receipt.
 perform pg_advisory_xact_lock(hashtextextended(owner::text||p_operation::text,0));
 select * into previous from public.basket_purchase_operations where owner_id=owner and operation_id=p_operation;
 if found then
  if previous.request<>request_value then raise exception 'Operation ID already used for a different purchase' using errcode='23514'; end if;
  return previous.result;
 end if;
 select * into product from public.basket_items where id=p_item and owner_id=owner for update;
 if not found then raise exception 'Basket product not found' using errcode='42501'; end if;
 if not exists(select 1 from public.pets where id=product.pet_id and owner_id=owner) then raise exception 'Pet not owned' using errcode='42501'; end if;
 update public.basket_items set last_price=p_price,last_bought_on=p_on where id=p_item returning * into product;
 if p_record_expense then
  insert into public.expenses(owner_id,pet_id,amount,currency,category,spent_on,note,source,basket_item_id)
  values(owner,product.pet_id,p_price,product.currency,case when product.kind='food' then 'food' when product.kind in ('litter','consumable') then 'litter_consumables' else 'other' end,
   p_on,product.name,'basket',product.id) returning * into cost;
 end if;
 result_value:=jsonb_build_object('item',to_jsonb(product),'expense',case when p_record_expense then to_jsonb(cost) else null end);
 insert into public.basket_purchase_operations(owner_id,operation_id,request,result) values(owner,p_operation,request_value,result_value);
 return result_value;
end $$;
revoke all on function access_private.record_basket_purchase(uuid,numeric,date,uuid,boolean) from public,anon;
grant execute on function access_private.record_basket_purchase(uuid,numeric,date,uuid,boolean) to authenticated;
create or replace function public.record_basket_purchase(p_item uuid,p_price numeric,p_on date,p_operation uuid,p_record_expense boolean default true)
returns jsonb language sql security invoker set search_path='' as $$
 select access_private.record_basket_purchase(p_item,p_price,p_on,p_operation,p_record_expense)
$$;
revoke all on function public.record_basket_purchase(uuid,numeric,date,uuid,boolean) from public,anon;
grant execute on function public.record_basket_purchase(uuid,numeric,date,uuid,boolean) to authenticated;

-- Atomic task patch prevents two devices replacing each other's arrays.
create or replace function access_private.set_first_days_task(p_pet uuid,p_task text,p_done boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare path public.pet_first_days;
begin
 if not access_private.evaluate(auth.uid(),'firstdays.edit') then raise exception 'Checklist permission required' using errcode='42501'; end if;
 if p_task is null or length(p_task) not between 1 and 100 or p_done is null then raise exception 'Invalid task' using errcode='23514'; end if;
 select * into path from public.pet_first_days where pet_id=p_pet and owner_id=auth.uid() for update;
 if not found then raise exception 'Checklist not found' using errcode='42501'; end if;
 update public.pet_first_days set done_tasks=case when p_done then
   array(select distinct unnest(array_append(path.done_tasks,p_task))) else array_remove(path.done_tasks,p_task) end
 where pet_id=p_pet returning * into path;
 return to_jsonb(path);
end $$;
revoke all on function access_private.set_first_days_task(uuid,text,boolean) from public,anon;
grant execute on function access_private.set_first_days_task(uuid,text,boolean) to authenticated;
create or replace function public.set_first_days_task(p_pet uuid,p_task text,p_done boolean)
returns jsonb language sql security invoker set search_path='' as $$ select access_private.set_first_days_task(p_pet,p_task,p_done) $$;
revoke all on function public.set_first_days_task(uuid,text,boolean) from public,anon;
grant execute on function public.set_first_days_task(uuid,text,boolean) to authenticated;

create table if not exists public.storage_cleanup_jobs (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 bucket text not null check(bucket in ('pet-photos','pet-documents','community-photos')),
 path text not null,
 not_before timestamptz not null default now(),
 attempts integer not null default 0,
 created_at timestamptz not null default now(),
 unique(bucket,path),
 check(path like owner_id::text||'/%')
);
alter table public.storage_cleanup_jobs enable row level security;
revoke all on public.storage_cleanup_jobs from anon,authenticated;
grant select,delete on public.storage_cleanup_jobs to authenticated;
grant all on public.storage_cleanup_jobs to service_role;
create policy cleanup_owner_read on public.storage_cleanup_jobs for select to authenticated using(owner_id=auth.uid());
create policy cleanup_owner_ack on public.storage_cleanup_jobs for delete to authenticated using(owner_id=auth.uid());

create or replace function access_private.file_is_orphan(p_bucket text,p_path text)
returns boolean language sql stable security definer set search_path='' as $$
 select case p_bucket
 when 'pet-photos' then not exists(select 1 from public.pets where photo_path=p_path)
 when 'pet-documents' then not exists(select 1 from public.health_documents where storage_path=p_path)
 when 'community-photos' then not exists(select 1 from public.community_posts where photo_path=p_path)
 else false end
$$;
revoke all on function access_private.file_is_orphan(text,text) from public,anon;
grant execute on function access_private.file_is_orphan(text,text) to authenticated,service_role;
create or replace function public.cleanup_file_is_orphan(p_bucket text,p_path text)
returns boolean language sql stable security invoker set search_path='' as $$
 select (auth.uid() is not null and p_path like auth.uid()::text||'/%' or current_user='service_role')
 and access_private.file_is_orphan(p_bucket,p_path)
$$;
revoke all on function public.cleanup_file_is_orphan(text,text) from public,anon;
grant execute on function public.cleanup_file_is_orphan(text,text) to authenticated,service_role;

create or replace function access_private.queue_storage_cleanup(p_bucket text,p_path text,p_upload boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare job uuid;
begin
 if auth.uid() is null or p_path not like auth.uid()::text||'/%' or p_bucket not in ('pet-photos','pet-documents','community-photos') then
  raise exception 'Invalid cleanup path' using errcode='42501'; end if;
 if not access_private.file_is_orphan(p_bucket,p_path) then raise exception 'File is still in use' using errcode='23514'; end if;
 if p_upload and not access_private.evaluate(auth.uid(),case p_bucket when 'pet-photos' then 'pets.edit' when 'pet-documents' then 'health.records.edit' else 'community.feed.post' end) then
  raise exception 'Upload permission required' using errcode='42501'; end if;
 insert into public.storage_cleanup_jobs(owner_id,bucket,path,not_before) values(auth.uid(),p_bucket,p_path,now()+case when p_upload then interval '1 hour' else interval '0' end)
 on conflict(bucket,path) do update set not_before=excluded.not_before returning id into job;
 return job;
end $$;
revoke all on function access_private.queue_storage_cleanup(text,text,boolean) from public,anon;
grant execute on function access_private.queue_storage_cleanup(text,text,boolean) to authenticated;
create or replace function public.queue_storage_cleanup(p_bucket text,p_path text,p_upload boolean default false)
returns uuid language sql security invoker set search_path='' as $$ select access_private.queue_storage_cleanup(p_bucket,p_path,p_upload) $$;
revoke all on function public.queue_storage_cleanup(text,text,boolean) from public,anon;
grant execute on function public.queue_storage_cleanup(text,text,boolean) to authenticated;

create or replace function access_private.queue_deleted_files()
returns trigger language plpgsql security definer set search_path='' as $$
declare bucket_name text; file_name text; owner uuid;
begin
 if tg_table_name='health_documents' then bucket_name:='pet-documents';file_name:=old.storage_path;owner:=old.owner_id;
 elsif tg_table_name='community_posts' then bucket_name:='community-photos';file_name:=old.photo_path;owner:=old.author_id;
 else
  if tg_op='UPDATE' and new.photo_path is not distinct from old.photo_path then return null; end if;
  bucket_name:='pet-photos';file_name:=old.photo_path;owner:=old.owner_id;
 end if;
 if file_name is not null and file_name<>'' then
  insert into public.storage_cleanup_jobs(owner_id,bucket,path) values(owner,bucket_name,file_name)
  on conflict(bucket,path) do update set not_before=now();
 end if;
 return null;
end $$;
revoke all on function access_private.queue_deleted_files() from public,anon,authenticated;
create trigger cleanup_deleted_document after delete on public.health_documents for each row execute function access_private.queue_deleted_files();
create trigger cleanup_deleted_post after delete on public.community_posts for each row execute function access_private.queue_deleted_files();
create trigger cleanup_pet_photo after delete or update of photo_path on public.pets for each row execute function access_private.queue_deleted_files();

-- Revocation prevents deleting live content, but orphan maintenance stays
-- possible with ownership protection from the original bucket policies.
create policy feature_storage_delete on storage.objects as restrictive for delete to authenticated using(
 (bucket_id='pet-photos' and public.can_use('pets.edit')) or
 (bucket_id='pet-documents' and public.can_use('health.records.edit')) or
 (bucket_id='community-photos' and public.can_use('community.feed.edit')) or
 (name like auth.uid()::text||'/%' and access_private.file_is_orphan(bucket_id,name)) or
 bucket_id not in ('pet-photos','pet-documents','community-photos'));
commit;
