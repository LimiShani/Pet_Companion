// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'care_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CareL10nEn extends CareL10n {
  CareL10nEn([String locale = 'en']) : super(locale);

  @override
  String get fed => 'Fed';

  @override
  String get walkAction => 'Walk';

  @override
  String get playAction => 'Play';

  @override
  String get walksTodayLabel => 'walks today';

  @override
  String get playTodayLabel => 'sessions today';

  @override
  String get minutesLabel => 'active minutes';

  @override
  String nextFeedingTomorrow(String time) {
    return 'Next feeding · tomorrow $time';
  }

  @override
  String nextWalkTomorrow(String time) {
    return 'Next walk · tomorrow $time';
  }

  @override
  String goalMinutesLine(String minutes) {
    return 'Goal: $minutes min a day';
  }

  @override
  String get inviteWalkTimes => 'Add walk times to follow the activity';

  @override
  String get invitePlay => 'Log play to follow the activity';

  @override
  String get addFoodToCount => 'Add the food to count calories';

  @override
  String walkRunning(String time) {
    return 'Walking · $time';
  }

  @override
  String playRunning(String time) {
    return 'Playing · $time';
  }

  @override
  String get finish => 'Finish';

  @override
  String savedMinutes(String minutes) {
    return 'Saved $minutes min';
  }

  @override
  String doseToday(String time) {
    return 'Today · $time';
  }

  @override
  String medicineItem(String name) {
    return 'Medicine: $name';
  }

  @override
  String get openFeeding => 'Open feeding';

  @override
  String get openActivity => 'Open activity';

  @override
  String get openHealth => 'Open health';

  @override
  String get loadFailed => 'Could not load. Tap to try again.';

  @override
  String feedingTitle(String name) {
    return 'Feeding · $name';
  }

  @override
  String get today => 'Today';

  @override
  String caloriesOfGoal(String eaten, String goal) {
    return '$eaten / $goal cal';
  }

  @override
  String caloriesOnly(String eaten) {
    return '$eaten cal';
  }

  @override
  String mealAmount(String grams, String calories) {
    return '$grams g · $calories cal';
  }

  @override
  String gramsValue(String grams) {
    return '$grams g';
  }

  @override
  String get mealNotEaten => 'Not eaten';

  @override
  String get mealDone => 'Done';

  @override
  String get extraMeal => 'Snack or extra meal';

  @override
  String get thisWeek => 'This week';

  @override
  String weekGoalLine(String goal, String average) {
    return 'Goal: $goal · Average: $average';
  }

  @override
  String weekAverageLine(String average) {
    return 'Average: $average';
  }

  @override
  String get foodAndPortion => 'Food and portion';

  @override
  String foodSummary(String kcal) {
    return '$kcal cal per 100 g';
  }

  @override
  String portionSummary(String grams) {
    return '$grams g a meal';
  }

  @override
  String get mealTimes => 'Meal times';

  @override
  String get noMealTimes => 'No meal times yet';

  @override
  String get addMealTime => 'Add a meal time';

  @override
  String get sameAsSchedule => 'The same times as in Health · Schedule.';

  @override
  String get noMealsToday => 'No meals today yet';

  @override
  String get removeEntry => 'Remove entry';

  @override
  String get removeEntryQuestion => 'Remove this entry? The time opens again.';

  @override
  String get remove => 'Remove';

  @override
  String get logMealTitle => 'Log a meal';

  @override
  String get whichMeal => 'Which meal';

  @override
  String get extra => 'Extra';

  @override
  String get howMuch => 'How much';

  @override
  String get wholePortion => 'Whole portion';

  @override
  String get halfPortion => 'Half';

  @override
  String get notEaten => 'Did not eat';

  @override
  String equalsCalories(String calories) {
    return '= $calories cal';
  }

  @override
  String get time => 'Time';

  @override
  String get less => 'Less';

  @override
  String get more => 'More';

  @override
  String get mealTitleExtra => 'Extra meal';

  @override
  String get foodName => 'Food name';

  @override
  String get foodNameHint => 'Dry food';

  @override
  String get kcalPer100g => 'Calories per 100 g';

  @override
  String get gramsPerCup => 'Grams in a cup (optional)';

  @override
  String get portion => 'Usual portion per meal (grams)';

  @override
  String portionCups(String cups) {
    return '$cups cups';
  }

  @override
  String get dailyGoal => 'Daily goal';

  @override
  String goalEstimateNote(String kg) {
    return 'Worked out from the weight ($kg kg), the age and neutering. A general estimate: your vet can give an exact goal.';
  }

  @override
  String get goalNoWeight => 'Add the weight in the profile for an estimate, or set a goal of your own.';

  @override
  String get goalNoSpecies => 'There is no estimate for this kind of animal. Set a goal of your own.';

  @override
  String get goalByEstimate => 'By the estimate';

  @override
  String get goalOwn => 'My own goal';

  @override
  String get caloriesADay => 'Calories a day';

  @override
  String get foodBagNote => 'The calories are printed on the bag.';

  @override
  String numberRange(String min, String max) {
    return 'Enter a number from $min to $max';
  }

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String activityTitle(String name) {
    return 'Activity · $name';
  }

  @override
  String minutesOfGoal(String minutes, String goal) {
    return '$minutes / $goal min';
  }

  @override
  String minutesValue(String minutes) {
    return '$minutes min';
  }

  @override
  String get start => 'Start';

  @override
  String get extraWalk => 'Another walk or play';

  @override
  String get extraPlay => 'Log play';

  @override
  String get weekMinutes => 'This week (minutes)';

  @override
  String get activityGoal => 'Daily activity goal';

  @override
  String get walkTimes => 'Walk times';

  @override
  String get noWalkTimes => 'No walk times yet';

  @override
  String get addWalkTime => 'Add a walk time';

  @override
  String get noWalksToday => 'No walks today yet';

  @override
  String get noPlayToday => 'No play logged today';

  @override
  String get goalSheetTitle => 'Minutes of activity a day';

  @override
  String get skipped => 'Skipped';

  @override
  String get walkTitle => 'Walk';

  @override
  String get playTitle => 'Play';

  @override
  String get startNow => 'Going out now';

  @override
  String get startPlayNow => 'Starting to play now';

  @override
  String get startNowNote => 'The clock keeps running even when the app is closed. Finish saves the minutes.';

  @override
  String get logPast => 'Or log one that already happened';

  @override
  String get whichWalk => 'Which walk';

  @override
  String get howLong => 'How long (minutes)';

  @override
  String get otherMinutes => 'Other';

  @override
  String get activityType => 'Type';

  @override
  String get typeWalk => 'Walk';

  @override
  String get typePlay => 'Play';

  @override
  String get typeRun => 'Run';

  @override
  String get when => 'When';

  @override
  String todayAt(String time) {
    return 'Today · $time';
  }

  @override
  String get cancelWalk => 'Cancel the walk';
}
