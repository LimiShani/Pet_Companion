# Insights and "Kelly's week" (phase 3c)

Two small things computed on the phone from what the owner already logs:
one calm sentence at the top of the Health Overview, and one weekly
summary notification per pet. Both need the capability
`health.insights.view` (migration 0038, Beta testers only for now).

## Owner steps

1. Run `supabase/migrations/0038_health_plans.sql` (see
   `docs/yearly_plan.md`); it adds `health.insights.view` for the Beta
   testers.
2. To open both to everyone: give `health.insights.view` to the Standard
   owners group (SQL in the header of 0038).

Nothing is sent to the server: no table, no push. A server version of
the weekly summary through `push_outbox` can follow once push is live.

## The insight line

Rules (`lib/services/insights/insight_rules.dart`), first that holds wins:

1. Appetite logged "less than usual" 3 or more times in the last 14 days.
2. Weight moved more than 5% within 8 weeks (the latest weight, from the
   last 4 weeks, against the earliest of the 8 weeks before it, at least
   a week apart), up or down.
3. Walk minutes of the last 28 days more than 20% below the 28 before
   (each period needs at least 4 done walks with minutes; routines' walks
   and extra walks count).

At most one insight per pet per ISO week: the first one shown is
remembered on the phone (`insight_shown:<petId>` = `2026-W42|shorterWalks`)
and is the only one shown that week. The card has the health disc, the
sentence and one link (the activity page, Records on the weight, Records
on the journal). Never a diagnosis.

| Rule | English | Hebrew |
|---|---|---|
| Walks | {pet}'s walks were shorter than last month. Worth a word with your vet if it goes on. | הטיולים של {pet} היו קצרים יותר מבחודש שעבר. אם זה נמשך, כדאי לדבר על זה עם הווטרינר. |
| Weight up | {pet}'s weight went up by about {percent}% in the last few weeks. Worth a word… | המשקל של {pet} עלה בכ־{percent}% בשבועות האחרונים. אם זה נמשך… |
| Weight down | {pet}'s weight went down by about {percent}% in the last few weeks. Worth a word… | המשקל של {pet} ירד בכ־{percent}% בשבועות האחרונים. אם זה נמשך… |
| Appetite | In the last two weeks you noted {count} times that {pet} ate less than usual. Worth a word… | בשבועיים האחרונים נרשם {count} פעמים שהתיאבון של {pet} היה פחות מהרגיל. אם זה נמשך… |

## "Kelly's week"

One local notification per pet (`NotificationKind.weekly`, sync group
`week:<petId>`, no Done button), on the weekday and time chosen in
Settings › Notifications (default: the first day of the week from
Settings › Week, at 09:00; on by default; quiet hours hold it until 07:00).
`ReminderCoordinator` plans it with each pet's reminders (sign-in, and
again after an hour away or on a new day); the language, the week and the
chosen day and time re-plan it at once.

The body (`lib/services/insights/weekly_summary.dart`,
`lib/notifications/weekly_summary_planner.dart`) counts the week before
the one the summary rings in, up to the day it is composed:

* walks: the walk routines' occurrences done, of those planned (or the
  walks logged, when no routine is planned);
* doses: medicine reminders answered "given", of those planned. A reminder
  nobody answered is not called missed;
* the next planned record from the ring day on.

Nothing to say (no routine, no medicine, nothing planned): no
notification.

| Part | English | Hebrew |
|---|---|---|
| Title | Kelly's week | השבוע של קלי |
| Line 1 | Last week: 9 of 12 walks · 14 of 14 doses given | בשבוע שעבר: 9 מתוך 12 טיולים · 14 מתוך 14 מנות ניתנו |
| Line 2 | Rabies vaccine due in 3 weeks (today / tomorrow / in N days / on dd.MM.yy) | חיסון כלבת בעוד 3 שבועות (היום / מחר / בעוד N ימים / בתאריך …) |

## Tests

`test/health_plan/insight_rules_test.dart`, `insight_line_test.dart`,
`weekly_summary_test.dart`, `weekly_app_test.dart`.
