import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../health/emergency/emergency.dart';
import 'add_pet/add_pet_screen.dart';
import 'icons/pet_icon_bank.dart';
import 'my_pets_screen.dart';
import 'pet_words.dart';
import 'pets_routes.dart';
import 'picture/pet_picture.dart';
import 'profile/basics_sheet.dart';
import 'profile/pet_profile_screen.dart';
import 'state/pet_completeness.dart';
import 'widgets/pet_basics_fields.dart';
import 'widgets/pets_widgets.dart';

/// Opens the add-a-pet flow, full screen (no bottom bar). Returns the new
/// pet, which is already saved and selected, or `null` when the owner left
/// before step 1 was saved.
Future<Pet?> openAddPet(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<Pet>(PetsRoutes.addPet);
  // A page shown on its own, outside the app's router.
  return pushPetsPage<Pet>(context, const AddPetScreen());
}

/// Opens the profile of the pet with [petId]: the edit page, with archive
/// and delete at the end. Nothing opens for an unknown id.
Future<void> openPetProfile(BuildContext context, String petId, {bool fromMyPets = false}) async {
  if (_petOf(context, petId, 'openPetProfile') == null) return;
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(PetsRoutes.profile(petId), extra: fromMyPets ? PetsRoutes.fromMyPets : null);
  } else {
    await pushPetsPage<void>(context, PetProfileScreen(petId: petId, fromMyPets: fromMyPets));
  }
}

/// Opens "My pets": all the owner's pets, the archived ones and "Add a
/// pet".
Future<void> openMyPets(BuildContext context) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(PetsRoutes.myPets);
  } else {
    await pushPetsPage<void>(context, const MyPetsScreen());
  }
}

/// The owner's pet with [petId], archived or not; `null` (and an assert in
/// debug builds) when there is none.
Pet? _petOf(BuildContext context, String petId, String caller) {
  final container = ProviderScope.containerOf(context, listen: false);
  for (final pet in container.read(petsProvider)) {
    if (pet.id == petId) return pet;
  }
  final archived = container.read(petsStoreProvider).byId(petId);
  assert(archived != null, '$caller: no pet with id "$petId"');
  return archived;
}

/// Lets the owner change the picture of the pet with [petId] (photo, icon
/// or none) and saves the choice.
Future<void> changePetPicture(BuildContext context, String petId) async {
  final pet = _petOf(context, petId, 'changePetPicture');
  if (pet == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final picture = await choosePetPicture(
    context,
    petName: pet.name,
    species: pet.species,
    canRemove: pet.hasPhoto || pet.iconKey != null,
    currentIcon: pet.iconKey == null ? null : PetIconChoice.parse(pet.iconKey, species: pet.species),
  );
  if (picture == null) return;
  try {
    // The pet as it is now: the sheet may have been open for a while.
    final current = container.read(petsStoreProvider).byId(petId) ?? pet;
    await savePetPicture(container.read(petsStoreProvider.notifier), current, picture);
  } catch (e) {
    if (context.mounted) showPetsSnack(context, petsErrorOf(context, e));
  }
}

/// Goes straight to where [item] is filled in for the pet with [petId]:
/// Health's vet picker or health profile page for the health items, a small
/// sheet with the one field for the pet's own items, the picture sheet for
/// the photo.
Future<void> openPetInfoItem(BuildContext context, {required String petId, required PetInfoItem item}) async {
  final pet = _petOf(context, petId, 'openPetInfoItem');
  if (pet == null) return;
  final l10n = context.petsL10n;
  switch (item) {
    case PetInfoItem.vetPhone:
      await openHealthCriticalItem(context, petId: petId, item: HealthCriticalItem.vetPhone);
    case PetInfoItem.allergies:
      await openHealthCriticalItem(context, petId: petId, item: HealthCriticalItem.allergies);
    case PetInfoItem.conditions:
      await openHealthCriticalItem(context, petId: petId, item: HealthCriticalItem.conditions);
    case PetInfoItem.microchip:
      await openHealthProfile(context, petId);
    case PetInfoItem.emergencyVet:
      await showVetPicker(context, petId: petId, role: VetRole.emergency);
    case PetInfoItem.age:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: l10n.petAgeTitle(pet.name),
        note: l10n.petAgeNote,
        sections: const {BasicsSection.age},
      );
    case PetInfoItem.weight:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: l10n.petWeightTitle(pet.name),
        note: l10n.petWeightNote,
        sections: const {BasicsSection.weight},
      );
    case PetInfoItem.breed:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: l10n.petBreedTitle(pet.name),
        sections: const {BasicsSection.breed},
      );
    case PetInfoItem.sexAndNeutering:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: l10n.itemSexAndNeutering,
        note: l10n.sexAndNeuteringNote,
        sections: const {BasicsSection.sex, BasicsSection.neutered},
      );
    case PetInfoItem.photo:
      await changePetPicture(context, petId);
  }
}
