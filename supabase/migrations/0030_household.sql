-- PetLoop: households (phase 1, foundation). Apply after 0029.
-- Design: docs/household.md.
--
-- The people of one home share their pets. A household holds people and
-- pets; every member looks after every pet in it.
--
--   * households, household_members (roles 'owner' and 'carer'),
--     household_invites (a code, one person, seven days).
--   * Every account owns one household: existing accounts get theirs now,
--     with their pets moved in; new accounts get one at sign-up.
--   * pets.household_id. A pet belongs to its household's owner
--     (pets.owner_id stays that account, so deleting it, cascades,
--     clean-up and rewards keep working as before).
--   * The rows of a pet (care logs, reminders, medicines, records,
--     documents, observations, emergency kit, lost card, first days, food
--     settings, health profile) keep owner_id = the pet's owner, set by a
--     trigger whoever writes them. care_logs and health_observations get
--     logged_by: the account that wrote the row.
--   * public.health_owns_pet(pet), the check every pet policy already
--     calls, now means "a member of the pet's household"; the
--     owner_id = auth.uid() conditions are replaced by it. Only the owner
--     deletes or archives a pet; nobody moves one between households yet.
--   * Files stay in their uploader's folder; members read a pet's photo
--     and documents because a row they can see points at the file.
--   * Feature 'household' with household.view and household.manage
--     (invite, remove, rename), for everyone (Standard owners).
--   * Functions: my_households, create/revoke/preview/accept invite,
--     remove_household_member, leave_household, rename_household.
--
-- Additive and idempotent: running it again changes nothing. It patches
-- one condition in public.meetup_save (0028) and in
-- access_private.record_basket_purchase (0015): if either of those files is
-- run again later, run this one again after it.
begin;

do $$
begin
  if to_regclass('public.pet_milestones') is null or to_regclass('public.access_capabilities') is null then
    raise exception 'Run 0014_feature_access.sql and 0029_rewards_foundation.sql first.';
  end if;
end $$;

create schema if not exists household_private;
revoke all on schema household_private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Tables.
-- ---------------------------------------------------------------------------
create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  -- Empty: the app names it after its pets ("Kelly & Soya's household").
  name text not null default '' check (char_length(name) <= 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.households is
  'Household: the people of one home who share their pets. Written only by the household functions.';
create index if not exists households_owner_id_idx on public.households (owner_id, created_at);

create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'carer')),
  invited_by uuid references auth.users(id) on delete set null,
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index if not exists household_members_user_id_idx on public.household_members (user_id);
-- One owner per household.
create unique index if not exists household_members_one_owner
  on public.household_members (household_id) where role = 'owner';

create table if not exists public.household_invites (
  code text primary key check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  check ((accepted_by is null) = (accepted_at is null) or accepted_at is not null)
);
create index if not exists household_invites_household_idx on public.household_invites (household_id);
create index if not exists household_invites_created_by_idx on public.household_invites (created_by, created_at);

-- Failed invite codes, so nobody can try codes until one fits.
create table if not exists household_private.join_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists join_attempts_user_idx on household_private.join_attempts (user_id, at);

alter table public.pets add column if not exists household_id uuid references public.households(id) on delete cascade;
create index if not exists pets_household_id_idx on public.pets (household_id, created_at);

alter table public.care_logs add column if not exists logged_by uuid references auth.users(id) on delete set null;
alter table public.health_observations add column if not exists logged_by uuid references auth.users(id) on delete set null;
comment on column public.care_logs.logged_by is
  'The account that logged it (a member of the pet''s household); owner_id is the pet''s owner.';
comment on column public.health_observations.logged_by is
  'The account that noted it (a member of the pet''s household); owner_id is the pet''s owner.';

drop trigger if exists households_touch_updated_at on public.households;
create trigger households_touch_updated_at
  before update on public.households
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Helpers. Security definer: they read memberships without going through
-- the policies that call them (no recursion), and return only facts about
-- the caller.
-- ---------------------------------------------------------------------------
create or replace function household_private.my_household_ids()
returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(m.household_id), '{}')
  from public.household_members m where m.user_id = (select auth.uid())
$$;

create or replace function public.pet_role(pet uuid)
returns text language sql stable security definer set search_path = '' as $$
  select m.role from public.pets p
  join public.household_members m on m.household_id = p.household_id
  where p.id = pet and m.user_id = (select auth.uid())
$$;
comment on function public.pet_role(uuid) is
  'The signed-in account''s role for a pet: owner, carer, or null when it is not in their household.';

create or replace function public.health_owns_pet(pet uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pets p
    join public.household_members m on m.household_id = p.household_id
    where p.id = pet and m.user_id = (select auth.uid())
  )
$$;
comment on function public.health_owns_pet(uuid) is
  'Pet policies: whether the pet is in a household the signed-in account belongs to (0030).';

-- A vet the caller may pick for a pet: their own, or one already on a
-- shared pet's health profile.
create or replace function public.health_owns_vet(vet uuid)
returns boolean language sql stable set search_path = public as $$
  select exists (select 1 from public.vets v where v.id = vet);
$$;

revoke all on function household_private.my_household_ids() from public, anon;
grant usage on schema household_private to authenticated;
grant execute on function household_private.my_household_ids() to authenticated;
revoke all on function public.pet_role(uuid) from public, anon;
grant execute on function public.pet_role(uuid) to authenticated;
grant execute on function public.health_owns_pet(uuid) to authenticated;
grant execute on function public.health_owns_vet(uuid) to authenticated;

-- The account's own household, made if it has none.
create or replace function household_private.own_household(p_user uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare found_id uuid;
begin
  if p_user is null then return null; end if;
  select h.id into found_id from public.households h
  where h.owner_id = p_user order by h.created_at, h.id limit 1;
  if found_id is null then
    insert into public.households(owner_id) values (p_user) returning id into found_id;
    insert into public.household_members(household_id, user_id, role)
    values (found_id, p_user, 'owner') on conflict do nothing;
  end if;
  return found_id;
end $$;
revoke all on function household_private.own_household(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Every account owns a household: the existing ones now, new ones at
-- sign-up. Their pets move in.
-- ---------------------------------------------------------------------------
do $$ begin perform household_private.own_household(u.id) from auth.users u; end $$;
insert into public.household_members(household_id, user_id, role)
select h.id, h.owner_id, 'owner' from public.households h
on conflict do nothing;
update public.pets p set household_id = household_private.own_household(p.owner_id)
where p.household_id is null;
alter table public.pets alter column household_id set not null;

-- Who logged what so far: always the owner (before any trigger below).
update public.care_logs set logged_by = owner_id
where logged_by is null and exists (select 1 from auth.users u where u.id = owner_id);
update public.health_observations set logged_by = owner_id
where logged_by is null and exists (select 1 from auth.users u where u.id = owner_id);

create or replace function household_private.new_account()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform household_private.own_household(new.id);
  return null;
end $$;
revoke all on function household_private.new_account() from public, anon, authenticated;
drop trigger if exists petloop_household on auth.users;
create trigger petloop_household after insert on auth.users
  for each row execute function household_private.new_account();

-- ---------------------------------------------------------------------------
-- Pets: which household, who owns it, what only the owner changes.
-- ---------------------------------------------------------------------------
create or replace function household_private.pet_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); household_owner uuid;
begin
  if tg_op = 'INSERT' then
    -- A new pet joins the adder's own household unless the row names one
    -- (row level security then checks they belong to it).
    if new.household_id is null then
      new.household_id := household_private.own_household(coalesce(me, new.owner_id));
    end if;
    select h.owner_id into household_owner from public.households h where h.id = new.household_id;
    if household_owner is not null then new.owner_id := household_owner; end if;
    return new;
  end if;
  -- Updates: the household and the owner never change from the app.
  if me is not null then
    new.household_id := old.household_id;
    new.owner_id := old.owner_id;
    if new.archived_at is distinct from old.archived_at and me <> old.owner_id then
      raise exception 'Only the owner archives a pet' using errcode = '42501', hint = 'owner_only';
    end if;
  end if;
  return new;
end $$;
revoke all on function household_private.pet_guard() from public, anon, authenticated;
-- Named to run before the other pets triggers.
drop trigger if exists a_household_pet on public.pets;
create trigger a_household_pet before insert or update on public.pets
  for each row execute function household_private.pet_guard();

-- A row may only point at a file in its writer's own folder (the rule the
-- old photo_path check enforced). Unchanged paths are always fine.
create or replace function household_private.own_file_guard()
returns trigger language plpgsql set search_path = '' as $$
declare me uuid := auth.uid(); new_path text; old_path text;
begin
  if me is null then return new; end if;
  if tg_table_name = 'pets' then
    new_path := new.photo_path;
    if tg_op = 'UPDATE' then old_path := old.photo_path; end if;
  else
    new_path := new.storage_path;
    if tg_op = 'UPDATE' then old_path := old.storage_path; end if;
  end if;
  if new_path is not null and new_path is distinct from old_path
     and split_part(new_path, '/', 1) <> me::text then
    raise exception 'That file is not yours' using errcode = '42501', hint = 'not_your_file';
  end if;
  return new;
end $$;
revoke all on function household_private.own_file_guard() from public, anon, authenticated;
alter table public.pets drop constraint if exists pets_photo_path_owner_check;
drop trigger if exists b_household_own_file on public.pets;
create trigger b_household_own_file before insert or update of photo_path on public.pets
  for each row execute function household_private.own_file_guard();
drop trigger if exists a_household_own_file on public.health_documents;
create trigger a_household_own_file before insert or update of storage_path on public.health_documents
  for each row execute function household_private.own_file_guard();

drop policy if exists "pets: owner has full access" on public.pets;
drop policy if exists "pets: household reads" on public.pets;
drop policy if exists "pets: household adds" on public.pets;
drop policy if exists "pets: household changes" on public.pets;
drop policy if exists "pets: owner removes" on public.pets;
create policy "pets: household reads" on public.pets for select to authenticated
  using (household_id = any ((select household_private.my_household_ids())::uuid[]));
create policy "pets: household adds" on public.pets for insert to authenticated
  with check (household_id = any ((select household_private.my_household_ids())::uuid[]));
create policy "pets: household changes" on public.pets for update to authenticated
  using (household_id = any ((select household_private.my_household_ids())::uuid[]))
  with check (household_id = any ((select household_private.my_household_ids())::uuid[]));
create policy "pets: owner removes" on public.pets for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- A pet's rows: owned by the pet's owner, written by any member.
-- ---------------------------------------------------------------------------
create or replace function household_private.pet_row_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pet_owner uuid;
begin
  select p.owner_id into pet_owner from public.pets p where p.id = new.pet_id;
  if pet_owner is not null then new.owner_id := pet_owner; end if;
  if tg_table_name in ('care_logs', 'health_observations') then
    if tg_op = 'INSERT' then
      if auth.uid() is not null then new.logged_by := auth.uid(); end if;
    elsif new.logged_by is not null then
      -- Who logged it never changes; it only goes (null) with a deleted
      -- account.
      new.logged_by := old.logged_by;
    end if;
  end if;
  return new;
end $$;
revoke all on function household_private.pet_row_owner() from public, anon, authenticated;

do $$
declare t text;
begin
  foreach t in array array[
    'care_logs', 'care_plan_items', 'medications', 'pet_care_settings', 'health_events',
    'health_observations', 'health_documents', 'health_profiles', 'emergency_kit_items',
    'lost_pet_cards', 'pet_first_days'
  ] loop
    -- "a_" runs before the tables' own triggers (schedule_domain_guard
    -- checks that a log and its reminder have the same owner).
    execute format('drop trigger if exists a_household_owner on public.%I', t);
    execute format('create trigger a_household_owner before insert or update on public.%I
      for each row execute function household_private.pet_row_owner()', t);
    execute format('drop policy if exists %I on public.%I', t || ': owner has full access', t);
    execute format('drop policy if exists %I on public.%I', t || ': household has full access', t);
    if t = 'health_profiles' then
      execute format('create policy %I on public.%I for all to authenticated
        using (public.health_owns_pet(pet_id))
        with check (public.health_owns_pet(pet_id)
          and (regular_vet_id is null or public.health_owns_vet(regular_vet_id))
          and (emergency_vet_id is null or public.health_owns_vet(emergency_vet_id)))',
        t || ': household has full access', t);
    else
      execute format('create policy %I on public.%I for all to authenticated
        using (public.health_owns_pet(pet_id)) with check (public.health_owns_pet(pet_id))',
        t || ': household has full access', t);
    end if;
  end loop;
end $$;

-- The 0001 health_events policy was written for every role.
drop policy if exists "health_events: owner has full access" on public.health_events;

-- A shared pet's vet: members read the vets on its health profile; each
-- account still writes only its own list.
drop policy if exists "vets: household reads" on public.vets;
create policy "vets: household reads" on public.vets for select to authenticated using (
  exists (select 1 from public.health_profiles hp
          where hp.regular_vet_id = vets.id or hp.emergency_vet_id = vets.id)
);

-- Rewards are the pet's: every member sees its milestones and rhythm.
drop policy if exists "pet_milestones: owner reads" on public.pet_milestones;
drop policy if exists "pet_milestones: household reads" on public.pet_milestones;
create policy "pet_milestones: household reads" on public.pet_milestones for select to authenticated
  using (public.health_owns_pet(pet_id) and (select public.can_use('rewards.view')));
drop policy if exists "care_rhythm: owner reads" on public.care_rhythm;
drop policy if exists "care_rhythm: household reads" on public.care_rhythm;
create policy "care_rhythm: household reads" on public.care_rhythm for select to authenticated
  using (public.health_owns_pet(pet_id) and (select public.can_use('rewards.view')));

-- ---------------------------------------------------------------------------
-- Files: a member reads a shared pet's photo and documents.
-- ---------------------------------------------------------------------------
drop policy if exists "pet-photos: household reads" on storage.objects;
create policy "pet-photos: household reads" on storage.objects for select to authenticated using (
  bucket_id = 'pet-photos'
  and exists (select 1 from public.pets p where p.photo_path = storage.objects.name)
);
drop policy if exists "pet-documents: household reads" on storage.objects;
create policy "pet-documents: household reads" on storage.objects for select to authenticated using (
  bucket_id = 'pet-documents'
  and exists (select 1 from public.health_documents d where d.storage_path = storage.objects.name)
);

-- A replaced or deleted file is cleaned up by the account whose folder it
-- is in (the uploader), not by the pet's owner, who may not delete it.
create or replace function access_private.queue_deleted_files()
returns trigger language plpgsql security definer set search_path = '' as $$
declare bucket_name text; file_name text; owner uuid; folder text;
begin
 if tg_table_name='health_documents' then bucket_name:='pet-documents';file_name:=old.storage_path;owner:=old.owner_id;
 elsif tg_table_name='community_posts' then bucket_name:='community-photos';file_name:=old.photo_path;owner:=old.author_id;
 elsif tg_table_name='chat_messages' then bucket_name:='community-photos';file_name:=old.photo_path;owner:=old.author_id;
 else
  if tg_op='UPDATE' and new.photo_path is not distinct from old.photo_path then return null; end if;
  bucket_name:='pet-photos';file_name:=old.photo_path;owner:=old.owner_id;
 end if;
 if file_name is not null and file_name<>'' then
  folder:=split_part(file_name,'/',1);
  if bucket_name in ('pet-photos','pet-documents')
     and folder ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
     and exists(select 1 from auth.users u where u.id=folder::uuid) then
   owner:=folder::uuid;
  end if;
  insert into public.storage_cleanup_jobs(owner_id,bucket,path) values(owner,bucket_name,file_name)
  on conflict(bucket,path) do update set not_before=now();
 end if;
 return null;
end $$;

-- ---------------------------------------------------------------------------
-- Server functions that asked "is this the caller's pet?".
-- ---------------------------------------------------------------------------
create or replace function access_private.pet_context()
returns jsonb language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(
   (case when access_private.evaluate(auth.uid(),'pets.view') then to_jsonb(p)
    else jsonb_build_object('id',p.id,'name',p.name,'species',p.species,
      'created_at',p.created_at,'archived_at',p.archived_at) end)
   || jsonb_build_object('household_id',p.household_id,'my_role',m.role)
   order by p.created_at),'[]'::jsonb)
 from public.pets p
 join public.household_members m on m.household_id=p.household_id and m.user_id=auth.uid()
$$;

create or replace function access_private.set_first_days_task(p_pet uuid, p_task text, p_done boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare path public.pet_first_days;
begin
 if not access_private.evaluate(auth.uid(),'firstdays.edit') then raise exception 'Checklist permission required' using errcode='42501'; end if;
 if p_task is null or length(p_task) not between 1 and 100 or p_done is null then raise exception 'Invalid task' using errcode='23514'; end if;
 select * into path from public.pet_first_days where pet_id=p_pet and public.health_owns_pet(p_pet) for update;
 if not found then raise exception 'Checklist not found' using errcode='42501'; end if;
 update public.pet_first_days set done_tasks=case when p_done then
   array(select distinct unnest(array_append(path.done_tasks,p_task))) else array_remove(path.done_tasks,p_task) end
 where pet_id=p_pet returning * into path;
 return to_jsonb(path);
end $$;

create or replace function rewards_private.mark_seen(p_pet uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare changed integer;
begin
  if not access_private.evaluate(auth.uid(), 'rewards.view') then
    raise exception 'Permission required' using errcode = '42501';
  end if;
  update public.pet_milestones set seen_at = now()
  where pet_id = p_pet and public.health_owns_pet(p_pet) and seen_at is null;
  get diagnostics changed = row_count;
  return changed;
end $$;

-- A trusted account has done care itself, on any pet it looks after.
create or replace function rewards_private.account_trusted(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from auth.users u, rewards_private.settings s
    where u.id = p_user and u.created_at <= now() - s.trusted_account_age and u.email_confirmed_at is not null
  ) and exists (
    select 1 from public.care_logs l
    where coalesce(l.logged_by, l.owner_id) = p_user and l.status = 'done'
  )
$$;

-- Care logs: 500 an hour per person who logs, not per pet owner.
do $$
declare def text := pg_get_functiondef('community_private.rate_limit_statement'::regproc);
begin
  if position('select distinct owner_id from new_rows' in def) > 0 then
    def := replace(def, 'select distinct owner_id from new_rows', 'select distinct coalesce(logged_by, owner_id) as who from new_rows');
    def := replace(def, 'where l.owner_id = n.owner_id and l.server_logged_at', 'where coalesce(l.logged_by, l.owner_id) = n.who and l.server_logged_at');
    execute def;
  end if;
end $$;

-- Two long functions with one "the caller's own pet" condition each:
-- rewrite only that condition (idempotent: skipped once done).
do $$
declare def text;
begin
  def := pg_get_functiondef('public.meetup_save'::regproc);
  if position('where id = v_pet and owner_id = me and archived_at is null' in def) > 0 then
    execute replace(def, 'where id = v_pet and owner_id = me and archived_at is null',
      'where id = v_pet and public.health_owns_pet(id) and archived_at is null');
  end if;
  def := pg_get_functiondef('access_private.record_basket_purchase'::regproc);
  if position('where id=product.pet_id and owner_id=owner)' in def) > 0 then
    execute replace(def, 'where id=product.pet_id and owner_id=owner)',
      'where id=product.pet_id and public.health_owns_pet(product.pet_id))');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Households are read here and written only by the functions below.
-- ---------------------------------------------------------------------------
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;
alter table household_private.join_attempts enable row level security;
revoke all on public.households, public.household_members, public.household_invites from anon;
revoke insert, update, delete, truncate on public.households, public.household_members, public.household_invites from authenticated;
grant select on public.households, public.household_members, public.household_invites to authenticated;
revoke all on household_private.join_attempts from public, anon, authenticated;

drop policy if exists "households: members read" on public.households;
create policy "households: members read" on public.households for select to authenticated
  using (id = any ((select household_private.my_household_ids())::uuid[]));
drop policy if exists "household_members: fellow members read" on public.household_members;
create policy "household_members: fellow members read" on public.household_members for select to authenticated
  using (household_id = any ((select household_private.my_household_ids())::uuid[]));
drop policy if exists "household_invites: members read" on public.household_invites;
create policy "household_invites: members read" on public.household_invites for select to authenticated
  using (household_id = any ((select household_private.my_household_ids())::uuid[]));

-- ---------------------------------------------------------------------------
-- Feature and capabilities, allowed for everyone.
-- ---------------------------------------------------------------------------
update public.access_revision set revision = revision + 1
where singleton and not exists (select 1 from public.access_capabilities where id = 'household.view');
insert into public.feature_catalog(id) values ('household') on conflict (id) do nothing;
insert into public.access_capabilities(id, feature_id, requires_view) values
  ('household.view', 'household', null),
  ('household.manage', 'household', 'household.view')
on conflict (id) do nothing;
insert into public.group_capability_rules(group_id, capability, allowed)
select 'acc35500-0000-4000-8000-000000000001', c, true
from unnest(array['household.view', 'household.manage']) c
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- The functions the app calls. Every refusal names its reason in the
-- message (the app maps these words): sign_in, not_available, not_member,
-- owner_only, invite_not_found, invite_expired, invite_used,
-- already_member, household_full, rate_limited, invalid_name.
-- ---------------------------------------------------------------------------
create or replace function household_private.require(p_capability text)
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'sign_in' using errcode = '42501'; end if;
  if not access_private.evaluate(me, p_capability) then
    raise exception 'not_available' using errcode = '42501';
  end if;
  return me;
end $$;
revoke all on function household_private.require(text) from public, anon, authenticated;

create or replace function household_private.role_in(p_household uuid, p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select role from public.household_members where household_id = p_household and user_id = p_user
$$;
revoke all on function household_private.role_in(uuid, uuid) from public, anon, authenticated;

create or replace function household_private.normal_code(p_code text)
returns text language sql immutable set search_path = '' as $$
  select upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'))
$$;
revoke all on function household_private.normal_code(text) from public, anon, authenticated;

-- Up to 10 people per household, invitations still open included.
create or replace function household_private.places_left(p_household uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select 10
    - (select count(*) from public.household_members where household_id = p_household)::integer
    - (select count(*) from public.household_invites
       where household_id = p_household and accepted_at is null and revoked_at is null and expires_at > now())::integer
$$;
revoke all on function household_private.places_left(uuid) from public, anon, authenticated;

create or replace function household_private.display_name(p_user uuid)
returns text language sql stable security definer set search_path = '' as $$
  select coalesce(nullif(btrim(p.display_name), ''), '') from public.profiles p where p.id = p_user
$$;
revoke all on function household_private.display_name(uuid) from public, anon, authenticated;

create or replace function household_private.household_json(p_household uuid, p_me uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', h.id,
    'name', h.name,
    'owner_id', h.owner_id,
    'my_role', household_private.role_in(h.id, p_me),
    'created_at', h.created_at,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', m.user_id, 'name', household_private.display_name(m.user_id),
        'role', m.role, 'joined_at', m.joined_at)
        order by (m.role = 'owner') desc, m.joined_at, m.user_id)
      from public.household_members m where m.household_id = h.id), '[]'::jsonb),
    'invites', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', i.code, 'created_by', i.created_by,
        'created_by_name', household_private.display_name(i.created_by),
        'created_at', i.created_at, 'expires_at', i.expires_at)
        order by i.created_at)
      from public.household_invites i
      where i.household_id = h.id and i.accepted_at is null and i.revoked_at is null and i.expires_at > now()), '[]'::jsonb),
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'species', p.species, 'icon_key', p.icon_key)
        order by p.created_at)
      from public.pets p where p.household_id = h.id and p.archived_at is null), '[]'::jsonb)
  )
  from public.households h where h.id = p_household
$$;
revoke all on function household_private.household_json(uuid, uuid) from public, anon, authenticated;

-- The signed-in account's households: members (with names), open
-- invitations and pets. The account's own household first.
create or replace function public.my_households()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare me uuid := household_private.require('household.view');
begin
  return coalesce((
    select jsonb_agg(household_private.household_json(h.id, me)
      order by (h.owner_id = me) desc, h.created_at, h.id)
    from public.households h
    join public.household_members m on m.household_id = h.id and m.user_id = me
  ), '[]'::jsonb);
end $$;

create or replace function public.create_household_invite(p_household uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  me uuid := household_private.require('household.manage');
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  new_code text;
  invite public.household_invites;
begin
  if household_private.role_in(p_household, me) is null then
    raise exception 'not_member' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('household-invite:' || p_household::text, 0));
  if (select count(*) from public.household_invites
      where created_by = me and created_at > now() - interval '1 day') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  if household_private.places_left(p_household) <= 0 then
    raise exception 'household_full' using errcode = '23514';
  end if;
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * 32)::integer, 1), '')
      into new_code from generate_series(1, 8);
    exit when not exists (select 1 from public.household_invites where code = new_code);
  end loop;
  insert into public.household_invites(code, household_id, created_by)
  values (new_code, p_household, me) returning * into invite;
  return jsonb_build_object('code', invite.code, 'expires_at', invite.expires_at);
end $$;

create or replace function public.revoke_household_invite(p_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := household_private.require('household.manage'); invite public.household_invites;
begin
  select * into invite from public.household_invites where code = household_private.normal_code(p_code);
  if not found or household_private.role_in(invite.household_id, me) is null then
    raise exception 'invite_not_found' using errcode = '42501';
  end if;
  update public.household_invites set revoked_at = now()
  where code = invite.code and accepted_at is null and revoked_at is null;
end $$;

-- What an invitation leads to, or why it does not: the household's name,
-- who invited, its pets and how many people. Nothing else of it.
create or replace function household_private.invite_status(p_code text, p_me uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare invite public.household_invites; normal text := household_private.normal_code(p_code);
begin
  if (select count(*) from household_private.join_attempts
      where user_id = p_me and at > now() - interval '1 hour') >= 20 then
    raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
  end if;
  select * into invite from public.household_invites where code = normal;
  if not found then
    insert into household_private.join_attempts(user_id) values (p_me);
    return jsonb_build_object('status', 'not_found');
  end if;
  return jsonb_build_object(
    'status', case
      when household_private.role_in(invite.household_id, p_me) is not null then 'member'
      when invite.revoked_at is not null then 'revoked'
      when invite.accepted_at is not null then 'used'
      when invite.expires_at <= now() then 'expired'
      else 'open' end,
    'code', invite.code,
    'household_id', invite.household_id,
    'household_name', (select h.name from public.households h where h.id = invite.household_id),
    'inviter_name', household_private.display_name(invite.created_by),
    'member_count', (select count(*) from public.household_members m where m.household_id = invite.household_id),
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object('name', p.name, 'species', p.species, 'icon_key', p.icon_key)
        order by p.created_at)
      from public.pets p where p.household_id = invite.household_id and p.archived_at is null), '[]'::jsonb)
  );
end $$;
revoke all on function household_private.invite_status(text, uuid) from public, anon, authenticated;

create or replace function public.preview_household_invite(p_code text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare me uuid := household_private.require('household.view');
begin
  return household_private.invite_status(p_code, me);
end $$;

create or replace function public.accept_household_invite(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  me uuid := household_private.require('household.view');
  status jsonb;
  invite public.household_invites;
begin
  status := household_private.invite_status(p_code, me);
  case status->>'status'
    when 'not_found' then raise exception 'invite_not_found' using errcode = '42501';
    when 'member' then raise exception 'already_member' using errcode = '23505';
    when 'revoked' then raise exception 'invite_used' using errcode = '42501';
    when 'used' then raise exception 'invite_used' using errcode = '42501';
    when 'expired' then raise exception 'invite_expired' using errcode = '42501';
    else null;
  end case;
  select * into invite from public.household_invites where code = status->>'code' for update;
  if invite.accepted_at is not null or invite.revoked_at is not null then
    raise exception 'invite_used' using errcode = '42501';
  end if;
  update public.household_invites set accepted_by = me, accepted_at = now() where code = invite.code;
  insert into public.household_members(household_id, user_id, role, invited_by)
  values (invite.household_id, me, 'carer', invite.created_by);
  return invite.household_id;
end $$;

create or replace function public.remove_household_member(p_household uuid, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := household_private.require('household.manage');
begin
  if household_private.role_in(p_household, me) is distinct from 'owner' then
    raise exception 'owner_only' using errcode = '42501';
  end if;
  if p_user = me then
    raise exception 'owner_only' using errcode = '42501', detail = 'The owner hands the household over instead';
  end if;
  delete from public.household_members where household_id = p_household and user_id = p_user and role <> 'owner';
  if not found then raise exception 'not_member' using errcode = '42501'; end if;
end $$;

create or replace function public.leave_household(p_household uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := household_private.require('household.view'); my_role text;
begin
  my_role := household_private.role_in(p_household, me);
  if my_role is null then raise exception 'not_member' using errcode = '42501'; end if;
  if my_role = 'owner' then raise exception 'owner_only' using errcode = '42501', detail = 'The owner cannot leave'; end if;
  delete from public.household_members where household_id = p_household and user_id = me;
end $$;

create or replace function public.rename_household(p_household uuid, p_name text)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := household_private.require('household.manage'); clean text := btrim(coalesce(p_name, ''));
begin
  if household_private.role_in(p_household, me) is distinct from 'owner' then
    raise exception 'owner_only' using errcode = '42501';
  end if;
  if char_length(clean) > 40 then raise exception 'invalid_name' using errcode = '23514'; end if;
  update public.households set name = clean where id = p_household;
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.my_households()', 'public.create_household_invite(uuid)', 'public.revoke_household_invite(text)',
    'public.preview_household_invite(text)', 'public.accept_household_invite(text)',
    'public.remove_household_member(uuid, uuid)', 'public.leave_household(uuid)',
    'public.rename_household(uuid, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

commit;
