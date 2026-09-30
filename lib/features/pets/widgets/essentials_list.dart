import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../health/emergency/emergency.dart';
import '../data/pets_repository_provider.dart';
import '../pet_actions.dart';
import '../state/pet_completeness.dart';
import 'pet_basics_fields.dart';
import 'pet_essentials_keeper.dart';
import 'pets_widgets.dart';

/// The answer to an essential in a few words ("About 3 years", "None
/// known"), or `null` while it is not at hand. The age is counted at [now].
String? essentialAnswer(
  PetInfoItem item,
  Pet pet, {
  required DateTime now,
  HealthProfile? profile,
  PetVets? vets,
}) {
  String list(List<String> entries) => entries.isEmpty ? 'None known' : entries.join(', ');
  switch (item) {
    case PetInfoItem.age:
      return pet.ageLabelAt(now);
    case PetInfoItem.weight:
      return pet.weightKg == null ? null : formatPetWeight(pet.weightKg!, pet.species);
    case PetInfoItem.allergies:
      return profile == null ? null : list(profile.allergies);
    case PetInfoItem.conditions:
      return profile == null ? null : list(profile.conditions);
    case PetInfoItem.vetPhone:
      final regular = vets?.regular;
      final emergency = vets?.emergency;
      final vet = regular != null && regular.hasPhone ? regular : emergency;
      return vet == null || !vet.hasPhone ? null : '${vet.name} · ${vet.phone}';
    default:
      return null;
  }
}

/// The five essentials of a pet, each ticked with its answer or still open
/// with a one-tap button to its own editor. Used by the "All set" page and
/// the checklist.
class EssentialsList extends ConsumerWidget {
  const EssentialsList({super.key, required this.pet, this.addLabel = 'Add', this.editable = true});

  final Pet pet;

  /// The text of the button on an open row.
  final String addLabel;

  /// Whether an answered row can be tapped to change the answer.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(petCompletenessProvider(pet.id));
    final profile = ref.watch(healthProfileProvider(pet.id)).value;
    final vets = ref.watch(petVetsProvider(pet.id)).value;
    final health = ref.watch(healthCriticalItemsProvider(pet.id));
    final now = ref.watch(petsClockProvider)();
    void open(PetInfoItem item) => openPetInfoItem(context, petId: pet.id, item: item);

    Widget row(PetInfoItem item) {
      final fromHealth = item.index <= PetInfoItem.conditions.index;
      if (fromHealth && !info.isKnown) {
        // Unknown is not missing: no button until Health has answered.
        return PetsRow(
          leading: const AnswerMark(answered: false),
          title: item.label,
          subtitle: health.hasError ? 'Could not check this right now' : 'Checking…',
        );
      }
      if (info.missing.contains(item)) {
        return PetsRow(
          leading: const AnswerMark(answered: false),
          title: item.label,
          subtitle: item.hint,
          trailing: PillButton(addLabel, key: Key('add-${item.name}'), onPressed: () => open(item)),
        );
      }
      return PetsRow(
        key: Key('answered-${item.name}'),
        leading: const AnswerMark(answered: true),
        title: item.label,
        subtitle: essentialAnswer(item, pet, now: now, profile: profile, vets: vets),
        trailing: editable ? const Icon(Icons.chevron_right_rounded) : null,
        onTap: editable ? () => open(item) : null,
      );
    }

    return PetEssentialsKeeper(
      petId: pet.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in PetInfoItem.essentials)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: row(item)),
        ],
      ),
    );
  }
}
