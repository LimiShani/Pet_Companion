import 'package:flutter/foundation.dart';

import 'notification_platform.dart';
import 'notification_settings.dart';
import 'notification_sink.dart';

/// At most this many reminders of one group wait on the phone; the
/// soonest are kept. A week of five daily routines is 35.
const maxPerGroup = 48;

/// A reminder closer than this to "now" is not scheduled any more: the
/// phone refuses times in the past, and the moment would pass meanwhile.
const _margin = Duration(seconds: 10);

/// The texts the sink adds to every notification: the phone's name of each
/// kind's channel and the label of the snooze button.
@immutable
class NotificationChrome {
  const NotificationChrome({
    this.channelNames = const {},
    this.snoozeLabel = '',
  });

  final Map<NotificationKind, String> channelNames;
  final String snoozeLabel;

  @override
  bool operator ==(Object other) =>
      other is NotificationChrome &&
      other.snoozeLabel == snoozeLabel &&
      mapEquals(other.channelNames, channelNames);

  @override
  int get hashCode => Object.hash(
    snoozeLabel,
    Object.hashAllUnordered(channelNames.entries.map((e) => e.toString())),
  );
}

/// The reminders of [items] (one group) that the owner's [settings] let
/// ring, at the time they ring: kinds that are off are dropped, and with
/// quiet hours on a meal, walk or basket reminder between 22:00 and 07:00
/// waits until 07:00.
///
/// A waiting reminder is dropped instead when another reminder of the same
/// kind in the group comes after it and no later than 07:00: a 23:00 snack
/// and a 06:30 breakfast become one reminder at 07:00, and a late walk is
/// not repeated by a 07:00 walk. Medicines and appointments never wait.
///
/// Reminders in the past are kept (the sink drops them), so a quiet-hours
/// reminder that was due at 05:00 still rings at 07:00.
List<PlannedNotification> applySettings(
  List<PlannedNotification> items,
  NotificationSettings settings,
) {
  final allowed = [
    for (final item in items)
      if (settings.allows(item.kind)) item,
  ];
  if (!settings.quietHours) return allowed;
  final result = <PlannedNotification>[];
  for (final item in allowed) {
    if (!NotificationSettings.waitsInQuietHours(item.kind) ||
        !NotificationSettings.isQuiet(item.at)) {
      result.add(item);
      continue;
    }
    final moved = NotificationSettings.quietEndAfter(item.at);
    final covered = allowed.any(
      (other) =>
          !identical(other, item) &&
          other.kind == item.kind &&
          other.at.isAfter(item.at) &&
          !other.at.isAfter(moved),
    );
    if (covered) continue;
    result.add(
      PlannedNotification(
        key: item.key,
        kind: item.kind,
        at: moved,
        title: item.title,
        body: item.body,
        payload: item.payload,
      ),
    );
  }
  return result;
}

/// What the phone should have waiting for [groups]: [applySettings] per
/// group, nothing before [now], the soonest [perGroup] of each group, and
/// the soonest [total] of all.
List<ScheduledNotification> notificationsToSchedule({
  required Map<String, List<PlannedNotification>> groups,
  required NotificationSettings settings,
  required DateTime now,
  bool exact = false,
  NotificationChrome chrome = const NotificationChrome(),
  int perGroup = maxPerGroup,
  int total = 250,
}) {
  final earliest = now.add(_margin);
  final all = <ScheduledNotification>[];
  for (final MapEntry(key: group, value: items) in groups.entries) {
    final upcoming = [
      for (final item in applySettings(items, settings))
        if (item.at.isAfter(earliest)) item,
    ]..sort((a, b) => a.at.compareTo(b.at));
    for (final item in upcoming.take(perGroup)) {
      all.add(
        ScheduledNotification(
          group: group,
          key: item.key,
          kind: item.kind,
          at: item.at,
          title: item.title,
          body: item.body,
          target: item.payload,
          exact: exact,
          channelName: chrome.channelNames[item.kind] ?? '',
          snoozeLabel: chrome.snoozeLabel,
        ),
      );
    }
  }
  all.sort((a, b) => a.at.compareTo(b.at));
  return all.take(total).toList();
}

/// The real [NotificationSink]: schedules the reminders on the phone
/// through a [NotificationPlatform].
///
/// It keeps the last items of every group, so a change of [settings], of
/// [exact] or of the texts ([chrome]) re-plans everything without the
/// callers. Every change ends in one pass that compares what should wait
/// on the phone with what does ([NotificationPlatform.pending]) and only
/// schedules or cancels the difference. A group nobody synced since the app
/// started is left as it is, so reminders of a feature that has not loaded
/// yet survive a restart.
///
/// A reminder snoozed with "In 15 min" stays while its key is still in its
/// group (with its kind on), and goes when the occurrence is answered.
class LocalNotificationSink implements NotificationSink {
  LocalNotificationSink(
    this._platform, {
    NotificationSettings settings = NotificationSettings.defaults,
    bool exact = false,
    NotificationChrome chrome = const NotificationChrome(),
    DateTime Function() now = DateTime.now,
    this.onSomethingToRemind,
  }) : _settings = settings,
       _exact = exact,
       _chrome = chrome,
       _now = now;

  final NotificationPlatform _platform;
  final DateTime Function() _now;

  /// Called whenever a group receives at least one reminder (before the
  /// settings are applied): the account has something to remind about.
  final VoidCallback? onSomethingToRemind;

  NotificationSettings _settings;
  bool _exact;
  NotificationChrome _chrome;
  final _groups = <String, List<PlannedNotification>>{};

  Future<void> _done = Future.value();
  Future<void>? _queued;

  NotificationSettings get settings => _settings;

  set settings(NotificationSettings value) {
    if (value == _settings) return;
    _settings = value;
    _reconcileSoon();
  }

  /// Whether Android lets PetLoop ring exactly ("Alarms & reminders").
  bool get exact => _exact;

  set exact(bool value) {
    if (value == _exact) return;
    _exact = value;
    _reconcileSoon();
  }

  NotificationChrome get chrome => _chrome;

  set chrome(NotificationChrome value) {
    if (value == _chrome) return;
    _chrome = value;
    _reconcileSoon();
  }

  /// The groups synced since the app started, with their last items.
  Map<String, List<PlannedNotification>> get groups =>
      Map.unmodifiable(_groups);

  @override
  Future<void> syncGroup(String group, List<PlannedNotification> items) {
    _groups[group] = List.unmodifiable(items);
    if (items.isNotEmpty) onSomethingToRemind?.call();
    return _reconcileSoon();
  }

  /// Cancels every group that starts with [prefix] except those in [keep]
  /// (e.g. `health:` and the ids of the owner's pets), including groups
  /// scheduled before the app started.
  Future<void> retainGroups(String prefix, Set<String> keep) {
    return _run(() async {
      final pending = await _platform.pending();
      for (final (_, notification) in pending) {
        final group = notification?.group;
        if (group != null && group.startsWith(prefix) && !keep.contains(group)) {
          _groups[group] = const [];
        }
      }
      for (final group in [..._groups.keys]) {
        if (group.startsWith(prefix) && !keep.contains(group)) {
          _groups[group] = const [];
        }
      }
      await _reconcile();
    });
  }

  /// Cancels everything (sign-out) and forgets every group.
  Future<void> cancelAll() {
    return _run(() async {
      _groups.clear();
      await _platform.cancelAll();
    });
  }

  /// Plans again soon, once for any number of changes made meanwhile.
  Future<void> _reconcileSoon() => _queued ??= _run(() {
    _queued = null;
    return _reconcile();
  });

  Future<void> _run(Future<void> Function() task) {
    final next = _done.then((_) => task()).catchError((Object error) {
      debugPrint('PetLoop: could not schedule the reminders: $error');
    });
    _done = next;
    return next;
  }

  Future<void> _reconcile() async {
    final settings = _settings;
    final wanted = notificationsToSchedule(
      groups: _groups,
      settings: settings,
      now: _now(),
      exact: _exact,
      chrome: _chrome,
      total: _platform.maxPending,
    );
    final wantedById = {for (final n in wanted) n.id: n};
    final liveKeys = {
      for (final MapEntry(key: group, value: items) in _groups.entries)
        group: {
          for (final item in items)
            if (settings.allows(item.kind)) item.key,
        },
    };

    final waiting = <int, ScheduledNotification>{};
    for (final (id, notification) in await _platform.pending()) {
      if (notification == null) {
        await _platform.cancel(id);
        continue;
      }
      final live = liveKeys[notification.group];
      if (live == null) continue;
      if (notification.snoozed) {
        if (!live.contains(notification.key)) await _platform.cancel(id);
      } else if (!wantedById.containsKey(id)) {
        await _platform.cancel(id);
      } else {
        waiting[id] = notification;
      }
    }
    for (final notification in wanted) {
      if (waiting[notification.id]?.encode() == notification.encode()) continue;
      await _platform.schedule(notification);
    }
  }
}
