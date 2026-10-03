import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbols.dart';
import 'package:intl/intl.dart';

import 'app_language.dart';
import 'bidi.dart';

/// Dates, times and numbers as the app shows them, in the app's language.
///
/// The numeric forms are the same in every language: `dd.MM.yy` and
/// 24-hour times. Names of months and days follow the language ("Tuesday,
/// 10 June" / "יום שלישי, 10 ביוני"), built from the language's own
/// patterns rather than by gluing words together.
///
/// In a widget: `AppFormat.of(context)`. In code without a screen (a PDF,
/// a message, a notification): `ref.watch(appFormatProvider)`.
@immutable
class AppFormat {
  const AppFormat(this.localeName);

  factory AppFormat.forLocale(Locale locale) => AppFormat(isHebrew(locale) ? 'he' : 'en');

  static AppFormat of(BuildContext context) =>
      AppFormat.forLocale(Localizations.maybeLocaleOf(context) ?? englishLocale);

  /// `en` or `he`.
  final String localeName;

  // Month and day names are loaded together with the app's localizations.
  // Before that (very early, or in a plain unit test) the numeric patterns
  // still work, in the default locale.
  String? get _dateLocale {
    try {
      return DateFormat.localeExists(localeName) ? localeName : null;
    } catch (_) {
      // intl throws, instead of answering "no", while nothing is loaded.
      return null;
    }
  }

  DateFormat _pattern(String pattern) => DateFormat(pattern, _dateLocale);

  /// "12.06.25".
  String date(DateTime d) => _pattern('dd.MM.yy').format(d);

  /// "18:20".
  String time(DateTime d) => _pattern('HH:mm').format(d);

  /// "18:20" for a time of day.
  String timeOfDay(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// "12.06.25 · 18:20". In a right-to-left line it reads date first too.
  String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  /// "01:32": hours and minutes of a length of time.
  String hoursMinutes(Duration d) => '${_two(d.inHours)}:${_two(d.inMinutes.remainder(60))}';

  /// "June 2025" / "יוני 2025".
  String monthYear(DateTime d) => DateFormat.yMMMM(_dateLocale).format(d);

  /// "June" / "יוני".
  String month(DateTime d) => DateFormat.MMMM(_dateLocale).format(d);

  /// "07.10": a day and month, for short lines where the year is plain.
  String dayMonth(DateTime d) => _pattern('dd.MM').format(d);

  /// "Tuesday, June 10" / "יום שלישי, 10 ביוני".
  String longDay(DateTime d) => DateFormat.MMMMEEEEd(_dateLocale).format(d);

  /// "Tue, Jun 10" / "יום ג׳, 10 ביוני".
  String shortDay(DateTime d) => DateFormat.MMMEd(_dateLocale).format(d);

  /// The short name of an ISO weekday (1 = Monday ... 7 = Sunday): "Mon" /
  /// "יום ב׳".
  String weekdayShort(int weekday) => _symbols.STANDALONESHORTWEEKDAYS[weekday % 7];

  /// The one-letter name of an ISO weekday, for day chips: "M" / "ב׳".
  String weekdayNarrow(int weekday) => _symbols.STANDALONENARROWWEEKDAYS[weekday % 7];

  DateSymbols get _symbols => _pattern('E').dateSymbols;

  /// "2,569".
  String integer(int value) => NumberFormat.decimalPattern(localeName).format(value);

  /// "23", "23.4": at most [decimals] decimals, none when whole.
  String decimal(double value, {int decimals = 1}) {
    final format = NumberFormat.decimalPattern(localeName)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimals;
    return format.format(value);
  }

  /// A price in the language's own form, with decimals only when the
  /// amount has them: "₪179" in English, "179 ₪" in Hebrew. Kept as one
  /// unit, so it cannot be reordered by the line it sits in.
  String money(double amount, String currency) {
    final whole = amount == amount.roundToDouble();
    final format = NumberFormat.simpleCurrency(locale: localeName, name: currency, decimalDigits: whole ? 0 : null);
    return isolate(format.format(amount));
  }

  /// "-40%" / "40%": a percentage that keeps its sign in front in every
  /// direction.
  String percent(int value) => ltr('$value%');

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  bool operator ==(Object other) => other is AppFormat && other.localeName == localeName;

  @override
  int get hashCode => localeName.hashCode;
}

/// [AppFormat] in the language the app is showing, for code without a
/// `BuildContext`.
final appFormatProvider = Provider<AppFormat>((ref) => AppFormat.forLocale(ref.watch(appLocaleProvider)));
