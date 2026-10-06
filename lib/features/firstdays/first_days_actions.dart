import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../platform/feature_ui.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../services/firstdays/data/first_days_tasks.dart';
import '../../services/pet_records/data/health_models.dart';

Future<void> runFirstDaysAction(
  BuildContext context,
  Pet pet,
  FirstDaysAction action,
) async {
  ProviderScope.containerOf(
    context,
    listen: false,
  ).read(selectedPetIdProvider.notifier).select(pet.id);
  final name = switch (action.kind) {
    FirstDaysActionKind.store => 'store-category',
    FirstDaysActionKind.schedule => 'health-schedule',
    FirstDaysActionKind.guides => 'guides',
    FirstDaysActionKind.foodSettings => 'food-settings',
    FirstDaysActionKind.feeding => 'feeding',
    FirstDaysActionKind.activity => 'activity',
    FirstDaysActionKind.addCheckup => 'record-form',
    FirstDaysActionKind.healthProfile => 'health-profile',
    FirstDaysActionKind.routine => 'routine',
    FirstDaysActionKind.guide => 'guide',
  };
  await openFeature<Object>(context, name, pet.id, {
    'category': action.category,
    'kind': action.kind == FirstDaysActionKind.addCheckup
        ? RecordKind.checkup
        : action.careKind,
    'planned': true,
    'guideId': action.guideId,
  });
}
