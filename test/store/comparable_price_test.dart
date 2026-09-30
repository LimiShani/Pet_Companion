import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/deal_detail_screen.dart';
import 'package:pet_companion/models/pet.dart';

import 'store_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  PackageSize kg(double amount) => PackageSize(amount, PackageUnit.kg);

  Finder onCard(String dealId, String text) =>
      find.descendant(of: find.byKey(ValueKey('deal-card-$dealId')), matching: find.text(text));

  Finder onPage(String text) => find.descendant(of: find.byType(DealDetailScreen), matching: find.text(text));

  Future<void> pickSort(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('Sort deals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('deal cards', () {
    testWidgets('show the unit price and the delivery cost when the deal has them', (tester) async {
      await pumpStore(
        tester,
        repository: fakeStore(seed: [
          testDeal('full', price: 179, originalPrice: 299, package: kg(12), delivery: 25),
          testDeal('free', price: 89, originalPrice: 129, package: kg(4), delivery: 0),
          testDeal('each', price: 19.90, originalPrice: 29.90, package: const PackageSize(300, PackageUnit.unit)),
          testDeal('plain', price: 74, originalPrice: 109),
        ]),
      );

      expect(onCard('full', '₪14.92 per kg'), findsOneWidget);
      expect(onCard('full', '+ ₪25 delivery'), findsOneWidget);

      expect(onCard('free', '₪22.25 per kg'), findsOneWidget);
      expect(onCard('free', 'Free delivery'), findsOneWidget);

      expect(onCard('each', '₪0.07 each'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('deal-card-each')), matching: find.textContaining('delivery')),
          findsNothing);

      // A deal with none of the new details looks as it always did.
      final plain = find.byKey(const ValueKey('deal-card-plain'));
      expect(find.descendant(of: plain, matching: find.textContaining(' per ')), findsNothing);
      expect(find.descendant(of: plain, matching: find.textContaining('delivery')), findsNothing);
      expect(find.descendant(of: plain, matching: find.text('₪74')), findsOneWidget);
    });
  });

  group('sort: lowest unit price', () {
    List<Deal> seed() => [
          testDeal('nosize', price: 1, originalPrice: 2),
          testDeal('each', price: 6, originalPrice: 12, package: const PackageSize(3, PackageUnit.unit)),
          testDeal('litre', price: 10, originalPrice: 20, package: const PackageSize(5, PackageUnit.litre)),
          testDeal('g-dear', price: 9, originalPrice: 18, package: const PackageSize(300, PackageUnit.g)),
          testDeal('kg-cheap', price: 20, originalPrice: 40, package: kg(4)),
          testDeal('over', price: 1, originalPrice: 2, package: kg(10), endsIn: const Duration(days: -1)),
        ];

    testWidgets('weight first, then volume, then count, then no size; expired last', (tester) async {
      // A tall screen, so all three rows of the grid are built.
      await pumpStore(tester, repository: fakeStore(seed: seed()), size: const Size(390, 1600));

      await pickSort(tester, 'Lowest unit price');

      expect(find.text('Lowest unit price'), findsOneWidget);
      expect(shownDealIds(tester), ['kg-cheap', 'g-dear', 'litre', 'each', 'nosize', 'over']);
      // Grams are compared per kilo.
      expect(onCard('g-dear', '₪30 per kg'), findsOneWidget);
      expect(onCard('kg-cheap', '₪5 per kg'), findsOneWidget);
      expect(onCard('litre', '₪2 per litre'), findsOneWidget);
      expect(onCard('each', '₪2 each'), findsOneWidget);
    });

    testWidgets('the sort menu lists the five orders', (tester) async {
      await pumpStore(tester, repository: fakeStore(seed: seed()));

      await tester.tap(find.byTooltip('Sort deals'));
      await tester.pumpAndSettle();

      final items = tester.widgetList<PopupMenuItem<DealSort>>(find.byType(PopupMenuItem<DealSort>));
      expect(
        [for (final item in items) item.value],
        [DealSort.biggestDiscount, DealSort.lowestPrice, DealSort.lowestUnitPrice, DealSort.newest, DealSort.endingSoon],
      );
    });

    testWidgets('in the sample catalogue the big bag of cat food comes out cheapest per kilo', (tester) async {
      await pumpStore(tester, extraPets: [const Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat)]);
      await tapPetPill(tester, 'Mitzi');
      final food = find.widgetWithText(ChoiceChip, 'Food');
      await tester.tap(food);
      await tester.pumpAndSettle();

      await pickSort(tester, 'Lowest unit price');

      expect(find.text('4 deals for cats'), findsOneWidget);
      expect(
        shownDealIds(tester),
        ['d-cat-dry-salmon-10kg', 'd-cat-dry-chicken-4kg', 'd-kitten-dry-2kg', 'd-cat-wet-pouches'],
      );
      expect(onCard('d-cat-dry-salmon-10kg', '₪18.90 per kg'), findsOneWidget);
      expect(onCard('d-cat-dry-salmon-10kg', '+ ₪29 delivery'), findsOneWidget);
      expect(onCard('d-cat-dry-chicken-4kg', '₪22.25 per kg'), findsOneWidget);
      expect(onCard('d-cat-dry-chicken-4kg', 'Free delivery'), findsOneWidget);
    });
  });

  group('deal page', () {
    testWidgets('shows the unit price, package, delivery, final price, who it is for and the checked date',
        (tester) async {
      await pumpStore(tester);
      await tapPetPill(tester, 'All animals');
      await tester.enterText(find.byType(TextField), 'clumping');
      await tester.pumpAndSettle();
      await openDeal(tester, 'd-clumping-litter-10kg');

      expect(onPage('Clumping cat litter, 10 kg'), findsOneWidget);
      expect(onPage('Litter & cleaning'), findsOneWidget);
      expect(onPage('For cats'), findsOneWidget);
      expect(onPage('₪36.90'), findsOneWidget);
      expect(onPage('₪59.90'), findsOneWidget);
      expect(onPage('You save ₪23 (38%)'), findsOneWidget);

      expect(onPage('Unit price'), findsOneWidget);
      expect(onPage('₪3.69 per kg'), findsOneWidget);
      expect(onPage('Package'), findsOneWidget);
      expect(onPage('10 kg'), findsOneWidget);
      expect(onPage('Delivery'), findsOneWidget);
      expect(onPage('+ ₪25'), findsOneWidget);
      expect(onPage('Final price'), findsOneWidget);
      expect(onPage('₪61.90'), findsOneWidget);

      expect(onPage('Price checked'), findsOneWidget);
      expect(onPage('29.09.26 · yesterday'), findsOneWidget);
      expect(onPage('2 days ago'), findsOneWidget);
      expect(find.byKey(const Key('deal-price-stale')), findsNothing);
    });

    Future<void> openOnly(WidgetTester tester, Deal deal) async {
      await pumpStore(tester, repository: fakeStore(seed: [deal]));
      await openDeal(tester, deal.id);
    }

    testWidgets('free delivery: the final price is the price', (tester) async {
      await openOnly(tester, testDeal('free', price: 89, originalPrice: 129, package: kg(4), delivery: 0));

      expect(onPage('₪22.25 per kg'), findsOneWidget);
      expect(onPage('4 kg'), findsOneWidget);
      expect(onPage('Free'), findsOneWidget);
      expect(onPage('Final price'), findsOneWidget);
      // Once as the price, once as the final price.
      expect(onPage('₪89'), findsNWidgets(2));
    });

    testWidgets('delivery not given: it says so, and there is no final price', (tester) async {
      await openOnly(tester, testDeal('unknown', price: 54, originalPrice: 69, package: kg(2)));

      expect(onPage('₪27 per kg'), findsOneWidget);
      expect(onPage('Not given'), findsOneWidget);
      expect(onPage('Check with the seller'), findsOneWidget);
      expect(onPage('Final price'), findsNothing);
    });

    testWidgets('a delivery cost without a package size shows the final price only', (tester) async {
      await openOnly(tester, testDeal('delivered', price: 65, originalPrice: 119, delivery: 20));

      expect(onPage('Unit price'), findsNothing);
      expect(onPage('Package'), findsNothing);
      expect(onPage('+ ₪20'), findsOneWidget);
      expect(onPage('₪85'), findsOneWidget);
    });

    testWidgets('a deal with none of the new details keeps the old price card', (tester) async {
      await openOnly(tester, testDeal('plain', price: 74, originalPrice: 109));

      expect(onPage('You save ₪35 (32%)'), findsOneWidget);
      expect(onPage('Unit price'), findsNothing);
      expect(onPage('Package'), findsNothing);
      expect(onPage('Delivery'), findsNothing);
      expect(onPage('Final price'), findsNothing);
      // It is for every pet, and its price was checked when it was posted.
      expect(onPage('For all pets'), findsOneWidget);
      expect(onPage('30.09.26 · today'), findsOneWidget);
    });

    testWidgets('who a deal is for is spelled out', (tester) async {
      await openOnly(
        tester,
        testDeal('both', species: const {PetSpecies.cat, PetSpecies.dog, PetSpecies.rabbit}),
      );
      expect(onPage('For dogs, cats and rabbits'), findsOneWidget);
    });

    testWidgets('a price checked more than 30 days ago gets a note', (tester) async {
      await openOnly(
        tester,
        testDeal('old', posted: const Duration(days: 60), checked: const Duration(days: 49)),
      );

      expect(find.byKey(const Key('deal-price-stale')), findsOneWidget);
      expect(onPage('This price was checked a while ago. It may have changed.'), findsOneWidget);
      expect(onPage('12.08.26 · 49 days ago'), findsOneWidget);
    });

    testWidgets('a price checked 30 days ago gets none, and neither does an expired deal', (tester) async {
      await pumpStore(
        tester,
        repository: fakeStore(seed: [
          testDeal('month', posted: const Duration(days: 40), checked: const Duration(days: 30)),
          testDeal('over', posted: const Duration(days: 60), endsIn: const Duration(days: -5)),
        ]),
      );

      await openDeal(tester, 'month');
      expect(find.byKey(const Key('deal-price-stale')), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await openDeal(tester, 'over');
      expect(find.byKey(const Key('deal-price-stale')), findsNothing);
      expect(onPage('This deal ended on 25.09.26'), findsOneWidget);
    });
  });
}
