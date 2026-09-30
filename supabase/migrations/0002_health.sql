-- Pet Companion: the Health tab (records, documents, vets, the health profile,
-- medicines, the care plan, the dose log and the observation journal).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 (public.pets,
-- public.health_events, public.touch_updated_at). Safe to run more than once.
--
-- What it does:
--   health_events        reused from 0001 for health records; gains four
--                        nullable columns and three more kinds. No row changes.
--   vets                 the owner's vets, saved once and shared by their pets
--   health_profiles      one per pet: microchip, allergies, conditions, the
--                        emergency contact and the pet's two vets
--   medications          a medicine with the vet's instructions, as typed
--   care_plan_items      recurring reminders: medicine times and routines
--   care_logs            what was actually done for one reminder on one day
--   health_observations  the Quick log journal; a weight is one of them
--   health_documents     the photos and PDFs attached to a health record
--   pet-documents        private storage bucket for those files
--
-- Every table has row level security on. The publishable key that ships in
-- the app can do nothing beyond the policies below: a signed-in user reads
-- and writes rows of their own only, and only for a pet that belongs to them.

-- ---------------------------------------------------------------------------
-- Helpers for the policies. They run as the caller, so they see exactly what
-- the caller may see through the policies of 0001 and of this file.
-- ---------------------------------------------------------------------------
create or replace function public.health_owns_pet(pet uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (select 1 from public.pets p where p.id = pet and p.owner_id = (select auth.uid()));
$$;

comment on function public.health_owns_pet(uuid) is
  'Health policies: whether the pet belongs to the signed-in user.';

-- ---------------------------------------------------------------------------
-- health_events (from 0001): now the pet's health records. A record that is
-- not done yet (done_at is null) is a planned appointment or a due date.
-- Additive only: four nullable columns, a default for owner_id, a wider list
-- of kinds and one extra policy. The 0001 policy "health_events: owner has
-- full access" stays as it is.
-- ---------------------------------------------------------------------------
alter table public.health_events add column if not exists clinic text;
alter table public.health_events add column if not exists product_name text;
-- The next due date the vet gave. The app never calculates it.
alter table public.health_events add column if not exists next_due_on date;
-- The record whose next due date created this planned record.
alter table public.health_events add column if not exists follow_up_of uuid
  references public.health_events (id) on delete set null;

alter table public.health_events alter column owner_id set default auth.uid();

-- 0001 allowed: medicine, checkup, vaccination, other. Existing rows stay valid.
alter table public.health_events drop constraint if exists health_events_kind_check;
alter table public.health_events add constraint health_events_kind_check check (
  kind in ('medicine', 'checkup', 'vaccination', 'preventive', 'procedure', 'document', 'other')
);

alter table public.health_events drop constraint if exists health_events_text_lengths;
alter table public.health_events add constraint health_events_text_lengths check (
  (clinic is null or char_length(clinic) <= 200)
  and (product_name is null or char_length(product_name) <= 200)
  and (notes is null or char_length(notes) <= 4000)
);

create index if not exists health_events_follow_up_of_idx
  on public.health_events (follow_up_of) where follow_up_of is not null;

grant select, insert, update, delete on public.health_events to authenticated;

-- On top of the 0001 policy (rows of your own), not instead of it: a record
-- can only be written for a pet that belongs to the signed-in user.
drop policy if exists "health_events: only for the owner's pets" on public.health_events;
create policy "health_events: only for the owner's pets" on public.health_events
  as restrictive
  for all to authenticated
  using (true)
  with check (public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- vets: a vet or clinic. It belongs to the owner, not to a pet, so a second
-- pet reuses it without retyping.
-- ---------------------------------------------------------------------------
create table if not exists public.vets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  phone text not null default '' check (char_length(phone) <= 40),
  -- The owner marked the phone as a WhatsApp number (it then carries the country code).
  on_whatsapp boolean not null default false,
  address text not null default '' check (char_length(address) <= 300),
  -- Free text, as the owner typed it.
  opening_hours text not null default '' check (char_length(opening_hours) <= 300),
  notes text not null default '' check (char_length(notes) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.vets is
  'Health tab: the owner''s vets and clinics. Pets point to them from health_profiles.';

create index if not exists vets_owner_id_idx on public.vets (owner_id);

drop trigger if exists vets_touch_updated_at on public.vets;
create trigger vets_touch_updated_at
  before update on public.vets
  for each row execute procedure public.touch_updated_at();

alter table public.vets enable row level security;

grant select, insert, update, delete on public.vets to authenticated;

drop policy if exists "vets: owner has full access" on public.vets;
create policy "vets: owner has full access" on public.vets
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- Whether the vet belongs to the signed-in user (runs as the caller).
create or replace function public.health_owns_vet(vet uuid)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (select 1 from public.vets v where v.id = vet and v.owner_id = (select auth.uid()));
$$;

comment on function public.health_owns_vet(uuid) is
  'Health policies: whether the vet belongs to the signed-in user.';

-- ---------------------------------------------------------------------------
-- health_profiles: one per pet. Identification, standing medical facts, the
-- emergency contact person and the pet's regular and emergency vet.
-- "None known" and "not chipped" are answers, stored as such.
-- ---------------------------------------------------------------------------
create table if not exists public.health_profiles (
  pet_id uuid primary key references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  microchip text not null default '' check (char_length(microchip) <= 40),
  not_chipped boolean not null default false,
  allergies text[] not null default '{}',
  allergies_none_known boolean not null default false,
  conditions text[] not null default '{}',
  conditions_none_known boolean not null default false,
  contact_name text not null default '' check (char_length(contact_name) <= 120),
  contact_phone text not null default '' check (char_length(contact_phone) <= 40),
  notes text not null default '' check (char_length(notes) <= 2000),
  -- Deleting a vet leaves the pet without one.
  regular_vet_id uuid references public.vets (id) on delete set null,
  emergency_vet_id uuid references public.vets (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.health_profiles is
  'Health tab: one row per pet with the facts the Emergency card shows.';

create index if not exists health_profiles_owner_id_idx on public.health_profiles (owner_id);
create index if not exists health_profiles_regular_vet_id_idx
  on public.health_profiles (regular_vet_id) where regular_vet_id is not null;
create index if not exists health_profiles_emergency_vet_id_idx
  on public.health_profiles (emergency_vet_id) where emergency_vet_id is not null;

drop trigger if exists health_profiles_touch_updated_at on public.health_profiles;
create trigger health_profiles_touch_updated_at
  before update on public.health_profiles
  for each row execute procedure public.touch_updated_at();

alter table public.health_profiles enable row level security;

grant select, insert, update, delete on public.health_profiles to authenticated;

-- The pet is the caller's, and so is every vet the profile points to.
drop policy if exists "health_profiles: owner has full access" on public.health_profiles;
create policy "health_profiles: owner has full access" on public.health_profiles
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and public.health_owns_pet(pet_id)
    and (regular_vet_id is null or public.health_owns_vet(regular_vet_id))
    and (emergency_vet_id is null or public.health_owns_vet(emergency_vet_id))
  );

-- ---------------------------------------------------------------------------
-- medications: a medicine with the vet's instructions, stored as typed.
-- ---------------------------------------------------------------------------
create table if not exists public.medications (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 120),
  strength text not null default '' check (char_length(strength) <= 120),
  dose text not null default '' check (char_length(dose) <= 120),
  -- How it is given: "By mouth", "In the ear"...
  route text not null default '' check (char_length(route) <= 60),
  -- How often, in the vet's words.
  frequency text not null default '' check (char_length(frequency) <= 200),
  starts_on date,
  ends_on date,
  prescribed_by text not null default '' check (char_length(prescribed_by) <= 200),
  instructions text not null default '' check (char_length(instructions) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint medications_ends_after_start check (starts_on is null or ends_on is null or ends_on >= starts_on)
);

comment on table public.medications is
  'Health tab: medicines as the owner typed them. The app never interprets a dose.';

create index if not exists medications_pet_id_idx on public.medications (pet_id);

drop trigger if exists medications_touch_updated_at on public.medications;
create trigger medications_touch_updated_at
  before update on public.medications
  for each row execute procedure public.touch_updated_at();

alter table public.medications enable row level security;

grant select, insert, update, delete on public.medications to authenticated;

drop policy if exists "medications: owner has full access" on public.medications;
create policy "medications: owner has full access" on public.medications
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- care_plan_items: one recurring reminder. Either one reminder time of a
-- medicine, or a routine (feeding, walk, grooming, cleaning, other). It
-- repeats at time_of_day on the ISO weekdays in days_of_week (Monday = 1).
-- Deleting a medicine removes its reminders.
-- ---------------------------------------------------------------------------
create table if not exists public.care_plan_items (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind text not null default 'other' check (
    kind in ('medication', 'feeding', 'walk', 'grooming', 'cleaning', 'other')
  ),
  title text not null check (char_length(title) between 1 and 120),
  medication_id uuid references public.medications (id) on delete cascade,
  time_of_day time not null,
  days_of_week smallint[] not null default '{1,2,3,4,5,6,7}' check (
    cardinality(days_of_week) between 1 and 7 and days_of_week <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  ),
  -- The first day the reminder counts from; earlier days never need review.
  starts_on date,
  ends_on date,
  -- A paused reminder stays in the plan but is not due.
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint care_plan_items_medicine_has_medication check (kind <> 'medication' or medication_id is not null)
);

comment on table public.care_plan_items is
  'Health tab: recurring reminders. One row per reminder time of a medicine, or per routine.';

create index if not exists care_plan_items_pet_id_idx on public.care_plan_items (pet_id);
create index if not exists care_plan_items_medication_id_idx
  on public.care_plan_items (medication_id) where medication_id is not null;

drop trigger if exists care_plan_items_touch_updated_at on public.care_plan_items;
create trigger care_plan_items_touch_updated_at
  before update on public.care_plan_items
  for each row execute procedure public.touch_updated_at();

alter table public.care_plan_items enable row level security;

grant select, insert, update, delete on public.care_plan_items to authenticated;

drop policy if exists "care_plan_items: owner has full access" on public.care_plan_items;
create policy "care_plan_items: owner has full access" on public.care_plan_items
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- care_logs: what actually happened for one reminder on one day, or a dose of
-- a medicine given only when needed (plan_item_id is null). Kept apart from
-- the reminder: a reminder nobody answered has no row here, and is never
-- treated as a missed dose.
--   done     done, or for a medicine: the dose was given (done_at says when)
--   skipped  deliberately not done / not given
--   unknown  the owner is not sure
-- Deleting a reminder keeps its log (the link is cleared); deleting the
-- medicine removes its dose log.
-- ---------------------------------------------------------------------------
create table if not exists public.care_logs (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  plan_item_id uuid references public.care_plan_items (id) on delete set null,
  medication_id uuid references public.medications (id) on delete cascade,
  -- The reminder's title when it was logged, kept if the reminder is deleted.
  title text not null default '' check (char_length(title) <= 120),
  -- The day and time the occurrence was due.
  due_on date not null,
  due_time time,
  status text not null check (status in ('done', 'skipped', 'unknown')),
  -- When it was actually done or given.
  done_at timestamptz,
  note text not null default '' check (char_length(note) <= 1000),
  -- Who recorded it, and when.
  logged_by_name text not null default '' check (char_length(logged_by_name) <= 80),
  logged_at timestamptz not null default now(),
  -- One answer per reminder per day; a new answer replaces the old one.
  -- Rows without a reminder (null) are not limited by it.
  constraint care_logs_one_answer_per_day unique (plan_item_id, due_on)
);

comment on table public.care_logs is
  'Health tab: the dose actually given and the routines ticked. No row means no answer, not a missed dose.';

create index if not exists care_logs_pet_id_due_on_idx on public.care_logs (pet_id, due_on);
create index if not exists care_logs_medication_id_idx
  on public.care_logs (medication_id) where medication_id is not null;

alter table public.care_logs enable row level security;

grant select, insert, update, delete on public.care_logs to authenticated;

drop policy if exists "care_logs: owner has full access" on public.care_logs;
create policy "care_logs: owner has full access" on public.care_logs
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- health_observations: what the owner noticed (the Quick log journal). A
-- weight is the row with category 'weight' and a value in kilograms.
-- ---------------------------------------------------------------------------
create table if not exists public.health_observations (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- A category key from the app: weight, appetite, energy, feathers...
  category text not null check (char_length(category) between 1 and 40),
  level text check (level is null or level in ('usual', 'less', 'more', 'different', 'unsure')),
  value numeric(10, 3) check (value is null or value > 0),
  unit text check (unit is null or char_length(unit) <= 12),
  note text not null default '' check (char_length(note) <= 1000),
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

comment on table public.health_observations is
  'Health tab: the observation journal. A record of what the owner noticed, never a diagnosis.';

create index if not exists health_observations_pet_id_observed_at_idx
  on public.health_observations (pet_id, observed_at desc);

alter table public.health_observations enable row level security;

grant select, insert, update, delete on public.health_observations to authenticated;

drop policy if exists "health_observations: owner has full access" on public.health_observations;
create policy "health_observations: owner has full access" on public.health_observations
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- health_documents: a photo or a PDF attached to a health record. The file
-- itself lives in the pet-documents bucket at storage_path. Deleting the
-- record removes these rows; the app removes the files first.
-- ---------------------------------------------------------------------------
create table if not exists public.health_documents (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  record_id uuid not null references public.health_events (id) on delete cascade,
  -- <user id>/<pet id>/<record id>/<file>, inside the pet-documents bucket.
  storage_path text not null unique check (char_length(storage_path) between 1 and 400),
  file_name text not null check (char_length(file_name) between 1 and 200),
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  size_bytes integer not null check (size_bytes > 0 and size_bytes <= 5242880),
  created_at timestamptz not null default now()
);

comment on table public.health_documents is
  'Health tab: photos and PDFs attached to a health record. Files are in the pet-documents bucket.';

create index if not exists health_documents_pet_id_idx on public.health_documents (pet_id);
create index if not exists health_documents_record_id_idx on public.health_documents (record_id);

alter table public.health_documents enable row level security;

grant select, insert, update, delete on public.health_documents to authenticated;

-- The file must sit in the caller's own folder of the bucket.
drop policy if exists "health_documents: owner has full access" on public.health_documents;
create policy "health_documents: owner has full access" on public.health_documents
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and public.health_owns_pet(pet_id)
    and split_part(storage_path, '/', 1) = (select auth.uid())::text
  );

-- ---------------------------------------------------------------------------
-- Storage: private bucket for the documents of health records. 5 MB per file;
-- JPEG, PNG, WebP and PDF only. Files live under
-- <user id>/<pet id>/<record id>/<file>, and the policies key off the first
-- folder, as for pet-photos in 0001. Nothing in it is public: the app opens
-- a file through a short-lived signed link.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pet-documents', 'pet-documents', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "pet-documents: owner can read" on storage.objects;
create policy "pet-documents: owner can read" on storage.objects
  for select to authenticated
  using (bucket_id = 'pet-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "pet-documents: owner can upload" on storage.objects;
create policy "pet-documents: owner can upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'pet-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "pet-documents: owner can update" on storage.objects;
create policy "pet-documents: owner can update" on storage.objects
  for update to authenticated
  using (bucket_id = 'pet-documents' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'pet-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "pet-documents: owner can delete" on storage.objects;
create policy "pet-documents: owner can delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'pet-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
