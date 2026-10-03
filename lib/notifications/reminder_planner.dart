import 'package:intl/intl.dart';

import '../features/health/data/health_models.dart';
import '../features/health/data/reminder_scheduler.dart';
import '../l10n/l10n.dart';
import 'notification_sink.dart';

/// How many days of routines and medicine times are planned ahead. The app
/// plans again whenever it opens, so the week keeps moving.
const routineDaysAhead = 7;

/// The appointment reminder of the evening before rings at 18:00...
const appointmentEveningHour = 18;

/// ...and the second one this long before the appointment.
const appointmentLeadTime = Duration(hours: 2);

/// The group of one pet's Health reminders in the sink.
String healthGroupOf(String petId) => 'health:$petId';

/// Where tapping a reminder leads; see [NotificationSink].
String feedingTarget(String petId) => 'feeding:$petId';
String activityTarget(String petId) => 'activity:$petId';
String healthTarget(String petId) => 'health:$petId';

/// The kind of notification a care plan item rings as, or `null` for the
/// routines that do not ring (grooming, cleaning, other).
NotificationKind? notificationKindOf(CareKind kind) => switch (kind) {
  CareKind.feeding => NotificationKind.meal,
  CareKind.walk => NotificationKind.walk,
  CareKind.medication => NotificationKind.medicine,
  _ => null,
};

/// Turns a pet's [plan] into the notifications of the coming
/// [routineDaysAhead] days, soonest first, with their texts in [l10n]'s
/// language. [now] is the real clock: reminders ring in the real world.
///
/// - Meals, walks and medicine times ring at their time on every day they
///   occur, from today; an occurrence that already has an answer in the
///   log (done, skipped or "not sure") does not ring. Grooming and the
///   other routines never ring.
/// - Every planned record (appointment or due date) rings the evening
///   before at 18:00 and 2 hours before.
///
/// Today's occurrences are included even when their time has passed: the
/// sink drops what is in the past after quiet hours have moved it.
///
/// When [ReminderPlan.today] is another day than [now] (the demo's sample
/// data lives in June 2025), the plan's dates are moved by the difference,
/// so the plan's "today" rings today.
List<PlannedNotification> planReminders(
  ReminderPlan plan, {
  required DateTime now,
  required NotificationsL10n l10n,
  int days = routineDaysAhead,
}) {
  final today = dateOnly(now);
  final shift = plan.today == null ? 0 : daysBetween(plan.today!, today);
  final petId = plan.petId;
  final petName = plan.petName.trim();
  final title = petName.isEmpty ? 'PetLoop' : l10n.title(petName);
  final result = <PlannedNotification>[];

  Medication? medicationOf(String? id) {
    for (final m in plan.medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  bool answered(CarePlanItem item, DateTime planDay) {
    for (final log in plan.logs) {
      if (log.planItemId == item.id && isSameDay(log.dueOn, planDay)) return true;
    }
    return false;
  }

  for (final item in plan.items) {
    final kind = notificationKindOf(item.kind);
    if (kind == null || !item.active) continue;
    final medication = medicationOf(item.medicationId);
    final body = switch (kind) {
      NotificationKind.meal => l10n.mealBody(_or(item.title, l10n.meals)),
      NotificationKind.walk => _or(item.title, l10n.walkFallback),
      _ => _medicineBody(l10n, item, medication),
    };
    final target = switch (kind) {
      NotificationKind.meal => feedingTarget(petId),
      NotificationKind.walk => activityTarget(petId),
      _ => healthTarget(petId),
    };
    for (var d = 0; d < days; d++) {
      final day = addDays(today, d);
      final planDay = addDays(day, -shift);
      if (!item.occursOn(planDay)) continue;
      if (medication != null && !medication.isActiveOn(planDay)) continue;
      if (answered(item, planDay)) continue;
      result.add(
        PlannedNotification(
          key: 'item:${item.id}@${_day(day)}',
          kind: kind,
          at: atTime(day, item.time),
          title: title,
          body: body,
          payload: target,
        ),
      );
    }
  }

  final time = DateFormat('HH:mm');
  final date = DateFormat('dd.MM.yy');
  for (final record in plan.upcoming) {
    if (record.isDone) continue;
    final s = record.scheduledAt;
    final at = DateTime(s.year, s.month, s.day + shift, s.hour, s.minute);
    final evening = DateTime(at.year, at.month, at.day - 1, appointmentEveningHour);
    final before = at.subtract(appointmentLeadTime);
    String body(DateTime ringsAt) {
      final when = time.format(at);
      final what = _or(record.title, l10n.appointments);
      final text = switch (daysBetween(ringsAt, at)) {
        0 => l10n.appointmentToday(when, what),
        1 => l10n.appointmentTomorrow(when, what),
        _ => l10n.appointmentOn(date.format(at), when, what),
      };
      final place = record.clinic.trim();
      return place.isEmpty ? text : l10n.withPlace(text, place);
    }

    for (final (suffix, ringsAt) in [('eve', evening), ('2h', before)]) {
      result.add(
        PlannedNotification(
          key: 'record:${record.id}@$suffix',
          kind: NotificationKind.appointment,
          at: ringsAt,
          title: title,
          body: body(ringsAt),
          payload: healthTarget(petId),
        ),
      );
    }
  }

  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}

String _medicineBody(NotificationsL10n l10n, CarePlanItem item, Medication? medication) {
  final name = _or(medication?.name ?? item.title, l10n.medicines);
  final dose = medication?.dose.trim() ?? '';
  return dose.isEmpty ? l10n.medicineNoDose(name) : l10n.medicineBody(name, dose);
}

String _or(String text, String fallback) => text.trim().isEmpty ? fallback : text.trim();

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
