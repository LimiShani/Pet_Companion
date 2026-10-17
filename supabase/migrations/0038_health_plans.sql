-- PetLoop: the yearly plan of vaccines and treatments, insights and the
-- weekly summary (improvement plan, phases 3a and 3c). Apply after 0031.
--
--   * health_events.plan_item: which item of a yearly plan a record belongs
--     to (e.g. 'dog.rabies', 'dog.combined#2', 'dog.flea@3m'), or null for
--     every record the owner added by hand. The app writes it on the
--     planned records it creates from a plan, copies it to the next planned
--     record when one is marked done, and shows "from Kelly's yearly plan"
--     next to them. Nothing else reads it; the plan templates live in the
--     app (lib/services/pet_records/plans/plan_templates.dart).
--   * Capabilities health.plans.view (the yearly plan) and
--     health.insights.view (the insight line on the Health Overview and the
--     weekly summary notification). Both are granted to the "Beta testers"
--     group only (0029), not to Standard owners: the plan's content waits
--     for a vet's review. To open them to everyone later:
--       insert into public.group_capability_rules(group_id, capability, allowed)
--       values ('acc35500-0000-4000-8000-000000000001', 'health.plans.view', true),
--              ('acc35500-0000-4000-8000-000000000001', 'health.insights.view', true)
--       on conflict do nothing;
--
-- No new table and no new policy: health_events keeps its row level
-- security (0002, 0014, 0030); the new column is written under the same
-- rules as every other column of a record.
--
-- Additive and idempotent: running it again changes nothing.
begin;

do $$
begin
  if to_regclass('public.health_events') is null
     or to_regclass('public.access_capabilities') is null
     or to_regclass('public.access_groups') is null then
    raise exception 'Run 0002_health.sql, 0014_feature_access.sql and 0029_rewards_foundation.sql first.';
  end if;
  if not exists (select 1 from public.access_groups where id = 'acc35500-0000-4000-8000-000000000002') then
    raise exception 'Run 0029_rewards_foundation.sql first (the Beta testers group).';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- health_events.plan_item
-- ---------------------------------------------------------------------------
alter table public.health_events add column if not exists plan_item text;

alter table public.health_events drop constraint if exists health_events_plan_item_valid;
alter table public.health_events add constraint health_events_plan_item_valid check (
  plan_item is null
  or (char_length(plan_item) between 3 and 64 and plan_item ~ '^[a-z]+\.[a-z_]+(#[1-9])?(@[1-9][0-9]?m)?$')
);

comment on column public.health_events.plan_item is
  'The yearly plan item a planned record was made from (species.item, an optional #dose of a puppy or kitten series, an optional @Nm interval the owner chose), or null.';

-- ---------------------------------------------------------------------------
-- Capabilities, for the beta testers only.
-- ---------------------------------------------------------------------------
update public.access_revision set revision = revision + 1
where singleton and (
  select count(*) from public.access_capabilities
  where id in ('health.plans.view', 'health.insights.view')
) < 2;

insert into public.access_capabilities(id, feature_id, requires_view) values
  ('health.plans.view', 'health', null),
  ('health.insights.view', 'health', null)
on conflict (id) do nothing;

-- The 0029 trigger already gives a new capability to the beta testers;
-- said again here so the grant does not depend on it.
insert into public.group_capability_rules(group_id, capability, allowed)
select 'acc35500-0000-4000-8000-000000000002', c, true
from unnest(array['health.plans.view', 'health.insights.view']) c
on conflict do nothing;

commit;
