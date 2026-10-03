import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../notifications/notification_sink.dart';
import '../../../state/pets_provider.dart';
import '../../../utils/calendar.dart';
import '../../care/state/care_providers.dart';
import '../../health/costs.dart';
import '../../health/state/health_providers.dart' show carePlanProvider, healthClockProvider;
import '../../store/data/deal.dart';
import '../../store/data/deal_filters.dart';
import '../../store/state/store_providers.dart';
import '../data/budget_models.dart';
import '../data/budget_repository.dart';
import '../data/supabase_budget_repository.dart';
import 'basket_logic.dart';
import 'budget_logic.dart';

/// The budget and basket backend: Supabase when the app is built with its
/// configuration, otherwise the in-memory sample data, dated around the
/// sample data's day.
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseBudgetRepository(sb.Supabase.instance.client)
      : FakeBudgetRepository(now: ref.watch(healthClockProvider)),
);

// A failure is shown with a "Try again" button rather than retried.
Duration? _noRetry(int retryCount, Object error) => null;

String? _watchUserId(Ref ref) => ref.watch(authControllerProvider.select((auth) => auth.value?.id));

DateTime _today(Ref ref) {
  final now = ref.watch(healthClockProvider)();
  return DateTime(now.year, now.month, now.day);
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

/// Every expense of the signed-in owner.
class ExpensesController extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() async {
    if (_watchUserId(ref) == null) return const [];
    return ref.watch(budgetRepositoryProvider).fetchExpenses();
  }

  void _replace(List<Expense> Function(List<Expense> current) change) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) {
      // Not loaded yet: load everything again, the new row included.
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(change(current));
  }

  /// Stores [expense] (new when its id is empty) and returns it. Throws a
  /// [BudgetException] when it is not stored.
  Future<Expense> save(Expense expense) async {
    final saved = await ref.read(budgetRepositoryProvider).saveExpense(expense);
    _replace(
      (current) => [
        for (final e in current)
          if (e.id != saved.id) e,
        saved,
      ],
    );
    return saved;
  }

  Future<void> delete(String id) async {
    await ref.read(budgetRepositoryProvider).deleteExpense(id);
    _replace(
      (current) => [
        for (final e in current)
          if (e.id != id) e,
      ],
    );
  }
}

final expensesProvider = AsyncNotifierProvider<ExpensesController, List<Expense>>(
  ExpensesController.new,
  retry: _noRetry,
);

/// The health costs of every pet, and whether some could not be loaded
/// (those are then simply not counted).
typedef HomeHealthCosts = ({List<HealthCost> costs, bool missing});

final homeHealthCostsProvider = Provider.autoDispose<AsyncValue<HomeHealthCosts>>((ref) {
  final pets = ref.watch(petsProvider);
  final costs = <HealthCost>[];
  var missing = false;
  var loading = false;
  for (final pet in pets) {
    final value = ref.watch(healthCostsProvider(pet.id));
    if (value.hasValue) {
      costs.addAll(value.requireValue);
    } else if (value.hasError) {
      missing = true;
    } else {
      loading = true;
    }
  }
  if (loading) return const AsyncLoading();
  return AsyncData((costs: costs, missing: missing));
});

/// What the budget page shows: one pet or the whole home, and which month.
class BudgetFilter {
  const BudgetFilter({this.allHome = true, this.month});

  /// Every pet and what belongs to no pet; otherwise the selected pet.
  final bool allHome;

  /// The first day of the month shown; `null` is the current month.
  final DateTime? month;
}

class BudgetFilterController extends Notifier<BudgetFilter> {
  @override
  BudgetFilter build() => const BudgetFilter();

  void setAllHome(bool value) => state = BudgetFilter(allHome: value, month: state.month);

  void showMonth(DateTime month) => state = BudgetFilter(allHome: state.allHome, month: monthOf(month));
}

final budgetFilterProvider = NotifierProvider<BudgetFilterController, BudgetFilter>(BudgetFilterController.new);

/// One pet (`petId`) or the whole home (`null`), in one month.
typedef BudgetScope = ({String? petId, DateTime month});

/// The budget of a month: its total, the month before, the average, the
/// categories and the lines.
final budgetMonthProvider = Provider.autoDispose.family<AsyncValue<BudgetMonth>, BudgetScope>((ref, scope) {
  final today = _today(ref);
  final expenses = ref.watch(expensesProvider);
  final health = ref.watch(homeHealthCostsProvider);
  if (expenses.hasError) return AsyncError(expenses.error!, expenses.stackTrace ?? StackTrace.current);
  if (!expenses.hasValue || !health.hasValue) return const AsyncLoading();
  final costs = health.requireValue;
  return AsyncData(
    budgetMonth(
      expenses: expenses.requireValue,
      health: costs.costs,
      month: scope.month,
      today: today,
      currency: AppConfig.defaultCurrency,
      petId: scope.petId,
      healthMissing: costs.missing,
    ),
  );
});

/// The month the budget page opens on (and Home's card shows).
final currentMonthProvider = Provider.autoDispose<DateTime>((ref) => monthOf(_today(ref)));

/// The budget page's choice, resolved: the scope it shows.
final budgetScopeProvider = Provider.autoDispose<BudgetScope>((ref) {
  final filter = ref.watch(budgetFilterProvider);
  final petId = ref.watch(selectedPetProvider.select((pet) => pet.id));
  return (petId: filter.allHome ? null : petId, month: filter.month ?? ref.watch(currentMonthProvider));
});

/// What the budget page shows, for its current choice.
final budgetPageProvider = Provider.autoDispose<AsyncValue<BudgetMonth>>(
  (ref) => ref.watch(budgetMonthProvider(ref.watch(budgetScopeProvider))),
);

/// Home's "This month's spending": the whole home, this month.
final homeSpendingProvider = Provider.autoDispose<AsyncValue<BudgetMonth>>(
  (ref) => ref.watch(budgetMonthProvider((petId: null, month: ref.watch(currentMonthProvider)))),
);

// ---------------------------------------------------------------------------
// Basket
// ---------------------------------------------------------------------------

/// Which half of the Store is showing: the deals or the owner's basket.
enum StoreView { deals, basket }

class StoreViewController extends Notifier<StoreView> {
  @override
  StoreView build() => StoreView.deals;

  void show(StoreView view) => state = view;
}

final storeViewProvider = NotifierProvider<StoreViewController, StoreView>(StoreViewController.new);

/// A pet's feeding as the basket counts it; `null` while the portion or
/// the meal times are missing, or when they could not be loaded.
final feedingRateProvider = Provider.autoDispose.family<AsyncValue<FeedingRate?>, String>((ref, petId) {
  final today = _today(ref);
  final plan = ref.watch(carePlanProvider(petId));
  final settings = ref.watch(careSettingsProvider(petId));
  if (plan.hasError || settings.hasError) return const AsyncData(null);
  if (!plan.hasValue || !settings.hasValue) return const AsyncLoading();
  return AsyncData(feedingRateOf(plan: plan.requireValue, settings: settings.requireValue, today: today));
});

/// The pets whose feeding a basket of [items] needs: those with a food
/// product whose owner did not say how long it lasts.
Set<String> _petsFedBy(Iterable<BasketItem> items) => {
  for (final item in items)
    if (item.kind == BasketKind.food && item.lastsDays == null) item.petId,
};

/// The products the owner buys again and again.
class BasketController extends AsyncNotifier<List<BasketItem>> {
  @override
  Future<List<BasketItem>> build() async {
    if (_watchUserId(ref) == null) return const [];
    return ref.watch(budgetRepositoryProvider).fetchBasket();
  }

  void _replace(List<BasketItem> Function(List<BasketItem> current) change) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData(change(current));
  }

  /// Stores [item] (new when its id is empty) and returns it. Throws a
  /// [BudgetException] when it is not stored.
  Future<BasketItem> save(BasketItem item) async {
    final before = state.value?.where((i) => i.id == item.id).firstOrNull;
    final saved = await ref.read(budgetRepositoryProvider).saveBasketItem(item);
    _replace(
      (current) => [
        for (final i in current)
          if (i.id != saved.id) i else saved,
        if (!current.any((i) => i.id == saved.id)) saved,
      ],
    );
    await _sync({saved.petId, ?before?.petId});
    return saved;
  }

  Future<void> delete(BasketItem item) async {
    await ref.read(budgetRepositoryProvider).deleteBasketItem(item.id);
    _replace(
      (current) => [
        for (final i in current)
          if (i.id != item.id) i,
      ],
    );
    await _sync({item.petId});
  }

  /// "Bought again": the product's price and date become [price] and [on],
  /// and the purchase is recorded in the budget. Throws a
  /// [BudgetException] when either is not stored.
  Future<Expense> boughtAgain(BasketItem item, {required double price, required DateTime on}) async {
    final day = DateTime(on.year, on.month, on.day);
    await save(item.copyWith(lastPrice: price, lastBoughtOn: day));
    return ref
        .read(expensesProvider.notifier)
        .save(
          Expense(
            id: '',
            petId: item.petId,
            amount: price,
            currency: item.currency,
            category: item.kind.category,
            spentOn: day,
            note: item.name,
            source: ExpenseSource.basket,
            basketItemId: item.id,
          ),
        );
  }

  Future<void> _sync(Set<String> petIds) async {
    final items = state.value;
    if (items == null) return;
    await _syncPets(petIds, items);
  }

  /// Plans [petId]'s basket reminders again. The notifications' coordinator
  /// calls it at sign-in and when the app comes back after a while: a run-out
  /// day also moves when the feeding portion or the meal times change.
  Future<void> resyncReminders(String petId) async {
    final List<BasketItem> items;
    try {
      items = await future;
    } catch (_) {
      return;
    }
    await _syncPets({petId}, items);
  }

  /// Plans the reminders of [petIds]' baskets again. A failure only means
  /// no reminder: it never fails what the owner did.
  Future<void> _syncPets(Set<String> petIds, List<BasketItem> items) async {
    if (petIds.isEmpty) return;
    try {
      final sink = ref.read(notificationSinkProvider);
      final words = ref.read(budgetL10nProvider);
      final format = ref.read(appFormatProvider);
      final pets = ref.read(petsProvider);
      final today = ref.read(healthClockProvider)();
      // The sample data lives on another day (see healthClockProvider): its
      // reminders move to the real calendar, so the demo rings too. On a
      // real account the two days are the same.
      final shift = daysBetween(today, DateTime.now());
      DateTime moved(DateTime at) => DateTime(at.year, at.month, at.day + shift, at.hour, at.minute);
      final fed = _petsFedBy(items);
      for (final petId in petIds) {
        final rate = fed.contains(petId) ? await _feedingRate(petId) : null;
        if (!ref.mounted) return;
        final pet = pets.firstWhere((p) => p.id == petId, orElse: () => Pet.none);
        final lines = [
          for (final item in items)
            if (item.petId == petId) basketLine(item, rate: rate, today: today),
        ];
        final reminders = [
          for (final r in basketReminders(
            petId: petId,
            lines: lines,
            now: today,
            title: (line) => words.reminderTitle(line.item.name),
            body: (line) => words.reminderBody(
              reminderDaysBefore,
              line.item.name,
              pet.name,
              format.dayMonth(moved(line.runsOutOn!)),
            ),
          ))
            PlannedNotification(
              key: r.key,
              kind: r.kind,
              at: moved(r.at),
              title: r.title,
              body: r.body,
              payload: r.payload,
            ),
        ];
        await sink.syncGroup(basketGroup(petId), reminders);
      }
    } catch (_) {
      // Nothing to show: the basket itself is saved.
    }
  }

  Future<FeedingRate?> _feedingRate(String petId) async {
    try {
      final today = ref.read(healthClockProvider)();
      final plan = await _once(carePlanProvider(petId).future);
      final settings = await _once(careSettingsProvider(petId).future);
      return feedingRateOf(plan: plan, settings: settings, today: today);
    } catch (_) {
      return null;
    }
  }

  /// Reads an auto-disposed provider's value, keeping it alive meanwhile.
  Future<T> _once<T>(ProviderListenable<Future<T>> provider) async {
    final sub = ref.listen(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }
}

final basketProvider = AsyncNotifierProvider<BasketController, List<BasketItem>>(BasketController.new, retry: _noRetry);

/// The basket with run-out dates, the pets in their usual order and each
/// pet's products by name.
final basketLinesProvider = Provider.autoDispose<AsyncValue<List<BasketLine>>>((ref) {
  final items = ref.watch(basketProvider);
  if (items.hasError) return AsyncError(items.error!, items.stackTrace ?? StackTrace.current);
  if (!items.hasValue) return const AsyncLoading();
  final today = _today(ref);
  final pets = ref.watch(petsProvider);
  final order = {for (var i = 0; i < pets.length; i++) pets[i].id: i};
  final shown = [
    for (final item in items.requireValue)
      if (order.containsKey(item.petId)) item,
  ];
  final rates = <String, FeedingRate?>{};
  for (final petId in _petsFedBy(shown)) {
    final rate = ref.watch(feedingRateProvider(petId));
    if (!rate.hasValue) return const AsyncLoading();
    rates[petId] = rate.requireValue;
  }
  final lines = [for (final item in shown) basketLine(item, rate: rates[item.petId], today: today)];
  lines.sort((a, b) {
    final byPet = order[a.item.petId]!.compareTo(order[b.item.petId]!);
    return byPet != 0 ? byPet : a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
  });
  return AsyncData(lines);
});

/// Home's "Running low": what runs out within a week, soonest first.
final runningLowProvider = Provider.autoDispose<AsyncValue<List<BasketLine>>>(
  (ref) => ref.watch(basketLinesProvider).whenData(runningLow),
);

/// The Store category a product's deals are in, or `null` when the Store
/// has none for it.
DealCategory? dealCategoryOf(BasketKind kind) => switch (kind) {
  BasketKind.food => DealCategory.food,
  BasketKind.litter || BasketKind.consumable => DealCategory.litterAndCleaning,
  BasketKind.other => null,
};

/// How many live deals the Store has in a category for a kind of animal.
final basketDealCountProvider = Provider.autoDispose.family<int, (DealCategory, PetSpecies)>((ref, key) {
  final (category, species) = key;
  final deals = ref.watch(dealsProvider).value ?? const <Deal>[];
  final now = ref.watch(storeClockProvider)();
  return visibleDeals(deals, StoreFilter(category: category), now, pet: species).where((d) => !d.isExpired(now)).length;
});

/// Opens the Store's deals on [category] for [petId]'s kind of animal.
void showDealsFor(WidgetRef ref, {required String petId, required DealCategory category}) {
  ref.read(selectedPetIdProvider.notifier).select(petId);
  ref.read(storeFilterProvider.notifier)
    ..clear()
    ..setAllAnimals(false)
    ..setCategory(category);
  ref.read(storeViewProvider.notifier).show(StoreView.deals);
}
