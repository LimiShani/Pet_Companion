import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_ui.dart';
import '../../platform/feature_module.dart';
import 'budget_screen.dart';
import 'expense_form_screen.dart';
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
  // The Store tab's "+": an expense in the budget (the Budget page keeps
  // its own "Add expense").
  add: {
    AddTab.store: [
      AddEntry(
        id: 'expense',
        capability: 'budget.edit',
        area: AppArea.store,
        icon: Icons.receipt_long_rounded,
        label: (c) => c.budgetL10n.addSheetExpense,
        order: 20,
        open: (c, r) =>
            openExpenseForm(c, petId: r.petId.isEmpty ? null : r.petId),
      ),
    ],
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
