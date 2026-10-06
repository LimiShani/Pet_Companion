import 'pets_routes.dart';
import 'package:flutter/material.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../theme/app_theme.dart';
import 'pets.dart';

final petsModule = FeatureModule(
  id: 'pets',
  routes: petsRoutes,
  home: [
    FeatureContribution(
      id: 'pet-reminders',
      capability: 'pets.view',
      order: 0,
      builder: (_, id) => PetReminderCard(
        petId: id,
        compact: true,
        margin: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      ),
    ),
  ],
  actions: {
    'add-pet': FeatureAction(
      capability: 'pets.edit',
      open: (c, r) => openAddPet(c),
    ),
    'my-pets': FeatureAction.task(
      capability: 'pets.view',
      open: (c, r) => openMyPets(c),
    ),
    'pet-profile': FeatureAction.task(
      capability: 'pets.view',
      open: (c, r) => openPetProfile(c, r.petId),
    ),
  },
  slots: {
    'pet-attention': FeatureSlot(
      capability: 'pets.view',
      build: (c, r) => PetAttentionDot(petId: r.petId),
    ),
    'pet-reminder': FeatureSlot(
      capability: 'pets.view',
      build: (c, r) => PetReminderCard(
        petId: r.petId,
        margin: const EdgeInsets.only(top: AppSpacing.cardGap),
      ),
    ),
  },
);
