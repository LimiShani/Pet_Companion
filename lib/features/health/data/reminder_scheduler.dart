import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_models.dart';

/// Everything that should remind the owner about one pet.
class ReminderPlan {
  const ReminderPlan({
    required this.petId,
    required this.petName,
    this.items = const [],
    this.upcoming = const [],
    this.medications = const [],
    this.logs = const [],
    this.itemsLoaded = true,
    this.upcomingLoaded = true,
    this.today,
  });

  final String petId;
  final String petName;

  /// Active recurring reminders: routines and medicine times.
  final List<CarePlanItem> items;

  /// Planned appointments and due dates that are still ahead.
  final List<HealthRecord> upcoming;

  /// The pet's medicines, for the dose a medicine reminder names.
  final List<Medication> medications;

  /// The answers given so far (the recent care log): an occurrence that
  /// already has one never rings.
  final List<CareLog> logs;

  /// Whether [items], [medications] and [logs] are known. `false` when the
  /// plan was sent because the records changed while the care plan was not
  /// loaded: a scheduler then keeps the reminders it had for them.
  final bool itemsLoaded;

  /// Whether [upcoming] is known; `false` as for [itemsLoaded].
  final bool upcomingLoaded;

  /// "Today" in the world of the data: the real day for an account, the
  /// day of the sample data in the demo. A scheduler that rings in the real
  /// world moves the plan's dates by the difference. `null`: the real day.
  final DateTime? today;
}

/// Schedules the phone's notifications for a pet's care.
///
/// The Health feature calls [sync] with the pet's whole plan every time it
/// is loaded or changes; an implementation replaces whatever it had
/// scheduled for that pet. The default is [NoopReminderScheduler] (tests);
/// `main.dart` wires the real one (`NotificationReminderScheduler` in
/// `lib/notifications/`), which rings on the phone.
abstract class ReminderScheduler {
  Future<void> sync(ReminderPlan plan);
}

/// Does nothing: reminders show in the Schedule, but the phone stays quiet.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> sync(ReminderPlan plan) async {}
}

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) => const NoopReminderScheduler());
