import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../access/access_provider.dart';
import '../l10n/l10n.dart';
import '../services/insights/insight_providers.dart' show insightsCapability;
import '../services/insights/weekly_summary.dart';
import '../services/pet_records/data/health_models.dart';
import '../services/pet_records/state/schedule_logic.dart';
import 'notification_settings.dart';
import 'notification_sink.dart';
import 'reminder_planner.dart' show healthTarget;

/// The group of one pet's weekly summary in the sink.
String weeklyGroupOf(String petId) => 'week:$petId';

/// The next moment after [now] that is on ISO weekday [weekday] at
/// [minutes] past midnight (a week ahead when that is right now or past
/// today).
DateTime nextWeeklyAt(DateTime now, int weekday, int minutes) {
  final today = dateOnly(now);
  var day = addDays(today, (weekday - today.weekday) % 7);
  var at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  if (!at.isAfter(now)) {
    day = addDays(day, 7);
    at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }
  return at;
}

/// "Rabies vaccine due in 3 weeks": the next planned record, counted from
/// [from] (the summary's day).
String dueLine(NotificationsL10n l10n, HealthRecord record, DateTime from) {
  final title = record.title.trim().isEmpty
      ? l10n.appointments
      : record.title.trim();
  final days = daysBetween(from, record.scheduledAt);
  if (days <= 0) return l10n.weeklyDueToday(title);
  if (days == 1) return l10n.weeklyDueTomorrow(title);
  if (days < 14) return l10n.weeklyDueInDays(title, days);
  if (days <= 8 * 7) return l10n.weeklyDueInWeeks(title, (days / 7).round());
  return l10n.weeklyDueOn(title, DateFormat('dd.MM.yy').format(record.scheduledAt));
}

/// The text of a summary: "Last week: 9 of 12 walks · 14 of 14 doses
/// given", then the next due record on a line of its own. `null` when
/// there is nothing to say.
String? weeklyBody(NotificationsL10n l10n, WeekNumbers numbers, DateTime ringDay) {
  if (numbers.isEmpty) return null;
  final week = [
    if (numbers.walksPlanned > 0)
      l10n.weeklyWalks(numbers.walksDone, numbers.walksPlanned)
    else if (numbers.extraWalks > 0)
      l10n.weeklyWalksLogged(numbers.extraWalks),
    if (numbers.hasDoses)
      l10n.weeklyDoses(numbers.dosesGiven, numbers.dosesPlanned),
  ];
  final next = numbers.nextDue;
  return [
    if (week.isNotEmpty) l10n.weeklyLastWeek(week.join(' · ')),
    if (next != null) dueLine(l10n, next, ringDay),
  ].join('\n');
}

/// The weekly summary of a pet, ringing at the next chosen weekday and
/// time after [now] (the real clock), or `null` when there is nothing to
/// say. [dataToday] is "today" in the world of the data (the sample data's
/// day in the demo): the numbers are counted there and the summary rings
/// in the real world.
PlannedNotification? planWeeklySummary({
  required String petId,
  required String petName,
  required CarePlan plan,
  required List<HealthRecord> records,
  required DateTime now,
  required DateTime dataToday,
  required NotificationSettings settings,
  required int firstDay,
  required NotificationsL10n l10n,
}) {
  final at = nextWeeklyAt(
    now,
    settings.weeklyDayOr(firstDay),
    settings.weeklyMinutes,
  );
  final shift = daysBetween(dateOnly(now), dateOnly(dataToday));
  final dataRingDay = addDays(dateOnly(at), shift);
  final numbers = weekNumbers(
    plan: plan,
    records: records,
    ringDay: dataRingDay,
    today: dataToday,
    firstDay: firstDay,
  );
  final body = weeklyBody(l10n, numbers, dataRingDay);
  if (body == null) return null;
  final name = petName.trim();
  return PlannedNotification(
    key: 'week@${dateOnly(at).toIso8601String().substring(0, 10)}',
    kind: NotificationKind.weekly,
    at: at,
    title: name.isEmpty ? 'PetLoop' : l10n.weeklyTitle(name),
    body: body,
    payload: healthTarget(petId),
  );
}

/// What one pet's summary was last planned from.
class _WeekInput {
  const _WeekInput(this.petName, this.plan, this.records, this.dataToday);

  final String petName;
  final CarePlan plan;
  final List<HealthRecord> records;
  final DateTime dataToday;
}

/// Keeps each pet's weekly summary scheduled in its own group
/// ([weeklyGroupOf]) of the [NotificationSink]: one notification, the next
/// one. `ReminderCoordinator` hands it every pet's care plan and records
/// when it loads them (at sign-in, and again on another day); it plans
/// again on its own when the language, the week or the chosen day and time
/// change. No "Done" button: there is nothing to tick.
class WeeklySummaryScheduler {
  WeeklySummaryScheduler({
    required NotificationSink sink,
    required NotificationsL10n Function() strings,
    required NotificationSettings Function() settings,
    required int Function() firstDay,
    required bool Function() allowed,
    DateTime Function() now = DateTime.now,
  }) : _sink = sink,
       _strings = strings,
       _settings = settings,
       _firstDay = firstDay,
       _allowed = allowed,
       _now = now;

  final NotificationSink _sink;
  final NotificationsL10n Function() _strings;
  final NotificationSettings Function() _settings;
  final int Function() _firstDay;
  final bool Function() _allowed;
  final DateTime Function() _now;
  final _inputs = <String, _WeekInput>{};

  /// Plans [petId]'s summary from its care plan and records. When either
  /// could not be loaded (`null`), the last known one is used, and nothing
  /// changes before both have been known once.
  Future<void> sync({
    required String petId,
    required String petName,
    required CarePlan? plan,
    required List<HealthRecord>? records,
    required DateTime dataToday,
  }) {
    final known = _inputs[petId];
    final p = plan ?? known?.plan;
    final r = records ?? known?.records;
    if (p == null || r == null) return Future.value();
    final input = _WeekInput(
      petName.isEmpty ? known?.petName ?? '' : petName,
      p,
      r,
      dataToday,
    );
    _inputs[petId] = input;
    return _send(petId, input);
  }

  /// Plans every known pet again.
  Future<void> replanAll() => Future.wait([
    for (final MapEntry(key: petId, value: input) in _inputs.entries)
      _send(petId, input),
  ]);

  /// Forgets a pet and cancels its summary.
  Future<void> forget(String petId) {
    _inputs.remove(petId);
    return _sink.syncGroup(weeklyGroupOf(petId), const []);
  }

  /// Forgets every pet, without touching the phone (sign-out cancels
  /// everything through the sink).
  void clear() => _inputs.clear();

  Future<void> _send(String petId, _WeekInput input) {
    final planned = _allowed()
        ? planWeeklySummary(
            petId: petId,
            petName: input.petName,
            plan: input.plan,
            records: input.records,
            now: _now(),
            dataToday: input.dataToday,
            settings: _settings(),
            firstDay: _firstDay(),
            l10n: _strings(),
          )
        : null;
    return _sink.syncGroup(weeklyGroupOf(petId), [?planned]);
  }
}

/// The weekly summaries' scheduler, on the app's sink.
final weeklySummarySchedulerProvider = Provider<WeeklySummaryScheduler>((ref) {
  final scheduler = WeeklySummaryScheduler(
    sink: ref.watch(notificationSinkProvider),
    strings: () => ref.read(notificationsL10nProvider),
    settings: () => ref.read(notificationSettingsProvider),
    firstDay: () => ref.read(weekSettingsProvider).firstDay,
    allowed: () => canUse(ref, insightsCapability),
  );
  void replan() => scheduler.replanAll();
  ref.listen(notificationsL10nProvider, (_, _) => replan());
  ref.listen(weekSettingsProvider, (_, _) => replan());
  ref.listen(
    notificationSettingsProvider.select(
      (s) => (s.weeklyDay, s.weeklyMinutes),
    ),
    (_, _) => replan(),
  );
  ref.listen(capabilityProvider(insightsCapability), (_, _) => replan());
  return scheduler;
});
