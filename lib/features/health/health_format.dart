import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pet.dart';
import 'data/health_models.dart';

/// Formatting shared by every Health screen. Dates follow the home
/// dashboard: `dd.MM.yy` and `HH:mm`.
final _date = DateFormat('dd.MM.yy');
final _time = DateFormat('HH:mm');
final _month = DateFormat('MMMM yyyy');
final _weekdayDate = DateFormat('EEE dd.MM.yy');
final _longDay = DateFormat('EEEE d MMMM');
final _shortDay = DateFormat('EEE d MMMM');
final _monthShort = DateFormat('MMM');
final _yearShort = DateFormat('yy');

String formatDate(DateTime d) => _date.format(d);
String formatTime(DateTime d) => _time.format(d);
String formatDateTime(DateTime d) => '${_date.format(d)} · ${_time.format(d)}';

/// "June 2025": the heading of a month in a timeline.
String formatMonth(DateTime d) => _month.format(d);

/// "Tuesday 10 June".
String formatLongDay(DateTime d) => _longDay.format(d);

/// "Tue 10 June".
String formatShortDay(DateTime d) => _shortDay.format(d);

/// "Mon 09.06.25".
String formatWeekdayDate(DateTime d) => _weekdayDate.format(d);

/// "Jun", and "Mar 26" when [d] is not in [now]'s year.
String formatBadgeMonth(DateTime d, DateTime now) =>
    d.year == now.year ? _monthShort.format(d) : '${_monthShort.format(d)} ${_yearShort.format(d)}';

String formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Today", "Tomorrow", "Yesterday", or "Thu 12.06.25".
String formatRelativeDay(DateTime day, DateTime now) {
  final diff = dateOnly(day).difference(dateOnly(now)).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => _weekdayDate.format(day),
  };
}

/// "23", "23.4": at most [decimals] decimals, none when whole.
String formatNumber(double v, {int decimals = 1}) {
  final fixed = v.toStringAsFixed(decimals);
  if (!fixed.contains('.')) return fixed;
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// "23 kg", or "412 g" for animals weighed in grams.
String formatWeight(double kg, {bool grams = false}) =>
    grams ? '${formatNumber(kg * 1000, decimals: 0)} g' : '${formatNumber(kg)} kg';

/// "0.2 kg down", "0.4 kg up" or "No change" between two weigh-ins.
String formatWeightChange(double fromKg, double toKg, {bool grams = false}) {
  final diff = toKg - fromKg;
  final shown = formatWeight(diff.abs(), grams: grams);
  if (shown.startsWith('0 ')) return 'No change';
  return diff < 0 ? '$shown down' : '$shown up';
}

/// "₪320", "₪89.90": the currency's own symbol, with decimals only when the
/// amount has them. The one place Health turns an amount into text.
String formatMoney(double amount, String currency) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.simpleCurrency(name: currency, decimalDigits: whole ? 0 : null).format(amount);
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

/// "Dog · Mix · 13.6 years": what is known about the pet, nothing invented.
String petLine(Pet pet) => [
  pet.species.label,
  if ((pet.breed ?? '').trim().isNotEmpty) pet.breed!.trim(),
  if (pet.ageYears != null) '${formatNumber(pet.ageYears!)} years',
].join(' · ');

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Short name of an ISO weekday (1 = Monday).
String dayName(int weekday) => _dayNames[weekday - 1];

/// "Every day", "Weekdays", "Weekends" or "Mon, Thu".
String formatDays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  final sorted = days.toList()..sort();
  if (sorted.length == 5 && sorted.every((d) => d <= 5)) return 'Weekdays';
  if (sorted.length == 2 && sorted.first == 6 && sorted.last == 7) return 'Weekends';
  return sorted.map(dayName).join(', ');
}

/// "1.2 MB", "340 KB".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${formatNumber(bytes / (1024 * 1024))} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

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
  CareKind.other => Icons.check_circle_outline_rounded,
};

/// The icon of every emergency entry point in the app. Deliberately not a
/// plus in a circle, which reads as "add".
const emergencyIcon = Icons.emergency_rounded;
