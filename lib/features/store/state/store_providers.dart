import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../data/deal.dart';
import '../data/deal_filters.dart';
import '../data/fake_store_repository.dart';
import '../data/store_repository.dart';
import '../data/supabase_store_repository.dart';

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

/// User-facing text for a Store failure.
String storeErrorMessage(Object error) =>
    error is StoreException ? error.message : 'Something went wrong. Please try again.';

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
    if (user == null) throw const StoreException('Please sign in to share a deal.');
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
    if (user == null) throw const StoreException('Please sign in to delete a deal.');
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

  /// Saves the deal, or unsaves it when it is already saved. The heart
  /// changes straight away and flips back if the backend refuses. Returns
  /// whether the change was stored.
  Future<bool> toggle(String dealId) async {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) return false;
    final before = state.value ?? const <String>{};
    final saving = !before.contains(dealId);
    state = AsyncData(saving ? {...before, dealId} : ({...before}..remove(dealId)));
    try {
      await ref.read(storeRepositoryProvider).setSaved(userId: userId, dealId: dealId, saved: saving);
      return true;
    } catch (_) {
      if (ref.mounted) {
        final current = {...?state.value};
        if (saving) {
          current.remove(dealId);
        } else {
          current.add(dealId);
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
    if (userId == null) throw const StoreException('Please sign in to report a deal.');
    await ref.read(storeRepositoryProvider).reportExpired(userId: userId, dealId: dealId);
    if (ref.mounted) state = AsyncData({...?state.value, dealId});
  }
}

final reportedDealIdsProvider =
    AsyncNotifierProvider<ReportedDealsController, Set<String>>(ReportedDealsController.new, retry: _noRetry);

/// The search text, category and sort order picked on the Store tab.
class StoreFilterController extends Notifier<StoreFilter> {
  @override
  StoreFilter build() => const StoreFilter();

  void setQuery(String query) => state = state.withQuery(query);

  void setCategory(DealCategory? category) => state = state.withCategory(category);

  void setSort(DealSort sort) => state = state.withSort(sort);

  /// Back to every category and no search text. The sort order stays.
  void clear() => state = StoreFilter(sort: state.sort);
}

final storeFilterProvider = NotifierProvider<StoreFilterController, StoreFilter>(StoreFilterController.new);

/// The catalogue as the Store grid shows it: filtered, sorted, expired last.
final visibleDealsProvider = Provider<AsyncValue<List<Deal>>>((ref) {
  final filter = ref.watch(storeFilterProvider);
  final now = ref.watch(storeClockProvider)();
  return ref.watch(dealsProvider).whenData((deals) => visibleDeals(deals, filter, now));
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
