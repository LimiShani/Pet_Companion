import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/settings_store.dart';
import 'notification_sink.dart';

/// What the owner lets ring on this phone (Settings > Notifications).
///
/// Every reminder kind is on by default, quiet hours are off. The choices
/// belong to the phone, not the account, and live in the [SettingsStore].
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.meals = true,
    this.walks = true,
    this.medicines = true,
    this.appointments = true,
    this.basket = true,
    this.quietHours = false,
  });

  static const defaults = NotificationSettings();

  /// Quiet hours run from 22:00 to 07:00, in minutes since midnight.
  static const quietStart = 22 * 60;
  static const quietEnd = 7 * 60;

  /// The master switch: off, nothing rings.
  final bool enabled;
  final bool meals;
  final bool walks;
  final bool medicines;
  final bool appointments;
  final bool basket;

  /// Meal, walk and basket reminders that fall between 22:00 and 07:00 wait
  /// until 07:00. Medicines and appointments still ring.
  final bool quietHours;

  /// The switch of one kind, ignoring the master switch.
  bool kindOn(NotificationKind kind) => switch (kind) {
    NotificationKind.meal => meals,
    NotificationKind.walk => walks,
    NotificationKind.medicine => medicines,
    NotificationKind.appointment => appointments,
    NotificationKind.basket => basket,
  };

  /// Whether reminders of [kind] ring at all.
  bool allows(NotificationKind kind) => enabled && kindOn(kind);

  /// Whether quiet hours hold [kind] back. Medicines never wait, and an
  /// appointment reminder is about a fixed time, so it never waits either.
  static bool waitsInQuietHours(NotificationKind kind) =>
      kind == NotificationKind.meal ||
      kind == NotificationKind.walk ||
      kind == NotificationKind.basket;

  /// Whether [at] is within quiet hours (22:00 included, 07:00 not).
  static bool isQuiet(DateTime at) {
    final minutes = at.hour * 60 + at.minute;
    return minutes >= quietStart || minutes < quietEnd;
  }

  /// The end of the quiet hours [at] falls in: 07:00 of the next day for a
  /// time from 22:00 on, 07:00 of the same day for a time before 07:00.
  static DateTime quietEndAfter(DateTime at) {
    final minutes = at.hour * 60 + at.minute;
    final day = minutes >= quietStart
        ? DateTime(at.year, at.month, at.day + 1)
        : DateTime(at.year, at.month, at.day);
    return DateTime(
      day.year,
      day.month,
      day.day,
      quietEnd ~/ 60,
      quietEnd % 60,
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? meals,
    bool? walks,
    bool? medicines,
    bool? appointments,
    bool? basket,
    bool? quietHours,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      meals: meals ?? this.meals,
      walks: walks ?? this.walks,
      medicines: medicines ?? this.medicines,
      appointments: appointments ?? this.appointments,
      basket: basket ?? this.basket,
      quietHours: quietHours ?? this.quietHours,
    );
  }

  /// The same settings with the switch of [kind] set to [on].
  NotificationSettings withKind(NotificationKind kind, bool on) =>
      switch (kind) {
        NotificationKind.meal => copyWith(meals: on),
        NotificationKind.walk => copyWith(walks: on),
        NotificationKind.medicine => copyWith(medicines: on),
        NotificationKind.appointment => copyWith(appointments: on),
        NotificationKind.basket => copyWith(basket: on),
      };

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.enabled == enabled &&
      other.meals == meals &&
      other.walks == walks &&
      other.medicines == medicines &&
      other.appointments == appointments &&
      other.basket == basket &&
      other.quietHours == quietHours;

  @override
  int get hashCode => Object.hash(
    enabled,
    meals,
    walks,
    medicines,
    appointments,
    basket,
    quietHours,
  );
}

/// The keys of the notification choices in the [SettingsStore]: `1` or `0`.
const notificationsSettingKey = 'notifications_on';
const quietHoursSettingKey = 'notifications_quiet_hours';
String notificationKindSettingKey(NotificationKind kind) =>
    'notifications_${kind.name}';

/// Set once the owner has been asked for permission to show notifications
/// (the explanation sheet was shown): the app never asks again by itself.
const notificationsAskedSettingKey = 'notifications_asked';

/// The notification choices, remembered on the phone. A change applies at
/// once: the sink listens and re-plans what it had scheduled.
class NotificationSettingsController extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    final store = ref.watch(settingsStoreProvider);
    bool read(String key, bool fallback) => switch (store.read(key)) {
      '1' => true,
      '0' => false,
      _ => fallback,
    };
    const d = NotificationSettings.defaults;
    return NotificationSettings(
      enabled: read(notificationsSettingKey, d.enabled),
      meals: read(notificationKindSettingKey(NotificationKind.meal), d.meals),
      walks: read(notificationKindSettingKey(NotificationKind.walk), d.walks),
      medicines: read(
        notificationKindSettingKey(NotificationKind.medicine),
        d.medicines,
      ),
      appointments: read(
        notificationKindSettingKey(NotificationKind.appointment),
        d.appointments,
      ),
      basket: read(
        notificationKindSettingKey(NotificationKind.basket),
        d.basket,
      ),
      quietHours: read(quietHoursSettingKey, d.quietHours),
    );
  }

  /// Turns every reminder on or off.
  Future<void> setEnabled(bool on) async {
    state = state.copyWith(enabled: on);
    await _save(notificationsSettingKey, on);
  }

  /// Turns the reminders of one kind on or off.
  Future<void> setKind(NotificationKind kind, bool on) async {
    state = state.withKind(kind, on);
    await _save(notificationKindSettingKey(kind), on);
  }

  Future<void> setQuietHours(bool on) async {
    state = state.copyWith(quietHours: on);
    await _save(quietHoursSettingKey, on);
  }

  Future<void> _save(String key, bool on) async {
    try {
      await ref.read(settingsStoreProvider).write(key, on ? '1' : '0');
    } catch (_) {
      // The choice holds for this session; it just is not remembered.
    }
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationSettings>(
      NotificationSettingsController.new,
    );
