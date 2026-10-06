import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/access/access_admin_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import '../helpers.dart';

class HistoryRepository extends FakeAccessRepository {
  final cursors = <int?>[];
  bool fail = false;
  @override
  Future<AccessAuditPage> history(
    AccessAuditQuery query, {
    int? beforeId,
    int limit = 50,
  }) {
    cursors.add(beforeId);
    if (fail) return Future.error(StateError('offline'));
    return super.history(query, beforeId: beforeId, limit: limit);
  }
}

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Feature access'));
  await tester.tap(find.text('Feature access'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Audit'));
  await tester.tap(find.text('Audit'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'open history details are hidden when administration is revoked',
    (tester) async {
      final repository = HistoryRepository();
      await repository.change('feature', {'id': 'care', 'enabled': true});
      await pumpApp(
        tester,
        now: DateTime(2025, 6, 10),
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      );
      await signInAsDemo(tester);
      await openHistory(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AccessAdministrationScreen)),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Feature settings'));
      await tester.pumpAndSettle();
      expect(find.text('Before'), findsOneWidget);
      repository.features['access'] = false;
      await container.read(accessProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(find.text('Before'), findsNothing);
      expect(find.text('After'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved history can be reopened, filtered, and read in detail', (
    tester,
  ) async {
    final repository = HistoryRepository();
    await repository.change('feature', {'id': 'care', 'enabled': false});
    await repository.change('feature', {'id': 'care', 'enabled': true});
    await pumpApp(
      tester,
      now: DateTime(2025, 6, 10),
      overrides: [accessRepositoryProvider.overrideWithValue(repository)],
    );
    await signInAsDemo(tester);
    await openHistory(tester);
    expect(find.widgetWithText(ListTile, 'Feature settings'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(ListTile, 'Feature settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Before'), findsOneWidget);
    expect(find.text('After'), findsOneWidget);
    expect(find.textContaining('"enabled": false'), findsOneWidget);
    expect(find.textContaining('demo@petloop.app'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing@example.test');
    await tester.tap(find.text('Search history'));
    await tester.pumpAndSettle();
    expect(find.text('No administration actions found.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Feature settings'), findsNWidgets(2));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openHistory(tester);
    expect(find.widgetWithText(ListTile, 'Feature settings'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'older saved history is accessible beyond the first 100 entries',
    (tester) async {
      final repository = HistoryRepository();
      for (var i = 0; i < 121; i++) {
        await repository.change('feature', {'id': 'care', 'enabled': i.isEven});
      }
      await pumpApp(
        tester,
        now: DateTime(2025, 6, 10),
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      );
      await signInAsDemo(tester);
      await openHistory(tester);
      for (var page = 0; page < 2; page++) {
        await tester.scrollUntilVisible(
          find.text('Load older actions'),
          500,
          scrollable: find.descendant(
            of: find.byKey(const Key('access-audit-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.text('Load older actions'));
        await tester.pumpAndSettle();
      }
      expect(repository.cursors, [null, 72, 22]);
      expect(find.text('Load older actions'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history fetch failure gives retry without silently claiming empty history',
    (tester) async {
      final repository = HistoryRepository()..fail = true;
      await repository.change('feature', {'id': 'care', 'enabled': true});
      await pumpApp(
        tester,
        now: DateTime(2025, 6, 10),
        overrides: [accessRepositoryProvider.overrideWithValue(repository)],
      );
      await signInAsDemo(tester);
      await openHistory(tester);
      expect(
        find.textContaining('Could not load saved history'),
        findsOneWidget,
      );
      expect(find.text('No administration actions found.'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Feature settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Hebrew history filters fit a narrow screen', (tester) async {
    await pumpApp(
      tester,
      language: AppLanguage.hebrew,
      size: const Size(320, 740),
      now: DateTime(2025, 6, 10),
    );
    await signInAsDemo(tester);
    final context = tester.element(find.byType(Scaffold).first);
    openAccessAdministration(context);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('היסטוריה'));
    await tester.tap(find.text('היסטוריה'));
    await tester.pumpAndSettle();
    expect(find.text('לא נמצאו פעולות ניהול.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
