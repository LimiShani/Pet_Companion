import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../platform/session.dart';
import '../../findvet/regions/region.dart' show GeoPoint;
import 'hazard_models.dart';
import 'hazards_repository.dart';
import 'park_models.dart';

/// [HazardsRepository] on `supabase/migrations/0035_neighbourhood.sql`:
/// reads the `hazard_board` view (the reader's rights: current reports and
/// one's own, never a blocked member's), writes through `hazard_report`,
/// `hazard_vote` and `hazard_delete`. Before 0035 is run the list is
/// simply empty.
class SupabaseHazardsRepository implements HazardsRepository {
  SupabaseHazardsRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  static const _limit = 200;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on HazardException {
      rethrow;
    } on StaleSessionException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw HazardException(failureOf(e.message, e.code));
    } catch (_) {
      throw const HazardException(HazardFailure.unavailable);
    }
  }

  /// The failure the server's refusal names (the functions of 0035 raise
  /// these words).
  static HazardFailure failureOf(String message, String? code) {
    final text = message.toLowerCase();
    if (text.contains('rate_limited')) return HazardFailure.rateLimited;
    if (text.contains('not_open')) return HazardFailure.notOpen;
    if (text.contains('invalid_hazard') || code == '22023' || code == '22P02') {
      return HazardFailure.invalid;
    }
    return HazardFailure.other;
  }

  /// The view does not exist yet: 0035 has not been run.
  static bool _missing(sb.PostgrestException e) =>
      e.code == '42P01' || e.code == 'PGRST205' || e.code == 'PGRST202';

  @override
  bool get isDemo => false;

  @override
  Future<List<HazardReport>> current(Iterable<String> localityCodes) =>
      _guard(() async {
        final codes = localityCodes.toList();
        if (codes.isEmpty) return const [];
        try {
          final rows = await _client
              .from('hazard_board')
              .select()
              .inFilter('locality_code', codes)
              .gt('expires_at', DateTime.now().toUtc().toIso8601String())
              .order('created_at', ascending: false)
              .limit(_limit);
          return [for (final row in rows) hazardFromRow(row)];
        } on sb.PostgrestException catch (e) {
          if (_missing(e)) return const [];
          rethrow;
        }
      });

  @override
  Future<String> report(HazardDraft draft) => _guard(() async {
    final id = await _client.rpc(
      'hazard_report',
      params: {'p': hazardDraftJson(draft)},
    );
    return '$id';
  });

  @override
  Future<bool> vote(String id, {required bool gone}) => _guard(() async {
    final shown = await _client.rpc(
      'hazard_vote',
      params: {'p_id': id, 'p_gone': gone},
    );
    return shown != false;
  });

  @override
  Future<void> delete(String id) =>
      _guard(() => _client.rpc('hazard_delete', params: {'p_id': id}));
}

/// What `hazard_report` receives for [draft].
Map<String, Object?> hazardDraftJson(HazardDraft draft) => {
  'kind': draft.kind.key,
  'park_id': draft.parkId,
  if (draft.parkId == null) 'locality_code': draft.localityCode,
  'note': draft.note.trim(),
};

/// A report from a `hazard_board` row.
HazardReport hazardFromRow(Map row) {
  String? text(Object? value) {
    final t = value == null ? '' : '$value'.trim();
    return t.isEmpty ? null : t;
  }

  DateTime time(Object? value) =>
      value == null ? DateTime.now() : DateTime.parse('$value').toLocal();
  final parkId = text(row['park_id']);
  final lat = row['park_lat'] as num?;
  final lng = row['park_lng'] as num?;
  return HazardReport(
    id: '${row['id']}',
    localityCode: '${row['locality_code']}',
    parkId: parkId,
    park: parkId == null || lat == null || lng == null
        ? null
        : DogPark(
            id: parkId,
            point: GeoPoint(lat.toDouble(), lng.toDouble()),
            nameHe: text(row['park_name_he']),
            nameEn: text(row['park_name_en']),
            streetHe: text(row['park_street_he']),
            streetEn: text(row['park_street_en']),
            localityCode: text(row['locality_code']),
          ),
    kind: HazardKind.parse(row['kind']) ?? HazardKind.other,
    note: '${row['note'] ?? ''}',
    createdAt: time(row['created_at']),
    expiresAt: time(row['expires_at']),
    mine: row['mine'] == true,
    hidden: row['hidden'] == true,
    stillCount: (row['still_count'] as num?)?.toInt() ?? 0,
    goneCount: (row['gone_count'] as num?)?.toInt() ?? 0,
    myVote: row['my_vote'] as bool?,
  );
}
