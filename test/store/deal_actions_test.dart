import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// The sample deal shared by the demo user.
  const mine = 'd-salmon-training-treats';

  Future<void> tapOnPage(WidgetTester tester, String label) async {
    final target = find.descendant(of: find.byType(DealDetailScreen), matching: find.text(label));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('the user can delete a deal they shared', (tester) async {
    final store = await pumpStore(tester);
    await store.setSaved(userId: demoUserId, dealId: mine, saved: true);
    await openDeal(tester, mine);

    expect(find.text('Shared by you'), findsOneWidget);
    await tapOnPage(tester, 'Delete my deal');
    expect(find.text('Delete this deal?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Back on the grid, without the deal.
    expect(find.byType(DealDetailScreen), findsNothing);
    expect(find.text('Your deal was deleted.'), findsOneWidget);
    expect(find.byKey(const ValueKey('deal-card-$mine')), findsNothing);
    expect((await store.fetchDeals()).any((d) => d.id == mine), isFalse);
    expect(await store.fetchSavedDealIds(userId: demoUserId), isEmpty);
  });

  testWidgets('cancelling the confirmation keeps the deal', (tester) async {
    final store = await pumpStore(tester);
    await openDeal(tester, mine);

    await tapOnPage(tester, 'Delete my deal');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect((await store.fetchDeals()).any((d) => d.id == mine), isTrue);
  });

  testWidgets('a delete that fails keeps the page and says why', (tester) async {
    final store = await pumpStore(tester);
    await openDeal(tester, mine);

    store.failWrites = true;
    await tapOnPage(tester, 'Delete my deal');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
    expect(find.text('Salmon training treats, 500 g'), findsOneWidget);
  });

  testWidgets('without permission to edit deals, your own deal offers no delete', (tester) async {
    final access = FakeAccessRepository();
    await access.change('user_rule', {'user_id': 'demo', 'capability': 'store.deals.edit', 'allowed': false});
    await pumpStore(tester, access: access);
    await openDeal(tester, mine);

    expect(find.text('Shared by you'), findsOneWidget);
    expect(find.text('Delete my deal'), findsNothing);
  });

  testWidgets('deals shared by others and curated deals cannot be deleted', (tester) async {
    await pumpStore(tester);

    await openDeal(tester, 'd-fetch-balls');
    expect(find.text('Shared by Noam'), findsOneWidget);
    expect(find.text('Delete my deal'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await openDeal(tester, 'd-rope-tug-toy');
    expect(find.text('PetLoop pick'), findsOneWidget);
    expect(find.text('Delete my deal'), findsNothing);
  });

  testWidgets('"Report as expired" records a report once', (tester) async {
    final store = await pumpStore(tester);
    await openDeal(tester, 'd-rope-tug-toy');

    await tapOnPage(tester, 'Report as expired');

    expect(find.text('Thanks, we will check it.'), findsOneWidget);
    expect(store.reports, [(demoUserId, 'd-rope-tug-toy')]);
    // The button gives way to a note, so it cannot be sent twice.
    expect(find.text('Report as expired'), findsNothing);
    expect(find.text('You reported this as expired'), findsOneWidget);
  });

  testWidgets('a deal reported earlier still shows the note', (tester) async {
    final store = fakeStore();
    await store.reportExpired(userId: demoUserId, dealId: 'd-rope-tug-toy');
    await pumpStore(tester, repository: store);
    await openDeal(tester, 'd-rope-tug-toy');

    expect(find.text('You reported this as expired'), findsOneWidget);
    expect(find.text('Report as expired'), findsNothing);
  });

  testWidgets('a report that fails says so and can be tried again', (tester) async {
    final store = await pumpStore(tester);
    await openDeal(tester, 'd-rope-tug-toy');

    store.failWrites = true;
    await tapOnPage(tester, 'Report as expired');

    expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
    expect(store.reports, isEmpty);
    expect(find.text('Report as expired'), findsOneWidget);
  });

  testWidgets('a deal that is already over offers no report', (tester) async {
    await pumpStore(tester);
    await openDeal(tester, 'd-cooling-mat');

    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Report as expired'), findsNothing);
  });
}
