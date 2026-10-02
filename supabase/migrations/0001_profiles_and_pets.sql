-- PetLoop: initial schema.
-- Run in the Supabase SQL editor (Dashboard > SQL Editor > New query > paste > Run)
-- or with the Supabase CLI: `supabase db push`.
--
-- Every table has row level security on, and every policy is "the signed-in
-- user only sees and edits their own rows". The anon key that ships in the
-- app can therefore do nothing beyond what these policies allow.

-- ---------------------------------------------------------------------------
-- profiles: one row per account, created automatically on sign-up.
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: owner can read" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles: owner can update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Copies the display name given at sign-up (user metadata) into profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------------
-- pets: the animals an account looks after.
-- ---------------------------------------------------------------------------
create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  species text not null default 'dog',
  breed text,
  birth_date date,
  weight_kg numeric(5, 2) check (weight_kg is null or weight_kg > 0),
  daily_calorie_goal integer check (daily_calorie_goal is null or daily_calorie_goal > 0),
  photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pets_owner_id_idx on public.pets (owner_id);

alter table public.pets enable row level security;

create policy "pets: owner has full access" on public.pets
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- health_events: medicine, check-ups, vaccinations... per pet.
-- ---------------------------------------------------------------------------
create table if not exists public.health_events (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  kind text not null default 'other' check (kind in ('medicine', 'checkup', 'vaccination', 'other')),
  title text not null check (char_length(title) between 1 and 120),
  notes text,
  scheduled_at timestamptz not null,
  done_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists health_events_pet_id_idx on public.health_events (pet_id, scheduled_at);

alter table public.health_events enable row level security;

create policy "health_events: owner has full access" on public.health_events
  for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- updated_at maintenance.
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute procedure public.touch_updated_at();

drop trigger if exists pets_touch_updated_at on public.pets;
create trigger pets_touch_updated_at
  before update on public.pets
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Storage: private bucket for pet photos. Files live under
-- <user id>/<pet id>/<file>, and the policies key off the first folder.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pet-photos', 'pet-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "pet-photos: owner can read" on storage.objects
  for select using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pet-photos: owner can upload" on storage.objects
  for insert with check (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pet-photos: owner can update" on storage.objects
  for update using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "pet-photos: owner can delete" on storage.objects
  for delete using (bucket_id = 'pet-photos' and (storage.foldername(name))[1] = auth.uid()::text);
