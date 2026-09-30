import 'package:flutter/foundation.dart';

import 'deal.dart';

/// What the shopper typed and picked on the Store tab.
@immutable
class StoreFilter {
  const StoreFilter({this.query = '', this.category, this.sort = DealSort.biggestDiscount});

  /// Free text matched against the title, description, seller and category.
  final String query;

  /// `null` shows every category.
  final DealCategory? category;
  final DealSort sort;

  /// True when a search or a category narrows the list.
  bool get isNarrowed => query.trim().isNotEmpty || category != null;

  StoreFilter withQuery(String value) => StoreFilter(query: value, category: category, sort: sort);

  StoreFilter withCategory(DealCategory? value) => StoreFilter(query: query, category: value, sort: sort);

  StoreFilter withSort(DealSort value) => StoreFilter(query: query, category: category, sort: value);

  @override
  bool operator ==(Object other) =>
      other is StoreFilter && other.query == query && other.category == category && other.sort == sort;

  @override
  int get hashCode => Object.hash(query, category, sort);
}

/// The deals matching [filter], in its sort order. Deals that are over at
/// [now] always come after the live ones.
List<Deal> visibleDeals(List<Deal> deals, StoreFilter filter, DateTime now) {
  final words = filter.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final matching = deals.where((deal) {
    if (filter.category != null && deal.category != filter.category) return false;
    if (words.isEmpty) return true;
    final haystack = '${deal.title} ${deal.description} ${deal.sellerName} ${deal.category.label}'.toLowerCase();
    return words.every(haystack.contains);
  });
  return sortDeals(matching, filter.sort, now);
}

/// [deals] ordered by [sort], expired ones last. Ties fall back to the
/// newest first, so the order is stable.
List<Deal> sortDeals(Iterable<Deal> deals, DealSort sort, DateTime now) {
  int byRule(Deal a, Deal b) => switch (sort) {
        DealSort.biggestDiscount => b.discountPercent.compareTo(a.discountPercent),
        DealSort.lowestPrice => a.price.compareTo(b.price),
        DealSort.newest => b.postedAt.compareTo(a.postedAt),
        DealSort.endingSoon => _compareEnd(a.expiresAt, b.expiresAt),
      };

  return deals.toList()
    ..sort((a, b) {
      final aOver = a.isExpired(now);
      final bOver = b.isExpired(now);
      if (aOver != bOver) return aOver ? 1 : -1;
      final primary = byRule(a, b);
      if (primary != 0) return primary;
      final newest = b.postedAt.compareTo(a.postedAt);
      return newest != 0 ? newest : a.id.compareTo(b.id);
    });
}

// Earliest end first; deals with no end date after those that have one.
int _compareEnd(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
