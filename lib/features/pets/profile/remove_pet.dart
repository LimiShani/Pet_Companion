import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/pets_repository_provider.dart';
import '../widgets/pets_widgets.dart';

/// Removes what the Health feature keeps in file storage for a pet (its
/// document files), before the pet itself is deleted. The database rows of
/// Health go with the pet on their own; files do not.
///
/// ---------------------------------------------------------------------
/// HEALTH CLEANUP CALL SITE. Health has been asked for
/// `removeHealthFilesForPet(petId)`; it does not exist yet, so this does
/// nothing for now. When it exists, make this provider call it:
///
///     final petHealthCleanupProvider = Provider<Future<void> Function(String)>(
///       (ref) => (petId) => removeHealthFilesForPet(ref, petId),
///     );
///
/// It is awaited in [deletePet] below, before the pet's row is deleted. If
/// it throws, the pet is not deleted and the owner sees the message.
/// ---------------------------------------------------------------------
final petHealthCleanupProvider = Provider<Future<void> Function(String petId)>((ref) => (petId) async {});

/// What the owner chose in the "Remove Soya?" dialog.
enum RemoveChoice { archive, delete }

/// Asks how to remove [pet]: **Archive** (suggested: hidden, everything
/// kept, restorable from My pets) or **Delete for good** (says what is
/// erased; cannot be undone). With [canArchive] false (the last visible
/// pet) only deleting is offered. Returns `null` on "Cancel".
Future<RemoveChoice?> askHowToRemovePet(BuildContext context, Pet pet, {required bool canArchive}) {
  return showDialog<RemoveChoice>(
    context: context,
    useRootNavigator: true,
    builder: (context) => _RemoveDialog(pet: pet, canArchive: canArchive),
  );
}

/// Hides [pet] from the app without losing anything.
Future<void> archivePet(ProviderContainer container, Pet pet) async {
  final now = container.read(petsClockProvider)();
  await container.read(petsStoreProvider.notifier).save(pet.withArchivedAt(now));
}

/// Brings an archived [pet] back.
Future<void> restorePet(ProviderContainer container, Pet pet) =>
    container.read(petsStoreProvider.notifier).save(pet.withArchivedAt(null));

/// Deletes [pet] for good: Health's files first (see
/// [petHealthCleanupProvider]), then its picture and its row, with which
/// its health rows go.
Future<void> deletePet(ProviderContainer container, Pet pet) async {
  await container.read(petHealthCleanupProvider)(pet.id);
  await container.read(petsStoreProvider.notifier).delete(pet);
}

class _RemoveDialog extends StatelessWidget {
  const _RemoveDialog({required this.pet, required this.canArchive});

  final Pet pet;
  final bool canArchive;

  @override
  Widget build(BuildContext context) {
    final name = pet.name;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PetsHeading('Remove $name?'),
            const SizedBox(height: 12),
            _Choice(
              icon: Icons.archive_outlined,
              title: 'Archive',
              suggested: canArchive,
              message: canArchive
                  ? '$name is hidden from the app. Everything is kept, and you can bring $name back from My pets.'
                  : '$name is your only pet, so there is nothing to show in its place. '
                      'Add another pet first, or delete $name.',
              button: PillButton(
                'Archive $name',
                key: const Key('remove-archive'),
                onPressed: canArchive ? () => Navigator.of(context).pop(RemoveChoice.archive) : null,
              ),
            ),
            const SizedBox(height: 12),
            _Choice(
              icon: Icons.delete_outline_rounded,
              discColor: AppColors.cream,
              title: 'Delete for good',
              message: "Erases $name's profile, picture, health records, reminders and documents. "
                  'This cannot be undone.',
              button: PillButton(
                'Delete $name',
                key: const Key('remove-delete'),
                outlined: true,
                onPressed: () => Navigator.of(context).pop(RemoveChoice.delete),
              ),
            ),
            const SizedBox(height: 4),
            PetsTextButton('Cancel', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    this.discColor = AppColors.yellow,
    this.suggested = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget button;
  final Color discColor;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PetsDisc(icon, color: discColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: AppText.cardTitle)),
              if (suggested) ...[
                const SizedBox(width: 8),
                const Flexible(child: PetsTag('Suggested', tone: TagTone.green)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppText.secondary.copyWith(color: AppColors.brown)),
          const SizedBox(height: 10),
          button,
        ],
      ),
    );
  }
}
