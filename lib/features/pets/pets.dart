/// What the Pets feature exposes to the rest of the app (the Home
/// dashboard, the Health tab, the shared pet selector). One import:
///
/// ```dart
/// import 'package:pet_companion/features/pets/pets.dart';
/// ```
///
/// Everything runs on providers, so tests use the in-memory fakes. The pets
/// themselves are read as before: `petsProvider` and `selectedPetProvider`
/// in `state/pets_provider.dart`.
library;

export 'data/fake_pets_repository.dart' show FakePetsRepository;
export 'data/pets_repository.dart' show PetsException, PetsRepository;
export 'data/pets_repository_provider.dart' show petsClockProvider, petsErrorMessage, petsRepositoryProvider;
export 'pet_actions.dart';
export 'widgets/pet_avatar.dart' show PetAvatar;
