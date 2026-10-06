import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/services/care/state/care_providers.dart';

import 'health_test_helpers.dart';

const kelly = 'kelly';

Future<void> _settle(ProviderContainer container) async {
  await container.read(carePlanProvider(kelly).future);
  await container.read(careSettingsProvider(kelly).future);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('an app left open overnight moves Home\'s care day to the new day '
      'and saves answers into it, not into yesterday', () async {
    final h = HealthHarness()..now = DateTime(2025, 6, 10, 23, 30);
    final container = h.container();
    container.listen(feedingDayProvider(kelly), (_, _) {});
    container.listen(activityDayProvider(kelly), (_, _) {});
    container.listen(upcomingHealthProvider(kelly), (_, _) {});
    await _settle(container);

    final evening = container.read(feedingDayProvider(kelly)).requireValue;
    expect(evening.meals.where((m) => m.isPlanned), isNotEmpty);
    expect(
      evening.meals.map((m) => dateOnly(m.time)).toSet(),
      {DateTime(2025, 6, 10)},
    );

    // The phone was asleep at midnight; the owner opens the app at 7:00.
    h.now = DateTime(2025, 6, 11, 7, 0);
    container.read(currentDayProvider.notifier).check();
    await _settle(container);

    expect(container.read(currentDayProvider), DateTime(2025, 6, 11));
    final morning = container.read(feedingDayProvider(kelly)).requireValue;
    expect(
      morning.meals.map((m) => dateOnly(m.time)).toSet(),
      {DateTime(2025, 6, 11)},
    );
    expect(morning.meals.where((m) => m.isAnswered), isEmpty);
    final activity = container.read(activityDayProvider(kelly)).requireValue;
    expect(
      activity.walks.map((w) => dateOnly(w.time)).toSet(),
      everyElement(DateTime(2025, 6, 11)),
    );

    // What the meal sheet does with the suggested meal.
    final meal = morning.meals.firstWhere((m) => m.isPlanned);
    bool yesterdays(CareLog l) =>
        l.planItemId == meal.item!.id && l.dueOn == DateTime(2025, 6, 10);
    final before = (await container.read(carePlanProvider(kelly).future))
        .logs
        .where(yesterdays)
        .map((l) => (l.id, l.status, l.loggedAt))
        .toList();
    final log = await container
        .read(carePlanProvider(kelly).notifier)
        .record(
          item: meal.item,
          dueOn: meal.time,
          status: CareLogStatus.done,
        );
    expect(log.dueOn, DateTime(2025, 6, 11));
    final plan = await container.read(carePlanProvider(kelly).future);
    expect(
      plan.logs.where(yesterdays).map((l) => (l.id, l.status, l.loggedAt)),
      before,
      reason: 'Yesterday\'s answer must not be overwritten',
    );
  });

  test('the day does not change while the clock stays on the same date', () {
    final h = HealthHarness()..now = DateTime(2025, 6, 10, 8, 0);
    final container = h.container();
    final days = <DateTime>[];
    container.listen(currentDayProvider, (_, next) => days.add(next));

    h.now = DateTime(2025, 6, 10, 23, 59);
    container.read(currentDayProvider.notifier).check();
    expect(days, isEmpty);

    h.now = DateTime(2025, 6, 11, 0, 0, 1);
    container.read(currentDayProvider.notifier).check();
    expect(days, [DateTime(2025, 6, 11)]);
  });
}
