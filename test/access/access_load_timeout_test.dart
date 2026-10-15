import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';

import '../helpers.dart';

/// A permissions backend that is not the in-memory demo one (so the app
/// really waits on it, as on a phone), and that can be made to never answer.
class _SlowAccessRepository implements AccessRepository {
  final _demo = FakeAccessRepository();
  bool hang = true;

  @override
  Future<AccessSnapshot> fetch(String? userId) =>
      hang ? Completer<AccessSnapshot>().future : _demo.fetch(userId);

  @override
  Future<Map<String, dynamic>> administration() => _demo.administration();

  @override
  Future<AccessSnapshot> preview(String userId) => _demo.preview(userId);

  @override
  Future<void> change(String action, Map<String, dynamic> values) =>
      _demo.change(action, values);

  @override
  Future<AccessAuditPage> history(
    AccessAuditQuery query, {
    int? beforeId,
    int limit = 50,
  }) => _demo.history(query, beforeId: beforeId, limit: limit);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'a permissions load that never answers ends on "Could not load" with Retry, not on the loading screen',
    (tester) async {
      final repository = _SlowAccessRepository();
      await pumpApp(
        tester,
        overrides: [
          accessRepositoryProvider.overrideWithValue(repository),
          accessLoadTimeoutProvider.overrideWithValue(const Duration(seconds: 2)),
        ],
      );
      await signInAsDemo(tester);

      // Still waiting: the loading screen.
      expect(find.text('Could not load account permissions'), findsNothing);

      // Past the limit: the error page, with a way out.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Could not load account permissions'), findsOneWidget);

      // The connection is back: Retry reaches Home.
      repository.hang = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Could not load account permissions'), findsNothing);
      expect(find.text('Feeding'), findsOneWidget);
    },
  );

  test('the limit is 15 seconds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(accessLoadTimeoutProvider), const Duration(seconds: 15));
  });
}
