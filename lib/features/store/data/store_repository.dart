import 'deal.dart';

/// Thrown by a [StoreRepository] with a message safe to show to the user.
class StoreException implements Exception {
  const StoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The deals catalogue and what a member can do with it. The screens talk
/// only to this interface, so the in-memory implementation can be swapped
/// for Supabase without touching them.
abstract class StoreRepository {
  /// Every deal in the catalogue, expired ones included. The order is not
  /// significant: the app sorts and filters.
  Future<List<Deal>> fetchDeals();

  /// Ids of the deals [userId] has saved.
  Future<Set<String>> fetchSavedDealIds({required String userId});

  /// Saves or unsaves a deal for [userId]. Doing it twice is harmless.
  Future<void> setSaved({required String userId, required String dealId, required bool saved});

  /// Adds [draft] to the catalogue, marked as shared by [userId], and
  /// returns the stored deal. [userName] is the sharer's display name; a
  /// backend that knows it better (the profile on Supabase) may ignore it.
  Future<Deal> shareDeal({required String userId, String? userName, required DealDraft draft});

  /// Removes a deal [userId] shared. Fails for anyone else's deal.
  Future<void> deleteDeal({required String userId, required String dealId});

  /// Ids of the deals [userId] has reported as expired.
  Future<Set<String>> fetchReportedDealIds({required String userId});

  /// Records that [userId] found the deal to be over. One report per user
  /// per deal; reporting again is harmless.
  Future<void> reportExpired({required String userId, required String dealId});
}
