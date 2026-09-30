/// What the Health feature exposes about money, for a Budget module. One
/// import:
///
/// ```dart
/// import 'package:pet_companion/features/health/costs.dart';
/// ```
///
/// ```dart
/// final AsyncValue<List<HealthCost>> costs = ref.watch(healthCostsProvider(pet.id));
/// final AsyncValue<List<HealthMonthCosts>> months = ref.watch(healthCostsByMonthProvider(pet.id));
/// ```
///
/// The amounts are the optional "Cost" of a health record (a vet visit, a
/// vaccination, a treatment, a medicine...), in the currency the record
/// carries (`AppConfig.defaultCurrency` for everything entered today). Only
/// records that are done count; an expected cost on a planned record does
/// not. Readers never touch Health's repository or its tables.
///
/// A load error is `AsyncError`; `healthErrorMessage(error)` gives text
/// that is safe to show.
library;

export 'state/health_costs.dart'
    show
        HealthCost,
        HealthCostCategory,
        HealthMonthCosts,
        healthCostsByMonth,
        healthCostsByMonthProvider,
        healthCostsOf,
        healthCostsProvider;
export 'state/health_providers.dart' show healthErrorMessage;
