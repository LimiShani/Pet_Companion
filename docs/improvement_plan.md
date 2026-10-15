# Improvement round, October 2026: build plan

Approved by the owner on 15 October 2026: the 16-feature list (what brings
people back), the "simplify the use" direction and the colour code. The
designs are on the canvas https://claude.ai/artifact/LYBq7u2gD5N2G5gfp5CRRG
(principles, app map, Home with Today, Health, Emergency sheet, Community,
Outside, Store, Household, components). This file is the work plan that
agents build from. Nothing in it is built yet.

## What was approved

Direction (five moves):

1. **The day comes first.** A Today list on Home for all pets, with who did
   what. Ticks live there; the three illustrated Home cards keep their
   layout and colours but show status only and open their pages.
2. **One plus per tab.** One floating "+" per tab opens a short sheet of 3
   to 6 rows; every existing "add" button moves behind it. Home has none.
3. **One safety door.** The Emergency sheet is the safety hub: Call now, Is
   it urgent?, Can they eat this?, Lost mode, Emergency card and kit, Find
   a clinic.
4. **Colour says where.** Care = coral tint `#FBD0C3`, Health = peach,
   Community and Outside = sage, Store and Budget = yellow, You = neutral
   `#EADFCB`. On icon discs, tags and nav icons only. The header stays
   coral, yellow still means "selected", the Home cards keep their colours.
5. **New features land in existing rooms.** No new tab, no new Home card.

Features (numbers are used throughout):

| # | Feature | Lands in |
|---|---|---|
| 1 | Household phase 2: updates, pushes, delegation, home chat | Household page, Home, Today |
| 2 | Today list with "Done" in the notification | Home, notifications |
| 3 | Usage counts (what people repeat) | Admin tools only |
| 4 | Yearly plan of vaccines and treatments for Israel | Health "+" sheet, Coming up |
| 5 | Follow a problem (entries with photos, report for the vet) | Health Overview row, Records |
| 6 | One insight sentence from existing data | Health Overview |
| 7 | "Kelly's week" summary | push or local notification |
| 8 | Buy again | Basket row, Today row |
| 9 | Going out now | Outside Partners, "+" sheet |
| 10 | Hazard reports by area | Outside line, "+" sheet |
| 11 | Lost mode | Emergency sheet |
| 12 | Near me: feed filter and recommendations by place | Community chips |
| 13 | Can they eat this? | Emergency sheet |
| 14 | Is it urgent? | Emergency sheet |
| 15 | Card for a sitter or walker | Pet profile "More", Household page |
| 16 | Later: Android widget of Today, park check-in (opt-in) | not in this round |

Dropped: OCR of visit summaries, insurance claims, GPS routes and collars,
paid bookings, barcode and plant-photo recognition, toxicity in grams.

## Rules for every phase

* Branch per phase piece, worktree per agent, merged by the lead, checked
  on the emulator in Hebrew and English, pushed on the owner's word.
* Migrations continue from **0031**; one file per piece, idempotent, RLS and
  explicit policies, SQL tests under `supabase/tests/` (Docker, see
  `tool/test_database.ps1`). Numbers are reserved below.
* `docs/design_rules.md` applies. Phase 0 adds the colour-code and
  "+" sheet rules to it; later phases follow them.
* **Approval gate.** Screens drawn on the canvas are approved: build them.
  Screens the canvas does not draw get a short proposal and mockup from the
  agent first (`tools/agent_board/state/proposals/<agent>/`), and the owner
  approves before the agent builds pages. Those screens are listed per
  phase under "needs a mockup".
* Capabilities: every new feature gets feature-access capabilities
  (`<feature>.view` first, per the `requiredView` rule), on for the
  `beta_testers` group, so content that needs a vet's review can ship
  dark.
* Hebrew strings in the feature's ARB pair from the start; placeholders in
  U+2068/U+2069; the glossary in `lib/l10n/GLOSSARY.md`.
* No paid services, nothing outside the Supabase free plan.

## Phase 0 · Colour code and the one plus

Foundation, no new features, no migration. One agent, two commits.

* `AppArea` enum (care, health, community, store, you) in `lib/theme/`
  with its disc colour; `AppColors.coralTint`, `AppColors.neutral`.
  `AreaDisc` widget (icon in a 34 px disc) in `lib/widgets/`; `AppTag`
  gains an area tone. Replace the existing yellow icon discs by area.
* Bottom nav: the selected tab fills a disc in its area colour; unselected
  icons take the colour as stroke. `PetSwitcher` dot colour = the area of
  the unseen thing.
* `AddSheet` in `lib/widgets/`: title, 3 to 6 rows with area discs. Each tab
  registers rows through a slot (`featureSlot('add-health')` etc. in
  `lib/platform/feature_ui.dart`). Wire: Health (Quick log, Record,
  Medicine, Care routine), Community (Share a moment, Ask a question,
  Recommend, Lost or found, New chat), Outside (Plan a walk or play date,
  Suggest a park), Store (Share a deal, Regular product, Expense). Remove
  the buttons they replace (Quick log and Add record actions on Overview,
  Getting-started tiles, New post / New chat / New ad / Share a deal
  FABs, "Add a regular product"). The park page keeps "Post a meetup
  here", pre-filled.
* Fit tests at 320 px in both languages; `docs/design_rules.md` updated.

Estimate 3 to 4 agent-days. Branches `feature/colour-code` then
`feature/add-sheet` (same agent, in order, since both touch the tab
screens).

## Phase 1 · Today, Done in the notification, usage counts

Needs phase 0. Three agents in parallel on separate folders.

**1a · Today** (branch `feature/today`, `lib/features/today`, LEAD-owned
like `care`)

* `todayProvider`: one list for all pets, merged from care plan items
  (meals, walks, routines in `lib/services/care`), medicine doses
  (`lib/services/pet_records`), basket products running low
  (`basket_logic.dart`), the first-days step, joined meetups for the day.
  Order: overdue, by time, undated; done rows sink and fold after five.
* `TodayCard` on Home right under the hero, replacing the essentials
  reminder row's actions (the essentials item becomes a Today row);
  `TodayRow` = `AreaDisc` + title (pet name when more than one pet) +
  who/when + tick or chevron. A tick calls the existing record paths
  (`CarePlanController.record`, dose sheet logic); undo within an hour.
* Home cards: Feeding, Activity, Health, Spending, First days become
  status only, no pill, the card opens its page; Running low card goes
  (its rows are in Today). The hero, pills and card colours stay.
* Empty day: one sentence and one action.
* Needs a mockup: none (canvas Home board).

**1b · Done in the notification** (branch `feature/notification-actions`,
`lib/notifications`)

* `flutter_local_notifications` action buttons "Done" and "In 15 min" on
  reminder notifications (meals, walks, doses, routines); the background
  callback records through the same paths as the Today tick, offline-safe
  (queue in SharedPreferences, flush at next start, the way
  `CrashReporter` queues).
* "Done" replaces the open-only behaviour decided on 3 October; "In 15
  min" stays.

**1c · Usage counts** (branch `feature/usage-counts`, migration
`0031_usage_counts.sql`)

* `usage_counts(user_id, day, kind, count)` with insert/upsert by the
  owner only, no reads for members; an admin RPC returns daily totals and
  the share of accounts that ticked at least one Today row, for the last
  28 days. No device ids, no screens, no text: kinds are the actions we
  want people to repeat (today_tick, dose_recorded, meetup_joined,
  deal_opened, buy_again, post_created, ...).
* `UsageSink` in `lib/platform/`, batched once a day; an Admin tools row
  "Usage" with a 28-day table. The earlier "daily metrics view" spec the
  owner pasted on 13 October is the reference for the columns.
* Needs a mockup: the Admin "Usage" page (tiny).

Estimate 5 to 6 agent-days for the three together.

## Phase 2 · Household phase 2 and the sitter card

Needs phase 1a (Today rows carry the assignee). Owner must have run 0030
and confirmed push works end to end (Firebase project, `community-push`
deployed) before the push parts can be tested; the rest does not wait.

Branch `feature/household-2`, migration `0032_household_events.sql`. Two
agents: server first (migration, push kinds), then app.

* `household_events` (fed, walked, dose, joined, left, assignment) written
  by triggers on `care_logs`, dose records and membership; the Updates
  list on the Household page reads it; a `household_updates` push kind in
  `push_preferences` (default on for feeding, walks and medicine) feeds
  `push_outbox`; a silent `replan` push so other phones re-plan reminders.
* Delegation: `care_plan_items.assignee_id` (a member or null = anyone),
  `care_assignments(item_id, day, member_id)` for per-day changes, and a
  claim when someone else ticks; "Plan the week" sheet.
* Home chat: a `chat_channels.kind = 'household'` room created with the
  household, members synced from `household_members`, pinned at the top
  of Chat; the Household page row shows the last message and unread.
* Home: the live line under the Today title, the assignee on a row
  ("Dana's turn"), the "Our home" card when the household has more than
  one member. Household page per the canvas board; "Home notifications"
  row under Settings › Notifications too.
* **Sitter card (15):** a shareable image or PDF built from data that
  exists (portions and meal times, medicines and times, vets, allergies,
  quirks from the health profile, emergency card), valid dates typed by
  the owner; from the pet profile "More" and the Household page. Timed
  guest access is a later step.
* Needs a mockup: Plan the week sheet, sitter card layout.

Estimate 6 to 7 agent-days.

## Phase 3 · The weekly loop in Health

Needs phase 0. Three agents in parallel.

**3a · Yearly plan for Israel (4)** (branch `feature/yearly-plan`, no
migration; plans become planned `health_events` with `next_due_on`)

* Plan templates per species and age in Dart data: rabies (yearly, legal),
  the combined vaccine, Spirocerca ("park worm") every 3 months,
  deworming, flea and tick treatment, for dogs and cats; puppy and kitten
  schedules by age. Choosing a plan from the "+" sheet creates the next
  planned records; recording one done schedules the next from its
  interval. Shown in Coming up as "from Kelly's yearly plan".
* An `.ics` share of the next dates (share_plus; no calendar permission).
* The content must be reviewed by a vet before the capability leaves the
  beta group; the sources are listed in the template file.
* Needs a mockup: the plan picker sheet.

**3b · Follow a problem (5)** (branch `feature/health-issues`, migration
`0033_health_issues.sql`)

* `health_issues(pet_id, title, started_on, status, closed_on)`; journal
  observations gain `issue_id` and photo attachments (photos only on the
  free plan's 1 GB; no video); an issue row on Overview while open, a
  filter in Records, and a PDF report per issue (reuse the records PDF
  builder).
* Needs a mockup: the issue page and the "Follow a problem" sheet.

**3c · Insights (6) and the weekly summary (7)** (branch
`feature/insights-weekly`)

* Rules computed on the device from `care_logs` and observations: walk
  minutes this 4 weeks vs the previous 4 (more than 20% down), weight
  moved more than 5% in 8 weeks, three "less than usual" appetite entries
  in 14 days. One sentence on the Health Overview with one link, at most
  one per pet per week, never alarming wording.
* "Kelly's week": one notification on the chosen weekday (Settings ›
  Notifications), composed on the device from the same numbers and the
  next due date; scheduled at app start for the coming week. A server
  version through `push_outbox` comes when push is confirmed live.
* Needs a mockup: none (one line and one notification; wording table for
  the owner).

Estimate 6 to 7 agent-days for the three.

## Phase 4 · The safety hub

Needs phase 0. Two agents.

**4a · Emergency sheet and the two lists (13, 14)** (branch
`feature/safety-tools`, no migration)

* The sheet per the canvas Safety board: primary contact with Call now,
  rows with call and message icons, then Is it urgent?, Can they eat
  this?, Lost mode, Emergency card and kit, Find a clinic nearby, one
  fine-print line.
* **Can they eat this?**: a searchable built-in list of foods and plants
  for dogs and cats with a three-level answer (safe, a little, dangerous)
  and a "call the vet" button; no amounts, no calculator. **Is it
  urgent?**: a list of signs by animal that mean "go now", each leading to
  Call now. Both ship EN+HE behind `safety.view` for beta testers until a
  vet has reviewed the content; sources listed in the data files.
* Needs a mockup: both list pages.

**4b · Lost mode (11)** (branch `feature/lost-mode`, migration
`0034_lost_alerts.sql`)

* One flow from the Emergency sheet: confirm, the lost-pet card is
  generated (exists), a `lost_found` post is created with the pet's facts
  and last-seen place, an alert row with the locality code and an active
  flag, a push to members in the area (the meetups push path by locality),
  sightings = comments on the post, "Found" closes everything.
* Needs a mockup: the lost-mode flow (3 frames).

Estimate 4 to 5 agent-days.

## Phase 5 · The neighbourhood

Needs phase 0; 5a and 5b share `lib/features/outdoors`, so one agent for
both; 5c separate.

**5a · Going out now (9)** (branch `feature/going-out-now`; meetups table,
no new migration if `kind` and `expires_at` suffice, else
`0035_meetups_now.sql`)

* A meetup kind `now`: leaving within 90 minutes from a park or an area,
  expires on its own, shown as the card at the top of Partners, posted
  from the card and from the "+" sheet, push to people who saved that
  park (exists for new ads, max 3 a day).

**5b · Hazard reports (10)** (same branch, migration `0035_hazards.sql`)

* `hazard_reports(locality, park_id?, kind, note, created_by, expires_at)`
  with kinds caterpillars, bait, glass, inspector, other; 7-day expiry;
  "not there any more" votes hide a report after two; rate limited; one
  line above the Partners and Parks lists ("2 hazard reports near you
  this week") opening a list, no map; report from the "+" sheet.
* Needs a mockup: the report form and the list.

**5c · Near me (12)** (branch `feature/near-me`, migration
`0036_posts_locality.sql`)

* Posts and guides requests gain a locality code (from the member's city,
  editable per post); a "Near me" chip on the Feed and Guides filter rows;
  the recommendation post kind gets a place field (name and locality), and
  a "Places people recommend" list under Community search results. No
  booking, no ratings.

Estimate 5 to 6 agent-days.

## Phase 6 · Buy again, QA, docs

**Buy again (8)** (branch `feature/buy-again`, migration
`0037_basket_seller.sql`): a basket item stores the seller link and the
last price; "Buy again" on the basket row and the Today row opens the link
(LinkOpener) and offers "Bought again" afterwards; "N deals on this
product" line under the row from the Store search.

**QA and docs:** golden-probe contact sheets of the changed screens, EN/HE
at 390 and 320; emulator walk; release APK on the S24+; `docs/` pages for
today, household, safety; wiki Design Document and Feature Breakdown;
`design_rules.md` final pass.

Estimate 3 agent-days.

## Order, dependencies, migrations

| Phase | Needs | Runs with | Migrations | Days |
|---|---|---|---|---|
| 0 Colour code, "+" sheet | nothing | alone | none | 3 to 4 |
| 1 Today, Done, usage | 0 | 1a/1b/1c parallel | 0031 | 5 to 6 |
| 2 Household 2, sitter card | 1a, push live | 3, 4, 5 | 0032 | 6 to 7 |
| 3 Health weekly loop | 0 | 2, 4, 5 | 0033 | 6 to 7 |
| 4 Safety hub, lost mode | 0 | 2, 3, 5 | 0034 | 4 to 5 |
| 5 Neighbourhood | 0 | 2, 3, 4 | 0035, 0036 | 5 to 6 |
| 6 Buy again, QA, docs | all merged | alone | 0037 | 3 |

About 32 to 38 agent-days; three to four calendar weeks with two or three
agents running at once. Phases 2 to 5 can start the moment phase 1a is
merged (2) or phase 0 is merged (3, 4, 5).

## Owner steps

Before phase 1: run `0029_rewards_foundation.sql` and `0030_household.sql`
if not yet applied; confirm the Firebase project and `community-push` are
live (push is needed by phases 2, 4b and 5a; everything else works without
it).
Per phase: run the phase's migration in the SQL editor, redeploy the Edge
Functions the phase names, install the release APK, say "push".
Before the capabilities leave the beta group: a vet reviews the yearly plan
templates, the foods and plants list and the urgent-signs list.

## How to judge the round

From the usage counts (phase 1c), 28 days after phase 2 is on the phones:

* Share of active accounts that tick at least one Today row on 4 or more
  days a week (target: half).
* Seven-day return rate of accounts that joined a household versus those
  that did not.
* Which "+" rows and which Emergency rows are used at all (the ones never
  used are candidates to fold deeper, not to delete).
