// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'healthplan_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class HealthPlanL10nEn extends HealthPlanL10n {
  HealthPlanL10nEn([String locale = 'en']) : super(locale);

  @override
  String insightShorterWalks(String pet) {
    return '$pet\'s walks were shorter than last month. Worth a word with your vet if it goes on.';
  }

  @override
  String insightWeightUp(String pet, int percent) {
    return '$pet\'s weight went up by about $percent% in the last few weeks. Worth a word with your vet if it goes on.';
  }

  @override
  String insightWeightDown(String pet, int percent) {
    return '$pet\'s weight went down by about $percent% in the last few weeks. Worth a word with your vet if it goes on.';
  }

  @override
  String insightAppetiteLess(String pet, int count) {
    return 'In the last two weeks you noted $count times that $pet ate less than usual. Worth a word with your vet if it goes on.';
  }

  @override
  String get insightSeeWalks => 'See walks';

  @override
  String get insightSeeWeight => 'See weight';

  @override
  String get insightSeeJournal => 'See journal';

  @override
  String get planAddRow => 'Yearly plan';

  @override
  String get planAddRowNote => 'Vaccines and treatments';

  @override
  String planTitle(String pet) {
    return '$pet\'s yearly plan';
  }

  @override
  String get planIntroDog => 'A common plan for dogs in Israel. Your vet may suggest another.';

  @override
  String get planIntroCat => 'A common plan for cats in Israel. Your vet may suggest another.';

  @override
  String get planNoPlan => 'There is no yearly plan for this kind of animal yet.';

  @override
  String get planRequired => 'Required by law';

  @override
  String get planRecommended => 'Recommended';

  @override
  String planFirstDate(String date) {
    return 'First date $date';
  }

  @override
  String get planFirstDateToday => 'First date today';

  @override
  String planLastTime(String date) {
    return 'Last time $date';
  }

  @override
  String planOverdue(String date) {
    return 'Last time $date · due now';
  }

  @override
  String get planNoHistory => 'Nothing on record. Check the vaccination booklet first.';

  @override
  String planFromWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count weeks old',
    );
    return '$_temp0';
  }

  @override
  String planFromMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'From $count months old',
      one: 'From 1 month old',
    );
    return '$_temp0';
  }

  @override
  String planSeriesTwo(int first, int second) {
    return 'Then at $first and $second weeks, then once a year';
  }

  @override
  String planSeriesOne(int weeks) {
    return 'Then at $weeks weeks, then once a year';
  }

  @override
  String get planSeriesLast => 'Then once a year';

  @override
  String planAlreadyPlanned(String date) {
    return 'Already in the schedule for $date';
  }

  @override
  String planEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String get planSources => 'Where this comes from';

  @override
  String planSourcesIntro(String pet) {
    return 'The plan follows these sources. Your vet knows $pet best.';
  }

  @override
  String get planFinePrint => 'Not a substitute for your vet\'s advice.';

  @override
  String planAddDates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count dates to the schedule',
      one: 'Add 1 date to the schedule',
    );
    return '$_temp0';
  }

  @override
  String planAdded(String pet) {
    return 'In $pet\'s schedule';
  }

  @override
  String planAddedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dates were added. When you mark one done, the next one is planned.',
      one: '1 date was added. When you mark it done, the next one is planned.',
    );
    return '$_temp0';
  }

  @override
  String get planAddToCalendar => 'Add to my calendar';

  @override
  String get planCalendarNote => 'Shares a calendar file. PetLoop does not read your calendar.';

  @override
  String get planDone => 'Done';

  @override
  String planInvite(String pet) {
    return 'No vaccinations on record for $pet yet. A yearly plan puts the next dates in the schedule.';
  }

  @override
  String get planInviteAction => 'Plan the year';

  @override
  String planFromPlan(String pet) {
    return 'From $pet\'s yearly plan';
  }
}
