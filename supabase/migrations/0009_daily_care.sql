-- PetLoop: daily care on Home (the feeding and activity cards).
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`. Needs 0001, 0002 and 0006
-- (public.pets, public.care_logs, public.health_owns_pet,
-- public.touch_updated_at). Safe to run more than once.
--
-- Purely additive: no table, column, row or file is removed or rewritten.
--   care_logs          four nullable columns: what an extra entry is (a meal
--                      or a walk no reminder asked for), how much a meal was
--                      and its calories, and how long a walk lasted
--   pet_care_settings  new: one row per pet with its food (calories per
--                      100 g, grams in a cup), the usual portion, the owner's
--                      own calorie goal and the daily activity goal
--
-- The meal times and walk times are the feeding and walk routines of
-- care_plan_items; nothing is duplicated here. The calorie goal the app
-- works out from the weight is never stored: only an owner's own goal is.
--
-- The new table has row level security on. The publishable key that ships
-- in the app can do nothing beyond the policies below: a signed-in user
-- reads and writes rows of their own only, and only for a pet that belongs
-- to them.

begin;

-- ---------------------------------------------------------------------------
-- care_logs: amounts. A reminder's answer keeps its kind on the reminder;
-- kind is set only on an extra meal ('feeding') or an extra walk or play
-- session ('walk').
-- ---------------------------------------------------------------------------
alter table public.care_logs add column if not exists kind text;
alter table public.care_logs add column if not exists amount_grams numeric(7, 1);
alter table public.care_logs add column if not exists calories integer;
alter table public.care_logs add column if not exists minutes integer;

alter table public.care_logs drop constraint if exists care_logs_amounts_valid;
alter table public.care_logs add constraint care_logs_amounts_valid check (
  (kind is null or kind in ('feeding', 'walk'))
  and (amount_grams is null or amount_grams between 0 and 100000)
  and (calories is null or calories between 0 and 100000)
  and (minutes is null or minutes between 0 and 1440)
);

comment on column public.care_logs.kind is
  'Set only on an entry no reminder asked for: an extra meal (feeding) or walk / play (walk).';
comment on column public.care_logs.calories is
  'The calories of a meal, worked out on the phone from the food when it was logged.';
comment on column public.care_logs.minutes is
  'How long a walk or play session lasted.';

-- ---------------------------------------------------------------------------
-- pet_care_settings: the food and the goals of one pet.
-- ---------------------------------------------------------------------------
create table if not exists public.pet_care_settings (
  pet_id uuid primary key references public.pets (id) on delete cascade,
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  food_name text not null default '' check (char_length(food_name) <= 80),
  -- As printed on the bag.
  kcal_per_100g numeric(6, 1) check (kcal_per_100g is null or kcal_per_100g between 1 and 2000),
  -- How many grams of this food fill the owner's cup; null when the owner
  -- weighs in grams.
  grams_per_cup numeric(6, 1) check (grams_per_cup is null or grams_per_cup between 1 and 2000),
  portion_grams numeric(7, 1) check (portion_grams is null or portion_grams between 1 and 100000),
  -- The owner's own goal; null means the app's estimate from the weight.
  calorie_goal integer check (calorie_goal is null or calorie_goal between 1 and 100000),
  activity_goal_minutes integer check (activity_goal_minutes is null or activity_goal_minutes between 1 and 1440),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.pet_care_settings is
  'Home: a pet''s food, usual portion, own calorie goal and daily activity goal.';

drop trigger if exists pet_care_settings_touch_updated_at on public.pet_care_settings;
create trigger pet_care_settings_touch_updated_at
  before update on public.pet_care_settings
  for each row execute procedure public.touch_updated_at();

alter table public.pet_care_settings enable row level security;

grant select, insert, update, delete on public.pet_care_settings to authenticated;

drop policy if exists "pet_care_settings: owner has full access" on public.pet_care_settings;
create policy "pet_care_settings: owner has full access" on public.pet_care_settings
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and public.health_owns_pet(pet_id));

commit;
