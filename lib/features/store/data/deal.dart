import 'package:flutter/foundation.dart';

import '../../../models/pet.dart';
import '../store_strings.dart';

/// The currency new deals are shared in, and the one the sample data uses.
/// Each deal stores its own code, so changing this only affects new deals.
/// (The migration's column default in `0004_store.sql` should match.)
const String kStoreDefaultCurrency = 'ILS';

/// A price checked longer ago than this gets a "may have changed" note.
const Duration kPriceCheckStaleAfter = Duration(days: 30);

/// What a deal is about, in the order the chips are shown.
enum DealCategory {
  food('food'),
  treats('treats'),
  litterAndCleaning('litter_and_cleaning'),
  toys('toys'),
  health('health'),
  grooming('grooming'),
  accessories('accessories'),
  bedsAndCrates('beds_and_crates');

  const DealCategory(this.code);

  /// The value stored in the `category` column.
  final String code;

  /// Shown on chips and in the detail page.
  String get label => StoreStrings.category(this);

  static DealCategory fromCode(String? code) => DealCategory.values.firstWhere(
        (c) => c.code == code,
        orElse: () => DealCategory.accessories,
      );
}

/// What a package is measured in, which decides what its unit price is
/// compared with: a price per kg is never compared with a price per litre.
enum UnitKind { weight, volume, count }

/// The unit of a package size.
enum PackageUnit {
  kg('kg', UnitKind.weight, 1),
  g('g', UnitKind.weight, 0.001),
  litre('l', UnitKind.volume, 1),
  ml('ml', UnitKind.volume, 0.001),
  unit('unit', UnitKind.count, 1);

  const PackageUnit(this.code, this.kind, this.toBase);

  /// The value stored in the `package_unit` column.
  final String code;
  final UnitKind kind;

  /// How many base units (kg, litre, one item) one of this unit is.
  final double toBase;

  /// As picked in the share form.
  String get label => StoreStrings.unit(this);

  static PackageUnit? fromCode(String? code) {
    for (final unit in values) {
      if (unit.code == code) return unit;
    }
    return null;
  }
}

/// How much is in the package: "12 kg", "500 ml", "28 units". For a
/// multi-pack it is the total.
@immutable
class PackageSize {
  const PackageSize(this.amount, this.unit);

  final double amount;
  final PackageUnit unit;

  /// The amount in kg, litres or items.
  double get inBaseUnits => amount * unit.toBase;

  @override
  bool operator ==(Object other) => other is PackageSize && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}

/// A price per kg, per litre or per item.
@immutable
class UnitPrice {
  const UnitPrice(this.amount, this.kind);

  final double amount;
  final UnitKind kind;
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
    this.package,
    this.deliveryCost,
    this.priceCheckedAt,
    this.species = const {},
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

  /// How much is in the package; `null` when not given.
  final PackageSize? package;

  /// What delivery costs in [currency]: `null` when not given, zero when
  /// it is free.
  final double? deliveryCost;

  /// When the price was last checked; `null` on deals from before this was
  /// recorded (see [priceChecked]).
  final DateTime? priceCheckedAt;

  /// The kinds of animal the deal is for. Empty means every pet.
  final Set<PetSpecies> species;

  /// Curated by Pet Companion rather than shared by a member.
  bool get isCurated => sharedBy == null;

  /// How much cheaper than [originalPrice], never negative.
  double get amountSaved => originalPrice > price ? originalPrice - price : 0;

  /// Whole-number discount, 0..100.
  int get discountPercent {
    if (originalPrice <= 0 || price >= originalPrice) return 0;
    return ((1 - price / originalPrice) * 100).round().clamp(0, 100);
  }

  /// The price per kg, litre or item, worked out from [price] alone:
  /// delivery is not part of it. `null` without a package size.
  UnitPrice? get unitPrice {
    final size = package;
    if (size == null || size.inBaseUnits <= 0) return null;
    return UnitPrice(price / size.inBaseUnits, size.unit.kind);
  }

  /// [price] plus delivery; `null` while the delivery cost is not known.
  double? get finalPrice {
    final delivery = deliveryCost;
    return delivery == null ? null : price + delivery;
  }

  /// When the price was checked: the day the deal was posted unless a later
  /// check was recorded.
  DateTime get priceChecked => priceCheckedAt ?? postedAt;

  /// The price was checked long enough ago that it may have changed.
  bool isPriceStale(DateTime now) => now.difference(priceChecked) > kPriceCheckStaleAfter;

  bool get isForEveryPet => species.isEmpty;

  /// Whether the deal is for [kind]: it names it, or it is for every pet.
  bool suits(PetSpecies kind) => species.isEmpty || species.contains(kind);

  /// [species] in the app's usual order (dog, cat, bird...).
  List<PetSpecies> get speciesInOrder => [
        for (final kind in PetSpecies.values)
          if (species.contains(kind)) kind,
      ];

  bool isExpired(DateTime now) {
    final end = expiresAt;
    return end != null && !end.isAfter(now);
  }

  bool isSharedBy(String? userId) => userId != null && sharedBy == userId;

  /// Builds a deal from a `store_deals` row. The columns added by
  /// `0008_store_phase1.sql` may be missing or empty.
  factory Deal.fromRow(Map<String, dynamic> row) {
    final amount = _toDoubleOrNull(row['package_amount']);
    final unit = PackageUnit.fromCode(row['package_unit'] as String?);
    final species = row['species'];
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
      expiresAt: _toTime(row['expires_at']),
      package: amount != null && amount > 0 && unit != null ? PackageSize(amount, unit) : null,
      deliveryCost: _toDoubleOrNull(row['delivery_cost']),
      priceCheckedAt: _toTime(row['price_checked_at']),
      species: {
        // An animal this version does not know is left out rather than
        // read as "other".
        if (species is List)
          for (final kind in PetSpecies.values)
            if (species.contains(kind.name)) kind,
      },
    );
  }

  static DateTime? _toTime(Object? value) => value is String ? DateTime.parse(value).toLocal() : null;

  // Postgres `numeric` arrives as a number or, for big values, a string.
  static double? _toDoubleOrNull(Object? value) => switch (value) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s),
        _ => null,
      };

  static double _toDouble(Object? value) => _toDoubleOrNull(value) ?? 0;
}

/// What a member fills in to share a deal. The repository adds the id, the
/// sharer, the posted time and the day the price was checked (today).
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
    this.package,
    this.deliveryCost,
    this.species = const {},
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
  final PackageSize? package;

  /// `null` when not known, zero when delivery is free.
  final double? deliveryCost;

  /// Empty means every pet.
  final Set<PetSpecies> species;

  /// The columns of a new `store_deals` row. `posted_at`, `shared_by_name`
  /// and `price_checked_at` are filled in by the database. The columns of
  /// `0008_store_phase1.sql` are only sent when they carry something, so a
  /// plain deal can still be shared before that file has been run.
  Map<String, dynamic> toRow({required String userId}) {
    final size = package;
    return {
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
      if (size != null) 'package_amount': size.amount,
      if (size != null) 'package_unit': size.unit.code,
      if (deliveryCost != null) 'delivery_cost': deliveryCost,
      if (species.isNotEmpty)
        'species': [
          for (final kind in PetSpecies.values)
            if (species.contains(kind)) kind.name,
        ],
    };
  }
}

/// How the catalogue is ordered, in the order the sort menu shows. Expired
/// deals always come last.
enum DealSort {
  biggestDiscount,
  lowestPrice,
  lowestUnitPrice,
  newest,
  endingSoon;

  String get label => StoreStrings.sort(this);
}
