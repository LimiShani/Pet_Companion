# Usage counts

PetLoop learns which actions people repeat without an analytics service:
each phone counts a fixed list of actions per day and sends the day's
numbers once a day to the project's own Supabase database (free plan).
No device ids, no screens, no text, no pet, deal or post ids: only how many
times an account did each kind of action on a day. Only permission
administrators (`access.admin`) read the totals, and only as totals across
all accounts.

```
a service's success point ─ ref.read(usageProvider).count(UsageKind.x)     (lib/platform/usage.dart)
  └─ UsageCounter: tally per account and local day, in the phone's preferences
       └─ at start, sign-in or resume, once a day ──> usage_add(p_day, p_counts)   (0031)
                                                         └─ public.usage_counts (no API access)
Admin tools > Usage ──> usage_summary(28) ──> 28-day table                  (lib/features/settings/usage_screen.dart)
```

## What is counted

| Kind | Counted when | Where (the success point) |
| --- | --- | --- |
| `today_tick` | a Today row is ticked | added by the lead with the Today list (the kind exists: `UsageKind.todayTick`) |
| `care_logged` | a meal, walk or routine is logged (done, skipped or not sure) | `CarePlanController.record`, `lib/services/pet_records/state/health_providers.dart` |
| `dose_recorded` | a medicine dose is recorded | same call, when the log belongs to a medicine |
| `record_added` | a new health record is saved (not edits, not "mark done") | `RecordsController.save`, same file |
| `quick_log` | a new Quick log entry is saved | `ObservationsController.save`, same file |
| `meetup_joined` | "I want to join" on a meetup | `MeetupsController.answer`, `lib/services/meetups/state/meetups_providers.dart` |
| `meetup_posted` | a new meetup is posted (not edits) | `MeetupsController.save`, same file |
| `post_created` | a community post is published | `FeedController.create`, `lib/features/community/feed/feed_controller.dart` |
| `comment_created` | a comment is published | `CommentsController.add`, same file |
| `chat_message_sent` | a chat message is delivered | `ChatRoomController._deliver`, `lib/features/community/chat/chat_providers.dart` |
| `deal_opened` | a deal's page opens | `DealDetailScreen` (`initState`), `lib/features/store/deal_detail_screen.dart` |
| `deal_shared` | a deal is shared | `DealsController.share`, `lib/services/store/state/store_providers.dart` |
| `basket_bought_again` | "Bought again" on a basket product | `BasketController.boughtAgain`, `lib/services/budget/state/budget_providers.dart` |
| `expense_added` | a new expense is saved (not edits) | `ExpensesController.save`, same file |
| `emergency_opened` | the Emergency sheet opens | `showEmergencySheet`, `lib/features/health/emergency/emergency_sheet.dart` |
| `find_vet_opened` | Find a vet opens | `FindVetScreen` (`initState`), `lib/features/findvet/find_vet_screen.dart` |
| `household_invite_sent` | a new household invitation code is made | `HouseholdsController.inviteFor`, `lib/services/household/state/household_providers.dart` |
| `app_opened` | the app starts, an account signs in, or the app comes back, on a new day (once a day) | `UsageCounter.resumed`, called by `StorageMaintenanceHost` in `lib/platform/storage_cleanup.dart` |

Each hook sits after the backend accepted the change, so a failed save
counts nothing. To count a new action: add the kind to
`0031_usage_counts.sql` (the check and `usage_private.kinds()`, in a new
migration once 0031 is applied), apply it, then add it to `UsageKind` and
the Usage page's labels, and call `count` at the action's success point.
The backend refuses a call carrying a kind it does not know, so the
database goes first.

## Behaviour on the phone

- `count` returns at once and never throws. It adds one to today's tally
  of the signed-in account (the phone's local day), capped at 500 a kind,
  and saves the tally in the preferences (`usage_counts.tally`).
- At start, sign-in and resume, `resumed` counts `app_opened` once a day,
  then sends when the last complete send was on another day: one
  `usage_add` call per day kept (today, yesterday, the day before),
  oldest first. What was sent is subtracted; counts made while a call was
  out wait for the next day.
- A failed call keeps its day; the next try waits 6 hours. Days older than
  the day before yesterday are dropped, so a phone that stays offline (or
  closed) for three days loses the counts of its last active day. The day
  of each opening is always sent at once, with that opening.
- Nothing is counted while signed out, in the demo (no Supabase settings)
  or in tests (`usageProvider` is off unless a test overrides it).

## The database (0031)

- `public.usage_counts(user_id, day, kind, count)`, primary key
  `(user_id, day, kind)`, `count` between 1 and 500, `kind` from the list
  above. Row level security with a restrictive "nobody" policy and no
  grants: members cannot read, insert, change or delete rows, not even
  their own.
- `usage_add(p_day date, p_counts jsonb)`: the signed-in account adds
  `{"care_logged": 3, ...}` to its row of `p_day`. Accepts a day from two
  days before the server's day to one after (phones in other time zones),
  only known kinds, whole counts from 1; adds and caps at 500. At most 30
  calls an account a server day (`rate_limited`, hint `slow_down`); the
  app makes at most three a send.
- `usage_summary(p_days int default 28)`: permission administrators only
  (`access_private.require_admin`, like the access administration). One
  element a day, newest first, days without counts included:
  `{"day", "active", "today_tick_share", "kinds": {"<kind>": {"accounts", "total"}}}`.
- `usage_private.housekeeping()`: deletes rows older than 400 days and the
  rate limit's counters after a week. Scheduled by
  `supabase/scheduling/usage_housekeeping.sql` (pg_cron, daily 02:17 UTC).
- Deleting an account deletes its rows (`on delete cascade`).

## Owner steps

1. Run `supabase/migrations/0031_usage_counts.sql` in the SQL editor
   (after 0030). Idempotent.
2. Run `supabase/scheduling/usage_housekeeping.sql` in the SQL editor
   (once; safe to run again).
3. Review the Privacy Policy change (`docs/legal/privacy.html` and
   `privacy.he.html`, version 1.2 of 15 October 2026: a "Usage counts" row
   in section 2 and two lines in section 5) and republish the pages
   (see `docs/legal_pages.md`).
4. Rebuild the app. Counting starts with the Supabase build; the demo
   counts nothing.

## Reading the Usage page

Admin tools > Usage (permission administrators only):

- **Last 28 days**, newest first: the day, **Active** (accounts with any
  count that day, including opening the app) and **Today ticks** (the
  share of those accounts that ticked at least one Today row; a dash on a
  day nobody was active). A phone sends a day's actions the next time it
  opens on a later day, so today and yesterday fill in over the next day
  or two.
- **Actions**: every kind with its total over the last 7 and 28 days, all
  accounts together. A kind at 0 is an action nobody used.

For more than the page shows, in the SQL editor:

```sql
select * from jsonb_array_elements(public.usage_summary(90));  -- as an administrator, through the API
select day, kind, count(*) as accounts, sum(count) as total
from public.usage_counts
where day > current_date - 28
group by day, kind order by day desc, kind;                    -- as the project owner
```

The round's measures (docs/improvement_plan.md, "How to judge the round")
come from these rows: days a week with `today_tick` per account, and
seven-day returns (`app_opened`) of household members versus others.

## Tests

- `supabase/tests/usage_counts_test.sql` (run by `tool/test_database.ps1`):
  no direct access, usage_add's checks, caps and rate limit, the summary
  for administrators only, housekeeping and account deletion.
- `test/platform/usage_test.dart`: the tally, day rollover, three days
  kept, once-a-day sending, failures, signed out and the demo, the
  Supabase sink and summary (MockClient).
- `test/platform/usage_hooks_test.dart`: in the real app, signing in sends
  the opening and opening a deal is counted.
- `test/settings/usage_screen_test.dart`: the Admin tools row (admins
  only), the table, empty and error states, Hebrew on a small phone.
