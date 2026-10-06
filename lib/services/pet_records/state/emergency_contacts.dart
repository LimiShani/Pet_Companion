import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_models.dart';
import 'health_providers.dart';

/// A vet as the emergency pieces show it: plain values, no repository.
class VetContact {
  const VetContact({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.openingHours,
    this.onWhatsApp = false,
  });

  factory VetContact.of(Vet vet) => VetContact(
    id: vet.id,
    name: vet.name,
    phone: vet.hasPhone ? vet.phone.trim() : null,
    address: vet.hasAddress ? vet.address.trim() : null,
    openingHours: vet.openingHours.trim().isEmpty
        ? null
        : vet.openingHours.trim(),
    onWhatsApp: vet.onWhatsApp && vet.hasPhone,
  );

  final String id;

  /// Vet or clinic name.
  final String name;
  final String? phone;
  final String? address;

  /// Free text, as the owner typed it.
  final String? openingHours;
  final bool onWhatsApp;
}

/// The emergency contact person of a pet.
class PersonContact {
  const PersonContact({required this.name, this.phone});

  /// As the owner typed it; empty when only a phone number was given (a
  /// screen then calls the person "Emergency contact" in its own language).
  final String name;
  final String? phone;
}

/// Who to reach for one pet in an emergency.
class EmergencyContacts {
  const EmergencyContacts({
    required this.petId,
    this.regularVet,
    this.emergencyVet,
    this.contact,
  });

  final String petId;
  final VetContact? regularVet;
  final VetContact? emergencyVet;

  /// The emergency contact person.
  final PersonContact? contact;

  /// Nothing is saved at all.
  bool get isEmpty =>
      regularVet == null && emergencyVet == null && contact == null;

  /// At least one phone number can be called.
  bool get hasPhone => primaryPhone != null;

  /// A vet with a phone number is saved (the emergency contact person does
  /// not count here).
  bool get hasVetPhone =>
      regularVet?.phone != null || emergencyVet?.phone != null;

  /// The number to call first: regular vet, else emergency vet, else the
  /// emergency contact.
  String? get primaryPhone =>
      regularVet?.phone ?? emergencyVet?.phone ?? contact?.phone;

  /// The name that goes with [primaryPhone].
  String? get primaryName {
    if (regularVet?.phone != null) return regularVet!.name;
    if (emergencyVet?.phone != null) return emergencyVet!.name;
    if (contact?.phone != null) return contact!.name;
    return null;
  }
}

Duration? _noRetry(int retryCount, Object error) => null;

/// A pet's regular vet, emergency vet and emergency contact person.
///
/// Loading is `AsyncLoading`; nothing saved is data with
/// [EmergencyContacts.isEmpty] (never an error); it refreshes by itself
/// when a vet or the health profile is edited.
final emergencyContactsProvider = FutureProvider.autoDispose
    .family<EmergencyContacts, String>((ref, petId) async {
      final vetsFuture = ref.watch(petVetsProvider(petId).future);
      final profileFuture = ref.watch(healthProfileProvider(petId).future);
      final vets = await vetsFuture;
      final profile = await profileFuture;
      final contactName = profile.contactName.trim();
      final contactPhone = profile.contactPhone.trim();
      return EmergencyContacts(
        petId: petId,
        regularVet: vets.regular == null ? null : VetContact.of(vets.regular!),
        emergencyVet: vets.emergency == null
            ? null
            : VetContact.of(vets.emergency!),
        contact: profile.hasContact
            ? PersonContact(
                name: contactName,
                phone: contactPhone.isEmpty ? null : contactPhone,
              )
            : null,
      );
    }, retry: _noRetry);

/// A failure of [emergencyContactsProvider] or [healthCriticalItemsProvider]
/// in plain English, for logs. On a screen use `healthErrorOf(context, error)`.
String emergencyErrorMessage(Object error) => healthErrorMessage(error);

/// Health information the app keeps asking for until it is filled in.
///
/// [label] and [promptFor] are in English, for logs and tests: the pages
/// that ask for these items (the Pets feature's) word them in the app's
/// language themselves.
enum HealthCriticalItem {
  /// No regular or emergency vet with a phone number.
  vetPhone("A vet's phone number"),

  /// Neither a list of allergies nor "none known".
  allergies('Allergies'),

  /// Neither a list of conditions nor "none known".
  conditions('Medical conditions');

  const HealthCriticalItem(this.label);

  final String label;

  /// What to ask the owner for, e.g. "Add a phone number for Kelly's vet".
  String promptFor(String petName) => switch (this) {
    HealthCriticalItem.vetPhone => "Add a phone number for $petName's vet",
    HealthCriticalItem.allergies => 'Say whether $petName has any allergies',
    HealthCriticalItem.conditions =>
      'Say whether $petName has any medical conditions',
  };
}

/// The health-side critical items still missing for a pet; empty when
/// nothing is missing. Refreshes by itself when a vet or the profile
/// changes. A load error should be read as "unknown", not as "missing".
final healthCriticalItemsProvider = FutureProvider.autoDispose
    .family<List<HealthCriticalItem>, String>((ref, petId) async {
      final contactsFuture = ref.watch(emergencyContactsProvider(petId).future);
      final profileFuture = ref.watch(healthProfileProvider(petId).future);
      final contacts = await contactsFuture;
      final profile = await profileFuture;
      return [
        if (!contacts.hasVetPhone) HealthCriticalItem.vetPhone,
        if (!profile.allergiesAnswered) HealthCriticalItem.allergies,
        if (!profile.conditionsAnswered) HealthCriticalItem.conditions,
      ];
    }, retry: _noRetry);
