import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../l10n/settings_store.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../pet_records/state/health_providers.dart';
import '../data/care_models.dart';
import '../data/care_repository.dart';
import '../data/supabase_care_repository.dart';
import 'care_logic.dart';

/// The food and goals backend: Supabase when the app is built with its
/// configuration, otherwise the in-memory sample data.
final careRepositoryProvider = Provider<CareRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseCareRepository(sb.Supabase.instance.client)
      : FakeCareRepository(),
);

Duration? _noRetry(int retryCount, Object error) => null;

class CareSettingsController extends SessionSafeAsyncNotifier<CareSettings> {
  CareSettingsController(this.petId);

  final String petId;

  @override
  Future<CareSettings> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('care.view'))) {
      return CareSettings(petId: petId);
    }
    return ref.watch(careRepositoryProvider).fetchSettings(petId);
  }

  /// Stores [settings]. Throws a `HealthException` when it is not stored.
  Future<CareSettings> save(CareSettings settings) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'care.edit');
      final saved = await ref
          .read(careRepositoryProvider)
          .saveSettings(settings);
      if (ref.mounted) state = AsyncData(saved);
      return saved;
    });
  }
}

final careSettingsProvider = AsyncNotifierProvider.autoDispose
    .family<CareSettingsController, CareSettings, String>(
      CareSettingsController.new,
      retry: _noRetry,
    );

Pet _petOf(Ref ref, String petId) => ref.watch(
  petsProvider.select(
    (pets) => pets.firstWhere((p) => p.id == petId, orElse: () => Pet.none),
  ),
);

/// Waits for two loads together; the first failure wins.
AsyncValue<R> _both<A, B, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  R Function(A a, B b) combine,
) {
  if (a.hasError) {
    return AsyncError(a.error!, a.stackTrace ?? StackTrace.current);
  }
  if (b.hasError) {
    return AsyncError(b.error!, b.stackTrace ?? StackTrace.current);
  }
  if (!a.hasValue || !b.hasValue) return const AsyncLoading();
  return AsyncData(combine(a.requireValue, b.requireValue));
}

/// Today's meals, calories and goal of a pet.
final feedingDayProvider = Provider.autoDispose
    .family<AsyncValue<FeedingDay>, String>((ref, petId) {
      final pet = _petOf(ref, petId);
      ref.watch(currentDayProvider);
      final now = ref.watch(healthClockProvider)();
      return _both(
        ref.watch(carePlanProvider(petId)),
        ref.watch(careSettingsProvider(petId)),
        (plan, settings) =>
            feedingDay(pet: pet, plan: plan, settings: settings, now: now),
      );
    });

/// Today's walks (or play), minutes and goal of a pet.
final activityDayProvider = Provider.autoDispose
    .family<AsyncValue<ActivityDay>, String>((ref, petId) {
      final pet = _petOf(ref, petId);
      ref.watch(currentDayProvider);
      final now = ref.watch(healthClockProvider)();
      return _both(
        ref.watch(carePlanProvider(petId)),
        ref.watch(careSettingsProvider(petId)),
        (plan, settings) =>
            activityDay(pet: pet, plan: plan, settings: settings, now: now),
      );
    });

/// What Home's health card lists, soonest first.
final upcomingHealthProvider = Provider.autoDispose
    .family<AsyncValue<List<HealthItem>>, String>((ref, petId) {
      ref.watch(currentDayProvider);
      final now = ref.watch(healthClockProvider)();
      return _both(
        ref.watch(carePlanProvider(petId)),
        ref.watch(healthRecordsProvider(petId)),
        (plan, records) =>
            upcomingHealth(plan: plan, records: records, now: now),
      );
    });

// ---------------------------------------------------------------------------
// A walk in progress
// ---------------------------------------------------------------------------

/// A walk (or play session) the owner started with "Start now".
class RunningWalk {
  const RunningWalk({required this.startedAt, this.planItemId});

  final DateTime startedAt;

  /// The planned walk it answers, or `null` for an extra one.
  final String? planItemId;

  String encode() => '${startedAt.toIso8601String()}|${planItemId ?? ''}';

  static RunningWalk? decode(String? value) {
    if (value == null) return null;
    final parts = value.split('|');
    final at = DateTime.tryParse(parts.first);
    if (at == null) return null;
    final item = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    return RunningWalk(startedAt: at, planItemId: item);
  }
}

/// The walk running for a pet, kept on the phone so it survives closing
/// the app.
class RunningWalkController extends Notifier<RunningWalk?> {
  RunningWalkController(this.petId);

  final String petId;

  String get _key => 'care.walk.$petId';
  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  RunningWalk? build() =>
      RunningWalk.decode(ref.watch(settingsStoreProvider).read(_key));

  Future<void> start({String? planItemId}) async {
    return sessionOperation(ref, () async {
      final walk = RunningWalk(
        startedAt: ref.read(healthClockProvider)(),
        planItemId: planItemId,
      );
      state = walk;
      await _store.write(_key, walk.encode());
    });
  }

  /// Forgets the running walk (after it was saved, or when cancelled).
  Future<void> clear() async {
    return sessionOperation(ref, () async {
      state = null;
      await _store.write(_key, null);
    });
  }
}

final runningWalkProvider =
    NotifierProvider.family<RunningWalkController, RunningWalk?, String>(
      RunningWalkController.new,
    );
