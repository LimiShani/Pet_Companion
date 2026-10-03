// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'firstdays_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FirstDaysL10nEn extends FirstDaysL10n {
  FirstDaysL10nEn([String locale = 'en']) : super(locale);

  @override
  String pageTitle(String name) {
    return 'The first 30 days · $name';
  }

  @override
  String arrivedOn(String date) {
    return 'Arrived home $date';
  }

  @override
  String dayOfTotal(String day, String total) {
    return 'Day $day of $total';
  }

  @override
  String doneCount(String count) {
    return '$count done';
  }

  @override
  String get firstWeek => 'First week';

  @override
  String get laterWeeks => 'Weeks 2–4';

  @override
  String get tickedForYou => 'Done in the app';

  @override
  String get markDone => 'Mark as done';

  @override
  String get markNotDone => 'Mark as not done';

  @override
  String get closePath => 'Close the first 30 days';

  @override
  String get closeQuestion => 'Close the first 30 days?';

  @override
  String closeMessage(String name) {
    return 'The card leaves Home. This list stays on $name\'s profile as a summary.';
  }

  @override
  String get closeConfirm => 'Close';

  @override
  String closedOn(String date) {
    return 'Closed on $date';
  }

  @override
  String get overLine => 'The 30 days are over';

  @override
  String get allDoneLine => 'Everything is done. Nice work.';

  @override
  String get summaryNote => 'A look back at the first 30 days.';

  @override
  String get loadFailed => 'Could not load the first 30 days';

  @override
  String notStarted(String name) {
    return 'The first 30 days have not started for $name.';
  }

  @override
  String cardTitle(String name) {
    return 'The first 30 days of $name';
  }

  @override
  String cardDay(String day) {
    return 'Day $day';
  }

  @override
  String cardNext(String task) {
    return 'Next: $task';
  }

  @override
  String get open => 'Open';

  @override
  String get openTapLabel => 'Open the first 30 days';

  @override
  String get arrivedQuestion => 'Just arrived home?';

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String get arrivalDay => 'Arrival day';

  @override
  String get arrivalNote => 'We\'ll make a short checklist for the first 30 days.';

  @override
  String get sectionTitle => 'The first 30 days';

  @override
  String get startPath => 'Start the first 30 days';

  @override
  String get startNote => 'A short checklist for a pet that just arrived home.';

  @override
  String get viewSummary => 'View';

  @override
  String get taskDogBasics => 'Get the basics: a bed, bowls, a lead and food';

  @override
  String get taskDogRestSpot => 'Set up a quiet spot to rest';

  @override
  String get taskFood => 'Keep to the food they know for now, and add it here';

  @override
  String get taskMealTimes => 'Set regular meal times';

  @override
  String get taskWalkTimes => 'Plan regular walk times';

  @override
  String get taskDogNameTag => 'A collar with a name tag and your phone number';

  @override
  String get taskFirstVet => 'Book a first check-up with a vet';

  @override
  String get taskDogGuide => 'Read the guide on the first week at home';

  @override
  String get taskMicrochip => 'Check the microchip and register your details';

  @override
  String get taskVaccines => 'Plan vaccinations with your vet';

  @override
  String get taskDogFirstWalks => 'Short first walks and calm hellos with people and dogs';

  @override
  String get taskDogHouseRules => 'Agree on house rules with everyone at home';

  @override
  String get taskCatBasics => 'Get the basics: a litter box, bowls and food';

  @override
  String get taskCatSafeRoom => 'A quiet room to settle in, with everything close by';

  @override
  String get taskCatGuide => 'Read the guide on a cat\'s first week at home';

  @override
  String get taskCatScratching => 'A scratching post near a favourite spot';

  @override
  String get taskCatExplore => 'Open up the rest of the home, one room at a time';

  @override
  String get taskCatPlay => 'A short play session every day';

  @override
  String get taskOtherHome => 'Set up their home: a cage, tank or corner, with food and water';

  @override
  String get taskOtherQuiet => 'Give them a few quiet days to settle in';

  @override
  String get taskCleaning => 'Plan a cleaning routine for their home';

  @override
  String get taskGuides => 'Have a look at the guides in Community';

  @override
  String get actionDeals => 'Deals';

  @override
  String get actionFood => 'Food';

  @override
  String get actionFeeding => 'Feeding';

  @override
  String get actionActivity => 'Activity';

  @override
  String get actionAddVisit => 'Add visit';

  @override
  String get actionMicrochip => 'Microchip';

  @override
  String get actionSchedule => 'Schedule';

  @override
  String get actionRoutine => 'Routine';

  @override
  String get actionRead => 'Read';

  @override
  String get actionGuides => 'Guides';
}
