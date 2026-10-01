import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/ordered_writes.dart';
import '../../../state/pets_provider.dart';
import '../data/deal.dart';
import '../data/deal_filters.dart';
import '../data/fake_store_repository.dart';
import '../data/store_repository.dart';
import '../data/supabase_store_repository.dart';
import '../store_strings.dart';

/// "Now" for everything time-related in the Store (expiry, "3 hours ago").
/// Tests override it with a fixed instant.
final storeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The deals backend: Supabase when the app is built with its
/// configuration, otherwise the in-memory sample catalogue.
final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseStoreRepository(sb.Supabase.instance.client)
      : FakeStoreRepository(now: ref.watch(storeClockProvider)),
);

// Riverpod retries failed providers on its own by default; here a failure
// is shown with a "Try again" button instead.
Duration? _noRetry(int retryCount, Object error) => null;

String? _watchUserId(Ref ref) => ref.watch(authControllerProvider.select((auth) => auth.value?.id));

/// The whole catalogue. Filtering and sorting happen in
/// [visibleDealsProvider].
class DealsController extends AsyncNotifier<List<Deal>> {
  @override
  Future<List<Deal>> build() => ref.watch(storeRepositoryProvider).fetchDeals();

  /// Loads the catalogue again. Deals already on screen stay there while it
  /// runs, and if it fails. Returns whether it succeeded.
  Future<bool> refresh() async {
    final hadDeals = state.hasValue && !state.hasError;
    if (!hadDeals) state = const AsyncLoading();
    final next = await AsyncValue.guard(() => ref.read(storeRepositoryProvider).fetchDeals());
    if (!ref.mounted) return false;
    if (next.hasError && hadDeals) return false;
    state = next;
    return !next.hasError;
  }

  /// Adds a deal shared by the signed-in user. Throws a [StoreException]
  /// when it cannot be stored.
  Future<Deal> share(DealDraft draft) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) throw const StoreException(StoreFailure.signInToShare);
    final deal = await ref
        .read(storeRepositoryProvider)
        .shareDeal(userId: user.id, userName: user.displayName, draft: draft);
    if (ref.mounted) state = AsyncData([deal, ...?state.value]);
    return deal;
  }

  /// Deletes one of the signed-in user's own deals. Throws a
  /// [StoreException] when it cannot be removed.
  Future<void> delete(String dealId) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) throw const StoreException(StoreFailure.signInToDelete);
    await ref.read(storeRepositoryProvider).deleteDeal(userId: user.id, dealId: dealId);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final deal in state.value ?? const <Deal>[])
        if (deal.id != dealId) deal,
    ]);
    ref.read(savedDealIdsProvider.notifier).forget(dealId);
  }
}

final dealsProvider = AsyncNotifierProvider<DealsController, List<Deal>>(DealsController.new, retry: _noRetry);

/// Ids of the deals the signed-in user saved.
class SavedDealsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = _watchUserId(ref);
    if (userId == null) return const {};
    return ref.watch(storeRepositoryProvider).fetchSavedDealIds(userId: userId);
  }

  /// Quick taps on one heart reach the backend in the order they were made.
  final _writes = OrderedWrites();

  /// Per deal with a change on its way: whether the backend has it saved,
  /// as far as the app knows.
  final _stored = <String, bool>{};

  /// The number of the newest tap per deal, so only its outcome counts.
  final _latestTap = <String, int>{};

  /// Saves the deal, or unsaves it when it is already saved. The heart
  /// changes straight away; if the backend refuses the newest tap, the
  /// heart shows what the backend has. Returns whether the change was
  /// stored; a tap that failed but was already overruled by a newer one
  /// counts as stored, since only the newest tap's outcome is the owner's
  /// concern.
  Future<bool> toggle(String dealId) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) return false;
    final before = state.value ?? const <String>{};
    final saving = !before.contains(dealId);
    if (!_writes.busy(dealId)) _stored[dealId] = before.contains(dealId);
    final tap = (_latestTap[dealId] ?? 0) + 1;
    _latestTap[dealId] = tap;
    state = AsyncData(saving ? {...before, dealId} : ({...before}..remove(dealId)));
    final repository = ref.read(storeRepositoryProvider);
    try {
      await _writes.run(dealId, () => repository.setSaved(userId: userId, dealId: dealId, saved: saving));
      _stored[dealId] = saving;
      return true;
    } catch (_) {
      // An older tap that failed is overruled by the newer one behind it.
      if (_latestTap[dealId] != tap) return true;
      if (ref.mounted) {
        final current = {...?state.value};
        if (_stored[dealId] ?? !saving) {
          current.add(dealId);
        } else {
          current.remove(dealId);
        }
        state = AsyncData(current);
      }
      return false;
    }
  }

  /// Drops a deal that no longer exists.
  void forget(String dealId) {
    final current = state.value;
    if (current == null || !current.contains(dealId)) return;
    state = AsyncData({...current}..remove(dealId));
  }
}

final savedDealIdsProvider =
    AsyncNotifierProvider<SavedDealsController, Set<String>>(SavedDealsController.new, retry: _noRetry);

/// Ids of the deals the signed-in user reported as expired.
class ReportedDealsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final userId = _watchUserId(ref);
    if (userId == null) return const {};
    return ref.watch(storeRepositoryProvider).fetchReportedDealIds(userId: userId);
  }

  /// Records a report. Throws a [StoreException] when it cannot be stored.
  Future<void> report(String dealId) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) throw const StoreException(StoreFailure.signInToReport);
    await ref.read(storeRepositoryProvider).reportExpired(userId: userId, dealId: dealId);
    if (ref.mounted) state = AsyncData({...?state.value, dealId});
  }
}

final reportedDealIdsProvider =
    AsyncNotifierProvider<ReportedDealsController, Set<String>>(ReportedDealsController.new, retry: _noRetry);

/// The search text, category, sort order and "all animals" choice picked
/// on the Store tab.
class StoreFilterController extends Notifier<StoreFilter> {
  @override
  StoreFilter build() => const StoreFilter();

  /// Shows the deals for every kind of animal, or (with `false`) only what
  /// suits the selected pet.
  void setAllAnimals(bool value) => state = state.withAllAnimals(value);

  void setQuery(String query) => state = state.withQuery(query);

  void setCategory(DealCategory? category) => state = state.withCategory(category);

  void setSort(DealSort sort) => state = state.withSort(sort);

  /// Back to every category and no search text. The sort order and the
  /// choice of animals stay.
  void clear() => state = StoreFilter(sort: state.sort, allAnimals: state.allAnimals);
}

final storeFilterProvider = NotifierProvider<StoreFilterController, StoreFilter>(StoreFilterController.new);

/// The kind of animal the Store is shopping for: the selected pet's.
final storePetSpeciesProvider = Provider<PetSpecies>(
  (ref) => ref.watch(selectedPetProvider.select((pet) => pet.species)),
);

/// The catalogue as the Store grid shows it: what suits the selected pet
/// (or every animal), filtered, sorted, expired last. The search matches a
/// category by its name in the language on screen.
final visibleDealsProvider = Provider<AsyncValue<List<Deal>>>((ref) {
  final filter = ref.watch(storeFilterProvider);
  final now = ref.watch(storeClockProvider)();
  final pet = ref.watch(storePetSpeciesProvider);
  final words = ref.watch(storeL10nProvider);
  return ref
      .watch(dealsProvider)
      .whenData((deals) => visibleDeals(deals, filter, now, pet: pet, categoryLabel: words.category));
});

/// How many deals match the search and the category when every animal is
/// included. Tells an empty list for the selected pet apart from a search
/// that finds nothing at all.
final allAnimalsDealCountProvider = Provider<int>((ref) {
  final filter = ref.watch(storeFilterProvider).withAllAnimals(true);
  final now = ref.watch(storeClockProvider)();
  final deals = ref.watch(dealsProvider).value ?? const <Deal>[];
  final words = ref.watch(storeL10nProvider);
  return visibleDeals(deals, filter, now, categoryLabel: words.category).length;
});

/// The signed-in user's saved deals, newest first, expired last.
final savedDealsProvider = Provider<AsyncValue<List<Deal>>>((ref) {
  final saved = ref.watch(savedDealIdsProvider).value ?? const <String>{};
  final now = ref.watch(storeClockProvider)();
  return ref
      .watch(dealsProvider)
      .whenData((deals) => sortDeals(deals.where((d) => saved.contains(d.id)), DealSort.newest, now));
});

/// One deal by id, or `null` when it is not (or no longer) in the catalogue.
final dealByIdProvider = Provider.family<Deal?, String>((ref, id) {
  final deals = ref.watch(dealsProvider).value ?? const <Deal>[];
  for (final deal in deals) {
    if (deal.id == id) return deal;
  }
  return null;
});
