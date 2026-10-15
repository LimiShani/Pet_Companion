import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pet_companion/l10n/settings_store.dart';
import 'package:pet_companion/platform/usage.dart';
import 'package:pet_companion/platform/usage_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Remembers what it was given; fails every call while [failing], and
/// holds each call until [gate] completes when one is set.
class RecordingUsageSink implements UsageSink {
  final sent = <String, Map<UsageKind, int>>{};
  int calls = 0;
  bool failing = false;
  Completer<void>? gate;

  @override
  Future<void> add(DateTime day, Map<UsageKind, int> counts) async {
    calls++;
    if (gate case final gate?) await gate.future;
    if (failing) throw StateError('backend down');
    final stored = sent.putIfAbsent(usageDayKey(day), () => {});
    for (final entry in counts.entries) {
      stored[entry.key] = (stored[entry.key] ?? 0) + entry.value;
    }
  }
}

const me = 'e2e2e2e2-e2e2-4e2e-8e2e-e2e2e2e2e2e2';

void main() {
  late RecordingUsageSink sink;
  late MemorySettingsStore store;
  late DateTime now;
  String? user;

  UsageCounter counter() => UsageCounter(
    sink: sink,
    userId: () => user,
    store: store,
    now: () => now,
  );

  setUp(() {
    sink = RecordingUsageSink();
    store = MemorySettingsStore();
    now = DateTime(2026, 10, 15, 9, 30);
    user = me;
  });

  group('the tally', () {
    test('counts per local day and kind, and survives a restart', () {
      final usage = counter();
      usage.count(UsageKind.careLogged);
      usage.count(UsageKind.careLogged);
      usage.count(UsageKind.dealOpened);
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.careLogged: 2, UsageKind.dealOpened: 1},
      });
      expect(store.read(UsageCounter.storeKey), isNotNull);
      expect(counter().pending(me), usage.pending(me));
      expect(sink.calls, 0, reason: 'Counting never sends');
    });

    test('a new day starts a new tally', () {
      final usage = counter();
      usage.count(UsageKind.quickLog);
      now = DateTime(2026, 10, 16, 0, 5);
      usage.count(UsageKind.quickLog);
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.quickLog: 1},
        '2026-10-16': {UsageKind.quickLog: 1},
      });
    });

    test('a row stops at 500', () {
      final usage = counter();
      for (var i = 0; i < 520; i++) {
        usage.count(UsageKind.chatMessageSent);
      }
      expect(usage.pending(me)['2026-10-15']![UsageKind.chatMessageSent], 500);
    });

    test('keeps three days: older counts are dropped', () {
      final usage = counter();
      usage.count(UsageKind.postCreated);
      now = DateTime(2026, 10, 17, 9);
      usage.count(UsageKind.postCreated);
      expect(usage.pending(me).keys, ['2026-10-15', '2026-10-17']);
      now = DateTime(2026, 10, 18, 9);
      usage.count(UsageKind.postCreated);
      expect(usage.pending(me).keys, ['2026-10-17', '2026-10-18']);
    });

    test('each account has its own tally', () {
      final usage = counter();
      usage.count(UsageKind.dealShared);
      user = 'other';
      usage.count(UsageKind.dealOpened);
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.dealShared: 1},
      });
      expect(usage.pending('other'), {
        '2026-10-15': {UsageKind.dealOpened: 1},
      });
    });

    test('a tally that cannot be read starts again', () {
      store.values[UsageCounter.storeKey] = 'not json';
      final usage = counter();
      usage.count(UsageKind.appOpened);
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.appOpened: 1},
      });
    });
  });

  group('sending', () {
    test('the first start of the day counts the opening and sends', () async {
      final usage = counter();
      now = DateTime(2026, 10, 14, 20);
      usage.count(UsageKind.doseRecorded);
      now = DateTime(2026, 10, 15, 8);
      await usage.resumed();
      expect(sink.sent, {
        '2026-10-14': {UsageKind.doseRecorded: 1},
        '2026-10-15': {UsageKind.appOpened: 1},
      });
      expect(sink.calls, 2, reason: 'One call per day');
      expect(usage.pending(me), isEmpty);
    });

    test('sends once a day; later counts wait for the next day', () async {
      final usage = counter();
      await usage.resumed();
      expect(sink.calls, 1);
      usage.count(UsageKind.careLogged);
      now = DateTime(2026, 10, 15, 22);
      await usage.resumed();
      expect(sink.calls, 1, reason: 'Already sent today');
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.careLogged: 1},
      });

      now = DateTime(2026, 10, 16, 7);
      await usage.resumed();
      expect(sink.sent['2026-10-15'], {
        UsageKind.appOpened: 1,
        UsageKind.careLogged: 1,
      });
      expect(sink.sent['2026-10-16'], {UsageKind.appOpened: 1});
      expect(usage.pending(me), isEmpty);
    });

    test('the opening is counted once a day, and survives a restart', () async {
      await counter().resumed();
      final restarted = counter();
      await restarted.resumed();
      expect(sink.sent['2026-10-15'], {UsageKind.appOpened: 1});
      expect(sink.calls, 1);
    });

    test('a failure keeps the tally; the next try waits six hours', () async {
      final usage = counter();
      usage.count(UsageKind.recordAdded);
      sink.failing = true;
      await usage.resumed();
      expect(sink.calls, 1);
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.recordAdded: 1, UsageKind.appOpened: 1},
      });

      sink.failing = false;
      now = DateTime(2026, 10, 15, 14);
      await usage.resumed();
      expect(sink.calls, 1, reason: 'Less than six hours after the try');

      now = DateTime(2026, 10, 15, 15, 31);
      await usage.resumed();
      expect(sink.sent['2026-10-15'], {
        UsageKind.recordAdded: 1,
        UsageKind.appOpened: 1,
      });
      expect(usage.pending(me), isEmpty);
    });

    test('a failure is remembered across a restart', () async {
      sink.failing = true;
      await counter().resumed();
      sink.failing = false;
      final restarted = counter();
      await restarted.resumed();
      expect(sink.calls, 1, reason: 'The six hours hold after a restart');
      expect(restarted.pending(me), isNotEmpty);
    });

    test('counts made while a send is out stay for the next one', () async {
      final usage = counter();
      usage.count(UsageKind.dealOpened);
      sink.gate = Completer<void>();
      final sending = usage.flush();
      await pumpEventQueue();
      expect(sink.calls, 1, reason: 'The call is out');
      usage.count(UsageKind.dealOpened);
      sink.gate!.complete();
      await sending;
      expect(sink.sent['2026-10-15'], {UsageKind.dealOpened: 1});
      expect(usage.pending(me), {
        '2026-10-15': {UsageKind.dealOpened: 1},
      });
    });

    test('never throws, even when the store fails', () async {
      final usage = UsageCounter(
        sink: sink,
        userId: () => me,
        store: _BrokenStore(),
        now: () => now,
      );
      usage.count(UsageKind.expenseAdded);
      await usage.resumed();
      expect(sink.sent['2026-10-15'], {
        UsageKind.expenseAdded: 1,
        UsageKind.appOpened: 1,
      });
    });
  });

  group('off', () {
    test('signed out: nothing is counted or sent', () async {
      user = null;
      final usage = counter();
      usage.count(UsageKind.careLogged);
      await usage.resumed();
      await usage.flush(force: true);
      expect(sink.calls, 0);
      expect(store.values, isEmpty);
    });

    test('the demo (and every test) has counting off', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final usage = container.read(usageProvider);
      expect(usage.enabled, isFalse);
      usage.count(UsageKind.careLogged);
      await usage.resumed();
      expect(usage.pending(me), isEmpty);
    });

    test('UsageCounter.off counts nothing', () async {
      final usage = UsageCounter.off();
      usage.count(UsageKind.todayTick);
      await usage.flush(force: true);
      expect(usage.pending(me), isEmpty);
    });

    test('NoopUsageSink accepts and forgets', () async {
      final usage = UsageCounter(
        sink: const NoopUsageSink(),
        userId: () => me,
        store: store,
        now: () => now,
      );
      usage.count(UsageKind.todayTick);
      await usage.resumed();
      expect(usage.pending(me), isEmpty);
    });
  });

  group('kinds', () {
    test('every kind has a distinct database name', () {
      final keys = UsageKind.values.map((k) => k.key).toSet();
      expect(keys, hasLength(UsageKind.values.length));
      expect(keys, contains('today_tick'));
      for (final kind in UsageKind.values) {
        expect(UsageKind.fromKey(kind.key), kind);
      }
      expect(UsageKind.fromKey('screen_viewed'), isNull);
    });
  });

  group('Supabase', () {
    late List<http.Request> requests;
    late int status;
    late Object answer;

    sb.SupabaseClient client() => sb.SupabaseClient(
      'https://test.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(answer),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
      authOptions: const sb.AuthClientOptions(autoRefreshToken: false),
    );

    setUp(() {
      requests = [];
      status = 200;
      answer = 2;
    });

    test('the sink calls usage_add with the day and the counts', () async {
      await SupabaseUsageSink(client()).add(DateTime(2026, 10, 5), {
        UsageKind.careLogged: 3,
        UsageKind.appOpened: 1,
      });
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/rpc/usage_add');
      expect(jsonDecode(requests.single.body), {
        'p_day': '2026-10-05',
        'p_counts': {'care_logged': 3, 'app_opened': 1},
      });
    });

    test('the sink throws when the backend refuses', () async {
      status = 400;
      answer = {'code': '22023', 'message': 'Day out of range'};
      await expectLater(
        SupabaseUsageSink(
          client(),
        ).add(DateTime(2026, 10, 5), {UsageKind.appOpened: 1}),
        throwsA(isA<sb.PostgrestException>()),
      );
    });

    test('the summary reads usage_summary', () async {
      answer = [
        {
          'day': '2026-10-15',
          'active': 4,
          'today_tick_share': 0.75,
          'kinds': {
            'care_logged': {'accounts': 3, 'total': 9},
            'not_a_kind_yet': {'accounts': 1, 'total': 1},
          },
        },
        {'day': '2026-10-14', 'active': 0, 'today_tick_share': 0, 'kinds': {}},
      ];
      final summary = await SupabaseUsageSummaryRepository(
        client(),
      ).fetch(days: 2);
      expect(jsonDecode(requests.single.body), {'p_days': 2});
      expect(requests.single.url.path, '/rest/v1/rpc/usage_summary');
      expect(summary.days, hasLength(2));
      final today = summary.days.first;
      expect(today.day, DateTime(2026, 10, 15));
      expect(today.active, 4);
      expect(today.todayTickShare, 0.75);
      expect(today.kinds.keys, [UsageKind.careLogged]);
      expect(today.kinds[UsageKind.careLogged]!.total, 9);
      expect(summary.total(UsageKind.careLogged, 7), 9);
      expect(summary.isEmpty, isFalse);
    });
  });
}

class _BrokenStore implements SettingsStore {
  @override
  String? read(String key) => throw StateError('no preferences');

  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('no preferences');
}
