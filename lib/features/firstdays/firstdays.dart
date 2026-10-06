/// "The first 30 days": a short guided checklist for a pet that just
/// arrived home. What the rest of the app uses, in one import:
///
/// ```dart
/// import 'package:pet_companion/features/firstdays/firstdays.dart';
/// ```
///
/// - Home: `FirstDaysHomeCard(pet: pet)`, shown only while the path runs.
/// - Add a pet: `ArrivalQuestion` driven by an `ArrivalController`, whose
///   `apply` starts the path when the step is saved.
/// - Pet profile: `FirstDaysProfileEntry(pet: pet)`, to start the path for
///   a pet already in the app, or to see it (a summary once it ended).
///
/// The tasks are bundled with the app, per kind of animal
/// (`data/first_days_tasks.dart`); only the arrival day, the ticks and an
/// early close are stored (`supabase/migrations/0011_first_days.sql`).
library;

export '../../services/firstdays/data/first_days_models.dart';
export '../../services/firstdays/data/first_days_repository.dart';
export '../../services/firstdays/data/first_days_tasks.dart';
export 'first_days_screen.dart' show FirstDaysScreen, openFirstDays;
export 'first_days_words.dart';
export '../../services/firstdays/state/first_days_logic.dart';
export '../../services/firstdays/state/first_days_providers.dart';
export 'widgets/arrival_question.dart'
    show ArrivalController, ArrivalQuestion, pickArrivalDay;
export 'widgets/first_days_card.dart' show FirstDaysHomeCard;
export 'widgets/first_days_keeper.dart' show FirstDaysKeeper;
export 'widgets/first_days_profile_entry.dart' show FirstDaysProfileEntry;
