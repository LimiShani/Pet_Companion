import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/care/data/care_repository.dart';
import 'package:pet_companion/features/care/state/care_providers.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/data/reminder_scheduler.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/notifications/notifications.dart';

/// The phone's notifications, in memory. [scheduled] is what waits on the
/// "phone"; [log] lists every call.
class FakeNotificationPlatform implements NotificationPlatform {
  FakeNotificationPlatform({
    this.currentAccess = const NotificationAccess(allowed: false, exact: false),
    this.grantNotifications = true,
    this.grantExact = true,
    this.maxPending = 250,
  });

  NotificationAccess currentAccess;
  bool grantNotifications;
  bool grantExact;

  @override
  final int maxPending;

  final scheduled = <int, ScheduledNotification>{};

  /// Ids of waiting notifications whose payload is not the app's.
  final foreign = <int>{};
  final log = <String>[];
  Map<NotificationKind, String> channelNames = const {};
  int permissionRequests = 0;
  int exactRequests = 0;
  int settingsOpened = 0;

  void Function(String target)? _onTap;
  final _waiting = <String>[];

  /// What waits for [group], soonest first.
  List<ScheduledNotification> of(String group) =>
      scheduled.values.where((n) => n.group == group).toList()..sort((a, b) => a.at.compareTo(b.at));

  /// The owner taps a reminder that leads to [target].
  void tap(String target) {
    final handler = _onTap;
    if (handler == null) {
      _waiting.add(target);
    } else {
      handler(target);
    }
  }

  @override
  set onTap(void Function(String target)? handler) {
    _onTap = handler;
    if (handler == null) return;
    final waiting = [..._waiting];
    _waiting.clear();
    waiting.forEach(handler);
  }

  @override
  Future<List<(int, ScheduledNotification?)>> pending() async => [
    for (final MapEntry(:key, :value) in scheduled.entries) (key, value),
    for (final id in foreign) (id, null),
  ];

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    log.add('schedule ${notification.group} ${notification.key}');
    scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel ${scheduled[id]?.key ?? id}');
    scheduled.remove(id);
    foreign.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    log.add('cancelAll');
    scheduled.clear();
    foreign.clear();
  }

  @override
  Future<void> nameChannels(Map<NotificationKind, String> names) async => channelNames = names;

  @override
  Future<NotificationAccess> access() async => currentAccess;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (grantNotifications) currentAccess = NotificationAccess(allowed: true, exact: currentAccess.exact);
    return currentAccess.allowed;
  }

  @override
  Future<void> requestExactAlarms() async {
    exactRequests++;
    if (grantExact) currentAccess = NotificationAccess(allowed: currentAccess.allowed, exact: true);
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// The overrides that wire real reminders onto [platform].
List<Override> notificationOverrides(FakeNotificationPlatform platform) => [
  notificationPlatformProvider.overrideWithValue(platform),
  notificationSinkProvider.overrideWith(localNotificationSink),
  reminderSchedulerProvider.overrideWith(notificationReminderScheduler),
];

/// The whole app on its fakes with real reminders on [platform]: like
/// `pumpApp` in `test/helpers.dart`, with Health's sample data answering at
/// once around [now] (10 June 2025, the sample data's day, by default).
/// Pass [health] to start from a repository of your own.
Future<void> pumpAppWithNotifications(
  WidgetTester tester,
  FakeNotificationPlatform platform, {
  AppLanguage? language,
  SettingsStore? settings,
  DateTime? now,
  FakeHealthRepository? health,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final clock = now ?? DateTime(2025, 6, 10, 12);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        settingsStoreProvider.overrideWithValue(settings ?? MemorySettingsStore({languageSettingKey: ?language?.code})),
        healthClockProvider.overrideWithValue(() => clock),
        healthRepositoryProvider.overrideWithValue(
          health ?? FakeHealthRepository(latency: Duration.zero, now: () => clock),
        ),
        careRepositoryProvider.overrideWithValue(FakeCareRepository(latency: Duration.zero)),
        ...notificationOverrides(platform),
      ],
      child: const PetLoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}
