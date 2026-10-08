# Crash reports

Every error the app does not handle is written to the `crash_reports`
table, so the owner learns about a crash on a user's phone without being
told. There is no outside service: the table lives in the project's
Supabase database (free plan), and only permission administrators read it.

```
FlutterError.onError / PlatformDispatcher.onError      (lib/platform/crash_reporting.dart)
  └─ CrashReporter.report ─ one report per distinct error, at most 20 a run
       ├─ queue, saved in the phone's preferences (survives a restart)
       └─ flush ──> crash_reports (RLS: own rows or ownerless; admins read)
                     └─ trigger: 60 rows an hour per account, 300 ownerless
```

## Setup (owner, once)

1. Run `supabase/migrations/0024_crash_reports.sql` in the SQL editor
   (after 0023). Idempotent.
2. Rebuild the app. Nothing else: the sink is on whenever the app is built
   with its Supabase settings. The demo build prints reports to the console
   instead.

## Reading the reports

In the SQL editor, signed in as the project owner, or through the API as an
account with `access.admin`:

```sql
select created_at, app_version, platform, kind, fatal, left(message, 120) as message, user_id
from public.crash_reports
order by created_at desc
limit 50;
```

The most useful columns:

| Column | Meaning |
| --- | --- |
| `kind` | `flutter`: the framework (a build or layout error, the screen may look wrong). `dart`: an uncaught error anywhere else, the operation was lost. `caught`: a feature reported an error it could not recover from. |
| `fatal` | True for `dart` reports. |
| `message`, `stack` | The error and where it happened. Release builds carry obfuscated frames unless the build keeps symbols (`flutter build apk --split-debug-info` is not used yet, so stacks are readable). |
| `context` | What Flutter was doing ("during layout"), or the feature's words. |
| `session_id` | One id per app start: `where session_id = ...` gives the whole run. |
| `app_version`, `build_number`, `platform`, `os_version`, `locale` | Which build, on what. |
| `user_id` | The signed-in account at sending time, or null before sign-in. Deleting the account leaves the row and clears this. |

Group by message to see what hurts most:

```sql
select left(message, 100) as message, count(*), max(created_at) as last_seen, max(app_version) as newest
from public.crash_reports
where created_at > now() - interval '14 days'
group by 1 order by 2 desc;
```

## Housekeeping

Old rows are deleted by an administrator (or a scheduled job calling the
same function):

```sql
select public.crash_reports_prune(90);  -- rows older than 90 days; never under 7
```

## Behaviour on the phone

- A report goes out at once when the backend answers; otherwise it waits in
  the phone's preferences and goes on the next report or the next start.
- The same error reports once per run, and a run reports at most 20 errors,
  so a crash loop does not flood the table. The table drops rows over the
  hourly limits quietly.
- A report the backend rejects three times is dropped, so a bad row never
  blocks the queue.
- A feature can report an error it caught through `crashReporterProvider`
  (`kind: 'caught'`); it is `null` in tests.

## Tests

- `test/platform/crash_reporting_test.dart`: reporting, clipping, the
  per-run cap, the queue across restarts, dropped poison rows, the handlers.
- `supabase/tests/crash_reports_test.sql` (in `tool/test_database.ps1`):
  who may write and read, forged owners, the rate limit, the prune.
