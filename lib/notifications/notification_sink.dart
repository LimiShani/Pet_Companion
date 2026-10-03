import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a reminder is about. The owner turns each kind on or off in
/// Settings; a [NotificationSink] drops the kinds that are off, so callers
/// never check the settings themselves.
enum NotificationKind { meal, walk, medicine, appointment, basket }

/// One notification the phone should show at [at].
class PlannedNotification {
  const PlannedNotification({
    required this.key,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    this.payload,
  });

  /// Stable within its group (e.g. `<planItemId>@2026-10-03`), so syncing
  /// the same plan twice changes nothing.
  final String key;
  final NotificationKind kind;
  final DateTime at;

  /// Already in the app's language.
  final String title;
  final String body;

  /// Where tapping it leads, e.g. `feeding:<petId>`; see the sink.
  final String? payload;
}

/// Schedules the phone's notifications.
///
/// [syncGroup] replaces everything scheduled under [group] (e.g.
/// `health:<petId>`, `basket:<petId>`) with [items]; an empty list cancels
/// the group. Items in the past are ignored.
///
/// The sink applies the owner's choices (Settings > Notifications: the
/// kinds that are off, quiet hours), so callers send everything. Tapping a
/// notification opens the page its [PlannedNotification.payload] names:
/// `feeding:<petId>` the feeding page, `activity:<petId>` the activity
/// page, `health:<petId>` Health's Schedule, `basket:<petId>` the Store
/// tab; the pet becomes the selected pet first. The real sink is
/// `LocalNotificationSink` (`local_notification_sink.dart`).
abstract class NotificationSink {
  Future<void> syncGroup(String group, List<PlannedNotification> items);
}

/// Does nothing: the app ships with it until real notifications are wired,
/// and tests use it.
class NoopNotificationSink implements NotificationSink {
  const NoopNotificationSink();

  @override
  Future<void> syncGroup(String group, List<PlannedNotification> items) async {}
}

final notificationSinkProvider = Provider<NotificationSink>((ref) => const NoopNotificationSink());
