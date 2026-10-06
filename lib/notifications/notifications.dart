/// Real phone notifications: the reminders of Health (meals, walks,
/// medicines, appointments) and of any feature that hands a
/// [NotificationSink] its own group.
///
/// The pieces:
/// - [NotificationPlatform]: the phone (`flutter_local_notifications`), or
///   a fake in tests. [notificationPlatformProvider] is `null` unless
///   `main.dart` sets it, so tests and the web run without notifications.
/// - [LocalNotificationSink]: applies the owner's choices
///   ([notificationSettingsProvider]) and schedules what should ring.
/// - [NotificationReminderScheduler]: turns each pet's `ReminderPlan`
///   into reminders.
/// - [ReminderCoordinator]: loads every pet's plan at sign-in, so all pets
///   ring and not only the one on screen, and cancels everything at
///   sign-out.
/// - `NotificationsHost` (the widget): asks for permission once, and opens
///   the right page when a reminder is tapped.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../services/budget/state/budget_providers.dart' show basketProvider;
import '../services/pet_records/data/health_models.dart';
import '../services/pet_records/data/reminder_scheduler.dart';
import '../services/pet_records/state/health_providers.dart';
import '../services/pet_records/state/schedule_logic.dart';
import '../l10n/l10n.dart';
import '../models/pet.dart';
import '../state/pets_provider.dart';
import 'local_notification_sink.dart';
import 'notification_platform.dart';
import 'notification_reminder_scheduler.dart';
import 'notification_settings.dart';
import 'notification_sink.dart';
import 'reminder_planner.dart';

export 'local_notification_sink.dart';
export 'notification_platform.dart';
export 'notification_reminder_scheduler.dart';
export 'notification_settings.dart';
export 'notification_sink.dart';
export 'reminder_planner.dart';

/// The phone's notifications; `null` when the app runs without them (the
/// default: tests, the web).
final notificationPlatformProvider = Provider<NotificationPlatform?>(
  (ref) => null,
);

/// Whether the signed-in account has anything that would ring (a routine,
/// a medicine time, a planned record, a basket reminder). The permission
/// is asked for the first time this turns true.
class SomethingToRemind extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    return false;
  }

  void found() {
    if (!state) state = true;
  }
}

final somethingToRemindProvider = NotifierProvider<SomethingToRemind, bool>(
  SomethingToRemind.new,
);

/// Whether the phone lets PetLoop show notifications and ring exactly;
/// `null` without a [NotificationPlatform]. Checked again with [refresh]
/// whenever the app comes back to the screen (the owner may have changed
/// it in the phone's settings).
class NotificationAccessController extends AsyncNotifier<NotificationAccess?> {
  @override
  Future<NotificationAccess?> build() async =>
      ref.watch(notificationPlatformProvider)?.access();

  Future<void> refresh() async {
    final platform = ref.read(notificationPlatformProvider);
    if (platform == null) return;
    try {
      final access = await platform.access();
      if (ref.mounted) state = AsyncData(access);
    } catch (_) {
      // Keep what was known.
    }
  }

  /// Shows the phone's permission prompt. When it cannot be shown any more
  /// (the owner said no before), opens the phone's settings instead.
  Future<void> allowNotifications() async {
    final platform = ref.read(notificationPlatformProvider);
    if (platform == null) return;
    final allowed = await platform.requestPermission();
    if (!allowed) await platform.openSettings();
    await refresh();
  }

  /// Opens Android's "Alarms & reminders" for PetLoop.
  Future<void> allowExact() async {
    await ref.read(notificationPlatformProvider)?.requestExactAlarms();
    await refresh();
  }

  Future<void> openSettings() async {
    await ref.read(notificationPlatformProvider)?.openSettings();
    await refresh();
  }
}

final notificationAccessProvider =
    AsyncNotifierProvider<NotificationAccessController, NotificationAccess?>(
      NotificationAccessController.new,
    );

/// A tapped reminder's target (e.g. `feeding:<petId>`) until the app has
/// opened it; see `NotificationsHost`.
class NotificationTaps extends Notifier<String?> {
  @override
  String? build() => null;

  void tapped(String target) => state = target;

  /// The waiting target, which is then no longer waiting.
  String? take() {
    final target = state;
    state = null;
    return target;
  }
}

final notificationTapsProvider = NotifierProvider<NotificationTaps, String?>(
  NotificationTaps.new,
);

/// The phone's names of the reminder kinds, and the snooze label, in the
/// app's language.
NotificationChrome notificationChromeOf(NotificationsL10n l10n) =>
    NotificationChrome(
      channelNames: {
        NotificationKind.meal: l10n.meals,
        NotificationKind.walk: l10n.walks,
        NotificationKind.medicine: l10n.medicines,
        NotificationKind.appointment: l10n.appointments,
        NotificationKind.basket: l10n.basket,
      },
      snoozeLabel: l10n.snooze,
    );

/// Builds the real sink; `main.dart` overrides [notificationSinkProvider]
/// with it. Without a platform it is the do-nothing sink.
NotificationSink localNotificationSink(Ref ref) {
  final platform = ref.watch(notificationPlatformProvider);
  if (platform == null) return const NoopNotificationSink();
  final chrome = notificationChromeOf(ref.read(notificationsL10nProvider));
  final sink = LocalNotificationSink(
    platform,
    settings: ref.read(notificationSettingsProvider),
    exact: ref.read(notificationAccessProvider).value?.exact ?? false,
    chrome: chrome,
    // Never during a build: a plan can arrive while a provider is built.
    onSomethingToRemind: () => Future.microtask(() {
      if (ref.mounted) ref.read(somethingToRemindProvider.notifier).found();
    }),
  );
  _nameChannels(platform, chrome);
  ref.listen(
    notificationSettingsProvider,
    (_, settings) => sink.settings = settings,
  );
  ref.listen(notificationAccessProvider, (_, access) {
    if (access.hasValue) sink.exact = access.value?.exact ?? false;
  });
  ref.listen(notificationsL10nProvider, (_, l10n) {
    sink.chrome = notificationChromeOf(l10n);
    _nameChannels(platform, sink.chrome);
  });
  return sink;
}

void _nameChannels(NotificationPlatform platform, NotificationChrome chrome) {
  platform.nameChannels(chrome.channelNames).catchError((Object error) {
    debugPrint('PetLoop: could not name the notification channels: $error');
  });
}

/// Builds the real scheduler; `main.dart` overrides
/// [reminderSchedulerProvider] with it.
ReminderScheduler notificationReminderScheduler(Ref ref) {
  final scheduler = NotificationReminderScheduler(
    sink: ref.watch(notificationSinkProvider),
    strings: () => ref.read(notificationsL10nProvider),
    ringsFor: (petId) =>
        ref.read(authControllerProvider).value != null &&
        ref.read(petsProvider).any((pet) => pet.id == petId),
  );
  ref.listen(notificationsL10nProvider, (_, _) => scheduler.replanAll());
  return scheduler;
}

/// Keeps every pet's reminders scheduled, not only those of the pet on
/// screen.
///
/// Health syncs a pet's plan whenever it is loaded or changes, but a pet's
/// plan is only loaded while one of its screens is open. So once the owner
/// is signed in and the pets are loaded, this loads each pet's care plan
/// and records once (and again for a pet that is added or renamed, and
/// when the app comes back after an hour or on another day: the week ahead
/// keeps moving) and hands them to the scheduler. The providers are only
/// held while loading; Health disposes them as usual afterwards.
///
/// A pet that is removed or archived stops ringing. Signing out cancels
/// every reminder on the phone; reminders survive a restart of the app.
class ReminderCoordinator {
  ReminderCoordinator(this._container, {DateTime Function() now = DateTime.now})
    : _now = now;

  final ProviderContainer _container;
  final DateTime Function() _now;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  String? _userId;

  /// The pets loaded for [_userId], by id, with the name they were loaded
  /// with.
  Map<String, String> _loaded = {};
  DateTime? _loadedAt;
  bool _disposed = false;

  /// Loads in progress, so a pet is not loaded twice at once.
  final _loading = <String, Future<void>>{};

  /// Every load since the start, finished or not (for tests).
  @visibleForTesting
  Future<void> get idle => Future.wait([..._loading.values]);

  void start() {
    _subscriptions
      ..add(_container.listen(authControllerProvider, (_, _) => _update()))
      ..add(_container.listen(petsGateProvider, (_, _) => _update()))
      ..add(_container.listen(petsProvider, (_, _) => _update()));
    _update();
  }

  void dispose() {
    _disposed = true;
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
  }

  /// The app is on the screen again: loads every pet again when the last
  /// load is more than an hour old or of another day.
  void resumed() {
    final at = _loadedAt;
    final now = _now();
    if (_userId == null || at == null) return;
    if (now.difference(at) < const Duration(hours: 1) && isSameDay(at, now)) {
      return;
    }
    _loaded = {};
    _update();
  }

  void _update() {
    if (_disposed) return;
    final auth = _container.read(authControllerProvider);
    // Restoring the session, signing in or out, or a failed attempt: wait.
    if (auth.isLoading || auth.hasError) return;
    final user = auth.value;
    if (user == null) {
      if (_userId != null) _signedOut();
      return;
    }
    if (user.id != _userId) {
      _userId = user.id;
      _loaded = {};
    }
    if (_container.read(petsGateProvider) != PetsGate.ready) return;

    final pets = {
      for (final Pet pet in _container.read(petsProvider)) pet.id: pet.name,
    };
    final scheduler = _scheduler;
    for (final id
        in _loaded.keys.where((id) => !pets.containsKey(id)).toList()) {
      _loaded.remove(id);
      scheduler?.forget(id);
    }
    final sink = _sink;
    final firstLoad = _loadedAt == null || _loaded.isEmpty;
    for (final MapEntry(key: id, value: name) in pets.entries) {
      if (_loaded[id] == name) continue;
      _loaded[id] = name;
      _load(id, name);
    }
    if (firstLoad) {
      _loadedAt = _now();
      // Reminders of pets that are gone (scheduled before the app started).
      sink?.retainGroups('health:', {
        for (final id in pets.keys) healthGroupOf(id),
      });
    }
  }

  void _signedOut() {
    _userId = null;
    _loaded = {};
    _loadedAt = null;
    _scheduler?.clear();
    final sink = _container.read(notificationSinkProvider);
    if (sink is LocalNotificationSink) sink.cancelAll();
  }

  NotificationReminderScheduler? get _scheduler {
    final scheduler = _container.read(reminderSchedulerProvider);
    return scheduler is NotificationReminderScheduler ? scheduler : null;
  }

  LocalNotificationSink? get _sink {
    final sink = _container.read(notificationSinkProvider);
    return sink is LocalNotificationSink ? sink : null;
  }

  void _load(String petId, String petName) {
    final previous = _loading[petId] ?? Future<void>.value();
    final load = previous.then((_) => _loadOnce(petId, petName));
    _loading[petId] = load;
    load.whenComplete(() {
      if (identical(_loading[petId], load)) _loading.remove(petId);
    });
  }

  Future<void> _loadOnce(String petId, String petName) async {
    final userId = _userId;
    final plan = _container.listen(
      carePlanProvider(petId),
      (_, _) {},
      onError: (_, _) {},
    );
    final records = _container.listen(
      healthRecordsProvider(petId),
      (_, _) {},
      onError: (_, _) {},
    );
    try {
      final results = await Future.wait([
        _container
            .read(carePlanProvider(petId).future)
            .then<Object?>((value) => value, onError: (_) => null),
        _container
            .read(healthRecordsProvider(petId).future)
            .then<Object?>((value) => value, onError: (_) => null),
      ]);
      if (_disposed || userId != _userId || !_loaded.containsKey(petId)) return;
      await _container
          .read(reminderSchedulerProvider)
          .sync(
            reminderPlanOf(
              petId: petId,
              petName: petName,
              plan: results[0] as CarePlan?,
              records: results[1] as List<HealthRecord>?,
              now: _container.read(healthClockProvider)(),
            ),
          );
      if (_disposed || userId != _userId || !_loaded.containsKey(petId)) return;
      // The basket's "running low" reminders, planned again for the same
      // reasons (a new day, the feeding portion or meal times changed).
      await _container.read(basketProvider.notifier).resyncReminders(petId);
    } catch (error) {
      debugPrint('PetLoop: could not load the reminders of a pet: $error');
    } finally {
      plan.close();
      records.close();
    }
  }
}
