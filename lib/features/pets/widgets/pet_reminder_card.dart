import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../checklist_sheet.dart';
import '../data/pets_repository_provider.dart';
import '../pet_actions.dart';
import '../state/pet_completeness.dart';
import 'pets_widgets.dart';

Pet? _find(List<Pet> pets, String id) {
  for (final pet in pets) {
    if (pet.id == id) return pet;
  }
  return null;
}

/// "2 of 5 essentials still to add".
String essentialsStillToAdd(PetCompleteness info) =>
    '${info.missing.length} of ${info.total} essentials still to add';

/// Says "Soya's essentials are complete" once, when the last missing
/// essential of the pet with [petId] is answered. Call it from the `build`
/// of a widget that shows the pet's missing essentials.
void announcePetCompletion(WidgetRef ref, BuildContext context, String petId) {
  ref.listen(petCompletenessProvider(petId), (previous, next) {
    if (previous == null || !previous.needsAttention || !next.isComplete) return;
    if (!ref.read(petCompletionAnnouncerProvider).claim(petId, DateTime.now())) return;
    final pet = ref.read(petsStoreProvider).byId(petId);
    if (pet != null && context.mounted) showPetsSnack(context, "${pet.name}'s essentials are complete");
  });
}

/// "Not now": postpones the reminder of the pet with [petId] for a week and
/// says so.
Future<void> postponePetReminder(BuildContext context, String petId) async {
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    await snoozePetReminder(container, petId);
    if (context.mounted) showPetsSnack(context, "We'll remind you again in a week");
  } catch (e) {
    if (context.mounted) showPetsSnack(context, petsErrorMessage(e));
  }
}

/// The reminder for one pet, shown while an essential is missing and the
/// reminder was not postponed.
///
/// `compact: false` is the card: the title, "2 of 5 essentials still to
/// add", a progress line, the action button and "Not now". `compact: true`
/// is one line about 60 px tall: the action, the count and "Not now".
///
/// The action opens the next missing item; the rest of the card opens the
/// checklist. "Not now" hides the reminder everywhere for 7 days.
///
/// Shows nothing at all, and takes no space including [margin], when there
/// is nothing to remind of: no `if` is needed around it.
class PetReminderCard extends ConsumerWidget {
  const PetReminderCard({super.key, required this.petId, this.compact = false, this.margin = EdgeInsets.zero});

  final String petId;
  final bool compact;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    announcePetCompletion(ref, context, petId);
    final info = ref.watch(petCompletenessProvider(petId));
    final name = ref.watch(petsProvider.select((pets) => _find(pets, petId)?.name));
    final next = info.next;
    if (!info.shouldRemind || name == null || next == null) return const SizedBox.shrink();

    void openNext() => openPetInfoItem(context, petId: petId, item: next);
    void notNow() => postponePetReminder(context, petId);
    final count = essentialsStillToAdd(info);
    final label = "$name's profile: $count";
    final action = next.actionFor(name);

    return Padding(
      padding: margin,
      child: compact
          ? _Line(label: label, action: action, count: count, onOpen: openNext, onNotNow: notNow)
          : _Card(
              label: label,
              title: "Finish $name's profile",
              action: action,
              count: count,
              info: info,
              onOpen: openNext,
              onChecklist: () => showPetChecklist(context, petId),
              onNotNow: notNow,
            ),
    );
  }
}

class _NotNow extends StatelessWidget {
  const _NotNow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(kPetsTapTarget, kPetsTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      child: const Text('Not now'),
    );
  }
}

/// The one-line reminder for the Home dashboard.
class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.action,
    required this.count,
    required this.onOpen,
    required this.onNotNow,
  });

  final String label;
  final String action;
  final String count;
  final VoidCallback onOpen;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return PetsCard(
      shadow: true,
      onTap: onOpen,
      semanticLabel: label,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
      child: Row(
        children: [
          const PetsDisc(Icons.fact_check_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  count,
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _NotNow(onPressed: onNotNow),
        ],
      ),
    );
  }
}

/// The reminder card for the Health overview.
class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    required this.action,
    required this.count,
    required this.info,
    required this.onOpen,
    required this.onChecklist,
    required this.onNotNow,
  });

  final String label;
  final String title;
  final String action;
  final String count;
  final PetCompleteness info;
  final VoidCallback onOpen;
  final VoidCallback onChecklist;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return PetsCard(
      shadow: true,
      onTap: onChecklist,
      semanticLabel: label,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const PetsDisc(Icons.fact_check_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.cardTitle),
                    Text(count, style: AppText.secondary.copyWith(color: AppColors.brown)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
            ],
          ),
          const SizedBox(height: 12),
          EssentialsProgress(answered: info.answered, total: info.total),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              PillButton(action, icon: Icons.add_rounded, onPressed: onOpen),
              _NotNow(onPressed: onNotNow),
            ],
          ),
        ],
      ),
    );
  }
}

/// Five short bars, one per essential, filled for the answered ones.
class EssentialsProgress extends StatelessWidget {
  const EssentialsProgress({super.key, required this.answered, required this.total});

  final int answered;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < answered ? AppColors.sage : kPetsLine,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
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
    final needed = ref.watch(petCompletenessProvider(petId).select((info) => info.needsAttention));
    if (!needed) return const SizedBox.shrink();
    return Semantics(
      label: 'Essentials missing',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.coralDark, width: 3),
        ),
      ),
    );
  }
}
