-- PetLoop: Health, "Follow a problem" (phase 3b). Apply after 0031.
-- Design: docs/health_issues.md.
--
-- A problem the owner follows over days or weeks ("Limping, right front
-- leg"): a title, when it started, optionally where on the body, open or
-- resolved. Quick log entries (health_observations) can belong to one, and
-- an entry can carry up to four photos.
--
--   * health_issues: one row per problem. Every member of the pet's
--     household reads and writes it (public.health_owns_pet, as 0030
--     redefined it). owner_id is the pet's owner (the 0030 trigger),
--     created_by the account that started it. At most 20 new problems per
--     pet per day.
--   * health_observations.issue_id: the problem an entry belongs to, of the
--     same pet. Deleting the problem keeps its entries (the link is
--     cleared).
--   * health_documents.observation_id: a photo of an entry. The table, the
--     pet-documents bucket, its policies, the household read policy, the
--     own-folder check and the clean-up queue of deleted files are the ones
--     record documents already use, so deleting an entry, a pet or an
--     account removes its photos the same way. A document belongs to a
--     record or to an entry, never both; an entry's are photos only (JPEG,
--     PNG, WebP; the bucket's 5 MB limit), at most four. record_id becomes
--     nullable for that; existing rows are unchanged.
--
-- Additive and idempotent: running it again changes nothing. Nothing is
-- removed or rewritten; no new bucket, no paid feature.
begin;

do $$
begin
  if to_regclass('public.household_members') is null
     or to_regclass('public.storage_cleanup_jobs') is null then
    raise exception 'Run 0015_reliable_operations.sql and 0030_household.sql first.';
  end if;
end $$;

create schema if not exists health_private;
revoke all on schema health_private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- health_issues
-- ---------------------------------------------------------------------------
create table if not exists public.health_issues (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  -- The pet's owner, whoever writes the row (household_private.pet_row_owner).
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  -- Where on the body, in the owner's words ("Right front leg"); optional.
  body_area text check (body_area is null or char_length(body_area) between 1 and 60),
  started_on date not null default current_date,
  status text not null default 'open' check (status in ('open', 'resolved')),
  resolved_on date,
  -- The account that started following it; set by the server.
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint health_issues_resolved_state check (
    (status = 'open' and resolved_on is null)
    or (status = 'resolved' and resolved_on is not null)
  ),
  constraint health_issues_resolved_after_start check (
    resolved_on is null or resolved_on >= started_on
  ),
  -- Lets an entry point at a problem of its own pet only.
  constraint health_issues_id_pet_key unique (id, pet_id)
);

comment on table public.health_issues is
  'Health: a problem the owner follows over time. Entries are health_observations with issue_id. Never a diagnosis.';

create index if not exists health_issues_pet_id_created_at_idx
  on public.health_issues (pet_id, created_at);
create index if not exists health_issues_owner_id_idx on public.health_issues (owner_id);
create index if not exists health_issues_created_by_idx
  on public.health_issues (created_by) where created_by is not null;

-- Who started it, the pet it is about, and the open/resolved pair; at most
-- 20 new problems per pet per day.
create or replace function health_private.issue_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  new.title := btrim(new.title);
  new.body_area := nullif(btrim(coalesce(new.body_area, '')), '');
  if new.status = 'open' then
    new.resolved_on := null;
  elsif new.resolved_on is null then
    new.resolved_on := greatest(current_date, new.started_on);
  end if;
  if tg_op = 'INSERT' then
    if me is not null then
      new.created_by := me;
      -- One counter per pet at a time, so two quick inserts cannot both pass.
      perform pg_advisory_xact_lock(hashtextextended('health_issues:' || new.pet_id::text, 0));
      if (select count(*) from public.health_issues i
          where i.pet_id = new.pet_id and i.created_at > now() - interval '1 day') >= 20 then
        raise exception 'rate_limited' using errcode = 'P0001', hint = 'slow_down';
      end if;
    end if;
    return new;
  end if;
  -- Updates: the pet, who started it and when never change.
  new.pet_id := old.pet_id;
  new.created_by := old.created_by;
  new.created_at := old.created_at;
  return new;
end $$;
revoke all on function health_private.issue_guard() from public, anon, authenticated;

-- "a_" runs first and sets owner_id to the pet's owner (0030).
drop trigger if exists a_household_owner on public.health_issues;
create trigger a_household_owner before insert or update on public.health_issues
  for each row execute function household_private.pet_row_owner();
drop trigger if exists b_health_issue_guard on public.health_issues;
create trigger b_health_issue_guard before insert or update on public.health_issues
  for each row execute function health_private.issue_guard();
drop trigger if exists health_issues_touch_updated_at on public.health_issues;
create trigger health_issues_touch_updated_at
  before update on public.health_issues
  for each row execute procedure public.touch_updated_at();

alter table public.health_issues enable row level security;

revoke all on public.health_issues from anon;
grant select, insert, update, delete on public.health_issues to authenticated;

drop policy if exists "health_issues: household has full access" on public.health_issues;
create policy "health_issues: household has full access" on public.health_issues
  for all to authenticated
  using (public.health_owns_pet(pet_id))
  with check (public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- health_observations: the problem an entry belongs to.
-- ---------------------------------------------------------------------------
alter table public.health_observations add column if not exists issue_id uuid;

comment on column public.health_observations.issue_id is
  'The problem (health_issues) this entry belongs to, of the same pet; cleared when the problem is deleted.';

-- Lets a photo point at an entry of its own pet only.
create unique index if not exists health_observations_id_pet_key
  on public.health_observations (id, pet_id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'health_observations_issue_fk'
      and conrelid = 'public.health_observations'::regclass
  ) then
    alter table public.health_observations
      add constraint health_observations_issue_fk
      foreign key (issue_id, pet_id) references public.health_issues (id, pet_id)
      on delete set null (issue_id);
  end if;
end $$;

create index if not exists health_observations_issue_id_idx
  on public.health_observations (issue_id, observed_at) where issue_id is not null;

-- ---------------------------------------------------------------------------
-- health_documents: a photo of an entry.
-- ---------------------------------------------------------------------------
alter table public.health_documents alter column record_id drop not null;
alter table public.health_documents add column if not exists observation_id uuid;

comment on column public.health_documents.observation_id is
  'The Quick log entry this photo belongs to (instead of record_id). Files: <user id>/<pet id>/<entry id>/<file>.';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'health_documents_observation_fk'
      and conrelid = 'public.health_documents'::regclass
  ) then
    alter table public.health_documents
      add constraint health_documents_observation_fk
      foreign key (observation_id, pet_id) references public.health_observations (id, pet_id)
      on delete cascade;
  end if;
end $$;

alter table public.health_documents drop constraint if exists health_documents_one_parent;
alter table public.health_documents add constraint health_documents_one_parent
  check (num_nonnulls(record_id, observation_id) = 1);

alter table public.health_documents drop constraint if exists health_documents_entry_photos_only;
alter table public.health_documents add constraint health_documents_entry_photos_only
  check (observation_id is null or mime_type in ('image/jpeg', 'image/png', 'image/webp'));

create index if not exists health_documents_observation_id_idx
  on public.health_documents (observation_id) where observation_id is not null;

-- At most four photos per entry.
create or replace function health_private.entry_photo_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.observation_id is null
     or (tg_op = 'UPDATE' and new.observation_id is not distinct from old.observation_id) then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('entry_photos:' || new.observation_id::text, 0));
  if (select count(*) from public.health_documents d
      where d.observation_id = new.observation_id and d.id <> new.id) >= 4 then
    raise exception 'too_many_photos' using errcode = 'P0001', hint = 'too_many_photos';
  end if;
  return new;
end $$;
revoke all on function health_private.entry_photo_limit() from public, anon, authenticated;

drop trigger if exists c_entry_photo_limit on public.health_documents;
create trigger c_entry_photo_limit before insert or update of observation_id on public.health_documents
  for each row execute function health_private.entry_photo_limit();

commit;
