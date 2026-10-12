import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'store_test_helpers.dart';

/// The form's checks, answering in English.
final _valid = DealValidators(lookupStoreL10n(englishLocale));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('Share a deal'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareDealScreen), findsOneWidget);
  }

  Future<void> fill(WidgetTester tester, String field, String text) async {
    await tester.enterText(find.byKey(Key('share-$field')), text);
    await tester.pump();
  }

  Future<void> pickCategory(WidgetTester tester, String label) async {
    final dropdown = find.byKey(const Key('share-category'));
    await tester.ensureVisible(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Step 1's "Next".
  Future<void> next(WidgetTester tester) => press(tester, 'Next');

  /// Step 2's "Share deal".
  Future<void> submit(WidgetTester tester) => press(tester, 'Share deal');

  /// Step 1, filled in and still on screen.
  Future<void> fillWhat(WidgetTester tester) async {
    await fill(tester, 'title', 'Chicken jerky strips, 300 g');
    await pickCategory(tester, 'Treats');
    await fill(tester, 'price', '22');
    await fill(tester, 'original-price', '36');
    await fill(tester, 'link', 'https://example.com/jerky');
    await fill(tester, 'seller', 'The Treat Jar');
  }

  /// Both steps, ending on step 2 ready to share.
  Future<void> fillValidDeal(WidgetTester tester) async {
    await fillWhat(tester);
    await next(tester);
    await fill(tester, 'description', 'Two bags for the price shown.');
  }

  String typed(WidgetTester tester, String field) =>
      tester.widget<TextField>(find.descendant(of: find.byKey(Key('share-$field')), matching: find.byType(TextField))).controller!.text;

  testWidgets('an empty form names every required field and sends nothing', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    // Full screen: the bottom bar is covered.
    expect(find.text('Community'), findsNothing);
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('What and the price'), findsOneWidget);

    await next(tester);

    expect(find.text('Give the deal a title.'), findsOneWidget);
    expect(find.text('Pick a category.'), findsOneWidget);
    expect(find.text('Enter the price now.'), findsOneWidget);
    expect(find.text('Enter the price before the discount.'), findsOneWidget);
    expect(find.text('Who is selling it?'), findsOneWidget);
    expect(find.text('Paste the link to the offer.'), findsOneWidget);
    expect(find.byType(ShareDealScreen), findsOneWidget);
    // Still on step 1.
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.byKey(const Key('share-package-amount')), findsNothing);
    expect((await store.fetchDeals()).length, 36);
  });

  testWidgets('the price must be below the original, and the link must be https', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);

    await fillWhat(tester);
    await fill(tester, 'price', '40');
    await fill(tester, 'link', 'http://example.com/jerky');
    expect(find.textContaining('% off'), findsNothing);
    await next(tester);

    expect(find.text('The deal price must be below the original price.'), findsOneWidget);
    expect(find.text('Use a full link that starts with https://'), findsOneWidget);
    expect(find.byType(ShareDealScreen), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);

    // Problems clear as they are fixed.
    await fill(tester, 'price', '22');
    await tester.pumpAndSettle();
    expect(find.text('The deal price must be below the original price.'), findsNothing);
    expect(find.text('That is 39% off'), findsOneWidget);

    await fill(tester, 'price', 'cheap');
    await tester.pumpAndSettle();
    expect(find.text('Enter a number, like 49.90.'), findsOneWidget);
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });

  testWidgets('a valid step 1 goes on to the details; Back keeps what was typed in both steps', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillWhat(tester);
    await next(tester);

    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Details (optional)'), findsOneWidget);
    expect(find.byKey(const Key('share-title')), findsNothing);
    expect(find.byKey(const Key('share-package-amount')), findsOneWidget);
    // The details start quiet: nothing is flagged before sharing.
    expect(find.textContaining('Enter'), findsNothing);
    await fill(tester, 'description', 'Two bags for the price shown.');

    final back = find.byKey(const Key('share-back'));
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(typed(tester, 'title'), 'Chicken jerky strips, 300 g');
    expect(typed(tester, 'price'), '22');
    expect(typed(tester, 'original-price'), '36');
    expect(typed(tester, 'link'), 'https://example.com/jerky');
    expect(typed(tester, 'seller'), 'The Treat Jar');
    expect(find.descendant(of: find.byKey(const Key('share-category')), matching: find.text('Treats')), findsOneWidget);
    expect(find.text('That is 39% off'), findsOneWidget);

    await next(tester);
    expect(typed(tester, 'description'), 'Two bags for the price shown.');
    await submit(tester);

    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('Thanks! Your deal is live.'), findsOneWidget);
    final shared = (await store.fetchDeals()).firstWhere((d) => d.title == 'Chicken jerky strips, 300 g');
    expect(shared.description, 'Two bags for the price shown.');
  });

  testWidgets('back on step 2 returns to step 1; leaving from there still asks', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillValidDeal(tester);

    // The header arrow on step 2 goes to step 1, with the deal kept.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareDealScreen), findsNothing);
    expect((await store.fetchDeals()).length, 36);
  });

  test('the form checks', () {
    expect(DealValidators.parsePrice('39,90'), 39.9);
    expect(DealValidators.parsePrice(' 12.345 '), 12.35);
    expect(DealValidators.parsePrice('abc'), isNull);
    expect(_valid.price('0', '10'), 'The price must be above zero.');
    expect(_valid.price('10', '10'), 'The deal price must be below the original price.');
    expect(_valid.price('9.99', '10'), isNull);
    expect(_valid.originalPrice('-5'), 'The price must be above zero.');
    expect(_valid.title('ab'), 'Use at least 3 characters.');
    expect(_valid.link('www.example.com/x'), 'Use a full link that starts with https://');
    expect(_valid.link('https://localhost'), 'Use a full link that starts with https://');
    expect(_valid.link('javascript:alert(1)'), 'Use a full link that starts with https://');
    expect(_valid.link(' https://shop.example.com/x?y=1 '), isNull);
  });

  testWidgets('sharing a valid deal adds it to the catalogue as the user\'s own', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);

    await fillValidDeal(tester);
    await submit(tester);

    // Back on the Store, with a thank you.
    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('Thanks! Your deal is live.'), findsOneWidget);
    expect(find.text('24 deals for dogs'), findsOneWidget);

    final shared = (await store.fetchDeals()).firstWhere((d) => d.title == 'Chicken jerky strips, 300 g');
    expect(shared.sharedBy, demoUserId);
    expect(shared.sharedByName, 'Alex');
    expect(shared.category, DealCategory.treats);
    expect(shared.price, 22);
    expect(shared.originalPrice, 36);
    expect(shared.currency, kStoreDefaultCurrency);
    expect(shared.sellerName, 'The Treat Jar');
    expect(shared.link, 'https://example.com/jerky');
    expect(shared.description, 'Two bags for the price shown.');
    expect(shared.postedAt, fixedNow);
    expect(shared.expiresAt, isNull);

    // It is in the grid, and its page says whose it is.
    await searchDeals(tester, 'jerky');
    await tester.pumpAndSettle();
    expect(shownDealIds(tester), [shared.id]);
    await openDeal(tester, shared.id);
    final page = find.byType(DealDetailScreen);
    expect(find.descendant(of: page, matching: find.text('Shared by you')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('You save ₪14 (39%)')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('Just now')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('Delete my deal')), findsOneWidget);
  });

  testWidgets('an end date can be picked and removed', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillValidDeal(tester);

    final endDate = find.byKey(const Key('share-end-date'));
    await tester.ensureVisible(endDate);
    await tester.pumpAndSettle();
    expect(find.text('Add an end date'), findsOneWidget);

    // The calendar opens a week ahead; accept it.
    await tester.tap(endDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Ends 07.10.26'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove the end date'));
    await tester.pumpAndSettle();
    expect(find.text('Add an end date'), findsOneWidget);

    await tester.tap(endDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await submit(tester);

    final shared = (await store.fetchDeals()).firstWhere((d) => d.title == 'Chicken jerky strips, 300 g');
    // The deal runs to the end of its last day.
    expect(shared.expiresAt, DateTime(2026, 10, 7, 23, 59, 59));
    expect(shared.isExpired(fixedNow), isFalse);
  });

  testWidgets('a deal that cannot be stored keeps the form open with the reason', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillValidDeal(tester);

    store.failWrites = true;
    await submit(tester);

    expect(find.byType(ShareDealScreen), findsOneWidget);
    expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);

    store.failWrites = false;
    await submit(tester);
    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('Thanks! Your deal is live.'), findsOneWidget);
  });

  testWidgets('back leaves the form without sharing', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fill(tester, 'title', 'Half a deal');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    // Something was typed: leaving asks first.
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('23 deals for dogs'), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);
  });
}
