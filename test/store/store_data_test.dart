import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/store/data/deal.dart';
import 'package:pet_companion/features/store/data/deal_filters.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/data/sample_deals.dart';
import 'package:pet_companion/features/store/data/store_repository.dart';
import 'package:pet_companion/features/store/store_format.dart';
import 'package:pet_companion/l10n/l10n.dart';

final _now = DateTime(2026, 9, 30, 12);

/// Money and times as the English screens show them.
final _format = StoreFormat.forLocale(englishLocale);

Deal _deal(
  String id, {
  double price = 50,
  double originalPrice = 100,
  DealCategory category = DealCategory.toys,
  Duration posted = const Duration(hours: 1),
  Duration? endsIn,
  String title = 'Thing',
  String seller = 'Shop',
  String? sharedBy,
}) {
  return Deal(
    id: id,
    title: title,
    category: category,
    price: price,
    originalPrice: originalPrice,
    sellerName: seller,
    link: 'https://example.com/$id',
    sharedBy: sharedBy,
    postedAt: _now.subtract(posted),
    expiresAt: endsIn == null ? null : _now.add(endsIn),
  );
}

List<String> _ids(Iterable<Deal> deals) => [for (final d in deals) d.id];

void main() {
  group('Deal', () {
    test('derives the discount and the saving', () {
      final deal = _deal('a', price: 179, originalPrice: 299);
      expect(deal.discountPercent, 40);
      expect(deal.amountSaved, 120);
      expect(deal.currency, kStoreDefaultCurrency);
      expect(deal.isCurated, isTrue);
    });

    test('a price at or above the original is no discount', () {
      expect(_deal('a', price: 100, originalPrice: 100).discountPercent, 0);
      expect(_deal('a', price: 120, originalPrice: 100).amountSaved, 0);
    });

    test('is expired from its end time on', () {
      expect(_deal('a').isExpired(_now), isFalse);
      expect(_deal('a', endsIn: const Duration(minutes: 1)).isExpired(_now), isFalse);
      expect(_deal('a', endsIn: Duration.zero).isExpired(_now), isTrue);
      expect(_deal('a', endsIn: const Duration(days: -1)).isExpired(_now), isTrue);
    });

    test('maps a database row', () {
      final deal = Deal.fromRow({
        'id': 'abc',
        'title': 'Crate',
        'description': 'Folds flat',
        'category': 'beds_and_crates',
        'price': 189,
        'original_price': '279.00',
        'currency': 'ILS',
        'seller_name': 'Cozy Den',
        'link': 'https://example.com/crate',
        'image_url': null,
        'shared_by': 'user-1',
        'shared_by_name': 'Dana',
        'posted_at': '2026-09-29T10:00:00Z',
        'expires_at': null,
      });
      expect(deal.category, DealCategory.bedsAndCrates);
      expect(deal.price, 189.0);
      expect(deal.originalPrice, 279.0);
      expect(deal.sharedByName, 'Dana');
      expect(deal.isSharedBy('user-1'), isTrue);
      expect(deal.postedAt.toUtc(), DateTime.utc(2026, 9, 29, 10));
      expect(deal.expiresAt, isNull);
    });

    test('a draft becomes a row owned by the sharer', () {
      const draft = DealDraft(
        title: 'Bowl',
        category: DealCategory.bedsAndCrates,
        price: 10,
        originalPrice: 20,
        sellerName: 'Shop',
        link: 'https://example.com/bowl',
      );
      final row = draft.toRow(userId: 'user-1');
      expect(row['shared_by'], 'user-1');
      expect(row['category'], 'beds_and_crates');
      expect(row['currency'], kStoreDefaultCurrency);
      expect(row.containsKey('posted_at'), isFalse);
    });
  });

  group('sorting and filtering', () {
    final deals = [
      _deal('cheap', price: 10, originalPrice: 12, posted: const Duration(days: 3), endsIn: const Duration(days: 9)),
      _deal('bargain', price: 30, originalPrice: 100, posted: const Duration(days: 2)),
      _deal('fresh', price: 80, originalPrice: 100, posted: const Duration(minutes: 5), endsIn: const Duration(days: 1)),
      _deal('over', price: 1, originalPrice: 100, posted: const Duration(minutes: 1), endsIn: const Duration(days: -1)),
    ];

    test('biggest discount first, expired last', () {
      expect(_ids(sortDeals(deals, DealSort.biggestDiscount, _now)), ['bargain', 'fresh', 'cheap', 'over']);
    });

    test('lowest price first, expired last', () {
      expect(_ids(sortDeals(deals, DealSort.lowestPrice, _now)), ['cheap', 'bargain', 'fresh', 'over']);
    });

    test('newest first, expired last', () {
      expect(_ids(sortDeals(deals, DealSort.newest, _now)), ['fresh', 'bargain', 'cheap', 'over']);
    });

    test('ending soon first, no end date after, expired last', () {
      expect(_ids(sortDeals(deals, DealSort.endingSoon, _now)), ['fresh', 'cheap', 'bargain', 'over']);
    });

    test('search matches the title, seller and category, every word', () {
      final list = [
        _deal('a', title: 'Rope tug toy', seller: 'Toy Barn'),
        _deal('b', title: 'Salmon kibble', seller: 'Happy Paws', category: DealCategory.food),
        _deal('c', title: 'Salmon treats', seller: 'Treat Jar', category: DealCategory.treats),
      ];
      List<String> search(String q) => _ids(visibleDeals(list, StoreFilter(query: q), _now));

      expect(search('SALMON'), unorderedEquals(['b', 'c']));
      expect(search('salmon jar'), ['c']);
      expect(search('barn'), ['a']);
      expect(search('food'), ['b']);
      expect(search('parrot'), isEmpty);
      expect(search('   '), hasLength(3));
    });

    test('category filter keeps only that category', () {
      final list = [_deal('a'), _deal('b', category: DealCategory.food)];
      expect(_ids(visibleDeals(list, const StoreFilter(category: DealCategory.food), _now)), ['b']);
    });
  });

  group('StoreFormat', () {
    test('money drops the decimals of a whole amount', () {
      expect(_format.money(179, 'ILS'), '₪179');
      expect(_format.money(39.9, 'ILS'), '₪39.90');
      expect(_format.money(1299, 'USD'), r'$1,299');
    });

    test('time ago', () {
      String ago(Duration d) => _format.timeAgo(_now.subtract(d), _now);
      expect(ago(const Duration(seconds: 20)), 'Just now');
      expect(ago(const Duration(minutes: 30)), '30 min ago');
      expect(ago(const Duration(hours: 1)), '1 hour ago');
      expect(ago(const Duration(hours: 3)), '3 hours ago');
      expect(ago(const Duration(hours: 30)), 'Yesterday');
      expect(ago(const Duration(days: 9)), '9 days ago');
      expect(ago(const Duration(days: 60)), '01.08.26');
    });

    test('end of a deal', () {
      expect(_format.ends(null, _now), 'No end date');
      expect(_format.ends(_now.add(const Duration(days: 12)), _now), '12.10.26 · 12 days left');
      expect(_format.ends(_now.add(const Duration(days: 1)), _now), '01.10.26 · 1 day left');
      expect(_format.ends(_now.add(const Duration(hours: 2)), _now), '30.09.26 · ends today');
      expect(_format.ends(_now.subtract(const Duration(days: 2)), _now), 'Ended 28.09.26');
    });
  });

  group('FakeStoreRepository', () {
    FakeStoreRepository repo() => FakeStoreRepository(latency: Duration.zero, now: () => _now);

    const draft = DealDraft(
      title: 'Travel bowl',
      category: DealCategory.accessories,
      price: 18,
      originalPrice: 30,
      sellerName: 'Park Play',
      link: 'https://example.com/bowl',
    );

    test('is seeded with believable deals in every category, for dogs, cats and others', () async {
      final deals = await repo().fetchDeals();
      expect(deals.length, 36);
      expect({for (final d in deals) d.category}, DealCategory.values.toSet());
      expect({for (final d in deals) d.id}.length, deals.length);
      for (final d in deals) {
        expect(d.link, startsWith('https://example.com/'));
        expect(d.currency, kStoreDefaultCurrency);
        expect(d.price, lessThan(d.originalPrice));
        expect(d.imageUrl, isNull);
      }
      expect(deals.where((d) => d.isExpired(_now)), isNotEmpty);
      expect(deals.where((d) => d.isCurated), isNotEmpty);
    });

    test('the sample data follows the clock', () {
      final later = _now.add(const Duration(days: 100));
      expect(sampleDeals(later).first.postedAt.isAfter(_now), isTrue);
    });

    test('favourites are kept per user', () async {
      final r = repo();
      await r.setSaved(userId: 'u1', dealId: 'd-fetch-balls', saved: true);
      await r.setSaved(userId: 'u1', dealId: 'd-fetch-balls', saved: true);
      expect(await r.fetchSavedDealIds(userId: 'u1'), {'d-fetch-balls'});
      expect(await r.fetchSavedDealIds(userId: 'u2'), isEmpty);
      await r.setSaved(userId: 'u1', dealId: 'd-fetch-balls', saved: false);
      expect(await r.fetchSavedDealIds(userId: 'u1'), isEmpty);
    });

    test('sharing adds a deal owned by the user, stamped with the clock', () async {
      final r = repo();
      final deal = await r.shareDeal(userId: 'u1', userName: 'Dana', draft: draft);
      expect(deal.sharedBy, 'u1');
      expect(deal.sharedByName, 'Dana');
      expect(deal.postedAt, _now);
      expect((await r.fetchDeals()).first.id, deal.id);
    });

    test('sharing rejects a price that is not a discount and a plain http link', () async {
      final r = repo();
      const notCheaper = DealDraft(
        title: 'Bowl',
        category: DealCategory.accessories,
        price: 40,
        originalPrice: 30,
        sellerName: 'Shop',
        link: 'https://example.com/bowl',
      );
      const insecure = DealDraft(
        title: 'Bowl',
        category: DealCategory.accessories,
        price: 10,
        originalPrice: 30,
        sellerName: 'Shop',
        link: 'http://example.com/bowl',
      );
      expect(() => r.shareDeal(userId: 'u1', draft: notCheaper), throwsA(isA<StoreException>()));
      expect(() => r.shareDeal(userId: 'u1', draft: insecure), throwsA(isA<StoreException>()));
    });

    test('only the sharer can delete a deal', () async {
      final r = repo();
      final deal = await r.shareDeal(userId: 'u1', draft: draft);
      expect(() => r.deleteDeal(userId: 'u2', dealId: deal.id), throwsA(isA<StoreException>()));
      expect(() => r.deleteDeal(userId: 'u1', dealId: 'd-fetch-balls'), throwsA(isA<StoreException>()));
      await r.deleteDeal(userId: 'u1', dealId: deal.id);
      expect((await r.fetchDeals()).any((d) => d.id == deal.id), isFalse);
    });

    test('a report is recorded once per user', () async {
      final r = repo();
      await r.reportExpired(userId: 'u1', dealId: 'd-cooling-mat');
      await r.reportExpired(userId: 'u1', dealId: 'd-cooling-mat');
      expect(r.reports, [('u1', 'd-cooling-mat')]);
      expect(await r.fetchReportedDealIds(userId: 'u1'), {'d-cooling-mat'});
      expect(await r.fetchReportedDealIds(userId: 'u2'), isEmpty);
    });

    test('can be made to fail', () async {
      final r = repo()..failFetches = true;
      expect(r.fetchDeals, throwsA(isA<StoreException>()));
    });
  });
}
