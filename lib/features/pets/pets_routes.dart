import 'package:go_router/go_router.dart';

import 'add_pet/add_pet_screen.dart';
import 'my_pets_screen.dart';
import 'profile/pet_profile_screen.dart';
import 'welcome_screen.dart';

/// The locations of the pets pages. Only the router uses them; the rest of
/// the app opens the pages with `openAddPet`, `openPetProfile` and
/// `openMyPets` (see `pets.dart`).
abstract final class PetsRoutes {
  /// The first-pet welcome (and "Could not load your pets").
  static const welcome = '/welcome';

  /// "My pets".
  static const myPets = '/pets';

  /// The add-a-pet flow.
  static const addPet = '/pets/new';

  /// The profile (edit page) of one pet.
  static String profile(String petId) => '/pets/${Uri.encodeComponent(petId)}';

  /// Passed as `extra` when the profile is opened from "My pets".
  static const fromMyPets = 'from-my-pets';

  /// The app's start: from here the router sends a signed-in owner to the
  /// dashboard, or to the welcome when there is no pet.
  static const start = '/';

  /// Where a signed-in owner who has no pet yet may be.
  static bool openWithoutPets(String location) =>
      location == welcome || location == addPet;
}

/// Full-screen routes (no bottom bar), placed beside the tabs.
final petsRoutes = <RouteBase>[
  GoRoute(
    path: PetsRoutes.welcome,
    builder: (context, state) => const WelcomeScreen(),
  ),
  GoRoute(
    path: PetsRoutes.myPets,
    builder: (context, state) => const MyPetsScreen(),
  ),
  // Before the profile, which would otherwise take "new" for a pet id.
  GoRoute(
    path: PetsRoutes.addPet,
    builder: (context, state) => const AddPetScreen(),
  ),
  GoRoute(
    path: '${PetsRoutes.myPets}/:petId',
    builder: (context, state) => PetProfileScreen(
      petId: state.pathParameters['petId']!,
      fromMyPets: state.extra == PetsRoutes.fromMyPets,
    ),
  ),
];
