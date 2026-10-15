import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'usage.dart';

/// One kind's numbers on one day.
class UsageKindDay {
  const UsageKindDay({required this.accounts, required this.total});

  /// How many accounts did it at least once.
  final int accounts;

  /// How many times, all accounts together.
  final int total;
}

/// One day of the administrators' summary (`usage_summary`, migration 0031).
class UsageDay {
  const UsageDay({
    required this.day,
    required this.active,
    required this.todayTickShare,
    this.kinds = const {},
  });

  final DateTime day;

  /// Accounts with any count that day.
  final int active;

  /// The share (0 to 1) of [active] accounts that ticked a Today row.
  final double todayTickShare;

  final Map<UsageKind, UsageKindDay> kinds;

  factory UsageDay.fromJson(Map<String, Object?> json) {
    final kinds = <UsageKind, UsageKindDay>{};
    final raw = json['kinds'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final kind = UsageKind.fromKey('${entry.key}');
        final value = entry.value;
        if (kind == null || value is! Map) continue;
        kinds[kind] = UsageKindDay(
          accounts: (value['accounts'] as num?)?.toInt() ?? 0,
          total: (value['total'] as num?)?.toInt() ?? 0,
        );
      }
    }
    return UsageDay(
      day: DateTime.parse(json['day'] as String),
      active: (json['active'] as num?)?.toInt() ?? 0,
      todayTickShare: (json['today_tick_share'] as num?)?.toDouble() ?? 0,
      kinds: kinds,
    );
  }
}

/// The last days of usage, newest first.
class UsageSummary {
  const UsageSummary(this.days);

  final List<UsageDay> days;

  /// True when no account counted anything in the whole window.
  bool get isEmpty => days.every((d) => d.active == 0);

  /// How many times [kind] happened in the newest [lastDays] days.
  int total(UsageKind kind, int lastDays) => days
      .take(lastDays)
      .fold(0, (sum, day) => sum + (day.kinds[kind]?.total ?? 0));
}

/// Reads the summary. Only permission administrators may.
abstract class UsageSummaryRepository {
  Future<UsageSummary> fetch({int days = 28});
}

class SupabaseUsageSummaryRepository implements UsageSummaryRepository {
  SupabaseUsageSummaryRepository(this.client);

  final SupabaseClient client;

  @override
  Future<UsageSummary> fetch({int days = 28}) async {
    final rows = await client.rpc('usage_summary', params: {'p_days': days});
    return UsageSummary([
      for (final row in rows as List)
        UsageDay.fromJson((row as Map).cast<String, Object?>()),
    ]);
  }
}

/// Believable sample numbers for the demo: a handful of accounts, more on
/// weekends, most ticking Today.
class FakeUsageSummaryRepository implements UsageSummaryRepository {
  FakeUsageSummaryRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    UsageSummary? summary,
    this.error,
  }) : _now = now ?? DateTime.now,
       _summary = summary;

  final Duration latency;
  final DateTime Function() _now;
  final UsageSummary? _summary;

  /// Thrown by [fetch] when set (tests of the error state).
  final Object? error;

  @override
  Future<UsageSummary> fetch({int days = 28}) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (error case final error?) throw error;
    if (_summary case final summary?) return summary;
    final now = _now();
    return UsageSummary([for (var i = 0; i < days; i++) _sampleDay(now, i)]);
  }

  static UsageDay _sampleDay(DateTime now, int ago) {
    final day = DateTime(now.year, now.month, now.day - ago);
    final weekend =
        day.weekday == DateTime.friday || day.weekday == DateTime.saturday;
    final active = 9 + (ago * 7) % 5 + (weekend ? 3 : 0);
    final ticked = math.max(1, active - 3 - ago % 3);
    int times(int per) => active * per + ago % 4;
    return UsageDay(
      day: day,
      active: active,
      todayTickShare: ticked / active,
      kinds: {
        UsageKind.appOpened: UsageKindDay(accounts: active, total: active),
        UsageKind.todayTick: UsageKindDay(accounts: ticked, total: times(3)),
        UsageKind.careLogged: UsageKindDay(
          accounts: active - 2,
          total: times(4),
        ),
        UsageKind.doseRecorded: UsageKindDay(accounts: 3, total: 5),
        UsageKind.dealOpened: UsageKindDay(accounts: 4, total: 6 + ago % 3),
        if (weekend)
          UsageKind.meetupJoined: const UsageKindDay(accounts: 2, total: 2),
        if (ago % 2 == 0)
          UsageKind.postCreated: const UsageKindDay(accounts: 2, total: 3),
      },
    );
  }
}

final usageSummaryRepositoryProvider = Provider<UsageSummaryRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseUsageSummaryRepository(Supabase.instance.client)
      : FakeUsageSummaryRepository(),
);

/// The last 28 days, for the Admin tools' Usage page. A failed load shows
/// its error with a "Try again" button; no automatic retries.
final usageSummaryProvider = FutureProvider.autoDispose<UsageSummary>(
  (ref) => ref.watch(usageSummaryRepositoryProvider).fetch(),
  retry: (_, _) => null,
);
