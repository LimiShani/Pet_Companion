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

## Layout

```
lib/
  main.dart                 entry point (ProviderScope)
  app.dart                  MaterialApp.router + theme
  theme/                    palette, spacing, type scale, ThemeData
  models/                   Pet, FeedingStatus, ActivityStatus, HealthEvent
  state/                    Riverpod providers (pets, selected pet)
  navigation/               go_router with a 4-tab StatefulShellRoute
  widgets/                  bottom nav, placeholder screen
  features/
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
