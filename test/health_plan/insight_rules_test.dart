import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/services/insights/insight_providers.dart';
import 'package:pet_companion/services/insights/insight_rules.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';

final today = DateTime(2026, 10, 17);

CareLog walk(int daysAgo, int minutes, {String item = 'walk-1', bool extra = false}) => CareLog(
  id: 'w$daysAgo-$minutes-$item',
  petId: 'kelly',
  title: 'Walk',
  dueOn: addDays(today, -daysAgo),
  status: CareLogStatus.done,
  loggedAt: addDays(today, -daysAgo),
  planItemId: extra ? null : item,
  kind: extra ? CareKind.walk : null,
  minutes: minutes,
);

Observation weight(int daysAgo, double kg) => Observation(
  id: 'kg$daysAgo',
  petId: 'kelly',
  category: Observation.weightCategory,
  value: kg,
  observedAt: addDays(today, -daysAgo),
);

Observation appetite(int daysAgo, ObservationLevel level) => Observation(
  id: 'a$daysAgo$level',
  petId: 'kelly',
  category: appetiteCategory,
  level: level,
  observedAt: addDays(today, -daysAgo),
);

HealthInsight? run({
  List<CareLog> logs = const [],
  List<Observation> observations = const [],
}) => insightFor(
  logs: logs,
  walkItemIds: const {'walk-1'},
  observations: observations,
  today: today,
);

/// Walks of [minutes] every other day over 4 weeks starting [from] days ago.
List<CareLog> walks(int from, int minutes) => [
  for (var d = from; d > from - 28; d -= 2) walk(d, minutes),
];

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('walks', () {
    test('more than 20% fewer minutes than the 4 weeks before', () {
      final insight = run(logs: [...walks(55, 40), ...walks(27, 30)]);
      expect(insight?.kind, InsightKind.shorterWalks);
      expect(insight?.percent, 25);
      expect(insight?.target, InsightTarget.activity);
    });

    test('20% or less is no insight, nor are a few logs', () {
      expect(run(logs: [...walks(55, 40), ...walks(27, 32)]), isNull);
      expect(run(logs: [walk(50, 60), walk(40, 60), walk(30, 60), walk(5, 10)]), isNull);
    });

    test('extra walks count; other routines and skipped walks do not', () {
      final skipped = CareLog(
        id: 's',
        petId: 'kelly',
        title: 'Walk',
        dueOn: addDays(today, -3),
        status: CareLogStatus.skipped,
        loggedAt: today,
        planItemId: 'walk-1',
        minutes: 300,
      );
      final meal = walk(2, 300, item: 'dinner');
      final extras = [for (var d = 27; d > 0; d -= 4) walk(d, 30, extra: true)];
      final insight = run(logs: [...walks(55, 40), ...extras, skipped, meal]);
      expect(insight?.kind, InsightKind.shorterWalks);
      expect(walkMinutes(logs: extras, walkItemIds: const {}, today: today), isNull,
          reason: 'nothing in the 4 weeks before');
    });
  });

  group('weight', () {
    test('moved more than 5% within 8 weeks, up or down', () {
      final down = run(observations: [weight(50, 30), weight(20, 29), weight(3, 28.2)]);
      expect(down?.kind, InsightKind.weightDown);
      expect(down?.percent, 6);
      expect(down?.target, InsightTarget.weight);
      final up = run(observations: [weight(40, 4.0), weight(1, 4.4)]);
      expect(up?.kind, InsightKind.weightUp);
      expect(up?.percent, 10);
    });

    test('a small change, an old change, or two weights a few days apart '
        'is no insight', () {
      expect(run(observations: [weight(40, 30), weight(1, 31)]), isNull);
      // The base is older than 8 weeks before the last weight.
      expect(run(observations: [weight(80, 30), weight(1, 33)]), isNull);
      // The last weight is more than 4 weeks old.
      expect(run(observations: [weight(80, 30), weight(40, 33)]), isNull);
      expect(run(observations: [weight(4, 30), weight(1, 33)]), isNull);
    });
  });

  group('appetite', () {
    test('three "less than usual" in 14 days, and it wins over the others', () {
      final insight = run(
        logs: [...walks(55, 40), ...walks(27, 20)],
        observations: [
          appetite(13, ObservationLevel.less),
          appetite(6, ObservationLevel.less),
          appetite(1, ObservationLevel.less),
          appetite(2, ObservationLevel.usual),
        ],
      );
      expect(insight?.kind, InsightKind.appetiteLess);
      expect(insight?.count, 3);
      expect(insight?.target, InsightTarget.journal);
    });

    test('two, or older ones, are not enough', () {
      expect(
        run(observations: [
          appetite(14, ObservationLevel.less),
          appetite(6, ObservationLevel.less),
          appetite(1, ObservationLevel.less),
        ]),
        isNull,
      );
    });
  });

  group('once a week', () {
    test('ISO weeks', () {
      expect(isoWeekOf(DateTime(2026, 10, 17)), '2026-W42');
      expect(isoWeekOf(DateTime(2026, 1, 1)), '2026-W01');
      expect(isoWeekOf(DateTime(2027, 1, 1)), '2026-W53');
      expect(isoWeekOf(DateTime(2024, 12, 30)), '2025-W01');
      expect(isoWeekOf(DateTime(2026, 10, 12)), isoWeekOf(DateTime(2026, 10, 18)));
      expect(isoWeekOf(DateTime(2026, 10, 18)), isNot(isoWeekOf(DateTime(2026, 10, 19))));
    });

    test('the first insight of the week is remembered and is the only one '
        'that week', () {
      const walksDown = HealthInsight(InsightKind.shorterWalks, percent: 25);
      const appetiteLess = HealthInsight(InsightKind.appetiteLess, count: 3);
      final first = pickWeeklyInsight(found: walksDown, remembered: null, today: today);
      expect(first.show, walksDown);
      expect(first.remember, '2026-W42|shorterWalks');
      // Later that week: the same one again, never a second one.
      final again = pickWeeklyInsight(found: walksDown, remembered: first.remember, today: addDays(today, 1));
      expect(again.show, walksDown);
      expect(again.remember, isNull);
      final other = pickWeeklyInsight(found: appetiteLess, remembered: first.remember, today: addDays(today, 1));
      expect(other.show, isNull);
      // A new week starts over.
      final next = pickWeeklyInsight(found: appetiteLess, remembered: first.remember, today: addDays(today, 2));
      expect(next.show, appetiteLess);
      expect(next.remember, '2026-W43|appetiteLess');
      expect(pickWeeklyInsight(found: null, remembered: null, today: today).show, isNull);
    });
  });
}
