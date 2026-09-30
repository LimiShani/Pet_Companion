import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../health/emergency/emergency.dart';
import '../data/pets_repository_provider.dart';

/// What the app knows, or still wants to know, about a pet.
///
/// The first five are the **essentials**: what a vet, an emergency clinic or
/// a poison line asks in the first minute. Only they produce a reminder. The
/// rest is "good to have": it shows in the checklist and nowhere else.
enum PetInfoItem {
  vetPhone("A vet's phone number", 'So Emergency can call'),
  allergies('Allergies', 'A list, or "None known"'),
  conditions('Medical conditions', 'A list, or "None known"'),
  age('Age', 'A birthday, or "about 3 years"'),
  weight('Weight', 'A rough number is fine'),
  photo('A real photo', 'Helps most if your pet is lost'),
  breed('Breed', '"Mixed or not sure" is an answer'),
  sexAndNeutering('Sex and neutering', 'Asked on vet forms'),
  microchip('Microchip', 'Finds a lost pet'),
  emergencyVet('Emergency vet (24 h)', 'A night-time fallback');

  const PetInfoItem(this.label, this.hint);

  final String label;

  /// Why it matters or what counts as an answer, for an open checklist row.
  final String hint;

  bool get isEssential => index <= weight.index;

  /// The five essentials, in the order the reminder asks for them.
  static const essentials = [vetPhone, allergies, conditions, age, weight];

  /// The button that opens this item, e.g. "Add the vet's phone".
  String actionFor(String petName) => switch (this) {
        vetPhone => "Add the vet's phone",
        allergies => 'Answer about allergies',
        conditions => 'Answer about conditions',
        age => "Add $petName's age",
        weight => "Add $petName's weight",
        photo => 'Add a photo of $petName',
        breed => "Add $petName's breed",
        sexAndNeutering => 'Add sex and neutering',
        microchip => 'Add the microchip number',
        emergencyVet => 'Add an emergency vet',
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
final petCompletenessProvider = Provider.autoDispose.family<PetCompleteness, String>((ref, petId) {
  final pet = ref.watch(petsProvider.select((pets) => _find(pets, petId))) ??
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
      if (pet.sex == null || pet.neutered == null) PetInfoItem.sexAndNeutering,
      if (profile != null && profile.microchip.trim().isEmpty) PetInfoItem.microchip,
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
Future<void> snoozePetReminder(ProviderContainer container, String petId) async {
  final pet = container.read(petsStoreProvider).byId(petId);
  if (pet == null) return;
  final until = container.read(petsClockProvider)().add(kReminderSnooze);
  await container.read(petsStoreProvider.notifier).save(pet.withReminderSnoozedUntil(until));
}

/// Makes sure "Soya's essentials are complete" is said once, however many
/// reminders for the same pet are on screen.
class PetCompletionAnnouncer {
  final _last = <String, DateTime>{};

  /// True for the first caller after the pet with [petId] became complete.
  bool claim(String petId, DateTime now) {
    final last = _last[petId];
    if (last != null && now.difference(last).abs() < const Duration(seconds: 5)) return false;
    _last[petId] = now;
    return true;
  }
}

final petCompletionAnnouncerProvider = Provider<PetCompletionAnnouncer>((ref) => PetCompletionAnnouncer());
