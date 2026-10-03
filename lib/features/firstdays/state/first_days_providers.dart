import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../config/app_config.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../care/state/care_providers.dart';
import '../../health/state/health_providers.dart';
import '../data/first_days_models.dart';
import '../data/first_days_repository.dart';
import '../data/supabase_first_days_repository.dart';
import 'first_days_logic.dart';

/// The "first 30 days" backend: Supabase when the app is built with its
/// configuration, otherwise the in-memory sample data.
final firstDaysRepositoryProvider = Provider<FirstDaysRepository>(
  (ref) => AppConfig.hasSupabase ? SupabaseFirstDaysRepository(sb.Supabase.instance.client) : FakeFirstDaysRepository(),
);

Duration? _noRetry(int retryCount, Object error) => null;

/// A pet's path (`null` when none was started), and what changes it.
class FirstDaysController extends AsyncNotifier<FirstDaysPath?> {
  FirstDaysController(this.petId);

  final String petId;

  FirstDaysRepository get _repo => ref.read(firstDaysRepositoryProvider);

  @override
  Future<FirstDaysPath?> build() => ref.watch(firstDaysRepositoryProvider).fetch(petId);

  void _set(FirstDaysPath? path) {
    if (ref.mounted) state = AsyncData(path);
  }

  /// Starts the path on [arrivedOn]. A path started before is opened again
  /// on the new day, its ticks kept. Throws a `HealthException` when it is
  /// not stored.
  Future<FirstDaysPath> start(DateTime arrivedOn) async {
    final current = state.value ?? await future;
    final path = current == null ? FirstDaysPath(petId: petId, arrivedOn: arrivedOn) : current.restartedOn(arrivedOn);
    final saved = await _repo.save(path);
    _set(saved);
    return saved;
  }

  /// Ticks or unticks a task. The tick shows at once and goes back if it
  /// cannot be stored (the error is rethrown).
  Future<void> setDone(String taskId, {required bool done}) async {
    final current = state.value;
    if (current == null) return;
    final changed = current.withTask(taskId, done: done);
    _set(changed);
    try {
      _set(await _repo.save(changed));
    } catch (_) {
      final now = state.value;
      if (now != null) _set(now.withTask(taskId, done: current.doneTasks.contains(taskId)));
      rethrow;
    }
  }

  /// Ends the path early: the Home card goes, the page stays as a summary.
  Future<void> close() async {
    final current = state.value;
    if (current == null || current.isClosed) return;
    _set(await _repo.save(current.closed(ref.read(healthClockProvider)())));
  }

  /// Forgets the path (an owner who said "just arrived" and then took it
  /// back while adding the pet).
  Future<void> forget() async {
    await _repo.delete(petId);
    _set(null);
  }
}

final firstDaysProvider = AsyncNotifierProvider.autoDispose.family<FirstDaysController, FirstDaysPath?, String>(
  FirstDaysController.new,
  retry: _noRetry,
);

Pet? _petOf(Ref ref, String petId) => ref.watch(
  petsProvider.select((pets) {
    for (final p in pets) {
      if (p.id == petId) return p;
    }
    return null;
  }),
);

/// A pet's path as the page and the Home card show it: `null` when no path
/// was started (or the pet is gone).
///
/// Health and care data only tick tasks: while one of them loads the view
/// waits for it, and one that failed ticks nothing.
final firstDaysViewProvider = Provider.autoDispose.family<AsyncValue<FirstDaysView?>, String>((ref, petId) {
  final pathValue = ref.watch(firstDaysProvider(petId));
  if (pathValue.hasError) return AsyncError(pathValue.error!, pathValue.stackTrace ?? StackTrace.current);
  if (!pathValue.hasValue) return const AsyncLoading();
  final path = pathValue.requireValue;
  final pet = _petOf(ref, petId);
  if (path == null || pet == null) return const AsyncData(null);

  final now = ref.watch(healthClockProvider)();
  final parts = <AsyncValue<Object?>>[
    ref.watch(healthRecordsProvider(petId)),
    ref.watch(healthProfileProvider(petId)),
    ref.watch(carePlanProvider(petId)),
    ref.watch(careSettingsProvider(petId)),
  ];
  if (parts.any((p) => !p.hasValue && !p.hasError)) return const AsyncLoading();
  T? valueOf<T>(AsyncValue<Object?> part) => part.hasError ? null : part.value as T?;

  return AsyncData(
    firstDaysView(
      pet: pet,
      path: path,
      now: now,
      facts: FirstDaysFacts(
        records: valueOf(parts[0]),
        profile: valueOf(parts[1]),
        plan: valueOf(parts[2]),
        settings: valueOf(parts[3]),
      ),
    ),
  );
});
