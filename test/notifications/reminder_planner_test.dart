import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/reminder_scheduler.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';

// planReminders: a pet's care plan and planned records as the phone's
// notifications, with a fixed "now".

final _en = lookupNotificationsL10n(englishLocale);
final _he = lookupNotificationsL10n(hebrewLocale);

/// Saturday 3 October 2026, noon.
final _now = DateTime(2026, 10, 3, 12);

const _pet = 'kelly';

CarePlanItem _item(String id, CareKind kind, String title, int hour, int minute, {String? medicationId}) =>
    CarePlanItem(
      id: id,
      petId: _pet,
      kind: kind,
      title: title,
      time: TimeOfDay(hour: hour, minute: minute),
      medicationId: medicationId,
    );

final _items = [
  _item('breakfast', CareKind.feeding, 'Breakfast', 7, 30),
  _item('walk', CareKind.walk, 'Evening walk', 18, 30),
  _item('dinner', CareKind.feeding, 'Dinner', 19, 30),
  _item('joint-am', CareKind.medication, 'Joint tablets', 8, 0, medicationId: 'joint'),
  _item('joint-pm', CareKind.medication, 'Joint tablets', 20, 0, medicationId: 'joint'),
  _item('brush', CareKind.grooming, 'Brush coat', 10, 0),
];

const _joint = Medication(id: 'joint', petId: _pet, name: 'Joint tablets', strength: '50 mg', dose: '1 tablet');

CareLog _answer(String itemId, DateTime day, {CareLogStatus status = CareLogStatus.done}) => CareLog(
  id: 'log-$itemId',
  petId: _pet,
  planItemId: itemId,
  title: itemId,
  dueOn: day,
  status: status,
  loggedAt: day,
);

final _check = HealthRecord(
  id: 'check',
  petId: _pet,
  kind: RecordKind.checkup,
  title: 'General check',
  scheduledAt: DateTime(2026, 10, 5, 18, 20),
  clinic: 'Park Vet Clinic',
);

ReminderPlan _plan({
  List<CarePlanItem>? items,
  List<CareLog> logs = const [],
  List<HealthRecord> upcoming = const [],
  List<Medication> medications = const [_joint],
  DateTime? today,
  String petName = 'Kelly',
}) => ReminderPlan(
  petId: _pet,
  petName: petName,
  items: items ?? _items,
  medications: medications,
  logs: logs,
  upcoming: upcoming,
  today: today,
);

PlannedNotification? _find(List<PlannedNotification> list, String key) => list.where((n) => n.key == key).firstOrNull;

void main() {
  group('routines and medicine times', () {
    test('a week of meals, walks and medicine times rings, grooming does not', () {
      final list = planReminders(_plan(), now: _now, l10n: _en);

      // 7 days x (2 meals + 1 walk + 2 doses).
      expect(list, hasLength(35));
      expect(list.where((n) => n.key.startsWith('item:brush')), isEmpty);
      expect(list.where((n) => n.kind == NotificationKind.meal), hasLength(14));
      expect(list.where((n) => n.kind == NotificationKind.walk), hasLength(7));
      expect(list.where((n) => n.kind == NotificationKind.medicine), hasLength(14));
      // Soonest first, from today to the sixth day after it.
      expect(list.first.at, DateTime(2026, 10, 3, 7, 30));
      expect(list.last.at, DateTime(2026, 10, 9, 20, 0));
      for (var i = 1; i < list.length; i++) {
        expect(list[i].at.isBefore(list[i - 1].at), isFalse);
      }
    });

    test('the texts name the pet, the meal, the walk and the dose', () {
      final list = planReminders(_plan(), now: _now, l10n: _en);

      final dinner = _find(list, 'item:dinner@2026-10-03')!;
      expect(dinner.title, 'PetLoop · Kelly');
      expect(dinner.body, 'Dinner · time to feed');
      expect(dinner.at, DateTime(2026, 10, 3, 19, 30));
      expect(dinner.kind, NotificationKind.meal);
      expect(dinner.payload, 'feeding:kelly');

      final walk = _find(list, 'item:walk@2026-10-03')!;
      expect(walk.body, 'Evening walk');
      expect(walk.payload, 'activity:kelly');

      final dose = _find(list, 'item:joint-pm@2026-10-03')!;
      expect(dose.body, 'Joint tablets · 1 tablet');
      expect(dose.kind, NotificationKind.medicine);
      expect(dose.payload, 'health:kelly');
    });

    test('a medicine without a dose and a routine without a name still read well', () {
      final list = planReminders(
        _plan(
          items: [
            _item('pill', CareKind.medication, 'Ear drops', 9, 0, medicationId: 'drops'),
            _item('w', CareKind.walk, ' ', 9, 0),
          ],
          medications: const [Medication(id: 'drops', petId: _pet, name: 'Ear drops')],
        ),
        now: _now,
        l10n: _en,
      );
      expect(_find(list, 'item:pill@2026-10-04')!.body, 'Ear drops · time for a dose');
      expect(_find(list, 'item:w@2026-10-04')!.body, 'Time for a walk');
    });

    test('an answered occurrence does not ring, the next day it does', () {
      final today = DateTime(2026, 10, 3);
      final list = planReminders(
        _plan(
          logs: [
            // Dinner logged early (at 19:10) answers the 19:30 reminder.
            _answer('dinner', today),
            // "Not given" and "Not sure" are answers too.
            _answer('joint-pm', today, status: CareLogStatus.skipped),
            _answer('walk', today, status: CareLogStatus.unknown),
          ],
        ),
        now: _now,
        l10n: _en,
      );
      expect(_find(list, 'item:dinner@2026-10-03'), isNull);
      expect(_find(list, 'item:joint-pm@2026-10-03'), isNull);
      expect(_find(list, 'item:walk@2026-10-03'), isNull);
      expect(_find(list, 'item:dinner@2026-10-04'), isNotNull);
      expect(_find(list, 'item:breakfast@2026-10-03'), isNotNull);
    });

    test('paused items, other weekdays and finished medicines do not ring', () {
      final list = planReminders(
        _plan(
          items: [
            _item('breakfast', CareKind.feeding, 'Breakfast', 7, 30).copyWith(active: false),
            // Mondays only: 5 October is the only Monday of the week.
            _item('vet-walk', CareKind.walk, 'Long walk', 9, 0).copyWith(days: {DateTime.monday}),
            _item('joint-am', CareKind.medication, 'Joint tablets', 8, 0, medicationId: 'joint'),
          ],
          medications: [Medication(id: 'joint', petId: _pet, name: 'Joint tablets', endsOn: DateTime(2026, 10, 4))],
        ),
        now: _now,
        l10n: _en,
      );
      expect(list.map((n) => n.key), [
        'item:joint-am@2026-10-03',
        'item:joint-am@2026-10-04',
        'item:vet-walk@2026-10-05',
      ]);
    });

    test('in Hebrew, with the names kept apart from the sentence', () {
      final list = planReminders(_plan(), now: _now, l10n: _he);
      final dinner = _find(list, 'item:dinner@2026-10-03')!;
      expect(dinner.title, 'PetLoop · \u2068Kelly\u2069');
      expect(dinner.body, '\u2068Dinner\u2069 · זמן להאכיל');
      expect(_find(list, 'item:joint-am@2026-10-04')!.body, '\u2068Joint tablets\u2069 · \u20681 tablet\u2069');
    });

    test('a pet without a name gets the app name as the title', () {
      final list = planReminders(
        _plan(petName: ' '),
        now: _now,
        l10n: _en,
      );
      expect(list.first.title, 'PetLoop');
    });

    test('the keys are stable: the same plan gives the same notifications', () {
      final a = planReminders(_plan(), now: _now, l10n: _en);
      final b = planReminders(_plan(), now: _now.add(const Duration(minutes: 5)), l10n: _en);
      expect(a.map((n) => n.key), b.map((n) => n.key));
    });
  });

  group('appointments and due dates', () {
    test('ring the evening before at 18:00 and 2 hours before', () {
      final list = planReminders(
        _plan(items: const [], upcoming: [_check]),
        now: _now,
        l10n: _en,
      );

      expect(list, hasLength(2));
      final evening = _find(list, 'record:check@eve')!;
      expect(evening.at, DateTime(2026, 10, 4, 18));
      expect(evening.body, 'Tomorrow 18:20: General check · Park Vet Clinic');
      expect(evening.kind, NotificationKind.appointment);
      expect(evening.payload, 'health:kelly');
      final before = _find(list, 'record:check@2h')!;
      expect(before.at, DateTime(2026, 10, 5, 16, 20));
      expect(before.body, 'Today 18:20: General check · Park Vet Clinic');
    });

    test('a due date without a clinic, just after midnight', () {
      final due = HealthRecord(
        id: 'rabies',
        petId: _pet,
        kind: RecordKind.vaccination,
        title: 'Rabies booster',
        scheduledAt: DateTime(2026, 10, 6, 1, 0),
      );
      final list = planReminders(
        _plan(items: const [], upcoming: [due]),
        now: _now,
        l10n: _en,
      );
      // Both the evening before and 2 hours before are on 5 October.
      expect(_find(list, 'record:rabies@eve')!.body, 'Tomorrow 01:00: Rabies booster');
      expect(_find(list, 'record:rabies@2h')!.at, DateTime(2026, 10, 5, 23));
      expect(_find(list, 'record:rabies@2h')!.body, 'Tomorrow 01:00: Rabies booster');
    });

    test('in Hebrew', () {
      final list = planReminders(
        _plan(items: const [], upcoming: [_check]),
        now: _now,
        l10n: _he,
      );
      expect(_find(list, 'record:check@eve')!.body, '\u2068מחר \u206818:20\u2069: \u2068General check\u2069\u2069 · \u2068Park Vet Clinic\u2069');
    });
  });

  group('the sample data (demo) lives in June 2025', () {
    test('its "today" rings today, with its answers and appointments moved along', () {
      final sampleDay = DateTime(2025, 6, 10);
      final list = planReminders(
        _plan(
          today: DateTime(2025, 6, 10, 12),
          logs: [_answer('dinner', sampleDay)],
          upcoming: [_check.copyWith(scheduledAt: DateTime(2025, 6, 12, 18, 20))],
        ),
        now: _now,
        l10n: _en,
      );
      // Dinner was logged on the sample day, which is "today".
      expect(_find(list, 'item:dinner@2026-10-03'), isNull);
      expect(_find(list, 'item:dinner@2026-10-04'), isNotNull);
      // The check two days after the sample day rings two days from now.
      expect(_find(list, 'record:check@eve')!.at, DateTime(2026, 10, 4, 18));
      expect(_find(list, 'record:check@2h')!.at, DateTime(2026, 10, 5, 16, 20));
    });
  });
}
