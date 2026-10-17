import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_provider.dart';
import '../../l10n/settings_store.dart';
import '../pet_records/data/health_models.dart';
import '../pet_records/state/health_providers.dart';
import '../pet_records/state/schedule_logic.dart';
import 'insight_rules.dart';

/// Who sees the insight line on the Health Overview and gets the weekly
/// summary: the beta testers for now (migration 0038).
const insightsCapability = 'health.insights.view';

/// Where the phone remembers which insight a pet had this week:
/// `2026-W42|shorterWalks`.
String insightShownKey(String petId) => 'insight_shown:$petId';

/// At most one insight a week: the insight of this ISO week for a pet,
/// given what the rules [found] today and what was [remembered] for it.
///
/// A week that already showed an insight shows only that one again (while
/// it still holds), never a second one; a week with none shows the one
/// found, which is then to be remembered ([remember], `null` when nothing
/// changes).
({HealthInsight? show, String? remember}) pickWeeklyInsight({
  required HealthInsight? found,
  required String? remembered,
  required DateTime today,
}) {
  final week = isoWeekOf(today);
  if (remembered != null && remembered.startsWith('$week|')) {
    final kind = remembered.substring(week.length + 1);
    return (show: found?.kind.name == kind ? found : null, remember: null);
  }
  if (found == null) return (show: null, remember: null);
  return (show: found, remember: '$week|${found.kind.name}');
}

/// The insight of a pet for the Health Overview, or `null`.
///
/// Reads the care plan (which routines are walks), the observations, and
/// [insightLogDays] days of care logs (more than the plan loads).
final healthInsightProvider = FutureProvider.autoDispose
    .family<HealthInsight?, String>((ref, petId) async {
      if (!ref.watch(capabilityProvider(insightsCapability))) return null;
      final today = ref.watch(currentDayProvider);
      // Waited for together, so a failure of one never leaves another
      // failing unobserved.
      final results = await Future.wait<Object>([
        ref.watch(carePlanProvider(petId).future),
        ref.watch(observationsProvider(petId).future),
        ref
            .watch(scheduleRepositoryProvider)
            .fetchLogs(petId, from: addDays(today, -insightLogDays)),
      ]);
      final plan = results[0] as CarePlan;
      final observations = results[1] as List<Observation>;
      final logs = results[2] as List<CareLog>;
      final found = insightFor(
        logs: logs,
        walkItemIds: {
          for (final item in plan.items)
            if (item.kind == CareKind.walk) item.id,
        },
        observations: observations,
        today: today,
      );
      final store = ref.read(settingsStoreProvider);
      final key = insightShownKey(petId);
      final pick = pickWeeklyInsight(
        found: found,
        remembered: store.read(key),
        today: today,
      );
      final remember = pick.remember;
      if (remember != null) {
        try {
          await store.write(key, remember);
        } catch (_) {
          // Shown anyway; the week is just not remembered.
        }
      }
      return pick.show;
    });
