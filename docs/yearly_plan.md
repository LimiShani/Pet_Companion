# Yearly plan of vaccines and treatments (phase 3a)

A common yearly plan for dogs and cats in Israel. The owner opens it,
ticks items, sees each first date and why, and adds them to the pet's
Schedule as planned health records. Marking one done plans the next one.
The dates can be shared to the owner's own calendar as an `.ics` file.

## Owner steps

1. **Run `supabase/migrations/0038_health_plans.sql`** in the Supabase SQL
   editor (after 0031). It adds `health_events.plan_item` and the
   capabilities `health.plans.view` and `health.insights.view`, granted to
   the Beta testers group only. Nothing to deploy.
2. **Have a vet review the plan** before `health.plans.view` reaches
   everyone. The content is in
   `lib/services/pet_records/plans/plan_templates.dart` (English and
   Hebrew, with the sources of each item). Points to check:
   * rabies for cats: shown as "Recommended", not required by law;
   * the park worm (Spirocerca) prevention: every 3 months, from 12 weeks;
   * deworming: every 2 weeks under 12 weeks of age, monthly under 26
     weeks, then every 3 months (cats: "depends on whether they go
     outside");
   * the combined dog vaccine (DHPPi+L) and the combined cat vaccine
     (FVRCP): series at 8, 12 and 16 weeks (at least 3 weeks apart), then
     once a year;
   * flea and tick: every month or every 3 months, the owner's choice;
   * an item with nothing on record is planned in two weeks ("Check the
     vaccination booklet first"); an overdue one for today.
3. **Open the plan to everyone** once reviewed (SQL in the header of 0038:
   two rows for the Standard owners group).

## Where it shows

* Health "+" sheet: **Yearly plan · Vaccines and treatments**
  (`health.plans.view`).
* Health Overview: an invitation card while a dog or cat has no
  vaccination on record (`health.plans.view` and `health.records.edit`).
* Coming up: a planned record made from the plan has the line **From
  Kelly's yearly plan**.

## How it works

* `plan_templates.dart`: the items per species (kind, EN/HE title and
  "why", interval, starting age, puppy or kitten series, interval choices,
  match words, sources).
* `plan_logic.dart`: `proposePlan` dates each item from the pet's age and
  its records (an item already planned is kept; the series by age; the
  interval after the last time; today when overdue; the starting age;
  two weeks with nothing on record). `PlanRef` is what
  `health_events.plan_item` holds: `dog.rabies`, `dog.combined#2` (a dose
  of the series), `dog.flea@3m` (the interval chosen).
* `plan_providers.dart`: `yearlyPlanProvider`, and
  `YearlyPlanService.apply`, which saves planned records through
  `RecordsController.save` (a record the owner planned by hand joins the
  plan instead of being duplicated).
* `RecordsController.save` (`health_providers.dart`): when a plan record
  is marked done and has no next due date, `withPlanNextDue` sets it from
  the plan; the existing follow-up then plans the next step, named after
  it (dose 2 of 3, then the yearly booster). A next due date the owner
  sets or clears afterwards is kept.
* `plan_calendar.dart`: the `.ics` file: one event per record added, at
  09:00 for 30 minutes, an alert the day before, no repeats (a done date
  moves the next one). Shared through `FileSharer` (share_plus); the app
  never asks for calendar access.
* The sheet: `lib/features/health/plans/yearly_plan_sheet.dart`; the
  invitation: `plan_invite.dart`. Strings: `lib/l10n/features/healthplan/`.

`plan_item` is sent to the database only when set, so records added by
hand keep saving on a database where 0038 is not applied yet; the plan
itself is hidden there, as its capability does not exist.

## Tests

`test/health_plan/`: `plan_logic_test.dart`, `plan_records_test.dart`,
`plan_sheet_test.dart`, `plan_fit_test.dart` (real fonts, 320 px, EN and
HE); `supabase/tests/health_plans_test.sql` (in `tool/test_database.ps1`).
