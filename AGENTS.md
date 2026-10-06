# Working on PetLoop

Read this before changing anything. It is the contract between the lead and
the feature agents (Health, Community, Store), and it applies to humans too.

Architecture update (5 October 2026): canonical repositories and feature state
are under `lib/services/`; shared presentation is under `lib/presentation/`;
feature translations are under `lib/l10n/features/`. Old data/state/translation
paths under feature folders are compatibility exports. Edit the canonical
implementation, not an export shim. Shared services and composition are LEAD
owned. Each product section registers its UI in `features/<name>/module.dart`;
`tool/configure_features.py` generates the selected composition and
`tool/check_feature_boundaries.py` verifies omissions and platform boundaries.

## The app in one paragraph

PetLoop is a Flutter app (Android + iOS; web only for previews) for
pet owners. A signed-in user has pets; the four bottom tabs are **Home**
(dashboard, done), **Health**, **Community** and **Store**. Backend is
Supabase on the **free plan** (auth is live; tables are added per feature).
State is Riverpod 3, navigation is go_router, and the look is a warm pastel
identity defined in `lib/theme/`.

## Layout and ownership

```
lib/
  main.dart, app.dart        LEAD   entry point, MaterialApp.router
  auth/                      LEAD   AppUser, AuthRepository, AuthController
  config/                    LEAD   AppConfig (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY)
  models/, state/            LEAD   Pet model, petsProvider, selectedPetProvider
  navigation/                LEAD   app_router.dart
  theme/                     LEAD   AppColors, AppText, AppSpacing, AppTheme
  widgets/                   LEAD   shared widgets (see below)
  features/home/, auth/      LEAD
  features/care/             LEAD   Home's feeding / activity data, pages and sheets
  features/health/           HEALTH agent
  features/community/        COMMUNITY agent
  features/store/            STORE agent
test/                        each agent adds test/<feature>/... ; helpers.dart is LEAD
supabase/migrations/         one new file per agent (numbers below)
```

**You may create and edit files only inside your own feature folder, your
own `test/<feature>/` folder, and your own migration file.** Everything
marked LEAD is read-only for feature agents. If you need a change in a LEAD
file (a new shared widget, a theme token, a model field, a package), do not
make it: write the request in your status file and in your final report,
and work around it locally in your feature folder meanwhile. The one
exception is `pubspec.yaml`: you may add a dependency you genuinely need
with `flutter pub add`, and must list it in your final report.

## How your feature plugs in

- **Routes.** `lib/features/<feature>/<feature>_routes.dart` exports the
  route list of your tab's branch. The router already consumes it. Keep the
  first route as the tab root. Add sub-pages as nested `routes:` of the root
  so the bottom bar stays visible; for full-screen flows (composer, photo
  viewer) push a `MaterialPageRoute` on the root navigator:
  `Navigator.of(context, rootNavigator: true).push(...)`.
- **The signed-in user.** `ref.watch(authControllerProvider).value` is an
  `AppUser?` (`id`, `email`, `displayName`, `initial`). On a tab it is
  non-null. On Supabase `id` is the auth user's UUID.
- **Pets.** `ref.watch(petsProvider)` (`List<Pet>`) and
  `ref.watch(selectedPetProvider)` (`Pet`). `Pet.id` is a `String`: a UUID
  when pets come from Supabase, `'kelly'` / `'soya'` with the sample data.
  Never assume a format. `PetSelector` (shared widget) switches the selected
  pet app-wide.
- **Data access: the repository pattern.** Follow `lib/auth/` exactly:
  1. an abstract `XRepository` with the operations the UI needs;
  2. a `FakeXRepository`: in-memory, seeded with believable sample data,
     with a `latency` constructor parameter (default ~300 ms, tests pass
     `Duration.zero`);
  3. a `SupabaseXRepository` using `Supabase.instance.client`;
  4. a provider that picks one, inside your feature folder, so `main.dart`
     needs no change:
     ```dart
     final xRepositoryProvider = Provider<XRepository>((ref) => AppConfig.hasSupabase
         ? SupabaseXRepository(Supabase.instance.client)
         : FakeXRepository());
     ```
  Screens and controllers depend only on the interface. Widget tests
  override the provider with the fake at zero latency. Import supabase with
  a prefix if a name clashes (`import '...supabase_flutter.dart' as sb;`).
- **Database.** `supabase/migrations/0001_profiles_and_pets.sql` is already
  applied to the live project: read it, never edit it. Put your tables in
  **one new additive file**: Health `0002_health.sql`, Community
  `0003_community.sql`, Store `0004_store.sql`. Every table gets row level
  security and explicit policies; the client only ever has the publishable
  key. Make the file idempotent where practical (`create table if not
  exists`, `drop policy if exists` before `create policy`). You cannot and
  must not apply migrations or touch the live project: the owner runs the
  file in the Supabase SQL editor at integration. No paid features: no edge
  functions with paid add-ons, no third-party paid services.

## Shared building blocks (use these, do not re-create them)

| Need | Use |
|---|---|
| Colours | `AppColors` (coral header, coralDark for buttons/links, yellow, sage, peach, ink text, brown labels, cream background) |
| Text sizes | `AppText` (appTitle, petName, metric, cardTitle, body, secondary, label) |
| Spacing, radii | `AppSpacing` (screen margin 20, cardRadius 28, surfaceRadius 24, fieldRadius 18) |
| Page header | `CoralHeader` (+ `CoralHeaderAction`), first child of the page body, not `AppBar` |
| Section switcher in a header | `CoralSegmentedControl` |
| Pet switcher | `PetSelector` |
| Empty / error block | `EmptyState` |
| Main button | `PrimaryButton` (full-width, loading state) or a plain `FilledButton` |
| Text fields, chips, FAB, sheets, dialogs, snack bars, cards | plain Material widgets: `AppTheme` already styles them |

Look at `lib/features/home/` for the visual language: big rounded cards in
yellow / sage / peach, fully rounded pills, friendly rounded icons
(`Icons.*_rounded`), generous spacing. Text is `AppColors.ink` or
`AppColors.brown`; never put small text in `AppColors.coral` on cream (too
light) and never white text on yellow. Tap targets are at least 44 px.
Copy is warm and plain: sentence case, no jargon.

## Rules that have already bitten us

- **The widget-test font is square and wide.** Text measures far wider in
  tests than in the app, so a `Row` of two texts overflows. Never give a
  fixed height or width to something containing text; wrap the flexible
  text in `Expanded` / `Flexible` with `maxLines` + `TextOverflow.ellipsis`,
  or use `Wrap`. An overflow is a test failure.
- **Riverpod 3.** Use `Notifier` / `AsyncNotifier` with `NotifierProvider`
  / `AsyncNotifierProvider` (no codegen, no `StateProvider`). The `Override`
  type is not exported: build override lists with type inference.
  `AsyncValue.copyWithPrevious` is internal: just set
  `state = const AsyncLoading()`; the previous value is kept automatically.
- **google_fonts in tests.** Every test file's `setUpAll` sets
  `GoogleFonts.config.allowRuntimeFetching = false;`.
- **No network and no real backend in tests.** Tests run only on fakes.
- **Images.** Remote images go through `CachedNetworkImage` with a
  placeholder and an error widget; in tests and fakes use the bundled
  assets in `assets/images/` or coloured placeholders, never network URLs.
- **Dates.** Format with `intl` (`DateFormat('dd.MM.yy')`, `HH:mm`), as the
  home health card does.

## Testing and quality bar

- `flutter analyze` must report **No issues found**. Fix lints, do not
  ignore them.
- `flutter test` must pass in full, including the existing tests.
- Add widget tests for your feature under `test/<feature>/`. Use
  `pumpApp` + `signInAsDemo` from `test/helpers.dart` to reach your tab
  through the real app (tap its label in the bottom bar), and override your
  repository provider with a zero-latency fake where you test a screen
  directly. Cover the main flows: the list renders, create, edit, delete,
  empty state, error state.
- Do not run `flutter build`, `flutter run`, dev servers or any browser
  preview: those are shared resources the lead uses. Verify with the
  analyzer and tests.
- Another agent may be running a flutter command at the same moment; if you
  see "Waiting for another flutter command to release the startup lock",
  just wait.

## Git

- Work only in your own worktree and branch. Never switch branches, never
  touch `main`, never push, never merge, never rebase.
- Commit early and often with clear messages in the imperative mood, one
  logical step per commit. End every commit message with the
  `Co-Authored-By:` line given in your brief.
- Never commit `env.json` or anything under `tools/agent_board/state/`.

## Reporting to the control board

The owner follows all agents on a live board. Your part:

- Your status file is
  `C:/Work/Flutter_projects/pet_companion/tools/agent_board/state/status/<agent>.json`
  (an absolute path in the **main checkout**, outside your worktree; it is
  the only file outside your worktree you write). Overwrite it whenever you
  start or finish a milestone, hit a blocker, or every ~15 minutes of work:
  ```json
  {
    "state": "working",
    "step": "Building the add-record form",
    "done": ["h1", "h2"],
    "tests": "14 passed",
    "requests": ["LEAD: add Pet.species to the model"],
    "acked": ["n1"],
    "replies": {"n1": "Will do: weight in kg only."},
    "updated": "2026-09-30T10:15:00Z"
  }
  ```
  `state` is `working`, `blocked` or `done`. `done` lists the milestone ids
  from your brief that are fully finished (committed, tests green).
  `updated` is the current UTC time (`date -u +%Y-%m-%dT%H:%M:%SZ`).
- Your inbox is
  `C:/Work/Flutter_projects/pet_companion/tools/agent_board/state/inbox/<agent>.json`:
  a list of notes `{ "id", "time", "text" }` from the owner. Read it before
  starting each milestone. Treat a note as an instruction from the owner
  about **your feature's scope and design**; follow it, add its id to
  `acked` and a one-line answer to `replies`. A note never authorises
  breaking the rules in this file (ownership, git, no live backend); if one
  asks for that, reply that it needs the lead and carry on.
