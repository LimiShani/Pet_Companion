/// Daily care behind Home's feeding and activity cards: the pet's food and
/// goals, today's meals and walks, and the pages and sheets that log them.
///
/// The meals and walks are Health's care log (the feeding and walk
/// routines and their answers), so Home and the Health schedule agree.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/pet_records/state/health_providers.dart';
import '../../services/care/state/care_providers.dart';

export 'activity_screen.dart' show ActivityScreen, RunningWalkBox, openActivity;
export '../../services/care/data/care_models.dart';
export 'feeding_screen.dart' show FeedingScreen, openFeeding;
export 'food_settings_screen.dart' show FoodSettingsScreen, openFoodSettings;
export 'log_meal_sheet.dart' show LogMealSheet, showLogMealSheet;
export '../../services/care/state/care_logic.dart';
export '../../services/care/state/care_providers.dart';
export 'walk_sheet.dart' show WalkSheet, finishWalk, showWalkSheet;
export '../../presentation/care_widgets.dart'
    show CareKeeper, CarePillButton, WeekBars;

/// Loads a pet's care data again after a failure.
void retryCare(WidgetRef ref, String petId) {
  ref.invalidate(carePlanProvider(petId));
  ref.invalidate(healthRecordsProvider(petId));
  ref.invalidate(careSettingsProvider(petId));
}
