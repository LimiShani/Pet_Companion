import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/link_opener.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/features/store/store_screen.dart';
import 'package:pet_companion/features/store/widgets/deal_badge.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/features/store/widgets/save_deal_button.dart';
import 'package:pet_companion/theme/app_theme.dart';

import 'store_test_helpers.dart';

class _SignedIn extends AuthController {
  @override
  Future<AppUser?> build() async => const AppUser(id: demoUserId, email: 'demo@petcompanion.app', displayName: 'Alex');
}

/// The Store laid out right to left, as it will be in Hebrew: nothing
/// overflows (an overflow fails a test), and what sits at the start of a
/// line in English sits at the right here. The texts are still English.
void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpRightToLeft(WidgetTester tester, Widget screen, {List<Deal>? seed}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
          // Signed in as the demo user without going through the login screen.
          authControllerProvider.overrideWith(_SignedIn.new),
          storeClockProvider.overrideWithValue(() => fixedNow),
          storeRepositoryProvider.overrideWithValue(fakeStore(seed: seed)),
          linkOpenerProvider.overrideWithValue(FakeLinkOpener()),
          petsRepositoryProvider.overrideWithValue(FakePetsRepository(latency: Duration.zero)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(textDirection: TextDirection.rtl, child: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The pet pills look up each pet's essentials in Health's sample data,
    // which answers in steps of 300 ms. Let those finish, so no timer is
    // left over when the test ends.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  double centerX(WidgetTester tester, Finder finder) => tester.getCenter(finder).dx;

  /// Where a widget ends on the right. A label that starts at the right
  /// margin ends about 26 px from the screen's right edge (390 wide).
  double rightEdge(WidgetTester tester, Finder finder) => tester.getTopRight(finder).dx;

  testWidgets('the Store grid runs from the right', (tester) async {
    await pumpRightToLeft(tester, const StoreScreen());

    expect(find.text('23 deals for dogs'), findsOneWidget);

    // The first card is on the right, the second to its left.
    final cards = find.byType(DealCard);
    expect(shownDealIds(tester).first, 'd-rope-tug-toy');
    expect(centerX(tester, cards.at(0)), greaterThan(centerX(tester, cards.at(1))));

    // On a card the discount badge is at the right, the heart at the left.
    final first = cards.at(0);
    final badge = find.descendant(of: first, matching: find.byType(DealBadge));
    final heart = find.descendant(of: first, matching: find.byType(SaveDealButton));
    expect(centerX(tester, badge), greaterThan(centerX(tester, first)));
    expect(centerX(tester, heart), lessThan(centerX(tester, first)));

    // The pet pills and the category chips start at the right.
    expect(centerX(tester, find.text('Kelly')), greaterThan(centerX(tester, find.text('Soya'))));
    expect(
      centerX(tester, find.widgetWithText(ChoiceChip, 'All')),
      greaterThan(centerX(tester, find.widgetWithText(ChoiceChip, 'Food'))),
    );
    // The count is at the right end of its row.
    expect(rightEdge(tester, find.byKey(const Key('store-deal-count'))), greaterThan(350));
  });

  testWidgets('the deal page reads from the right', (tester) async {
    await pumpRightToLeft(tester, const DealDetailScreen(dealId: 'd-clumping-litter-10kg'));

    expect(find.text('Clumping cat litter, 10 kg'), findsOneWidget);
    // In the price card each label is at the right of its value.
    expect(centerX(tester, find.text('Package')), greaterThan(centerX(tester, find.text('10 kg'))));
    expect(centerX(tester, find.text('Delivery')), greaterThan(centerX(tester, find.text('+ ₪25'))));
    // The badge on the picture is at the right.
    expect(centerX(tester, find.byType(DealBadge)), greaterThan(195));
    // "Report as expired" starts at the right.
    final report = find.text('Report as expired');
    await tester.ensureVisible(report);
    await tester.pumpAndSettle();
    expect(centerX(tester, report), greaterThan(195));
    expect(rightEdge(tester, find.text('Clumping cat litter, 10 kg')), greaterThan(350));
  });

  testWidgets('the share form reads from the right', (tester) async {
    await pumpRightToLeft(tester, const ShareDealScreen());

    expect(rightEdge(tester, find.text('Title')), greaterThan(350));
    expect(rightEdge(tester, find.text('For which animals')), greaterThan(350));
    // The first chip is the rightmost one.
    expect(
      centerX(tester, find.byKey(const Key('share-animals-all'))),
      greaterThan(centerX(tester, find.byKey(const Key('share-animals-dog')))),
    );
    // "Price now" is the right one of the two price fields.
    expect(
      centerX(tester, find.byKey(const Key('share-price'))),
      greaterThan(centerX(tester, find.byKey(const Key('share-original-price')))),
    );

    // Walking the form to its end lays out every part without an overflow.
    final send = find.widgetWithText(FilledButton, 'Share deal');
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Pick a category.'), findsOneWidget);
  });
}
