# Pet Companion

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

## Signing in

Accounts are in-memory for now (`lib/auth/fake_auth_repository.dart`), so
nothing persists across restarts. A demo account is seeded there; its
credentials are the `demoEmail` / `demoPassword` constants in that file.
Creating an account from the sign-up screen also works within a session.

## Layout

```
lib/
  main.dart                 entry point (ProviderScope)
  app.dart                  MaterialApp.router + theme
  auth/                     AppUser, AuthRepository (+ in-memory fake), AuthController, validators
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
- Backend: Supabase (auth, Postgres, storage, realtime chat)
- Reminders: flutter_local_notifications with timezone scheduling
