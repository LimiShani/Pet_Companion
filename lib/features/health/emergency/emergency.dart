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

import 'emergency_contacts.dart';
import 'health_profile_form.dart';
import 'vet_picker.dart';

export '../data/health_models.dart' show HealthException, HealthProfile, Vet, VetRole;
export '../state/health_providers.dart' show PetVets, healthErrorMessage, healthProfileProvider, petVetsProvider;
export 'contact_launcher.dart';
export 'emergency_button.dart';
export 'emergency_card_screen.dart' show openEmergencyCard;
export 'emergency_contacts.dart';
export 'emergency_sheet.dart' show callPrimaryEmergencyContact, showEmergencySheet;
export 'health_profile_form.dart' show HealthBasicsSection, HealthProfileScreen;
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

/// Opens Health's profile page (allergies, conditions, microchip, emergency
/// contact, notes) for [petId]. Nothing opens for an unknown pet id.
Future<void> openHealthProfile(BuildContext context, String petId) => openHealthProfileById(context, petId);
