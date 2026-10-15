import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/reminder_scheduler.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';

// "Done" on a reminder: what the payload carries (and what an old payload
// decodes to), which reminders get the button, and the queue the presses
// of the background isolate wait in.

final _en = lookupNotificationsL10n(englishLocale);

/// Saturday 3 October 2026, noon.
final _now = DateTime(2026, 10, 3, 12);

final _dinner = CareDone(
  petId: 'kelly',
  itemId: 'dinner',
  kind: CareDoneKind.meal,
  dueOn: DateTime(2026, 10, 3),
  dueMinutes: 19 * 60 + 30,
);

ScheduledNotification _reminder({CareDone? done, String doneLabel = 'Done'}) => ScheduledNotification(
  group: 'health:kelly',
  key: 'item:dinner@2026-10-03',
  kind: NotificationKind.meal,
  at: DateTime(2026, 10, 3, 19, 30),
  title: 'PetLoop · Kelly',
  body: 'Dinner · time to feed',
  target: 'feeding:kelly',
  channelName: 'Meals',
  snoozeLabel: 'In 15 min',
  done: done,
  doneLabel: done == null ? '' : doneLabel,
);

CarePlanItem _item(String id, CareKind kind, int hour, {String? medicationId}) => CarePlanItem(
  id: id,
  petId: 'kelly',
  kind: kind,
  title: id,
  time: TimeOfDay(hour: hour, minute: 0),
  medicationId: medicationId,
);

void main() {
  group('the payload', () {
    test('carries what Done records, and decodes to the same', () {
      final n = _reminder(done: _dinner);
      final back = ScheduledNotification.decode(n.encode())!;
      expect(back.done, _dinner);
      expect(back.doneLabel, 'Done');
      expect(back.hasDone, isTrue);
      expect(back.encode(), n.encode());
      final action = back.doneAt(DateTime(2026, 10, 3, 19, 40))!;
      expect(action.done, _dinner);
      expect(action.group, 'health:kelly');
      expect(action.key, 'item:dinner@2026-10-03');
      expect(action.occurrenceKey, 'dinner@2026-10-03T19:30');
    });

    test('keeps the demo\'s shift of days', () {
      final shifted = CareDone(
        petId: 'kelly',
        itemId: 'walk',
        kind: CareDoneKind.walk,
        dueOn: DateTime(2025, 6, 10),
        dueMinutes: 18 * 60 + 30,
        shiftDays: 480,
      );
      expect(ScheduledNotification.decode(_reminder(done: shifted).encode())!.done, shifted);
    });

    test('of a version before Done decodes to a reminder without Done', () {
      // What the app wrote before the button existed.
      final old = jsonEncode({
        'g': 'health:kelly',
        'k': 'item:dinner@2026-10-03',
        'n': 'meal',
        'a': DateTime(2026, 10, 3, 19, 30).millisecondsSinceEpoch,
        't': 'PetLoop · Kelly',
        'b': 'Dinner · time to feed',
        'p': 'feeding:kelly',
        'c': 'Meals',
        'z': 'In 15 min',
      });
      final n = ScheduledNotification.decode(old)!;
      expect(n.key, 'item:dinner@2026-10-03');
      expect(n.snoozeLabel, 'In 15 min');
      expect(n.done, isNull);
      expect(n.hasDone, isFalse);
      expect(n.doneAt(_now), isNull);
    });

    test('with an unreadable Done is a reminder without Done', () {
      final map = jsonDecode(_reminder(done: _dinner).encode()) as Map<String, dynamic>;
      map['d'] = {'pet': 'kelly', 'kind': 'meal'};
      final n = ScheduledNotification.decode(jsonEncode(map))!;
      expect(n.done, isNull);
      expect(n.hasDone, isFalse);
    });

    test('without a label has no Done button', () {
      expect(_reminder(done: _dinner, doneLabel: '').hasDone, isFalse);
      expect(_reminder().hasDone, isFalse);
    });
  });

  group('which reminders have Done', () {
    test('meals, walks, medicine times and routines; appointments do not', () {
      final plan = ReminderPlan(
        petId: 'kelly',
        petName: 'Kelly',
        items: [
          _item('dinner', CareKind.feeding, 19),
          _item('walk', CareKind.walk, 18),
          _item('joint-pm', CareKind.medication, 20, medicationId: 'joint'),
        ],
        medications: const [Medication(id: 'joint', petId: 'kelly', name: 'Joint tablets')],
        upcoming: [
          HealthRecord(
            id: 'check',
            petId: 'kelly',
            kind: RecordKind.checkup,
            title: 'General check',
            scheduledAt: DateTime(2026, 10, 5, 18, 20),
          ),
        ],
      );
      final reminders = planReminders(plan, now: _now, l10n: _en, days: 1);
      final byKey = {for (final r in reminders) r.key: r};
      expect(byKey['item:dinner@2026-10-03']!.done, _dinner.copyWithHour(19));
      expect(byKey['item:walk@2026-10-03']!.done!.kind, CareDoneKind.walk);
      final dose = byKey['item:joint-pm@2026-10-03']!.done!;
      expect(dose.kind, CareDoneKind.dose);
      expect(dose.dueMinutes, 20 * 60);
      expect(byKey['record:check@eve']!.done, isNull);
      expect(byKey['record:check@2h']!.done, isNull);
    });

    test('a routine kind other than meals, walks and medicines records as a routine', () {
      expect(careDoneKindOf(CareKind.grooming), CareDoneKind.routine);
      expect(careDoneKindOf(CareKind.litterCleaning), CareDoneKind.routine);
      expect(careDoneKindOf(CareKind.feeding), CareDoneKind.meal);
      expect(careDoneKindOf(CareKind.medication), CareDoneKind.dose);
    });

    test('the sink adds the label only where there is something to record', () {
      final scheduled = notificationsToSchedule(
        groups: {
          'health:kelly': [
            PlannedNotification(
              key: 'item:dinner@2026-10-03',
              kind: NotificationKind.meal,
              at: DateTime(2026, 10, 3, 19, 30),
              title: 'PetLoop · Kelly',
              body: 'Dinner',
              done: _dinner,
            ),
            PlannedNotification(
              key: 'record:check@eve',
              kind: NotificationKind.appointment,
              at: DateTime(2026, 10, 4, 18),
              title: 'PetLoop · Kelly',
              body: 'Tomorrow',
            ),
          ],
          // The basket's reminders never carry a Done (basket_logic.dart).
          'basket:kelly': [
            PlannedNotification(
              key: 'food@2026-10-10',
              kind: NotificationKind.basket,
              at: DateTime(2026, 10, 5, 10),
              title: 'Basket',
              body: 'Adult dry food runs out in 5 days',
            ),
          ],
        },
        settings: NotificationSettings.defaults,
        now: _now,
        chrome: const NotificationChrome(snoozeLabel: 'In 15 min', doneLabel: 'Done'),
      );
      final byKey = {for (final n in scheduled) n.key: n};
      expect(byKey['item:dinner@2026-10-03']!.hasDone, isTrue);
      expect(byKey['item:dinner@2026-10-03']!.doneLabel, 'Done');
      expect(byKey['record:check@eve']!.hasDone, isFalse);
      expect(byKey['food@2026-10-10']!.hasDone, isFalse);
      expect(byKey['food@2026-10-10']!.doneLabel, '');
    });

    test('a reminder that quiet hours move keeps its Done', () {
      final late = PlannedNotification(
        key: 'item:snack@2026-10-03',
        kind: NotificationKind.meal,
        at: DateTime(2026, 10, 3, 23),
        title: 'PetLoop · Kelly',
        body: 'Snack',
        done: _dinner,
      );
      final moved = applySettings([late], NotificationSettings.defaults.copyWith(quietHours: true));
      expect(moved.single.at, DateTime(2026, 10, 4, 7));
      expect(moved.single.done, _dinner);
    });
  });

  group('the queue', () {
    test('the background isolate queues a press with its time', () async {
      final store = MemoryDoneQueueStore();
      final pressed = DateTime(2026, 10, 3, 19, 41);
      await queueDoneInBackground(_reminder(done: _dinner).encode(), store: store, now: pressed);
      final pending = await DoneQueue(store).pending();
      expect(pending, hasLength(1));
      expect(pending.single.done, _dinner);
      expect(pending.single.actedAt, pressed);
      expect(pending.single.key, 'item:dinner@2026-10-03');
    });

    test('a reminder without Done queues nothing', () async {
      final store = MemoryDoneQueueStore();
      await queueDoneInBackground(_reminder().encode(), store: store, now: _now);
      await queueDoneInBackground('not json', store: store, now: _now);
      await queueDoneInBackground(null, store: store, now: _now);
      expect(store.values, isEmpty);
    });

    test('keeps one entry per occurrence, oldest first, and drops unreadable ones', () async {
      final store = MemoryDoneQueueStore();
      final queue = DoneQueue(store);
      final walk = CareDone(
        petId: 'kelly',
        itemId: 'walk',
        kind: CareDoneKind.walk,
        dueOn: DateTime(2026, 10, 3),
        dueMinutes: 18 * 60 + 30,
      );
      await queue.add(DoneAction(done: _dinner, actedAt: DateTime(2026, 10, 3, 19, 45)));
      await queue.add(DoneAction(done: walk, actedAt: DateTime(2026, 10, 3, 18, 40)));
      // The same occurrence again replaces the first.
      await queue.add(DoneAction(done: _dinner, actedAt: DateTime(2026, 10, 3, 19, 50)));
      store.values['${DoneQueue.entryPrefix}broken'] = '{';
      final pending = await queue.pending();
      expect([for (final a in pending) a.done.itemId], ['walk', 'dinner']);
      expect(pending.last.actedAt, DateTime(2026, 10, 3, 19, 50));
      expect(store.values.keys, isNot(contains('${DoneQueue.entryPrefix}broken')));

      await queue.remove(pending.first);
      expect([for (final a in await queue.pending()) a.done.itemId], ['dinner']);
    });

    test('remembers recorded occurrences for 72 hours', () async {
      final queue = DoneQueue(MemoryDoneQueueStore());
      await queue.markHandled('dinner@2026-10-01T19:30', DateTime(2026, 10, 1, 20));
      await queue.markHandled('walk@2026-10-03T18:30', DateTime(2026, 10, 3, 19));
      expect((await queue.handled()).keys, ['dinner@2026-10-01T19:30', 'walk@2026-10-03T18:30']);
      await queue.markHandled('dinner@2026-10-04T19:30', DateTime(2026, 10, 4, 20, 1));
      expect((await queue.handled()).keys, ['walk@2026-10-03T18:30', 'dinner@2026-10-04T19:30']);
    });
  });
}

extension on CareDone {
  CareDone copyWithHour(int hour) => CareDone(
    petId: petId,
    itemId: itemId,
    kind: kind,
    dueOn: dueOn,
    dueMinutes: hour * 60,
    shiftDays: shiftDays,
  );
}
