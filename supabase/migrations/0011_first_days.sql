-- PetLoop: "the first 30 days" of a pet that just arrived home.
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001 (public.pets,
-- public.touch_updated_at) and 0002 (public.health_owns_pet). Safe to run
-- more than once.
--
-- Purely additive: no table, column, row or file is removed or rewritten.
--   pet_first_days  new: at most one row per pet with the day it arrived
--                   home, the tasks the owner ticked by hand and when the
--                   owner closed the path early
--
-- The tasks themselves are bundled with the app (per kind of animal), so
-- only their ids are stored. The ticks the app works out by itself (a vet
-- visit in Health, meal times, the microchip...) are never stored: they
-- come from the tables they are about.
--
-- The new table has row level security on. The publishable key that ships
-- in the app can do nothing beyond the policies below: a signed-in user
-- reads and writes rows of their own only, and only for a pet that belongs
-- to them.

begin;

create table if not exists public.pet_first_days (
  pet_id uuid primary key references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Day 1 of the 30.
  arrived_on date not null,
  -- Set when the owner ended the path before day 30.
  closed_at timestamptz,
  -- Ids of the tasks ticked by hand, such as 'dog-name-tag'.
  done_tasks text[] not null default '{}' check (cardinality(done_tasks) <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.pet_first_days is
  'Home: the first 30 days of a pet that just arrived home (arrival day, ticked tasks, early close).';

drop trigger if exists pet_first_days_touch_updated_at on public.pet_first_days;
create trigger pet_first_days_touch_updated_at
  before update on public.pet_first_days
  for each row execute procedure public.touch_updated_at();

alter table public.pet_first_days enable row level security;

grant select, insert, update, delete on public.pet_first_days to authenticated;

drop policy if exists "pet_first_days: owner has full access" on public.pet_first_days;
create policy "pet_first_days: owner has full access" on public.pet_first_days
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

commit;
