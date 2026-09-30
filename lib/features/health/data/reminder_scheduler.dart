import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'health_models.dart';

/// Everything that should remind the owner about one pet.
class ReminderPlan {
  const ReminderPlan({
    required this.petId,
    required this.petName,
    this.items = const [],
    this.upcoming = const [],
  });

  final String petId;
  final String petName;

  /// Active recurring reminders: routines and medicine times.
  final List<CarePlanItem> items;

  /// Planned appointments and due dates that are still ahead.
  final List<HealthRecord> upcoming;
}

/// Schedules the phone's notifications for a pet's care.
///
/// The Health feature calls [sync] with the pet's whole plan every time it
/// is loaded or changes; an implementation replaces whatever it had
/// scheduled for that pet. The app ships with [NoopReminderScheduler]: the
/// lead wires real local notifications behind this interface later.
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
