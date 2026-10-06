import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'budget_l10n_en.dart';
import 'budget_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of BudgetL10n
/// returned by `BudgetL10n.of(context)`.
///
/// Applications need to include `BudgetL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/budget_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: BudgetL10n.localizationsDelegates,
///   supportedLocales: BudgetL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the BudgetL10n.supportedLocales
/// property.
abstract class BudgetL10n {
  BudgetL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static BudgetL10n of(BuildContext context) {
    return Localizations.of<BudgetL10n>(context, BudgetL10n)!;
  }

  static const LocalizationsDelegate<BudgetL10n> delegate =
      _BudgetL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// Title of the budget page and of its row in the side menu.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetTitle;

  /// Under "Budget" in the side menu.
  ///
  /// In en, this message translates to:
  /// **'What the pets cost each month'**
  String get menuBudgetSummary;

  /// The pill that shows every pet's expenses and the ones of the whole home.
  ///
  /// In en, this message translates to:
  /// **'All the home'**
  String get allHome;

  /// An expense that is not for one pet.
  ///
  /// In en, this message translates to:
  /// **'Whole home'**
  String get wholeHome;

  /// No description provided for @previousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Above the month's total on the budget page.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spentLabel;

  /// The month before and its total: "May: ₪570".
  ///
  /// In en, this message translates to:
  /// **'{month}: {amount}'**
  String previousMonthLine(String month, String amount);

  /// No description provided for @changeUp.
  ///
  /// In en, this message translates to:
  /// **'↑ {percent}% from {month}'**
  String changeUp(String percent, String month);

  /// No description provided for @changeDown.
  ///
  /// In en, this message translates to:
  /// **'↓ {percent}% from {month}'**
  String changeDown(String percent, String month);

  /// No description provided for @changeSame.
  ///
  /// In en, this message translates to:
  /// **'Same as {month}'**
  String changeSame(String month);

  /// No description provided for @averageLine.
  ///
  /// In en, this message translates to:
  /// **'Monthly average: {amount}'**
  String averageLine(String amount);

  /// No description provided for @averageNote.
  ///
  /// In en, this message translates to:
  /// **'Over the last 12 months at most. A yearly cost counts as 1/12 in every month.'**
  String get averageNote;

  /// No description provided for @byCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get byCategory;

  /// No description provided for @expensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expensesTitle;

  /// No description provided for @noExpenses.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent in this month.'**
  String get noExpenses;

  /// No description provided for @addExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get addExpense;

  /// No description provided for @healthMissing.
  ///
  /// In en, this message translates to:
  /// **'The costs from Health could not be loaded, so they are not counted here.'**
  String get healthMissing;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the budget'**
  String get loadFailed;

  /// No description provided for @sourceHealth.
  ///
  /// In en, this message translates to:
  /// **'from Health'**
  String get sourceHealth;

  /// No description provided for @sourceBasket.
  ///
  /// In en, this message translates to:
  /// **'from the basket'**
  String get sourceBasket;

  /// No description provided for @sourceManual.
  ///
  /// In en, this message translates to:
  /// **'manual'**
  String get sourceManual;

  /// No description provided for @tagEveryMonth.
  ///
  /// In en, this message translates to:
  /// **'every month'**
  String get tagEveryMonth;

  /// No description provided for @tagEveryYear.
  ///
  /// In en, this message translates to:
  /// **'every year'**
  String get tagEveryYear;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryLitter.
  ///
  /// In en, this message translates to:
  /// **'Litter and consumables'**
  String get categoryLitter;

  /// No description provided for @categoryVet.
  ///
  /// In en, this message translates to:
  /// **'Vet and medicines'**
  String get categoryVet;

  /// No description provided for @categoryEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get categoryEquipment;

  /// No description provided for @categoryServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get categoryServices;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @newExpense.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get newExpense;

  /// No description provided for @editExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get editExpense;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount, like 120'**
  String get amountInvalid;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @forLabel.
  ///
  /// In en, this message translates to:
  /// **'For'**
  String get forLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteLabel;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'What was it? (optional)'**
  String get noteHint;

  /// No description provided for @howOften.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get howOften;

  /// No description provided for @once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @everyYear.
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get everyYear;

  /// No description provided for @monthlyNote.
  ///
  /// In en, this message translates to:
  /// **'Entered once: it counts again every month from this date, until it is stopped.'**
  String get monthlyNote;

  /// No description provided for @yearlyNote.
  ///
  /// In en, this message translates to:
  /// **'Counts in this month every year. In the monthly average it counts as 1/12 a month.'**
  String get yearlyNote;

  /// No description provided for @stopRepeating.
  ///
  /// In en, this message translates to:
  /// **'Stop repeating'**
  String get stopRepeating;

  /// No description provided for @keepRepeating.
  ///
  /// In en, this message translates to:
  /// **'Repeat again'**
  String get keepRepeating;

  /// No description provided for @stoppedOn.
  ///
  /// In en, this message translates to:
  /// **'Stopped on {date}'**
  String stoppedOn(String date);

  /// No description provided for @deleteExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get deleteExpenseTitle;

  /// No description provided for @deleteExpenseBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the budget. This cannot be undone.'**
  String get deleteExpenseBody;

  /// No description provided for @deleteRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'Every month it counted in will lose it. To keep the past months, stop it from repeating instead.'**
  String get deleteRecurringBody;

  /// No description provided for @expenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get expenseSaved;

  /// No description provided for @expenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted'**
  String get expenseDeleted;

  /// First half of the Store's switch: the deals.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get deals;

  /// Second half of the Store's switch: the products the owner rebuys.
  ///
  /// In en, this message translates to:
  /// **'My basket'**
  String get myBasket;

  /// No description provided for @basketEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your basket yet'**
  String get basketEmptyTitle;

  /// No description provided for @basketEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the food, litter and other things you buy again and again, and see when each one runs out.'**
  String get basketEmptyMessage;

  /// Button with a plus: adds a product to the basket.
  ///
  /// In en, this message translates to:
  /// **'Regular product'**
  String get regularProduct;

  /// No description provided for @boughtAgain.
  ///
  /// In en, this message translates to:
  /// **'Bought again'**
  String get boughtAgain;

  /// No description provided for @boughtOn.
  ///
  /// In en, this message translates to:
  /// **'bought {date}'**
  String boughtOn(String date);

  /// No description provided for @runsOutOn.
  ///
  /// In en, this message translates to:
  /// **'runs out {date}'**
  String runsOutOn(String date);

  /// No description provided for @ranOutOn.
  ///
  /// In en, this message translates to:
  /// **'ran out {date}'**
  String ranOutOn(String date);

  /// No description provided for @byFeeding.
  ///
  /// In en, this message translates to:
  /// **'by {grams} g a day from feeding'**
  String byFeeding(String grams);

  /// No description provided for @notBoughtYet.
  ///
  /// In en, this message translates to:
  /// **'Not bought yet'**
  String get notBoughtYet;

  /// No description provided for @dealsOnFood.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 deal on food for {animals}} other{{count} deals on food for {animals}}}'**
  String dealsOnFood(int count, String animals);

  /// No description provided for @dealsOnLitter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 deal on litter and cleaning for {animals}} other{{count} deals on litter and cleaning for {animals}}}'**
  String dealsOnLitter(int count, String animals);

  /// No description provided for @runsOutIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{runs out today} =1{runs out tomorrow} other{runs out in {count} days}}'**
  String runsOutIn(int count);

  /// No description provided for @ranOut.
  ///
  /// In en, this message translates to:
  /// **'ran out'**
  String get ranOut;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is running low'**
  String reminderTitle(String name);

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{name} for {pet} runs out tomorrow ({date}).} other{{name} for {pet} runs out in {count} days ({date}).}}'**
  String reminderBody(int count, String name, String pet, String date);

  /// No description provided for @newProduct.
  ///
  /// In en, this message translates to:
  /// **'New regular product'**
  String get newProduct;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productName;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'Adult dry food'**
  String get productNameHint;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the product\'s name'**
  String get nameRequired;

  /// No description provided for @kindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kindLabel;

  /// No description provided for @kindFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get kindFood;

  /// No description provided for @kindLitter.
  ///
  /// In en, this message translates to:
  /// **'Litter'**
  String get kindLitter;

  /// No description provided for @kindConsumable.
  ///
  /// In en, this message translates to:
  /// **'Consumable'**
  String get kindConsumable;

  /// No description provided for @kindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get kindOther;

  /// No description provided for @packageSize.
  ///
  /// In en, this message translates to:
  /// **'Package size'**
  String get packageSize;

  /// No description provided for @sizeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a size, like 12'**
  String get sizeInvalid;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get unitL;

  /// No description provided for @unitUnits.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get unitUnits;

  /// No description provided for @lastPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get lastPrice;

  /// No description provided for @boughtOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Bought on'**
  String get boughtOnLabel;

  /// No description provided for @lastsLabel.
  ///
  /// In en, this message translates to:
  /// **'How long a package lasts'**
  String get lastsLabel;

  /// No description provided for @lastsByFeedingChoice.
  ///
  /// In en, this message translates to:
  /// **'By the feeding'**
  String get lastsByFeedingChoice;

  /// No description provided for @lastsOwnChoice.
  ///
  /// In en, this message translates to:
  /// **'My own'**
  String get lastsOwnChoice;

  /// No description provided for @lastsByFeeding.
  ///
  /// In en, this message translates to:
  /// **'About {days} days, by {grams} g a day from feeding.'**
  String lastsByFeeding(String days, String grams);

  /// No description provided for @lastsNoFeeding.
  ///
  /// In en, this message translates to:
  /// **'Add the portion and the meal times on the feeding page, or the size in kg or g, to work it out from the feeding.'**
  String get lastsNoFeeding;

  /// No description provided for @lastsAbout.
  ///
  /// In en, this message translates to:
  /// **'Lasts about'**
  String get lastsAbout;

  /// No description provided for @lastsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, like 30'**
  String get lastsInvalid;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @weeks.
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get weeks;

  /// No description provided for @lastsOptional.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty if you are not sure: there is just no run-out date.'**
  String get lastsOptional;

  /// No description provided for @deleteProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this product?'**
  String get deleteProductTitle;

  /// No description provided for @deleteProductBody.
  ///
  /// In en, this message translates to:
  /// **'Its past purchases stay in the budget.'**
  String get deleteProductBody;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product removed'**
  String get productDeleted;

  /// No description provided for @boughtAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Bought again: {name}'**
  String boughtAgainTitle(String name);

  /// No description provided for @boughtAgainNote.
  ///
  /// In en, this message translates to:
  /// **'Saved as an expense in the budget.'**
  String get boughtAgainNote;

  /// No description provided for @addedToBudget.
  ///
  /// In en, this message translates to:
  /// **'{amount} added to the budget'**
  String addedToBudget(String amount);

  /// No description provided for @spendingTitle.
  ///
  /// In en, this message translates to:
  /// **'This month\'s spending'**
  String get spendingTitle;

  /// No description provided for @openBudget.
  ///
  /// In en, this message translates to:
  /// **'Open the budget'**
  String get openBudget;

  /// No description provided for @runningLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get runningLowTitle;

  /// No description provided for @openBasket.
  ///
  /// In en, this message translates to:
  /// **'Open my basket'**
  String get openBasket;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get errorSessionEnded;

  /// No description provided for @errorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'That is not allowed. Please sign in again.'**
  String get errorNotAllowed;

  /// No description provided for @errorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Please check them.'**
  String get errorInvalid;

  /// No description provided for @errorPetNotStored.
  ///
  /// In en, this message translates to:
  /// **'This pet is not saved to your account yet, so nothing can be stored for it.'**
  String get errorPetNotStored;

  /// No description provided for @errorGone.
  ///
  /// In en, this message translates to:
  /// **'That item no longer exists.'**
  String get errorGone;

  /// No description provided for @errorNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'The budget is not set up on the server yet.'**
  String get errorNeedsUpdate;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;
}

class _BudgetL10nDelegate extends LocalizationsDelegate<BudgetL10n> {
  const _BudgetL10nDelegate();

  @override
  Future<BudgetL10n> load(Locale locale) {
    return SynchronousFuture<BudgetL10n>(lookupBudgetL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_BudgetL10nDelegate old) => false;
}

BudgetL10n lookupBudgetL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return BudgetL10nEn();
    case 'he':
      return BudgetL10nHe();
  }

  throw FlutterError(
    'BudgetL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
