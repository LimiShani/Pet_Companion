// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'today_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class TodayL10nHe extends TodayL10n {
  TodayL10nHe([String locale = 'he']) : super(locale);

  @override
  String get title => 'היום';

  @override
  String headerDone(String day, int done, int total) {
    return '\u2068$day\u2069 · $done מתוך $total בוצעו';
  }

  @override
  String withPet(String title, String pet) {
    return '\u2068$title\u2069 · \u2068$pet\u2069';
  }

  @override
  String get you => 'אני';

  @override
  String doneBy(String time, String who) {
    return '\u2068$time\u2069 · \u2068$who\u2069';
  }

  @override
  String notDoneBy(String time, String who) {
    return '\u2068$time\u2069 · \u2068$who\u2069 · לא בוצע';
  }

  @override
  String notDoneAt(String time) {
    return '\u2068$time\u2069 · לא בוצע';
  }

  @override
  String runsOutIn(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'המלאי של \u2068$name\u2069 ייגמר בעוד $count ימים',
      two: 'המלאי של \u2068$name\u2069 ייגמר בעוד יומיים',
      one: 'המלאי של \u2068$name\u2069 ייגמר מחר',
      zero: 'המלאי של \u2068$name\u2069 נגמר היום',
    );
    return '$_temp0';
  }

  @override
  String ranOut(String name) {
    return 'המלאי של \u2068$name\u2069 נגמר';
  }

  @override
  String firstDaysLine(String day) {
    return '30 הימים הראשונים · יום \u2068$day\u2069';
  }

  @override
  String foldDone(int count) {
    return '$count בוצעו';
  }

  @override
  String get showDone => 'הצגת מה שבוצע';

  @override
  String get hideDone => 'הסתרת מה שבוצע';

  @override
  String markDone(String title) {
    return 'סימון \u2068$title\u2069 כבוצע';
  }

  @override
  String undoDone(String title) {
    return 'ביטול הסימון של \u2068$title\u2069';
  }

  @override
  String doneSemantics(String title) {
    return '\u2068$title\u2069, בוצע';
  }

  @override
  String get empty => 'אין שום דבר מתוכנן להיום.';

  @override
  String get setUpFeeding => 'הגדרת האכלה';

  @override
  String get loadFailed => 'לא הצלחנו לטעון את הרשימה של היום. אפשר להקיש כדי לנסות שוב.';
}
