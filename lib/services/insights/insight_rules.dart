/// One calm sentence from data the owner already logs: walks that got
/// shorter, a weight that moved, appetite that was less than usual. The
/// rules run on the phone; they never diagnose anything, and at most one
/// insight a week is shown for a pet (`insight_providers.dart`).
library;

import '../pet_records/data/health_models.dart';
import '../pet_records/state/schedule_logic.dart';

/// What an insight is about. [name] is what is remembered on the phone.
enum InsightKind {
  /// Appetite logged as "less than usual" three times or more in 14 days.
  appetiteLess,

  /// Weight up more than 5% within 8 weeks.
  weightUp,

  /// Weight down more than 5% within 8 weeks.
  weightDown,

  /// Walk minutes of the last 28 days more than 20% below the 28 before.
  shorterWalks,
}

/// Where an insight's one link leads.
enum InsightTarget { activity, weight, journal }

/// One insight about one pet.
class HealthInsight {
  const HealthInsight(this.kind, {this.percent = 0, this.count = 0});

  final InsightKind kind;

  /// How much it moved, in whole percent (walks, weight).
  final int percent;

  /// How many entries (appetite).
  final int count;

  InsightTarget get target => switch (kind) {
    InsightKind.shorterWalks => InsightTarget.activity,
    InsightKind.weightUp || InsightKind.weightDown => InsightTarget.weight,
    InsightKind.appetiteLess => InsightTarget.journal,
  };

  @override
  bool operator ==(Object other) =>
      other is HealthInsight &&
      other.kind == kind &&
      other.percent == percent &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, percent, count);
}

/// The window of each walks period, in days.
const walkWindowDays = 28;

/// Walk minutes must drop by more than this share.
const walkDropShare = 0.20;

/// Each period needs this many done walks with minutes, so a few logs
/// never make a trend.
const minWalksPerWindow = 4;

/// Weight: the window, the share, and how recent the last weight must be.
const weightWindowDays = 56;
const weightMoveShare = 0.05;
const weightRecentDays = 28;
const weightMinGapDays = 7;

/// Appetite: the window and how many "less than usual" entries.
const appetiteWindowDays = 14;
const appetiteMinCount = 3;

/// The observation category of appetite in the Quick log.
const appetiteCategory = 'appetite';

/// How far back [insightFor] needs the care logs.
const insightLogDays = walkWindowDays * 2;

/// The days a done walk counts for: walks are the logs of the pet's walk
/// routines ([walkItemIds]) and the extra walks.
bool _isWalk(CareLog log, Set<String> walkItemIds) =>
    log.kind == CareKind.walk ||
    (log.planItemId != null && walkItemIds.contains(log.planItemId));

/// Walk minutes of the [walkWindowDays] before [today] (today included)
/// against the same window before that; `null` when there is too little to
/// say. The two numbers are (recent, previous).
({int recent, int previous})? walkMinutes({
  required List<CareLog> logs,
  required Set<String> walkItemIds,
  required DateTime today,
}) {
  final day = dateOnly(today);
  final recentFrom = addDays(day, -(walkWindowDays - 1));
  final previousFrom = addDays(recentFrom, -walkWindowDays);
  var recent = 0, previous = 0, recentCount = 0, previousCount = 0;
  for (final log in logs) {
    if (log.status != CareLogStatus.done || !_isWalk(log, walkItemIds)) {
      continue;
    }
    final minutes = log.minutes;
    if (minutes == null || minutes <= 0) continue;
    final on = dateOnly(log.dueOn);
    if (on.isAfter(day) || on.isBefore(previousFrom)) continue;
    if (on.isBefore(recentFrom)) {
      previous += minutes;
      previousCount++;
    } else {
      recent += minutes;
      recentCount++;
    }
  }
  if (recentCount < minWalksPerWindow || previousCount < minWalksPerWindow) {
    return null;
  }
  return (recent: recent, previous: previous);
}

/// The rules, in the order they win when more than one holds: appetite
/// (the most recent), weight, walks. `null` when none holds.
HealthInsight? insightFor({
  required List<CareLog> logs,
  required Set<String> walkItemIds,
  required List<Observation> observations,
  required DateTime today,
}) {
  final day = dateOnly(today);

  // Appetite: "less than usual" entries in the last 14 days.
  final appetiteFrom = addDays(day, -(appetiteWindowDays - 1));
  final less = observations.where((o) {
    final on = dateOnly(o.observedAt);
    return o.category == appetiteCategory &&
        o.level == ObservationLevel.less &&
        !on.isBefore(appetiteFrom) &&
        !on.isAfter(day);
  }).length;
  if (less >= appetiteMinCount) {
    return HealthInsight(InsightKind.appetiteLess, count: less);
  }

  // Weight: the latest weight (from the last 4 weeks) against the earliest
  // of the 8 weeks before it, at least a week apart.
  final weights = weightEntries(observations)
      .where((o) => !dateOnly(o.observedAt).isAfter(day))
      .toList();
  if (weights.isNotEmpty) {
    final latest = weights.last;
    final latestDay = dateOnly(latest.observedAt);
    if (daysBetween(latestDay, day) <= weightRecentDays) {
      final from = addDays(latestDay, -weightWindowDays);
      Observation? base;
      for (final o in weights) {
        final on = dateOnly(o.observedAt);
        if (on.isBefore(from)) continue;
        if (daysBetween(on, latestDay) < weightMinGapDays) break;
        base = o;
        break;
      }
      final then = base?.value;
      final now = latest.value;
      if (then != null && now != null && then > 0) {
        final change = (now - then) / then;
        if (change.abs() > weightMoveShare) {
          return HealthInsight(
            change > 0 ? InsightKind.weightUp : InsightKind.weightDown,
            percent: (change.abs() * 100).round(),
          );
        }
      }
    }
  }

  // Walks: the last 4 weeks against the 4 before.
  final walks = walkMinutes(logs: logs, walkItemIds: walkItemIds, today: day);
  if (walks != null &&
      walks.previous > 0 &&
      walks.recent < walks.previous * (1 - walkDropShare)) {
    final drop = (walks.previous - walks.recent) / walks.previous;
    return HealthInsight(
      InsightKind.shorterWalks,
      percent: (drop * 100).round(),
    );
  }
  return null;
}

/// The ISO 8601 week of [day] as `2026-W42`: weeks start on Monday, and
/// week 1 is the one with the year's first Thursday.
String isoWeekOf(DateTime day) {
  final d = dateOnly(day);
  // The Thursday of the same ISO week decides the year.
  final thursday = addDays(d, DateTime.thursday - d.weekday);
  final firstThursday = () {
    final jan4 = DateTime(thursday.year, 1, 4);
    return addDays(jan4, DateTime.thursday - jan4.weekday);
  }();
  final week = daysBetween(firstThursday, thursday) ~/ 7 + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}
