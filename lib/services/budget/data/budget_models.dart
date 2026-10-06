import '../../../config/app_config.dart';

/// A budget category. [dbValue] is `expenses.category`.
enum ExpenseCategory {
  food('food'),
  litter('litter_consumables'),
  vet('vet_medicines'),
  equipment('equipment'),
  services('services'),
  other('other');

  const ExpenseCategory(this.dbValue);

  final String dbValue;

  static ExpenseCategory fromDb(String? value) => values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => ExpenseCategory.other,
  );
}

/// How often an expense is paid. [dbValue] is `expenses.frequency`.
///
/// A recurring expense is entered once, on the date of its first payment,
/// and counts again in every later month (every month) or in the same
/// month of every later year (every year), on the same day of the month,
/// until the owner stops it ([Expense.endedOn]).
enum ExpenseFrequency {
  once('once'),
  monthly('monthly'),
  yearly('yearly');

  const ExpenseFrequency(this.dbValue);

  final String dbValue;

  static ExpenseFrequency fromDb(String? value) => values.firstWhere(
    (f) => f.dbValue == value,
    orElse: () => ExpenseFrequency.once,
  );
}

/// Where a stored expense came from. [dbValue] is `expenses.source`. Health
/// costs are not stored here: the budget reads them from Health.
enum ExpenseSource {
  manual('manual'),
  basket('basket');

  const ExpenseSource(this.dbValue);

  final String dbValue;

  static ExpenseSource fromDb(String? value) => values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => ExpenseSource.manual,
  );
}

/// One expense the owner entered, or one "Bought again" in the basket.
class Expense {
  const Expense({
    required this.id,
    required this.petId,
    required this.amount,
    required this.category,
    required this.spentOn,
    this.currency = AppConfig.defaultCurrency,
    this.note = '',
    this.frequency = ExpenseFrequency.once,
    this.source = ExpenseSource.manual,
    this.basketItemId,
    this.endedOn,
  });

  final String id;

  /// `null`: the whole home, not one pet.
  final String? petId;
  final double amount;

  /// ISO 4217 code ("ILS").
  final String currency;
  final ExpenseCategory category;

  /// The day it was paid; for a recurring one, the first payment.
  final DateTime spentOn;
  final String note;
  final ExpenseFrequency frequency;
  final ExpenseSource source;

  /// The basket product a "Bought again" was for.
  final String? basketItemId;

  /// The day a recurring expense was stopped: no payment after it counts.
  final DateTime? endedOn;

  bool get isNew => id.isEmpty;
  bool get isRecurring => frequency != ExpenseFrequency.once;
  bool get isWholeHome => petId == null;

  Expense copyWith({
    String? id,
    String? Function()? petId,
    double? amount,
    ExpenseCategory? category,
    DateTime? spentOn,
    String? note,
    ExpenseFrequency? frequency,
    DateTime? Function()? endedOn,
  }) => Expense(
    id: id ?? this.id,
    petId: petId == null ? this.petId : petId(),
    amount: amount ?? this.amount,
    currency: currency,
    category: category ?? this.category,
    spentOn: spentOn ?? this.spentOn,
    note: note ?? this.note,
    frequency: frequency ?? this.frequency,
    source: source,
    basketItemId: basketItemId,
    endedOn: endedOn == null ? this.endedOn : endedOn(),
  );
}

/// What a basket product is. [dbValue] is `basket_items.kind`.
enum BasketKind {
  food('food'),
  litter('litter'),
  consumable('consumable'),
  other('other');

  const BasketKind(this.dbValue);

  final String dbValue;

  static BasketKind fromDb(String? value) => values.firstWhere(
    (k) => k.dbValue == value,
    orElse: () => BasketKind.other,
  );

  /// The budget category a purchase of this kind lands in.
  ExpenseCategory get category => switch (this) {
    BasketKind.food => ExpenseCategory.food,
    BasketKind.litter || BasketKind.consumable => ExpenseCategory.litter,
    BasketKind.other => ExpenseCategory.other,
  };
}

/// The unit of a package size. [dbValue] is `basket_items.package_unit`.
enum BasketUnit {
  kg('kg'),
  g('g'),
  l('l'),
  units('units');

  const BasketUnit(this.dbValue);

  final String dbValue;

  static BasketUnit fromDb(String? value) => values.firstWhere(
    (u) => u.dbValue == value,
    orElse: () => BasketUnit.units,
  );

  /// Grams in [size] of this unit, or `null` when it is not a weight.
  double? grams(double size) => switch (this) {
    BasketUnit.kg => size * 1000,
    BasketUnit.g => size,
    BasketUnit.l || BasketUnit.units => null,
  };
}

/// A product the owner buys again and again: a bag of food, litter, poop
/// bags.
class BasketItem {
  const BasketItem({
    required this.id,
    required this.petId,
    required this.name,
    required this.kind,
    required this.packageSize,
    required this.unit,
    this.lastPrice,
    this.currency = AppConfig.defaultCurrency,
    this.lastBoughtOn,
    this.lastsDays,
  });

  final String id;
  final String petId;
  final String name;
  final BasketKind kind;
  final double packageSize;
  final BasketUnit unit;

  /// What the last package cost.
  final double? lastPrice;
  final String currency;
  final DateTime? lastBoughtOn;

  /// How many days a package lasts, as the owner said. `null` for food
  /// means "work it out from the feeding"; for anything else, unknown.
  final int? lastsDays;

  bool get isNew => id.isEmpty;

  BasketItem copyWith({
    String? id,
    double? lastPrice,
    DateTime? lastBoughtOn,
  }) => BasketItem(
    id: id ?? this.id,
    petId: petId,
    name: name,
    kind: kind,
    packageSize: packageSize,
    unit: unit,
    lastPrice: lastPrice ?? this.lastPrice,
    currency: currency,
    lastBoughtOn: lastBoughtOn ?? this.lastBoughtOn,
    lastsDays: lastsDays,
  );
}
