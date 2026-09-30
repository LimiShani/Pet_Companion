import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/app.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/data/link_opener.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/features/store/widgets/deal_card.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/widgets/pet_selector.dart';

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
  PackageSize? package,
  double? delivery,
  Duration? checked,
  Set<PetSpecies> species = const {},
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
    package: package,
    deliveryCost: delivery,
    priceCheckedAt: checked == null ? null : fixedNow.subtract(checked),
    species: species,
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

/// Pumps the whole app on fakes (at phone size unless [size] says
/// otherwise), signs in as the demo user and opens the Store tab. Returns
/// the catalogue the app runs on.
///
/// The demo user has two dogs, Kelly (selected) and Soya; [extraPets] are
/// added after them, for tests that need a cat. The app runs in English
/// unless [language] says otherwise.
Future<FakeStoreRepository> pumpStore(
  WidgetTester tester, {
  FakeStoreRepository? repository,
  FakeLinkOpener? opener,
  Size size = const Size(390, 844),
  List<Pet> extraPets = const [],
  AppLanguage? language,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = repository ?? fakeStore();
  final pets = FakePetsRepository(latency: Duration.zero);
  for (final pet in extraPets) {
    await pets.savePet(FakePetsRepository.demoOwner, pet);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
        storeClockProvider.overrideWithValue(() => fixedNow),
        storeRepositoryProvider.overrideWithValue(store),
        petsRepositoryProvider.overrideWithValue(pets),
        linkOpenerProvider.overrideWithValue(opener ?? FakeLinkOpener()),
        settingsStoreProvider.overrideWithValue(MemorySettingsStore({languageSettingKey: ?language?.code})),
      ],
      child: const PetCompanionApp(),
    ),
  );
  await tester.pumpAndSettle();
  await signInAsDemo(tester);
  // The Store tab, by its name in the app's language.
  final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
  await tester.tap(find.text(lookupAppL10n(locale).navStore));
  await tester.pumpAndSettle();
  return store;
}

/// Taps a pill of the pet row in the Store header ("Kelly", "All animals"),
/// sliding the row to it first: in the wide test font the row is longer
/// than the screen.
Future<void> tapPetPill(WidgetTester tester, String label) async {
  final pill = find.descendant(of: find.byType(PetSelector), matching: find.text(label));
  await tester.ensureVisible(pill);
  await tester.pumpAndSettle();
  await tester.tap(pill);
  await tester.pumpAndSettle();
}

/// The vertical scroll view of the page on top (the grid, or a deal page).
Finder get gridScrollable =>
    find.descendant(of: find.byType(CustomScrollView).last, matching: find.byType(Scrollable)).first;

/// Opens the page of the deal whose card is on screen (scrolling to it).
Future<void> openDeal(WidgetTester tester, String dealId) async {
  final card = find.byKey(ValueKey('deal-card-$dealId'));
  // Start from the top: the grid only builds the rows near the viewport.
  tester.state<ScrollableState>(gridScrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(card, 200, scrollable: gridScrollable);
  await tester.pumpAndSettle();
  // Up to the top of the grid, away from the floating button (which sits
  // at the bottom right, or the bottom left on a right-to-left screen).
  await Scrollable.ensureVisible(tester.element(card), alignment: 0.05);
  await tester.pumpAndSettle();
  // The middle of the picture, below the badge and the heart.
  await tester.tapAt(Offset(tester.getCenter(card).dx, tester.getTopLeft(card).dy + 70));
  await tester.pumpAndSettle();
}

/// Ids of the deal cards currently built, in grid order.
List<String> shownDealIds(WidgetTester tester) =>
    [for (final card in tester.widgetList<DealCard>(find.byType(DealCard))) card.deal.id];
