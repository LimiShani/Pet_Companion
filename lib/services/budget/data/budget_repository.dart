import '../../../utils/calendar.dart';
import 'budget_models.dart';

/// Why a budget or basket action failed. The screen puts it into words in
/// the app's language (`budgetErrorText`).
enum BudgetFailure {
  /// The server could not be reached.
  offline,
  sessionEnded,
  notAllowed,
  invalid,

  /// The pet is not stored in the account (sample data on a real account).
  petNotStored,

  /// The expense or product no longer exists.
  gone,

  /// The database is older than the app (0010 has not been run).
  needsUpdate,
  unknown,
}

/// Thrown by a [BudgetRepository] and the budget's controllers. [detail] is
/// for logs only.
class BudgetException implements Exception {
  const BudgetException(this.failure, [this.detail]);

  final BudgetFailure failure;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'BudgetException(${failure.name})'
      : 'BudgetException(${failure.name}: $detail)';
}

/// The owner's expenses and the products of their basket.
///
/// "Save" methods create the item when its id is empty and update it
/// otherwise, and return what is stored. Failures are [BudgetException]s.
typedef BasketPurchase = ({BasketItem item, Expense? expense});

abstract interface class ExpensesRepository {
  Future<List<Expense>> fetchExpenses();
  Future<Expense> saveExpense(Expense expense);
  Future<void> deleteExpense(String id);
}

abstract interface class BasketRepository {
  Future<BasketPurchase> recordPurchase({
    required BasketItem item,
    required double price,
    required DateTime on,
    required String operationId,
    bool recordExpense = true,
  });
  Future<List<BasketItem>> fetchBasket();
  Future<BasketItem> saveBasketItem(BasketItem item);
  Future<void> deleteBasketItem(String id);
}

/// Legacy aggregate for existing adapters and overrides.
abstract class BudgetRepository
    implements ExpensesRepository, BasketRepository {}

/// In memory, for the demo and the tests. The sample data is dated around
/// [now] (the sample data's day, see `healthClockProvider`), so "this
/// month" always has something to show.
class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    bool seeded = true,
    this.failWith,
  }) : _now = now ?? DateTime.now {
    if (seeded) _seed();
  }

  final Duration latency;
  final DateTime Function() _now;

  /// When set, every call fails with it (for error states in tests).
  BudgetFailure? failWith;

  final _expenses = <String, Expense>{};
  final _basket = <String, BasketItem>{};
  final _purchases = <String, BasketPurchase>{};
  final _purchaseRequests = <String, String>{};
  var _nextId = 1;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    final failure = failWith;
    if (failure != null) throw BudgetException(failure);
  }

  String _id(String prefix) => '$prefix-${_nextId++}';

  void _seed() {
    final today = _now();
    final day = DateTime(today.year, today.month, today.day);
    DateTime ago(int days) => addDays(day, -days);
    final lastMonth = DateTime(day.year, day.month - 1, 3);
    final twoMonthsAgo = DateTime(day.year, day.month - 2, 1);

    for (final item in [
      // 12 kg at 280 g a day (two meals of 140 g) lasts 42 days: Kelly's
      // food runs out in three days, so Home shows "Running low".
      BasketItem(
        id: 'b-kelly-food',
        petId: 'kelly',
        name: 'Adult dry food',
        kind: BasketKind.food,
        packageSize: 12,
        unit: BasketUnit.kg,
        lastPrice: 240,
        lastBoughtOn: ago(39),
      ),
      BasketItem(
        id: 'b-kelly-chews',
        petId: 'kelly',
        name: 'Dental chews',
        kind: BasketKind.consumable,
        packageSize: 28,
        unit: BasketUnit.units,
        lastPrice: 59,
        lastBoughtOn: ago(12),
        lastsDays: 28,
      ),
      BasketItem(
        id: 'b-soya-bags',
        petId: 'soya',
        name: 'Poop bags',
        kind: BasketKind.consumable,
        packageSize: 120,
        unit: BasketUnit.units,
        lastPrice: 29,
        lastBoughtOn: ago(10),
        lastsDays: 60,
      ),
    ]) {
      _basket[item.id] = item;
    }

    for (final expense in [
      Expense(
        id: 'e-food',
        petId: 'kelly',
        amount: 240,
        category: ExpenseCategory.food,
        spentOn: ago(39),
        note: 'Adult dry food',
        source: ExpenseSource.basket,
        basketItemId: 'b-kelly-food',
      ),
      Expense(
        id: 'e-chews',
        petId: 'kelly',
        amount: 59,
        category: ExpenseCategory.litter,
        spentOn: ago(12),
        note: 'Dental chews',
        source: ExpenseSource.basket,
        basketItemId: 'b-kelly-chews',
      ),
      Expense(
        id: 'e-bags',
        petId: 'soya',
        amount: 29,
        category: ExpenseCategory.litter,
        spentOn: ago(10),
        note: 'Poop bags',
        source: ExpenseSource.basket,
        basketItemId: 'b-soya-bags',
      ),
      Expense(
        id: 'e-insurance',
        petId: 'kelly',
        amount: 600,
        category: ExpenseCategory.services,
        spentOn: lastMonth,
        note: 'Pet insurance',
        frequency: ExpenseFrequency.yearly,
      ),
      Expense(
        id: 'e-walker',
        petId: 'kelly',
        amount: 200,
        category: ExpenseCategory.services,
        spentOn: twoMonthsAgo,
        note: 'Dog walker',
        frequency: ExpenseFrequency.monthly,
      ),
      Expense(
        id: 'e-toy',
        petId: 'kelly',
        amount: 45,
        category: ExpenseCategory.equipment,
        spentOn: ago(3),
        note: 'Rope toy',
      ),
      Expense(
        id: 'e-groom',
        petId: 'soya',
        amount: 150,
        category: ExpenseCategory.services,
        spentOn: ago(20),
        note: 'Grooming',
      ),
      Expense(
        id: 'e-home',
        petId: null,
        amount: 35,
        category: ExpenseCategory.other,
        spentOn: ago(1),
        note: 'Lint roller',
      ),
    ]) {
      _expenses[expense.id] = expense;
    }
  }

  @override
  Future<List<Expense>> fetchExpenses() async {
    await _wait();
    return _expenses.values.toList();
  }

  @override
  Future<Expense> saveExpense(Expense expense) async {
    await _wait();
    if (expense.amount < 0) throw const BudgetException(BudgetFailure.invalid);
    if (!expense.isNew && !_expenses.containsKey(expense.id)) {
      throw const BudgetException(BudgetFailure.gone);
    }
    final saved = expense.isNew ? expense.copyWith(id: _id('e')) : expense;
    return _expenses[saved.id] = saved;
  }

  @override
  Future<void> deleteExpense(String id) async {
    await _wait();
    _expenses.remove(id);
  }

  @override
  Future<List<BasketItem>> fetchBasket() async {
    await _wait();
    return _basket.values.toList();
  }

  @override
  Future<BasketItem> saveBasketItem(BasketItem item) async {
    await _wait();
    if (item.name.trim().isEmpty || item.packageSize <= 0) {
      throw const BudgetException(BudgetFailure.invalid);
    }
    if (!item.isNew && !_basket.containsKey(item.id)) {
      throw const BudgetException(BudgetFailure.gone);
    }
    final saved = item.isNew ? item.copyWith(id: _id('b')) : item;
    return _basket[saved.id] = saved;
  }

  @override
  Future<BasketPurchase> recordPurchase({
    required BasketItem item,
    required double price,
    required DateTime on,
    required String operationId,
    bool recordExpense = true,
  }) async {
    await _wait();
    final previous = _purchases[operationId];
    final fingerprint =
        '${item.id}|$price|${DateTime(on.year, on.month, on.day).toIso8601String()}|$recordExpense';
    if (previous != null) {
      if (_purchaseRequests[operationId] != fingerprint) {
        throw const BudgetException(BudgetFailure.invalid);
      }
      return previous;
    }
    if (!_basket.containsKey(item.id)) {
      throw const BudgetException(BudgetFailure.gone);
    }
    if (!price.isFinite ||
        price < 0 ||
        price > 1000000 ||
        operationId.isEmpty) {
      throw const BudgetException(BudgetFailure.invalid);
    }
    final day = DateTime(on.year, on.month, on.day);
    final saved = _basket[item.id]!.copyWith(
      lastPrice: price,
      lastBoughtOn: day,
    );
    final expense = recordExpense
        ? Expense(
            id: _id('e'),
            petId: saved.petId,
            amount: price,
            currency: saved.currency,
            category: saved.kind.category,
            spentOn: day,
            note: saved.name,
            source: ExpenseSource.basket,
            basketItemId: saved.id,
          )
        : null;
    final result = (item: saved, expense: expense);
    _basket[item.id] = saved;
    if (expense != null) _expenses[expense.id] = expense;
    _purchases[operationId] = result;
    _purchaseRequests[operationId] = fingerprint;
    return result;
  }

  @override
  Future<void> deleteBasketItem(String id) async {
    await _wait();
    _basket.remove(id);
  }
}
