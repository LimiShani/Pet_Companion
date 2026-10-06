-- Directory reporter APIs also obey the feature kill switch. Guard the
-- private implementations, since their public wrappers deliberately run
-- with the caller's privileges.
begin;
do $migration$
declare signature regprocedure; definition text;
begin
 foreach signature in array array[
  'vet_private.vet_report_intake(uuid,text,text[],integer)'::regprocedure,
  'vet_private.vet_confirm_case(uuid,text,boolean,integer)'::regprocedure
 ] loop
  definition:=pg_get_functiondef(signature);
  definition:=regexp_replace(definition,'(?i)\mbegin\M',
   E'begin\n  if not public.can_use(''findvet.search'') then raise exception ''Feature unavailable'' using errcode=''42501''; end if;');
  execute definition;
 end loop;
end $migration$;
create or replace function vet_private.vet_case_status(p_reference text)
returns table (facility_id uuid, accepted boolean, confirmed_at timestamptz, expires_at timestamptz)
language sql stable security definer set search_path = '' as $$
 select c.facility_id,c.accepted,c.confirmed_at,c.expires_at
 from public.vet_case_confirmations c
 where public.can_use('findvet.search') and c.reference=btrim(coalesce(p_reference,''))
   and char_length(btrim(coalesce(p_reference,'')))>=8 and c.expires_at>now()
 order by c.confirmed_at desc limit 1
$$;
-- Pet identity is foundational. Disabling the profile section must not
-- remove the IDs/names/species required by Care, Basket and Health.
-- Full profile fields remain protected by pets.view.
create or replace function access_private.pet_context()
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(case when access_private.evaluate(auth.uid(),'pets.view') then to_jsonb(p)
  else jsonb_build_object('id',p.id,'name',p.name,'species',p.species,
    'created_at',p.created_at,'archived_at',p.archived_at) end order by p.created_at),'[]'::jsonb)
 from public.pets p where p.owner_id=auth.uid()
$$;
revoke all on function access_private.pet_context() from public,anon;
grant execute on function access_private.pet_context() to authenticated;
create or replace function public.get_my_pet_context()
returns jsonb language sql stable security invoker set search_path='' as $$ select access_private.pet_context() $$;
revoke all on function public.get_my_pet_context() from public,anon;
grant execute on function public.get_my_pet_context() to authenticated;
commit;
