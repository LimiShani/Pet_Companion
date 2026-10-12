import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../presentation/care_widgets.dart' show CarePillButton;
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../checklist_sheet.dart';
import '../pet_actions.dart';
import '../../../presentation/pet_words.dart';
import '../../../services/pets/state/pet_completeness.dart';
import 'pet_essentials_keeper.dart';
import '../../../presentation/pets_widgets.dart';

Pet? _find(List<Pet> pets, String id) {
  for (final pet in pets) {
    if (pet.id == id) return pet;
  }
  return null;
}

/// "2 of 5 essentials still to add".
String essentialsStillToAdd(PetsL10n l10n, PetCompleteness info) =>
    l10n.essentialsStillToAdd(info.missing.length, info.total);

/// Says "Soya's essentials are complete" once, when the last missing
/// essential of the pet with [petId] is answered. Call it from the `build`
/// of a widget that shows the pet's missing essentials.
void announcePetCompletion(WidgetRef ref, BuildContext context, String petId) {
  ref.listen(petCompletenessProvider(petId), (previous, next) {
    if (previous == null || !previous.needsAttention || !next.isComplete) {
      return;
    }
    if (!ref.read(petCompletionAnnouncerProvider).claim(petId, DateTime.now())) {
      return;
    }
    final pet = ref.read(petsStoreProvider).byId(petId);
    if (pet != null && context.mounted) {
      showPetsSnack(context, context.petsL10n.essentialsComplete(pet.name));
    }
  });
}

/// "Remind me in a week": postpones the reminder of the pet with [petId] for a week and
/// says so. [context] is only used before anything is awaited, so the
/// caller may close its sheet or page straight away.
Future<void> postponePetReminder(BuildContext context, String petId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  // The words are taken now, in the language of the screen that asked.
  final l10n = context.petsL10n;
  final app = context.l10n;
  void say(String message) {
    if (messenger == null || !messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  try {
    await snoozePetReminder(container, petId);
    say(l10n.remindAgainInAWeek);
  } catch (e) {
    say(petsErrorText(l10n, app, e));
  }
}

/// The reminder for one pet, shown while an essential is missing and the
/// reminder was not postponed.
///
/// One row for Home, the app's one essentials nag: the title, "2 of 5
/// essentials still to add" and an "Add" pill.
///
/// The pill opens the next missing item; the rest of the row opens the
/// checklist, where "Remind me in a week" hides the reminder everywhere for
/// 7 days.
///
/// Shows nothing at all, and takes no space including [margin], when there
/// is nothing to remind of: no `if` is needed around it.
class PetReminderCard extends ConsumerWidget {
  const PetReminderCard({
    super.key,
    required this.petId,
    this.margin = EdgeInsets.zero,
  });

  final String petId;
  final EdgeInsetsGeometry margin;

  /// The "Add" pill of the row.
  static const addKey = Key('reminder-add');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    announcePetCompletion(ref, context, petId);
    final info = ref.watch(petCompletenessProvider(petId));
    final name = ref.watch(
      petsProvider.select((pets) => _find(pets, petId)?.name),
    );
    final next = info.next;
    if (!info.shouldRemind || name == null || next == null) {
      return PetEssentialsKeeper(petId: petId, child: const SizedBox.shrink());
    }

    final l10n = context.petsL10n;

    return PetEssentialsKeeper(
      petId: petId,
      child: Padding(
        padding: margin,
        child: _Line(
          label: l10n.reminderSemantics(name, info.missing.length, info.total),
          title: l10n.finishProfile(name),
          action: next.actionIn(l10n, name),
          count: essentialsStillToAdd(l10n, info),
          onOpen: () => openPetInfoItem(context, petId: petId, item: next),
          onChecklist: () => showPetChecklist(context, petId),
        ),
      ),
    );
  }
}

/// The one-row reminder for the Home dashboard: a white card like Home's
/// other cards, "Finish Soya's profile", the count and one "Add" pill.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.title,
    required this.action,
    required this.count,
    required this.onOpen,
    required this.onChecklist,
  });

  final String label;
  final String title;

  /// What "Add" does ("Add the vet's phone"), for screen readers.
  final String action;
  final String count;
  final VoidCallback onOpen;
  final VoidCallback onChecklist;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChecklist,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 10, 6),
            child: Row(
              children: [
                const PetsDisc(Icons.fact_check_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppText.cardTitle),
                      Text(
                        count,
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: action,
                  excludeSemantics: true,
                  onTap: onOpen,
                  child: CarePillButton(
                    key: PetReminderCard.addKey,
                    label: context.l10n.commonAdd,
                    filled: true,
                    onPressed: onOpen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small dot for a pet's pill or avatar (13 px). Shows nothing for a
/// complete pet, and while Health has not answered. It ignores "Not now",
/// so the way back to the missing essentials is always visible.
class PetAttentionDot extends ConsumerWidget {
  const PetAttentionDot({super.key, required this.petId});

  final String petId;

  static const size = 13.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needed = ref.watch(
      petCompletenessProvider(petId).select((info) => info.needsAttention),
    );
    return PetEssentialsKeeper(
      petId: petId,
      child: !needed
          ? const SizedBox.shrink()
          : Semantics(
              label: context.petsL10n.essentialsMissing,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.coralDark, width: 3),
                ),
              ),
            ),
    );
  }
}
