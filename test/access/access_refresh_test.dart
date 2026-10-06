import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' show ClientException;
import 'package:pet_companion/access/access_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, AuthRetryableFetchException, PostgrestException;

import '../helpers.dart';

/// The demo policy, with background refreshes that can be made to fail.
class FlakyAccessRepository extends FakeAccessRepository {
  Object? failWith;

  @override
  Future<AccessSnapshot> fetch(String? userId) async {
    final error = failWith;
    if (error != null) throw error;
    return super.fetch(userId);
  }
}

Future<ProviderContainer> _loaded(
  FlakyAccessRepository repository, {
  Duration? grace,
}) async {
  final container = ProviderContainer(
    overrides: [
      accessRepositoryProvider.overrideWithValue(repository),
      if (grace != null) accessOfflineGraceProvider.overrideWithValue(grace),
    ],
  );
  addTearDown(container.dispose);
  container.listen(accessProvider, (_, _) {});
  await container.read(accessProvider.future);
  return container;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('a failed background refresh', () {
    for (final (name, error) in [
      ('offline', ClientException('Connection failed')),
      ('a timeout', TimeoutException('no answer')),
      ('a gateway error', const PostgrestException(message: 'Bad gateway', code: '503')),
      ('a token refresh that could not reach the server', AuthRetryableFetchException()),
    ]) {
      test('keeps the confirmed permissions through $name', () async {
        final repository = FlakyAccessRepository();
        final container = await _loaded(repository);
        repository.failWith = error;

        await container.read(accessProvider.notifier).refresh();

        final access = container.read(accessProvider);
        expect(access.hasError, isFalse);
        expect(access.requireValue.can('pets.view'), isTrue);
        expect(container.read(capabilityProvider('pets.view')), isTrue);
      });
    }

    for (final (name, error) in [
      ('a permission error', const PostgrestException(message: 'denied', code: '42501')),
      ('an expired session', const PostgrestException(message: 'JWT expired', code: 'PGRST301')),
      ('an auth error', const AuthException('Invalid refresh token')),
      ('an unreadable answer', const FormatException('not JSON')),
    ]) {
      test('drops the permissions on $name', () async {
        final repository = FlakyAccessRepository();
        final container = await _loaded(repository);
        repository.failWith = error;

        await container.read(accessProvider.notifier).refresh();

        expect(container.read(accessProvider).hasError, isTrue);
        expect(container.read(capabilityProvider('pets.view')), isFalse);
      });
    }

    test('drops the permissions once the offline grace period is over', () async {
      final repository = FlakyAccessRepository();
      final container = await _loaded(repository, grace: Duration.zero);
      repository.failWith = ClientException('Connection failed');

      await container.read(accessProvider.notifier).refresh();

      expect(container.read(accessProvider).hasError, isTrue);
      expect(container.read(capabilityProvider('pets.view')), isFalse);
    });

    test('takes the next successful answer, including a revocation', () async {
      final repository = FlakyAccessRepository();
      final container = await _loaded(repository);
      repository.failWith = ClientException('Connection failed');
      await container.read(accessProvider.notifier).refresh();

      repository
        ..failWith = null
        ..features['pets'] = false;
      await container.read(accessProvider.notifier).refresh();

      expect(container.read(accessProvider).hasError, isFalse);
      expect(container.read(capabilityProvider('pets.view')), isFalse);
    });
  });

  testWidgets('going offline for a moment keeps the open screen', (
    tester,
  ) async {
    final repository = FlakyAccessRepository();
    await pumpApp(
      tester,
      now: DateTime(2025, 6, 10),
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
    );
    await signInAsDemo(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Feature access'));
    await tester.tap(find.text('Feature access'));
    await tester.pumpAndSettle();
    expect(find.text('Users'), findsOneWidget);

    repository.failWith = ClientException('Connection failed');
    final container = ProviderScope.containerOf(
      tester.element(find.text('Users')),
    );
    await container.read(accessProvider.notifier).refresh();
    await tester.pumpAndSettle();

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Could not load account permissions'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
