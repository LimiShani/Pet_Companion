import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../l10n/settings_store.dart';

/// Usage counts: how many times a day an account does the actions we want
/// people to repeat, so the owner learns which ones are used, without an
/// analytics service. See docs/usage_counts.md and migration 0031.
///
/// ```
/// a service's success point ─ ref.read(usageProvider).count(UsageKind.x)
///   └─ UsageCounter: tally per account and local day, in the preferences
///        └─ once a day, at start or resume ──> UsageSink (usage_add RPC)
/// ```
///
/// Only the kinds below are counted: no screens, no text, no ids. Nothing
/// is counted while signed out or in the demo, and nothing here ever
/// throws to the caller or waits on the network.
enum UsageKind {
  /// A Today row ticked (added by the Today list).
  todayTick('today_tick'),
  careLogged('care_logged'),
  doseRecorded('dose_recorded'),
  recordAdded('record_added'),
  quickLog('quick_log'),
  meetupJoined('meetup_joined'),
  meetupPosted('meetup_posted'),
  postCreated('post_created'),
  commentCreated('comment_created'),
  chatMessageSent('chat_message_sent'),
  dealOpened('deal_opened'),
  dealShared('deal_shared'),
  basketBoughtAgain('basket_bought_again'),
  expenseAdded('expense_added'),
  emergencyOpened('emergency_opened'),
  findVetOpened('find_vet_opened'),
  householdInviteSent('household_invite_sent'),

  /// The app opened (or came back) on a new day; once a day.
  appOpened('app_opened');

  const UsageKind(this.key);

  /// The kind's name in the database (`usage_counts.kind`).
  final String key;

  static UsageKind? fromKey(String key) {
    for (final kind in values) {
      if (kind.key == key) return kind;
    }
    return null;
  }
}

/// A local day as the database writes it: `2026-10-15`.
String usageDayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Where the counts go.
abstract class UsageSink {
  /// Adds [counts] to the signed-in account's row of [day]; throws when
  /// they were not stored.
  Future<void> add(DateTime day, Map<UsageKind, int> counts);
}

/// Adds the counts through the `usage_add` RPC (migration 0031), which
/// stores them for the signed-in account.
class SupabaseUsageSink implements UsageSink {
  SupabaseUsageSink(this.client);

  final SupabaseClient client;

  @override
  Future<void> add(DateTime day, Map<UsageKind, int> counts) async {
    await client.rpc(
      'usage_add',
      params: {
        'p_day': usageDayKey(day),
        'p_counts': {
          for (final entry in counts.entries) entry.key.key: entry.value,
        },
      },
    );
  }
}

/// Accepts the counts and keeps them nowhere.
class NoopUsageSink implements UsageSink {
  const NoopUsageSink();

  @override
  Future<void> add(DateTime day, Map<UsageKind, int> counts) async {}
}

class _Tally {
  _Tally();

  /// Day key → kind key → count.
  final Map<String, Map<String, int>> days = {};

  /// The local day of the last flush that sent everything.
  String? flushedOn;

  /// When the last flush started (sent or not).
  DateTime? attemptAt;

  /// The local day app_opened was last counted.
  String? openedOn;

  Map<String, Object?> toJson() => {
    'days': days,
    'flushed': flushedOn,
    'attempt': attemptAt?.toUtc().toIso8601String(),
    'opened': openedOn,
  };

  static _Tally fromJson(Object? json) {
    final tally = _Tally();
    if (json is! Map) return tally;
    final days = json['days'];
    if (days is Map) {
      for (final day in days.entries) {
        final counts = day.value;
        if (day.key is! String || counts is! Map) continue;
        tally.days[day.key as String] = {
          for (final count in counts.entries)
            if (count.key is String && count.value is num)
              count.key as String: (count.value as num).toInt(),
        };
      }
    }
    tally.flushedOn = json['flushed'] as String?;
    tally.attemptAt = DateTime.tryParse(json['attempt'] as String? ?? '');
    tally.openedOn = json['opened'] as String?;
    return tally;
  }
}

/// Counts the actions of the signed-in account and sends them once a day.
///
/// The tally is kept per account and per local day in the phone's
/// preferences, so counts survive a restart and an offline day. [resumed]
/// (the app started or came back to the front) counts [UsageKind.appOpened]
/// once a day and sends what waits when the last complete send was on
/// another day; after a failed send it waits [retryAfter] before trying
/// again. The days kept are today and the [keepDays] - 1 before it; what
/// was not sent by then is dropped.
class UsageCounter {
  UsageCounter({
    required UsageSink this.sink,
    required String? Function() userId,
    SettingsStore? store,
    DateTime Function()? now,
    this.retryAfter = const Duration(hours: 6),
    this.keepDays = 3,
  }) : _userId = userId,
       _store = store ?? MemorySettingsStore(),
       _now = now ?? DateTime.now {
    _load();
  }

  /// Counts nothing and sends nothing (the demo, tests).
  UsageCounter.off()
    : sink = null,
      _userId = (() => null),
      _store = MemorySettingsStore(),
      _now = DateTime.now,
      retryAfter = Duration.zero,
      keepDays = 0;

  /// The preferences key the tally waits under.
  static const storeKey = 'usage_counts.tally';

  /// A row's limit in the database (checked there too).
  static const maxCount = 500;

  /// Where counts go; `null` when counting is off.
  final UsageSink? sink;

  final Duration retryAfter;
  final int keepDays;

  final String? Function() _userId;
  final SettingsStore _store;
  final DateTime Function() _now;
  final Map<String, _Tally> _tallies = {};
  bool _flushing = false;

  bool get enabled => sink != null;

  /// What waits to be sent for [userId]: day key → kind → count (tests).
  Map<String, Map<UsageKind, int>> pending(String userId) => {
    for (final day in (_tallies[userId]?.days ?? const {}).entries)
      day.key: {
        for (final count in day.value.entries)
          ?UsageKind.fromKey(count.key): count.value,
      },
  };

  /// Adds one [kind] to today's tally of the signed-in account. Returns at
  /// once; does nothing while signed out or when counting is off.
  void count(UsageKind kind) {
    if (!enabled) return;
    try {
      final user = _userId();
      if (user == null) return;
      final counts = _tally(
        user,
      ).days.putIfAbsent(usageDayKey(_now()), () => {});
      counts[kind.key] = math.min((counts[kind.key] ?? 0) + 1, maxCount);
      _prune();
      unawaited(_persist());
    } catch (_) {
      // Counting never throws.
    }
  }

  /// The app started, an account signed in, or the app came back to the
  /// front: counts [UsageKind.appOpened] once a day and sends what waits
  /// when it is due. Never throws.
  Future<void> resumed() async {
    if (!enabled) return;
    try {
      final user = _userId();
      if (user == null) return;
      final tally = _tally(user);
      final today = usageDayKey(_now());
      if (tally.openedOn != today) {
        tally.openedOn = today;
        count(UsageKind.appOpened);
      }
      await flush();
    } catch (_) {
      // Counting never throws.
    }
  }

  /// Sends the signed-in account's tally, one call per day kept, and
  /// forgets what was stored. Skipped when everything was already sent
  /// today, or a send started less than [retryAfter] ago (unless [force]).
  /// A day that fails stays for the next time. Never throws.
  Future<void> flush({bool force = false}) async {
    final sink = this.sink;
    if (sink == null || _flushing) return;
    _flushing = true;
    try {
      final user = _userId();
      if (user == null) return;
      final tally = _tally(user);
      final now = _now();
      final today = usageDayKey(now);
      if (!force) {
        if (tally.flushedOn == today) return;
        final last = tally.attemptAt;
        if (last != null && now.difference(last).abs() < retryAfter) return;
      }
      _prune();
      tally.attemptAt = now;
      await _persist();
      var complete = true;
      for (final day in tally.days.keys.toList()..sort()) {
        final counts = tally.days[day]!;
        final sent = {
          for (final count in counts.entries)
            if (UsageKind.fromKey(count.key) case final kind?)
              if (count.value > 0) kind: math.min(count.value, maxCount),
        };
        if (sent.isEmpty) {
          tally.days.remove(day);
          continue;
        }
        try {
          await sink.add(DateTime.parse(day), sent);
        } catch (_) {
          complete = false;
          continue;
        }
        // Counts made while the call was out stay for the next send.
        for (final entry in sent.entries) {
          final left = (counts[entry.key.key] ?? 0) - entry.value;
          if (left > 0) {
            counts[entry.key.key] = left;
          } else {
            counts.remove(entry.key.key);
          }
        }
        counts.removeWhere((key, _) => UsageKind.fromKey(key) == null);
        if (counts.isEmpty) tally.days.remove(day);
      }
      if (complete) tally.flushedOn = today;
      await _persist();
    } catch (_) {
      // Sending never throws; the tally waits for the next time.
    } finally {
      _flushing = false;
    }
  }

  _Tally _tally(String user) => _tallies.putIfAbsent(user, _Tally.new);

  /// Drops the days older than [keepDays], and accounts with nothing left.
  void _prune() {
    final now = _now();
    final oldest = usageDayKey(
      DateTime(now.year, now.month, now.day - (keepDays - 1)),
    );
    final today = usageDayKey(now);
    for (final tally in _tallies.values) {
      tally.days.removeWhere((day, _) => day.compareTo(oldest) < 0);
    }
    _tallies.removeWhere(
      (_, tally) =>
          tally.days.isEmpty &&
          tally.openedOn != today &&
          tally.flushedOn != today,
    );
  }

  void _load() {
    try {
      final raw = _store.read(storeKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      for (final entry in json.entries) {
        if (entry.key is String) {
          _tallies[entry.key as String] = _Tally.fromJson(entry.value);
        }
      }
    } catch (_) {
      // A tally that cannot be read starts again.
    }
  }

  Future<void> _persist() async {
    try {
      // Encoded now, so a later count is never overwritten by an older one.
      final raw = _tallies.isEmpty
          ? null
          : jsonEncode({
              for (final entry in _tallies.entries)
                entry.key: entry.value.toJson(),
            });
      await _store.write(storeKey, raw);
    } catch (_) {
      // The tally then lives for this run only.
    }
  }
}

/// The app's usage counter: on with the Supabase backend, off in the demo
/// and in tests (override it with a [UsageCounter] on a fake sink).
final usageProvider = Provider<UsageCounter>((ref) {
  if (!AppConfig.hasSupabase) return UsageCounter.off();
  final client = Supabase.instance.client;
  return UsageCounter(
    sink: SupabaseUsageSink(client),
    userId: () => client.auth.currentUser?.id,
    store: ref.watch(settingsStoreProvider),
  );
});
