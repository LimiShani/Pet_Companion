import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/care/data/supabase_care_repository.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/health_rows.dart';
import 'package:pet_companion/features/health/state/schedule_logic.dart';
import 'package:pet_companion/models/pet.dart';

void main() {
  final now = DateTime(2025, 6, 10, 15);
  final today = DateTime(2025, 6, 10);

  const food = CareSettings(petId: 'p', foodName: 'Dry', kcalPer100g: 360, gramsPerCup: 100, portionGrams: 140);

  CarePlanItem routine(String id, CareKind kind, int hour) => CarePlanItem(
    id: id,
    petId: 'p',
    kind: kind,
    title: id,
    time: TimeOfDay(hour: hour, minute: 0),
  );

  CareLog answer(
    CarePlanItem item,
    DateTime day, {
    CareLogStatus status = CareLogStatus.done,
    int? calories,
    int? minutes,
  }) => CareLog(
    id: 'l-${item.id}-${day.day}',
    petId: 'p',
    planItemId: item.id,
    title: item.title,
    dueOn: day,
    dueTime: item.time,
    status: status,
    doneAt: atTime(day, item.time),
    loggedAt: atTime(day, item.time),
    calories: calories,
    minutes: minutes,
  );

  CareLog extra(CareKind kind, DateTime at, {int? calories, int? minutes}) => CareLog(
    id: 'x-${at.hour}-${at.day}',
    petId: 'p',
    kind: kind,
    title: 'Extra',
    dueOn: DateTime(at.year, at.month, at.day),
    status: CareLogStatus.done,
    doneAt: at,
    loggedAt: at,
    calories: calories,
    minutes: minutes,
  );

  group('calorie estimate', () {
    int calories(Pet pet) => (estimatedCalorieGoal(pet, now) as CalorieEstimate).calories;

    test('a senior dog: 70 × kg^0.75 × 1.4, in tens', () {
      const kelly = Pet(id: 'k', name: 'K', weightKg: 23, ageYears: 13.6, neutered: Neutered.yes);
      expect(calories(kelly), 1030);
    });

    test('adult dogs: neutered 1.6, not neutered 1.8', () {
      expect(calories(const Pet(id: 'a', name: 'A', weightKg: 10, ageYears: 4, neutered: Neutered.yes)), 630);
      expect(calories(const Pet(id: 'b', name: 'B', weightKg: 10, ageYears: 4, neutered: Neutered.no)), 710);
    });

    test('a puppy and a kitten eat more', () {
      expect(calories(const Pet(id: 'p', name: 'P', weightKg: 5, ageYears: 0.25)), 700);
      expect(calories(const Pet(id: 'c', name: 'C', species: PetSpecies.cat, weightKg: 2, ageYears: 0.5)), 290);
    });

    test('no estimate without a weight, or for a rabbit', () {
      expect(estimatedCalorieGoal(const Pet(id: 'x', name: 'X'), now), NoEstimate.weight);
      expect(
        estimatedCalorieGoal(const Pet(id: 'r', name: 'R', species: PetSpecies.rabbit, weightKg: 2), now),
        NoEstimate.species,
      );
    });
  });

  group('feeding day', () {
    final breakfast = routine('breakfast', CareKind.feeding, 7);
    final dinner = routine('dinner', CareKind.feeding, 19);
    const kelly = Pet(id: 'p', name: 'K', weightKg: 23, ageYears: 13.6, neutered: Neutered.yes);

    test('adds up the done meals, extras included, and finds the next one', () {
      final plan = CarePlan(
        items: [breakfast, dinner],
        logs: [
          answer(breakfast, today, calories: 504),
          extra(CareKind.feeding, DateTime(2025, 6, 10, 12), calories: 40),
        ],
      );
      final day = feedingDay(pet: kelly, plan: plan, settings: food, now: now);
      expect(day.calories, 544);
      expect(day.goal, 1030);
      expect(day.goalIsEstimate, isTrue);
      expect(day.meals.map((m) => m.title), ['breakfast', 'Extra', 'dinner']);
      expect(day.next!.entry.item, dinner);
      expect(day.next!.tomorrow, isFalse);
      expect(day.suggested(now)!.item, dinner);
      expect(day.week.last.value, 544);
      expect(day.week, hasLength(7));
    });

    test("the owner's own goal wins; a meal not eaten adds nothing", () {
      final plan = CarePlan(
        items: [breakfast],
        logs: [answer(breakfast, today, status: CareLogStatus.skipped)],
      );
      final day = feedingDay(pet: kelly, plan: plan, settings: food.withCalorieGoal(900), now: now);
      expect(day.goal, 900);
      expect(day.goalIsEstimate, isFalse);
      expect(day.calories, 0);
      expect(day.meals.single.isSkipped, isTrue);
      // Every meal of today is answered: the next one is tomorrow's.
      expect(day.next!.tomorrow, isTrue);
    });

    test('without food or times there is nothing to count or wait for', () {
      final day = feedingDay(
        pet: const Pet(id: 'p', name: 'S'),
        plan: const CarePlan(),
        settings: const CareSettings(petId: 'p'),
        now: now,
      );
      expect(day.hasFood, isFalse);
      expect(day.hasTimes, isFalse);
      expect(day.goal, isNull);
      expect(day.progress, isNull);
      expect(day.next, isNull);
    });

    test('calories of an amount follow the food', () {
      expect(food.caloriesOf(140), 504);
      expect(food.portionCups, 1.4);
      expect(const CareSettings(petId: 'p').caloriesOf(140), isNull);
    });
  });

  group('activity day', () {
    final morning = routine('morning', CareKind.walk, 7);
    final evening = routine('evening', CareKind.walk, 18);

    test('counts walks done of those planned and their minutes', () {
      final plan = CarePlan(
        items: [morning, evening],
        logs: [answer(morning, today, minutes: 35), extra(CareKind.walk, DateTime(2025, 6, 10, 12), minutes: 15)],
      );
      final day = activityDay(
        pet: const Pet(id: 'p', name: 'K'),
        plan: plan,
        settings: food,
        now: now,
      );
      expect(day.done, 2);
      expect(day.planned, 3);
      expect(day.minutes, 50);
      expect(day.goalMinutes, 60);
      expect(day.next!.entry.item, evening);
    });

    test('a cat plays half an hour unless the owner says otherwise', () {
      const cat = Pet(id: 'c', name: 'M', species: PetSpecies.cat);
      expect(activityDay(pet: cat, plan: const CarePlan(), settings: food, now: now).goalMinutes, 30);
      expect(
        activityDay(
          pet: cat,
          plan: const CarePlan(),
          settings: food.copyWith(activityGoalMinutes: 45),
          now: now,
        ).goalMinutes,
        45,
      );
    });
  });

  test("upcoming health: today's open doses and planned records, soonest first", () {
    final pill = CarePlanItem(
      id: 'pill',
      petId: 'p',
      kind: CareKind.medication,
      title: 'Joint tablets',
      time: const TimeOfDay(hour: 20, minute: 0),
      medicationId: 'm',
    );
    final morningPill = CarePlanItem(
      id: 'pill-am',
      petId: 'p',
      kind: CareKind.medication,
      title: 'Joint tablets',
      time: const TimeOfDay(hour: 8, minute: 0),
      medicationId: 'm',
    );
    final medicine = Medication(id: 'm', petId: 'p', name: 'Joint tablets');
    final plan = CarePlan(medications: [medicine], items: [pill, morningPill], logs: [answer(morningPill, today)]);
    final records = [
      HealthRecord(
        id: 'r1',
        petId: 'p',
        kind: RecordKind.checkup,
        title: 'Check',
        scheduledAt: DateTime(2025, 6, 12, 18),
      ),
      HealthRecord(id: 'r0', petId: 'p', kind: RecordKind.checkup, title: 'Old', scheduledAt: DateTime(2025, 6, 1, 9)),
    ];
    final items = upcomingHealth(plan: plan, records: records, now: now);
    expect(items.map((i) => i.title), ['Joint tablets', 'Check']);
    expect(items.first.isDose, isTrue);
  });

  group('rows', () {
    test('care settings travel to and from the table', () {
      final row = settingsToRow(food.withCalorieGoal(900));
      expect(row['kcal_per_100g'], 360);
      expect(row['calorie_goal'], 900);
      final back = settingsFromRow(row);
      expect(back.portionGrams, 140);
      expect(back.calorieGoal, 900);
    });

    test('a log sends the new columns only when they are used', () {
      final plain = logToRow(
        CareLog(id: '', petId: 'p', title: 'Breakfast', dueOn: today, status: CareLogStatus.done, loggedAt: now),
      );
      expect(plain.containsKey('calories'), isFalse);
      expect(plain.containsKey('kind'), isFalse);

      final meal = logToRow(
        CareLog(
          id: '',
          petId: 'p',
          title: 'Snack',
          dueOn: today,
          status: CareLogStatus.done,
          loggedAt: now,
          kind: CareKind.feeding,
          amountGrams: 20,
          calories: 72,
        ),
      );
      expect(meal['kind'], 'feeding');
      expect(meal['calories'], 72);
      final read = logFromRow({...meal, 'id': 'l1', 'logged_at': now.toUtc().toIso8601String()});
      expect(read.kind, CareKind.feeding);
      expect(read.amountGrams, 20);
      expect(read.calories, 72);
    });
  });
}
