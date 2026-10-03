/// The budget (what the pets cost each month) and the Store's basket (the
/// products the owner buys again and again). One import for the rest of
/// the app:
///
/// ```dart
/// import 'package:pet_companion/features/budget/budget.dart';
/// ```
///
/// - `openBudget(context)` opens the budget page (the side menu's
///   "Budget", Home's spending card).
/// - `BudgetHomeCards` are Home's "This month's spending" and "Running
///   low" cards; each shows only while it has something to say.
/// - `BasketView` is the Store's "My basket"; `storeViewProvider` says
///   which half of the Store shows.
///
/// "Bought again" in the basket records an expense in the budget; health
/// costs are read from Health (`features/health/costs.dart`) and never
/// copied. Basket reminders go through the shared `NotificationSink`
/// (kind `basket`, group and payload `basket:<petId>`).
library;

export 'basket/basket_view.dart' show BasketView;
export 'budget_screen.dart' show BudgetScreen, openBudget;
export 'data/budget_models.dart';
export 'data/budget_repository.dart' show BudgetException, BudgetFailure, BudgetRepository, FakeBudgetRepository;
export 'state/budget_providers.dart'
    show StoreView, basketProvider, budgetRepositoryProvider, expensesProvider, storeViewProvider;
export 'widgets/home_cards.dart' show BudgetHomeCards, RunningLowCard, SpendingCard;
