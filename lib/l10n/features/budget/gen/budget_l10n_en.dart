// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'budget_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class BudgetL10nEn extends BudgetL10n {
  BudgetL10nEn([String locale = 'en']) : super(locale);

  @override
  String get budgetTitle => 'Budget';

  @override
  String get menuBudgetSummary => 'What the pets cost each month';

  @override
  String get allHome => 'All the home';

  @override
  String get wholeHome => 'Whole home';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get spentLabel => 'Spent';

  @override
  String previousMonthLine(String month, String amount) {
    return '$month: $amount';
  }

  @override
  String changeUp(String percent, String month) {
    return '↑ $percent% from $month';
  }

  @override
  String changeDown(String percent, String month) {
    return '↓ $percent% from $month';
  }

  @override
  String changeSame(String month) {
    return 'Same as $month';
  }

  @override
  String averageLine(String amount) {
    return 'Monthly average: $amount';
  }

  @override
  String get averageNote =>
      'Over the last 12 months at most. A yearly cost counts as 1/12 in every month.';

  @override
  String get byCategory => 'By category';

  @override
  String get expensesTitle => 'Expenses';

  @override
  String get noExpenses => 'Nothing spent in this month.';

  @override
  String get addExpense => 'Add expense';

  @override
  String get healthMissing =>
      'The costs from Health could not be loaded, so they are not counted here.';

  @override
  String get loadFailed => 'Could not load the budget';

  @override
  String get sourceHealth => 'from Health';

  @override
  String get sourceBasket => 'from the basket';

  @override
  String get sourceManual => 'manual';

  @override
  String get tagEveryMonth => 'every month';

  @override
  String get tagEveryYear => 'every year';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryLitter => 'Litter and consumables';

  @override
  String get categoryVet => 'Vet and medicines';

  @override
  String get categoryEquipment => 'Equipment';

  @override
  String get categoryServices => 'Services';

  @override
  String get categoryOther => 'Other';

  @override
  String get newExpense => 'New expense';

  @override
  String get editExpense => 'Edit expense';

  @override
  String get amountLabel => 'Amount';

  @override
  String get amountInvalid => 'Enter an amount, like 120';

  @override
  String get categoryLabel => 'Category';

  @override
  String get forLabel => 'For';

  @override
  String get dateLabel => 'Date';

  @override
  String get noteLabel => 'Note';

  @override
  String get noteHint => 'What was it? (optional)';

  @override
  String get howOften => 'How often';

  @override
  String get once => 'Once';

  @override
  String get everyMonth => 'Every month';

  @override
  String get everyYear => 'Every year';

  @override
  String get monthlyNote =>
      'Entered once: it counts again every month from this date, until it is stopped.';

  @override
  String get yearlyNote =>
      'Counts in this month every year. In the monthly average it counts as 1/12 a month.';

  @override
  String get stopRepeating => 'Stop repeating';

  @override
  String get keepRepeating => 'Repeat again';

  @override
  String stoppedOn(String date) {
    return 'Stopped on $date';
  }

  @override
  String get deleteExpenseTitle => 'Delete this expense?';

  @override
  String get deleteExpenseBody =>
      'It will be removed from the budget. This cannot be undone.';

  @override
  String get deleteRecurringBody =>
      'Every month it counted in will lose it. To keep the past months, stop it from repeating instead.';

  @override
  String get expenseSaved => 'Saved';

  @override
  String get expenseDeleted => 'Expense deleted';

  @override
  String get deals => 'Deals';

  @override
  String get myBasket => 'My basket';

  @override
  String get basketEmptyTitle => 'Nothing in your basket yet';

  @override
  String get basketEmptyMessage =>
      'Add the food, litter and other things you buy again and again, and see when each one runs out.';

  @override
  String get regularProduct => 'Regular product';

  @override
  String get boughtAgain => 'Bought again';

  @override
  String boughtOn(String date) {
    return 'bought $date';
  }

  @override
  String runsOutOn(String date) {
    return 'runs out $date';
  }

  @override
  String ranOutOn(String date) {
    return 'ran out $date';
  }

  @override
  String byFeeding(String grams) {
    return 'by $grams g a day from feeding';
  }

  @override
  String get notBoughtYet => 'Not bought yet';

  @override
  String dealsOnFood(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals on food for $animals',
      one: '1 deal on food for $animals',
    );
    return '$_temp0';
  }

  @override
  String dealsOnLitter(int count, String animals) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count deals on litter and cleaning for $animals',
      one: '1 deal on litter and cleaning for $animals',
    );
    return '$_temp0';
  }

  @override
  String runsOutIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'runs out in $count days',
      one: 'runs out tomorrow',
      zero: 'runs out today',
    );
    return '$_temp0';
  }

  @override
  String get ranOut => 'ran out';

  @override
  String reminderTitle(String name) {
    return '$name is running low';
  }

  @override
  String reminderBody(int count, String name, String pet, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name for $pet runs out in $count days ($date).',
      one: '$name for $pet runs out tomorrow ($date).',
    );
    return '$_temp0';
  }

  @override
  String get newProduct => 'New regular product';

  @override
  String get editProduct => 'Edit product';

  @override
  String get productName => 'Product';

  @override
  String get productNameHint => 'Adult dry food';

  @override
  String get nameRequired => 'Enter the product\'s name';

  @override
  String get kindLabel => 'Kind';

  @override
  String get kindFood => 'Food';

  @override
  String get kindLitter => 'Litter';

  @override
  String get kindConsumable => 'Consumable';

  @override
  String get kindOther => 'Other';

  @override
  String get packageSize => 'Package size';

  @override
  String get sizeInvalid => 'Enter a size, like 12';

  @override
  String get unitKg => 'kg';

  @override
  String get unitG => 'g';

  @override
  String get unitL => 'l';

  @override
  String get unitUnits => 'units';

  @override
  String get lastPrice => 'Price';

  @override
  String get boughtOnLabel => 'Bought on';

  @override
  String get lastsLabel => 'How long a package lasts';

  @override
  String get lastsByFeedingChoice => 'By the feeding';

  @override
  String get lastsOwnChoice => 'My own';

  @override
  String lastsByFeeding(String days, String grams) {
    return 'About $days days, by $grams g a day from feeding.';
  }

  @override
  String get lastsNoFeeding =>
      'Add the portion and the meal times on the feeding page, or the size in kg or g, to work it out from the feeding.';

  @override
  String get lastsAbout => 'Lasts about';

  @override
  String get lastsInvalid => 'Enter a number, like 30';

  @override
  String get days => 'days';

  @override
  String get weeks => 'weeks';

  @override
  String get lastsOptional =>
      'Leave it empty if you are not sure: there is just no run-out date.';

  @override
  String get deleteProductTitle => 'Remove this product?';

  @override
  String get deleteProductBody => 'Its past purchases stay in the budget.';

  @override
  String get productDeleted => 'Product removed';

  @override
  String boughtAgainTitle(String name) {
    return 'Bought again: $name';
  }

  @override
  String get boughtAgainNote => 'Saved as an expense in the budget.';

  @override
  String addedToBudget(String amount) {
    return '$amount added to the budget';
  }

  @override
  String get spendingTitle => 'This month\'s spending';

  @override
  String get openBudget => 'Open the budget';

  @override
  String get runningLowTitle => 'Running low';

  @override
  String get openBasket => 'Open my basket';

  @override
  String get errorOffline =>
      'Could not reach the server. Check your connection and try again.';

  @override
  String get errorSessionEnded =>
      'Your session has ended. Please sign in again.';

  @override
  String get errorNotAllowed => 'That is not allowed. Please sign in again.';

  @override
  String get errorInvalid =>
      'Some of the details are not valid. Please check them.';

  @override
  String get errorPetNotStored =>
      'This pet is not saved to your account yet, so nothing can be stored for it.';

  @override
  String get errorGone => 'That item no longer exists.';

  @override
  String get errorNeedsUpdate => 'The budget is not set up on the server yet.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';
}
