import 'package:go_router/go_router.dart';

import 'welcome_screen.dart';

/// The locations of the pets pages. Only the router uses them; the rest of
/// the app opens the pages with `openAddPet`, `openPetProfile` and
/// `openMyPets` (see `pets.dart`).
abstract final class PetsRoutes {
  /// The first-pet welcome (and "Could not load your pets").
  static const welcome = '/welcome';

  /// The add-a-pet flow.
  static const addPet = '/pets/new';

  /// Where a signed-in owner who has no pet yet may be.
  static bool openWithoutPets(String location) => location == welcome || location == addPet;
}

/// Full-screen routes (no bottom bar), placed beside the tabs.
final petsRoutes = <RouteBase>[
  GoRoute(path: PetsRoutes.welcome, builder: (context, state) => const WelcomeScreen()),
];
