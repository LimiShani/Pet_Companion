import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../health/emergency/emergency.dart';
import 'add_pet/add_pet_screen.dart';
import 'data/pets_repository_provider.dart';
import 'icons/pet_icon_bank.dart';
import 'pets_routes.dart';
import 'picture/pet_picture.dart';
import 'profile/basics_sheet.dart';
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
    if (context.mounted) showPetsSnack(context, petsErrorMessage(e));
  }
}

/// Goes straight to where [item] is filled in for the pet with [petId]:
/// Health's vet picker or health profile page for the health items, a small
/// sheet with the one field for the pet's own items, the picture sheet for
/// the photo.
Future<void> openPetInfoItem(BuildContext context, {required String petId, required PetInfoItem item}) async {
  final pet = _petOf(context, petId, 'openPetInfoItem');
  if (pet == null) return;
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
        title: "${pet.name}'s age",
        note: 'A birthday, or a guess: both count.',
        sections: const {BasicsSection.age},
      );
    case PetInfoItem.weight:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: "${pet.name}'s weight",
        note: 'Every dose starts with the weight.',
        sections: const {BasicsSection.weight},
      );
    case PetInfoItem.breed:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: "${pet.name}'s breed",
        sections: const {BasicsSection.breed},
      );
    case PetInfoItem.sexAndNeutering:
      await showPetBasicsSheet(
        context,
        pet: pet,
        title: 'Sex and neutering',
        note: '"Not sure" is an answer too.',
        sections: const {BasicsSection.sex, BasicsSection.neutered},
      );
    case PetInfoItem.photo:
      await changePetPicture(context, petId);
  }
}
