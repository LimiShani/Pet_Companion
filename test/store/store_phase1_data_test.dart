import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/deal_filters.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/data/sample_deals.dart';
import 'package:pet_companion/features/store/data/store_repository.dart';
import 'package:pet_companion/features/store/store_format.dart';
import 'package:pet_companion/features/store/store_strings.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

/// The data side of phase 1: package sizes and unit prices, delivery, the
/// checked date, the animals a deal is for, and the new category.
final _now = DateTime(2026, 9, 30, 12);

/// The English words and formats.
final _words = lookupStoreL10n(englishLocale);
final _format = StoreFormat.forLocale(englishLocale);

Deal _deal(
  String id, {
  double price = 50,
  double originalPrice = 100,
  PackageSize? package,
  double? delivery,
  Set<PetSpecies> species = const {},
  Duration posted = const Duration(hours: 1),
  Duration? checked,
  Duration? endsIn,
}) {
  return Deal(
    id: id,
    title: 'Deal $id',
    category: DealCategory.food,
    price: price,
    originalPrice: originalPrice,
    sellerName: 'Shop',
    link: 'https://example.com/$id',
    postedAt: _now.subtract(posted),
    expiresAt: endsIn == null ? null : _now.add(endsIn),
    package: package,
    deliveryCost: delivery,
    priceCheckedAt: checked == null ? null : _now.subtract(checked),
    species: species,
  );
}

List<String> _ids(Iterable<Deal> deals) => [for (final d in deals) d.id];

void main() {
  group('unit price', () {
    test('is the price per kg, per litre or per item', () {
      final perKg = _deal('a', price: 179, package: const PackageSize(12, PackageUnit.kg)).unitPrice!;
      expect(perKg.kind, UnitKind.weight);
      expect(perKg.amount, closeTo(14.9167, 0.0001));

      final fromGrams = _deal('b', price: 27, package: const PackageSize(200, PackageUnit.g)).unitPrice!;
      expect(fromGrams.kind, UnitKind.weight);
      expect(fromGrams.amount, closeTo(135, 0.0001));

      final perLitre = _deal('c', price: 29.90, package: const PackageSize(5, PackageUnit.litre)).unitPrice!;
      expect(perLitre.kind, UnitKind.volume);
      expect(perLitre.amount, closeTo(5.98, 0.0001));

      final fromMl = _deal('d', price: 24, package: const PackageSize(500, PackageUnit.ml)).unitPrice!;
      expect(fromMl.kind, UnitKind.volume);
      expect(fromMl.amount, closeTo(48, 0.0001));

      final each = _deal('e', price: 19.90, package: const PackageSize(300, PackageUnit.unit)).unitPrice!;
      expect(each.kind, UnitKind.count);
      expect(each.amount, closeTo(0.0663, 0.0001));
    });

    test('is missing without a package size, and never includes delivery', () {
      expect(_deal('a').unitPrice, isNull);
      expect(_deal('a', package: const PackageSize(0, PackageUnit.kg)).unitPrice, isNull);

      final withDelivery = _deal('a', price: 100, delivery: 30, package: const PackageSize(10, PackageUnit.kg));
      expect(withDelivery.unitPrice!.amount, 10);
      expect(withDelivery.finalPrice, 130);
    });

    test('is formatted with its unit', () {
      String text(double price, PackageSize size) =>
          _format.unitPrice(_deal('a', price: price, package: size).unitPrice!, 'ILS');

      expect(text(189, const PackageSize(10, PackageUnit.kg)), '₪18.90 per kg');
      expect(text(54, const PackageSize(2, PackageUnit.kg)), '₪27 per kg');
      expect(text(34.90, const PackageSize(1020, PackageUnit.g)), '₪34.22 per kg');
      expect(text(29.90, const PackageSize(5, PackageUnit.litre)), '₪5.98 per litre');
      expect(text(19.90, const PackageSize(300, PackageUnit.unit)), '₪0.07 each');
      // Never "₪0 each".
      expect(text(3, const PackageSize(1000, PackageUnit.unit)), '₪0.01 each');
    });

    test('package sizes read naturally', () {
      expect(_format.package(const PackageSize(12, PackageUnit.kg)), '12 kg');
      expect(_format.package(const PackageSize(4.8, PackageUnit.kg)), '4.8 kg');
      expect(_format.package(const PackageSize(1020, PackageUnit.g)), '1,020 g');
      expect(_format.package(const PackageSize(1, PackageUnit.litre)), '1 litre');
      expect(_format.package(const PackageSize(60, PackageUnit.litre)), '60 litres');
      expect(_format.package(const PackageSize(500, PackageUnit.ml)), '500 ml');
      expect(_format.package(const PackageSize(1, PackageUnit.unit)), '1 unit');
      expect(_format.package(const PackageSize(28, PackageUnit.unit)), '28 units');
    });
  });

  group('delivery and the final price', () {
    test('free, paid and not given', () {
      expect(_deal('a', price: 89, delivery: 0).finalPrice, 89);
      expect(_deal('a', price: 36.90, delivery: 25).finalPrice, closeTo(61.90, 0.0001));
      expect(_deal('a', price: 54).finalPrice, isNull);
    });
  });

  group('the checked date', () {
    test('falls back to the posted date', () {
      final legacy = _deal('a', posted: const Duration(days: 3));
      expect(legacy.priceCheckedAt, isNull);
      expect(legacy.priceChecked, legacy.postedAt);

      final rechecked = _deal('a', posted: const Duration(days: 3), checked: const Duration(days: 1));
      expect(rechecked.priceChecked, _now.subtract(const Duration(days: 1)));
    });

    test('is stale after 30 days', () {
      expect(_deal('a', checked: const Duration(days: 30)).isPriceStale(_now), isFalse);
      expect(_deal('a', checked: const Duration(days: 31)).isPriceStale(_now), isTrue);
      expect(_deal('a', posted: const Duration(days: 45)).isPriceStale(_now), isTrue);
      expect(_deal('a', posted: const Duration(days: 45), checked: const Duration(days: 2)).isPriceStale(_now), isFalse);
    });

    test('is shown with how long ago it was', () {
      expect(_format.checked(_now.subtract(const Duration(hours: 2)), _now), '30.09.26 · today');
      expect(_format.checked(_now.subtract(const Duration(hours: 20)), _now), '29.09.26 · yesterday');
      expect(_format.checked(_now.subtract(const Duration(days: 49)), _now), '12.08.26 · 49 days ago');
    });
  });

  group('the animals a deal is for', () {
    test('none means every pet', () {
      final everyone = _deal('a');
      expect(everyone.isForEveryPet, isTrue);
      for (final kind in PetSpecies.values) {
        expect(everyone.suits(kind), isTrue);
      }

      final cats = _deal('b', species: const {PetSpecies.cat});
      expect(cats.isForEveryPet, isFalse);
      expect(cats.suits(PetSpecies.cat), isTrue);
      expect(cats.suits(PetSpecies.dog), isFalse);
    });

    test('are named in the usual order', () {
      final deal = _deal('a', species: const {PetSpecies.rabbit, PetSpecies.cat, PetSpecies.dog});
      expect(deal.speciesInOrder, [PetSpecies.dog, PetSpecies.cat, PetSpecies.rabbit]);
      expect(_words.forWhom(deal.speciesInOrder), 'For dogs, cats and rabbits');
      expect(_words.animalsTag(deal.speciesInOrder), 'Dogs, cats, rabbits');
      expect(_words.forWhom(const [PetSpecies.cat]), 'For cats');
      expect(_words.forWhom(const [PetSpecies.dog, PetSpecies.cat]), 'For dogs and cats');
      expect(_words.forWhom(const []), 'For all pets');
      expect(_words.animalsTag(const [PetSpecies.other]), 'Other');
    });

    test('the pet filter keeps what suits the pet, unless all animals are asked for', () {
      final deals = [
        _deal('dog', species: const {PetSpecies.dog}),
        _deal('cat', species: const {PetSpecies.cat}),
        _deal('both', species: const {PetSpecies.dog, PetSpecies.cat}),
        _deal('every'),
      ];
      List<String> shown(StoreFilter filter, PetSpecies? pet) => _ids(visibleDeals(deals, filter, _now, pet: pet));

      expect(shown(const StoreFilter(), PetSpecies.cat), unorderedEquals(['cat', 'both', 'every']));
      expect(shown(const StoreFilter(), PetSpecies.dog), unorderedEquals(['dog', 'both', 'every']));
      expect(shown(const StoreFilter(), PetSpecies.bird), ['every']);
      expect(shown(const StoreFilter(allAnimals: true), PetSpecies.bird), hasLength(4));
      expect(shown(const StoreFilter(), null), hasLength(4));
    });

    test('the filter keeps its choice of animals when the rest changes', () {
      const all = StoreFilter(allAnimals: true);
      expect(all.withQuery('x').allAnimals, isTrue);
      expect(all.withCategory(DealCategory.toys).allAnimals, isTrue);
      expect(all.withSort(DealSort.newest).allAnimals, isTrue);
      expect(all.withAllAnimals(false), const StoreFilter());
      expect(all == const StoreFilter(), isFalse);
      expect(all.isNarrowed, isFalse);
    });
  });

  group('sort by lowest unit price', () {
    test('weight, then volume, then count, then no size, expired last', () {
      final deals = [
        _deal('nosize', price: 1),
        _deal('each', price: 6, package: const PackageSize(3, PackageUnit.unit)),
        _deal('ml', price: 5, package: const PackageSize(500, PackageUnit.ml)),
        _deal('litre', price: 10, package: const PackageSize(5, PackageUnit.litre)),
        _deal('grams', price: 9, package: const PackageSize(300, PackageUnit.g)),
        _deal('kilos', price: 20, package: const PackageSize(4, PackageUnit.kg)),
        _deal('over', price: 1, package: const PackageSize(10, PackageUnit.kg), endsIn: const Duration(days: -1)),
      ];
      expect(
        _ids(sortDeals(deals, DealSort.lowestUnitPrice, _now)),
        ['kilos', 'grams', 'litre', 'ml', 'each', 'nosize', 'over'],
      );
    });

    test('the sort orders are listed as the menu shows them', () {
      expect(
        [for (final sort in DealSort.values) _words.sort(sort)],
        ['Biggest discount', 'Lowest price', 'Lowest unit price', 'Newest', 'Ending soon'],
      );
    });
  });

  group('database rows', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 'abc',
          'title': 'Litter',
          'description': '',
          'category': 'litter_and_cleaning',
          'price': 36.9,
          'original_price': 59.9,
          'currency': 'ILS',
          'seller_name': 'Clean Paws',
          'link': 'https://example.com/litter',
          'posted_at': '2026-09-28T10:00:00Z',
          'expires_at': null,
          ...extra,
        };

    test('the new columns are read', () {
      final deal = Deal.fromRow(row({
        'package_amount': '10.000',
        'package_unit': 'kg',
        'delivery_cost': 25,
        'price_checked_at': '2026-09-29T09:00:00Z',
        'species': ['cat', 'dog', 'dragon'],
      }));
      expect(deal.category, DealCategory.litterAndCleaning);
      expect(deal.package, const PackageSize(10, PackageUnit.kg));
      expect(deal.deliveryCost, 25);
      expect(deal.priceCheckedAt!.toUtc(), DateTime.utc(2026, 9, 29, 9));
      // An animal this version does not know is left out.
      expect(deal.species, {PetSpecies.cat, PetSpecies.dog});
    });

    test('a row from before the new columns still reads', () {
      final deal = Deal.fromRow(row({}));
      expect(deal.package, isNull);
      expect(deal.deliveryCost, isNull);
      expect(deal.priceCheckedAt, isNull);
      expect(deal.priceChecked, deal.postedAt);
      expect(deal.species, isEmpty);
    });

    test('empty new columns read as "not given"', () {
      final deal = Deal.fromRow(row({
        'package_amount': null,
        'package_unit': null,
        'delivery_cost': 0,
        'species': <dynamic>[],
      }));
      expect(deal.package, isNull);
      expect(deal.deliveryCost, 0);
      expect(deal.species, isEmpty);
    });

    test('every unit and category has its own stored code', () {
      expect([for (final u in PackageUnit.values) u.code], ['kg', 'g', 'l', 'ml', 'unit']);
      for (final unit in PackageUnit.values) {
        expect(PackageUnit.fromCode(unit.code), unit);
      }
      expect(PackageUnit.fromCode('stone'), isNull);
      expect(PackageUnit.fromCode(null), isNull);

      expect(
        [for (final c in DealCategory.values) c.code],
        ['food', 'treats', 'litter_and_cleaning', 'toys', 'health', 'grooming', 'accessories', 'beds_and_crates'],
      );
      for (final category in DealCategory.values) {
        expect(DealCategory.fromCode(category.code), category);
      }
    });

    test('a draft sends the new columns only when they carry something', () {
      const plain = DealDraft(
        title: 'Bowl',
        category: DealCategory.accessories,
        price: 10,
        originalPrice: 20,
        sellerName: 'Shop',
        link: 'https://example.com/bowl',
      );
      final plainRow = plain.toRow(userId: 'u1');
      for (final column in ['package_amount', 'package_unit', 'delivery_cost', 'species', 'price_checked_at']) {
        expect(plainRow.containsKey(column), isFalse, reason: column);
      }

      const full = DealDraft(
        title: 'Litter',
        category: DealCategory.litterAndCleaning,
        price: 36.90,
        originalPrice: 59.90,
        sellerName: 'Clean Paws',
        link: 'https://example.com/litter',
        package: PackageSize(10, PackageUnit.kg),
        deliveryCost: 0,
        species: {PetSpecies.cat, PetSpecies.dog},
      );
      final fullRow = full.toRow(userId: 'u1');
      expect(fullRow['category'], 'litter_and_cleaning');
      expect(fullRow['package_amount'], 10);
      expect(fullRow['package_unit'], 'kg');
      expect(fullRow['delivery_cost'], 0);
      expect(fullRow['species'], ['dog', 'cat']);
      // The database stamps the checked date itself.
      expect(fullRow.containsKey('price_checked_at'), isFalse);
    });
  });

  group('FakeStoreRepository', () {
    FakeStoreRepository repo() => FakeStoreRepository(latency: Duration.zero, now: () => _now);

    DealDraft draft({PackageSize? package, double? delivery, Set<PetSpecies> species = const {}}) => DealDraft(
          title: 'Litter',
          category: DealCategory.litterAndCleaning,
          price: 36.90,
          originalPrice: 59.90,
          sellerName: 'Clean Paws',
          link: 'https://example.com/litter',
          package: package,
          deliveryCost: delivery,
          species: species,
        );

    test('a shared deal keeps its details and is checked today', () async {
      final deal = await repo().shareDeal(
        userId: 'u1',
        draft: draft(package: const PackageSize(10, PackageUnit.kg), delivery: 25, species: {PetSpecies.cat}),
      );
      expect(deal.package, const PackageSize(10, PackageUnit.kg));
      expect(deal.deliveryCost, 25);
      expect(deal.species, {PetSpecies.cat});
      expect(deal.priceCheckedAt, _now);
      expect(deal.isPriceStale(_now), isFalse);
    });

    test('a package of nothing and a negative delivery cost are refused', () async {
      final r = repo();
      expect(
        () => r.shareDeal(userId: 'u1', draft: draft(package: const PackageSize(0, PackageUnit.kg))),
        throwsA(isA<StoreException>()),
      );
      expect(() => r.shareDeal(userId: 'u1', draft: draft(delivery: -5)), throwsA(isA<StoreException>()));
      // Free delivery is fine.
      expect((await r.shareDeal(userId: 'u1', draft: draft(delivery: 0))).deliveryCost, 0);
    });
  });

  group('the sample catalogue', () {
    final deals = sampleDeals(_now);

    test('has deals for cats in every part of a cat\'s shopping', () {
      final catOnly = deals.where((d) => d.species.length == 1 && d.species.contains(PetSpecies.cat)).toList();
      expect(catOnly.length, greaterThanOrEqualTo(10));
      expect({for (final d in catOnly) d.category}, {
        DealCategory.food,
        DealCategory.treats,
        DealCategory.litterAndCleaning,
        DealCategory.toys,
        DealCategory.accessories,
      });
    });

    test('no kind of pet opens an empty Store', () {
      for (final kind in PetSpecies.values) {
        final live = deals.where((d) => d.suits(kind) && !d.isExpired(_now));
        expect(live.length, greaterThanOrEqualTo(3), reason: kind.name);
      }
      expect(deals.where((d) => d.suits(PetSpecies.dog)).length, 23);
      expect(deals.where((d) => d.suits(PetSpecies.cat)).length, 18);
    });

    test('uses the new category and carries sizes, delivery costs and checked dates', () {
      expect(deals.where((d) => d.category == DealCategory.litterAndCleaning).length, 6);
      expect(deals.where((d) => d.package != null).length, greaterThanOrEqualTo(20));
      expect(deals.where((d) => d.deliveryCost == 0), isNotEmpty);
      expect(deals.where((d) => (d.deliveryCost ?? 0) > 0), isNotEmpty);
      expect(deals.where((d) => d.deliveryCost == null), isNotEmpty);
      for (final d in deals) {
        expect(d.priceCheckedAt, isNotNull, reason: d.id);
        expect(d.priceChecked.isBefore(d.postedAt), isFalse, reason: d.id);
        expect(d.package == null || d.package!.amount > 0, isTrue, reason: d.id);
      }
      // One deal shows the "may have changed" note.
      expect(deals.where((d) => d.isPriceStale(_now) && !d.isExpired(_now)).length, 1);
    });

    test('a bigger bag is cheaper per kilo but not the bigger discount', () {
      Deal byId(String id) => deals.firstWhere((d) => d.id == id);
      final big = byId('d-cat-dry-salmon-10kg');
      final small = byId('d-cat-dry-chicken-4kg');
      expect(big.unitPrice!.amount, lessThan(small.unitPrice!.amount));
      expect(big.discountPercent, lessThan(small.discountPercent));
      expect(_format.unitPrice(byId('d-cat-wet-pouches').unitPrice!, 'ILS'), '₪34.22 per kg');
    });
  });
}
