import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/emergency_contacts.dart';
import '../../../services/pets/data/pets_repository_provider.dart';
import '../pet_actions.dart';
import '../../../services/pets/state/pet_completeness.dart';
import '../../../presentation/pet_words.dart';
import 'pet_essentials_keeper.dart';
import '../../../presentation/pets_widgets.dart';

/// The answer to an essential in a few words ("About 3 years", "None
/// known"), or `null` while it is not at hand. The age is counted at [now].
String? essentialAnswer(
  PetsL10n l10n,
  PetInfoItem item,
  Pet pet, {
  required DateTime now,
  HealthProfile? profile,
  PetVets? vets,
}) {
  String list(List<String> entries) => entries.isEmpty
      ? l10n.noneKnown
      : [for (final entry in entries) typedInLine(l10n, entry)].join(', ');
  switch (item) {
    case PetInfoItem.age:
      return petAgeText(l10n, pet, now: now);
    case PetInfoItem.weight:
      return pet.weightKg == null
          ? null
          : petWeightText(l10n, pet.weightKg!, pet.species);
    case PetInfoItem.allergies:
      return profile == null ? null : list(profile.allergies);
    case PetInfoItem.conditions:
      return profile == null ? null : list(profile.conditions);
    case PetInfoItem.vetPhone:
      final regular = vets?.regular;
      final emergency = vets?.emergency;
      final vet = regular != null && regular.hasPhone ? regular : emergency;
      return vet == null || !vet.hasPhone
          ? null
          : '${typedInLine(l10n, vet.name)} · ${phoneInLine(l10n, vet.phone)}';
    default:
      return null;
  }
}

/// The five essentials of a pet, each ticked with its answer or still open
/// with a one-tap button to its own editor. Used by the "All set" page and
/// the checklist.
class EssentialsList extends ConsumerWidget {
  const EssentialsList({
    super.key,
    required this.pet,
    this.addLabel,
    this.editable = true,
  });

  final Pet pet;

  /// The text of the button on an open row; "Add" when not given.
  final String? addLabel;

  /// Whether an answered row can be tapped to change the answer.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(petCompletenessProvider(pet.id));
    final profile = ref.watch(healthProfileProvider(pet.id)).value;
    final vets = ref.watch(petVetsProvider(pet.id)).value;
    final health = ref.watch(healthCriticalItemsProvider(pet.id));
    final now = ref.watch(petsClockProvider)();
    final l10n = context.petsL10n;
    final addLabel = this.addLabel ?? context.l10n.commonAdd;
    void open(PetInfoItem item) =>
        openPetInfoItem(context, petId: pet.id, item: item);

    Widget row(PetInfoItem item) {
      final fromHealth = item.index <= PetInfoItem.conditions.index;
      if (fromHealth && !info.isKnown) {
        // Unknown is not missing: no button until Health has answered.
        return PetsRow(
          leading: const AnswerMark(answered: false),
          title: item.labelIn(l10n),
          subtitle: health.hasError ? l10n.couldNotCheck : l10n.checking,
        );
      }
      if (info.missing.contains(item)) {
        return PetsRow(
          leading: const AnswerMark(answered: false),
          title: item.labelIn(l10n),
          subtitle: item.hintIn(l10n),
          trailing: PillButton(
            addLabel,
            key: Key('add-${item.name}'),
            onPressed: () => open(item),
          ),
        );
      }
      return PetsRow(
        key: Key('answered-${item.name}'),
        leading: const AnswerMark(answered: true),
        title: item.labelIn(l10n),
        subtitle: essentialAnswer(
          l10n,
          item,
          pet,
          now: now,
          profile: profile,
          vets: vets,
        ),
        trailing: editable ? const AppIcon(Icons.chevron_right_rounded) : null,
        onTap: editable ? () => open(item) : null,
      );
    }

    return PetEssentialsKeeper(
      petId: pet.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in PetInfoItem.essentials)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: row(item),
            ),
        ],
      ),
    );
  }
}
