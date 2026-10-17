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
}
