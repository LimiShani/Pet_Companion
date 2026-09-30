import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../pets/pets.dart';
import 'data/health_models.dart';
import 'health_strings.dart';

/// Dates, numbers, money and short lines as Health shows them, in the
/// language on screen: the numbers from [AppFormat], the words around them
/// from the strings files (Health's, and the Pets feature's words for a
/// pet).
///
/// In a widget: `HealthFormat.of(context)`. In code without a screen (the
/// PDF, the message composed for another app): `ref.read(healthFormatProvider)`.
///
/// Inside right-to-left text, a number, a name or anything typed is kept in
/// one piece with invisible direction marks, so it cannot reorder the line
/// around it. A left-to-right line needs none, so the English texts stay
/// free of them.
@immutable
class HealthFormat {
  const HealthFormat(this.l10n, this.common, this.pets, this.app);

  factory HealthFormat.of(BuildContext context) =>
      HealthFormat(context.healthL10n, context.l10n, context.petsL10n, AppFormat.of(context));

  /// For code and tests without a screen.
  factory HealthFormat.forLocale(Locale locale) => HealthFormat(
    lookupHealthL10n(locale),
    lookupAppL10n(locale),
    lookupPetsL10n(locale),
    AppFormat.forLocale(locale),
  );

  final HealthL10n l10n;

  /// The shared words: Today, Save, Cancel...
  final AppL10n common;

  /// The Pets feature's words: a kind of animal, an age, "kg".
  final PetsL10n pets;
  final AppFormat app;

  bool get isRtl => app.localeName != 'en';

  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  // -------------------------------------------------------------- direction

  /// [text] (a phone number, a microchip number, "+972") ready to sit in a
  /// line of the screen's language: kept left-to-right as one unit on a
  /// right-to-left screen.
  String ltrInLine(String text) => isRtl ? ltr(text) : text;

  /// Something that was typed (a name, a title, a note) ready to sit in a
  /// line of the screen's language: kept as one unit in its own direction
  /// on a right-to-left screen.
  String typed(String text) => isRtl ? isolate(text) : text;

  String _join(Iterable<String> parts, String separator) => [
    for (final part in parts)
      if (part.isNotEmpty) typed(part),
  ].join(separator);

  /// "Dog · Mix · 13.6 years": [parts] as one line of facts. Each part
  /// keeps its own direction, so the line reads in order in both languages.
  String dots(Iterable<String> parts) => _join(parts, ' · ');

  /// "08:00, 20:00": a short list.
  String commas(Iterable<String> parts) => _join(parts, ', ');

  /// "Chicken; Beef": a list whose items may have commas of their own.
  String semicolons(Iterable<String> parts) => _join(parts, '; ');

  // ------------------------------------------------------------------ dates

  /// "12.06.25".
  String date(DateTime d) => app.date(d);

  /// "18:20".
  String time(DateTime d) => app.time(d);

  String timeOfDay(TimeOfDay t) => app.timeOfDay(t);

  /// "12.06.25 · 18:20".
  String dateTime(DateTime d) => app.dateTime(d);

  /// "June 2025": the heading of a month in a timeline.
  String month(DateTime d) => app.monthYear(d);

  /// "Tue, Jun 10".
  String shortDay(DateTime d) => app.shortDay(d);

  /// "Mon 09.06.25".
  String weekdayDate(DateTime d) => l10n.weekdayAndDate(app.weekdayShort(d.weekday), app.date(d));

  /// "Thu 18:20".
  String weekdayTime(DateTime d) => l10n.weekdayAndTime(app.weekdayShort(d.weekday), app.time(d));

  /// "Today", "Tomorrow", "Yesterday", or "Thu 12.06.25".
  String relativeDay(DateTime day, DateTime now) => switch (dateOnly(day).difference(dateOnly(now)).inDays) {
    0 => common.commonToday,
    1 => common.commonTomorrow,
    -1 => common.commonYesterday,
    _ => weekdayDate(day),
  };

  /// "Today · 18:20", "Thu 12.06.25 · 18:20".
  String relativeDayTime(DateTime at, DateTime now) => l10n.dayAndTime(relativeDay(at, now), time(at));

  /// "Jun", and "Mar 26" when [d] is not in [now]'s year: the month on a
  /// date badge.
  String badgeMonth(DateTime d, DateTime now) =>
      DateFormat(d.year == now.year ? 'MMM' : 'MMM yy', _dateLocale).format(d);

  // Month names are loaded with the app's localizations; before that (a
  // plain unit test) the default locale's are used.
  String? get _dateLocale {
    try {
      return DateFormat.localeExists(app.localeName) ? app.localeName : null;
    } catch (_) {
      return null;
    }
  }

  /// "Every day", "Weekdays", "Weekends" or "Mon, Thu", in the owner's
  /// [week]: its first day orders the list, and its weekdays decide what
  /// "Weekdays" and "Weekends" mean.
  String days(Set<int> days, WeekSettings week) {
    if (week.isEveryDay(days)) return l10n.daysEveryDay;
    if (week.isWeekdays(days)) return l10n.daysWeekdays;
    if (week.isWeekend(days)) return l10n.daysWeekends;
    return [for (final day in week.sorted(days)) l10n.dayChip(day)].join(', ');
  }

  // ---------------------------------------------------------------- numbers

  /// "23 kg", or "412 g" for animals weighed in grams.
  String weight(double kg, {bool grams = false}) =>
      grams ? pets.weightG(formatNumber(kg * 1000, decimals: 0)) : pets.weightKg(formatNumber(kg));

  /// The number of [weight] alone: "23", "412".
  String weightNumber(double kg, {bool grams = false}) =>
      grams ? formatNumber(kg * 1000, decimals: 0) : formatNumber(kg);

  /// "kg" or "g".
  String weightUnit({bool grams = false}) => grams ? pets.unitG : pets.unitKg;

  /// "0.2 kg down since 02.05.25", "0.4 kg up since..." or "No change
  /// since..." between two weigh-ins.
  String weightChangeSince(double fromKg, double toKg, DateTime since, {bool grams = false}) {
    final diff = toKg - fromKg;
    final amount = weightNumber(diff.abs(), grams: grams);
    final shown = weight(diff.abs(), grams: grams);
    if (amount == '0') return l10n.weightNoChangeSince(date(since));
    return diff < 0 ? l10n.weightDownSince(shown, date(since)) : l10n.weightUpSince(shown, date(since));
  }

  /// "₪320", "₪89.90" (Hebrew: "320 ₪"): the currency's own sign, with
  /// decimals only when the amount has them. The one place Health turns an
  /// amount into text.
  String money(double amount, String currency) {
    final text = app.money(amount, currency);
    return isRtl ? text : stripBidiMarks(text);
  }

  /// "1.2 MB", "340 KB".
  String fileSize(int bytes) {
    if (bytes >= 1024 * 1024) return l10n.fileSizeMb(formatNumber(bytes / (1024 * 1024)));
    if (bytes >= 1024) return l10n.fileSizeKb('${(bytes / 1024).round()}');
    return l10n.fileSizeBytes('$bytes');
  }

  // ------------------------------------------------------------------ words

  /// "Dog · Mix · 13.6 years": what is known about the pet, nothing
  /// invented, in the Pets feature's words.
  String petLine(Pet pet, {DateTime? now}) => petSummaryLine(pets, pet, now: now);

  /// "1 tablet by mouth, twice a day with food": the vet's instructions as
  /// the owner entered them. Empty when nothing was entered.
  String instructions(Medication medication) {
    final dose = medication.dose.trim();
    final stored = medication.route.trim();
    final route = l10n.medicineRoute(stored);
    final how = dose.isEmpty
        ? route
        : stored.isEmpty
        ? dose
        : l10n.medicineDoseAndRoute(dose, _lowerFirst(route));
    final often = medication.frequency.trim();
    if (how.isEmpty) return often;
    if (often.isEmpty) return how;
    return l10n.medicineHowAndOften(how, _lowerFirst(often));
  }

  /// "Given 08:05", "Not given" or "Not sure", for the dose log.
  String doseStatus(CareLog log) =>
      l10n.doseStatus(log.status, givenAtTime: log.doneAt == null ? null : time(log.doneAt!));

  /// [healthErrorText] in this language.
  String error(Object? error) => healthErrorText(l10n, common, error);
}

String _lowerFirst(String text) => text.isEmpty ? text : '${text[0].toLowerCase()}${text.substring(1)}';

/// [HealthFormat] in the language the app is showing, for code without a
/// `BuildContext`.
final healthFormatProvider = Provider<HealthFormat>((ref) => HealthFormat.forLocale(ref.watch(appLocaleProvider)));

/// "23", "23.4": at most [decimals] decimals, none when whole. The same
/// digits and decimal point in every language (it also fills number fields).
String formatNumber(double v, {int decimals = 1}) {
  final fixed = v.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The symbol shown beside an amount field ("₪" for ILS).
String currencySymbol(String currency) => NumberFormat.simpleCurrency(name: currency).currencySymbol;

/// The amount typed into a cost field, or `null` when it is not an amount.
/// A comma is accepted as the decimal mark.
double? parseMoney(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || value.isNaN || value < 0 || value > maxMoney) return null;
  return (value * 100).round() / 100;
}

/// The largest amount a cost column holds.
const maxMoney = 99999999.99;

IconData recordKindIcon(RecordKind kind) => switch (kind) {
  RecordKind.checkup => Icons.medical_services_rounded,
  RecordKind.vaccination => Icons.vaccines_rounded,
  RecordKind.preventive => Icons.shield_rounded,
  RecordKind.procedure => Icons.healing_rounded,
  RecordKind.medicine => Icons.medication_rounded,
  RecordKind.document => Icons.description_rounded,
  RecordKind.other => Icons.sticky_note_2_rounded,
};

IconData careKindIcon(CareKind kind) => switch (kind) {
  CareKind.medication => Icons.medication_rounded,
  CareKind.feeding => Icons.restaurant_rounded,
  CareKind.walk => Icons.directions_walk_rounded,
  CareKind.grooming => Icons.brush_rounded,
  CareKind.cleaning => Icons.cleaning_services_rounded,
  CareKind.litterCleaning => Icons.inbox_rounded,
  CareKind.litterChange => Icons.autorenew_rounded,
  CareKind.cageCleaning => Icons.cleaning_services_rounded,
  CareKind.other => Icons.check_circle_outline_rounded,
};

/// Whether [icon] points somewhere (a figure walking forward) and so is
/// mirrored on a right-to-left screen. Flutter mirrors arrows and chevrons
/// by itself; this is for the ones it leaves alone.
bool iconPointsForward(IconData icon) => icon == Icons.directions_walk_rounded;

/// The icon of every emergency entry point in the app. Deliberately not a
/// plus in a circle, which reads as "add".
const emergencyIcon = Icons.emergency_rounded;
