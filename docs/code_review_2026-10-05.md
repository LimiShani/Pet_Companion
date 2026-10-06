# PetLoop code review and project map

Reviewed 5 October 2026, main checkout at `418800d`. This review concerns the current integrated application in `pet_companion`, not the older feature worktrees.

Scope: startup, authentication, routing, shared state, feature repositories and controllers, cross-feature integrations, notifications, localization, SQL migrations, vet Edge Functions, tests, and CI. Generated translations and bundled editorial content were not reviewed line by line. This is a source review with existing automated checks; live Supabase configuration, deployed policies, device behavior, and production data were not inspected. Findings below distinguish code defects from architectural gaps. The proposed migration is in [modular_architecture.md](modular_architecture.md).

## Findings, highest priority first

Implementation follow-up: the eight findings below describe the original
baseline. Final validation is recorded in
[implementation_validation_2026-10-05.md](implementation_validation_2026-10-05.md).
Fixes now include session-bound writes and popup teardown; server
capabilities with user/group administration; atomic First Days task patches;
per-item kit queues and rollback; transactional purchases with stable retry IDs;
recovery routing and new-password form; durable cleanup jobs and a worker; and
explicit demo/release configuration. See
[feature_access_operations.md](feature_access_operations.md) for deployment and
verification. Live migration, Edge Function deployment and real-email recovery
remain owner integration steps, not claims of completed production validation.

### 1. P1 — Late saves can put one account's private state into another account's state

Locations: `lib/features/budget/state/budget_providers.dart:48–81` and `:221–253`; similar missing session checks occur in `lib/features/store/state/store_providers.dart` and `lib/features/community/feed/feed_controller.dart`.

Expenses and basket providers watch the authenticated user during `build()`, but their mutation methods only check `ref.mounted` after awaiting the repository. They do not verify that the account which started the save is still current. The providers live in the root application scope. A dependency rebuild does not itself make every previously started controller method safe.

Trigger: account A starts saving an expense, signs out while the request is delayed, then account B signs in and loads their expenses. When A's save returns, `ExpensesController.save()` calls `_replace()` against the current list and can append A's expense to B's state. RLS can correctly protect the database while this still exposes the returned expense locally. The basket has the same pattern. This is a code-traced race; it was not reproduced against a live backend.

Fix: capture a session generation and user ID at operation start, and reject stale results and queued work before changing state or performing subsequent writes. Dispose account-owned state on session changes. Apply this consistently to repositories, caches, realtime subscriptions, and optimistic write queues. `PetsStore` already supplies useful local precedent with `_ownerId` and `_load` checks. Check both mounted state and session identity: mounted alone is insufficient.

Verification to add: delay A's save, switch to B, load B's list, then complete A's save. Assert that B never receives A's data and that stale follow-on operations do not run.

### 2. P1 for the requested architecture — Feature access is not represented or enforced

Locations: `lib/navigation/app_router.dart:45–71`, `lib/widgets/app_bottom_nav.dart:18`, `lib/features/settings/side_menu.dart`, `supabase/migrations/0003_community.sql`, and `0004_store.sql`.

The app registers four fixed branches and four fixed navigation items. Home cards and menu entries are directly instantiated. Routing gates authentication and pet readiness, not feature permissions. SQL protects ownership and signed-in membership; it does not encode which user or group may use Health, Community, Store, or the other modules. For example, Community and Store read policies allow all authenticated users.

Consequently, adding a UI switch would only hide an entry point. A client could still query the API, while notification targets and manually pushed pages could still reach hidden functionality. This is a gap against the requested user/group access requirement, not a claim that the app violates its existing ownership model.

Fix: introduce a server-owned feature/capability policy, client access snapshot, module registry, guarded navigation, and matching database/storage/Edge Function checks. Keep ownership checks as well as capability checks. See the migration plan for public vet search and shared care-table handling.

### 3. P2 — Rapid First Days edits can lose checklist changes

Locations: `lib/features/firstdays/state/first_days_providers.dart:50–62`, `lib/features/firstdays/data/supabase_first_days_repository.dart:33–36`, and `lib/features/firstdays/first_days_screen.dart:159–163`.

Every tick saves the entire `done_tasks` set and unconditionally installs the returned path. The UI allows another task to be toggled before that save finishes. Starting from no ticks, tapping A then B creates writes `{A}` and `{A,B}`. If the first write completes last, the older whole-row upsert and response can replace the newer result and lose B. Even in the normal completion order, the first response temporarily removes B from local state.

Fix: serialize updates per pet, compute changes from the current state inside the queue, and protect optimistic state from obsolete responses. For multiple devices, make task changes atomic on the server (individual task rows or an operation-based RPC); a client queue alone does not prevent competing devices from overwriting whole arrays.

Existing controller tests await each toggle in sequence. Add out-of-order completion, failure, and concurrent-device tests.

### 4. P2 — An emergency-kit save failure rolls back unrelated successful edits

Location: `lib/features/health/state/emergency_kit.dart:26–39`.

`KitController._put()` captures the entire list and restores it on any save failure. Trigger: toggle A, then B; B saves successfully; A fails. A's catch block reinstalls the list from before both edits, removing B's successful change from the UI. Two writes to the same kit item can also arrive out of order.

Fix: queue per item and roll back only that item's latest failed operation. Preserve changes to other items and ignore obsolete outcomes. Add a delayed failure for A after B succeeds, and rapid toggles of one item.

### 5. P2 — “Bought again” is a non-atomic two-write operation

Locations: `lib/features/budget/state/budget_providers.dart:268–288`, `lib/features/budget/data/supabase_budget_repository.dart:32–44`, and `lib/features/budget/basket/bought_again_dialog.dart:85–108`.

`boughtAgain()` first updates the basket's purchase date/price, then inserts an expense. If expense creation fails, the basket already shows the purchase while the budget does not. If the insert committed but the response was lost, retrying uses another empty expense ID and can create a duplicate. The dialog presents a general save failure without a durable operation identity.

Fix: a transactional purchase RPC updates the basket and inserts the expense together, using a client-generated operation ID with a unique constraint. Repeated submissions must return the original purchase. Mirror that operation in the fake repository.

### 6. P2 — Password recovery stops at sending the email

Locations: `lib/auth/supabase_auth_repository.dart:73–78`, `lib/auth/auth_repository.dart`, `lib/features/auth/login_screen.dart:53–65`, and `lib/navigation/app_router.dart`.

The UI offers “Forgot password” and sends a reset email. The repository has no operation to update a recovered user's password; the router has no recovery destination; auth changes reduce all events to an `AppUser?`. No recovery-event handler or `updateUser` call was found in the application. Even if an external redirect returns a recovery session, the user cannot set a replacement password within this codebase. An independently hosted recovery page could supply this, but none is evidenced here.

Fix: handle the recovery event explicitly, configure the redirect/deep link, add a new-password screen and repository operation, and give that flow priority over the normal first-pet/Home redirects. Verify success, expired links, invalid passwords, and Android/iOS link handling.

### 7. P2 — Failed file deletion is not recoverable after a restart

Locations: `lib/features/pets/data/supabase_pets_repository.dart:54–66` and `lib/features/health/data/supabase_health_repository.dart:168–193`.

Rows are deliberately deleted before files, which preserves documents when the row deletion fails. However, photo-removal failures are discarded, and health-file retry paths exist only in `_leftoverFiles` memory. Trigger: database deletion succeeds, storage deletion fails, then the process exits. The database references and the in-memory retry list are gone, leaving files without a durable cleanup job. These files still consume storage and remain subject to storage access policies; previously issued URLs may also remain usable until expiry.

Fix: record cleanup jobs durably before losing the row references, preferably in a server transaction/outbox, and retry them independently of whether the feature UI is enabled. Deleting a pet must still clean up files from disabled modules.

### 8. P2 — A release missing backend configuration silently becomes a nonpersistent demo

Locations: `lib/main.dart:18–26`, `lib/auth/auth_controller.dart:13`, feature repository providers, and `.github/workflows/ios.yml:35–50`.

No backend configuration means fake repositories in every build mode. Only debug builds print a warning; the iOS workflow explicitly builds the demo when secrets are missing. This is useful for deliberate previews, but an accidentally misconfigured distributable can accept sign-ups and edits which disappear on restart.

Fix: make demo mode an explicit build flavor/configuration, visibly identify it, and fail production builds/startup when required configuration is missing. Preserve fakes through provider overrides in tests.

## What is already working well

- Repository interfaces and injected fake implementations are established across the features. Keep these seams during extraction.
- SQL migrations consistently use RLS and explicit ownership rules; storage uses private buckets and signed URLs. The vet directory hardening migration separates privileged internals from caller-facing wrappers.
- `OrderedWrites` already addresses rapid pet updates, feed likes, and saved deals. Its use can be extended, with session and revision checks.
- Health distinguishes partial medicine/follow-up failures and carries the saved entity into retries, which is better than blindly recreating it.
- English/Hebrew localization, RTL layouts, narrow screens, unsaved changes, emergency flows, notification limits, and backend fallbacks have extensive tests.
- Vet search has injected dependencies, rate limits, daily provider caps, region interfaces, privacy-conscious logging, and an independently tested TypeScript backend.

## Project map: how the application works

`main.dart` initializes Supabase when configured, loads device settings, starts notification support, and installs Riverpod overrides. `PetLoopApp` wires theme, locale, the router, and `NotificationsHost`.

`AuthController` restores the session and observes auth events. `PetsStore` loads the current user's pets; synchronous pet providers supply selected-pet context. The router waits for auth and pets, sends users without a pet to onboarding, and then opens a state-preserving four-tab shell. Many subsidiary pages use root `MaterialPageRoute` pushes rather than registered URLs.

| Area | Current responsibility and storage |
|---|---|
| Auth and settings | Supabase email/password auth; device language, week layout and preferences |
| Pets | Pet CRUD, archive/restore, photos, profile and completeness; `pets`, `pet-photos` |
| Home | Composition of pet profile, daily care, health, budget/basket and First Days cards |
| Health | Records, documents, schedules, medications, observations, saved vets, emergency profile/kit and lost-pet card; health tables and `pet-documents` |
| Daily care | Feeding, food settings, activity and running walks; `pet_care_settings` plus Health-owned care plan/log tables |
| Community | Feed, comments, likes/reports, realtime chat and bundled guides; community/chat tables and `community-photos` |
| Store | Shared and curated external deals, favourites, reports, filtering; store tables; also hosts Budget's basket view |
| Budget and basket | Expenses, health-cost aggregation, recurring purchases, run-out estimates and reminders; `expenses`, `basket_items` |
| First Days | Arrival date, manually ticked tasks, inferred tasks and links to other areas; `pet_first_days` |
| Find a vet | Public search, location/geocoding, country configuration, offline directory fallback and reviewer tools; vet tables, RPC wrappers and two Edge Functions |
| Notifications | Device scheduling, permission/settings, user/pet lifecycle, reminder planning and tap navigation; feature plan inputs and local device state |

### Coupling that prevents independent removal

- Home directly constructs feature widgets. Router, bottom navigation, side menu, and localization have fixed feature lists.
- Pets onboarding/profile/completeness/deletion import Health, and Pets imports First Days. Health also imports Pets UI. These dependencies form cycles at feature level.
- Daily care consumes Health's models, errors, clock, plan and logs; disabling Health's UI cannot remove the underlying shared functionality.
- Budget consumes care providers, Health costs/clock, Store categories/state, and notification services. Store directly imports Budget to host the basket, creating another cycle.
- First Days imports Health/Care data and directly opens Community/Store/Health pages or changes their providers.
- Core notification files import Health, Budget, Care, Store and Pets details. Background loads would still run if only UI visibility were toggled.
- Care, Budget and First Days SQL depend on `health_owns_pet`, although ownership belongs to the shared pet platform.

The existing feature folders are organizational boundaries, but not independently optional modules yet.

## Baseline verification and limits (before implementation)

- `flutter analyze --no-pub`: **No issues found**.
- Full `flutter test --no-pub --reporter expanded`: **1,236 passed, 0 failed** (4 minutes 19 seconds).
- `node --test "supabase/functions/_tests/*.test.ts"`: **83 passed, 0 failed**.
- There are 81 Flutter `*_test.dart` files. The tests use fakes and mocked HTTP; source-string assertions on SQL do not prove live RLS behavior.
- The initial sandboxed Flutter runs stalled and were stopped. The analyzer/test checks were rerun with approval outside the sandbox. The initial Node run was blocked from spawning workers (`EPERM`); the approved rerun passed.
- No app build, preview, deployment, migration application, or live data change was performed. Application source is unchanged.

Add a CI check workflow for analysis, Flutter tests, backend tests, and migration/RLS tests on pull requests. The current workflow builds unsigned iOS on main/manual dispatch but does not run those quality checks. Future access-control tests must run queries as separate users and anonymous callers against a disposable database, including storage, views, RPCs and realtime.
