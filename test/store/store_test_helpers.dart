import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/data/link_opener.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';

import '../helpers.dart';

/// The instant every Store test runs at.
final fixedNow = DateTime(2026, 9, 30, 12);

/// The id of the demo account the tests sign in with.
const demoUserId = 'demo';

/// A zero-latency catalogue at [fixedNow]: the sample deals, or [seed].
FakeStoreRepository fakeStore({List<Deal>? seed}) =>
    FakeStoreRepository(latency: Duration.zero, now: () => fixedNow, seed: seed);

/// A small deal for tests that need a controlled catalogue.
Deal testDeal(
  String id, {
  String? title,
  double price = 50,
  double originalPrice = 100,
  DealCategory category = DealCategory.toys,
  Duration posted = const Duration(hours: 1),
  Duration? endsIn,
  String seller = 'Test Shop',
  String? sharedBy,
  String? sharedByName,
  String description = '',
  String? link,
}) {
  return Deal(
    id: id,
    title: title ?? 'Deal $id',
    description: description,
    category: category,
    price: price,
    originalPrice: originalPrice,
    sellerName: seller,
    link: link ?? 'https://example.com/$id',
    sharedBy: sharedBy,
    sharedByName: sharedByName,
    postedAt: fixedNow.subtract(posted),
    expiresAt: endsIn == null ? null : fixedNow.add(endsIn),
  );
}

/// Records the links the app asks to open instead of launching a browser.
class FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];

  /// What [open] answers: false simulates a device with no browser.
  bool succeeds = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return succeeds;
  }
}

/// Pumps the whole app at phone size on fakes, signs in as the demo user
/// and opens the Store tab. Returns the catalogue the app runs on.
Future<FakeStoreRepository> pumpStore(
  WidgetTester tester, {
  FakeStoreRepository? repository,
  FakeLinkOpener? opener,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = repository ?? fakeStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        storeClockProvider.overrideWithValue(() => fixedNow),
        storeRepositoryProvider.overrideWithValue(store),
        linkOpenerProvider.overrideWithValue(opener ?? FakeLinkOpener()),
      ],
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);
  await tester.tap(find.text('Store'));
  await tester.pumpAndSettle();
  return store;
}

/// The vertical scroll view of the page on top (the grid, or a deal page).
Finder get gridScrollable =>
    find.descendant(of: find.byType(CustomScrollView).last, matching: find.byType(Scrollable)).first;

/// Opens the page of the deal whose card is on screen (scrolling to it).
Future<void> openDeal(WidgetTester tester, String dealId) async {
  final card = find.byKey(ValueKey('deal-card-$dealId'));
  await tester.scrollUntilVisible(card, 200, scrollable: gridScrollable);
  await tester.pumpAndSettle();
  // The picture's left half: clear of the badge, the heart and the
  // floating button.
  await tester.tapAt(tester.getTopLeft(card) + const Offset(30, 70));
  await tester.pumpAndSettle();
}

/// Ids of the deal cards currently built, in grid order.
List<String> shownDealIds(WidgetTester tester) =>
    [for (final card in tester.widgetList<DealCard>(find.byType(DealCard))) card.deal.id];
