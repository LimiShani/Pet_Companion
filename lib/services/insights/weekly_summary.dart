/// The numbers of "Kelly's week", the weekly summary notification: walks
/// done of those planned last week, medicine doses marked as given, and
/// the next planned health record. The words are in
/// `lib/notifications/weekly_summary_planner.dart`.
library;

import '../pet_records/data/health_models.dart';
import '../pet_records/state/schedule_logic.dart';

/// The first day of the week [day] is in, for a week starting on
/// [firstDay] (an ISO weekday: Monday = 1 ... Sunday = 7).
DateTime weekStartOf(DateTime day, int firstDay) {
  final d = dateOnly(day);
  return addDays(d, -((d.weekday - firstDay) % 7));
}

/// What the weekly summary says about one pet.
class WeekNumbers {
  const WeekNumbers({
    required this.from,
    required this.to,
    this.walksDone = 0,
    this.walksPlanned = 0,
    this.extraWalks = 0,
    this.dosesGiven = 0,
    this.dosesPlanned = 0,
    this.nextDue,
  });

  /// The week counted: [from] up to [to], [to] not included.
  final DateTime from;
  final DateTime to;

  /// Occurrences of the walk routines that were done, of those planned.
  final int walksDone;
  final int walksPlanned;

  /// Walks logged without a routine (counted only when none is planned).
  final int extraWalks;

  /// Medicine reminders answered "given", of those planned. A reminder
  /// nobody answered is not a missed dose: it simply is not counted as
  /// given.
  final int dosesGiven;
  final int dosesPlanned;

  /// The next planned record from the summary's day on.
  final HealthRecord? nextDue;

  bool get hasWalks => walksPlanned > 0 || extraWalks > 0;
  bool get hasDoses => dosesPlanned > 0;

  /// Nothing to say: no notification is sent.
  bool get isEmpty => !hasWalks && !hasDoses && nextDue == null;
}

/// The numbers of the summary that rings on [ringDay]: the week before
/// the one [ringDay] is in (weeks start on [firstDay]), counting only the
/// days before [today] (the summary is composed ahead of time, when the
/// app plans it), and the first planned record from [ringDay] on.
///
/// Every date is in the world of the data (the sample data's days in the
/// demo).
WeekNumbers weekNumbers({
  required CarePlan plan,
  required List<HealthRecord> records,
  required DateTime ringDay,
  required DateTime today,
  required int firstDay,
}) {
  final to = weekStartOf(ringDay, firstDay);
  final from = addDays(to, -7);
  final until = dateOnly(today).isBefore(to) ? dateOnly(today) : to;
  var walksDone = 0, walksPlanned = 0, extra = 0;
  var dosesGiven = 0, dosesPlanned = 0;
  for (var day = from; day.isBefore(until); day = addDays(day, 1)) {
    for (final e in entriesOn(plan, day)) {
      if (e.item.kind == CareKind.walk) {
        walksPlanned++;
        if (e.isDone) walksDone++;
      } else if (e.item.isMedication) {
        dosesPlanned++;
        if (e.isDone) dosesGiven++;
      }
    }
    for (final log in plan.logs) {
      if (log.planItemId == null &&
          log.kind == CareKind.walk &&
          log.status == CareLogStatus.done &&
          isSameDay(log.dueOn, day)) {
        extra++;
      }
    }
  }
  final upcoming = upcomingRecords(records, ringDay);
  return WeekNumbers(
    from: from,
    to: to,
    walksDone: walksDone,
    walksPlanned: walksPlanned,
    extraWalks: walksPlanned > 0 ? 0 : extra,
    dosesGiven: dosesGiven,
    dosesPlanned: dosesPlanned,
    nextDue: upcoming.isEmpty ? null : upcoming.first,
  );
}
