import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/widgets/add_sheet.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/area_disc.dart';

import '../helpers.dart';

/// The ids of the Add sheet's rows, top to bottom.
List<String> _rows(WidgetTester tester) => [
  for (final element in find
      .descendant(
        of: find.byKey(AddSheet.sheetKey),
        matching: find.byWidgetPredicate(
          (w) => w is InkWell && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('add-'),
        ),
      )
      .evaluate())
    (element.widget.key! as ValueKey<String>).value.substring(4),
];

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(AddFab.fabKey));
  await tester.pumpAndSettle();
  expect(find.byKey(AddSheet.sheetKey), findsOneWidget);
}

Future<void> _closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(AddSheet.sheetKey))).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Home has no "+"; every other tab has one, with its own rows', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    expect(find.byKey(AddFab.fabKey), findsNothing, reason: 'Home has no plus');

    for (final (tab, title, rows) in [
      ('Health', 'Add to Health', ['quick-log', 'record', 'appointment', 'medicine', 'routine']),
      (
        'Community',
        'Add to Community',
        ['post-moment', 'post-question', 'post-recommendation', 'post-lostFound', 'new-chat'],
      ),
      ('Outside', 'Add to Outside', ['plan-walk', 'going-now', 'suggest-park']),
      ('Store', 'Add to Store', ['share-deal', 'regular-product', 'expense']),
    ]) {
      await _openTab(tester, tab);
      // 56 px, round, named for a screen reader.
      expect(find.byKey(AddFab.fabKey), findsOneWidget, reason: tab);
      expect(tester.getSize(find.byKey(AddFab.fabKey)), const Size.square(56), reason: tab);
      expect(find.byTooltip(title), findsOneWidget, reason: tab);

      await _openSheet(tester);
      expect(find.descendant(of: find.byKey(AddSheet.sheetKey), matching: find.text(title)), findsOneWidget);
      expect(_rows(tester), rows, reason: tab);
      // Each row leads with an area disc.
      expect(
        find.descendant(of: find.byKey(AddSheet.sheetKey), matching: find.byType(AreaDisc)),
        findsNWidgets(rows.length),
      );
      expect(tester.takeException(), isNull);
      await _closeSheet(tester);
    }

    // Back on Home, still no plus.
    await _openTab(tester, 'Home');
    expect(find.byKey(AddFab.fabKey), findsNothing);
  });

  testWidgets('the rows follow the account\'s capabilities; no row, no "+"', (tester) async {
    final access = FakeAccessRepository()
      ..users['demo'] = {
        'community.chat.private': AccessRule.deny,
        'store.deals.share': AccessRule.deny,
        'basket.edit': AccessRule.deny,
        'community.meetups.post': AccessRule.deny,
        'community.parks.suggest': AccessRule.deny,
      };
    await pumpApp(tester, overrides: [accessRepositoryProvider.overrideWithValue(access)]);
    await signInAsDemo(tester);

    await _openTab(tester, 'Community');
    await _openSheet(tester);
    expect(_rows(tester), ['post-moment', 'post-question', 'post-recommendation', 'post-lostFound']);
    await _closeSheet(tester);

    await _openTab(tester, 'Store');
    await _openSheet(tester);
    expect(_rows(tester), ['expense']);
    await _closeSheet(tester);

    await _openTab(tester, 'Outside');
    expect(find.byKey(AddFab.fabKey), findsNothing, reason: 'nothing to add outside');
  });

  testWidgets('a row closes the sheet and opens its form: a question opens the composer on Question', (
    tester,
  ) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await _openTab(tester, 'Community');
    await _openSheet(tester);
    await tester.tap(find.byKey(AddSheet.rowKey('post-question')));
    await tester.pumpAndSettle();

    expect(find.byKey(AddSheet.sheetKey), findsNothing);
    final question = tester.widget<ChoiceChip>(find.byKey(const ValueKey('compose-kind-question')));
    expect(question.selected, isTrue);
    final moment = tester.widget<ChoiceChip>(find.byKey(const ValueKey('compose-kind-moment')));
    expect(moment.selected, isFalse);
  });

  testWidgets('Health: Quick log from the "+" opens the Quick log sheet', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);
    await _openTab(tester, 'Health');
    await _openSheet(tester);
    await tester.tap(find.byKey(AddSheet.rowKey('quick-log')));
    await tester.pumpAndSettle();
    expect(find.byKey(AddSheet.sheetKey), findsNothing);
    expect(find.text('Quick log for Kelly'), findsOneWidget);
  });
}
