import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../store_strings.dart';
import 'deal.dart';
import 'store_repository.dart';

/// [StoreRepository] backed by the tables of `0004_store.sql`, with the
/// columns `0008_store_phase1.sql` adds to `store_deals`.
///
/// Row level security does the enforcing: every signed-in user reads the
/// catalogue, and a user only adds, changes or removes rows of their own.
/// The user id passed in must be the signed-in user's, or the database
/// refuses the write.
class SupabaseStoreRepository implements StoreRepository {
  SupabaseStoreRepository(this._client);

  final sb.SupabaseClient _client;

  static const _deals = 'store_deals';
  static const _favourites = 'store_favourites';
  static const _reports = 'store_reports';

  /// The catalogue is filtered and sorted in the app, so it is fetched in
  /// one go; this caps how much a very large catalogue would download.
  static const _maxDeals = 500;

  @override
  Future<List<Deal>> fetchDeals() => _guard(() async {
        final rows = await _client.from(_deals).select().order('posted_at', ascending: false).limit(_maxDeals);
        return [for (final row in rows) Deal.fromRow(row)];
      });

  @override
  Future<Set<String>> fetchSavedDealIds({required String userId}) => _guard(() async {
        final rows = await _client.from(_favourites).select('deal_id').eq('user_id', userId);
        return {for (final row in rows) row['deal_id'] as String};
      });

  @override
  Future<void> setSaved({required String userId, required String dealId, required bool saved}) => _guard(() async {
        if (saved) {
          await _client.from(_favourites).upsert(
            {'user_id': userId, 'deal_id': dealId},
            onConflict: 'user_id,deal_id',
            ignoreDuplicates: true,
          );
        } else {
          await _client.from(_favourites).delete().eq('user_id', userId).eq('deal_id', dealId);
        }
      });

  // [userName] is not sent: a database trigger copies the sharer's display
  // name from their profile, so it cannot be made up by a client.
  @override
  Future<Deal> shareDeal({required String userId, String? userName, required DealDraft draft}) => _guard(() async {
        final row = await _client.from(_deals).insert(draft.toRow(userId: userId)).select().single();
        return Deal.fromRow(row);
      });

  @override
  Future<void> deleteDeal({required String userId, required String dealId}) => _guard(() async {
        final removed = await _client.from(_deals).delete().eq('id', dealId).eq('shared_by', userId).select('id');
        if (removed.isEmpty) throw const StoreException(StoreStrings.onlyDeleteOwn);
      });

  @override
  Future<Set<String>> fetchReportedDealIds({required String userId}) => _guard(() async {
        final rows = await _client.from(_reports).select('deal_id').eq('reporter_id', userId);
        return {for (final row in rows) row['deal_id'] as String};
      });

  @override
  Future<void> reportExpired({required String userId, required String dealId}) => _guard(() async {
        await _client.from(_reports).upsert(
          {'deal_id': dealId, 'reporter_id': userId, 'reason': 'expired'},
          onConflict: 'deal_id,reporter_id',
          ignoreDuplicates: true,
        );
      });

  /// Runs [action], turning backend failures into a [StoreException] with
  /// copy that fits the app's tone.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on StoreException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw StoreException(_friendly(e));
    } catch (_) {
      // No connection, a timeout, or a response that was not what we expect.
      throw const StoreException(StoreStrings.cannotReachServer);
    }
  }

  static String _friendly(sb.PostgrestException e) {
    final message = e.message.toLowerCase();
    // 42501: refused by row level security. 23514: a check constraint.
    if (e.code == '42501' || message.contains('row-level security')) return StoreStrings.notAllowed;
    if (e.code == '23514') {
      // The message names the constraint that refused the row.
      if (message.contains('package')) return StoreStrings.packageNotValid;
      if (message.contains('delivery')) return StoreStrings.deliveryNotValid;
      if (message.contains('price')) return StoreStrings.priceBelowOriginal;
      if (message.contains('link')) return StoreStrings.linkMustBeHttps;
      return StoreStrings.detailsNotValid;
    }
    if (e.code == '23503') return StoreStrings.dealNoLongerAvailable;
    if (e.code == 'PGRST301' || message.contains('jwt')) return StoreStrings.sessionEnded;
    // PGRST204: a column the app sends is not in the database yet, which
    // means `0008_store_phase1.sql` has not been run.
    if (e.code == 'PGRST204') return StoreStrings.storeNeedsUpdate;
    return StoreStrings.somethingWentWrong;
  }
}
