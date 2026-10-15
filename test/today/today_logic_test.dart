import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/care/data/care_models.dart';
import 'package:pet_companion/services/household/data/household_models.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/schedule_logic.dart';
import 'package:pet_companion/services/today/today_logic.dart';

final _day = DateTime(2025, 6, 10);
DateTime _at(int hour, [int minute = 0]) => DateTime(2025, 6, 10, hour, minute);

const _kelly = Pet(id: 'kelly', name: 'Kelly', species: PetSpecies.dog);
const _soya = Pet(id: 'soya', name: 'Soya', species: PetSpecies.dog);

CarePlanItem _item(
  String id,
  CareKind kind,
  int hour, {
  String pet = 'kelly',
  String? title,
  String? medicationId,
}) => CarePlanItem(
  id: id,
  petId: pet,
  kind: kind,
  title: title ?? id,
  time: TimeOfDay(hour: hour, minute: 0),
  medicationId: medicationId,
);

CareLog _log(
  CarePlanItem item, {
  required DateTime at,
  String? by,
  String name = '',
  CareLogStatus status = CareLogStatus.done,
}) => CareLog(
  id: 'log-${item.id}',
  petId: item.petId,
  planItemId: item.id,
  title: item.title,
  dueOn: _day,
  dueTime: item.time,
  status: status,
  doneAt: status == CareLogStatus.done ? at : null,
  loggedAt: at,
  loggedBy: by,
  loggedByName: name,
);

TodayItem _row(
  String id, {
  DateTime? time,
  bool done = false,
  String pet = 'kelly',
  TodayKind kind = TodayKind.meal,
}) {
  final item = _item(id, CareKind.feeding, time?.hour ?? 8, pet: pet);
  return TodayItem(
    id: id,
    kind: kind,
    petId: pet,
    title: id,
    time: time,
    entry: time == null
        ? null
        : ScheduleEntry(
            item: item,
            due: time,
            log: done ? _log(item, at: time) : null,
          ),
  );
}

List<String> _ids(List<TodayItem> items) => [for (final i in items) i.id];

void main() {
  group('orderToday', () {
    test('what is to do comes first by time (overdue first), then the undated rows, then what is done', () {
      final ordered = orderToday([
        _row('done-early', time: _at(7), done: true),
        _row('runs-out', kind: TodayKind.runsOut),
        _row('evening', time: _at(19)),
        _row('overdue', time: _at(8)),
        _row('essentials', kind: TodayKind.essentials),
        _row('first-days', kind: TodayKind.firstDays),
        _row('done-late', time: _at(12), done: true),
        _row('noon', time: _at(12)),
      ]);
      expect(_ids(ordered), [
        'overdue',
        'noon',
        'evening',
        'runs-out',
        'first-days',
        'essentials',
        'done-early',
        'done-late',
      ]);
    });

    test('rows at the same time go by the pets\' order, then by title', () {
      final ordered = orderToday([
        _row('b', time: _at(8), pet: 'soya'),
        _row('c', time: _at(8)),
        _row('a', time: _at(8), pet: 'soya'),
      ], petOrder: ['kelly', 'soya']);
      expect(_ids(ordered), ['c', 'a', 'b']);
    });

    test('a row is overdue once its time has passed and nobody answered it', () {
      final open = _row('open', time: _at(8));
      final done = _row('done', time: _at(8), done: true);
      expect(open.isOverdue(_at(9)), isTrue);
      expect(open.isOverdue(_at(7)), isFalse);
      expect(done.isOverdue(_at(9)), isFalse);
    });
  });

  group('todayItems', () {
    final breakfast = _item('breakfast', CareKind.feeding, 7, title: 'Breakfast');
    final walk = _item('walk', CareKind.walk, 18, title: 'Evening walk');
    final brush = _item('brush', CareKind.grooming, 10, title: 'Brush coat');
    final dose = _item(
      'dose',
      CareKind.medication,
      20,
      title: 'Joint tablets',
      medicationId: 'm',
    );
    final soyaDinner = _item('dinner', CareKind.feeding, 19, pet: 'soya', title: 'Dinner');
    final medication = Medication(
      id: 'm',
      petId: 'kelly',
      name: 'Joint tablets',
      startsOn: DateTime(2025, 5, 1),
    );

    test('every pet\'s meals, walks, routines and doses, with the usual portion on a meal', () {
      final items = todayItems(
        pets: [_kelly, _soya],
        now: _at(9),
        plans: {
          'kelly': CarePlan(
            medications: [medication],
            items: [breakfast, walk, brush, dose],
            logs: [_log(breakfast, at: _at(7, 40))],
          ),
          'soya': CarePlan(items: [soyaDinner]),
        },
        settings: {
          'kelly': const CareSettings(petId: 'kelly', kcalPer100g: 360, portionGrams: 140),
        },
      );
      expect(_ids(items), [
        'kelly:brush',
        'kelly:walk',
        'soya:dinner',
        'kelly:dose',
        'kelly:breakfast',
      ]);
      final kinds = {for (final i in items) i.id: i.kind};
      expect(kinds['kelly:brush'], TodayKind.routine);
      expect(kinds['kelly:walk'], TodayKind.walk);
      expect(kinds['kelly:dose'], TodayKind.dose);
      expect(kinds['kelly:breakfast'], TodayKind.meal);
      final done = items.last;
      expect(done.isDone, isTrue);
      expect(done.portionGrams, 140);
      expect(done.portionCalories, 504);
      expect(todayProgress(items), (done: 1, total: 5));
    });

    test('a pet without its plan yet adds nothing', () {
      final items = todayItems(
        pets: [_kelly, _soya],
        now: _at(9),
        plans: {'kelly': CarePlan(items: [breakfast])},
      );
      expect(_ids(items), ['kelly:breakfast']);
    });
  });

  group('who did it', () {
    final breakfast = _item('breakfast', CareKind.feeding, 7);
    final maya = HouseholdMember(
      userId: 'maya',
      name: 'Maya',
      role: HouseholdRole.carer,
      joinedAt: DateTime(2025, 1, 1),
    );

    test('the signed-in account, or a log that names no account, is "you"', () {
      expect(todayWhoDid(_log(breakfast, at: _at(7), by: 'me'), 'me', [maya]), (null, true));
      expect(todayWhoDid(_log(breakfast, at: _at(7), name: 'Alex'), 'me', [maya]), (null, true));
    });

    test('another member is named as the household knows them, else as stored', () {
      expect(todayWhoDid(_log(breakfast, at: _at(7), by: 'maya', name: 'M.'), 'me', [maya]), ('Maya', false));
      expect(todayWhoDid(_log(breakfast, at: _at(7), by: 'noa', name: 'Noa'), 'me', [maya]), ('Noa', false));
    });
  });

  group('undo and fold', () {
    test('a done row can be taken back within the hour, and only by whoever logged it', () {
      final row = _row('meal', time: _at(8), done: true);
      expect(row.canUndo(_at(8, 30)), isTrue);
      expect(row.canUndo(_at(9, 1)), isFalse);
      final theirs = TodayItem(
        id: row.id,
        kind: row.kind,
        petId: row.petId,
        time: row.time,
        entry: row.entry,
        doneBy: 'Maya',
        doneByMe: false,
      );
      expect(theirs.canUndo(_at(8, 30)), isFalse);
      expect(_row('open', time: _at(8)).canUndo(_at(8, 30)), isFalse);
    });

    test('more than five done rows fold into one', () {
      expect(todayFoldsDone(5), isFalse);
      expect(todayFoldsDone(6), isTrue);
    });
  });
}
