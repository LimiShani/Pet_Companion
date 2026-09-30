import 'deal.dart';
import 'sample_deals.dart';
import 'store_repository.dart';

/// In-memory catalogue for development and tests. Nothing persists across
/// restarts.
///
/// Used automatically when the app is built without Supabase configuration.
/// It applies the same rules as the database: a deal must be a real
/// discount with an `https` link, and only the sharer can delete it.
class FakeStoreRepository implements StoreRepository {
  FakeStoreRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    List<Deal>? seed,
  }) : _now = now ?? DateTime.now {
    _deals.addAll(seed ?? sampleDeals(_now()));
  }

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final DateTime Function() _now;

  /// When true, [fetchDeals] fails. Lets tests reach the error state.
  bool failFetches = false;

  /// When true, every change (save, share, delete, report) fails.
  bool failWrites = false;

  final _deals = <Deal>[];
  final _savedByUser = <String, Set<String>>{};
  final _reportsByUser = <String, Set<String>>{};
  var _nextId = 1;

  /// Every report recorded so far, as `(user id, deal id)`. For tests.
  List<(String userId, String dealId)> get reports => [
        for (final entry in _reportsByUser.entries)
          for (final dealId in entry.value) (entry.key, dealId),
      ];

  // No timer at all at zero latency, so widget tests leave none pending.
  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  void _checkWrite() {
    if (failWrites) throw const StoreException('Cannot reach the server. Check your connection and try again.');
  }

  @override
  Future<List<Deal>> fetchDeals() async {
    await _wait();
    if (failFetches) throw const StoreException('Cannot reach the server. Check your connection and try again.');
    return List.unmodifiable(_deals);
  }

  @override
  Future<Set<String>> fetchSavedDealIds({required String userId}) async {
    await _wait();
    return {...?_savedByUser[userId]};
  }

  @override
  Future<void> setSaved({required String userId, required String dealId, required bool saved}) async {
    await _wait();
    _checkWrite();
    final ids = _savedByUser.putIfAbsent(userId, () => {});
    if (saved) {
      ids.add(dealId);
    } else {
      ids.remove(dealId);
    }
  }

  @override
  Future<Deal> shareDeal({required String userId, String? userName, required DealDraft draft}) async {
    await _wait();
    _checkWrite();
    if (draft.title.trim().isEmpty || draft.sellerName.trim().isEmpty) {
      throw const StoreException('A deal needs a title and a seller.');
    }
    if (draft.price <= 0 || draft.originalPrice <= 0 || draft.price > draft.originalPrice) {
      throw const StoreException('The deal price must be below the original price.');
    }
    if (Uri.tryParse(draft.link)?.scheme != 'https') {
      throw const StoreException('Use a link that starts with https://');
    }
    final name = userName?.trim() ?? '';
    final deal = Deal(
      id: 'shared-${_nextId++}',
      title: draft.title.trim(),
      description: draft.description.trim(),
      category: draft.category,
      price: draft.price,
      originalPrice: draft.originalPrice,
      currency: draft.currency,
      sellerName: draft.sellerName.trim(),
      link: draft.link.trim(),
      sharedBy: userId,
      sharedByName: name.isEmpty ? null : name,
      postedAt: _now(),
      expiresAt: draft.expiresAt,
    );
    _deals.insert(0, deal);
    return deal;
  }

  @override
  Future<void> deleteDeal({required String userId, required String dealId}) async {
    await _wait();
    _checkWrite();
    final index = _deals.indexWhere((d) => d.id == dealId);
    if (index < 0) return;
    if (_deals[index].sharedBy != userId) throw const StoreException('You can only delete deals you shared.');
    _deals.removeAt(index);
    for (final ids in _savedByUser.values) {
      ids.remove(dealId);
    }
    for (final ids in _reportsByUser.values) {
      ids.remove(dealId);
    }
  }

  @override
  Future<Set<String>> fetchReportedDealIds({required String userId}) async {
    await _wait();
    return {...?_reportsByUser[userId]};
  }

  @override
  Future<void> reportExpired({required String userId, required String dealId}) async {
    await _wait();
    _checkWrite();
    _reportsByUser.putIfAbsent(userId, () => {}).add(dealId);
  }
}
