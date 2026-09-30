-- Pet Companion: community, phase 1 (cats as first-class).
-- Run AFTER 0003_community.sql, in the Supabase SQL editor (Dashboard >
-- SQL Editor > New query > paste > Run) or with `supabase db push`.
--
-- Additive and idempotent: running it again changes nothing. It adds no
-- table and changes no policy:
--   * chat rooms say which animal they are for (`audience`);
--   * the three dog rooms are marked as such;
--   * four rooms for cat owners are added.
-- Guides, and who wrote and reviewed them, are bundled in the app and have
-- no table.

-- This file builds on the chat rooms of 0003_community.sql.
do $$
begin
  if to_regclass('public.chat_channels') is null then
    raise exception 'public.chat_channels does not exist: run 0003_community.sql first.';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- chat_channels.audience: who a room is for. 'all' is shared by everyone;
-- otherwise a kind of animal, written as in pets.species (the app's
-- PetSpecies names), so rooms for rabbits or birds later need no further
-- schema change. The app shows a room under Dogs or Cats together with the
-- shared rooms, and every room under Everything.
-- ---------------------------------------------------------------------------
alter table public.chat_channels
  add column if not exists audience text not null default 'all';

alter table public.chat_channels
  drop constraint if exists chat_channels_audience_check;
alter table public.chat_channels
  add constraint chat_channels_audience_check
  check (audience in ('all', 'dog', 'cat', 'bird', 'rabbit', 'reptile', 'other'));

-- The rooms 0003 created for dog owners. Only while still unmarked, so a
-- choice made later in the dashboard is not overwritten.
update public.chat_channels
set audience = 'dog'
where id in ('puppies', 'training', 'seniors')
  and audience = 'all';

-- Rooms for cat owners. sort_order places them after the dog rooms (20 to
-- 40) and before 'Health questions' (50), which everyone shares.
insert into public.chat_channels (id, name, description, audience, sort_order)
values
  ('kittens', 'Kittens', 'First weeks, litter habits and play', 'cat', 42),
  ('cat-litter', 'Litter and cleaning', 'Litter, smell and how many boxes', 'cat', 44),
  ('cat-behaviour', 'Cat behaviour and play', 'Scratching, night-time energy, a second cat', 'cat', 46),
  ('senior-cats', 'Senior cats', 'Comfort and care for older cats', 'cat', 48)
on conflict (id) do nothing;

-- Row level security is unchanged: 0003's "chat_channels: members can read"
-- covers the new column and the new rows (signed-in members read rooms;
-- nobody creates or changes a room from the app), and chat_messages in the
-- new rooms fall under the existing chat_messages policies and realtime
-- publication.
