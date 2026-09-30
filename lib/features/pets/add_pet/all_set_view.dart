import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../state/pet_completeness.dart';
import '../widgets/essentials_list.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_widgets.dart';

/// The last page of the add-a-pet flow: what was filled in, and what is
/// still open with a one-tap "Add now".
class AllSetView extends ConsumerWidget {
  const AllSetView({super.key, required this.pet, required this.onDashboard, required this.onAddAnother});

  final Pet pet;
  final VoidCallback onDashboard;
  final VoidCallback onAddAnother;

  static const _picture = 132.0;

  /// How far the picture hangs below the coral band.
  static const _drop = 66.0;

  static String _summary(PetCompleteness info) {
    if (!info.isKnown) return 'Checking the essentials…';
    if (info.isComplete) return 'All ${info.total} essentials filled';
    return '${info.answered} of ${info.total} essentials filled';
  }

  static String _closing(PetCompleteness info, String name) {
    if (!info.isKnown) return "$name's dashboard shows a small reminder while an essential is missing.";
    if (info.isComplete) return "$name's essentials are complete. You can change anything from the profile.";
    final rest = info.missing.length == 1 && info.missing.single == PetInfoItem.vetPhone
        ? "the vet's phone is added"
        : 'the rest is added';
    return "We'll keep a small reminder on $name's dashboard until $rest.";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(petCompletenessProvider(pet.id));

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: _drop),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.shellRadius)),
                    ),
                    child: const SafeArea(bottom: false, child: SizedBox(height: _picture - _drop + 28)),
                  ),
                ),
                Stack(
                  children: [
                    PetAvatar(pet: pet, size: _picture, borderColor: AppColors.cream, borderWidth: 5),
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cream, width: 3),
                        ),
                        child: const Icon(Icons.check_rounded, size: 22, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                12,
                AppSpacing.screen,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PetsHeading('${pet.name} is ready', center: true, size: 24),
                  const SizedBox(height: 2),
                  PetsNote(_summary(info), center: true),
                  const SizedBox(height: 16),
                  EssentialsList(pet: pet, addLabel: 'Add now', editable: false),
                  const SizedBox(height: 12),
                  PrimaryButton(label: "Go to ${pet.name}'s dashboard", onPressed: onDashboard),
                  const SizedBox(height: 10),
                  PetsOutlineButton('Add another pet', onPressed: onAddAnother),
                  const SizedBox(height: 12),
                  PetsFinePrint(_closing(info, pet.name), center: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
