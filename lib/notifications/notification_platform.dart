import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'notification_sink.dart';

/// One notification as it is handed to the phone, with everything needed
/// to recognise it later: the plugin only gives back a pending
/// notification's id, title, body and payload, so the rest travels in the
/// payload (see [encode]).
@immutable
class ScheduledNotification {
  const ScheduledNotification({
    required this.group,
    required this.key,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.target,
    this.exact = false,
    this.snoozed = false,
    this.channelName = '',
    this.snoozeLabel = '',
  });

  final String group;
  final String key;
  final NotificationKind kind;
  final DateTime at;
  final String title;
  final String body;

  /// Where a tap leads (the [PlannedNotification.payload]).
  final String? target;

  /// Scheduled as an exact alarm (Android's "Alarms & reminders").
  final bool exact;

  /// Shown again after the owner tapped "In 15 min".
  final bool snoozed;

  /// The name of the kind's channel and the label of the snooze button, so
  /// a snooze can be scheduled where the app's strings are not at hand.
  final String channelName;
  final String snoozeLabel;

  /// Stable for a (group, key), so scheduling it again replaces it. A
  /// snoozed copy has an id of its own and does not replace the planned one.
  int get id => notificationIdOf(group, key, snoozed: snoozed);

  ScheduledNotification copyWith({DateTime? at, bool? exact, bool? snoozed}) =>
      ScheduledNotification(
        group: group,
        key: key,
        kind: kind,
        at: at ?? this.at,
        title: title,
        body: body,
        target: target,
        exact: exact ?? this.exact,
        snoozed: snoozed ?? this.snoozed,
        channelName: channelName,
        snoozeLabel: snoozeLabel,
      );

  /// The plugin's payload: everything above as JSON.
  String encode() => jsonEncode({
    'g': group,
    'k': key,
    'n': kind.name,
    'a': at.millisecondsSinceEpoch,
    't': title,
    'b': body,
    'p': ?target,
    if (exact) 'x': 1,
    if (snoozed) 's': 1,
    'c': channelName,
    'z': snoozeLabel,
  });

  /// The notification behind a payload, or `null` when it is not one of
  /// [encode]'s (a payload of an older version of the app).
  static ScheduledNotification? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return null;
      final kind = NotificationKind.values
          .where((k) => k.name == map['n'])
          .firstOrNull;
      final group = map['g'];
      final key = map['k'];
      final at = map['a'];
      if (kind == null || group is! String || key is! String || at is! int) {
        return null;
      }
      return ScheduledNotification(
        group: group,
        key: key,
        kind: kind,
        at: DateTime.fromMillisecondsSinceEpoch(at),
        title: map['t'] as String? ?? '',
        body: map['b'] as String? ?? '',
        target: map['p'] as String?,
        exact: map['x'] == 1,
        snoozed: map['s'] == 1,
        channelName: map['c'] as String? ?? '',
        snoozeLabel: map['z'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// The notification id of [key] in [group]: a 31-bit hash (FNV-1a), never
/// 0, the same on every run of the app.
int notificationIdOf(String group, String key, {bool snoozed = false}) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(
    '$group\u0000$key${snoozed ? '\u0000snoozed' : ''}',
  )) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final id = hash & 0x7fffffff;
  return id == 0 ? 1 : id;
}

/// Whether the phone lets PetLoop show notifications, and ring exactly.
@immutable
class NotificationAccess {
  const NotificationAccess({required this.allowed, this.exact});

  /// Notifications may be shown (Android 13+ and iOS ask the owner).
  final bool allowed;

  /// Android's "Alarms & reminders": `true` granted, `false` missing,
  /// `null` when the phone has no such question (iOS, older Android).
  final bool? exact;

  @override
  bool operator ==(Object other) =>
      other is NotificationAccess &&
      other.allowed == allowed &&
      other.exact == exact;

  @override
  int get hashCode => Object.hash(allowed, exact);
}

/// The phone's notifications, behind an interface so the sink can be
/// tested with a fake.
abstract class NotificationPlatform {
  /// How many notifications may wait at once. iOS keeps only 64.
  int get maxPending;

  /// Everything scheduled and not shown yet, as stored by [schedule]; a
  /// payload this app did not write comes back as `null` with its id.
  Future<List<(int, ScheduledNotification?)>> pending();

  /// Schedules [notification] (replacing any with the same id).
  Future<void> schedule(ScheduledNotification notification);

  Future<void> cancel(int id);
  Future<void> cancelAll();

  /// Names (or renames) the phone's notification categories.
  Future<void> nameChannels(Map<NotificationKind, String> names);

  Future<NotificationAccess> access();

  /// Shows the phone's own permission prompt; true when allowed afterwards.
  Future<bool> requestPermission();

  /// Opens Android's "Alarms & reminders" screen for PetLoop.
  Future<void> requestExactAlarms();

  /// Opens PetLoop's notification settings in the phone's settings.
  Future<void> openSettings();

  /// Called with the [ScheduledNotification.target] of a notification the
  /// owner tapped, including the one that opened the app. Taps that came
  /// before a handler was set are delivered to it at once.
  set onTap(void Function(String target)? handler);
}

/// The action id of "In 15 min".
const snoozeActionId = 'snooze';

/// How long "In 15 min" waits.
const snoozeDelay = Duration(minutes: 15);

const _iosCategory = 'petloop_reminder';
const _smallIcon = 'ic_stat_petloop';
const _settingsChannel = MethodChannel('petloop/system_settings');

String _channelId(NotificationKind kind) => 'petloop_${kind.name}';

NotificationDetails _details(ScheduledNotification n) => NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId(n.kind),
    n.channelName.isEmpty ? n.kind.name : n.channelName,
    icon: _smallIcon,
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    styleInformation: BigTextStyleInformation(n.body),
    actions: [
      if (n.snoozeLabel.isNotEmpty)
        AndroidNotificationAction(
          snoozeActionId,
          n.snoozeLabel,
          cancelNotification: true,
        ),
    ],
  ),
  iOS: const DarwinNotificationDetails(categoryIdentifier: _iosCategory),
);

Future<void> _schedule(
  FlutterLocalNotificationsPlugin plugin,
  ScheduledNotification n,
) async {
  Future<void> go(bool exact) => plugin.zonedSchedule(
    id: n.id,
    scheduledDate: tz.TZDateTime.from(n.at.toUtc(), tz.UTC),
    notificationDetails: _details(n),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    title: n.title,
    body: n.body,
    payload: n.copyWith(exact: exact).encode(),
  );
  try {
    await go(n.exact);
  } on PlatformException {
    // "Alarms & reminders" was taken away meanwhile: ring a little late
    // rather than not at all.
    if (!n.exact) rethrow;
    await go(false);
  }
}

/// Schedules [payload]'s notification again [snoozeDelay] from now.
Future<void> _snooze(
  FlutterLocalNotificationsPlugin plugin,
  String? payload,
) async {
  final original = ScheduledNotification.decode(payload);
  if (original == null) return;
  var exact = false;
  if (!kIsWeb && Platform.isAndroid) {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    exact = await android?.canScheduleExactNotifications() ?? false;
  }
  await _schedule(
    plugin,
    original.copyWith(
      at: DateTime.now().add(snoozeDelay),
      exact: exact,
      snoozed: true,
    ),
  );
}

/// "In 15 min" tapped while the app's screen is not running: Android and
/// iOS start a separate background isolate for it.
@pragma('vm:entry-point')
Future<void> notificationResponseInBackground(
  NotificationResponse response,
) async {
  if (response.actionId != snoozeActionId) return;
  try {
    await _snooze(FlutterLocalNotificationsPlugin(), response.payload);
  } catch (error) {
    debugPrint('PetLoop: could not snooze a reminder: $error');
  }
}

/// The real notifications, through `flutter_local_notifications`.
///
/// Times are handed over as instants (in UTC): each reminder is computed
/// in the phone's local time by the planner, so no time-zone database is
/// needed. When the phone moves to another zone the app plans again the
/// next time it is opened.
class FlutterNotificationPlatform implements NotificationPlatform {
  FlutterNotificationPlatform._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  void Function(String target)? _onTap;
  final _waitingTaps = <String>[];

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Sets up the plugin, or returns `null` where the app has no phone
  /// notifications (web, desktop) or they cannot be set up. [snoozeLabel]
  /// names the snooze button on iOS, where it is fixed at start-up.
  static Future<FlutterNotificationPlatform?> start({
    required String snoozeLabel,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return null;
    final plugin = FlutterLocalNotificationsPlugin();
    final platform = FlutterNotificationPlatform._(plugin);
    try {
      await plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings(_smallIcon),
          iOS: DarwinInitializationSettings(
            // The app asks itself, after explaining why (see the
            // permission sheet), never at start-up.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                _iosCategory,
                actions: [
                  DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: platform._onResponse,
        onDidReceiveBackgroundNotificationResponse:
            notificationResponseInBackground,
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        platform._onResponse(response);
      }
    } catch (error) {
      debugPrint('PetLoop: notifications are not available: $error');
      return null;
    }
    return platform;
  }

  void _onResponse(NotificationResponse response) {
    if (response.actionId == snoozeActionId) {
      _snooze(_plugin, response.payload).catchError((Object error) {
        debugPrint('PetLoop: could not snooze a reminder: $error');
      });
      return;
    }
    final target = ScheduledNotification.decode(response.payload)?.target;
    if (target == null) return;
    final handler = _onTap;
    if (handler == null) {
      _waitingTaps.add(target);
    } else {
      handler(target);
    }
  }

  @override
  set onTap(void Function(String target)? handler) {
    _onTap = handler;
    if (handler == null) return;
    final waiting = [..._waitingTaps];
    _waitingTaps.clear();
    waiting.forEach(handler);
  }

  @override
  int get maxPending => Platform.isIOS ? 60 : 250;

  @override
  Future<List<(int, ScheduledNotification?)>> pending() async => [
    for (final request in await _plugin.pendingNotificationRequests())
      (request.id, ScheduledNotification.decode(request.payload)),
  ];

  @override
  Future<void> schedule(ScheduledNotification notification) =>
      _schedule(_plugin, notification);

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> nameChannels(Map<NotificationKind, String> names) async {
    final android = _android;
    if (android == null) return;
    for (final MapEntry(key: kind, value: name) in names.entries) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId(kind),
          name,
          importance: Importance.high,
        ),
      );
    }
  }

  @override
  Future<NotificationAccess> access() async {
    final android = _android;
    if (android != null) {
      final allowed = await android.areNotificationsEnabled() ?? false;
      final exact = await android.canScheduleExactNotifications();
      return NotificationAccess(allowed: allowed, exact: exact);
    }
    final options = await _ios?.checkPermissions();
    return NotificationAccess(allowed: options?.isEnabled ?? false);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> openSettings() async {
    if (Platform.isAndroid) {
      await _settingsChannel.invokeMethod<void>('openNotificationSettings');
    } else {
      await launchUrl(Uri.parse('app-settings:'));
    }
  }
}
