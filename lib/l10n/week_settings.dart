import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_store.dart';

/// How the week is laid out: which day it starts on, and which days are
/// "weekdays" (the rest are the weekend).
///
/// Days are ISO weekday numbers, as in [DateTime.weekday]: Monday is 1 and
/// Sunday is 7.
///
/// The default is the Israeli week in every language: it starts on Sunday
/// and the weekdays are Sunday to Thursday. The owner's own choice is kept
/// in the [SettingsStore] (see [WeekSettingsController]); there is no
/// settings page yet, but day pickers and texts such as "Weekdays" should
/// already read [weekSettingsProvider] instead of assuming a week.
@immutable
class WeekSettings {
  const WeekSettings({required this.firstDay, required this.weekdays});

  /// Sunday first; Sunday to Thursday are the weekdays.
  static const israeli = WeekSettings(
    firstDay: DateTime.sunday,
    weekdays: {DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday},
  );

  /// Monday first; Monday to Friday are the weekdays.
  static const mondayToFriday = WeekSettings(
    firstDay: DateTime.monday,
    weekdays: {DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday},
  );

  static const defaults = israeli;

  /// The day the week starts on (1 to 7).
  final int firstDay;

  /// The days "Weekdays" means.
  final Set<int> weekdays;

  /// The seven days in the order a day picker shows them.
  List<int> get orderedDays => [for (var i = 0; i < 7; i++) (firstDay - 1 + i) % 7 + 1];

  /// The days "Weekends" means: every day that is not a weekday.
  Set<int> get weekend => {
    for (var day = 1; day <= 7; day++)
      if (!weekdays.contains(day)) day,
  };

  bool isEveryDay(Set<int> days) => days.length == 7;

  /// Whether [days] is exactly the weekdays.
  bool isWeekdays(Set<int> days) => weekdays.isNotEmpty && setEquals(days, weekdays);

  /// Whether [days] is exactly the weekend.
  bool isWeekend(Set<int> days) => weekend.isNotEmpty && setEquals(days, weekend);

  /// [days] in this week's order.
  List<int> sorted(Iterable<int> days) {
    final order = orderedDays;
    return days.toList()..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  }

  WeekSettings copyWith({int? firstDay, Set<int>? weekdays}) =>
      WeekSettings(firstDay: firstDay ?? this.firstDay, weekdays: weekdays ?? this.weekdays);

  @override
  bool operator ==(Object other) =>
      other is WeekSettings && other.firstDay == firstDay && setEquals(other.weekdays, weekdays);

  @override
  int get hashCode => Object.hash(firstDay, Object.hashAllUnordered(weekdays));
}

/// The keys of the week layout in the [SettingsStore].
const weekFirstDaySettingKey = 'week_first_day';
const weekWeekdaysSettingKey = 'week_weekdays';

bool _isDay(int? day) => day != null && day >= 1 && day <= 7;

/// The week layout, remembered on the phone. Anything missing or unreadable
/// in the store falls back to [WeekSettings.defaults].
class WeekSettingsController extends Notifier<WeekSettings> {
  @override
  WeekSettings build() {
    final store = ref.watch(settingsStoreProvider);
    final firstDay = int.tryParse(store.read(weekFirstDaySettingKey) ?? '');
    final weekdays = _parseDays(store.read(weekWeekdaysSettingKey));
    return WeekSettings(
      firstDay: _isDay(firstDay) ? firstDay! : WeekSettings.defaults.firstDay,
      weekdays: weekdays ?? WeekSettings.defaults.weekdays,
    );
  }

  static Set<int>? _parseDays(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final days = <int>{};
    for (final part in text.split(',')) {
      final day = int.tryParse(part.trim());
      if (!_isDay(day)) return null;
      days.add(day!);
    }
    // All seven days would leave no weekend: not a layout.
    return days.length == 7 ? null : days;
  }

  /// Starts the week on [day] (1 = Monday ... 7 = Sunday).
  Future<void> setFirstDay(int day) async {
    assert(_isDay(day));
    if (!_isDay(day) || !ref.mounted) return;
    state = state.copyWith(firstDay: day);
    await _save(weekFirstDaySettingKey, '$day');
  }

  /// Makes "Weekdays" mean [days]; the other days become the weekend.
  Future<void> setWeekdays(Set<int> days) async {
    final valid = days.isNotEmpty && days.length < 7 && days.every(_isDay);
    assert(valid);
    if (!valid || !ref.mounted) return;
    state = state.copyWith(weekdays: {...days});
    await _save(weekWeekdaysSettingKey, (days.toList()..sort()).join(','));
  }

  /// Applies a whole layout, e.g. [WeekSettings.israeli].
  Future<void> use(WeekSettings layout) async {
    await setFirstDay(layout.firstDay);
    await setWeekdays(layout.weekdays);
  }

  Future<void> _save(String key, String value) async {
    try {
      await ref.read(settingsStoreProvider).write(key, value);
    } catch (_) {
      // The choice holds for this session; it just is not remembered.
    }
  }
}

final weekSettingsProvider = NotifierProvider<WeekSettingsController, WeekSettings>(WeekSettingsController.new);
