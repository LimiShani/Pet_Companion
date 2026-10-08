# PetLoop

A warm, friendly hub for pet owners: pet profiles, feeding and activity tracking,
health log, reminders, community and a bargain store. Flutter, Android + iOS
(web is enabled for quick previews only).

## Run

For module composition, administrator access and required migrations, see
[Feature access operations](docs/feature_access_operations.md).
Community (chat, safety, moderation, members) and its migrations 0021 and
0022: [Community](docs/community.md).
Push notifications for community activity (Firebase setup, migration 0023,
the Edge Function): [Push notifications](docs/push_notifications.md).
Crash reports from users' phones (migration 0024, how to read them):
[Crash reports](docs/crash_reports.md).

```bash
flutter pub get
flutter run            # pick a connected device or emulator
flutter run -d chrome  # quick web preview
```

## Check

```bash
flutter analyze
flutter test
```

## Backend: Supabase (free plan)

Accounts and data live in a Supabase project. The app is built with the
project's URL and publishable key. Debug builds without settings use a marked
in-memory demo. Releases require both settings or explicit `PETLOOP_DEMO=true`.

### One-time setup

1. Create a free account at https://supabase.com and a new project (the
   Free plan covers 2 active projects, 500 MB database, 1 GB storage and
   50,000 monthly active users). Pick a region close to you and save the
   database password somewhere safe; the app never needs it.
2. In the dashboard open **SQL Editor > New query**, paste the contents of
   `supabase/migrations/0001_profiles_and_pets.sql` and run it. This creates
   the `profiles`, `pets` and `health_events` tables, the `pet-photos`
   storage bucket, and the row level security policies.
3. Open **Project Settings > Data API** for the **Project URL**, and
   **Project Settings > API Keys** for the **Publishable key**
   (`sb_publishable_...`). A legacy **anon** key works too.
4. Copy `env.example.json` to `env.json` in the project root and paste the
   two values in. `env.json` is gitignored. The publishable key is designed
   to ship in the client; row level security is what protects the data.
5. Optional, recommended while developing: **Authentication > Providers >
   Email > Confirm email** can be turned off so sign-ups work without
   opening a confirmation link. Leave it on for a real release. The free
   plan's built-in mailer is limited to a few emails per hour; add a custom
   SMTP provider under **Authentication > SMTP Settings** before launch.

### Running against Supabase

```bash
flutter run --dart-define-from-file=env.json
flutter build apk --dart-define-from-file=env.json
```

Sessions persist on the device, so a signed-in user stays signed in across
restarts.

### Android release signing

Release builds are signed with the upload key from `android/key.properties`
(gitignored, like the keystore itself):

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`storeFile` is relative to `android/`. Without this file a release build
stops with an error instead of shipping with the debug key. For a local
`flutter run --release` that is never distributed, set
`PETLOOP_ALLOW_DEBUG_SIGNED_RELEASE=true` (or pass
`'-Ppetloop.allowDebugSignedRelease=true'` to Gradle).

### Free plan notes

- Projects on the Free plan pause after 7 days without activity. Restore
  them from the dashboard with one click; nothing is lost.
- Everything in the migration is within the free limits. Storage counts
  pet photos against the 1 GB quota.

### Without Supabase

Run the app with no `--dart-define`s and it uses the in-memory backend in
`lib/auth/fake_auth_repository.dart`. Nothing persists across restarts. A
demo account is seeded there; its credentials are the `demoEmail` /
`demoPassword` constants in that file. Widget tests always use this backend.

## Find a vet

Emergency and long term vet search for Israel, built to add countries as
modules. It needs migration `0012_vet_directory.sql`, two Edge Functions
(`find-vet`, `vet-directory-weekly`), an optional Google Places key and a
weekly schedule: see [docs/find_a_vet.md](docs/find_a_vet.md), section
"Backend setup". Without them the app shows sample data in the demo, and
only PetLoop's own directory against Supabase. Backend tests:

```bash
node --test "supabase/functions/_tests/*.test.ts"
```

### Deno development

Use Deno 2.9 or later for the Supabase Edge Functions. On Windows, install
the CLI using the [official PowerShell installer](https://docs.deno.com/runtime/getting_started/installation/):

```powershell
irm https://deno.land/install.ps1 | iex
deno --version
```

Restart VS Code after installation so it picks up the updated PATH, and
open `pet_companion` as the workspace folder. Install the recommended
`denoland.vscode-deno` extension. Workspace settings enable Deno only for
`supabase/functions`; Dart and Flutter continue to use their own extensions.

From the project root:

```bash
deno task check  # type-check both functions and the existing tests
deno task test   # run the existing node:test suite under Deno
deno task lint   # lint the Edge Functions and tests
deno task fmt    # format only the Edge Functions and tests
```

The tests use fakes and run without network, environment, filesystem, or
subprocess permissions. No npm dependencies are needed for the current
functions. The original Node test command remains supported. Linting currently
reports existing `no-explicit-any` and `require-await` findings; these are
separate from the Deno setup.

## Layout

```
lib/
  main.dart                 entry point (ProviderScope)
  app.dart                  MaterialApp.router + theme
  auth/                     AppUser, AuthRepository (Supabase + in-memory fake), AuthController, validators
  config/                   AppConfig: SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY from --dart-define
  theme/                    palette, spacing, type scale, ThemeData
  models/                   Pet, FeedingStatus, ActivityStatus, HealthEvent
  state/                    Riverpod providers (pets, selected pet)
  navigation/               go_router: auth redirects + a 4-tab StatefulShellRoute
  widgets/                  bottom nav, placeholder screen
  features/
    auth/                   splash, login, sign-up, account sheet (sign out)
    home/                   dashboard (header, hero, feeding/activity/health cards)
    health/ community/ store/   placeholder tabs
assets/images/              pet photo + illustrated card icons
supabase/migrations/        SQL schema (run in the Supabase SQL editor)
env.example.json            template for the local env.json
```

## Design

The home screen follows the redesign brief: coral header with a dog selector,
large circular photo with Breed / Age / Weight pills, three colored dashboard
cards and a Home / Health / Community / Store bottom bar. Colors and type sizes
live in `lib/theme/`.

## Planned stack

- State: Riverpod
- Navigation: go_router
- Local data: Drift (SQLite)
- Backend: Supabase (auth done; Postgres tables, storage, realtime chat next)
- Reminders: flutter_local_notifications with timezone scheduling
