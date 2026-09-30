import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

import 'store_test_helpers.dart';

/// The parts of the "Share a deal" form added in phase 1: the animals, the
/// package size and the delivery cost.
/// The form's checks, answering in English.
final _valid = DealValidators(lookupStoreL10n(englishLocale));

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const title = 'Clumping cat litter, 10 kg';

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('Share a deal'));
    await tester.pumpAndSettle();
    expect(find.byType(ShareDealScreen), findsOneWidget);
  }

  Future<void> show(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String field, String text) async {
    final input = find.byKey(Key('share-$field'));
    await show(tester, input);
    await tester.enterText(input, text);
    await tester.pumpAndSettle();
  }

  Future<void> pickFrom(WidgetTester tester, String dropdownKey, String label) async {
    final dropdown = find.byKey(Key(dropdownKey));
    await show(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapChip(WidgetTester tester, String key) async {
    final chip = find.byKey(Key(key));
    await show(tester, chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  bool animalChosen(WidgetTester tester, String name) =>
      tester.widget<FilterChip>(find.byKey(Key('share-animals-$name'))).selected;

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Share deal');
    await show(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Everything the form required before phase 1.
  Future<void> fillBasics(WidgetTester tester) async {
    await fill(tester, 'title', title);
    await pickFrom(tester, 'share-category', 'Litter & cleaning');
    await fill(tester, 'price', '36.90');
    await fill(tester, 'original-price', '59.90');
    await fill(tester, 'seller', 'Clean Paws');
    await fill(tester, 'link', 'https://example.com/litter');
  }

  Future<Deal> sharedDeal(FakeStoreRepository store) async =>
      (await store.fetchDeals()).firstWhere((d) => d.title == title);

  testWidgets('a deal is shared with its animals, package size and delivery cost', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);

    // Starts on the kind of the selected pet: Kelly is a dog.
    expect(animalChosen(tester, 'dog'), isTrue);
    expect(animalChosen(tester, 'cat'), isFalse);
    expect(animalChosen(tester, 'all'), isFalse);

    await fillBasics(tester);
    await tapChip(tester, 'share-animals-cat');
    expect(animalChosen(tester, 'dog'), isTrue);
    expect(animalChosen(tester, 'cat'), isTrue);

    // No hints until there is something to work out.
    expect(find.textContaining('per kg'), findsNothing);
    expect(find.textContaining('Final price'), findsNothing);

    await fill(tester, 'package-amount', '10');
    await pickFrom(tester, 'share-package-unit', 'kg');
    expect(find.text('That is ₪3.69 per kg'), findsOneWidget);

    await tapChip(tester, 'share-delivery-paid');
    await fill(tester, 'delivery-cost', '25');
    expect(find.text('Final price ₪61.90'), findsOneWidget);

    expect(find.text('The price will show as checked today, 30.09.26.'), findsOneWidget);
    await submit(tester);

    expect(find.byType(ShareDealScreen), findsNothing);
    expect(find.text('Thanks! Your deal is live.'), findsOneWidget);

    final deal = await sharedDeal(store);
    expect(deal.category, DealCategory.litterAndCleaning);
    expect(deal.package, const PackageSize(10, PackageUnit.kg));
    expect(deal.deliveryCost, 25);
    expect(deal.finalPrice, closeTo(61.90, 0.001));
    expect(deal.species, {PetSpecies.dog, PetSpecies.cat});
    expect(deal.priceCheckedAt, fixedNow);

    // Its page shows what was entered.
    await tester.enterText(find.byType(TextField), 'clumping');
    await tester.pumpAndSettle();
    await openDeal(tester, deal.id);
    final page = find.byType(DealDetailScreen);
    Finder onPage(String text) => find.descendant(of: page, matching: find.text(text));
    expect(onPage('For dogs and cats'), findsOneWidget);
    expect(onPage('₪3.69 per kg'), findsOneWidget);
    expect(onPage('+ ₪25'), findsOneWidget);
    expect(onPage('₪61.90'), findsOneWidget);
    expect(onPage('30.09.26 · today'), findsOneWidget);
  });

  testWidgets('"All pets", free delivery and no package size', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillBasics(tester);

    await tapChip(tester, 'share-animals-all');
    expect(animalChosen(tester, 'all'), isTrue);
    expect(animalChosen(tester, 'dog'), isFalse);

    await tapChip(tester, 'share-delivery-free');
    expect(find.text('Final price ₪36.90'), findsOneWidget);
    expect(find.byKey(const Key('share-delivery-cost')), findsNothing);

    await submit(tester);

    final deal = await sharedDeal(store);
    expect(deal.species, isEmpty);
    expect(deal.isForEveryPet, isTrue);
    expect(deal.deliveryCost, 0);
    expect(deal.package, isNull);
    expect(deal.unitPrice, isNull);
  });

  testWidgets('left alone, the new parts share a deal for the selected pet with no size and no delivery',
      (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillBasics(tester);
    await submit(tester);

    final deal = await sharedDeal(store);
    expect(deal.species, {PetSpecies.dog});
    expect(deal.package, isNull);
    expect(deal.deliveryCost, isNull);
    expect(deal.finalPrice, isNull);
  });

  testWidgets('with a cat selected the form starts on cats; taking the last animal off means all pets',
      (tester) async {
    await pumpStore(tester, extraPets: [const Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat)]);
    await tapPetPill(tester, 'Mitzi');
    await openForm(tester);

    expect(animalChosen(tester, 'cat'), isTrue);
    expect(animalChosen(tester, 'dog'), isFalse);

    await tapChip(tester, 'share-animals-cat');
    expect(animalChosen(tester, 'cat'), isFalse);
    expect(animalChosen(tester, 'all'), isTrue);

    await tapChip(tester, 'share-animals-bird');
    expect(animalChosen(tester, 'bird'), isTrue);
    expect(animalChosen(tester, 'all'), isFalse);
  });

  testWidgets('a package size needs a unit and an amount above zero', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillBasics(tester);

    await fill(tester, 'package-amount', '10');
    await submit(tester);

    expect(find.text('Choose a unit: kg, g, litre, ml or units.'), findsOneWidget);
    expect(find.byType(ShareDealScreen), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);

    // The problem goes as soon as it is fixed.
    await pickFrom(tester, 'share-package-unit', 'g');
    expect(find.text('Choose a unit: kg, g, litre, ml or units.'), findsNothing);
    expect(find.text('That is ₪3,690 per kg'), findsOneWidget);

    await fill(tester, 'package-amount', '0');
    expect(find.text('Enter a size above zero, like 2.5.'), findsOneWidget);
    await fill(tester, 'package-amount', 'big');
    expect(find.text('Enter a size above zero, like 2.5.'), findsOneWidget);

    // Emptying the amount drops the package; the unit on its own is ignored.
    await fill(tester, 'package-amount', '');
    expect(find.text('Enter a size above zero, like 2.5.'), findsNothing);
    await submit(tester);

    expect(find.byType(ShareDealScreen), findsNothing);
    expect((await sharedDeal(store)).package, isNull);
  });

  testWidgets('a paid delivery needs a cost above zero', (tester) async {
    final store = await pumpStore(tester);
    await openForm(tester);
    await fillBasics(tester);

    await tapChip(tester, 'share-delivery-paid');
    await submit(tester);
    expect(find.text('Enter the delivery cost.'), findsOneWidget);
    expect(find.byType(ShareDealScreen), findsOneWidget);

    await fill(tester, 'delivery-cost', '0');
    expect(find.text('Enter a number above zero, or pick Free.'), findsOneWidget);
    await fill(tester, 'delivery-cost', 'soon');
    expect(find.text('Enter a number above zero, or pick Free.'), findsOneWidget);
    expect((await store.fetchDeals()).length, 36);

    // "Not sure" takes the field, and its problem, away.
    await tapChip(tester, 'share-delivery-notSure');
    expect(find.byKey(const Key('share-delivery-cost')), findsNothing);
    await submit(tester);

    expect(find.byType(ShareDealScreen), findsNothing);
    expect((await sharedDeal(store)).deliveryCost, isNull);
  });

  test('the checks of the new fields', () {
    expect(DealValidators.parseAmount('2,5'), 2.5);
    expect(DealValidators.parseAmount(' 1020 '), 1020);
    expect(DealValidators.parseAmount('0.0354'), 0.035);
    expect(DealValidators.parseAmount('x'), isNull);

    expect(_valid.packageAmount(''), isNull);
    expect(_valid.packageAmount('  '), isNull);
    expect(_valid.packageAmount('12'), isNull);
    expect(_valid.packageAmount('-1'), 'Enter a size above zero, like 2.5.');

    expect(_valid.packageUnit(null, ''), isNull);
    expect(_valid.packageUnit(PackageUnit.kg, ''), isNull);
    expect(_valid.packageUnit(PackageUnit.kg, '3'), isNull);
    expect(_valid.packageUnit(null, '3'), 'Choose a unit: kg, g, litre, ml or units.');

    expect(_valid.deliveryCost(''), 'Enter the delivery cost.');
    expect(_valid.deliveryCost('-3'), 'Enter a number above zero, or pick Free.');
    expect(_valid.deliveryCost('19,90'), isNull);
  });
}
