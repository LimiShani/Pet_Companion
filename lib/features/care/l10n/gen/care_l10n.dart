import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'care_l10n_en.dart';
import 'care_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CareL10n
/// returned by `CareL10n.of(context)`.
///
/// Applications need to include `CareL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/care_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CareL10n.localizationsDelegates,
///   supportedLocales: CareL10n.supportedLocales,
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
/// be consistent with the languages listed in the CareL10n.supportedLocales
/// property.
abstract class CareL10n {
  CareL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CareL10n of(BuildContext context) {
    return Localizations.of<CareL10n>(context, CareL10n)!;
  }

  static const LocalizationsDelegate<CareL10n> delegate = _CareL10nDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// Home feeding card button: log a meal now.
  ///
  /// In en, this message translates to:
  /// **'Fed'**
  String get fed;

  /// Home activity card button for a dog.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walkAction;

  /// Home activity card button for any other pet.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playAction;

  /// Under "1/2" on the activity card.
  ///
  /// In en, this message translates to:
  /// **'walks today'**
  String get walksTodayLabel;

  /// Under the count on the activity card of a pet that is not a dog.
  ///
  /// In en, this message translates to:
  /// **'sessions today'**
  String get playTodayLabel;

  /// Under the minutes number on the activity card.
  ///
  /// In en, this message translates to:
  /// **'active minutes'**
  String get minutesLabel;

  /// No description provided for @nextFeedingTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Next feeding · tomorrow {time}'**
  String nextFeedingTomorrow(String time);

  /// No description provided for @nextWalkTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Next walk · tomorrow {time}'**
  String nextWalkTomorrow(String time);

  /// No description provided for @goalMinutesLine.
  ///
  /// In en, this message translates to:
  /// **'Goal: {minutes} min a day'**
  String goalMinutesLine(String minutes);

  /// Home activity card of a dog with no walk times and nothing logged today.
  ///
  /// In en, this message translates to:
  /// **'Add walk times to follow the activity'**
  String get inviteWalkTimes;

  /// Home activity card of a pet that does not go for walks, with nothing logged today.
  ///
  /// In en, this message translates to:
  /// **'Log play to follow the activity'**
  String get invitePlay;

  /// No description provided for @addFoodToCount.
  ///
  /// In en, this message translates to:
  /// **'Add the food to count calories'**
  String get addFoodToCount;

  /// A walk in progress and how long it has run.
  ///
  /// In en, this message translates to:
  /// **'Walking · {time}'**
  String walkRunning(String time);

  /// No description provided for @playRunning.
  ///
  /// In en, this message translates to:
  /// **'Playing · {time}'**
  String playRunning(String time);

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @savedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Saved {minutes} min'**
  String savedMinutes(String minutes);

  /// When a medicine dose is due on the health card.
  ///
  /// In en, this message translates to:
  /// **'Today · {time}'**
  String doseToday(String time);

  /// No description provided for @medicineItem.
  ///
  /// In en, this message translates to:
  /// **'Medicine: {name}'**
  String medicineItem(String name);

  /// No description provided for @openFeeding.
  ///
  /// In en, this message translates to:
  /// **'Open feeding'**
  String get openFeeding;

  /// No description provided for @openActivity.
  ///
  /// In en, this message translates to:
  /// **'Open activity'**
  String get openActivity;

  /// No description provided for @openHealth.
  ///
  /// In en, this message translates to:
  /// **'Open health'**
  String get openHealth;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Tap to try again.'**
  String get loadFailed;

  /// No description provided for @feedingTitle.
  ///
  /// In en, this message translates to:
  /// **'Feeding · {name}'**
  String feedingTitle(String name);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @caloriesOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{eaten} / {goal} cal'**
  String caloriesOfGoal(String eaten, String goal);

  /// No description provided for @caloriesOnly.
  ///
  /// In en, this message translates to:
  /// **'{eaten} cal'**
  String caloriesOnly(String eaten);

  /// No description provided for @mealAmount.
  ///
  /// In en, this message translates to:
  /// **'{grams} g · {calories} cal'**
  String mealAmount(String grams, String calories);

  /// No description provided for @gramsValue.
  ///
  /// In en, this message translates to:
  /// **'{grams} g'**
  String gramsValue(String grams);

  /// A meal the owner marked as not eaten.
  ///
  /// In en, this message translates to:
  /// **'Not eaten'**
  String get mealNotEaten;

  /// No description provided for @mealDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mealDone;

  /// No description provided for @extraMeal.
  ///
  /// In en, this message translates to:
  /// **'Snack or extra meal'**
  String get extraMeal;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @weekGoalLine.
  ///
  /// In en, this message translates to:
  /// **'Goal: {goal} · Average: {average}'**
  String weekGoalLine(String goal, String average);

  /// No description provided for @weekAverageLine.
  ///
  /// In en, this message translates to:
  /// **'Average: {average}'**
  String weekAverageLine(String average);

  /// No description provided for @foodAndPortion.
  ///
  /// In en, this message translates to:
  /// **'Food and portion'**
  String get foodAndPortion;

  /// No description provided for @foodSummary.
  ///
  /// In en, this message translates to:
  /// **'{kcal} cal per 100 g'**
  String foodSummary(String kcal);

  /// No description provided for @portionSummary.
  ///
  /// In en, this message translates to:
  /// **'{grams} g a meal'**
  String portionSummary(String grams);

  /// No description provided for @mealTimes.
  ///
  /// In en, this message translates to:
  /// **'Meal times'**
  String get mealTimes;

  /// No description provided for @noMealTimes.
  ///
  /// In en, this message translates to:
  /// **'No meal times yet'**
  String get noMealTimes;

  /// No description provided for @addMealTime.
  ///
  /// In en, this message translates to:
  /// **'Add a meal time'**
  String get addMealTime;

  /// No description provided for @sameAsSchedule.
  ///
  /// In en, this message translates to:
  /// **'The same times as in Health · Schedule.'**
  String get sameAsSchedule;

  /// No description provided for @noMealsToday.
  ///
  /// In en, this message translates to:
  /// **'No meals today yet'**
  String get noMealsToday;

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove entry'**
  String get removeEntry;

  /// No description provided for @removeEntryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Remove this entry? The time opens again.'**
  String get removeEntryQuestion;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @logMealTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a meal'**
  String get logMealTitle;

  /// No description provided for @whichMeal.
  ///
  /// In en, this message translates to:
  /// **'Which meal'**
  String get whichMeal;

  /// An extra meal or snack nobody planned.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get extra;

  /// No description provided for @howMuch.
  ///
  /// In en, this message translates to:
  /// **'How much'**
  String get howMuch;

  /// No description provided for @wholePortion.
  ///
  /// In en, this message translates to:
  /// **'Whole portion'**
  String get wholePortion;

  /// No description provided for @halfPortion.
  ///
  /// In en, this message translates to:
  /// **'Half'**
  String get halfPortion;

  /// The meal was not eaten.
  ///
  /// In en, this message translates to:
  /// **'Did not eat'**
  String get notEaten;

  /// No description provided for @equalsCalories.
  ///
  /// In en, this message translates to:
  /// **'= {calories} cal'**
  String equalsCalories(String calories);

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Title stored for an extra meal.
  ///
  /// In en, this message translates to:
  /// **'Extra meal'**
  String get mealTitleExtra;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food name'**
  String get foodName;

  /// No description provided for @foodNameHint.
  ///
  /// In en, this message translates to:
  /// **'Dry food'**
  String get foodNameHint;

  /// No description provided for @kcalPer100g.
  ///
  /// In en, this message translates to:
  /// **'Calories per 100 g'**
  String get kcalPer100g;

  /// No description provided for @gramsPerCup.
  ///
  /// In en, this message translates to:
  /// **'Grams in a cup (optional)'**
  String get gramsPerCup;

  /// No description provided for @portion.
  ///
  /// In en, this message translates to:
  /// **'Usual portion per meal (grams)'**
  String get portion;

  /// No description provided for @portionCups.
  ///
  /// In en, this message translates to:
  /// **'{cups} cups'**
  String portionCups(String cups);

  /// No description provided for @dailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get dailyGoal;

  /// No description provided for @goalEstimateNote.
  ///
  /// In en, this message translates to:
  /// **'Worked out from the weight ({kg} kg), the age and neutering. A general estimate: your vet can give an exact goal.'**
  String goalEstimateNote(String kg);

  /// No description provided for @goalNoWeight.
  ///
  /// In en, this message translates to:
  /// **'Add the weight in the profile for an estimate, or set a goal of your own.'**
  String get goalNoWeight;

  /// No description provided for @goalNoSpecies.
  ///
  /// In en, this message translates to:
  /// **'There is no estimate for this kind of animal. Set a goal of your own.'**
  String get goalNoSpecies;

  /// No description provided for @goalByEstimate.
  ///
  /// In en, this message translates to:
  /// **'By the estimate'**
  String get goalByEstimate;

  /// No description provided for @goalOwn.
  ///
  /// In en, this message translates to:
  /// **'My own goal'**
  String get goalOwn;

  /// No description provided for @caloriesADay.
  ///
  /// In en, this message translates to:
  /// **'Calories a day'**
  String get caloriesADay;

  /// No description provided for @foodBagNote.
  ///
  /// In en, this message translates to:
  /// **'The calories are printed on the bag.'**
  String get foodBagNote;

  /// No description provided for @numberRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}'**
  String numberRange(String min, String max);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity · {name}'**
  String activityTitle(String name);

  /// No description provided for @minutesOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{minutes} / {goal} min'**
  String minutesOfGoal(String minutes, String goal);

  /// No description provided for @minutesValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesValue(String minutes);

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @extraWalk.
  ///
  /// In en, this message translates to:
  /// **'Another walk or play'**
  String get extraWalk;

  /// No description provided for @extraPlay.
  ///
  /// In en, this message translates to:
  /// **'Log play'**
  String get extraPlay;

  /// No description provided for @weekMinutes.
  ///
  /// In en, this message translates to:
  /// **'This week (minutes)'**
  String get weekMinutes;

  /// No description provided for @activityGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily activity goal'**
  String get activityGoal;

  /// No description provided for @walkTimes.
  ///
  /// In en, this message translates to:
  /// **'Walk times'**
  String get walkTimes;

  /// No description provided for @noWalkTimes.
  ///
  /// In en, this message translates to:
  /// **'No walk times yet'**
  String get noWalkTimes;

  /// No description provided for @addWalkTime.
  ///
  /// In en, this message translates to:
  /// **'Add a walk time'**
  String get addWalkTime;

  /// No description provided for @noWalksToday.
  ///
  /// In en, this message translates to:
  /// **'No walks today yet'**
  String get noWalksToday;

  /// No description provided for @noPlayToday.
  ///
  /// In en, this message translates to:
  /// **'No play logged today'**
  String get noPlayToday;

  /// No description provided for @goalSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Minutes of activity a day'**
  String get goalSheetTitle;

  /// No description provided for @skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get skipped;

  /// No description provided for @walkTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walkTitle;

  /// No description provided for @playTitle.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playTitle;

  /// No description provided for @startNow.
  ///
  /// In en, this message translates to:
  /// **'Going out now'**
  String get startNow;

  /// No description provided for @startPlayNow.
  ///
  /// In en, this message translates to:
  /// **'Starting to play now'**
  String get startPlayNow;

  /// No description provided for @startNowNote.
  ///
  /// In en, this message translates to:
  /// **'The clock keeps running even when the app is closed. Finish saves the minutes.'**
  String get startNowNote;

  /// No description provided for @logPast.
  ///
  /// In en, this message translates to:
  /// **'Or log one that already happened'**
  String get logPast;

  /// No description provided for @whichWalk.
  ///
  /// In en, this message translates to:
  /// **'Which walk'**
  String get whichWalk;

  /// No description provided for @howLong.
  ///
  /// In en, this message translates to:
  /// **'How long (minutes)'**
  String get howLong;

  /// No description provided for @otherMinutes.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherMinutes;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get activityType;

  /// No description provided for @typeWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get typeWalk;

  /// No description provided for @typePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get typePlay;

  /// No description provided for @typeRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get typeRun;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today · {time}'**
  String todayAt(String time);

  /// No description provided for @cancelWalk.
  ///
  /// In en, this message translates to:
  /// **'Cancel the walk'**
  String get cancelWalk;
}

class _CareL10nDelegate extends LocalizationsDelegate<CareL10n> {
  const _CareL10nDelegate();

  @override
  Future<CareL10n> load(Locale locale) {
    return SynchronousFuture<CareL10n>(lookupCareL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_CareL10nDelegate old) => false;
}

CareL10n lookupCareL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return CareL10nEn();
    case 'he': return CareL10nHe();
  }

  throw FlutterError(
    'CareL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
