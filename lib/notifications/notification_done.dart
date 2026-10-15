import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Done" on a reminder notification: what it records, and the queue the
/// answers wait in until the app can record them.
///
/// A reminder of a care plan item (a meal, a walk, a medicine time, a
/// routine) carries a [CareDone] in its payload. Pressing "Done" turns it
/// into a [DoneAction] (the same plus the moment it was pressed). The
/// phone runs that button in a separate background isolate, where the
/// backend is not available, so the action is written to a [DoneQueue] in
/// the phone's preferences there; the app records what waits as soon as it
/// can (`NotificationDoneRecorder`), with the moment of the press.

/// What a "Done" records: the planned meal with the usual portion, the
/// planned walk, a medicine dose given now, or a routine done.
enum CareDoneKind { meal, walk, dose, routine }

/// One occurrence of a care plan item that "Done" answers.
@immutable
class CareDone {
  const CareDone({
    required this.petId,
    required this.itemId,
    required this.kind,
    required this.dueOn,
    required this.dueMinutes,
    this.shiftDays = 0,
  });

  final String petId;

  /// The care plan item (`care_plan_items.id`).
  final String itemId;
  final CareDoneKind kind;

  /// The day the occurrence is due, in the data's world (see
  /// [shiftDays]); only the date counts.
  final DateTime dueOn;

  /// The item's time on that day, in minutes after midnight.
  final int dueMinutes;

  /// How many days the reminder was moved to ring in the real world: the
  /// demo's sample data lives on another day (`ReminderPlan.today`). 0 for
  /// an account.
  final int shiftDays;

  /// The same for the same occurrence on every run: an occurrence is
  /// recorded at most once.
  String get occurrenceKey {
    final h = (dueMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (dueMinutes % 60).toString().padLeft(2, '0');
    return '$itemId@${_dayOf(dueOn)}T$h:$m';
  }

  Map<String, Object> toJson() => {
    'pet': petId,
    'item': itemId,
    'kind': kind.name,
    'on': _dayOf(dueOn),
    'at': dueMinutes,
    if (shiftDays != 0) 'sh': shiftDays,
  };

  /// The occurrence in [json], or `null` when it is not one of [toJson]'s.
  static CareDone? fromJson(Object? json) {
    if (json is! Map) return null;
    final pet = json['pet'];
    final item = json['item'];
    final kind = CareDoneKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final day = json['on'];
    final on = day is String ? DateTime.tryParse(day) : null;
    final at = json['at'];
    final shift = json['sh'] ?? 0;
    if (pet is! String ||
        item is! String ||
        item.isEmpty ||
        kind == null ||
        on == null ||
        at is! int ||
        shift is! int) {
      return null;
    }
    return CareDone(
      petId: pet,
      itemId: item,
      kind: kind,
      dueOn: DateTime(on.year, on.month, on.day),
      dueMinutes: at,
      shiftDays: shift,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CareDone &&
      other.petId == petId &&
      other.itemId == itemId &&
      other.kind == kind &&
      _dayOf(other.dueOn) == _dayOf(dueOn) &&
      other.dueMinutes == dueMinutes &&
      other.shiftDays == shiftDays;

  @override
  int get hashCode =>
      Object.hash(petId, itemId, kind, _dayOf(dueOn), dueMinutes, shiftDays);
}

/// "Done" pressed on the notification [key] of [group] at [actedAt].
@immutable
class DoneAction {
  const DoneAction({
    required this.done,
    required this.actedAt,
    this.group = '',
    this.key = '',
  });

  final CareDone done;

  /// When the owner pressed it: the time the dose was given, the meal
  /// eaten, the walk done.
  final DateTime actedAt;

  /// The notification's group and key in the sink, so its "In 15 min" copy
  /// can be cancelled.
  final String group;
  final String key;

  String get occurrenceKey => done.occurrenceKey;

  Map<String, Object> toJson() => {
    'd': done.toJson(),
    'a': actedAt.millisecondsSinceEpoch,
    'g': group,
    'k': key,
  };

  static DoneAction? fromJson(Object? json) {
    if (json is! Map) return null;
    final done = CareDone.fromJson(json['d']);
    final at = json['a'];
    if (done == null || at is! int) return null;
    return DoneAction(
      done: done,
      actedAt: DateTime.fromMillisecondsSinceEpoch(at),
      group: json['g'] as String? ?? '',
      key: json['k'] as String? ?? '',
    );
  }

  static DoneAction? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      return fromJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Where the [DoneQueue] keeps its entries: the phone's preferences, or
/// memory in tests.
abstract class DoneQueueStore {
  /// Every entry whose key starts with [prefix], read afresh (another
  /// isolate may have written meanwhile).
  Future<Map<String, String>> readAll(String prefix);

  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// The phone's preferences. Each isolate keeps its own copy of them, so
/// [readAll] reloads first: the background isolate of a notification
/// button writes behind the app's back.
class SharedPrefsDoneQueueStore implements DoneQueueStore {
  const SharedPrefsDoneQueueStore();

  @override
  Future<Map<String, String>> readAll(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return {
      for (final key in prefs.getKeys())
        if (key.startsWith(prefix) && prefs.get(key) is String)
          key: prefs.getString(key)!,
    };
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

/// In memory, for tests.
class MemoryDoneQueueStore implements DoneQueueStore {
  MemoryDoneQueueStore([Map<String, String>? values]) : values = values ?? {};

  final Map<String, String> values;

  @override
  Future<Map<String, String>> readAll(String prefix) async => {
    for (final MapEntry(:key, :value) in values.entries)
      if (key.startsWith(prefix)) key: value,
  };

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// The "Done" answers that wait to be recorded, and the occurrences
/// already recorded from a notification.
///
/// Like the crash reports' queue (`CrashReporter`), it lives in the
/// phone's preferences, so an answer given while the app was closed is
/// recorded on the next start. Unlike it, every entry has a key of its
/// own (its occurrence): the background isolate adds entries while the
/// app may be removing others, and neither may overwrite the other's
/// work. The list of recorded occurrences is only written by the app.
class DoneQueue {
  DoneQueue(this._store);

  static const entryPrefix = 'notifications.done.queue.';
  static const handledKey = 'notifications.done.handled';

  /// How long an answer is kept for recording: an older one is dropped,
  /// rather than surprising the owner with a meal of two days ago.
  static const maxAge = Duration(hours: 48);

  /// How long a recorded occurrence is remembered: longer than [maxAge],
  /// so a late copy of the same answer is never recorded twice.
  static const handledAge = Duration(hours: 72);

  final DoneQueueStore _store;

  Future<void> add(DoneAction action) =>
      _store.write('$entryPrefix${action.occurrenceKey}', action.encode());

  /// Every waiting answer, oldest first. Unreadable entries are removed.
  Future<List<DoneAction>> pending() async {
    final entries = await _store.readAll(entryPrefix);
    final result = <DoneAction>[];
    for (final MapEntry(:key, :value) in entries.entries) {
      final action = DoneAction.decode(value);
      if (action == null) {
        await _store.remove(key);
      } else {
        result.add(action);
      }
    }
    result.sort((a, b) => a.actedAt.compareTo(b.actedAt));
    return result;
  }

  Future<void> remove(DoneAction action) =>
      _store.remove('$entryPrefix${action.occurrenceKey}');

  /// The occurrences recorded from a notification, with when.
  Future<Map<String, DateTime>> handled() async {
    final raw = (await _store.readAll(handledKey))[handledKey];
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in map.entries)
          if (key is String && value is int)
            key: DateTime.fromMillisecondsSinceEpoch(value),
      };
    } catch (_) {
      return {};
    }
  }

  /// Remembers that [occurrenceKey] was recorded at [now], and forgets
  /// what is older than [handledAge].
  Future<void> markHandled(String occurrenceKey, DateTime now) async {
    final all = await handled();
    all[occurrenceKey] = now;
    all.removeWhere((_, at) => now.difference(at) > handledAge);
    await _store.write(
      handledKey,
      jsonEncode({
        for (final MapEntry(:key, :value) in all.entries)
          key: value.millisecondsSinceEpoch,
      }),
    );
  }
}

String _dayOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
