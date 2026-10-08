import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/l10n/settings_store.dart';
import 'package:pet_companion/platform/crash_reporting.dart';

/// Remembers what it was given; fails every send while [failing].
class RecordingCrashSink implements CrashSink {
  final sent = <CrashReport>[];
  int calls = 0;
  bool failing = false;

  @override
  Future<void> send(List<CrashReport> reports) async {
    calls++;
    if (failing) throw StateError('backend down');
    sent.addAll(reports);
  }
}

const environment = CrashEnvironment(
  appVersion: '0.1.0',
  buildNumber: '7',
  platform: 'android',
  osVersion: 'Android 15',
);

CrashReporter reporter({
  CrashSink? sink,
  SettingsStore? store,
  int maxPerSession = 20,
  int maxQueued = 50,
  int maxAttempts = 3,
}) => CrashReporter(
  environment: environment,
  store: store,
  sink: sink,
  locale: () => 'he-IL',
  now: () => DateTime.utc(2026, 10, 8, 9, 30),
  maxPerSession: maxPerSession,
  maxQueued: maxQueued,
  maxAttempts: maxAttempts,
);

void main() {
  group('reporting', () {
    test('a report carries the error, the app and the phone', () async {
      final sink = RecordingCrashSink();
      final r = reporter(sink: sink);
      await r.report(
        StateError('boom'),
        StackTrace.fromString('#0 main\n#1 other'),
        kind: 'caught',
        context: 'saving a walk',
      );

      expect(sink.sent, hasLength(1));
      final report = sink.sent.single;
      expect(report.kind, 'caught');
      expect(report.message, 'Bad state: boom');
      expect(report.stack, '#0 main\n#1 other');
      expect(report.fatal, isFalse);
      expect(report.context, 'saving a walk');
      expect(report.appVersion, '0.1.0');
      expect(report.buildNumber, '7');
      expect(report.platform, 'android');
      expect(report.osVersion, 'Android 15');
      expect(report.locale, 'he-IL');
      expect(report.sessionId, r.sessionId);
      expect(report.occurredAt, DateTime.utc(2026, 10, 8, 9, 30));
      expect(report.toJson()['occurred_at'], '2026-10-08T09:30:00.000Z');
      expect(r.queued, 0);
    });

    test('long messages and stacks are clipped to the table\'s limits', () async {
      final sink = RecordingCrashSink();
      final r = reporter(sink: sink);
      await r.report(
        'm' * 5000,
        StackTrace.fromString('s' * 20000),
        context: 'c' * 1000,
      );
      final report = sink.sent.single;
      expect(report.message.length, CrashReport.maxMessage);
      expect(report.stack!.length, CrashReport.maxStack);
      expect(report.context!.length, CrashReport.maxContext);
    });

    test('the same error reports once a run, and a run has a cap', () async {
      final sink = RecordingCrashSink();
      final r = reporter(sink: sink, maxPerSession: 3);
      final stack = StackTrace.fromString('#0 same');
      await r.report(StateError('again'), stack);
      await r.report(StateError('again'), stack);
      expect(sink.sent, hasLength(1));

      await r.report(StateError('two'), stack);
      await r.report(StateError('three'), stack);
      await r.report(StateError('four'), stack);
      expect(sink.sent.map((s) => s.message), [
        'Bad state: again',
        'Bad state: two',
        'Bad state: three',
      ]);
      expect(r.reported, 3);
    });

    test('an error whose toString throws is still reported', () async {
      final sink = RecordingCrashSink();
      await reporter(sink: sink).report(_Unprintable(), null);
      expect(sink.sent.single.message, '_Unprintable');
      expect(sink.sent.single.stack, isNull);
    });
  });

  group('the queue', () {
    test('a report waits without a sink and goes once there is one', () async {
      final r = reporter();
      await r.report(StateError('early'), null);
      expect(r.queued, 1);

      final sink = RecordingCrashSink();
      r.sink = sink;
      await r.flush();
      expect(sink.sent.single.message, 'Bad state: early');
      expect(r.queued, 0);
    });

    test('a failed send is kept, persisted, and sent on the next start', () async {
      final store = MemorySettingsStore();
      final sink = RecordingCrashSink()..failing = true;
      final r = reporter(sink: sink, store: store);
      await r.report(StateError('offline'), StackTrace.fromString('#0 a'));
      expect(r.queued, 1);
      expect(store.read(CrashReporter.queueKey), contains('offline'));

      // The next run, same phone, backend reachable.
      final later = RecordingCrashSink();
      final restarted = reporter(sink: later, store: store);
      expect(restarted.queued, 1);
      await restarted.flush();
      expect(later.sent.single.message, 'Bad state: offline');
      expect(later.sent.single.stack, '#0 a');
      expect(later.sent.single.sessionId, r.sessionId);
      expect(restarted.queued, 0);
      expect(store.read(CrashReporter.queueKey), isNull);
    });

    test('a report the backend keeps rejecting is dropped', () async {
      final sink = RecordingCrashSink()..failing = true;
      final r = reporter(sink: sink, maxAttempts: 3);
      await r.report(StateError('poison'), null);
      await r.flush();
      expect(r.queued, 1);
      await r.flush();
      expect(r.queued, 0);
      expect(sink.calls, 3);
    });

    test('only the newest reports are kept when many wait', () async {
      final r = reporter(maxQueued: 2);
      await r.report(StateError('one'), null);
      await r.report(StateError('two'), null);
      await r.report(StateError('three'), null);
      expect(r.queued, 2);
      final sink = RecordingCrashSink();
      r.sink = sink;
      await r.flush();
      expect(sink.sent.map((s) => s.message), ['Bad state: two', 'Bad state: three']);
    });

    test('a broken saved queue is ignored', () {
      final store = MemorySettingsStore({CrashReporter.queueKey: '{not json'});
      expect(reporter(store: store).queued, 0);
    });
  });

  group('the handlers', () {
    test('framework errors and uncaught errors reach the reporter', () async {
      final sink = RecordingCrashSink();
      final r = reporter(sink: sink);
      var previousRan = 0;
      final savedFlutter = FlutterError.onError;
      final savedPlatform = PlatformDispatcher.instance.onError;
      FlutterError.onError = (_) => previousRan++;
      PlatformDispatcher.instance.onError = null;
      final restore = installCrashHandlers(r);
      addTearDown(() {
        restore();
        FlutterError.onError = savedFlutter;
        PlatformDispatcher.instance.onError = savedPlatform;
      });

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('overflow'),
          stack: StackTrace.fromString('#0 layout'),
          library: 'rendering library',
          context: ErrorDescription('during layout'),
        ),
      );
      FlutterError.reportError(
        FlutterErrorDetails(exception: StateError('quiet'), silent: true),
      );
      final handled = PlatformDispatcher.instance.onError!(
        ArgumentError('async'),
        StackTrace.fromString('#0 zone'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(handled, isTrue);
      expect(previousRan, 2, reason: 'the earlier handler still runs');
      expect(sink.sent, hasLength(2));
      expect(sink.sent[0].kind, 'flutter');
      expect(sink.sent[0].message, 'Bad state: overflow');
      expect(sink.sent[0].context, 'during layout');
      expect(sink.sent[0].fatal, isFalse);
      expect(sink.sent[1].kind, 'dart');
      expect(sink.sent[1].message, 'Invalid argument(s): async');
      expect(sink.sent[1].fatal, isTrue);

      restore();
      expect(FlutterError.onError, isNot(same(savedFlutter)));
      expect(PlatformDispatcher.instance.onError, isNull);
    });
  });
}

class _Unprintable {
  @override
  String toString() => throw StateError('no words');
}
