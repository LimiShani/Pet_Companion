import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/budget/budget.dart';
import 'package:pet_companion/features/budget/state/basket_logic.dart';
import 'package:pet_companion/features/budget/state/budget_logic.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/health/costs.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/state/schedule_logic.dart';
import 'package:pet_companion/notifications/notification_sink.dart';

Expense _expense(
  String id,
  double amount,
  DateTime on, {
  String? pet = 'kelly',
  ExpenseCategory category = ExpenseCategory.other,
  ExpenseFrequency frequency = ExpenseFrequency.once,
  DateTime? endedOn,
  String currency = 'ILS',
}) => Expense(
  id: id,
  petId: pet,
  amount: amount,
  category: category,
  spentOn: on,
  frequency: frequency,
  endedOn: endedOn,
  currency: currency,
  note: id,
);

HealthCost _cost(String id, double amount, DateTime on, {String pet = 'kelly'}) => HealthCost(
  recordId: id,
  petId: pet,
  title: id,
  date: on,
  amount: amount,
  currency: 'ILS',
  category: HealthCostCategory.vetVisit,
);

CarePlanItem _meal(String id, {Set<int> days = CarePlanItem.everyDay, bool active = true, DateTime? endsOn}) =>
    CarePlanItem(
      id: id,
      petId: 'kelly',
      kind: CareKind.feeding,
      title: id,
      time: const TimeOfDay(hour: 8, minute: 0),
      days: days,
      active: active,
      endsOn: endsOn,
    );

BasketItem _item({
  String id = 'b1',
  BasketKind kind = BasketKind.food,
  double size = 12,
  BasketUnit unit = BasketUnit.kg,
  DateTime? bought,
  int? lastsDays,
  String pet = 'kelly',
}) => BasketItem(
  id: id,
  petId: pet,
  name: 'Dry food',
  kind: kind,
  packageSize: size,
  unit: unit,
  lastPrice: 240,
  lastBoughtOn: bought,
  lastsDays: lastsDays,
);

void main() {
  final today = DateTime(2025, 6, 10);
  final june = DateTime(2025, 6);
  final may = DateTime(2025, 5);

  group('payments of an expense in a month', () {
    test('a one-off expense is paid only in its own month', () {
      final e = _expense('toy', 45, DateTime(2025, 6, 7));
      expect(paymentIn(e, june, today), DateTime(2025, 6, 7));
      expect(paymentIn(e, may, today), isNull);
      expect(paymentIn(e, DateTime(2025, 7), today), isNull);
    });

    test('a monthly expense counts in every month from its date on, once its day has come', () {
      final e = _expense('walker', 200, DateTime(2025, 4, 1), frequency: ExpenseFrequency.monthly);
      expect(paymentIn(e, DateTime(2025, 3), today), isNull);
      expect(paymentIn(e, DateTime(2025, 4), today), DateTime(2025, 4, 1));
      expect(paymentIn(e, may, today), DateTime(2025, 5, 1));
      expect(paymentIn(e, june, today), DateTime(2025, 6, 1));
      // On the 15th of a month, the payment of the 20th is still ahead.
      final late = _expense('late', 50, DateTime(2025, 1, 20), frequency: ExpenseFrequency.monthly);
      expect(paymentIn(late, june, today), isNull);
      expect(paymentIn(late, may, today), DateTime(2025, 5, 20));
    });

    test('the 31st falls on the last day of a shorter month', () {
      final e = _expense('rent', 100, DateTime(2025, 1, 31), frequency: ExpenseFrequency.monthly);
      expect(paymentIn(e, DateTime(2025, 2), today), DateTime(2025, 2, 28));
      expect(paymentIn(e, DateTime(2025, 4), today), DateTime(2025, 4, 30));
    });

    test('a stopped expense counts no payment after the day it was stopped', () {
      final e = _expense(
        'walker',
        200,
        DateTime(2025, 2, 1),
        frequency: ExpenseFrequency.monthly,
        endedOn: DateTime(2025, 4, 15),
      );
      expect(paymentIn(e, DateTime(2025, 4), today), DateTime(2025, 4, 1));
      expect(paymentIn(e, may, today), isNull);
      expect(paymentIn(e, june, today), isNull);
    });

    test('a yearly expense is paid in the same month of every year', () {
      final e = _expense('insurance', 600, DateTime(2024, 6, 3), frequency: ExpenseFrequency.yearly);
      expect(paymentIn(e, june, today), DateTime(2025, 6, 3));
      expect(paymentIn(e, may, today), isNull);
      expect(paymentIn(e, DateTime(2024, 6), today), DateTime(2024, 6, 3));
    });
  });

  group('a month of the budget', () {
    final expenses = [
      _expense('food', 240, DateTime(2025, 5, 2), category: ExpenseCategory.food),
      _expense('toy', 45, DateTime(2025, 6, 7), category: ExpenseCategory.equipment),
      _expense('home', 35, DateTime(2025, 6, 9), pet: null),
      _expense('soya', 150, DateTime(2025, 6, 3), pet: 'soya', category: ExpenseCategory.services),
      _expense(
        'walker',
        200,
        DateTime(2025, 4, 1),
        category: ExpenseCategory.services,
        frequency: ExpenseFrequency.monthly,
      ),
      _expense(
        'insurance',
        600,
        DateTime(2025, 5, 3),
        category: ExpenseCategory.services,
        frequency: ExpenseFrequency.yearly,
      ),
      _expense('dollars', 99, DateTime(2025, 6, 1), currency: 'USD'),
    ];
    final health = [_cost('check', 320, DateTime(2025, 6, 5, 18)), _cost('flea', 85, DateTime(2025, 5, 27))];

    BudgetMonth month(DateTime m, {String? pet}) =>
        budgetMonth(expenses: expenses, health: health, month: m, today: today, currency: 'ILS', petId: pet);

    test('the whole home counts every pet, the home itself and the health costs, in its own currency', () {
      final b = month(june);
      // 45 + 35 + 150 + 200 (walker) + 320 (health). The dollars are left out.
      expect(b.total, 750);
      expect(b.entries.map((e) => e.title), ['home', 'toy', 'check', 'soya', 'walker']);
      expect(b.entries.firstWhere((e) => e.title == 'check').category, ExpenseCategory.vet);
      expect(b.entries.firstWhere((e) => e.title == 'check').source, EntrySource.health);
      expect(b.entries.firstWhere((e) => e.title == 'home').petId, isNull);
    });

    test('one pet counts only its own expenses and health costs', () {
      expect(month(june, pet: 'kelly').total, 45 + 200 + 320);
      expect(month(june, pet: 'soya').total, 150);
    });

    test('the month before is compared in whole percent', () {
      final b = month(june);
      // May: 240 + 200 + 600 + 85.
      expect(b.previousTotal, 1125);
      expect(b.change, -33);
      expect(month(DateTime(2025, 4)).change, isNull, reason: 'March had nothing');
    });

    test('the categories are added up, largest first', () {
      final b = month(june);
      expect(b.byCategory.keys.toList(), [
        ExpenseCategory.services,
        ExpenseCategory.vet,
        ExpenseCategory.equipment,
        ExpenseCategory.other,
      ]);
      expect(b.byCategory[ExpenseCategory.services], 350);
    });

    test('the average spreads a yearly expense as 1/12 a month', () {
      // April to June: April 200; May 240 + 200 + 85 (the insurance is
      // spread); June 750. 1475 / 3 = 491.67, plus 600 / 12 = 50.
      expect(month(june).average, closeTo(541.67, 0.01));
      // Before the insurance started, it is not in the average.
      expect(month(DateTime(2025, 4)).average, 200);
    });

    test('the average looks back twelve months at most', () {
      final old = [
        _expense('old', 1200, DateTime(2023, 1, 1)),
        _expense('now', 100, DateTime(2025, 6, 1)),
      ];
      final avg = monthlyAverage(expenses: old, health: const [], month: june, today: today, currency: 'ILS');
      expect(avg, closeTo(100 / 12, 0.01));
    });

    test('an empty month is empty', () {
      final b = budgetMonth(expenses: const [], health: const [], month: june, today: today, currency: 'ILS');
      expect(b.isEmpty, isTrue);
      expect(b.total, 0);
      expect(b.average, 0);
    });

    test('amounts add up in whole cents', () {
      expect(sumOf([0.1, 0.2]), 0.3);
    });
  });

  group('how long a package lasts', () {
    const settings = CareSettings(petId: 'kelly', portionGrams: 140);

    test('grams a day are the portion times the active feeding routines', () {
      final rate = feedingRateOf(
        plan: CarePlan(items: [_meal('breakfast'), _meal('dinner'), _meal('paused', active: false)]),
        settings: settings,
        today: today,
      );
      expect(rate!.mealsPerDay, 2);
      expect(rate.gramsPerDay, 280);
    });

    test('a routine on some days counts its share of the week; one that ended does not count', () {
      final rate = feedingRateOf(
        plan: CarePlan(
          items: [
            _meal('breakfast'),
            _meal('weekend', days: {6, 7}),
            _meal('old', endsOn: DateTime(2025, 6, 1)),
          ],
        ),
        settings: settings,
        today: today,
      );
      expect(rate!.mealsPerDay, closeTo(9 / 7, 1e-9));
    });

    test('no portion or no meal times: nothing to work out', () {
      expect(
        feedingRateOf(plan: CarePlan(items: [_meal('a')]), settings: const CareSettings(petId: 'kelly'), today: today),
        isNull,
      );
      expect(feedingRateOf(plan: const CarePlan(), settings: settings, today: today), isNull);
    });

    const rate = FeedingRate(portionGrams: 140, mealsPerDay: 2);

    test('food lasts by the feeding: 12 kg at 280 g a day is 42 days', () {
      final line = basketLine(_item(bought: DateTime(2025, 5, 2)), rate: rate, today: today);
      expect(line.by, LastsBy.feeding);
      expect(line.lastsDays, 42);
      expect(line.runsOutOn, DateTime(2025, 6, 13));
      expect(line.daysLeft, 3);
      expect(line.left, closeTo(3 / 42, 1e-9));
      expect(line.isLow, isTrue);
    });

    test("the owner's own number wins over the feeding", () {
      final line = basketLine(_item(bought: DateTime(2025, 5, 2), lastsDays: 60), rate: rate, today: today);
      expect(line.by, LastsBy.owner);
      expect(line.runsOutOn, DateTime(2025, 7, 1));
      expect(line.isLow, isFalse);
    });

    test('food in litres, other kinds without a number, or never bought: no run-out date', () {
      expect(
        basketLine(
          _item(unit: BasketUnit.l, bought: today),
          rate: rate,
          today: today,
        ).runsOutOn,
        isNull,
      );
      expect(
        basketLine(
          _item(kind: BasketKind.litter, bought: today),
          rate: rate,
          today: today,
        ).by,
        LastsBy.unknown,
      );
      expect(basketLine(_item(), rate: rate, today: today).runsOutOn, isNull);
    });

    test('running low is within a week, soonest first, the ones that ran out included', () {
      final lines = [
        basketLine(_item(id: 'later', bought: DateTime(2025, 6, 1), lastsDays: 30), today: today),
        basketLine(_item(id: 'week', bought: DateTime(2025, 6, 1), lastsDays: 16), today: today),
        basketLine(_item(id: 'gone', bought: DateTime(2025, 5, 1), lastsDays: 30), today: today),
        basketLine(_item(id: 'soon', bought: DateTime(2025, 6, 1), lastsDays: 11), today: today),
      ];
      expect(runningLow(lines).map((l) => l.item.id), ['gone', 'soon', 'week']);
    });
  });

  group('basket reminders', () {
    final lines = [
      basketLine(_item(id: 'food', bought: DateTime(2025, 6, 1), lastsDays: 20), today: today),
      basketLine(_item(id: 'soon', bought: DateTime(2025, 6, 1), lastsDays: 12), today: today),
      basketLine(_item(id: 'unknown', kind: BasketKind.other, bought: today), today: today),
      basketLine(_item(id: 'soya', pet: 'soya', bought: today, lastsDays: 30), today: today),
    ];

    test('five days before a product runs out, at 10:00, in the basket group of the pet', () {
      final reminders = basketReminders(
        petId: 'kelly',
        lines: lines,
        now: DateTime(2025, 6, 10, 12),
        title: (line) => 'Low: ${line.item.id}',
        body: (line) => 'body',
      );
      // "food" runs out on 21 June: the reminder is on 16 June at 10:00.
      // "soon" runs out on 13 June: its reminder (8 June) is already past.
      expect(reminders, hasLength(1));
      final r = reminders.single;
      expect(r.at, DateTime(2025, 6, 16, 10));
      expect(r.kind, NotificationKind.basket);
      expect(r.key, 'food@2025-06-21');
      expect(r.title, 'Low: food');
      expect(r.payload, 'basket:kelly');
      expect(basketGroup('kelly'), 'basket:kelly');
    });

    test('nothing ahead: an empty list, which cancels the group', () {
      final reminders = basketReminders(
        petId: 'kelly',
        lines: lines,
        now: DateTime(2025, 7, 1),
        title: (_) => '',
        body: (_) => '',
      );
      expect(reminders, isEmpty);
    });
  });
}
