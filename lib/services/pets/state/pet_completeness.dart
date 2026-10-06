import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../pet_records/state/health_providers.dart';
import '../../pet_records/state/emergency_contacts.dart';
import '../data/pets_repository_provider.dart';

/// What the app knows, or still wants to know, about a pet.
///
/// The first five are the **essentials**: what a vet, an emergency clinic or
/// a poison line asks in the first minute. Only they produce a reminder. The
/// rest is "good to have": it shows in the checklist and nowhere else.
enum PetInfoItem {
  vetPhone,
  allergies,
  conditions,
  age,
  weight,
  photo,
  breed,
  sexAndNeutering,
  microchip,
  emergencyVet;

  bool get isEssential => index <= weight.index;

  /// The five essentials, in the order the reminder asks for them.
  static const essentials = [vetPhone, allergies, conditions, age, weight];

  // The words are in the strings files; give these the strings of the
  // screen's language (`context.petsL10n`).

  /// "A vet's phone number", "Allergies", "Age"...
  String labelIn(PetsL10n l10n) => switch (this) {
    vetPhone => l10n.itemVetPhone,
    allergies => l10n.itemAllergies,
    conditions => l10n.itemConditions,
    age => l10n.itemAge,
    weight => l10n.itemWeight,
    photo => l10n.itemPhoto,
    breed => l10n.itemBreed,
    sexAndNeutering => l10n.itemSexAndNeutering,
    microchip => l10n.itemMicrochip,
    emergencyVet => l10n.emergencyVet,
  };

  /// Why it matters or what counts as an answer, for an open checklist row.
  String hintIn(PetsL10n l10n) => switch (this) {
    vetPhone => l10n.hintVetPhone,
    allergies || conditions => l10n.hintListOrNone,
    age => l10n.hintAge,
    weight => l10n.hintWeight,
    photo => l10n.hintPhoto,
    breed => l10n.hintBreed,
    sexAndNeutering => l10n.hintSexAndNeutering,
    microchip => l10n.hintMicrochip,
    emergencyVet => l10n.hintEmergencyVet,
  };

  /// The button that opens this item, e.g. "Add the vet's phone".
  String actionIn(PetsL10n l10n, String petName) => switch (this) {
    vetPhone => l10n.actionVetPhone,
    allergies => l10n.actionAllergies,
    conditions => l10n.actionConditions,
    age => l10n.actionAge(petName),
    weight => l10n.actionWeight(petName),
    photo => l10n.actionPhoto(petName),
    breed => l10n.actionBreed(petName),
    sexAndNeutering => l10n.actionSexAndNeutering,
    microchip => l10n.actionMicrochip,
    emergencyVet => l10n.actionEmergencyVet,
  };

  static PetInfoItem ofHealth(HealthCriticalItem item) => switch (item) {
    HealthCriticalItem.vetPhone => vetPhone,
    HealthCriticalItem.allergies => allergies,
    HealthCriticalItem.conditions => conditions,
  };
}

/// How complete a pet's essentials are. Worked out from the pet and from
/// Health every time, never stored, so it cannot go stale.
class PetCompleteness {
  const PetCompleteness({
    required this.petId,
    this.missing = const [],
    this.goodToHave = const [],
    this.isKnown = false,
    this.snoozedUntil,
    this.isSnoozed = false,
  });

  final String petId;

  /// Essentials not answered yet, in reminder order. While [isKnown] is
  /// false this holds only what the pet itself lacks (age, weight).
  final List<PetInfoItem> missing;

  /// Recommended items not answered yet.
  final List<PetInfoItem> goodToHave;

  /// False while Health's part is loading or failed to load: its items then
  /// count as unknown, never as missing, so nothing flashes in and out.
  final bool isKnown;

  /// Set by "Not now".
  final DateTime? snoozedUntil;

  /// [snoozedUntil] is still ahead.
  final bool isSnoozed;

  /// The number of essentials.
  int get total => PetInfoItem.essentials.length;
  int get answered => total - missing.length;

  /// The first missing essential: what one tap on the reminder opens.
  PetInfoItem? get next => missing.isEmpty ? null : missing.first;
  bool get isComplete => isKnown && missing.isEmpty;

  /// Something is known to be missing (postponed or not): the dot.
  bool get needsAttention => isKnown && missing.isNotEmpty;

  /// The reminder shows: something is missing and it was not postponed.
  bool get shouldRemind => needsAttention && !isSnoozed;
}

Pet? _find(List<Pet> pets, String id) {
  for (final pet in pets) {
    if (pet.id == id) return pet;
  }
  return null;
}

/// What is missing for the pet with the given id. Synchronous and never
/// throws: there is no loading or error state to handle. It refreshes by
/// itself when the pet, a vet or the health profile changes.
final petCompletenessProvider = Provider.autoDispose
    .family<PetCompleteness, String>((ref, petId) {
      final pet =
          ref.watch(petsProvider.select((pets) => _find(pets, petId))) ??
          ref.watch(archivedPetsProvider.select((pets) => _find(pets, petId)));
      if (pet == null) return PetCompleteness(petId: petId);

      final health = ref.watch(healthCriticalItemsProvider(petId));
      final profile = ref.watch(healthProfileProvider(petId)).value;
      final vets = ref.watch(petVetsProvider(petId)).value;
      final isKnown = health.hasValue;
      final now = ref.watch(petsClockProvider)();
      final snoozedUntil = pet.reminderSnoozedUntil;

      return PetCompleteness(
        petId: petId,
        isKnown: isKnown,
        missing: [
          if (isKnown)
            for (final item in HealthCriticalItem.values)
              if (health.value!.contains(item)) PetInfoItem.ofHealth(item),
          if (!pet.hasAge) PetInfoItem.age,
          if (pet.weightKg == null) PetInfoItem.weight,
        ],
        goodToHave: [
          if (!pet.hasPhoto) PetInfoItem.photo,
          if ((pet.breed ?? '').trim().isEmpty) PetInfoItem.breed,
          if (pet.sex == null || pet.neutered == null)
            PetInfoItem.sexAndNeutering,
          if (profile != null && profile.microchip.trim().isEmpty)
            PetInfoItem.microchip,
          if (vets != null && vets.emergency == null) PetInfoItem.emergencyVet,
        ],
        snoozedUntil: snoozedUntil,
        isSnoozed: snoozedUntil != null && snoozedUntil.isAfter(now),
      );
    });

/// How long "Not now" hides the reminder.
const kReminderSnooze = Duration(days: 7);

/// "Not now": hides the reminder of the pet with [petId] on every screen
/// for [kReminderSnooze]. The dot on the pet's pill stays. Throws a
/// `PetsException` when it cannot be saved.
Future<void> snoozePetReminder(
  ProviderContainer container,
  String petId,
) async {
  final pet = container.read(petsStoreProvider).byId(petId);
  if (pet == null) return;
  final until = container.read(petsClockProvider)().add(kReminderSnooze);
  await container
      .read(petsStoreProvider.notifier)
      .save(pet.withReminderSnoozedUntil(until));
}

/// Makes sure "Soya's essentials are complete" is said once, however many
/// reminders for the same pet are on screen.
class PetCompletionAnnouncer {
  final _last = <String, DateTime>{};

  /// True for the first caller after the pet with [petId] became complete.
  bool claim(String petId, DateTime now) {
    final last = _last[petId];
    if (last != null && now.difference(last).abs() < const Duration(seconds: 5)) {
      return false;
    }
    _last[petId] = now;
    return true;
  }
}

final petCompletionAnnouncerProvider = Provider<PetCompletionAnnouncer>(
  (ref) => PetCompletionAnnouncer(),
);
