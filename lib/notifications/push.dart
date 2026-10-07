/// Push notifications: what the server sends this phone about community
/// activity (comments on the member's posts, likes, answers to their chat
/// messages), through Firebase Cloud Messaging.
///
/// - [PushMessaging]: the phone's messaging (Firebase), or a fake in
///   tests. [pushMessagingProvider] is `null` unless `main.dart` sets it,
///   so tests, the web and builds without Firebase settings run without
///   push.
/// - [PushDeviceRepository]: tells the server which account this phone
///   belongs to (`register_push_device`, `unregister_push_device`).
/// - [PushRegistrar]: keeps that registration in step with the signed-in
///   account, the phone's token and the app's language, and takes the
///   phone off before signing out.
/// - [pushArrivalsProvider]: counts notifications that arrived while the
///   app was open, so pages that show activity refresh.
///
/// A tapped notification's target (`post:<id>`, `room:<id>`) goes through
/// the same path as a tapped reminder (`notificationTapsProvider`,
/// `openNotificationTarget`).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import '../l10n/l10n.dart';

/// A notification that arrived while the app was open.
@immutable
class PushArrival {
  const PushArrival({required this.kind, required this.target});

  /// `comment`, `like` or `reply`.
  final String kind;

  /// Where a tap would lead: `post:<id>` or `room:<id>`.
  final String target;
}

/// The phone's push messaging.
abstract class PushMessaging {
  /// `android` or `ios`, as the server stores it.
  String get platform;

  /// Asks the owner to allow notifications (once; later calls answer at
  /// once). Whether they are allowed.
  Future<bool> requestPermission();

  /// This phone's address for the server; `null` when there is none yet.
  Future<String?> token();

  /// A new address replacing the old one.
  Stream<String> get tokenRefreshes;

  /// Notifications that arrive while the app is open (the phone shows
  /// none then).
  Stream<PushArrival> get arrivals;

  /// The targets of notifications tapped while the app was in the
  /// background.
  Stream<String> get taps;

  /// The target of the notification that started the app, once.
  Future<String?> initialTap();

  /// Forgets this phone's address: the server's sends to it fail from
  /// then on, and it removes it.
  Future<void> deleteToken();
}

final pushMessagingProvider = Provider<PushMessaging?>((ref) => null);

/// [PushMessaging] backed by Firebase Cloud Messaging (Android for now).
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging._(this._messaging);

  final FirebaseMessaging _messaging;

  /// Starts Firebase with the build's settings and creates the phone's
  /// "Community" channel. `null` without settings, on the web, on iOS
  /// (until its push setup exists), or when Firebase does not start.
  static Future<FirebasePushMessaging?> start({
    required String channelName,
  }) async {
    if (!AppConfig.hasFirebase || kIsWeb || !Platform.isAndroid) return null;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          appId: AppConfig.firebaseAppId,
          messagingSenderId: AppConfig.firebaseSenderId,
          projectId: AppConfig.firebaseProjectId,
        ),
      );
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              'community',
              channelName,
              importance: Importance.high,
            ),
          );
      return FirebasePushMessaging._(FirebaseMessaging.instance);
    } catch (error) {
      debugPrint('PetLoop: push notifications are off: $error');
      return null;
    }
  }

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<PushArrival> get arrivals =>
      FirebaseMessaging.onMessage.map(_arrivalOf);

  @override
  Stream<String> get taps => FirebaseMessaging.onMessageOpenedApp
      .map((message) => _arrivalOf(message).target)
      .where((target) => target.isNotEmpty);

  @override
  Future<String?> initialTap() async {
    final message = await _messaging.getInitialMessage();
    final target = message == null ? '' : _arrivalOf(message).target;
    return target.isEmpty ? null : target;
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  static PushArrival _arrivalOf(RemoteMessage message) => PushArrival(
    kind: message.data['kind'] as String? ?? '',
    target: message.data['target'] as String? ?? '',
  );
}

/// Where the server keeps which phones belong to which account.
abstract class PushDeviceRepository {
  Future<void> register({
    required String token,
    required String platform,
    required String language,
  });

  Future<void> unregister(String token);
}

class SupabasePushDeviceRepository implements PushDeviceRepository {
  SupabasePushDeviceRepository(this._client);

  final sb.SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required String language,
  }) async {
    await _client.rpc(
      'register_push_device',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_language': language,
      },
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_push_device', params: {'p_token': token});
  }
}

final pushDeviceRepositoryProvider = Provider<PushDeviceRepository?>(
  (ref) => AppConfig.hasSupabase
      ? SupabasePushDeviceRepository(sb.Supabase.instance.client)
      : null,
);

/// Counts the notifications that arrived while the app was open.
class PushArrivals extends Notifier<int> {
  @override
  int build() => 0;

  void arrived() => state++;
}

final pushArrivalsProvider = NotifierProvider<PushArrivals, int>(
  PushArrivals.new,
);

/// Keeps the server's record of this phone in step with the signed-in
/// account, the phone's token and the app's language.
///
/// Signing in registers the phone (and asks once for permission to show
/// notifications); a new token or another language registers it again.
/// [signingOut] removes it while the session still exists. A session that
/// ended without that (signed out on another device, an expired session)
/// forgets the phone's token, so the server's next send fails and the
/// server removes it.
class PushRegistrar {
  PushRegistrar({
    required PushMessaging messaging,
    required PushDeviceRepository devices,
  }) : _messaging = messaging,
       _devices = devices;

  final PushMessaging _messaging;
  final PushDeviceRepository _devices;

  String? _userId;
  String _language = 'he';
  String? _registeredToken;
  String? _registeredFor;
  String? _registeredLanguage;
  bool _asked = false;
  bool _disposed = false;
  StreamSubscription<String>? _refreshes;
  Future<void> _queue = Future.value();

  /// The token the server has for the current account, for tests.
  @visibleForTesting
  String? get registeredToken => _registeredToken;

  /// Every change so far, done (for tests).
  @visibleForTesting
  Future<void> get idle => _queue;

  void start() {
    _refreshes = _messaging.tokenRefreshes.listen(
      (_) => _enqueue(_sync),
      onError: (_) {},
    );
  }

  void dispose() {
    _disposed = true;
    _refreshes?.cancel();
  }

  void userChanged(String? userId) {
    final previous = _userId;
    _userId = userId;
    if (userId == null) {
      if (previous != null && _registeredToken != null) {
        _enqueue(_forgetToken);
      }
      return;
    }
    _enqueue(_sync);
  }

  void languageChanged(String language) {
    _language = language == 'en' ? 'en' : 'he';
    if (_userId != null) _enqueue(_sync);
  }

  /// Takes this phone off the account before signing out.
  Future<void> signingOut() {
    _enqueue(() async {
      final token = _registeredToken;
      if (token == null) return;
      try {
        await _devices.unregister(token);
      } finally {
        await _forgetToken();
      }
    });
    return _queue;
  }

  void _enqueue(Future<void> Function() step) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await step();
      } catch (error) {
        debugPrint('PetLoop: push registration step failed: $error');
      }
    });
  }

  Future<void> _sync() async {
    final userId = _userId;
    if (userId == null) return;
    if (!_asked) {
      _asked = true;
      await _messaging.requestPermission();
    }
    final token = await _messaging.token();
    if (token == null || _userId != userId) return;
    if (token == _registeredToken &&
        userId == _registeredFor &&
        _language == _registeredLanguage) {
      return;
    }
    await _devices.register(
      token: token,
      platform: _messaging.platform,
      language: _language,
    );
    _registeredToken = token;
    _registeredFor = userId;
    _registeredLanguage = _language;
  }

  Future<void> _forgetToken() async {
    _registeredToken = null;
    _registeredFor = null;
    _registeredLanguage = null;
    await _messaging.deleteToken();
  }
}

/// The phone's registrar; `null` without push messaging or a server.
final pushRegistrarProvider = Provider<PushRegistrar?>((ref) {
  final messaging = ref.watch(pushMessagingProvider);
  final devices = ref.watch(pushDeviceRepositoryProvider);
  if (messaging == null || devices == null) return null;
  final registrar = PushRegistrar(messaging: messaging, devices: devices)
    ..start()
    ..languageChanged(ref.read(appLocaleProvider).languageCode);
  ref.listen(
    authControllerProvider.select((auth) => auth.value?.id),
    (_, id) => registrar.userChanged(id),
    fireImmediately: true,
  );
  ref.listen(
    appLocaleProvider,
    (_, locale) => registrar.languageChanged(locale.languageCode),
  );
  ref.onDispose(registrar.dispose);
  return registrar;
});
