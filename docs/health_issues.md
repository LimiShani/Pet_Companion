# Follow a problem (Health, phase 3b)

A problem the owner follows over days or weeks ("Limping, right front
leg"): when it started, optionally where on the body, open or resolved,
its Quick log entries and their photos, and a PDF for the vet. A record of
what the owner noticed, in their words, never a diagnosis.

## For the owner: before a build with this talks to Supabase

1. Apply `supabase/migrations/0033_health_issues.sql` (after 0031) in the
   Supabase SQL editor. It is additive and can be run again safely.
2. Nothing else: no new bucket (photos use `pet-documents`), no Edge
   Function, no new capability (the problem screens follow
   `health.records.view` / `health.records.edit`, the PDF
   `health.records.export`), no push.
3. The database test is `supabase/tests/health_issues_test.sql`, run by
   `tool/test_database.ps1` (disposable Docker PostgreSQL only).

Until 0033 is applied, Quick log entries still save (the app sends
`issue_id` only when an entry belongs to a problem); only the problem
screens fail.

## Where it shows

| Place | What |
|---|---|
| Health "+" | "Follow a problem", after the Quick log (`AddEntry` id `follow-problem`, order 5). Opens the sheet; saving opens the problem's page with the Quick log on it. |
| Overview, rows card | One row per open problem after the health profile, newest first, at most 3; more fold into "N more problems", which opens Records on the first one not listed. Resolved problems are not shown. |
| Problem page | Summary (Ongoing / Resolved, since when, body area, counts), "Add an entry", the entries newest first with their photos, "Mark as resolved" / "Open again", Share report (PDF), More: Rename, Stop following. |
| Quick log | While the pet has an open problem: "Part of a problem" (None by default from the "+", chosen already from the page). An entry of a problem takes up to 4 photos (camera or photos; JPEG, PNG, WebP, 5 MB each). |
| Records | A chip per problem (open, or resolved in the last 90 days) after the other chips; it lists that problem's entries and links to its page. |

Copy, EN and HE: `lib/l10n/features/health/health_*.arb`, keys `issue*`,
`addFollowProblem*`, `errPhotoType`, `errTooManyPhotos`, `errTooManyIssues`.

## Data

* `health_issues`: id, pet_id, owner_id (the pet's owner, set by the 0030
  trigger), title (1 to 80), body_area (optional, up to 60), started_on,
  status open / resolved, resolved_on, created_by (the server), created_at,
  updated_at. Household members share them (`health_owns_pet`). At most 20
  new problems per pet per day (`rate_limited`).
* `health_observations.issue_id`: the problem of an entry, of the same pet
  (composite foreign key). Deleting the problem keeps the entries and
  clears the link. Saving an entry never clears a link; taking an entry out
  of its problem is `linkEntry(entry, null)`.
* Entry photos are rows of `health_documents` with `observation_id`
  instead of `record_id` (one of the two, never both), files at
  `<user>/<pet>/<entry>/<file>` in `pet-documents`, photos only, at most 4
  per entry (`too_many_photos`). The existing clean-up queue, the household
  read policy, the own-folder check, pet deletion and account deletion all
  cover them unchanged. `fetchDocuments` lists record files only; entry
  photos are `fetchEntryPhotos`.

Code: `lib/services/pet_records/data/issue_models.dart`, the
`HealthIssuesRepository` contract in `contracts.dart` (fake and Supabase
in the two repositories), state in
`lib/services/pet_records/state/health_issues.dart`, screens in
`lib/features/health/issues/`, the PDF in
`lib/features/health/share/issue_report.dart` and `issue_share.dart`.

## The PDF

Built by the records' builder (`PdfHealthPdfBuilder`): title "Kelly:
Limping, right front leg", the pet line, prepared on/by, then Started on,
Status, Body area, Entries, and one table row per entry (date and time, how
it was, what, notes) with its photos as small thumbnails. Hebrew reads
right to left in the embedded Fredoka; a photo that cannot be read is left
out.

## Sample data

Without Supabase the app follows Kelly's "Limping, right front leg" since
3 June 2025: four mobility entries (3, 5, 7 and 9 June), two with a photo
(coloured squares). Tests get it with
`FakeHealthRepository(seedIssue: true)`; the default fake has no problem,
so the journal of other tests keeps its nine entries.
