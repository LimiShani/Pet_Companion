-- PetLoop: the Health tab, phase 1 extension (cost on a record,
-- cleaning routines, the emergency kit, the "my pet is lost" card).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 and 0002
-- (public.pets, public.health_events, public.care_plan_items,
-- public.health_owns_pet, public.touch_updated_at). Safe to run more than once.
--
-- Purely additive: no table, column, row or file is removed or rewritten.
--   health_events        two nullable columns: what a record cost, and in
--                        which currency
--   care_plan_items      three more kinds of routine: litter box cleaning,
--                        litter change, cage cleaning. Existing rows stay valid.
--   emergency_kit_items  new: which items of a pet's emergency kit are
--                        ready, since when, and a short note
--   lost_pet_cards       new: what the owner wrote for a pet's lost card, so
--                        nothing is retyped
--
-- The behaviour journal needs nothing here: a category of
-- health_observations is already free text. No bucket is added: the lost
-- card is drawn on the phone and handed to the share sheet; the app stores
-- no picture of it and posts it nowhere.
--
-- Both new tables have row level security on. The publishable key that
-- ships in the app can do nothing beyond the policies below: a signed-in
-- user reads and writes rows of their own only, and only for a pet that
-- belongs to them.

begin;

-- ---------------------------------------------------------------------------
-- health_events: the optional cost of a record. What was paid for a done
-- record; what is expected for a planned one. The amount is never part of
-- what the app shares with a vet.
-- ---------------------------------------------------------------------------
alter table public.health_events add column if not exists cost_amount numeric(10, 2);
-- ISO 4217 code. The default matches AppConfig.defaultCurrency in the app.
alter table public.health_events add column if not exists cost_currency text default 'ILS';

alter table public.health_events drop constraint if exists health_events_cost_valid;
alter table public.health_events add constraint health_events_cost_valid check (
  (cost_amount is null or cost_amount >= 0)
  and (cost_currency is null or cost_currency ~ '^[A-Z]{3}$')
  and (cost_amount is null or cost_currency is not null)
);

comment on column public.health_events.cost_amount is
  'What the owner paid (done record) or expects to pay (planned record); null when not entered.';

-- ---------------------------------------------------------------------------
-- care_plan_items: more kinds of routine. 0002 allowed: medication, feeding,
-- walk, grooming, cleaning, other.
-- ---------------------------------------------------------------------------
alter table public.care_plan_items drop constraint if exists care_plan_items_kind_check;
alter table public.care_plan_items add constraint care_plan_items_kind_check check (
  kind in (
    'medication', 'feeding', 'walk', 'grooming', 'cleaning',
    'litter_cleaning', 'litter_change', 'cage_cleaning', 'other'
  )
);

-- ---------------------------------------------------------------------------
-- emergency_kit_items: one row per pet and item of its emergency kit
-- (carrier, food_water, documents, microchip, medicines, shelter_plan).
-- checked_at is when the owner ticked it; null means "not ready". The item
-- is a free key, so a later version of the app can add one without a
-- migration.
-- ---------------------------------------------------------------------------
create table if not exists public.emergency_kit_items (
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  item text not null check (char_length(item) between 1 and 40),
  checked_at timestamptz,
  -- The owner's own words, e.g. the plan for the protected room.
  note text not null default '' check (char_length(note) <= 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (pet_id, item)
);

comment on table public.emergency_kit_items is
  'Health tab: the per-pet emergency kit checklist. The owner''s own list, not official guidance.';

create index if not exists emergency_kit_items_owner_id_idx on public.emergency_kit_items (owner_id);

drop trigger if exists emergency_kit_items_touch_updated_at on public.emergency_kit_items;
create trigger emergency_kit_items_touch_updated_at
  before update on public.emergency_kit_items
  for each row execute procedure public.touch_updated_at();

alter table public.emergency_kit_items enable row level security;

grant select, insert, update, delete on public.emergency_kit_items to authenticated;

drop policy if exists "emergency_kit_items: owner has full access" on public.emergency_kit_items;
create policy "emergency_kit_items: owner has full access" on public.emergency_kit_items
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

-- ---------------------------------------------------------------------------
-- lost_pet_cards: one per pet. The draft of the "my pet is lost" card, kept
-- so the owner does not retype it. Only the owner ever reads it: nothing
-- here is public, and the app posts the card nowhere. The area is what the
-- owner typed (a neighbourhood), never an address taken from elsewhere.
-- found_at is set when the pet is back home.
-- ---------------------------------------------------------------------------
create table if not exists public.lost_pet_cards (
  pet_id uuid primary key references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  description text not null default '' check (char_length(description) <= 400),
  area text not null default '' check (char_length(area) <= 120),
  last_seen_at timestamptz,
  -- The owner's own phone number; shown on the card only after they confirm it.
  phone text not null default '' check (char_length(phone) <= 40),
  extra text not null default '' check (char_length(extra) <= 120),
  -- The language of the card's fixed words: Hebrew by default.
  language text not null default 'he' check (language in ('he', 'en')),
  found_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.lost_pet_cards is
  'Health tab: the owner''s draft of a lost-pet card. Private to the owner; never published by the app.';

create index if not exists lost_pet_cards_owner_id_idx on public.lost_pet_cards (owner_id);

drop trigger if exists lost_pet_cards_touch_updated_at on public.lost_pet_cards;
create trigger lost_pet_cards_touch_updated_at
  before update on public.lost_pet_cards
  for each row execute procedure public.touch_updated_at();

alter table public.lost_pet_cards enable row level security;

grant select, insert, update, delete on public.lost_pet_cards to authenticated;

drop policy if exists "lost_pet_cards: owner has full access" on public.lost_pet_cards;
create policy "lost_pet_cards: owner has full access" on public.lost_pet_cards
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

commit;
