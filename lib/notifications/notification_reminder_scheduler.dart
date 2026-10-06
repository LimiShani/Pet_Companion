import '../services/pet_records/data/reminder_scheduler.dart';
import '../l10n/l10n.dart';
import 'notification_sink.dart';
import 'reminder_planner.dart';

/// The real [ReminderScheduler]: turns each pet's [ReminderPlan] into
/// notifications ([planReminders]) in the group `health:<petId>` of a
/// [NotificationSink].
///
/// Health sends a plan whenever the care plan or the records of a pet load
/// or change, sometimes with only one of the two loaded; the scheduler
/// keeps the last known half of each pet, so a plan sent while the records
/// are not loaded never cancels the appointments. It also keeps the plans
/// to [replanAll] when the language changes.
class NotificationReminderScheduler implements ReminderScheduler {
  NotificationReminderScheduler({
    required NotificationSink sink,
    required NotificationsL10n Function() strings,
    DateTime Function() now = DateTime.now,
    bool Function(String petId)? ringsFor,
  }) : _sink = sink,
       _strings = strings,
       _now = now,
       _ringsFor = ringsFor;

  final NotificationSink _sink;
  final NotificationsL10n Function() _strings;
  final DateTime Function() _now;

  /// Whether reminders ring for a pet at all (signed in, not archived);
  /// plans of other pets are ignored.
  final bool Function(String petId)? _ringsFor;

  final _plans = <String, ReminderPlan>{};

  /// The pets whose plan the scheduler knows.
  Iterable<String> get petIds => _plans.keys;

  @override
  Future<void> sync(ReminderPlan plan) {
    if (!(_ringsFor?.call(plan.petId) ?? true)) return Future.value();
    final known = _plans[plan.petId];
    final merged = known == null ? plan : _merge(known, plan);
    _plans[plan.petId] = merged;
    return _send(merged);
  }

  /// Plans every known pet again (the language changed, or the day did).
  Future<void> replanAll() =>
      Future.wait([for (final plan in _plans.values) _send(plan)]);

  /// Forgets a pet and cancels its reminders.
  Future<void> forget(String petId) {
    _plans.remove(petId);
    return _sink.syncGroup(healthGroupOf(petId), const []);
  }

  /// Forgets every pet, without touching the phone (sign-out cancels
  /// everything through the sink).
  void clear() => _plans.clear();

  Future<void> _send(ReminderPlan plan) => _sink.syncGroup(
    healthGroupOf(plan.petId),
    planReminders(plan, now: _now(), l10n: _strings()),
  );

  /// [next], with the half it did not load taken from [known].
  static ReminderPlan _merge(ReminderPlan known, ReminderPlan next) {
    final items = next.itemsLoaded ? next : known;
    final records = next.upcomingLoaded ? next : known;
    return ReminderPlan(
      petId: next.petId,
      petName: next.petName.isEmpty ? known.petName : next.petName,
      items: items.items,
      medications: items.medications,
      logs: items.logs,
      upcoming: records.upcoming,
      itemsLoaded: items.itemsLoaded,
      upcomingLoaded: records.upcomingLoaded,
      today: next.today ?? known.today,
    );
  }
}
