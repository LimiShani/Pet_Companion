import 'package:flutter/foundation.dart';

/// The currency new deals are shared in, and the one the sample data uses.
/// Each deal stores its own code, so changing this only affects new deals.
/// (The migration's column default in `0004_store.sql` should match.)
const String kStoreDefaultCurrency = 'ILS';

/// What a deal is about. [name] is what the database stores.
enum DealCategory {
  food('Food'),
  treats('Treats'),
  toys('Toys'),
  health('Health'),
  grooming('Grooming'),
  accessories('Accessories'),
  bedsAndCrates('Beds & crates');

  const DealCategory(this.label);

  /// Shown on chips and in the detail page.
  final String label;

  /// The value stored in the `category` column.
  String get code => this == DealCategory.bedsAndCrates ? 'beds_and_crates' : name;

  static DealCategory fromCode(String? code) => DealCategory.values.firstWhere(
        (c) => c.code == code,
        orElse: () => DealCategory.accessories,
      );
}

/// A discounted product offered by a seller outside the app. The app only
/// lists the bargain and links out: nothing is bought here.
@immutable
class Deal {
  const Deal({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.sellerName,
    required this.link,
    required this.postedAt,
    this.description = '',
    this.currency = kStoreDefaultCurrency,
    this.imageUrl,
    this.sharedBy,
    this.sharedByName,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String description;
  final DealCategory category;

  /// What it costs now, in [currency].
  final double price;

  /// What it cost before the discount, in [currency].
  final double originalPrice;

  /// ISO 4217 code, e.g. `ILS`.
  final String currency;
  final String sellerName;

  /// The seller's page for this offer. Always `https`.
  final String link;
  final String? imageUrl;

  /// Id of the user who shared the deal; `null` for curated deals.
  final String? sharedBy;

  /// Display name of that user, when known.
  final String? sharedByName;
  final DateTime postedAt;

  /// When the offer ends; `null` when the seller gave no end date.
  final DateTime? expiresAt;

  /// Curated by Pet Companion rather than shared by a member.
  bool get isCurated => sharedBy == null;

  /// How much cheaper than [originalPrice], never negative.
  double get amountSaved => originalPrice > price ? originalPrice - price : 0;

  /// Whole-number discount, 0..100.
  int get discountPercent {
    if (originalPrice <= 0 || price >= originalPrice) return 0;
    return ((1 - price / originalPrice) * 100).round().clamp(0, 100);
  }

  bool isExpired(DateTime now) {
    final end = expiresAt;
    return end != null && !end.isAfter(now);
  }

  bool isSharedBy(String? userId) => userId != null && sharedBy == userId;

  /// Builds a deal from a `store_deals` row.
  factory Deal.fromRow(Map<String, dynamic> row) {
    return Deal(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      category: DealCategory.fromCode(row['category'] as String?),
      price: _toDouble(row['price']),
      originalPrice: _toDouble(row['original_price']),
      currency: (row['currency'] as String?) ?? kStoreDefaultCurrency,
      sellerName: (row['seller_name'] as String?) ?? '',
      link: (row['link'] as String?) ?? '',
      imageUrl: row['image_url'] as String?,
      sharedBy: row['shared_by'] as String?,
      sharedByName: row['shared_by_name'] as String?,
      postedAt: DateTime.parse(row['posted_at'] as String).toLocal(),
      expiresAt: row['expires_at'] == null ? null : DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  // Postgres `numeric` arrives as a number or, for big values, a string.
  static double _toDouble(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0,
        _ => 0,
      };
}

/// What a member fills in to share a deal. The repository adds the id, the
/// sharer and the posted time.
@immutable
class DealDraft {
  const DealDraft({
    required this.title,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.sellerName,
    required this.link,
    this.description = '',
    this.currency = kStoreDefaultCurrency,
    this.expiresAt,
  });

  final String title;
  final String description;
  final DealCategory category;
  final double price;
  final double originalPrice;
  final String currency;
  final String sellerName;
  final String link;
  final DateTime? expiresAt;

  /// The columns of a new `store_deals` row. `posted_at` and
  /// `shared_by_name` are filled in by the database.
  Map<String, dynamic> toRow({required String userId}) => {
        'title': title,
        'description': description,
        'category': category.code,
        'price': price,
        'original_price': originalPrice,
        'currency': currency,
        'seller_name': sellerName,
        'link': link,
        'shared_by': userId,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      };
}

/// How the catalogue is ordered. Expired deals always come last.
enum DealSort {
  biggestDiscount('Biggest discount'),
  lowestPrice('Lowest price'),
  newest('Newest'),
  endingSoon('Ending soon');

  const DealSort(this.label);

  final String label;
}
