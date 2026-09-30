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

export 'checklist_sheet.dart' show showPetChecklist;
export 'data/fake_pets_repository.dart' show FakePetsRepository;
export 'data/pets_repository.dart' show PetsException, PetsFailure, PetsRepository;
export 'data/pets_repository_provider.dart' show petsClockProvider, petsErrorMessage, petsRepositoryProvider;
export 'pet_words.dart';
export 'pet_actions.dart' show changePetPicture, openAddPet, openMyPets, openPetInfoItem, openPetProfile;
export 'state/pet_completeness.dart' show PetCompleteness, PetInfoItem, petCompletenessProvider;
export 'data/pets_repository.dart' show PetPhotoData;
export 'widgets/pet_avatar.dart' show PetAvatar, petPhotoProvider;
export 'widgets/pet_essentials_keeper.dart' show PetEssentialsKeeper;
export 'widgets/pet_reminder_card.dart' show PetAttentionDot, PetReminderCard;
