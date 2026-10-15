// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'today_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class TodayL10nEn extends TodayL10n {
  TodayL10nEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Today';

  @override
  String headerDone(String day, int done, int total) {
    return '$day · $done of $total done';
  }

  @override
  String withPet(String title, String pet) {
    return '$title · $pet';
  }

  @override
  String get you => 'you';

  @override
  String doneBy(String time, String who) {
    return '$time · $who';
  }

  @override
  String notDoneBy(String time, String who) {
    return '$time · $who · not done';
  }

  @override
  String notDoneAt(String time) {
    return '$time · not done';
  }

  @override
  String runsOutIn(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name runs out in $count days',
      one: '$name runs out tomorrow',
      zero: '$name runs out today',
    );
    return '$_temp0';
  }

  @override
  String ranOut(String name) {
    return '$name ran out';
  }

  @override
  String firstDaysLine(String day) {
    return 'First 30 days · day $day';
  }

  @override
  String foldDone(int count) {
    return '$count done';
  }

  @override
  String get showDone => 'Show what is done';

  @override
  String get hideDone => 'Hide what is done';

  @override
  String markDone(String title) {
    return 'Mark $title as done';
  }

  @override
  String undoDone(String title) {
    return 'Undo $title';
  }

  @override
  String doneSemantics(String title) {
    return '$title, done';
  }

  @override
  String get empty => 'Nothing planned today.';

  @override
  String get setUpFeeding => 'Set up feeding';

  @override
  String get loadFailed => 'Could not load today\'s list. Tap to try again.';
}
