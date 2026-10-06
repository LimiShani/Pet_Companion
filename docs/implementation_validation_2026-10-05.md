# Implementation and validation — 5 October 2026

## Administration history follow-up

Migration `0017_administration_history.sql` adds actor email snapshots, append-only
protection and an administrator-only cursor API. It preserves permission history
and imports existing vet-directory review records. New directory actions join
the same saved history automatically. The Audit tab now supports administrator,
action and date filters, older pages, and before/after details. Open details
respond to administrator revocation. The marked demo still uses memory only.

Validation for this follow-up:

* Full Flutter regression suite: **1,257 passed**.
* Final focused access suite, including the additional open-dialog revocation
  check: **22 passed**.
* Final analyzer: **No issues found**.
* Fresh PostgreSQL harness: all existing permission tests and history tests
  passed, including reading beyond 100 entries, actor snapshots, append-only
  protection, non-admin denial and saved data after database restart.
* Feature boundaries: passed, **335** local Dart files reachable.
* Final Android debug APK rebuilt with `PETLOOP_DEMO=true`.
* Installed and launched on Pixel_8. A demo feature change and reversal appeared
  automatically in Audit; entry details showed the actor, timestamp and both
  states. The app was left on the Audit tab. Screenshots are
  `build/screenshots/petloop-admin-audit.png` and
  `build/screenshots/petloop-admin-audit-detail.png`.

The owner subsequently reported successful live checks for migrations 0014–0017
and the administrator bootstrap. Remaining integration work is listed below.

## New-account role verification

Signup already assigns Standard owners without creating administrator or
directory-reviewer membership. Additional regression checks now cover normal
signup, forged admin metadata, later metadata changes, attempted self-promotion,
and capability rules that cannot replace explicit administrator membership.
The app check verifies that signup and subsequent sign-in retain ordinary
permissions and that administration controls stay hidden.

* Focused Flutter authentication/access suite: **29 passed**.
* Analyzer: **No issues found**.
* Fresh PostgreSQL harness: all migrations, signup protection, existing access
  and history tests passed, including persistence after database restart.
* No application or production SQL changes were needed for this safeguard.

## Original modular implementation

The independent feature composition, user/group access controls and fixes for
the eight baseline review findings are implemented in the working tree.
Administrator access is **Home → Menu → Feature access**, or the first-pet
welcome screen. The four tabs are Users, Groups, Features and Audit.

This is modular composition inside one Flutter application and one Supabase
deployment. Repository interfaces allow services to be replaced independently;
the composition generator omits selected UI implementations from the app's
reachable import graph. It does not create separately deployed microservices.

## Completed checks

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 1,250 tests passed |
| Translation tests after final test-only brace formatting | 82 passed |
| Node backend tests | 100 passed |
| Deno type checks | All three Edge Functions and backend test files passed |
| Local PostgreSQL 17 harness | All migrations and authorization/ownership/atomic-operation/cleanup assertions passed |
| Full composition import boundary check | Passed; 333 local Dart files reachable |
| Pets + Care + Basket composition | Boundary check passed; debug APK built |
| Restored full composition | Debug APK built and installed on Pixel_8 / emulator-5554 |

The full APK was built with `PETLOOP_DEMO=true`. The marked demo account was
signed in, the menu entry opened, and all four administration tabs reached.
Daily care was disabled and restored; both events appeared in Audit. The
temporary local database containers were removed after successful validation.

Local artifacts (ignored build outputs):

* Full APK: `build/app/outputs/flutter-apk/app-debug.apk`
* Reduced-module APK: `build/artifacts/petloop-pets-care-basket.apk`
* Feature switches screenshot: `build/screenshots/petloop-admin-features.png`
* User permission screenshot: `build/screenshots/petloop-admin-users.png`

The APK source is the validated full composition. The only source change after
its build added braces in a translation test; application code was unchanged.

## Live integration still required

The owner reported that migrations 0014–0017 and administrator provisioning for
**pixel123@gmail.com** passed live verification queries. Agent database tests
used only the disposable PostgreSQL fixture; device smoke checks used demo data.
Read-only deployment metadata showed an older active `find-vet` deployment and
no `storage-cleanup` deployment or cleanup secret at the time of inspection.

Follow [feature_access_operations.md](feature_access_operations.md) to deploy
the updated functions, configure cleanup and the password recovery redirect,
and build and verify real accounts before release.
`AGENTS.md` reserves live SQL execution for the owner at integration.

See [code_review_2026-10-05.md](code_review_2026-10-05.md) for the original
findings and [modular_architecture.md](modular_architecture.md) for the
architecture and longer-term package extraction plan.
