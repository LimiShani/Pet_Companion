import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/app_language.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../data/health_models.dart';
import '../state/health_providers.dart';
import 'plan_logic.dart';
import 'plan_templates.dart';

/// Who may see the yearly plan. Its content waits for a vet's review, so
/// it is on for the beta testers only (migration 0038).
const plansCapability = 'health.plans.view';

/// Whether [pet]'s species has a plan (dogs and cats).
bool hasYearlyPlan(Pet pet) => planTemplatesFor(pet.species).isNotEmpty;

/// Whether [records] hold no vaccination at all: the Health Overview then
/// invites the owner to the yearly plan.
bool hasNoVaccinations(List<HealthRecord> records) =>
    !records.any((r) => r.kind == RecordKind.vaccination);

/// A pet's yearly plan as it stands today, one proposal per item; empty
/// for an animal without a plan or an account without [plansCapability].
final yearlyPlanProvider = FutureProvider.autoDispose
    .family<List<PlanProposal>, String>((ref, petId) async {
      if (!ref.watch(capabilityProvider(plansCapability))) return const [];
      final pet = ref.watch(
        petsProvider.select((pets) {
          for (final p in pets) {
            if (p.id == petId) return p;
          }
          return null;
        }),
      );
      if (pet == null || !hasYearlyPlan(pet)) return const [];
      final today = ref.watch(currentDayProvider);
      final records = await ref.watch(healthRecordsProvider(petId).future);
      return proposePlan(pet: pet, records: records, today: today);
    });

/// Turns the items the owner chose into planned records.
class YearlyPlanService {
  YearlyPlanService(this._ref);

  final Ref _ref;

  /// Plans each of [chosen] for [petId]: a new planned record on its date,
  /// or, for an item already planned by hand, that record marked as part
  /// of the plan (so marking it done plans the next one). Items already
  /// planned from the plan are left alone. Returns the records saved.
  ///
  /// Throws [FeatureDenied] without [plansCapability], and what
  /// `RecordsController.save` throws when a record is not saved; the
  /// records saved before stay.
  Future<List<HealthRecord>> apply(
    String petId,
    List<PlanProposal> chosen,
  ) async {
    requireCapability(_ref, plansCapability);
    final hebrew = isHebrew(_ref.read(appLocaleProvider));
    final records = _ref.read(healthRecordsProvider(petId).notifier);
    final saved = <HealthRecord>[];
    for (final proposal in chosen) {
      final planned = proposal.planned;
      if (planned != null) {
        if (planned.isFromPlan) continue;
        saved.add(
          await records.save(
            planned.copyWith(planItem: proposal.ref.toString()),
          ),
        );
        continue;
      }
      saved.add(
        await records.save(
          plannedRecordOf(proposal, petId: petId, hebrew: hebrew),
        ),
      );
    }
    return saved;
  }
}

final yearlyPlanServiceProvider = Provider<YearlyPlanService>(
  YearlyPlanService.new,
);
