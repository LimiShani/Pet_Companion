-- PetLoop: the Store tab (a deals marketplace).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 (public.profiles).
-- Safe to run more than once.
--
-- Three tables:
--   store_deals       the catalogue: curated deals (shared_by is null) and
--                     deals shared by members
--   store_favourites  which member saved which deal
--   store_reports     "this deal has expired" reports, for the owner to review
--
-- Every table has row level security on with explicit policies for signed-in
-- users only. The publishable key that ships in the app can do nothing beyond
-- them: read the catalogue, and add, change or remove rows of your own.
-- Curated deals are added and edited here in the dashboard, which bypasses
-- row level security; the app can never create one.

-- ---------------------------------------------------------------------------
-- store_deals
-- ---------------------------------------------------------------------------
create table if not exists public.store_deals (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '' check (char_length(description) <= 1000),
  category text not null check (
    category in ('food', 'treats', 'toys', 'health', 'grooming', 'accessories', 'beds_and_crates')
  ),
  -- What it costs now, and what it cost before the discount.
  price numeric(10, 2) not null check (price > 0),
  original_price numeric(10, 2) not null check (original_price > 0),
  -- ISO 4217 code. The default matches kStoreDefaultCurrency in the app.
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  seller_name text not null check (char_length(seller_name) between 1 and 80),
  -- The seller's page. The app only ever opens https links.
  link text not null check (link ~* '^https://[^[:space:]]+$' and char_length(link) <= 2000),
  image_url text check (
    image_url is null or (image_url ~* '^https://[^[:space:]]+$' and char_length(image_url) <= 2000)
  ),
  -- The member who shared the deal; null for curated deals.
  shared_by uuid references auth.users (id) on delete cascade,
  -- That member's display name when they shared it (set by the trigger below).
  shared_by_name text check (shared_by_name is null or char_length(shared_by_name) <= 80),
  posted_at timestamptz not null default now(),
  -- When the offer ends; null when the seller gave no end date.
  expires_at timestamptz,
  constraint store_deals_price_not_above_original check (price <= original_price),
  constraint store_deals_expires_after_posted check (expires_at is null or expires_at > posted_at)
);

comment on table public.store_deals is
  'Store tab: discounted pet products that link out to the seller. shared_by is null for curated deals.';

-- Category listing, newest first; the plain newest-first listing; a member's own deals.
create index if not exists store_deals_category_posted_at_idx on public.store_deals (category, posted_at desc);
create index if not exists store_deals_posted_at_idx on public.store_deals (posted_at desc);
create index if not exists store_deals_shared_by_idx on public.store_deals (shared_by) where shared_by is not null;

-- Rows written through the app (there is a signed-in user) are stamped by the
-- database, so a client cannot backdate a deal, pretend to be someone else in
-- the "Shared by" line, or hand a deal to another member later. Rows written
-- in the dashboard (no signed-in user) are left as given.
create or replace function public.store_deals_stamp()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.posted_at := now();
    -- Runs as the member, who may read their own profile (see 0001).
    new.shared_by_name := (
      select nullif(left(trim(p.display_name), 80), '')
      from public.profiles p
      where p.id = new.shared_by
    );
  else
    new.shared_by := old.shared_by;
    new.shared_by_name := old.shared_by_name;
    new.posted_at := old.posted_at;
  end if;
  return new;
end;
$$;

drop trigger if exists store_deals_stamp on public.store_deals;
create trigger store_deals_stamp
  before insert or update on public.store_deals
  for each row execute procedure public.store_deals_stamp();

alter table public.store_deals enable row level security;

grant select, insert, update, delete on public.store_deals to authenticated;

drop policy if exists "store_deals: signed-in users can read" on public.store_deals;
create policy "store_deals: signed-in users can read" on public.store_deals
  for select to authenticated
  using (true);

-- shared_by must be the caller, so the app cannot insert a curated deal
-- (null) or a deal in someone else's name.
drop policy if exists "store_deals: members share as themselves" on public.store_deals;
create policy "store_deals: members share as themselves" on public.store_deals
  for insert to authenticated
  with check (shared_by = (select auth.uid()));

drop policy if exists "store_deals: sharer can update" on public.store_deals;
create policy "store_deals: sharer can update" on public.store_deals
  for update to authenticated
  using (shared_by = (select auth.uid()))
  with check (shared_by = (select auth.uid()));

drop policy if exists "store_deals: sharer can delete" on public.store_deals;
create policy "store_deals: sharer can delete" on public.store_deals
  for delete to authenticated
  using (shared_by = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- store_favourites: the deals a member saved with the heart.
-- ---------------------------------------------------------------------------
create table if not exists public.store_favourites (
  user_id uuid not null references auth.users (id) on delete cascade,
  deal_id uuid not null references public.store_deals (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, deal_id)
);

-- The primary key serves "my saved deals"; this one serves deleting a deal.
create index if not exists store_favourites_deal_id_idx on public.store_favourites (deal_id);

alter table public.store_favourites enable row level security;

grant select, insert, delete on public.store_favourites to authenticated;

drop policy if exists "store_favourites: owner can read" on public.store_favourites;
create policy "store_favourites: owner can read" on public.store_favourites
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "store_favourites: owner can add" on public.store_favourites;
create policy "store_favourites: owner can add" on public.store_favourites
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "store_favourites: owner can remove" on public.store_favourites;
create policy "store_favourites: owner can remove" on public.store_favourites
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- store_reports: a member says a deal is over. One per member per deal.
-- Members can add a report and see their own; nobody can change or remove
-- one from the app. Review them here in the dashboard.
-- ---------------------------------------------------------------------------
create table if not exists public.store_reports (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.store_deals (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reason text not null default 'expired' check (reason in ('expired')),
  created_at timestamptz not null default now(),
  constraint store_reports_one_per_member unique (deal_id, reporter_id)
);

create index if not exists store_reports_reporter_id_idx on public.store_reports (reporter_id);

alter table public.store_reports enable row level security;

grant select, insert on public.store_reports to authenticated;

drop policy if exists "store_reports: reporter can read" on public.store_reports;
create policy "store_reports: reporter can read" on public.store_reports
  for select to authenticated
  using (reporter_id = (select auth.uid()));

drop policy if exists "store_reports: reporter can add" on public.store_reports;
create policy "store_reports: reporter can add" on public.store_reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- A handful of curated deals to start with (no sharer). Sample products and
-- shops are invented and the links are placeholders: replace them with real
-- offers in the Table editor. Fixed ids keep a second run from adding copies.
-- ---------------------------------------------------------------------------
insert into public.store_deals
  (id, title, description, category, price, original_price, currency, seller_name, link, posted_at, expires_at)
values
  (
    '5707e000-0000-4000-8000-000000000001',
    'Grain-free salmon kibble, 12 kg',
    'Salmon is the first ingredient, with sweet potato and peas instead of grain. For adult dogs of all sizes.',
    'food', 179.00, 299.00, 'ILS', 'Happy Paws Market',
    'https://example.com/deals/salmon-kibble-12kg',
    now() - interval '3 hours', now() + interval '12 days'
  ),
  (
    '5707e000-0000-4000-8000-000000000002',
    'Squeaky rope tug toy, 2 pack',
    'Two knotted cotton ropes with a squeaker in the middle. Good for tug and for teeth.',
    'toys', 29.00, 59.00, 'ILS', 'Toy Barn',
    'https://example.com/deals/rope-tug-toy',
    now() - interval '5 hours', now() + interval '6 days'
  ),
  (
    '5707e000-0000-4000-8000-000000000003',
    'Dental chew sticks, 28 pieces',
    'One chew a day helps keep tartar down. A month of sticks for dogs between 10 and 25 kg.',
    'treats', 39.90, 64.90, 'ILS', 'The Treat Jar',
    'https://example.com/deals/dental-chew-sticks',
    now() - interval '1 day', null
  ),
  (
    '5707e000-0000-4000-8000-000000000004',
    'Orthopaedic memory foam bed, large',
    'Thick memory foam with a raised edge to lean on. The cover zips off and goes in the washing machine.',
    'beds_and_crates', 219.00, 349.00, 'ILS', 'Cozy Den',
    'https://example.com/deals/memory-foam-bed-large',
    now() - interval '2 days', now() + interval '20 days'
  ),
  (
    '5707e000-0000-4000-8000-000000000005',
    'Reflective no-pull harness',
    'Front and back leash rings, padded chest plate and reflective stitching for evening walks.',
    'accessories', 74.00, 109.00, 'ILS', 'Walkies Supply',
    'https://example.com/deals/no-pull-harness',
    now() - interval '8 hours', now() + interval '3 days'
  ),
  (
    '5707e000-0000-4000-8000-000000000006',
    'Oatmeal soothing shampoo, 500 ml',
    'Gentle oatmeal and aloe shampoo for itchy or dry skin. No added perfume.',
    'grooming', 24.00, 35.00, 'ILS', 'Fur & Foam',
    'https://example.com/deals/oatmeal-shampoo',
    now() - interval '3 days', null
  )
on conflict (id) do nothing;
