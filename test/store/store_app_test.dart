import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/saved_deals_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';

import '../helpers.dart';
import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the Store tab works in the app as shipped: sample deals after a short load', (tester) async {
    // No Store overrides: the default in-memory catalogue with its latency.
    await pumpApp(tester);
    await signInAsDemo(tester);

    await tester.tap(find.text('Store'));
    await tester.pump();
    expect(find.byKey(const Key('store-screen')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('21 deals'), findsOneWidget);
    expect(find.text('Squeaky rope tug toy, 2 pack'), findsOneWidget);
    expect(find.text('Share a deal'), findsOneWidget);

    // Tapping the tab again from a sub-page returns to the grid.
    await tester.tap(find.byTooltip('Saved deals'));
    await tester.pumpAndSettle();
    expect(find.byType(SavedDealsScreen), findsOneWidget);
    await tester.tap(find.text('Store').last);
    await tester.pumpAndSettle();
    expect(find.byType(SavedDealsScreen), findsNothing);
    expect(find.text('21 deals'), findsOneWidget);
  });

  testWidgets('a wide screen shows more cards per row', (tester) async {
    await pumpStore(tester, size: const Size(820, 1180));

    final cards = find.byType(DealCard);
    final firstRow = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(3)).dy, firstRow);
    expect(tester.getTopLeft(cards.at(4)).dy, greaterThan(firstRow));
  });

  testWidgets('every Store screen fits a small phone', (tester) async {
    // Any overflow fails the test, and the test font is wider than the
    // real one, so this is a strict check.
    // Signed in at the usual size first, then the screen shrinks: the
    // login screen is not what is being checked here.
    await pumpStore(tester);
    tester.view.physicalSize = const Size(320, 568) * 3;
    await tester.pumpAndSettle();
    expect(find.byType(DealCard), findsWidgets);

    await openDeal(tester, 'd-dental-chew-sticks');
    expect(find.byType(DealDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await openDeal(tester, 'd-salmon-training-treats');
    expect(find.text('Delete my deal'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Saved deals'));
    await tester.pumpAndSettle();
    expect(find.text('No saved deals yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No deals found'), findsOneWidget);

    await tester.tap(find.text('Share a deal'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareDealScreen), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Share deal');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Pick a category.'), findsOneWidget);
  });
}
