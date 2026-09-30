import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_models.dart';
import 'health_providers.dart';

/// What a health cost was for. Finer than a budget needs, so a reader can
/// group them as it likes (for example everything under "Vet and medicines").
/// [label] is the English name, for logs; a screen says it in its own
/// language with `HealthWords.costCategory`.
enum HealthCostCategory {
  vetVisit('Vet visits'),
  vaccination('Vaccinations'),
  preventive('Preventive treatments'),
  procedure('Procedures'),
  medicine('Medicine'),
  other('Other');

  const HealthCostCategory(this.label);

  final String label;

  static HealthCostCategory of(RecordKind kind) => switch (kind) {
    RecordKind.checkup => vetVisit,
    RecordKind.vaccination => vaccination,
    RecordKind.preventive => preventive,
    RecordKind.procedure => procedure,
    RecordKind.medicine => medicine,
    RecordKind.document || RecordKind.other => other,
  };
}

/// One amount the owner entered on a health record that is done.
class HealthCost {
  const HealthCost({
    required this.recordId,
    required this.petId,
    required this.title,
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
  });

  final String recordId;
  final String petId;

  /// The record's title ("Rabies booster").
  final String title;

  /// When the record happened.
  final DateTime date;
  final double amount;

  /// ISO 4217 code ("ILS").
  final String currency;
  final HealthCostCategory category;
}

/// What was spent on a pet's health in one calendar month, in one currency.
class HealthMonthCosts {
  const HealthMonthCosts({
    required this.month,
    required this.currency,
    required this.total,
    required this.byCategory,
    required this.count,
  });

  /// The first day of the month.
  final DateTime month;
  final String currency;
  final double total;

  /// Only the categories that have an amount in this month.
  final Map<HealthCostCategory, double> byCategory;

  /// How many records the total is made of.
  final int count;
}

/// The costs of done records, newest first. A planned record's expected
/// cost is not money spent, so it is left out.
List<HealthCost> healthCostsOf(List<HealthRecord> records) => [
  for (final record in records)
    if (record.isDone && record.costAmount != null)
      HealthCost(
        recordId: record.id,
        petId: record.petId,
        title: record.title,
        date: record.when,
        amount: record.costAmount!,
        currency: record.costCurrency,
        category: HealthCostCategory.of(record.kind),
      ),
]..sort((a, b) => b.date.compareTo(a.date));

/// [costs] added up per calendar month and currency, newest month first.
List<HealthMonthCosts> healthCostsByMonth(List<HealthCost> costs) {
  final groups = <(int, int, String), List<HealthCost>>{};
  for (final cost in costs) {
    groups.putIfAbsent((cost.date.year, cost.date.month, cost.currency), () => []).add(cost);
  }
  double cents(double amount) => (amount * 100).roundToDouble();
  final months = [
    for (final MapEntry(key: (year, month, currency), value: items) in groups.entries)
      HealthMonthCosts(
        month: DateTime(year, month),
        currency: currency,
        // Summed in whole cents, so 0.1 + 0.2 stays 0.3.
        total: items.fold(0.0, (sum, c) => sum + cents(c.amount)) / 100,
        byCategory: {
          for (final category in HealthCostCategory.values)
            if (items.any((c) => c.category == category))
              category: items.where((c) => c.category == category).fold(0.0, (sum, c) => sum + cents(c.amount)) / 100,
        },
        count: items.length,
      ),
  ];
  return months..sort((a, b) {
    final byMonth = b.month.compareTo(a.month);
    return byMonth != 0 ? byMonth : a.currency.compareTo(b.currency);
  });
}

Duration? _noRetry(int retryCount, Object error) => null;

/// Every amount entered on a pet's done health records, newest first.
/// Loading is `AsyncLoading`, no amounts is an empty list, and it refreshes
/// by itself when a record is added, changed or deleted.
final healthCostsProvider = FutureProvider.autoDispose.family<List<HealthCost>, String>((ref, petId) async {
  return healthCostsOf(await ref.watch(healthRecordsProvider(petId).future));
}, retry: _noRetry);

/// The same amounts added up per month and category, newest month first.
/// One entry per month and currency.
final healthCostsByMonthProvider = FutureProvider.autoDispose.family<List<HealthMonthCosts>, String>((
  ref,
  petId,
) async {
  return healthCostsByMonth(await ref.watch(healthCostsProvider(petId).future));
}, retry: _noRetry);
