import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_icon.dart';
import 'pet_actions.dart';
import 'state/pet_completeness.dart';
import 'widgets/essentials_list.dart';
import 'widgets/pet_avatar.dart';
import 'widgets/pet_reminder_card.dart';
import 'widgets/pets_widgets.dart';

/// The "what is missing" checklist as a bottom sheet: the five essentials,
/// each one tap from its own editor, the "good to have" items, and "Remind
/// me in a week". Nothing opens for an unknown [petId].
Future<void> showPetChecklist(BuildContext context, String petId) {
  final pet = ProviderScope.containerOf(context, listen: false).read(petsStoreProvider).byId(petId);
  assert(pet != null, 'showPetChecklist: no pet with id "$petId"');
  if (pet == null) return Future.value();
  return showPetsSheet<void>(context, PetChecklist(petId: petId));
}

class PetChecklist extends ConsumerWidget {
  const PetChecklist({super.key, required this.petId});

  final String petId;

  /// The order of the mockup: what helps most first.
  static const _goodToHave = [
    PetInfoItem.photo,
    PetInfoItem.microchip,
    PetInfoItem.emergencyVet,
    PetInfoItem.breed,
    PetInfoItem.sexAndNeutering,
  ];

  static bool _fromHealth(PetInfoItem item) => item == PetInfoItem.microchip || item == PetInfoItem.emergencyVet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    announcePetCompletion(ref, context, petId);
    final Pet? pet = ref.watch(petsStoreProvider.select((pets) => pets.byId(petId)));
    if (pet == null) return const SizedBox.shrink();
    final info = ref.watch(petCompletenessProvider(petId));

    final l10n = context.petsL10n;
    final summary = !info.isKnown
        ? l10n.checklistChecking
        : info.isComplete
            ? l10n.checklistAllAnswered(info.total)
            : l10n.checklistSomeAnswered(info.answered, info.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PetAvatar(pet: pet, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [PetsHeading(l10n.checklistTitle(pet.name)), PetsNote(summary)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        EssentialsList(pet: pet),
        PetsLabel(l10n.goodToHave, topGap: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final item in _goodToHave)
              // Health's items show once Health has answered.
              if (!_fromHealth(item) || info.isKnown)
                _GoodToHaveChip(
                  item: item,
                  answered: !info.goodToHave.contains(item),
                  onPressed: () => openPetInfoItem(context, petId: petId, item: item),
                ),
          ],
        ),
        const SizedBox(height: 12),
        if (info.shouldRemind)
          PetsTextButton(
            l10n.remindInAWeek,
            // Close first, then save: a pop after the save could remove
            // whatever page is on top by then.
            onPressed: () {
              postponePetReminder(context, petId);
              Navigator.of(context).pop();
            },
          )
        else if (info.needsAttention && info.snoozedUntil != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: PetsFinePrint(
              l10n.reminderHiddenUntil(AppFormat.of(context).date(info.snoozedUntil!), pet.name),
              center: true,
            ),
          ),
      ],
    );
  }
}

class _GoodToHaveChip extends StatelessWidget {
  const _GoodToHaveChip({required this.item, required this.answered, required this.onPressed});

  final PetInfoItem item;
  final bool answered;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.petsL10n;
    final label = item.labelIn(l10n);
    return ActionChip(
      key: Key('good-${item.name}'),
      avatar: AppIcon(answered ? Icons.check_rounded : Icons.add_rounded, size: 16, color: AppColors.ink),
      label: Text(label),
      backgroundColor: answered ? AppColors.yellow : AppColors.white,
      side: BorderSide(color: answered ? AppColors.yellow : kPetsLine),
      tooltip: answered ? l10n.chipAnswered(label) : l10n.chipNotAdded(label),
      onPressed: onPressed,
    );
  }
}
