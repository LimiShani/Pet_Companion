# PetLoop

A warm, friendly hub for pet owners: pet profiles, feeding and activity tracking,
health log, reminders, community and a bargain store. Flutter, Android + iOS
(web is enabled for quick previews only).

## Run

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
project's URL and publishable key; without them it falls back to an
in-memory auth backend (see "Without Supabase" below).

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
