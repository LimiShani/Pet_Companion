-- Pet Companion: Store phase 1 (prices you can compare, deals for your pet, cats).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0004 (public.store_deals).
-- Safe to run more than once.
--
-- Purely additive: no table, policy, column or row is removed. It adds to
-- public.store_deals what the Store now shows about a deal:
--   package_amount, package_unit   how much is in the package ("12 kg"); the
--                                  app works out the unit price from them
--   delivery_cost                  null = not given, 0 = free
--   price_checked_at               when the price was last checked
--   species                        the animals the deal is for; empty = every pet
-- it lets the category be 'litter_and_cleaning', and it adds five curated
-- cat deals.
--
-- No access rule changes: the new columns sit on store_deals and are covered
-- by its row level security from 0004 (signed-in users read; a member adds,
-- changes and removes only deals of their own).
--
-- The unit price ("18.90 per kg") and the final price (price + delivery) are
-- worked out in the app and deliberately not stored, so they cannot go stale.
-- The app reads the whole catalogue and filters it on the device, so the new
-- columns need no index.

begin;

-- ---------------------------------------------------------------------------
-- New columns.
-- ---------------------------------------------------------------------------
alter table public.store_deals
  add column if not exists package_amount numeric(12, 3),
  add column if not exists package_unit text,
  add column if not exists delivery_cost numeric(10, 2),
  add column if not exists price_checked_at timestamptz,
  add column if not exists species text[] not null default '{}';

comment on column public.store_deals.package_amount is
  'How much is in the package, in package_unit. For a multi-pack, the total. Null when not given.';
comment on column public.store_deals.package_unit is
  'kg, g, l, ml or unit. Filled exactly when package_amount is.';
comment on column public.store_deals.delivery_cost is
  'What delivery costs, in the deal''s currency. Null = not given, 0 = free.';
comment on column public.store_deals.price_checked_at is
  'When the price was last checked. Set by the database for deals shared from the app; edit it here for curated deals.';
comment on column public.store_deals.species is
  'The animals the deal is for: dog, cat, bird, rabbit, reptile, other. Empty = every pet.';

-- Deals from before this file: their price was checked when they were posted.
update public.store_deals set price_checked_at = posted_at where price_checked_at is null;

alter table public.store_deals alter column price_checked_at set default now();
alter table public.store_deals alter column price_checked_at set not null;

-- ---------------------------------------------------------------------------
-- Rules for the new columns.
-- ---------------------------------------------------------------------------
alter table public.store_deals drop constraint if exists store_deals_package_size_valid;
alter table public.store_deals add constraint store_deals_package_size_valid check (
  (package_amount is null and package_unit is null)
  or (package_amount > 0 and package_unit in ('kg', 'g', 'l', 'ml', 'unit'))
);

alter table public.store_deals drop constraint if exists store_deals_delivery_cost_valid;
alter table public.store_deals add constraint store_deals_delivery_cost_valid check (
  delivery_cost is null or delivery_cost >= 0
);

-- Only the kinds of animal the app knows, and no empty entries.
alter table public.store_deals drop constraint if exists store_deals_species_known;
alter table public.store_deals add constraint store_deals_species_known check (
  species <@ array['dog', 'cat', 'bird', 'rabbit', 'reptile', 'other']::text[]
  and array_position(species, null) is null
);

-- ---------------------------------------------------------------------------
-- A new category: litter and cleaning. The list of categories is a check on
-- the column, so the old check is replaced by one with the longer list.
-- (Found by what it checks rather than by name, whatever it was called.)
-- ---------------------------------------------------------------------------
do $$
declare
  old_check record;
begin
  for old_check in
    select conname
    from pg_constraint
    where conrelid = 'public.store_deals'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%category%'
  loop
    execute format('alter table public.store_deals drop constraint %I', old_check.conname);
  end loop;
end;
$$;

alter table public.store_deals add constraint store_deals_category_check check (
  category in (
    'food', 'treats', 'litter_and_cleaning', 'toys', 'health', 'grooming', 'accessories', 'beds_and_crates'
  )
);

-- ---------------------------------------------------------------------------
-- The six curated deals of 0004 get their package size, delivery cost and
-- animals. Only where those are all still empty, so nothing you edited is
-- overwritten and a second run changes nothing. This comes before the trigger
-- below is created, so filling them in does not count as checking the price.
-- ---------------------------------------------------------------------------
update public.store_deals d
set package_amount = v.package_amount,
    package_unit = v.package_unit,
    delivery_cost = v.delivery_cost,
    species = v.species
from (
  values
    ('5707e000-0000-4000-8000-000000000001'::uuid, 12::numeric, 'kg', 25::numeric, array['dog']),
    ('5707e000-0000-4000-8000-000000000002'::uuid, 2::numeric, 'unit', null::numeric, array['dog']),
    ('5707e000-0000-4000-8000-000000000003'::uuid, 28::numeric, 'unit', null::numeric, array['dog']),
    ('5707e000-0000-4000-8000-000000000004'::uuid, null::numeric, null::text, 0::numeric, array['dog']),
    ('5707e000-0000-4000-8000-000000000005'::uuid, null::numeric, null::text, null::numeric, array['dog']),
    ('5707e000-0000-4000-8000-000000000006'::uuid, 500::numeric, 'ml', 20::numeric, array['dog'])
) as v (id, package_amount, package_unit, delivery_cost, species)
where d.id = v.id
  and d.package_amount is null
  and d.delivery_cost is null
  and d.species = '{}';

-- ---------------------------------------------------------------------------
-- The "price checked" date cannot be made up from the app.
--   A member shares a deal: it is stamped now.
--   A member changes their deal's price, delivery or package: stamped now.
--   A member changes anything else: the date stays as it was.
-- Here in the dashboard (no signed-in user) the date is yours to set; when
-- you change a price and leave the date alone, it moves to now for you.
-- ---------------------------------------------------------------------------
create or replace function public.store_deals_price_checked()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  price_changed boolean;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null or new.price_checked_at is null then
      new.price_checked_at := now();
    end if;
    return new;
  end if;

  price_changed :=
    new.price is distinct from old.price
    or new.original_price is distinct from old.original_price
    or new.delivery_cost is distinct from old.delivery_cost
    or new.package_amount is distinct from old.package_amount
    or new.package_unit is distinct from old.package_unit;

  if auth.uid() is not null then
    new.price_checked_at := case when price_changed then now() else old.price_checked_at end;
  elsif new.price_checked_at is null
     or (price_changed and new.price_checked_at is not distinct from old.price_checked_at) then
    new.price_checked_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists store_deals_price_checked on public.store_deals;
create trigger store_deals_price_checked
  before insert or update on public.store_deals
  for each row execute procedure public.store_deals_price_checked();

-- ---------------------------------------------------------------------------
-- Five curated deals for cats (no sharer). Sample products and shops are
-- invented and the links are placeholders: replace them with real offers in
-- the Table editor. Fixed ids keep a second run from adding copies.
-- ---------------------------------------------------------------------------
insert into public.store_deals
  (id, title, description, category, price, original_price, currency, seller_name, link,
   posted_at, expires_at, package_amount, package_unit, delivery_cost, species)
values
  (
    '5707e000-0000-4000-8000-000000000007',
    'Adult cat dry food, chicken, 4 kg',
    'Chicken and rice dry food for adult indoor cats. A bag this size is easy to carry and to store.',
    'food', 89.00, 129.00, 'ILS', 'Happy Paws Market',
    'https://example.com/deals/cat-dry-chicken-4kg',
    now() - interval '4 hours', now() + interval '5 days',
    4, 'kg', 0, array['cat']
  ),
  (
    '5707e000-0000-4000-8000-000000000008',
    'Cat wet food pouches, 12 × 85 g',
    'Twelve pouches in gravy: four chicken, four tuna, four beef. Handy for cats that drink too little.',
    'food', 34.90, 49.90, 'ILS', 'Happy Paws Market',
    'https://example.com/deals/cat-wet-pouches',
    now() - interval '2 days', now() + interval '11 days',
    1020, 'g', 25, array['cat']
  ),
  (
    '5707e000-0000-4000-8000-000000000009',
    'Clumping cat litter, 10 kg',
    'Fine-grain clumping litter with low dust. One 10 kg bag lasts one cat about a month.',
    'litter_and_cleaning', 36.90, 59.90, 'ILS', 'Clean Paws',
    'https://example.com/deals/clumping-litter-10kg',
    now() - interval '2 days', now() + interval '14 days',
    10, 'kg', 25, array['cat']
  ),
  (
    '5707e000-0000-4000-8000-00000000000a',
    'Hooded litter box with scoop',
    'A covered box with a swing door and a charcoal filter that keeps the smell in. The lid lifts off for cleaning.',
    'litter_and_cleaning', 99.00, 149.00, 'ILS', 'Cozy Den',
    'https://example.com/deals/hooded-litter-box',
    now() - interval '6 days', null,
    null, null, 0, array['cat']
  ),
  (
    '5707e000-0000-4000-8000-00000000000b',
    'Sisal scratching post, 80 cm',
    'A tall, heavy-based post wrapped in sisal rope, high enough for a full stretch.',
    'toys', 79.00, 119.00, 'ILS', 'Cozy Den',
    'https://example.com/deals/scratching-post',
    now() - interval '1 day', null,
    null, null, null, array['cat']
  )
on conflict (id) do nothing;

commit;
