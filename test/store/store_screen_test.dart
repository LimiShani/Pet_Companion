import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/features/store/widgets/deal_grid.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Four deals whose order differs under every sort rule, one of them over.
  List<Deal> sortSeed() => [
        testDeal('cheap', price: 10, originalPrice: 12, posted: const Duration(days: 3), endsIn: const Duration(days: 9)),
        testDeal('bargain', price: 30, originalPrice: 100, posted: const Duration(days: 2)),
        testDeal('fresh', price: 80, originalPrice: 100, posted: const Duration(minutes: 5), endsIn: const Duration(days: 1)),
        testDeal('over', price: 1, originalPrice: 100, posted: const Duration(minutes: 1), endsIn: const Duration(days: -1)),
      ];

  Future<void> pickSort(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Sort deals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the grid shows the deals, biggest discount first', (tester) async {
    await pumpStore(tester);

    expect(find.byKey(const Key('store-screen')), findsOneWidget);
    expect(find.text('21 deals'), findsOneWidget);
    expect(find.text('Biggest discount'), findsOneWidget);

    expect(shownDealIds(tester).first, 'd-rope-tug-toy');
    final first = find.byKey(const ValueKey('deal-card-d-rope-tug-toy'));
    expect(find.descendant(of: first, matching: find.text('Squeaky rope tug toy, 2 pack')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('₪29')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('₪59')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('-51%')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('Toy Barn')), findsOneWidget);

    // The old price is struck through.
    final original = tester.widget<Text>(find.descendant(of: first, matching: find.text('₪59')));
    expect(original.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('two cards per row on a phone, more on a wide screen', (tester) async {
    await pumpStore(tester);

    final cards = find.byType(DealCard);
    expect(tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(1)).dy);
    expect(tester.getTopLeft(cards.at(2)).dy, greaterThan(tester.getTopLeft(cards.at(0)).dy));
    // Cards in a row share a height.
    expect(tester.getSize(cards.at(0)).height, tester.getSize(cards.at(1)).height);

    expect(SliverDealGrid.columnsFor(390), 2);
    expect(SliverDealGrid.columnsFor(320), 2);
    expect(SliverDealGrid.columnsFor(800), 4);
  });

  testWidgets('search narrows the grid and can be cleared', (tester) async {
    await pumpStore(tester);

    await tester.enterText(find.byType(TextField), 'salmon');
    await tester.pumpAndSettle();
    expect(find.text('2 deals'), findsOneWidget);
    expect(shownDealIds(tester), ['d-salmon-kibble-12kg', 'd-salmon-training-treats']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('21 deals'), findsOneWidget);
  });

  testWidgets('a category chip filters the grid', (tester) async {
    await pumpStore(tester);

    final toys = find.widgetWithText(ChoiceChip, 'Toys');
    await tester.ensureVisible(toys);
    await tester.pumpAndSettle();
    await tester.tap(toys);
    await tester.pumpAndSettle();

    expect(find.text('3 deals'), findsOneWidget);
    expect(shownDealIds(tester), ['d-rope-tug-toy', 'd-puzzle-feeder', 'd-fetch-balls']);

    final all = find.widgetWithText(ChoiceChip, 'All');
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(find.text('21 deals'), findsOneWidget);
  });

  testWidgets('sort: biggest discount is the default, expired last', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: sortSeed()));
    expect(shownDealIds(tester), ['bargain', 'fresh', 'cheap', 'over']);
  });

  testWidgets('sort: lowest price', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: sortSeed()));
    await pickSort(tester, 'Lowest price');
    expect(shownDealIds(tester), ['cheap', 'bargain', 'fresh', 'over']);
    expect(find.text('Lowest price'), findsOneWidget);
  });

  testWidgets('sort: newest', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: sortSeed()));
    await pickSort(tester, 'Newest');
    expect(shownDealIds(tester), ['fresh', 'bargain', 'cheap', 'over']);
  });

  testWidgets('sort: ending soon, then back to biggest discount', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: sortSeed()));
    await pickSort(tester, 'Ending soon');
    expect(shownDealIds(tester), ['fresh', 'cheap', 'bargain', 'over']);

    await pickSort(tester, 'Biggest discount');
    expect(shownDealIds(tester), ['bargain', 'fresh', 'cheap', 'over']);
  });

  testWidgets('an expired deal is marked instead of showing its discount', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: sortSeed()));

    final over = find.byKey(const ValueKey('deal-card-over'));
    expect(find.descendant(of: over, matching: find.text('Expired')), findsOneWidget);
    expect(find.descendant(of: over, matching: find.text('-99%')), findsNothing);
    expect(find.text('Expired'), findsOneWidget);
  });

  testWidgets('no results shows the empty state, and clearing brings the grid back', (tester) async {
    await pumpStore(tester);

    await tester.enterText(find.byType(TextField), 'hamster wheel');
    await tester.pumpAndSettle();

    expect(find.text('No deals found'), findsOneWidget);
    expect(find.text('Nothing matches "hamster wheel". Try another word.'), findsOneWidget);
    expect(find.byType(DealCard), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('No deals found'), findsNothing);
    expect(find.text('21 deals'), findsOneWidget);
    expect(find.text('hamster wheel'), findsNothing);
  });

  testWidgets('an empty catalogue says so', (tester) async {
    await pumpStore(tester, repository: fakeStore(seed: []));
    expect(find.text('No deals yet'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state, and "Try again" recovers', (tester) async {
    final store = fakeStore()..failFetches = true;
    await pumpStore(tester, repository: store);

    expect(find.text('Could not load deals'), findsOneWidget);
    expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
    expect(find.byType(DealCard), findsNothing);

    store.failFetches = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load deals'), findsNothing);
    expect(find.text('21 deals'), findsOneWidget);
  });

  testWidgets('pull to refresh loads new deals', (tester) async {
    final store = await pumpStore(tester, repository: fakeStore(seed: sortSeed()));
    expect(find.text('4 deals'), findsOneWidget);

    await store.shareDeal(
      userId: 'someone-else',
      draft: const DealDraft(
        title: 'Brand new bargain',
        category: DealCategory.food,
        price: 5,
        originalPrice: 50,
        sellerName: 'Shop',
        link: 'https://example.com/new',
      ),
    );

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('5 deals'), findsOneWidget);
    expect(find.text('Brand new bargain'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the deals on screen', (tester) async {
    final store = await pumpStore(tester, repository: fakeStore(seed: sortSeed()));

    store.failFetches = true;
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Could not refresh the deals. Please try again.'), findsOneWidget);
    expect(find.text('4 deals'), findsOneWidget);
  });
}
