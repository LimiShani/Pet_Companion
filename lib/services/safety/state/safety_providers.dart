import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../state/pets_provider.dart';
import '../data/fake_lost_alerts_repository.dart';
import '../data/lost_alert_models.dart';
import '../data/lost_alerts_repository.dart';
import '../data/supabase_lost_alerts_repository.dart';

export '../data/lost_alert_models.dart';
export '../data/lost_alerts_repository.dart';

/// Who may use the safety tools (`0034_lost_alerts.sql`). All three are
/// for the Beta testers until a vet has reviewed the lists.
abstract final class SafetyCapabilities {
  static const view = 'safety.view';

  /// "Is it urgent?" and "Can they eat this?".
  static const lists = 'safety.lists';

  /// Starting Lost mode.
  static const lost = 'safety.lost';
}

final lostAlertsRepositoryProvider = Provider<LostAlertsRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseLostAlertsRepository(sb.Supabase.instance.client)
      : FakeLostAlertsRepository(
          ownerId: ref.read(authControllerProvider).value?.id ?? 'demo',
          petFacts: (petId) {
            final pet = ref.read(petsStoreProvider).byId(petId);
            return (
              name: pet?.name ?? petId,
              species: pet?.species.name ?? 'other',
            );
          },
        ),
);

/// The open alerts of the account's households, newest first; empty when
/// signed out or without [SafetyCapabilities.view]. Starting and closing
/// go through here and load the list again.
class LostAlertsController extends AsyncNotifier<List<LostAlert>> {
  @override
  Future<List<LostAlert>> build() async {
    final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final allowed = ref.watch(capabilityProvider(SafetyCapabilities.view));
    if (user == null || !allowed) return const [];
    return ref.watch(lostAlertsRepositoryProvider).mine();
  }

  LostAlertsRepository get _repo => ref.read(lostAlertsRepositoryProvider);

  Future<void> _reload() async {
    try {
      final alerts = await _repo.mine();
      if (ref.mounted) state = AsyncData(alerts);
    } catch (_) {
      // The change itself went through; the list catches up next time.
    }
  }

  /// Loads the alerts again ("Try again", coming back to the sheet).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.mine);
  }

  /// Starts Lost mode for a pet. Throws a [LostAlertException] when the
  /// server refuses.
  Future<LostAlert> start(LostStart request) async {
    final alert = await _repo.start(request);
    await _reload();
    return alert;
  }

  /// The pet is home.
  Future<LostAlert> markFound(String alertId) async {
    final alert = await _repo.markFound(alertId);
    await _reload();
    return alert;
  }

  /// Closes the alert without "found".
  Future<LostAlert> cancel(String alertId) async {
    final alert = await _repo.cancel(alertId);
    await _reload();
    return alert;
  }
}

final lostAlertsProvider =
    AsyncNotifierProvider<LostAlertsController, List<LostAlert>>(
      LostAlertsController.new,
    );

/// The open alert of [petId], if any (`null` while loading or on error:
/// the Emergency sheet then shows plain Lost mode).
final activeLostAlertProvider = Provider.family<LostAlert?, String>((
  ref,
  petId,
) {
  for (final alert in ref.watch(lostAlertsProvider).value ?? const []) {
    if (alert.petId == petId && alert.isActive) return alert;
  }
  return null;
});
