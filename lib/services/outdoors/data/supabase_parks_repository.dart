import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../platform/session.dart';
import 'park_area.dart';
import 'park_models.dart';
import 'parks_repository.dart';

/// [ParksRepository] on `supabase/migrations/0027_dog_parks.sql`: the
/// `dog_parks`, `dog_park_favorites` and `dog_park_suggestions` tables and
/// the reviewers' functions. Row level security shows members only active
/// and closed parks, their own favourites and their own suggestions.
class SupabaseParksRepository implements ParksRepository {
  SupabaseParksRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  static const _columns =
      'id,source,name_he,name_en,street_he,street_en,lat,lng,locality_code,'
      'fenced,water,shade,lighting,small_dogs,benches,opening_hours,status';

  /// More than any city holds; a box this full is a big city at 25 km.
  static const _limit = 600;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ParkException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      if (e.message.contains('rate_limited')) {
        throw const ParkException(ParkFailure.rateLimited);
      }
      throw const ParkException(ParkFailure.other);
    } on StaleSessionException {
      rethrow;
    } catch (_) {
      throw const ParkException(ParkFailure.unavailable);
    }
  }

  @override
  bool get isDemo => false;

  @override
  Future<List<DogPark>> parks(ParkQuery query) => _guard(() async {
    var request = _client.from('dog_parks').select(_columns);
    if (query.localityCode case final code?) {
      request = request.eq('locality_code', code);
    } else {
      final box = query.box!;
      request = request
          .gte('lat', box.south)
          .lte('lat', box.north)
          .gte('lng', box.west)
          .lte('lng', box.east);
    }
    final rows = await request.limit(_limit);
    return [for (final row in rows) DogPark.fromRow(row)];
  });

  @override
  Future<List<DogPark>> parksByIds(Iterable<String> ids) => _guard(() async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final rows = await _client
        .from('dog_parks')
        .select(_columns)
        .inFilter('id', list);
    return [for (final row in rows) DogPark.fromRow(row)];
  });

  @override
  Future<DogPark?> park(String id) => _guard(() async {
    final row = await _client
        .from('dog_parks')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : DogPark.fromRow(row);
  });

  @override
  Future<Set<String>> favoriteIds() => _guard(() async {
    final rows = await _client.from('dog_park_favorites').select('park_id');
    return {for (final row in rows) '${row['park_id']}'};
  });

  @override
  Future<void> setFavorite(String parkId, bool saved) => _guard(() async {
    if (saved) {
      await _client
          .from('dog_park_favorites')
          .upsert(
            {'park_id': parkId},
            onConflict: 'user_id,park_id',
            ignoreDuplicates: true,
          );
    } else {
      await _client.from('dog_park_favorites').delete().eq('park_id', parkId);
    }
  });

  @override
  Future<void> suggestPark(NewParkSuggestion suggestion) =>
      _guard(() async {
        await _client.from('dog_park_suggestions').insert({
          'kind': 'new_park',
          'name': suggestion.name,
          'lat': suggestion.point.lat,
          'lng': suggestion.point.lng,
          'location_kind': suggestion.location.code,
          'locality_code': suggestion.localityCode,
          'place_note': suggestion.placeNote,
          'changes': suggestionChanges(suggestion.details),
        });
      });

  @override
  Future<void> suggestDetails(
    String parkId,
    Map<ParkDetail, ParkAnswer> changes, {
    bool? closed,
  }) => _guard(() async {
    await _client.from('dog_park_suggestions').insert({
      'kind': 'details',
      'park_id': parkId,
      'changes': suggestionChanges(changes, closed: closed),
    });
  });

  @override
  Future<ParkReviewQueue> reviewQueue() => _guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'dog_park_review_queue',
    );
    return ParkReviewQueue.fromJson(json);
  });

  @override
  Future<String?> decide(
    String suggestionId, {
    required bool approve,
    Map<String, Object?> edits = const {},
  }) => _guard(() async {
    final id = await _client.rpc<Object?>(
      'dog_park_decide',
      params: {
        'p_suggestion': suggestionId,
        'p_action': approve ? 'approve' : 'reject',
        'p_edits': edits,
      },
    );
    return id?.toString();
  });

  @override
  Future<void> setParkStatus(String parkId, ParkStatus status) =>
      _guard(() async {
        await _client.rpc<void>(
          'dog_park_set_status',
          params: {'p_park': parkId, 'p_status': status.code},
        );
      });
}
