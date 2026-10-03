import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/care/data/care_models.dart';
import 'package:pet_companion/features/firstdays/firstdays.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/health/state/schedule_logic.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

const _dog = Pet(id: 'rex', name: 'Rex');
const _cat = Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat);
const _rabbit = Pet(id: 'bun', name: 'Bun', species: PetSpecies.rabbit);

final _arrived = DateTime(2025, 6, 1);

/// 10 June 2025 in the afternoon: day 10 of a path that started on 1 June.
final _now = DateTime(2025, 6, 10, 15);

FirstDaysPath _path({String petId = 'rex', Set<String> done = const {}, DateTime? closedAt}) =>
    FirstDaysPath(petId: petId, arrivedOn: _arrived, doneTasks: done, closedAt: closedAt);

HealthRecord _record(RecordKind kind, DateTime when, {bool done = true}) => HealthRecord(
  id: 'r-${kind.name}-${when.day}',
  petId: 'rex',
  kind: kind,
  title: 'Visit',
  scheduledAt: when,
  doneAt: done ? when : null,
);

CarePlanItem _routine(CareKind kind, {bool active = true}) => CarePlanItem(
  id: 'i-${kind.name}',
  petId: 'rex',
  kind: kind,
  title: kind.label,
  time: const TimeOfDay(hour: 8, minute: 0),
  active: active,
);

Set<String> _autoDone(Pet pet, FirstDaysFacts facts) => {
  for (final item in firstDaysView(
    pet: pet,
    path: _path(petId: pet.id),
    now: _now,
    facts: facts,
  ).items)
    if (item.autoDone) item.task.id,
};

void main() {
  group('the day of the path', () {
    test('the arrival day is day 1, and 1 June to 10 June is day 10', () {
      expect(firstDaysDayNumber(_arrived, DateTime(2025, 6, 1, 23, 59)), 1);
      expect(firstDaysDayNumber(_arrived, DateTime(2025, 6, 2, 0, 1)), 2);
      expect(firstDaysDayNumber(_arrived, _now), 10);
      expect(firstDaysDayNumber(_arrived, DateTime(2025, 6, 30, 22)), 30);
      expect(firstDaysDayNumber(_arrived, DateTime(2025, 7, 1, 8)), 31);
    });

    test('counts calendar days across a change of clocks', () {
      // Summer time starts in late March in Israel and in Europe.
      expect(firstDaysDayNumber(DateTime(2025, 3, 20), DateTime(2025, 4, 5, 0, 30)), 17);
      expect(firstDaysDayNumber(DateTime(2025, 10, 20), DateTime(2025, 11, 2, 23, 30)), 14);
    });

    test('the earliest arrival keeps today among the 30 days', () {
      final earliest = earliestArrival(_now);
      expect(earliest, DateTime(2025, 5, 12));
      expect(firstDaysDayNumber(earliest, _now), firstDaysLength);
    });

    test('the arrival keeps only the date', () {
      expect(FirstDaysPath(petId: 'rex', arrivedOn: DateTime(2025, 6, 1, 18, 45)).arrivedOn, _arrived);
    });
  });

  group('the tasks of each kind of animal', () {
    test('dogs have 12, cats 11, every other animal the same shorter list of 7', () {
      expect(firstDaysTasksFor(PetSpecies.dog), hasLength(12));
      expect(firstDaysTasksFor(PetSpecies.cat), hasLength(11));
      for (final species in [PetSpecies.bird, PetSpecies.rabbit, PetSpecies.reptile, PetSpecies.other]) {
        expect(firstDaysTasksFor(species).map((t) => t.id), [
          'other-home',
          'other-quiet',
          'food',
          'meal-times',
          'first-vet',
          'cleaning',
          'guides',
        ]);
      }
    });

    test('each list starts with the first week, and has no id twice', () {
      for (final species in PetSpecies.values) {
        final tasks = firstDaysTasksFor(species);
        expect(tasks.map((t) => t.id).toSet(), hasLength(tasks.length), reason: species.name);
        final weeks = tasks.map((t) => t.week).toList();
        expect(weeks, [...weeks]..sort((a, b) => a.index.compareTo(b.index)), reason: species.name);
        expect(weeks.first, FirstDaysWeek.first);
        expect(weeks.last, FirstDaysWeek.later);
      }
    });

    test('dogs walk and wear a name tag, cats get a scratching post, both read their first-week guide', () {
      final dog = firstDaysTasksFor(PetSpecies.dog).map((t) => t.id);
      final cat = firstDaysTasksFor(PetSpecies.cat).map((t) => t.id);
      expect(dog, containsAll(['walk-times', 'dog-first-walks', 'dog-name-tag', 'dog-guide']));
      expect(cat, containsAll(['cat-safe-room', 'cat-scratching', 'cat-guide']));
      expect(cat, isNot(contains('walk-times')));
      final dogGuide = firstDaysTasksFor(PetSpecies.dog).firstWhere((t) => t.id == 'dog-guide');
      final catGuide = firstDaysTasksFor(PetSpecies.cat).firstWhere((t) => t.id == 'cat-guide');
      expect(dogGuide.action!.guideId, 'first-week');
      expect(catGuide.action!.guideId, 'cat-first-week');
    });

    test('every task and every pill has words in English and in Hebrew', () {
      for (final l10n in [lookupFirstDaysL10n(englishLocale), lookupFirstDaysL10n(hebrewLocale)]) {
        for (final id in allFirstDaysTaskIds) {
          expect(firstDaysTaskText(l10n, id), isNotEmpty, reason: id);
        }
        for (final kind in FirstDaysActionKind.values) {
          expect(firstDaysActionLabel(l10n, kind), isNotEmpty, reason: kind.name);
        }
      }
    });
  });

  group('tasks the app ticks by itself', () {
    test('nothing is ticked without data', () {
      expect(_autoDone(_dog, const FirstDaysFacts()), isEmpty);
    });

    test('a vet visit counts from the arrival day on, done or booked; other kinds do not', () {
      expect(
        _autoDone(_dog, FirstDaysFacts(records: [_record(RecordKind.checkup, DateTime(2025, 5, 31, 18))])),
        isEmpty,
      );
      expect(
        _autoDone(_dog, FirstDaysFacts(records: [_record(RecordKind.vaccination, DateTime(2025, 6, 3))])),
        isEmpty,
      );
      expect(_autoDone(_dog, FirstDaysFacts(records: [_record(RecordKind.checkup, DateTime(2025, 6, 1, 9))])), {
        'first-vet',
      });
      expect(
        _autoDone(_dog, FirstDaysFacts(records: [_record(RecordKind.checkup, DateTime(2025, 6, 12), done: false)])),
        {'first-vet'},
      );
    });

    test('the microchip counts as a number or as "not chipped"', () {
      expect(_autoDone(_dog, const FirstDaysFacts(profile: HealthProfile(petId: 'rex'))), isEmpty);
      expect(
        _autoDone(
          _dog,
          const FirstDaysFacts(
            profile: HealthProfile(petId: 'rex', microchip: '9851'),
          ),
        ),
        {'microchip'},
      );
      expect(_autoDone(_dog, const FirstDaysFacts(profile: HealthProfile(petId: 'rex', notChipped: true))), {
        'microchip',
      });
    });

    test('meal and walk times count while their routine is active; the food once its calories are known', () {
      final plan = CarePlan(items: [_routine(CareKind.feeding), _routine(CareKind.walk, active: false)]);
      expect(_autoDone(_dog, FirstDaysFacts(plan: plan)), {'meal-times'});
      expect(_autoDone(_dog, FirstDaysFacts(plan: CarePlan(items: [_routine(CareKind.walk)]))), {'walk-times'});
      expect(
        _autoDone(
          _dog,
          const FirstDaysFacts(
            settings: CareSettings(petId: 'rex', foodName: 'Kibble'),
          ),
        ),
        isEmpty,
      );
      expect(_autoDone(_dog, const FirstDaysFacts(settings: CareSettings(petId: 'rex', kcalPer100g: 360))), {'food'});
    });

    test('a cat has no walk times; a rabbit ticks its cleaning routine', () {
      final plan = CarePlan(items: [_routine(CareKind.walk), _routine(CareKind.cageCleaning)]);
      expect(_autoDone(_cat, FirstDaysFacts(plan: plan)), isEmpty);
      expect(_autoDone(_rabbit, FirstDaysFacts(plan: plan)), {'cleaning'});
    });

    test('a task ticked by hand and by the app counts once', () {
      final view = firstDaysView(
        pet: _dog,
        path: _path(done: {'food'}),
        now: _now,
        facts: const FirstDaysFacts(settings: CareSettings(petId: 'rex', kcalPer100g: 360)),
      );
      final food = view.items.firstWhere((i) => i.task.id == 'food');
      expect(food.isDone, isTrue);
      expect(food.onlyAuto, isFalse);
      expect(view.doneCount, 1);
    });
  });

  group('progress, next task and the end of the path', () {
    test('day 10, 2 of 12 done, and the next task is the first one left in the order of the page', () {
      final view = firstDaysView(
        pet: _dog,
        path: _path(done: {'dog-rest-spot', 'dog-name-tag'}),
        now: _now,
      );
      expect(view.day, 10);
      expect(view.doneCount, 2);
      expect(view.total, 12);
      expect(view.progress, closeTo(2 / 12, 1e-9));
      expect(view.next!.task.id, 'dog-basics');
      expect(view.stage, FirstDaysStage.running);
      expect(view.isRunning, isTrue);
      expect(view.hasEnded, isFalse);

      final later = firstDaysView(
        pet: _dog,
        path: _path(done: {'dog-basics', 'dog-rest-spot'}),
        now: _now,
      );
      expect(later.next!.task.id, 'food');
    });

    test('everything done before day 30 is finished: no card, but the page still takes changes', () {
      final all = {for (final t in firstDaysTasksFor(PetSpecies.cat)) t.id};
      final view = firstDaysView(
        pet: _cat,
        path: _path(petId: 'mitzi', done: all),
        now: _now,
      );
      expect(view.stage, FirstDaysStage.finished);
      expect(view.next, isNull);
      expect(view.isRunning, isFalse);
      expect(view.hasEnded, isFalse);
    });

    test('after day 30 the path is over', () {
      final view = firstDaysView(pet: _dog, path: _path(), now: DateTime(2025, 7, 1, 9));
      expect(view.stage, FirstDaysStage.over);
      expect(view.isRunning, isFalse);
      expect(view.hasEnded, isTrue);
      expect(view.shownDay, 30);
    });

    test('a closed path has ended, whatever the day', () {
      final view = firstDaysView(
        pet: _dog,
        path: _path(closedAt: DateTime(2025, 6, 8, 20)),
        now: _now,
      );
      expect(view.stage, FirstDaysStage.closed);
      expect(view.isRunning, isFalse);
      expect(view.hasEnded, isTrue);
    });
  });

  group('the path controller', () {
    late FakeFirstDaysRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeFirstDaysRepository(latency: Duration.zero);
      container = ProviderContainer(
        overrides: [
          firstDaysRepositoryProvider.overrideWithValue(repo),
          healthClockProvider.overrideWithValue(() => _now),
        ],
      );
      addTearDown(container.dispose);
    });

    Future<FirstDaysController> controllerOf(String petId) async {
      container.listen(firstDaysProvider(petId), (_, _) {});
      await container.read(firstDaysProvider(petId).future);
      return container.read(firstDaysProvider(petId).notifier);
    }

    test('the sample data has Soya arrived on 1 June with two ticks', () async {
      await controllerOf('soya');
      final path = container.read(firstDaysProvider('soya')).value!;
      expect(path.arrivedOn, _arrived);
      expect(path.doneTasks, {'dog-rest-spot', 'dog-name-tag'});
      expect(container.read(firstDaysProvider('kelly')).value, isNull);
    });

    test('start, tick, untick and close are stored', () async {
      final paths = await controllerOf('rex');
      expect(container.read(firstDaysProvider('rex')).value, isNull);

      await paths.start(DateTime(2025, 6, 8, 12));
      expect((await repo.fetch('rex'))!.arrivedOn, DateTime(2025, 6, 8));

      await paths.setDone('dog-basics', done: true);
      await paths.setDone('food', done: true);
      await paths.setDone('dog-basics', done: false);
      expect((await repo.fetch('rex'))!.doneTasks, {'food'});

      await paths.close();
      final closed = (await repo.fetch('rex'))!;
      expect(closed.closedAt, _now);
      expect(closed.doneTasks, {'food'});

      // Started again on another day: open again, ticks kept.
      await paths.start(DateTime(2025, 6, 9));
      final again = (await repo.fetch('rex'))!;
      expect(again.isClosed, isFalse);
      expect(again.arrivedOn, DateTime(2025, 6, 9));
      expect(again.doneTasks, {'food'});

      await paths.forget();
      expect(await repo.fetch('rex'), isNull);
      expect(container.read(firstDaysProvider('rex')).value, isNull);
    });

    test('a tick that cannot be stored goes back, and the failure is passed on', () async {
      final paths = await controllerOf('soya');
      repo.failing = true;
      await expectLater(paths.setDone('dog-basics', done: true), throwsA(isA<HealthException>()));
      expect(container.read(firstDaysProvider('soya')).value!.doneTasks, {'dog-rest-spot', 'dog-name-tag'});
    });
  });
}
