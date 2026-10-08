import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../l10n/settings_store.dart';

/// Crash reporting: every error the app does not handle is written to the
/// `crash_reports` table (migration 0024), so the owner learns about a
/// crash on a user's phone without being told.
///
/// ```
/// FlutterError.onError / PlatformDispatcher.onError
///   └─ CrashReporter.report ─ dedupes, caps per session
///        ├─ queue (persisted in the phone's preferences)
///        └─ flush ──> CrashSink (Supabase insert; debug print in the demo)
/// ```
///
/// Reports are queued before they are sent, so a crash while offline, or
/// before the backend is ready, is kept and sent on the next start. A
/// report the backend rejects a few times is dropped rather than retried
/// for ever. `main.dart` installs the handlers first thing and gives the
/// reporter its sink once Supabase is up; [crashReporterProvider] lets a
/// feature report an error it caught but cannot recover from.
class CrashReport {
  const CrashReport({
    required this.kind,
    required this.message,
    required this.stack,
    required this.fatal,
    required this.occurredAt,
    required this.sessionId,
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
    required this.locale,
    this.context,
  });

  /// Where the error came from: `flutter` (the framework, usually a build
  /// or layout error), `dart` (an uncaught error anywhere else; the app
  /// may have lost the operation) or `caught` (a feature reported it).
  final String kind;
  final String message;
  final String? stack;
  final bool fatal;
  final DateTime occurredAt;

  /// One id per app start, so the reports of one run can be read together.
  final String sessionId;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;
  final String locale;

  /// What the app was doing (Flutter's "context" or the feature's words).
  final String? context;

  /// The table's limits (checked there too).
  static const maxMessage = 2000;
  static const maxStack = 8000;
  static const maxContext = 500;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'message': message,
    'stack': stack,
    'fatal': fatal,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'session_id': sessionId,
    'app_version': appVersion,
    'build_number': buildNumber,
    'platform': platform,
    'os_version': osVersion,
    'locale': locale,
    'context': context,
  };

  factory CrashReport.fromJson(Map<String, Object?> json) => CrashReport(
    kind: json['kind'] as String? ?? 'dart',
    message: json['message'] as String? ?? '',
    stack: json['stack'] as String?,
    fatal: json['fatal'] as bool? ?? false,
    occurredAt:
        DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    sessionId: json['session_id'] as String? ?? '',
    appVersion: json['app_version'] as String? ?? '',
    buildNumber: json['build_number'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    osVersion: json['os_version'] as String? ?? '',
    locale: json['locale'] as String? ?? '',
    context: json['context'] as String?,
  );
}

/// Where reports go.
abstract class CrashSink {
  /// Sends [reports] together; throws when none of them was stored.
  Future<void> send(List<CrashReport> reports);
}

/// Writes the reports to `crash_reports`. The signed-in account at sending
/// time is the report's owner (the table only lets an account write its
/// own rows, or none); a report sent while signed out has no owner.
class SupabaseCrashSink implements CrashSink {
  SupabaseCrashSink(this.client);

  final SupabaseClient client;

  @override
  Future<void> send(List<CrashReport> reports) async {
    final userId = client.auth.currentUser?.id;
    await client.from('crash_reports').insert([
      for (final report in reports) {...report.toJson(), 'user_id': userId},
    ]);
  }
}

/// The demo's sink: the console in debug builds, nowhere otherwise.
class DebugPrintCrashSink implements CrashSink {
  const DebugPrintCrashSink();

  @override
  Future<void> send(List<CrashReport> reports) async {
    if (!kDebugMode) return;
    for (final report in reports) {
      debugPrint(
        'PetLoop crash report (${report.kind}${report.fatal ? ', fatal' : ''}): '
        '${report.message}',
      );
    }
  }
}

/// What every report says about the app and the phone.
class CrashEnvironment {
  const CrashEnvironment({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
  });

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;

  /// Reads the app's version and the phone's system; never throws.
  static Future<CrashEnvironment> detect() async {
    var version = 'unknown';
    var build = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {
      // A platform without package info still reports crashes.
    }
    var os = '';
    if (!kIsWeb) {
      try {
        os = Platform.operatingSystemVersion;
      } catch (_) {
        // Not every platform tells.
      }
    }
    return CrashEnvironment(
      appVersion: version,
      buildNumber: build,
      platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      osVersion: os,
    );
  }
}

class _Queued {
  _Queued(this.report, [this.attempts = 0]);

  final CrashReport report;
  int attempts;

  Map<String, Object?> toJson() => {
    'report': report.toJson(),
    'attempts': attempts,
  };

  static _Queued? fromJson(Object? json) {
    if (json is! Map) return null;
    final report = json['report'];
    if (report is! Map) return null;
    return _Queued(
      CrashReport.fromJson(report.cast<String, Object?>()),
      (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Collects the reports of one app run and sends them through [sink].
class CrashReporter {
  CrashReporter({
    required this.environment,
    SettingsStore? store,
    this.sink,
    String Function()? locale,
    DateTime Function()? now,
    this.maxPerSession = 20,
    this.maxQueued = 50,
    this.maxAttempts = 3,
  }) : _store = store ?? MemorySettingsStore(),
       _locale =
           locale ?? (() => PlatformDispatcher.instance.locale.toLanguageTag()),
       _now = now ?? DateTime.now,
       sessionId = const Uuid().v4() {
    _queue.addAll(_load());
  }

  /// The preferences key the unsent reports wait under.
  static const queueKey = 'crash_reports.queue';

  final CrashEnvironment environment;
  final String sessionId;

  /// At most this many reports in one run: a crash loop reports once, not
  /// a thousand times.
  final int maxPerSession;

  /// At most this many unsent reports kept; the oldest go first.
  final int maxQueued;

  /// A report the sink rejected this many times is dropped.
  final int maxAttempts;

  /// Where reports go; `null` until the backend is ready (they queue).
  CrashSink? sink;

  final SettingsStore _store;
  final String Function() _locale;
  final DateTime Function() _now;
  final List<_Queued> _queue = [];
  final Set<String> _seen = {};
  int _reported = 0;
  bool _flushing = false;

  /// How many reports wait to be sent.
  int get queued => _queue.length;

  /// How many reports this run has made (sent or queued).
  int get reported => _reported;

  /// Records [error] and tries to send everything waiting. Never throws:
  /// a failure in reporting must not add to the crash.
  Future<void> report(
    Object error,
    StackTrace? stack, {
    String kind = 'dart',
    bool fatal = false,
    String? context,
  }) async {
    try {
      final message = _clip(_describe(error), CrashReport.maxMessage);
      final trace = stack == null ? null : _clip('$stack', CrashReport.maxStack);
      final key = '$kind|$message|${_firstLine(trace)}';
      if (_reported >= maxPerSession || !_seen.add(key)) return;
      _reported++;
      _queue.add(
        _Queued(
          CrashReport(
            kind: kind,
            message: message,
            stack: trace,
            fatal: fatal,
            occurredAt: _now(),
            sessionId: sessionId,
            appVersion: environment.appVersion,
            buildNumber: environment.buildNumber,
            platform: environment.platform,
            osVersion: environment.osVersion,
            locale: _safe(_locale, ''),
            context: context == null
                ? null
                : _clip(context, CrashReport.maxContext),
          ),
        ),
      );
      while (_queue.length > maxQueued) {
        _queue.removeAt(0);
      }
      await _persist();
      await flush();
    } catch (_) {
      // Reporting never throws.
    }
  }

  /// Sends what waits, in order, until the queue is empty or a send fails.
  /// A batch the sink has rejected [maxAttempts] times is dropped.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_queue.isNotEmpty) {
        final sink = this.sink;
        if (sink == null) return;
        final batch = List.of(_queue);
        try {
          await sink.send([for (final q in batch) q.report]);
          _queue.removeWhere(batch.contains);
        } catch (_) {
          for (final q in batch) {
            q.attempts++;
          }
          _queue.removeWhere((q) => q.attempts >= maxAttempts);
          await _persist();
          return;
        }
        await _persist();
      }
    } finally {
      _flushing = false;
    }
  }

  List<_Queued> _load() {
    try {
      final raw = _store.read(queueKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final item in list) ?_Queued.fromJson(item)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    try {
      await _store.write(
        queueKey,
        _queue.isEmpty
            ? null
            : jsonEncode([for (final q in _queue) q.toJson()]),
      );
    } catch (_) {
      // The queue then lives for this run only.
    }
  }

  static String _describe(Object error) {
    if (error is FlutterErrorDetails) return error.exceptionAsString();
    return _safe(() => '$error', error.runtimeType.toString());
  }

  static String _clip(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  static String _firstLine(String? text) {
    if (text == null) return '';
    final end = text.indexOf('\n');
    return end < 0 ? text : text.substring(0, end);
  }

  static String _safe(String Function() read, String fallback) {
    try {
      return read();
    } catch (_) {
      return fallback;
    }
  }
}

/// Routes the framework's and the platform's unhandled errors to
/// [reporter]. Whatever handler was installed before (in debug builds,
/// the one that paints the red screen and prints) still runs.
///
/// Returns a function that restores the previous handlers (tests).
void Function() installCrashHandlers(CrashReporter reporter) {
  final previousFlutter = FlutterError.onError;
  final previousPlatform = PlatformDispatcher.instance.onError;

  FlutterError.onError = (details) {
    (previousFlutter ?? FlutterError.presentError)(details);
    if (details.silent) return;
    reporter.report(
      details.exception,
      details.stack,
      kind: 'flutter',
      context: details.context?.toDescription() ?? details.library,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (previousPlatform != null) {
      previousPlatform(error, stack);
    } else if (kDebugMode) {
      debugPrint('Unhandled error: $error\n$stack');
    }
    reporter.report(error, stack, fatal: true);
    return true;
  };

  return () {
    FlutterError.onError = previousFlutter;
    PlatformDispatcher.instance.onError = previousPlatform;
  };
}

/// The app's reporter, for a feature to report an error it caught but
/// cannot recover from (`kind: 'caught'`); `null` in tests.
final crashReporterProvider = Provider<CrashReporter?>((ref) => null);
