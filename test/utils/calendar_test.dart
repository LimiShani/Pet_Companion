import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart' hide addDays, daysBetween;
import 'package:pet_companion/features/health/state/schedule_logic.dart';
import 'package:pet_companion/utils/calendar.dart';

/// Israel's clocks went forward on Friday 27 March 2026 (a 23-hour day) and
/// go back on Sunday 25 October 2026 (a 25-hour day). On a machine in
/// another zone these dates are ordinary days and the tests still hold.
void main() {
  final springEve = DateTime(2026, 3, 27);
  final springAfter = DateTime(2026, 3, 28);
  final autumnDay = DateTime(2026, 10, 25);

  group('calendar days', () {
    test('adding and subtracting days lands on the right date across a clock change', () {
      expect(addDays(springAfter, -1), springEve);
      expect(addDays(springEve, 1), springAfter);
      expect(addDays(autumnDay, 1), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('the gap between two dates is counted in dates, not in hours', () {
      expect(daysBetween(springEve, springAfter), 1);
      expect(daysBetween(springAfter, springEve), -1);
      expect(daysBetween(DateTime(2026, 10, 25, 23, 30), DateTime(2026, 10, 26, 0, 10)), 1);
      expect(daysBetween(DateTime(2026, 6, 10, 23, 59), DateTime(2026, 6, 10, 0, 1)), 0);
    });
  });

  test('the seven days needing review include the day the clocks went forward', () {
    final plan = CarePlan(
      medications: const [Medication(id: 'm1', petId: 'p', name: 'Joint support')],
      items: [
        CarePlanItem(
          id: 'i1',
          petId: 'p',
          kind: CareKind.medication,
          title: 'Joint support',
          time: const TimeOfDay(hour: 8, minute: 0),
          medicationId: 'm1',
          startsOn: DateTime(2026, 1, 1),
        ),
      ],
    );

    final days = [for (final e in entriesNeedingReview(plan, DateTime(2026, 3, 28, 10))) dateOnly(e.due)];

    expect(days, [for (var back = 1; back <= 7; back++) DateTime(2026, 3, 28 - back)]);
    expect(days, contains(springEve));
  });
}
