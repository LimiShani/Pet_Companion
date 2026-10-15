import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/health_providers.dart';

import '../helpers.dart';
import 'notification_test_helpers.dart';

// "Done" on a reminder, through the whole app on its fakes: pressed while
// the app runs it records at once; pressed while the app was closed it
// waits in the queue and is recorded after sign-in with the time it was
// pressed. Never twice, never for an occurrence already answered, never
// for something gone or too old.

/// The sample data's day (Tuesday): breakfast and the morning dose are
/// answered, the evening walk (18:30), dinner (19:30) and the evening dose
/// (20:00) are open.
final _day = DateTime(2025, 6, 10);

/// The health backend, counting the answers stored.
class _Health extends FakeHealthRepository {
  _Health() : super(latency: Duration.zero, now: () => DateTime(2025, 6, 10, 12));

  final saved = <CareLog>[];

  @override
  Future<CareLog> saveLog(CareLog log) async {
    final stored = await super.saveLog(log);
    saved.add(stored);
    return stored;
  }
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// "Done" on today's reminder of [itemId], pressed at [at] (the real
/// clock: reminders ring in the real world, the demo's plan is moved).
DoneAction _press(String itemId, CareDoneKind kind, int hour, int minute, {required DateTime at, String petId = 'kelly'}) {
  final today = DateTime(at.year, at.month, at.day);
  return DoneAction(
    done: CareDone(
      petId: petId,
      itemId: itemId,
      kind: kind,
      dueOn: _day,
      dueMinutes: hour * 60 + minute,
      shiftDays: daysBetween(_day, today),
    ),
    actedAt: at,
    group: 'health:$petId',
    key: 'item:$itemId@${_dayKey(today)}',
  );
}

/// [at] moved into the sample data's day, as the log keeps it.
DateTime _inDemo(DateTime at) => DateTime(2025, 6, 10, at.hour, at.minute, at.second);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  }
}

Future<List<CareLog>> _logsOf(WidgetTester tester, _Health health, String itemId) async =>
    (await tester.runAsync(() => health.fetchLogs('kelly', from: _day)))!
        .where((l) => l.planItemId == itemId && isSameDay(l.dueOn, _day))
        .toList();

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Done while the app runs records the meal with the usual portion and takes the reminder off', (
    tester,
  ) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    final health = _Health();
    final queue = DoneQueue(MemoryDoneQueueStore());
    await pumpAppWithNotifications(tester, phone, health: health, doneQueue: queue);
    await signInAsDemo(tester);
    await _settle(tester);
    // Care reminders have Done; appointments and the basket do not.
    expect(phone.scheduled.values.where((n) => n.hasDone), isNotEmpty);
    for (final n in phone.scheduled.values) {
      expect(n.hasDone, n.key.startsWith('item:'), reason: n.key);
      if (n.hasDone) expect(n.doneLabel, 'Done');
    }

    final pressed = DateTime.now();
    final action = _press('p-dinner', CareDoneKind.meal, 19, 30, at: pressed);
    // A snoozed copy is waiting: it goes too.
    final snoozed = ScheduledNotification(
      group: action.group,
      key: action.key,
      kind: NotificationKind.meal,
      at: pressed.add(const Duration(minutes: 15)),
      title: 'PetLoop · Kelly',
      body: 'Dinner',
      snoozed: true,
    );
    phone.scheduled[snoozed.id] = snoozed;

    phone.pressDone(action);
    await _settle(tester);

    final logs = await _logsOf(tester, health, 'p-dinner');
    expect(logs, hasLength(1));
    final log = logs.single;
    expect(log.status, CareLogStatus.done);
    // Kelly's food: a 140 g portion, 360 cal per 100 g.
    expect(log.amountGrams, 140);
    expect(log.calories, 504);
    expect(log.doneAt, _inDemo(pressed));
    expect(log.loggedByName, 'Alex');
    expect(phone.scheduled.containsKey(snoozed.id), isFalse);
    expect(phone.of('health:kelly').where((n) => n.key == action.key), isEmpty);
    expect(await queue.pending(), isEmpty);
    expect((await queue.handled()).keys, [action.occurrenceKey]);

    // The same press delivered again (from the background isolate's queue)
    // records nothing more.
    final saves = health.saved.length;
    phone.pressDone(action);
    await _settle(tester);
    expect(health.saved.length, saves);
  });

  testWidgets('Done records the walk, the dose given at the press, and a routine', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    final health = _Health();
    // A daily routine (grooming does not ring today, but Done records any).
    final routine = (await tester.runAsync(
      () => health.savePlanItem(
        const CarePlanItem(
          id: '',
          petId: 'kelly',
          kind: CareKind.grooming,
          title: 'Brush teeth',
          time: TimeOfDay(hour: 21, minute: 0),
        ),
      ),
    ))!;
    await pumpAppWithNotifications(tester, phone, health: health);
    await signInAsDemo(tester);
    await _settle(tester);

    final pressed = DateTime.now();
    phone
      ..pressDone(_press('p-walk', CareDoneKind.walk, 18, 30, at: pressed))
      ..pressDone(_press('p-joint-pm', CareDoneKind.dose, 20, 0, at: pressed))
      ..pressDone(_press(routine.id, CareDoneKind.routine, 21, 0, at: pressed));
    await _settle(tester);

    final walk = (await _logsOf(tester, health, 'p-walk')).single;
    expect(walk.status, CareLogStatus.done);
    expect(walk.minutes, doneWalkMinutes);
    expect(walk.doneAt, _inDemo(pressed));

    final dose = (await _logsOf(tester, health, 'p-joint-pm')).single;
    expect(dose.status, CareLogStatus.done);
    expect(dose.medicationId, 'm-joint');
    expect(dose.doneAt, _inDemo(pressed));
    expect(dose.amountGrams, isNull);

    final brushed = (await _logsOf(tester, health, routine.id)).single;
    expect(brushed.status, CareLogStatus.done);
    expect(brushed.minutes, isNull);
  });

  testWidgets('Done after the meal was ticked in the app adds no second log', (tester) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    final health = _Health();
    await pumpAppWithNotifications(tester, phone, health: health);
    await signInAsDemo(tester);
    await _settle(tester);

    final container = _container(tester);
    final sub = container.listen(carePlanProvider('kelly'), (_, _) {});
    final plan = container.read(carePlanProvider('kelly')).requireValue;
    final dinner = plan.items.firstWhere((i) => i.id == 'p-dinner');
    final ticked = DateTime(2025, 6, 10, 19, 35);
    final saving = container
        .read(carePlanProvider('kelly').notifier)
        .record(item: dinner, dueOn: _day, status: CareLogStatus.done, doneAt: ticked);
    await _settle(tester);
    await saving;
    expect(health.saved, hasLength(1));

    phone.pressDone(_press('p-dinner', CareDoneKind.meal, 19, 30, at: DateTime.now()));
    await _settle(tester);
    expect(health.saved, hasLength(1));
    expect((await _logsOf(tester, health, 'p-dinner')).single.doneAt, ticked);
    sub.close();
  });

  testWidgets('Done pressed while the app was closed is recorded after sign-in, with the time it was pressed', (
    tester,
  ) async {
    final phone = FakeNotificationPlatform(currentAccess: const NotificationAccess(allowed: true, exact: true));
    final health = _Health();
    final store = MemoryDoneQueueStore();
    final now = DateTime.now();
    final pressed = now.subtract(const Duration(hours: 3));
    final press = _press('p-dinner', CareDoneKind.meal, 19, 30, at: pressed);
    // What the background isolate did with the button.
    final reminder = ScheduledNotification(
      group: press.group,
      key: press.key,
      kind: NotificationKind.meal,
      at: pressed,
      title: 'PetLoop · Kelly',
      body: 'Dinner',
      done: press.done,
      doneLabel: 'Done',
    );
    await tester.runAsync(() => queueDoneInBackground(reminder.encode(), store: store, now: pressed));
    // Older than 48 hours, for an item that is gone, for a pet that is gone.
    final queue = DoneQueue(store);
    await tester.runAsync(() async {
      await queue.add(_press('p-walk', CareDoneKind.walk, 18, 30, at: now.subtract(const Duration(hours: 49))));
      await queue.add(_press('p-gone', CareDoneKind.meal, 9, 0, at: now));
      await queue.add(_press('p-joint-pm', CareDoneKind.dose, 20, 0, at: now, petId: 'rex'));
    });
    expect(await tester.runAsync(queue.pending), hasLength(4));

    await pumpAppWithNotifications(tester, phone, health: health, doneQueue: queue);
    await _settle(tester);
    // Signed out: everything waits.
    expect(health.saved, isEmpty);
    expect(await tester.runAsync(queue.pending), hasLength(4));

    await signInAsDemo(tester);
    await _settle(tester);
    expect(health.saved, hasLength(1));
    final dinner = (await _logsOf(tester, health, 'p-dinner')).single;
    expect(dinner.doneAt, _inDemo(pressed));
    expect(dinner.amountGrams, 140);
    expect(await _logsOf(tester, health, 'p-walk'), isEmpty);
    expect(await tester.runAsync(queue.pending), isEmpty);

    // The app comes back: nothing is recorded again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(health.saved, hasLength(1));
  });
}
