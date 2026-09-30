/// What the Health feature exposes to the rest of the app (the Home
/// dashboard's emergency control, the add-a-pet flow). One import:
///
/// ```dart
/// import 'package:pet_companion/features/health/emergency/emergency.dart';
/// ```
///
/// Everything runs on providers, so tests use Health's in-memory fake.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/health_providers.dart';

import 'emergency_contacts.dart';
import 'health_profile_form.dart';
import 'vet_picker.dart';

export '../data/health_models.dart' show HealthException, HealthProfile, KitItem, Vet, VetRole;
// The emergency kit: `ref.watch(emergencyKitProvider(petId))` gives how many
// items are ready (`ready`) out of how many apply to the pet (`total`).
export '../state/emergency_kit.dart' show EmergencyKit, KitEntry, emergencyKitProvider;
export '../state/health_providers.dart'
    show PetVets, healthErrorMessage, healthProfileProvider, petVetsProvider, removeHealthFilesForPetProvider;
export 'contact_launcher.dart';
export 'emergency_button.dart';
export 'emergency_card_screen.dart' show openEmergencyCard;
export 'emergency_contacts.dart';
export 'emergency_kit_screen.dart' show openEmergencyKit;
export 'emergency_sheet.dart' show callPrimaryEmergencyContact, showEmergencySheet;
export 'health_profile_form.dart' show HealthBasicsSection, HealthProfileScreen;
// The "my pet is lost" page: builds a card to share; posts nothing itself.
export 'lost_pet_card_screen.dart' show openLostPetCard;
export 'vet_form_screen.dart' show openVetForm;
export 'vet_picker.dart' show PetVetTile, showVetPicker;

/// Opens the place where [item] is filled in: the vet picker for a missing
/// phone number, the health profile page for allergies and conditions.
Future<void> openHealthCriticalItem(
  BuildContext context, {
  required String petId,
  required HealthCriticalItem item,
}) async {
  switch (item) {
    case HealthCriticalItem.vetPhone:
      await showVetPicker(context, petId: petId);
    case HealthCriticalItem.allergies:
    case HealthCriticalItem.conditions:
      await openHealthProfile(context, petId);
  }
}

/// Removes every stored health file of [petId] (photos and PDFs attached to
/// its records). Call it before deleting a pet. The same function is
/// available without a context as `ref.read(removeHealthFilesForPetProvider)`.
Future<void> removeHealthFilesForPet(BuildContext context, String petId) =>
    ProviderScope.containerOf(context, listen: false).read(removeHealthFilesForPetProvider)(petId);

/// Opens Health's profile page (allergies, conditions, microchip, emergency
/// contact, notes) for [petId]. Nothing opens for an unknown pet id.
Future<void> openHealthProfile(BuildContext context, String petId) => openHealthProfileById(context, petId);
