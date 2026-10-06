import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../presentation/schedule/routine_form_screen.dart';
import '../../services/pet_records/data/health_models.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_theme.dart';
import 'widgets/feeding_card.dart';
import 'widgets/activity_card.dart';
import 'care.dart';

final careModule = FeatureModule(
  id: 'care',
  home: [
    FeatureContribution(
      id: 'daily-care',
      capability: 'care.view',
      order: 10,
      builder: (_, id) => Consumer(
        builder: (c, ref, _) {
          final pet = ref.watch(selectedPetProvider);
          return CareKeeper(
            petId: id,
            child: Column(
              children: [
                FeedingCard(pet: pet),
                const SizedBox(height: AppSpacing.cardGap),
                ActivityCard(pet: pet),
                const SizedBox(height: AppSpacing.cardGap),
              ],
            ),
          );
        },
      ),
    ),
  ],
  actions: {
    'feeding': FeatureAction.task(
      capability: 'care.view',
      open: (c, r) => openFeeding(c, requestPet(c, r)),
    ),
    'activity': FeatureAction.task(
      capability: 'care.view',
      open: (c, r) => openActivity(c, requestPet(c, r)),
    ),
    'food-settings': FeatureAction.task(
      capability: 'care.edit',
      open: (c, r) => openFoodSettings(c, requestPet(c, r)),
    ),
    'routine': FeatureAction(
      capability: 'care.edit|health.schedule.edit',
      open: (c, r) =>
          openRoutineForm(c, requestPet(c, r), kind: r.value<CareKind>('kind')),
    ),
  },
);
