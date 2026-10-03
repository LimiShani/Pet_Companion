import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/reminder_scheduler.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';

// The scheduler between Health and the sink: one group per pet, and a plan
// that arrives with only half of the pet's data loaded never wipes the
// other half.

class _RecordingSink implements NotificationSink {
  final groups = <String, List<PlannedNotification>>{};

  @override
  Future<void> syncGroup(String group, List<PlannedNotification> items) async => groups[group] = items;
}

final _now = DateTime(2026, 10, 3, 12);

const _dinner = CarePlanItem(
  id: 'dinner',
  petId: 'kelly',
  kind: CareKind.feeding,
  title: 'Dinner',
  time: TimeOfDay(hour: 19, minute: 30),
);

final _check = HealthRecord(
  id: 'check',
  petId: 'kelly',
  kind: RecordKind.checkup,
  title: 'General check',
  scheduledAt: DateTime(2026, 10, 5, 18, 20),
);

void main() {
  late _RecordingSink sink;
  var language = englishLocale;
  late NotificationReminderScheduler scheduler;

  setUp(() {
    sink = _RecordingSink();
    language = englishLocale;
    scheduler = NotificationReminderScheduler(
      sink: sink,
      strings: () => lookupNotificationsL10n(language),
      now: () => _now,
      ringsFor: (petId) => petId != 'archived',
    );
  });

  Set<String> keys() => {for (final n in sink.groups['health:kelly']!) n.key};

  test('a pet\'s plan becomes the group health:<petId>', () async {
    await scheduler.sync(ReminderPlan(petId: 'kelly', petName: 'Kelly', items: const [_dinner], upcoming: [_check]));
    expect(keys(), containsAll(['item:dinner@2026-10-03', 'record:check@eve', 'record:check@2h']));
    expect(sink.groups['health:kelly']!.first.title, 'PetLoop · Kelly');
  });

  test('a plan without its records keeps the appointments, and the other way round', () async {
    await scheduler.sync(ReminderPlan(petId: 'kelly', petName: 'Kelly', items: const [_dinner], upcoming: [_check]));

    // The care plan changed while the records were not loaded.
    await scheduler.sync(const ReminderPlan(petId: 'kelly', petName: 'Kelly', upcomingLoaded: false));
    expect(keys(), {'record:check@eve', 'record:check@2h'});

    // The records changed while the care plan was not loaded.
    await scheduler.sync(const ReminderPlan(petId: 'kelly', petName: 'Kelly', items: [_dinner], upcomingLoaded: false));
    await scheduler.sync(const ReminderPlan(petId: 'kelly', petName: 'Kelly', itemsLoaded: false));
    expect(keys().where((k) => k.startsWith('record:')), isEmpty);
    expect(keys(), contains('item:dinner@2026-10-04'));
  });

  test('a new language plans every pet again', () async {
    await scheduler.sync(const ReminderPlan(petId: 'kelly', petName: 'Kelly', items: [_dinner]));
    language = hebrewLocale;
    await scheduler.replanAll();
    expect(sink.groups['health:kelly']!.first.body, '\u2068Dinner\u2069 · זמן להאכיל');
  });

  test('a pet that does not ring is ignored, and a forgotten pet is cancelled', () async {
    await scheduler.sync(const ReminderPlan(petId: 'archived', petName: 'Old', items: [_dinner]));
    expect(sink.groups, isEmpty);

    await scheduler.sync(const ReminderPlan(petId: 'kelly', petName: 'Kelly', items: [_dinner]));
    await scheduler.forget('kelly');
    expect(sink.groups['health:kelly'], isEmpty);
    expect(scheduler.petIds, isEmpty);
  });
}
