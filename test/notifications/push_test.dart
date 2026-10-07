import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/navigation/app_router.dart';
import 'package:pet_companion/notifications/notifications.dart';
import 'package:pet_companion/services/community/data/push_preferences_repository.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import '../helpers.dart';

class FakePushMessaging implements PushMessaging {
  String? current = 'token-1';
  var permissionAsks = 0;
  var deletes = 0;
  final refreshes = StreamController<String>.broadcast();
  final arrivalsController = StreamController<PushArrival>.broadcast();
  final tapsController = StreamController<String>.broadcast();
  String? initial;

  @override
  String get platform => 'android';

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return true;
  }

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<PushArrival> get arrivals => arrivalsController.stream;

  @override
  Stream<String> get taps => tapsController.stream;

  @override
  Future<String?> initialTap() async => initial;

  @override
  Future<void> deleteToken() async {
    deletes++;
    current = 'token-after-delete';
  }
}

class FakePushDevices implements PushDeviceRepository {
  final calls = <String>[];

  @override
  Future<void> register({required String token, required String platform, required String language}) async {
    calls.add('register $token $platform $language');
  }

  @override
  Future<void> unregister(String token) async {
    calls.add('unregister $token');
  }
}

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('registrar', () {
    late FakePushMessaging messaging;
    late FakePushDevices devices;
    late PushRegistrar registrar;

    setUp(() {
      messaging = FakePushMessaging();
      devices = FakePushDevices();
      registrar = PushRegistrar(messaging: messaging, devices: devices)..start();
    });
    tearDown(() => registrar.dispose());

    test('signing in registers the phone in the app\'s language, asking once', () async {
      registrar.languageChanged('he');
      registrar.userChanged('u1');
      await registrar.idle;
      expect(devices.calls, ['register token-1 android he']);
      expect(messaging.permissionAsks, 1);

      // Nothing changed: nothing sent again.
      registrar.userChanged('u1');
      await registrar.idle;
      expect(devices.calls, hasLength(1));
      expect(messaging.permissionAsks, 1);
    });

    test('a new language or a new token registers again', () async {
      registrar.userChanged('u1');
      await registrar.idle;
      registrar.languageChanged('en');
      await registrar.idle;
      messaging.current = 'token-2';
      messaging.refreshes.add('token-2');
      await Future<void>.delayed(Duration.zero);
      await registrar.idle;
      expect(devices.calls, [
        'register token-1 android he',
        'register token-1 android en',
        'register token-2 android en',
      ]);
    });

    test('signing out takes the phone off, then forgets its token', () async {
      registrar.userChanged('u1');
      await registrar.idle;
      await registrar.signingOut();
      expect(devices.calls.last, 'unregister token-1');
      expect(messaging.deletes, 1);
      expect(registrar.registeredToken, isNull);

      // The sign-out itself then changes nothing more.
      registrar.userChanged(null);
      await registrar.idle;
      expect(messaging.deletes, 1);
    });

    test('a session that ended elsewhere forgets the token so the server drops it', () async {
      registrar.userChanged('u1');
      await registrar.idle;
      registrar.userChanged(null);
      await registrar.idle;
      expect(devices.calls, ['register token-1 android he']);
      expect(messaging.deletes, 1);
    });

    test('another account on the same phone registers it for that account', () async {
      registrar.userChanged('u1');
      await registrar.idle;
      await registrar.signingOut();
      registrar.userChanged(null);
      registrar.userChanged('u2');
      await registrar.idle;
      expect(devices.calls.last, 'register token-after-delete android he');
    });
  });

  test('signing out runs the before-sign-out work first, and goes on when it fails', () async {
    final order = <String>[];
    final auth = FakeAuthRepository(latency: Duration.zero);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        beforeSignOutProvider.overrideWithValue([
          () async => order.add('push off'),
          () async => throw StateError('offline'),
        ]),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await container
        .read(authControllerProvider.notifier)
        .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword);
    expect(await container.read(authControllerProvider.notifier).signOut(), isTrue);
    expect(order, ['push off']);
    expect(container.read(authControllerProvider).value, isNull);
  });

  group('in the app', () {
    late FakePushMessaging messaging;
    late FakePushDevices devices;
    late FakePushPreferencesRepository preferences;

    List<dynamic> overrides() => [
      pushMessagingProvider.overrideWithValue(messaging),
      pushDeviceRepositoryProvider.overrideWithValue(devices),
      pushPreferencesRepositoryProvider.overrideWithValue(preferences),
      feedRepositoryProvider.overrideWithValue(FakeFeedRepository(latency: Duration.zero)),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository(latency: Duration.zero)),
    ];

    setUp(() {
      messaging = FakePushMessaging();
      devices = FakePushDevices();
      preferences = FakePushPreferencesRepository();
    });

    testWidgets('signing in registers the phone; a tapped answer opens its room', (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [...overrides()]);
      await signInAsDemo(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(devices.calls, ['register token-1 android en']);

      messaging.tapsController.add('room:puppies');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(headerTitle('Puppies'), findsOneWidget);
    });

    testWidgets('a tapped comment opens its post, even one the feed has not loaded', (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [...overrides()]);
      await signInAsDemo(tester);
      await tester.pumpAndSettle();
      // The demo account's own post, as the server would name it.
      messaging.tapsController.add('post:p4');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(headerTitle('Post'), findsOneWidget);
      expect(find.textContaining('Kelly is thirteen'), findsOneWidget);
      // The Community tab's other loads answer on the demo backend's delay.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a notification that started the app opens its target once signed in', (tester) async {
      messaging.initial = 'room:general';
      await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [...overrides()]);
      await signInAsDemo(tester);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(headerTitle('General'), findsOneWidget);
    });

    testWidgets('an arrival while the app is open is counted', (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [...overrides()]);
      await signInAsDemo(tester);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
      expect(container.read(pushArrivalsProvider), 0);
      messaging.arrivalsController.add(const PushArrival(kind: 'comment', target: 'post:p4'));
      await tester.pumpAndSettle();
      expect(container.read(pushArrivalsProvider), 1);
    });

    testWidgets('Settings shows the community switches and saves them', (tester) async {
      await pumpApp(tester, now: DateTime(2025, 6, 10, 9), overrides: [...overrides()]);
      await signInAsDemo(tester);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
      container.read(routerProvider).push('/settings');
      await tester.pumpAndSettle();
      expect(find.byKey(SettingsScreen.screenKey), findsOneWidget);

      final likes = find.byKey(const ValueKey('push-likes'));
      await tester.scrollUntilVisible(likes, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Answers to my chat messages'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(likes).value, isFalse);

      await tester.tap(likes);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(likes).value, isTrue);
      expect(preferences.saved['demo']!.likes, isTrue);
      expect(preferences.saved['demo']!.replies, isTrue);
    });
  });

  testWidgets('without push the Settings page has no community switches', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
    container.read(routerProvider).push('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Answers to my chat messages'), findsNothing);
  });
}
