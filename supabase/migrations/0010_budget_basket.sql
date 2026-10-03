-- PetLoop: the budget (what the pets cost) and the Store's basket (the
-- products the owner buys again and again).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 and 0002
-- (public.pets, public.health_owns_pet, public.touch_updated_at). Safe to
-- run more than once.
--
-- Purely additive: two new tables, nothing else is changed.
--   basket_items  a regular product: its pet, kind, package, last price and
--                 purchase, and how long a package lasts (null for food =
--                 worked out on the phone from the pet's feeding)
--   expenses      what the owner spent: an amount, a category, a pet or the
--                 whole home (pet_id null), a date, a note, how often it is
--                 paid, and where it came from (entered by hand, or "Bought
--                 again" in the basket)
--
-- Health costs are not copied here: the app reads them from the health
-- records (health_events.cost_amount, from 0006), so they are never
-- counted twice.
--
-- A recurring expense is one row: it counts from spent_on in every later
-- month (monthly) or in the same month of every later year (yearly), until
-- ended_on. The app works the months out; nothing is generated here.
--
-- Both tables have row level security on. The publishable key that ships
-- in the app can do nothing beyond the policies below: a signed-in user
-- reads and writes rows of their own only, and only for a pet that belongs
-- to them.

begin;

-- ---------------------------------------------------------------------------
-- basket_items
-- ---------------------------------------------------------------------------
create table if not exists public.basket_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  pet_id uuid not null references public.pets (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 80),
  kind text not null default 'other' check (kind in ('food', 'litter', 'consumable', 'other')),
  package_size numeric(9, 2) not null check (package_size > 0 and package_size <= 100000),
  package_unit text not null default 'units' check (package_unit in ('kg', 'g', 'l', 'units')),
  last_price numeric(10, 2) check (last_price is null or last_price >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  last_bought_on date,
  -- The owner's "lasts about N days"; null means: work it out from the
  -- pet's feeding (food), or unknown (anything else).
  lasts_days integer check (lasts_days is null or lasts_days between 1 and 3650),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.basket_items is
  'Store > My basket: a product the owner buys again and again, and when the last package runs out.';

create index if not exists basket_items_owner_idx on public.basket_items (owner_id);
create index if not exists basket_items_pet_idx on public.basket_items (pet_id);

drop trigger if exists basket_items_touch_updated_at on public.basket_items;
create trigger basket_items_touch_updated_at
  before update on public.basket_items
  for each row execute procedure public.touch_updated_at();

alter table public.basket_items enable row level security;

grant select, insert, update, delete on public.basket_items to authenticated;

drop policy if exists "basket_items: owner reads" on public.basket_items;
create policy "basket_items: owner reads" on public.basket_items
  for select to authenticated
  using (owner_id = (select auth.uid()));

drop policy if exists "basket_items: owner adds" on public.basket_items;
create policy "basket_items: owner adds" on public.basket_items
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

drop policy if exists "basket_items: owner changes" on public.basket_items;
create policy "basket_items: owner changes" on public.basket_items
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

drop policy if exists "basket_items: owner removes" on public.basket_items;
create policy "basket_items: owner removes" on public.basket_items
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- expenses
-- ---------------------------------------------------------------------------
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Null: the whole home, not one pet.
  pet_id uuid references public.pets (id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  category text not null default 'other' check (
    category in ('food', 'litter_consumables', 'vet_medicines', 'equipment', 'services', 'other')
  ),
  -- The day it was paid; for a recurring expense, the first payment.
  spent_on date not null default current_date,
  note text not null default '' check (char_length(note) <= 120),
  frequency text not null default 'once' check (frequency in ('once', 'monthly', 'yearly')),
  source text not null default 'manual' check (source in ('manual', 'basket')),
  -- The product a "Bought again" was for. The expense stays when the
  -- product is removed from the basket.
  basket_item_id uuid references public.basket_items (id) on delete set null,
  -- A recurring expense the owner stopped: no payment after this day counts.
  ended_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expenses_end_after_start check (ended_on is null or ended_on >= spent_on),
  constraint expenses_end_only_recurring check (ended_on is null or frequency <> 'once')
);

comment on table public.expenses is
  'Budget: what the owner spent on a pet or on the whole home. Health costs live on the health records, not here.';

create index if not exists expenses_owner_spent_idx on public.expenses (owner_id, spent_on desc);
create index if not exists expenses_pet_idx on public.expenses (pet_id);
create index if not exists expenses_basket_item_idx on public.expenses (basket_item_id);

drop trigger if exists expenses_touch_updated_at on public.expenses;
create trigger expenses_touch_updated_at
  before update on public.expenses
  for each row execute procedure public.touch_updated_at();

alter table public.expenses enable row level security;

grant select, insert, update, delete on public.expenses to authenticated;

drop policy if exists "expenses: owner reads" on public.expenses;
create policy "expenses: owner reads" on public.expenses
  for select to authenticated
  using (owner_id = (select auth.uid()));

-- A pet must be one of the owner's; the whole home (null) is always theirs.
drop policy if exists "expenses: owner adds" on public.expenses;
create policy "expenses: owner adds" on public.expenses
  for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and (pet_id is null or public.health_owns_pet(pet_id))
    and (
      basket_item_id is null
      or exists (select 1 from public.basket_items b where b.id = basket_item_id and b.owner_id = (select auth.uid()))
    )
  );

drop policy if exists "expenses: owner changes" on public.expenses;
create policy "expenses: owner changes" on public.expenses
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and (pet_id is null or public.health_owns_pet(pet_id))
    and (
      basket_item_id is null
      or exists (select 1 from public.basket_items b where b.id = basket_item_id and b.owner_id = (select auth.uid()))
    )
  );

drop policy if exists "expenses: owner removes" on public.expenses;
create policy "expenses: owner removes" on public.expenses
  for delete to authenticated
  using (owner_id = (select auth.uid()));

commit;
