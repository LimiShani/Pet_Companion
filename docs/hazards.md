# Hazard reports (Outside)

Members warn each other about what is around this week: pine processionary
caterpillars, poison bait, broken glass, dog inspectors handing out fines,
or something else. No map and no author names: a report says what, where
(a dog park, or somewhere in a city), how long ago and a short note. The
approved proposal is `tools/agent_board/state/proposals/neighbourhood/` in
the main checkout (phase 5b of docs/improvement_plan.md).

This file is the design record and the contract between the app
(`lib/features/outdoors/hazards/`, `lib/services/outdoors/`) and the
database (`supabase/migrations/0035_neighbourhood.sql`).

## Owner steps (server)

Nothing here costs money.

1. **Back up**, then run in the Supabase SQL editor, in order:
   - `supabase/migrations/0035_neighbourhood.sql` (after 0028 and 0030;
     it refuses to run before them). It also carries "Going out now" for
     partner ads ([meetups.md](meetups.md)).
   - `supabase/migrations/0036_posts_locality.sql` (posts near me, see
     [community.md](community.md)).
   Both are additive and safe to run twice. 0035 gives
   `community.hazards.view` and `community.hazards.post` to the Standard
   owners group, so every account has hazard reports at once. To switch
   them off for one account: Feature access → Users → the person →
   *Hazard reports · View* (or *· Post*) → Deny.
2. **Clean-up schedule** (optional): run
   `supabase/scheduling/hazards_housekeeping.sql`. It deletes reports 30
   days after they expired, every night at 02:29 UTC (pg_cron). Without it
   nothing breaks: the same clean-up runs on every new report, and
   expired reports are never shown.
3. **Push function**: deploy `community-push` again (it words the
   going-now push of 0035):
   ```bash
   npx supabase@2.119.0 functions deploy community-push --project-ref rogmiiusncgmxjqpwgsn --use-api
   ```
4. If `0028_meetups.sql` is ever run again, run 0035 again after it (it
   replaces `meetup_save` and patches one line of `push_claim`), as for
   0030.

Before 0035 is run the app shows no hazard line and no list (the reads
answer nothing); "Report a hazard" says it could not send.

## The app

- **The line** (`HazardLine`): one white line above the Partners and the
  Parks lists, "2 hazard reports near you this week." and the newest one
  in a few words ("Caterpillars at Ra'anana Park dog run", "Poison bait:
  by the river path", "Broken glass in Kfar Saba"), the community disc and
  a chevron. Nothing when there is no report around (or no
  `community.hazards.view`). "Near you" is Outside's one area
  (`outsideAreaProvider`): the localities within its radius
  (`areaLocalityCodes`), never a position.
- **The list** (`HazardsScreen`, `openHazards`, action `hazards`):
  "Hazards near you", "Reports from members, gone after a week.", then one
  card per report, newest first: the kind's disc and name, the place ("Ra'anana
  Park dog run" or "Somewhere in Kfar Saba") and how long ago, the note,
  **Still there** · **Not there any more** (the reader's vote yellow), and
  "2 say it's still there". One's own report: "Your report" and
  **Delete** (after asking). Empty: "Nothing reported around here this
  week." and **Report a hazard**. The tab's "+" stays on the page.
- **Report a hazard** (`ReportHazardSheet`, `openReportHazard`; the
  Outside "+" row `report-hazard` and the empty list): **What** (five
  chips), **Where** (up to four saved parks, the first chosen; **Another
  park**, the park picker; **Somewhere else in Ra'anana**, Outside's city),
  "What did you see? Where exactly?" (140 characters; needed for
  "Something else"), "Shown to members around here for a week.",
  **Report**. Refusals in words: "That's five for today.".
- **Strings**: `lib/l10n/features/outdoors/` (`hazard*`), Hebrew
  gender-neutral ("סכנות באזור", "עדיין שם" / "כבר לא שם").

### Code map

| Path | What |
|---|---|
| `lib/services/outdoors/data/hazard_models.dart` | `HazardKind`, `HazardReport`, `HazardDraft`, `HazardLimits`, `HazardException` |
| `lib/services/outdoors/data/hazards_repository.dart` | the interface; `fake_hazards_repository.dart` (the server's rules; sample reports around Ra'anana, Kfar Saba and Tel Aviv-Yafo), `supabase_hazards_repository.dart` |
| `lib/services/outdoors/state/hazards_providers.dart` | repository, clock, `areaHazardsProvider` (Outside's area), `shownHazardsProvider` (the line), `HazardsController` (each change bumps `hazardsRevisionProvider`) |
| `lib/services/outdoors/data/park_area.dart` | `areaLocalityCodes`: the localities of an area |
| `lib/features/outdoors/hazards/` | `HazardLine` and the words (`HazardWords`, `hazardIcon`), `HazardsScreen` / `HazardCard`, `ReportHazardSheet` |

`OutdoorsKeeper` and the Partners board's `MeetupsKeeper` keep the hazard
providers listened to while a page covers them (see `CommunityKeeper` in
[community.md](community.md)).

## Database (`0035_neighbourhood.sql`)

| Object | What |
|---|---|
| `hazard_reports` | `locality_code`, `park_id` (optional; its city wins), `kind` (`caterpillars`, `bait`, `glass`, `inspector`, `other`), `note` (140), `created_by`, `created_at`, `expires_at` (7 days), `hidden`, `still_count` / `gone_count` (kept by the vote function) |
| `hazard_votes` | one vote per member and report: `gone` true ("not there any more") or false ("still there") |
| `hazard_board` (view, the reader's rights) | a report with its counts, the reader's own vote (`my_vote`), `mine`, and its park's names, street and position when the reader may see the park |

Rules (row level security with the once-per-statement form; functions are
security definer with `search_path = ''`):

- **Reading.** Members with `community.hazards.view` read reports that are
  neither hidden nor expired; authors always read their own. Never a
  report of someone the reader blocked. Members read only their own
  votes (the counts are on the report).
- **Writing.** Clients never write the tables:
  - `hazard_report(p)` (`community.hazards.post`): `{"kind", "park_id" |
    "locality_code", "note"}`; an active or closed park gives its city;
    "other" needs a note; **five a day** (`rate_limited`); refusals
    `invalid_hazard`.
  - `hazard_vote(id, gone)`: someone else's current report, no block
    either way (`not_open`); voting again changes the vote; two "not
    there any more" from others hide it. Answers whether it is still
    shown.
  - `hazard_delete(id)`: the author only.
- **Clean-up.** `community_private.hazards_housekeeping()` deletes reports
  30 days after they expired: on every new report and from the schedule.
- **Moderation (v1).** The gone votes and the author's delete; no reports
  queue (owner decision, October 2026).
- **Accounts.** Deleting an account deletes its reports and votes.

## Tests

- `test/outdoors/hazards_test.dart`: the fake's rules (city from the park,
  five a day, "other", votes and hiding, the author's delete, a week), the
  Supabase rows and refusals, the area's localities, the line on Partners
  and Parks, no line without reports or access, Hebrew.
- `test/outdoors/hazard_pages_test.dart`: the list (votes, hiding, one's
  own and Delete, empty), the form (the kind, the saved park, somewhere
  else, "other", five a day), Hebrew.
- `test/meetups/neighbourhood_fit_test.dart`: the line, the list and the
  form with real fonts at 320 px, English and Hebrew.
- `supabase/tests/neighbourhood_test.sql` (`tool/test_database.ps1`):
  grants, refusals, the limit, reading, votes, hiding, blocks, deleting,
  the clean-up, account deletion.
