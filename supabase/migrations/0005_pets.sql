-- PetLoop: pets for the add-a-pet flow.
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 (public.pets and the
-- private `pet-photos` bucket). Safe to run more than once.
--
-- Purely additive: no column, row or file is removed or rewritten. It adds to
-- public.pets what the app now asks about a pet:
--   sex, neutered            an answer, or null while not answered
--                            ('unknown' is the answer "Not sure")
--   birth_date_approx        "about 3 years" is stored as a birthday that is
--                            marked approximate, so the age keeps counting
--   icon_key                 the icon from the app's bank and its background,
--                            e.g. 'dog_floppy:sage' (a photo wins over it)
--   archived_at              hidden from the app, nothing lost, restorable
--   reminder_snoozed_until   "Not now" on the essentials reminder, so that it
--                            follows the account to every device
-- and it widens weight_kg so that a 35 g bird is not rounded away.
--
-- Whether a pet's essentials are complete is worked out in the app (age and
-- weight from this table; the vet's phone, allergies and conditions from the
-- Health tables) and deliberately not stored, so it cannot go stale.

begin;

-- ---------------------------------------------------------------------------
-- New columns.
-- ---------------------------------------------------------------------------
alter table public.pets
  add column if not exists sex text,
  add column if not exists neutered text,
  add column if not exists birth_date_approx boolean not null default false,
  add column if not exists icon_key text,
  add column if not exists archived_at timestamptz,
  add column if not exists reminder_snoozed_until timestamptz;

comment on column public.pets.sex is
  'male, female or unknown ("Not sure"); null while not answered.';
comment on column public.pets.neutered is
  'yes, no or unknown ("Not sure"); null while not answered.';
comment on column public.pets.birth_date_approx is
  'True when birth_date was worked out from an approximate age ("about 3 years").';
comment on column public.pets.icon_key is
  'Icon from the app''s bank and its background, e.g. dog_floppy:sage. photo_path wins when both are set.';
comment on column public.pets.archived_at is
  'Set when the owner archived the pet: hidden in the app, everything kept.';
comment on column public.pets.reminder_snoozed_until is
  'The essentials reminder is hidden until this moment ("Not now", 7 days).';

-- ---------------------------------------------------------------------------
-- Weight: numeric(5, 2) rounds a 35 g budgie (0.035 kg) to 0.04. Three
-- decimals keep the gram; the existing "weight_kg > 0" check stays.
-- ---------------------------------------------------------------------------
alter table public.pets alter column weight_kg type numeric(7, 3);

-- ---------------------------------------------------------------------------
-- An insert that leaves the owner out can only ever be the caller's own.
-- (Row level security below still refuses any other owner.)
-- ---------------------------------------------------------------------------
alter table public.pets alter column owner_id set default auth.uid();

-- ---------------------------------------------------------------------------
-- Checks. Dropped and added again so the file can be run more than once.
-- ---------------------------------------------------------------------------
alter table public.pets drop constraint if exists pets_sex_check;
alter table public.pets add constraint pets_sex_check
  check (sex is null or sex in ('male', 'female', 'unknown'));

alter table public.pets drop constraint if exists pets_neutered_check;
alter table public.pets add constraint pets_neutered_check
  check (neutered is null or neutered in ('yes', 'no', 'unknown'));

-- An approximate birthday is still a birthday.
alter table public.pets drop constraint if exists pets_birth_date_approx_check;
alter table public.pets add constraint pets_birth_date_approx_check
  check (not birth_date_approx or birth_date is not null);

alter table public.pets drop constraint if exists pets_icon_key_check;
alter table public.pets add constraint pets_icon_key_check
  check (icon_key is null or icon_key ~ '^[a-z0-9_]{1,40}(:[a-z0-9_]{1,20})?$');

-- A pet's photo lives in its owner's folder of the pet-photos bucket
-- (<owner id>/<pet id>/<file>), so a row can never point at someone else's
-- file. "not valid": rows written before this file are left as they are; the
-- rule applies to every insert and update from now on.
alter table public.pets drop constraint if exists pets_photo_path_owner_check;
alter table public.pets add constraint pets_photo_path_owner_check
  check (photo_path is null or photo_path like owner_id::text || '/%') not valid;

-- The owner's pets, oldest first: the one query the app makes.
create index if not exists pets_owner_id_created_at_idx on public.pets (owner_id, created_at);

-- ---------------------------------------------------------------------------
-- Row level security. Already on since 0001; stated again so this file stands
-- on its own. One policy: a signed-in user sees and changes only their own
-- pets, new columns included. Replaced inside this transaction, so there is
-- no moment without it.
-- ---------------------------------------------------------------------------
alter table public.pets enable row level security;

drop policy if exists "pets: owner has full access" on public.pets;
create policy "pets: owner has full access" on public.pets
  for all
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

commit;

-- ---------------------------------------------------------------------------
-- Nothing changes in storage. The private `pet-photos` bucket and its four
-- policies from 0001 already keep every file in its owner's folder; the app
-- stores one cropped 512 px JPEG per pet as
--   <owner id>/<pet id>/avatar_<time>.jpg
-- and shows it through a short-lived signed link.
--
-- Deleting a pet: the app removes the pet's files first, then the row. Rows
-- of other tables that reference public.pets with "on delete cascade" (the
-- health tables) go with it.
-- ---------------------------------------------------------------------------
