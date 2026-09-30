import 'package:flutter/foundation.dart';

import '../../../models/pet.dart';
import 'deal.dart';

/// What the shopper typed and picked on the Store tab.
@immutable
class StoreFilter {
  const StoreFilter({
    this.query = '',
    this.category,
    this.sort = DealSort.biggestDiscount,
    this.allAnimals = false,
  });

  /// Free text matched against the title, description, seller and category.
  final String query;

  /// `null` shows every category.
  final DealCategory? category;
  final DealSort sort;

  /// With `false` the Store shows what suits the selected pet's kind; with
  /// `true` it shows the deals for every kind of animal.
  final bool allAnimals;

  /// True when a search or a category narrows the list.
  bool get isNarrowed => query.trim().isNotEmpty || category != null;

  StoreFilter withQuery(String value) =>
      StoreFilter(query: value, category: category, sort: sort, allAnimals: allAnimals);

  StoreFilter withCategory(DealCategory? value) =>
      StoreFilter(query: query, category: value, sort: sort, allAnimals: allAnimals);

  StoreFilter withSort(DealSort value) =>
      StoreFilter(query: query, category: category, sort: value, allAnimals: allAnimals);

  StoreFilter withAllAnimals(bool value) =>
      StoreFilter(query: query, category: category, sort: sort, allAnimals: value);

  @override
  bool operator ==(Object other) =>
      other is StoreFilter &&
      other.query == query &&
      other.category == category &&
      other.sort == sort &&
      other.allAnimals == allAnimals;

  @override
  int get hashCode => Object.hash(query, category, sort, allAnimals);
}

/// The deals matching [filter], in its sort order. Deals that are over at
/// [now] always come after the live ones.
///
/// Unless the filter asks for all animals, only deals that suit [pet] are
/// kept: those that name its kind and those for every pet. Without a [pet]
/// nothing is left out.
///
/// The search also matches a deal's category by name: [categoryLabel] gives
/// that name in the language on screen ("Food", "מזון"). Without it the
/// stored code is used ("litter and cleaning").
List<Deal> visibleDeals(
  List<Deal> deals,
  StoreFilter filter,
  DateTime now, {
  PetSpecies? pet,
  String Function(DealCategory category)? categoryLabel,
}) {
  String nameOf(DealCategory category) => categoryLabel?.call(category) ?? category.code.replaceAll('_', ' ');

  final words = filter.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final matching = deals.where((deal) {
    if (pet != null && !filter.allAnimals && !deal.suits(pet)) return false;
    if (filter.category != null && deal.category != filter.category) return false;
    if (words.isEmpty) return true;
    final haystack = '${deal.title} ${deal.description} ${deal.sellerName} ${nameOf(deal.category)}'.toLowerCase();
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
        DealSort.lowestUnitPrice => _compareUnitPrice(a.unitPrice, b.unitPrice),
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

// A price per kg cannot be compared with a price per litre, so deals sold
// by weight come first, then by volume, then by count, each from the
// cheapest; deals without a package size come after all of those.
int _compareUnitPrice(UnitPrice? a, UnitPrice? b) {
  final group = _unitGroup(a).compareTo(_unitGroup(b));
  if (group != 0 || a == null || b == null) return group;
  return a.amount.compareTo(b.amount);
}

int _unitGroup(UnitPrice? price) => price == null ? UnitKind.values.length : price.kind.index;
