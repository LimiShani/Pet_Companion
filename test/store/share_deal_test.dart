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

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Share deal');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> fillValidDeal(WidgetTester tester) async {
    await fill(tester, 'title', 'Chicken jerky strips, 300 g');
    await pickCategory(tester, 'Treats');
    await fill(tester, 'price', '22');
    await fill(tester, 'original-price', '36');
    await fill(tester, 'seller', 'The Treat Jar');
    await fill(tester, 'link', 'https://example.com/jerky');
    await fill(tester, 'description', 'Two bags for the price shown.');
  }

  testWidgets('an empty form names every required field and sends nothing', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    // Full screen: the bottom bar is covered.
    expect(find.text('Community'), findsNothing);

    await submit(tester);

    expect(find.text('Give the deal a title.'), findsOneWidget);
    expect(find.text('Pick a category.'), findsOneWidget);
    expect(find.text('Enter the price now.'), findsOneWidget);
    expect(find.text('Enter the price before the discount.'), findsOneWidget);
    expect(find.text('Who is selling it?'), findsOneWidget);
    expect(find.text('Paste the link to the offer.'), findsOneWidget);
    expect(find.byType(ShareDealScreen), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);
  });

  testWidgets('the price must be below the original, and the link must be https', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);

    await fillValidDeal(tester);
    await fill(tester, 'price', '40');
    await fill(tester, 'link', 'http://example.com/jerky');
    expect(find.textContaining('% off'), findsNothing);
    await submit(tester);

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
    await tester.enterText(find.byType(TextField), 'jerky');
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

    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('23 deals for dogs'), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);
  });
}
