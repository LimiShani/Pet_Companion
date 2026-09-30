import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/saved_deals_screen.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const rope = 'd-rope-tug-toy';
  final ropeHeart = find.byKey(const ValueKey('save-$rope'));

  String? heartTooltip(WidgetTester tester) =>
      tester.widget<IconButton>(find.descendant(of: ropeHeart, matching: find.byType(IconButton))).tooltip;

  Future<void> openSaved(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Saved deals'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedDealsScreen), findsOneWidget);
  }

  testWidgets('the heart on a card saves the deal, and the Saved view lists it', (tester) async {
    final store = await pumpStore(tester);

    expect(heartTooltip(tester), 'Save deal');
    await tester.tap(ropeHeart);
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    expect(heartTooltip(tester), 'Remove from saved');
    expect(await store.fetchSavedDealIds(userId: demoUserId), {rope});

    await openSaved(tester);
    expect(find.text('1 saved deal'), findsOneWidget);
    expect(shownDealIds(tester), [rope]);
    expect(find.text('Squeaky rope tug toy, 2 pack'), findsOneWidget);
  });

  testWidgets('unsaving from the Saved view removes the deal and shows the empty state', (tester) async {
    final store = fakeStore();
    await store.setSaved(userId: demoUserId, dealId: rope, saved: true);
    await pumpStore(tester, repository: store);

    await openSaved(tester);
    expect(shownDealIds(tester), [rope]);

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();

    expect(find.text('No saved deals yet'), findsOneWidget);
    expect(await store.fetchSavedDealIds(userId: demoUserId), isEmpty);

    // "Browse deals" goes back to the grid, where the heart is empty again.
    await tester.tap(find.text('Browse deals'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedDealsScreen), findsNothing);
    expect(heartTooltip(tester), 'Save deal');
  });

  testWidgets('the heart on the deal page saves and unsaves', (tester) async {
    final store = await pumpStore(tester);
    await openDeal(tester, rope);

    await tester.tap(find.byTooltip('Save deal'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from saved'), findsOneWidget);
    expect(await store.fetchSavedDealIds(userId: demoUserId), {rope});

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();
    expect(find.text('Removed from saved deals'), findsOneWidget);
    expect(find.byTooltip('Save deal'), findsOneWidget);
    expect(await store.fetchSavedDealIds(userId: demoUserId), isEmpty);
  });

  testWidgets('saved deals belong to the account', (tester) async {
    final store = fakeStore();
    await store.setSaved(userId: 'someone-else', dealId: rope, saved: true);
    await pumpStore(tester, repository: store);

    expect(heartTooltip(tester), 'Save deal');
    await openSaved(tester);
    expect(find.text('No saved deals yet'), findsOneWidget);
  });

  testWidgets('the Saved view lists expired deals last and opens a deal page', (tester) async {
    final store = fakeStore();
    for (final id in ['d-cooling-mat', 'd-first-aid-kit', 'd-chicken-rice-cans']) {
      await store.setSaved(userId: demoUserId, dealId: id, saved: true);
    }
    await pumpStore(tester, repository: store);

    await openSaved(tester);
    expect(find.text('3 saved deals'), findsOneWidget);
    expect(shownDealIds(tester), ['d-chicken-rice-cans', 'd-first-aid-kit', 'd-cooling-mat']);
    expect(find.text('Expired'), findsOneWidget);

    await openDeal(tester, 'd-first-aid-kit');
    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect(find.text('Pet first aid kit, 40 pieces'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedDealsScreen), findsOneWidget);
  });

  testWidgets('a heart that cannot be stored flips back and says so', (tester) async {
    final store = await pumpStore(tester);
    store.failWrites = true;

    await tester.tap(ropeHeart);
    await tester.pumpAndSettle();

    expect(find.text('Could not update your saved deals. Please try again.'), findsOneWidget);
    expect(heartTooltip(tester), 'Save deal');
  });
}
