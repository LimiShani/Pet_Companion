import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/platform/session.dart';
import 'package:pet_companion/services/budget/data/budget_models.dart';
import 'package:pet_companion/services/budget/data/budget_repository.dart';
import 'package:pet_companion/services/budget/state/budget_providers.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/health_providers.dart';
import 'package:pet_companion/services/pet_records/state/emergency_kit.dart';
import 'package:pet_companion/services/firstdays/data/first_days_repository.dart';
import 'package:pet_companion/services/firstdays/state/first_days_providers.dart';

class DelayedBudget extends FakeBudgetRepository {
  DelayedBudget() : super(latency: Duration.zero, seeded: false);
  final started = Completer<void>();
  final completion = Completer<Expense>();
  @override
  Future<Expense> saveExpense(Expense expense) {
    started.complete();
    return completion.future;
  }
}

class ControlledKit extends FakeHealthRepository {
  ControlledKit() : super(latency: Duration.zero, seeded: false);
  final carrierStarted = Completer<void>();
  final carrierCompletion = Completer<KitCheck>();
  @override
  Future<KitCheck> saveKitCheck(KitCheck check) {
    if (check.item == KitItem.carrier) {
      carrierStarted.complete();
      return carrierCompletion.future;
    }
    return super.saveKitCheck(check);
  }
}

void main() {
  Future<void> signIn(ProviderContainer container) async {
    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .signIn(
          email: FakeAuthRepository.demoEmail,
          password: FakeAuthRepository.demoPassword,
        );
    await container.read(accessProvider.future);
  }

  test(
    'an expense completing after account change cannot enter the next owner state',
    () async {
      final repository = DelayedBudget();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(latency: Duration.zero),
          ),
          budgetRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await signIn(container);
      await container.read(expensesProvider.future);
      final expense = Expense(
        id: 'old-owner-expense',
        petId: null,
        amount: 10,
        category: ExpenseCategory.food,
        spentOn: DateTime(2026, 10, 5),
      );
      final save = container.read(expensesProvider.notifier).save(expense);
      final rejected = expectLater(save, throwsA(isA<StaleSessionException>()));
      await repository.started.future;
      await container.read(authControllerProvider.notifier).signOut();
      await container
          .read(authControllerProvider.notifier)
          .signUp(
            displayName: 'Other',
            email: 'other@example.test',
            password: 'other1234',
          );
      await container.read(accessProvider.future);
      await container.read(expensesProvider.future);
      repository.completion.complete(expense);
      await rejected;
      expect(container.read(expensesProvider).value, isEmpty);
    },
  );

  test('a failed kit item cannot undo another successful edit', () async {
    final repository = ControlledKit();
    final container = ProviderContainer(
      overrides: [healthRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      kitChecksProvider('kelly'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(kitChecksProvider('kelly').future);
    final controller = container.read(kitChecksProvider('kelly').notifier);
    final failed = controller.setReady(KitItem.carrier, true);
    final rejected = expectLater(failed, throwsA(isA<HealthException>()));
    await repository.carrierStarted.future;
    await controller.setReady(KitItem.foodWater, true);
    repository.carrierCompletion.completeError(
      HealthException.of(HealthFailure.offline),
    );
    await rejected;
    final values = container.read(kitChecksProvider('kelly')).value!;
    expect(
      values.singleWhere((c) => c.item == KitItem.foodWater).isReady,
      isTrue,
    );
    expect(
      values.singleWhere((c) => c.item == KitItem.carrier).isReady,
      isFalse,
    );
  });

  test(
    'rapid note and readiness changes on one kit item preserve both fields',
    () async {
      final repository = FakeHealthRepository(
        latency: Duration.zero,
        seeded: false,
      );
      final container = ProviderContainer(
        overrides: [healthRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        kitChecksProvider('kelly'),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(kitChecksProvider('kelly').future);
      final controller = container.read(kitChecksProvider('kelly').notifier);
      await Future.wait([
        controller.setReady(KitItem.shelterPlan, true),
        controller.setNote(KitItem.shelterPlan, 'Lead by the door'),
      ]);
      final result = (await repository.fetchKit('kelly')).single;
      expect(result.isReady, isTrue);
      expect(result.note, 'Lead by the door');
    },
  );

  test('concurrent First Days task toggles preserve unrelated tasks', () async {
    final repository = FakeFirstDaysRepository(latency: Duration.zero);
    final container = ProviderContainer(
      overrides: [firstDaysRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      firstDaysProvider('kelly'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(firstDaysProvider('kelly').future);
    final controller = container.read(firstDaysProvider('kelly').notifier);
    await controller.start(DateTime(2026, 10, 5));
    await Future.wait([
      controller.setDone('one', done: true),
      controller.setDone('two', done: true),
    ]);
    expect(
      (await repository.fetch('kelly'))!.doneTasks,
      containsAll(['one', 'two']),
    );
  });

  test(
    'purchase retries create one expense; Basket can restock without Budget',
    () async {
      final repository = FakeBudgetRepository(latency: Duration.zero);
      final item = (await repository.fetchBasket()).first;
      final date = DateTime(2026, 10, 5);
      await Future.wait([
        for (var i = 0; i < 3; i++)
          repository.recordPurchase(
            item: item,
            price: 50,
            on: date,
            operationId: 'purchase',
          ),
      ]);
      expect(
        (await repository.fetchExpenses()).where((e) => e.amount == 50),
        hasLength(1),
      );
      await expectLater(
        repository.recordPurchase(
          item: item,
          price: 51,
          on: date,
          operationId: 'purchase',
        ),
        throwsA(isA<BudgetException>()),
      );
      final purchase = await repository.recordPurchase(
        item: item,
        price: 60,
        on: date,
        operationId: 'basket-only',
        recordExpense: false,
      );
      expect(purchase.item.lastPrice, 60);
      expect(purchase.expense, isNull);
    },
  );
}
