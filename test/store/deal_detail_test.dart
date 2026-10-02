import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/link_opener.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('opening a deal shows its prices, saving, seller and dates', (tester) async {
    await pumpStore(tester);
    await openDeal(tester, 'd-salmon-kibble-12kg');

    final page = find.byType(DealDetailScreen);
    Finder onPage(String text) => find.descendant(of: page, matching: find.text(text));

    expect(page, findsOneWidget);
    expect(onPage('Grain-free salmon kibble, 12 kg'), findsOneWidget);
    expect(onPage('₪179'), findsOneWidget);
    expect(onPage('₪299'), findsOneWidget);
    expect(onPage('-40%'), findsOneWidget);
    expect(onPage('You save ₪120 (40%)'), findsOneWidget);
    expect(onPage('Food'), findsOneWidget);
    expect(onPage('PetLoop pick'), findsOneWidget);
    expect(onPage('Happy Paws Market'), findsOneWidget);
    expect(onPage('3 hours ago'), findsOneWidget);
    expect(onPage('12.10.26 · 12 days left'), findsOneWidget);
    expect(find.textContaining('Salmon is the first ingredient'), findsOneWidget);
    expect(onPage('Opens example.com in your browser'), findsOneWidget);

    // The bottom bar stays, and back returns to the grid.
    expect(find.text('Community'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(DealDetailScreen), findsNothing);
    expect(find.byKey(const ValueKey('deal-card-d-salmon-kibble-12kg')), findsOneWidget);
    expect(find.text('Search deals'), findsOneWidget);
  });

  testWidgets('"Open offer" hands the deal\'s link to the browser', (tester) async {
    final opener = FakeLinkOpener();
    await pumpStore(tester, opener: opener);
    await openDeal(tester, 'd-salmon-kibble-12kg');

    await tester.tap(find.text('Open offer'));
    await tester.pumpAndSettle();

    expect(opener.opened, [Uri.parse('https://example.com/deals/salmon-kibble-12kg')]);
    expect(find.text('Could not open the offer. Please try again.'), findsNothing);
  });

  testWidgets('a link that cannot be opened says so', (tester) async {
    final opener = FakeLinkOpener()..succeeds = false;
    await pumpStore(tester, opener: opener);
    await openDeal(tester, 'd-salmon-kibble-12kg');

    await tester.tap(find.text('Open offer'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the offer. Please try again.'), findsOneWidget);
  });

  testWidgets('a deal with a link that is not https is never opened', (tester) async {
    final opener = FakeLinkOpener();
    // Seeded directly: sharing through the repository would refuse this link.
    final store = fakeStore(seed: [testDeal('odd', link: 'javascript:alert(1)')]);
    await pumpStore(tester, repository: store, opener: opener);
    await openDeal(tester, 'odd');

    await tester.tap(find.text('Open offer'));
    await tester.pumpAndSettle();

    expect(opener.opened, isEmpty);
    expect(find.text('Could not open the offer. Please try again.'), findsOneWidget);
    expect(safeDealLink('http://example.com'), isNull);
    expect(safeDealLink('https://example.com/x'), isNotNull);
  });

  testWidgets('an expired deal is clearly marked on its page', (tester) async {
    await pumpStore(tester);
    await openDeal(tester, 'd-cooling-mat');

    final page = find.byType(DealDetailScreen);
    expect(find.descendant(of: page, matching: find.text('Expired')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('This deal ended on 27.09.26')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('-40%')), findsNothing);
    expect(find.descendant(of: page, matching: find.text('Ends')), findsNothing);
  });

  testWidgets('a deal shared by a member names them; no end date is said plainly', (tester) async {
    await pumpStore(tester);
    await openDeal(tester, 'd-fetch-balls');

    final page = find.byType(DealDetailScreen);
    expect(find.descendant(of: page, matching: find.text('Shared by Noam')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('No end date')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('5 days ago')), findsOneWidget);
    expect(find.descendant(of: page, matching: find.text('₪19.90')), findsOneWidget);
  });
}
