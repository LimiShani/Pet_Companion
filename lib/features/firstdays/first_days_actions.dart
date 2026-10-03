import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../care/care.dart';
import '../community/community_routes.dart';
import '../community/community_screen.dart' show communityGuidesRequestProvider;
import '../community/guides/guide_reader_screen.dart';
import '../health/data/health_models.dart';
import '../health/emergency/emergency.dart' show openHealthProfile;
import '../health/health_routes.dart';
import '../health/records/record_form_screen.dart';
import '../health/schedule/routine_form_screen.dart';
import '../health/state/health_providers.dart';
import '../store/state/store_providers.dart';
import '../store/store_routes.dart';
import 'data/first_days_tasks.dart';

/// Opens the screen that does [action] for [pet], from the first 30 days
/// page.
///
/// Pages of the pet's care (the feeding page, a new vet visit, the health
/// profile, a guide) open over the first 30 days page, and back returns to
/// it. A whole tab (the Store, the Health schedule, the guides library) is
/// reached by leaving the page: it can be opened again from Home or from
/// the pet's profile.
Future<void> runFirstDaysAction(BuildContext context, Pet pet, FirstDaysAction action) async {
  final container = ProviderScope.containerOf(context, listen: false);

  /// Leaves the page, selects the pet and shows [location].
  void goToTab(String location, void Function() prepare) {
    final router = GoRouter.maybeOf(context);
    container.read(selectedPetIdProvider.notifier).select(pet.id);
    prepare();
    Navigator.of(context).maybePop();
    router?.go(location);
  }

  switch (action.kind) {
    case FirstDaysActionKind.store:
      goToTab(StoreRoutes.root, () {
        // The Store shows what suits the selected pet's kind.
        container.read(storeFilterProvider.notifier)
          ..clear()
          ..setAllAnimals(false)
          ..setCategory(action.category);
      });
    case FirstDaysActionKind.schedule:
      goToTab(HealthRoutes.root, () => container.read(healthSectionProvider.notifier).show(HealthSection.schedule));
    case FirstDaysActionKind.guides:
      goToTab(CommunityRoutes.root, () => container.read(communityGuidesRequestProvider.notifier).request());
    case FirstDaysActionKind.foodSettings:
      await openFoodSettings(context, pet);
    case FirstDaysActionKind.feeding:
      await openFeeding(context, pet);
    case FirstDaysActionKind.activity:
      await openActivity(context, pet);
    case FirstDaysActionKind.addCheckup:
      // A visit still to come is booked; one already done can be dated back.
      await openRecordForm(context, pet, kind: RecordKind.checkup, planned: true);
    case FirstDaysActionKind.healthProfile:
      await openHealthProfile(context, pet.id);
    case FirstDaysActionKind.routine:
      await openRoutineForm(context, pet, kind: action.careKind);
    case FirstDaysActionKind.guide:
      await Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(MaterialPageRoute(builder: (_) => GuideReaderScreen(guideId: action.guideId!)));
  }
}
