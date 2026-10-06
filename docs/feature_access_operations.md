# Feature modules and administration

## What is implemented

Home, the bottom navigation, contextual profile sections and cross-feature
actions consume module registrations. Product UI lives in `lib/features/`;
shared repository implementations and state live in `lib/services/`;
shared presentation and translations survive removal of a product UI module.
The pure policy contract is the local `packages/petloop_access` package.

Records, schedules, emergency tools, observations, expenses and basket have
independent repository interfaces and Riverpod providers. Override a service
provider to replace its backend without changing other service implementations.
The legacy aggregate repository providers remain as compatibility defaults.

These are independent modules within one Flutter application and one Supabase
deployment. Creating separate deployments or moving every module into a Dart
package remains a subsequent extraction; no network microservices are created.
New code requires an app release. Access changes for shipped features do not.

## Administrator entry

New signups automatically join **Standard owners**, with ordinary feature
permissions and no administrator or vet-reviewer role. Signup names and user
metadata cannot grant either role. Clients cannot write administrator membership
or permission tables directly; administrator provisioning requires privileged
SQL. The dedicated demo account previews administration only in demo mode;
new accounts created in demo mode are ordinary owners too.

Open **Home → Menu → Feature access**. Only an account in `access_admins` sees
the entry or can call the administration APIs. A vet directory reviewer is a
different role and cannot administer permissions. A missing permission schema
shows the access loading error instead of granting access.

An administrator who has no pets yet can also open **Feature access** directly
from the first-pet welcome screen.

* **Users:** select an account, add/remove group memberships, and set individual
  Allow/Deny/Inherit rules. The effective result includes its reason.
* **Groups:** create groups and edit their capability rules.
* **Features:** enable/disable a section for everyone; separately control public
  vet search. Disabling preserves the section's data.
* **Audit:** read saved administration history, including vet-directory reviews.
  Filter by administrator email/UUID, action type and date range. Use **Load older
  actions** to read beyond the first page, and tap an entry for details.

Successful permission changes record their administrator UUID, email snapshot,
UTC timestamp and before/after values in `access_audit`, in the same transaction
as the change. Directory review events retain the reviewer, target, note and
action details and are mirrored into the same history. Older directory events
are imported by migration 0017. Previously recorded emails are backfilled from
accounts still present at migration time; deleted historical accounts may only
have their UUID, or appear as System / database owner when no actor was recorded.

History has no automatic expiry and survives app restarts, administrator email
changes and account deletion. The app cannot fabricate, alter, delete or clear
logs; only permissions administrators can browse them. Failed changes roll back
with their transaction and are not shown as successful actions. Demo history is
in memory, explicitly marked, and resets when the demo app closes.

Precedence: global off; required view permission; individual override; any group
deny; any group allow; otherwise deny. Ownership restrictions always apply.
Administration is provisioned separately and cannot be granted through ordinary
feature rules or disabled from the feature switch screen.

## Activate the live backend

The changes have been tested against an isolated local PostgreSQL fixture.
During setup on 5 October 2026, the owner reported successful live checks for
migrations 0014–0017 and the administrator bootstrap for pixel123@gmail.com.
The repository's `AGENTS.md` assigns live SQL execution to the owner at
integration. Function deployment, scheduled cleanup, recovery redirects and
real-account device verification remain to be completed. The steps below also
serve as the procedure for a fresh project.

1. Confirm existing migrations through `0013` are applied, and take a database
   backup. Apply, in order:
   * `supabase/migrations/0014_feature_access.sql`
   * `supabase/migrations/0015_reliable_operations.sql`
   * `supabase/migrations/0016_permission_endpoint_guards.sql`
   * `supabase/migrations/0017_administration_history.sql`
   * `supabase/migrations/0018_account_deletion_cleanup.sql` (lets accounts
     with stored files be deleted; their files stay queued for clean-up)
   * `supabase/migrations/0019_findvet_service_reads.sql` (turning public vet
     search off keeps the curated directory for signed-in searches)
   * `supabase/migrations/0020_permission_checks_once.sql` (permission checks
     run once per query instead of once per row)
2. Run `supabase/seed/access_admin_bootstrap.sql` in SQL Editor. It provisions
   **pixel123@gmail.com** and aborts if that auth account does not exist. No email
   check or administrator secret is embedded in the mobile client.
3. Redeploy `find-vet`, whose caller authorization now uses `can_use` before
   search/provider access. Deploy `storage-cleanup` and set a strong
   `PETLOOP_CLEANUP_SECRET` as an Edge Function secret. Invoke it periodically
   from a server-owned scheduler with a POST and that secret as the bearer.
   Never put the service role key or worker secret in the app's `env.json`.
4. Add `petloop://auth/reset-password` to the auth redirect URL allowlist.
   Android and iOS register the `petloop` URL scheme. Test a real recovery email
   on a device before release.
5. Build using `--dart-define-from-file=env.json`, sign in as the administrator,
   and open the menu entry. Verify a regular account has no administration entry.

Existing accounts and new signups join the Standard owners group by default,
preserving normal feature access. To provision another permissions administrator,
the owner inserts that account's UUID into `access_admins` using privileged SQL.
For a vet reviewer, both the reviewer role and `findvet.admin` grant are required.

The app refreshes real-account access at most every 60 seconds and on Android/iOS
resume. Database requests enforce revocation immediately. Device content already
viewed or exported cannot be recalled; export controls gate app export actions.
When a refresh fails for a reason unrelated to the account (offline, timeout,
gateway error), the app keeps the last confirmed permissions for up to 10
minutes so open screens and unsaved forms survive; a database or auth refusal,
or a longer outage, still closes access at once.

## Include or omit implementations

```powershell
python tool/configure_features.py --modules pets,care,basket
python tool/check_feature_boundaries.py
flutter build apk --debug --dart-define=PETLOOP_DEMO=true
```

Omitted modules do not register tabs, home cards, profile sections or actions.
Optional actions resolve to no contribution. Shared pet identity/data contracts
remain available to the selected modules. `PETLOOP_MODULES` can further restrict
the installed set at build time; it cannot add an omitted implementation.

Restore the full composition before the usual distribution build:

```powershell
python tool/configure_features.py
python tool/check_feature_boundaries.py
flutter build apk --dart-define-from-file=env.json
```

Debug builds without backend settings use the clearly marked DEMO mode. A
release without backend settings fails unless `PETLOOP_DEMO=true` is explicit.
Demo credentials are `demo@petloop.app` / `kelly1234`; this sample account can
preview administration, and its changes remain in memory only.

## Verify locally

```powershell
flutter analyze
flutter test
node --test "supabase/functions/_tests/*.test.ts"
./tool/test_database.ps1 -ContainerName petloop-permission-tests-fresh
```

The database harness requires Docker, creates a named isolated test container
with no host database port, and runs all migrations plus assertions for grants,
ownership, independent Care and Basket, purchase retries, task patches and
durable file cleanup. History checks cover older pages, filtering, actor/state
snapshots, append-only protection, non-admin denial and persistence across a
database restart. It never uses the project's live backend credentials.
