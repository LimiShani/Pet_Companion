import '../../../models/pet.dart';
import '../../health/data/health_models.dart';
import '../../health/state/schedule_logic.dart';
import '../data/care_models.dart';

/// One meal or walk of a day: a reminder's occurrence (with the owner's
/// answer once there is one), or an extra entry nobody planned ([item] is
/// `null`, [log] is set).
class CareEntry {
  const CareEntry({required this.time, required this.title, this.item, this.log});

  /// When it is due, or for an extra entry, when it was done.
  final DateTime time;
  final String title;
  final CarePlanItem? item;
  final CareLog? log;

  bool get isPlanned => item != null;
  bool get isAnswered => log != null;
  bool get isDone => log?.status == CareLogStatus.done;
  bool get isSkipped => log != null && log!.status != CareLogStatus.done;
}

/// The next planned occurrence that nobody answered, and whether it is
/// tomorrow's (every one of today's is answered or past).
class NextUp {
  const NextUp(this.entry, {this.tomorrow = false});

  final CareEntry entry;
  final bool tomorrow;
}

/// One bar of the week chart.
class DayTotal {
  const DayTotal(this.day, this.value);

  final DateTime day;
  final int value;
}

/// Everything Home's feeding card and the feeding page show for one day.
class FeedingDay {
  const FeedingDay({
    required this.settings,
    required this.meals,
    required this.calories,
    required this.goal,
    required this.estimate,
    required this.next,
    required this.week,
  });

  final CareSettings settings;

  /// Today's meals, earliest first.
  final List<CareEntry> meals;

  /// Calories of today's done meals.
  final int calories;

  /// The owner's goal, or else the app's estimate; `null` when neither.
  final int? goal;

  /// The app's estimate ([CalorieEstimate]) or why there is none
  /// ([NoEstimate]).
  final Object estimate;
  final NextUp? next;

  /// Calories of the last seven days, today last.
  final List<DayTotal> week;

  bool get goalIsEstimate => settings.calorieGoal == null && goal != null;
  bool get hasFood => settings.hasFood;
  bool get hasTimes => meals.any((m) => m.isPlanned) || next != null;

  /// Today's share of the goal, 0..1, or `null` without a goal.
  double? get progress {
    final g = goal;
    if (g == null || g <= 0) return null;
    return (calories / g).clamp(0.0, 1.0);
  }

  /// The meal the "Fed" button means: the unanswered one closest to now.
  CareEntry? suggested(DateTime now) => _closestOpen(meals, now);
}

/// Everything Home's activity card and the activity page show for one day.
class ActivityDay {
  const ActivityDay({
    required this.settings,
    required this.walks,
    required this.goalMinutes,
    required this.next,
    required this.week,
  });

  final CareSettings settings;

  /// Today's walks (or play sessions), earliest first.
  final List<CareEntry> walks;
  final int goalMinutes;
  final NextUp? next;

  /// Minutes of the last seven days, today last.
  final List<DayTotal> week;

  int get done => walks.where((w) => w.isDone).length;

  /// How many there are today: the planned ones plus the extra ones done.
  int get planned => walks.where((w) => w.isPlanned || w.isDone).length;
  int get minutes => walks.fold(0, (sum, w) => sum + (w.isDone ? (w.log!.minutes ?? 0) : 0));
  bool get hasTimes => walks.any((w) => w.isPlanned) || next != null;

  double get progress => goalMinutes <= 0 ? 0 : (minutes / goalMinutes).clamp(0.0, 1.0);

  CareEntry? suggested(DateTime now) => _closestOpen(walks, now);
}

/// One line of Home's health card.
class HealthItem {
  const HealthItem({required this.title, required this.when, this.dose, this.record});

  final String title;
  final DateTime when;

  /// A medicine reminder of today that nobody answered yet.
  final ScheduleEntry? dose;

  /// A planned visit, vaccination or treatment.
  final HealthRecord? record;

  bool get isDose => dose != null;
}

CareEntry? _closestOpen(List<CareEntry> entries, DateTime now) {
  CareEntry? best;
  for (final e in entries) {
    if (!e.isPlanned || e.isAnswered) continue;
    if (best == null || e.time.difference(now).abs() < best.time.difference(now).abs()) best = e;
  }
  return best;
}

/// The occurrences of the routines of [kind] on [day], and the extra
/// entries of that kind logged for it, earliest first.
List<CareEntry> entriesOfKind(CarePlan plan, CareKind kind, DateTime day) {
  final entries = <CareEntry>[
    for (final e in entriesOn(plan, day))
      if (e.item.kind == kind) CareEntry(time: e.due, title: e.item.title, item: e.item, log: e.log),
    for (final log in plan.logs)
      if (log.planItemId == null && log.kind == kind && isSameDay(log.dueOn, day))
        CareEntry(time: log.doneAt ?? log.loggedAt, title: log.title, log: log),
  ];
  entries.sort((a, b) => a.time.compareTo(b.time));
  return entries;
}

/// What a day's done entries of [kind] add up to ([value] of each log).
List<DayTotal> weekOf(CarePlan plan, CareKind kind, DateTime today, int Function(CareLog log) value) => [
  for (var back = 6; back >= 0; back--)
    () {
      final day = addDays(dateOnly(today), -back);
      var total = 0;
      for (final e in entriesOfKind(plan, kind, day)) {
        if (e.isDone) total += value(e.log!);
      }
      return DayTotal(day, total);
    }(),
];

NextUp? _next(CarePlan plan, CareKind kind, DateTime now) {
  final today = dateOnly(now);
  for (final e in entriesOfKind(plan, kind, today)) {
    if (e.isPlanned && !e.isAnswered && !e.time.isBefore(now)) return NextUp(e);
  }
  for (final e in entriesOfKind(plan, kind, addDays(today, 1))) {
    if (e.isPlanned) return NextUp(e, tomorrow: true);
  }
  return null;
}

FeedingDay feedingDay({
  required Pet pet,
  required CarePlan plan,
  required CareSettings settings,
  required DateTime now,
}) {
  final meals = entriesOfKind(plan, CareKind.feeding, now);
  final estimate = estimatedCalorieGoal(pet, now);
  return FeedingDay(
    settings: settings,
    meals: meals,
    calories: meals.fold(0, (sum, m) => sum + (m.isDone ? (m.log!.calories ?? 0) : 0)),
    goal: settings.calorieGoal ?? (estimate is CalorieEstimate ? estimate.calories : null),
    estimate: estimate,
    next: _next(plan, CareKind.feeding, now),
    week: weekOf(plan, CareKind.feeding, now, (log) => log.calories ?? 0),
  );
}

ActivityDay activityDay({
  required Pet pet,
  required CarePlan plan,
  required CareSettings settings,
  required DateTime now,
}) {
  return ActivityDay(
    settings: settings,
    walks: entriesOfKind(plan, CareKind.walk, now),
    goalMinutes: settings.activityGoalMinutes ?? defaultActivityGoal(pet.species),
    next: _next(plan, CareKind.walk, now),
    week: weekOf(plan, CareKind.walk, now, (log) => log.minutes ?? 0),
  );
}

/// Home's "Upcoming": today's medicine doses nobody answered yet and the
/// planned records from today on, soonest first.
List<HealthItem> upcomingHealth({required CarePlan plan, required List<HealthRecord> records, required DateTime now}) {
  final items = <HealthItem>[
    for (final e in entriesOn(plan, now))
      if (e.item.isMedication && !e.isAnswered) HealthItem(title: e.item.title, when: e.due, dose: e),
    for (final r in upcomingRecords(records, now)) HealthItem(title: r.title, when: r.scheduledAt, record: r),
  ];
  items.sort((a, b) => a.when.compareTo(b.when));
  return items;
}
