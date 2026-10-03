import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import 'data/budget_models.dart';
import 'data/budget_repository.dart';
import 'state/budget_logic.dart';

/// The bridge between the budget's values and its words (the words are in
/// `l10n/budget_en.arb` and `l10n/budget_he.arb`).
extension BudgetWords on BudgetL10n {
  String category(ExpenseCategory category) => switch (category) {
    ExpenseCategory.food => categoryFood,
    ExpenseCategory.litter => categoryLitter,
    ExpenseCategory.vet => categoryVet,
    ExpenseCategory.equipment => categoryEquipment,
    ExpenseCategory.services => categoryServices,
    ExpenseCategory.other => categoryOther,
  };

  String frequency(ExpenseFrequency frequency) => switch (frequency) {
    ExpenseFrequency.once => once,
    ExpenseFrequency.monthly => everyMonth,
    ExpenseFrequency.yearly => everyYear,
  };

  String source(EntrySource source) => switch (source) {
    EntrySource.manual => sourceManual,
    EntrySource.basket => sourceBasket,
    EntrySource.health => sourceHealth,
  };

  String kind(BasketKind kind) => switch (kind) {
    BasketKind.food => kindFood,
    BasketKind.litter => kindLitter,
    BasketKind.consumable => kindConsumable,
    BasketKind.other => kindOther,
  };

  String unit(BasketUnit unit) => switch (unit) {
    BasketUnit.kg => unitKg,
    BasketUnit.g => unitG,
    BasketUnit.l => unitL,
    BasketUnit.units => unitUnits,
  };

  String failure(BudgetFailure failure) => switch (failure) {
    BudgetFailure.offline => errorOffline,
    BudgetFailure.sessionEnded => errorSessionEnded,
    BudgetFailure.notAllowed => errorNotAllowed,
    BudgetFailure.invalid => errorInvalid,
    BudgetFailure.petNotStored => errorPetNotStored,
    BudgetFailure.gone => errorGone,
    BudgetFailure.needsUpdate => errorNeedsUpdate,
    BudgetFailure.unknown => errorUnknown,
  };
}

/// A budget failure in the language of the screen.
String budgetErrorText(BuildContext context, Object error) {
  final l10n = context.budgetL10n;
  return error is BudgetException ? l10n.failure(error.failure) : l10n.errorUnknown;
}

/// The icon of a budget category.
IconData categoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => Icons.restaurant_rounded,
  ExpenseCategory.litter => Icons.inventory_2_rounded,
  ExpenseCategory.vet => Icons.medical_services_rounded,
  ExpenseCategory.equipment => Icons.sports_baseball_rounded,
  ExpenseCategory.services => Icons.content_cut_rounded,
  ExpenseCategory.other => Icons.category_rounded,
};

/// The colour of a budget category's bar.
Color categoryColor(ExpenseCategory category) => switch (category) {
  ExpenseCategory.food => AppColors.sage,
  ExpenseCategory.litter => AppColors.yellow,
  ExpenseCategory.vet => AppColors.peach,
  ExpenseCategory.equipment => AppColors.coral,
  ExpenseCategory.services => AppColors.coralDeep,
  ExpenseCategory.other => AppColors.brown,
};
