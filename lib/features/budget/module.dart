import '../../platform/feature_ui.dart';
import '../../platform/feature_module.dart';
import 'budget_screen.dart';
import 'widgets/spending_card.dart';
import '../../presentation/budget_widgets.dart';

final budgetModule = FeatureModule(
  id: 'budget',
  actions: {
    'budget': FeatureAction.task(
      capability: 'budget.view',
      open: (c, r) => openBudget(c),
    ),
  },
  home: [
    FeatureContribution(
      id: 'budget-and-basket',
      capability: 'budget.view|basket.view',
      order: 30,
      builder: (_, _) => const BudgetKeeper(child: SpendingCard()),
    ),
  ],
);
