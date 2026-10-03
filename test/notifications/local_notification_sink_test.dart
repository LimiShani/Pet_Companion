import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/notifications/notifications.dart';

import 'notification_test_helpers.dart';

// The sink: the owner's switches, quiet hours, the caps, and keeping the
// phone's notifications in step with the groups (through a fake phone).

/// Saturday 3 October 2026, noon.
final _now = DateTime(2026, 10, 3, 12);

PlannedNotification _n(String key, NotificationKind kind, DateTime at) =>
    PlannedNotification(key: key, kind: kind, at: at, title: 'PetLoop · Kelly', body: key, payload: 'feeding:kelly');

DateTime _at(int day, int hour, [int minute = 0]) => DateTime(2026, 10, day, hour, minute);

const _quiet = NotificationSettings(quietHours: true);

void main() {
  group('the owner\'s switches', () {
    final items = [
      _n('meal', NotificationKind.meal, _at(3, 19)),
      _n('walk', NotificationKind.walk, _at(3, 18)),
      _n('dose', NotificationKind.medicine, _at(3, 20)),
      _n('check', NotificationKind.appointment, _at(4, 18)),
      _n('food', NotificationKind.basket, _at(5, 10)),
    ];

    test('everything rings by default', () {
      expect(applySettings(items, NotificationSettings.defaults).map((n) => n.key), [
        'meal',
        'walk',
        'dose',
        'check',
        'food',
      ]);
    });

    test('a kind that is off does not ring', () {
      final settings = NotificationSettings.defaults.withKind(NotificationKind.walk, false).copyWith(basket: false);
      expect(applySettings(items, settings).map((n) => n.key), ['meal', 'dose', 'check']);
    });

    test('the master switch silences everything', () {
      expect(applySettings(items, const NotificationSettings(enabled: false)), isEmpty);
    });
  });

  group('quiet hours (22:00-07:00)', () {
    test('a meal, walk or basket reminder in quiet hours waits until 07:00', () {
      final moved = applySettings([
        _n('late walk', NotificationKind.walk, _at(3, 23, 15)),
        _n('early meal', NotificationKind.meal, _at(4, 6, 30)),
        _n('basket', NotificationKind.basket, _at(4, 2)),
      ], _quiet);
      expect(
        {for (final n in moved) n.key: n.at},
        {'late walk': _at(4, 7), 'early meal': _at(4, 7), 'basket': _at(4, 7)},
      );
    });

    test('medicines and appointments ring in quiet hours too', () {
      final items = [
        _n('dose', NotificationKind.medicine, _at(3, 23)),
        _n('check', NotificationKind.appointment, _at(4, 6)),
      ];
      expect(applySettings(items, _quiet).map((n) => n.at), [_at(3, 23), _at(4, 6)]);
    });

    test('a waiting reminder is dropped when one of its kind comes before 07:00', () {
      final kept = applySettings([
        // A late snack and an early breakfast: one reminder at 07:00.
        _n('snack', NotificationKind.meal, _at(3, 23)),
        _n('breakfast', NotificationKind.meal, _at(4, 6, 45)),
        // A late walk, with a walk at 07:00: only the 07:00 one.
        _n('night walk', NotificationKind.walk, _at(3, 22, 30)),
        _n('morning walk', NotificationKind.walk, _at(4, 7)),
      ], _quiet);
      expect({for (final n in kept) n.key: n.at}, {'breakfast': _at(4, 7), 'morning walk': _at(4, 7)});
    });

    test('times outside quiet hours do not move, and nothing moves with quiet hours off', () {
      final items = [_n('a', NotificationKind.meal, _at(3, 7)), _n('b', NotificationKind.meal, _at(3, 21, 59))];
      expect(applySettings(items, _quiet).map((n) => n.at), [_at(3, 7), _at(3, 21, 59)]);
      final night = [_n('c', NotificationKind.meal, _at(3, 23))];
      expect(applySettings(night, NotificationSettings.defaults).single.at, _at(3, 23));
    });

    test('22:00 is quiet, 07:00 is not', () {
      expect(NotificationSettings.isQuiet(_at(3, 22)), isTrue);
      expect(NotificationSettings.isQuiet(_at(3, 6, 59)), isTrue);
      expect(NotificationSettings.isQuiet(_at(3, 7)), isFalse);
      expect(NotificationSettings.quietEndAfter(_at(3, 22)), _at(4, 7));
      expect(NotificationSettings.quietEndAfter(_at(4, 3)), _at(4, 7));
    });
  });

  group('what goes to the phone', () {
    test('nothing in the past, soonest first, at most so many per group and in all', () {
      final groups = {
        'health:kelly': [
          _n('past', NotificationKind.meal, _at(3, 11)),
          for (var day = 3; day <= 9; day++) _n('dinner $day', NotificationKind.meal, _at(day, 19)),
        ],
        'health:soya': [for (var day = 3; day <= 9; day++) _n('walk $day', NotificationKind.walk, _at(day, 8))],
      };
      final all = notificationsToSchedule(groups: groups, settings: NotificationSettings.defaults, now: _now);
      expect(all, hasLength(13));
      expect(all.first.key, 'dinner 3');
      expect(all.where((n) => n.key == 'past'), isEmpty);

      final capped = notificationsToSchedule(
        groups: groups,
        settings: NotificationSettings.defaults,
        now: _now,
        perGroup: 3,
        total: 5,
      );
      expect(capped.map((n) => n.key), ['dinner 3', 'walk 4', 'dinner 4', 'walk 5', 'dinner 5']);
    });

    test('a quiet-hours reminder that was due tonight still rings at 07:00', () {
      final all = notificationsToSchedule(
        groups: {
          'g': [_n('early', NotificationKind.meal, DateTime(2026, 10, 3, 5))],
        },
        settings: _quiet,
        now: DateTime(2026, 10, 3, 6),
      );
      expect(all.single.at, _at(3, 7));
    });

    test('a payload carries the notification and comes back the same', () {
      final n = ScheduledNotification(
        group: 'health:kelly',
        key: 'item:dinner@2026-10-03',
        kind: NotificationKind.meal,
        at: _at(3, 19, 30),
        title: 'PetLoop · Kelly',
        body: 'Dinner · time to feed',
        target: 'feeding:kelly',
        exact: true,
        channelName: 'Meals',
        snoozeLabel: 'In 15 min',
      );
      final back = ScheduledNotification.decode(n.encode())!;
      expect(back.encode(), n.encode());
      expect(back.target, 'feeding:kelly');
      expect(back.at, n.at);
      expect(back.id, n.id);
      expect(ScheduledNotification.decode('feeding:kelly'), isNull);
      expect(ScheduledNotification.decode(null), isNull);
    });

    test('ids are stable per group and key, and a snoozed copy has its own', () {
      final id = notificationIdOf('health:kelly', 'item:dinner@2026-10-03');
      expect(notificationIdOf('health:kelly', 'item:dinner@2026-10-03'), id);
      expect(id, greaterThan(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
      expect(notificationIdOf('health:soya', 'item:dinner@2026-10-03'), isNot(id));
      expect(notificationIdOf('health:kelly', 'item:dinner@2026-10-03', snoozed: true), isNot(id));
    });
  });

  group('LocalNotificationSink on a phone', () {
    late FakeNotificationPlatform phone;
    late LocalNotificationSink sink;
    var reminded = 0;

    setUp(() {
      phone = FakeNotificationPlatform();
      reminded = 0;
      sink = LocalNotificationSink(
        phone,
        now: () => _now,
        chrome: const NotificationChrome(channelNames: {NotificationKind.meal: 'Meals'}, snoozeLabel: 'In 15 min'),
        onSomethingToRemind: () => reminded++,
      );
    });

    final week = [
      _n('breakfast 4', NotificationKind.meal, _at(4, 7, 30)),
      _n('dinner 3', NotificationKind.meal, _at(3, 19, 30)),
      _n('dose 3', NotificationKind.medicine, _at(3, 20)),
      _n('breakfast 3', NotificationKind.meal, _at(3, 7, 30)),
    ];

    test('schedules what lies ahead, with its channel and the snooze button', () async {
      await sink.syncGroup('health:kelly', week);
      expect(phone.of('health:kelly').map((n) => n.key), ['dinner 3', 'dose 3', 'breakfast 4']);
      final dinner = phone.of('health:kelly').first;
      expect(dinner.channelName, 'Meals');
      expect(dinner.snoozeLabel, 'In 15 min');
      expect(dinner.target, 'feeding:kelly');
      expect(dinner.exact, isFalse);
      expect(reminded, 1);
    });

    test('syncing the same plan again changes nothing; a removed item is cancelled', () async {
      await sink.syncGroup('health:kelly', week);
      phone.log.clear();
      await sink.syncGroup('health:kelly', week);
      expect(phone.log, isEmpty);

      // Dinner was logged: the plan comes again without it.
      await sink.syncGroup('health:kelly', [
        for (final n in week)
          if (n.key != 'dinner 3') n,
      ]);
      expect(phone.log, ['cancel dinner 3']);
      expect(phone.of('health:kelly').map((n) => n.key), ['dose 3', 'breakfast 4']);
    });

    test('an empty list cancels the group, and leaves the others', () async {
      await sink.syncGroup('health:kelly', week);
      await sink.syncGroup('basket:kelly', [_n('food', NotificationKind.basket, _at(8, 10))]);
      await sink.syncGroup('health:kelly', const []);
      expect(phone.scheduled.values.map((n) => n.key), ['food']);
      expect(reminded, 2);
    });

    test('a change of the switches applies at once, without the callers', () async {
      await sink.syncGroup('health:kelly', week);
      sink.settings = NotificationSettings.defaults.withKind(NotificationKind.meal, false);
      await pumpEventQueue();
      expect(phone.of('health:kelly').map((n) => n.key), ['dose 3']);

      sink.settings = NotificationSettings.defaults.copyWith(quietHours: true);
      await pumpEventQueue();
      expect(phone.of('health:kelly').map((n) => n.key), ['dinner 3', 'dose 3', 'breakfast 4']);

      sink.settings = const NotificationSettings(enabled: false);
      await pumpEventQueue();
      expect(phone.scheduled, isEmpty);
    });

    test('with "Alarms & reminders" allowed, everything is scheduled again as exact', () async {
      await sink.syncGroup('health:kelly', week);
      sink.exact = true;
      await pumpEventQueue();
      expect(phone.of('health:kelly').every((n) => n.exact), isTrue);
    });

    test('a snoozed reminder stays while its occurrence is open, and goes once it is answered', () async {
      await sink.syncGroup('health:kelly', week);
      final dose = phone.of('health:kelly').firstWhere((n) => n.key == 'dose 3');
      final snoozed = dose.copyWith(at: _at(3, 20, 15), snoozed: true);
      phone.scheduled[snoozed.id] = snoozed;

      await sink.syncGroup('health:kelly', week);
      expect(phone.scheduled[snoozed.id], isNotNull);

      await sink.syncGroup('health:kelly', [
        for (final n in week)
          if (n.key != 'dose 3') n,
      ]);
      expect(phone.scheduled[snoozed.id], isNull);
    });

    test('groups nobody synced since the start are left alone; foreign payloads go', () async {
      final earlier = ScheduledNotification(
        group: 'basket:kelly',
        key: 'food',
        kind: NotificationKind.basket,
        at: _at(8, 10),
        title: 'PetLoop · Kelly',
        body: 'Basket',
      );
      phone.scheduled[earlier.id] = earlier;
      phone.foreign.add(42);
      await sink.syncGroup('health:kelly', week);
      expect(phone.scheduled[earlier.id], isNotNull);
      expect(phone.foreign, isEmpty);
    });

    test('retainGroups cancels the groups of pets that are gone, also from an earlier run', () async {
      final gone = ScheduledNotification(
        group: 'health:old',
        key: 'x',
        kind: NotificationKind.meal,
        at: _at(4, 8),
        title: 't',
        body: 'b',
      );
      phone.scheduled[gone.id] = gone;
      await sink.syncGroup('health:kelly', week);
      await sink.syncGroup('health:soya', [_n('walk', NotificationKind.walk, _at(4, 8))]);
      await sink.retainGroups('health:', {'health:kelly'});
      expect(phone.scheduled.values.map((n) => n.group).toSet(), {'health:kelly'});
    });

    test('cancelAll empties the phone and forgets the groups', () async {
      await sink.syncGroup('health:kelly', week);
      await sink.cancelAll();
      expect(phone.scheduled, isEmpty);
      expect(sink.groups, isEmpty);
    });

    test('at most maxPending wait on the phone', () async {
      final small = FakeNotificationPlatform(maxPending: 2);
      final capped = LocalNotificationSink(small, now: () => _now);
      await capped.syncGroup('health:kelly', week);
      expect(small.of('health:kelly').map((n) => n.key), ['dinner 3', 'dose 3']);
    });
  });
}
