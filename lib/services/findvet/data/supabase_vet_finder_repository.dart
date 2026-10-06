import '../../../platform/session.dart';
import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../l10n/settings_store.dart';
import '../regions/region.dart';
import 'local_ranking.dart';
import 'vet_finder_repository.dart';
import 'vet_models.dart';

/// Find a vet on Supabase.
///
/// - The live search is the `find-vet` Edge Function (it holds the places
///   provider's key and does the matching and ranking).
/// - When the function cannot be reached, the app reads PetLoop's own
///   directory (`vet_directory_public`, readable without signing in) and
///   ranks it itself; with no connection at all it uses the copy of that
///   directory kept on the phone. Only our own maintained records are
///   copied: provider listings and the owner's searches are never stored.
class SupabaseVetFinderRepository implements VetFinderRepository {
  SupabaseVetFinderRepository(
    this._backend, {
    required SettingsStore store,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 15),
  }) : _store = store,
       _now = now ?? DateTime.now;

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  final SettingsStore _store;
  final DateTime Function() _now;
  final Duration timeout;

  static const functionName = 'find-vet';

  /// The settings key of the directory copy of [region].
  static String copyKey(String region) => 'findvet.directory.$region';

  @override
  bool get isDemo => false;

  @override
  Future<VetSearchResult> search({
    required VetRegion region,
    required VetSearchMode mode,
    required GeoPoint center,
    required int radiusM,
    required String language,
  }) async {
    try {
      final response = await _client.functions
          .invoke(
            functionName,
            body: {
              'action': 'search',
              'region': region.code,
              'mode': mode.wire,
              'lat': center.lat,
              'lng': center.lng,
              'radiusM': radiusM,
              'lang': language,
            },
          )
          .timeout(timeout);
      final data = response.data;
      if (data is! Map) {
        throw const VetFinderException(
          VetFinderFailure.unavailable,
          'not json',
        );
      }
      return VetSearchResult.fromJson(data, mode: mode);
    } on sb.FunctionException catch (e) {
      // A request the server rejects would be rejected again: say so.
      if (e.status == 400) {
        throw VetFinderException(_badRequest(e.details), '${e.details}');
      }
      if (e.status == 429) {
        throw const VetFinderException(VetFinderFailure.rateLimited);
      }
      return _fromDirectory(
        region: region,
        mode: mode,
        center: center,
        language: language,
      );
    } on VetFinderException {
      return _fromDirectory(
        region: region,
        mode: mode,
        center: center,
        language: language,
      );
    } catch (_) {
      // No connection, a timeout, a server error: our own records next.
      return _fromDirectory(
        region: region,
        mode: mode,
        center: center,
        language: language,
      );
    }
  }

  VetFinderFailure _badRequest(Object? details) =>
      details is Map && details['error'] == 'unsupported_region'
      ? VetFinderFailure.unsupportedRegion
      : VetFinderFailure.invalid;

  @override
  Future<List<PlaceMatch>> geocode({
    required VetRegion region,
    required String query,
    required String language,
  }) async {
    try {
      final response = await _client.functions
          .invoke(
            functionName,
            body: {
              'action': 'geocode',
              'region': region.code,
              'query': query,
              'lang': language,
            },
          )
          .timeout(timeout);
      final data = response.data;
      final results = data is Map ? data['results'] : null;
      return [
        if (results is List)
          for (final r in results)
            if (r is Map && r['lat'] is num && r['lng'] is num)
              PlaceMatch(
                label: '${r['label'] ?? query}',
                point: GeoPoint(
                  (r['lat'] as num).toDouble(),
                  (r['lng'] as num).toDouble(),
                ),
              ),
      ];
    } on sb.FunctionException catch (e) {
      if (e.status == 429) {
        throw const VetFinderException(VetFinderFailure.rateLimited);
      }
      if (e.status == 400) throw VetFinderException(_badRequest(e.details));
      throw const VetFinderException(VetFinderFailure.unavailable);
    } catch (_) {
      throw const VetFinderException(VetFinderFailure.offline);
    }
  }

  /// Reads the region's directory and keeps a copy on the phone for the
  /// times there is no connection. Best effort: failures are ignored.
  Future<void> refreshDirectoryCopy(VetRegion region) async {
    try {
      await _readDirectory(region);
    } catch (_) {}
  }

  Future<List<Map>> _readDirectory(VetRegion region) async {
    final rows = await _client
        .from('vet_directory_public')
        .select()
        .eq('country_code', region.code)
        .timeout(timeout);
    await _store.write(
      copyKey(region.code),
      jsonEncode({'savedAt': _now().toUtc().toIso8601String(), 'rows': rows}),
    );
    return rows.cast<Map>();
  }

  Future<Map<String, IntakeReport>> _readIntake() async {
    final rows = await _client
        .from('vet_intake_current')
        .select()
        .timeout(timeout);
    return {
      for (final row in rows)
        '${row['facility_id']}': IntakeReport(
          state: IntakeState.parse(row['status']),
          species: [
            for (final s in (row['species'] as List? ?? const [])) '$s',
          ],
          updatedAt: DateTime.tryParse('${row['updated_at']}'),
          expiresAt: DateTime.tryParse('${row['expires_at']}'),
        ),
    };
  }

  Future<VetSearchResult> _fromDirectory({
    required VetRegion region,
    required VetSearchMode mode,
    required GeoPoint center,
    required String language,
  }) async {
    List<Map> rows;
    DateTime? copyFrom;
    var intake = const <String, IntakeReport>{};
    try {
      rows = await _readDirectory(region);
      try {
        intake = await _readIntake();
      } catch (_) {}
    } catch (_) {
      final copy = _readCopy(region);
      if (copy == null) {
        throw const VetFinderException(VetFinderFailure.offline);
      }
      rows = copy.rows;
      copyFrom = copy.savedAt;
    }
    return rankDirectoryLocally(
      region: region,
      mode: mode,
      center: center,
      directory: [
        for (final row in rows)
          if (row['lat'] is num && row['lng'] is num)
            directoryRecord(row, language: language, intake: intake),
      ],
      now: _now(),
      providerStatus: ProviderStatus.unreached,
      directoryCopyFrom: copyFrom,
    );
  }

  ({List<Map> rows, DateTime savedAt})? _readCopy(VetRegion region) {
    final raw = _store.read(copyKey(region.code));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map;
      final savedAt = DateTime.parse('${json['savedAt']}');
      return (rows: (json['rows'] as List).cast<Map>(), savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }
}

/// A row of `vet_directory_public` as a result card's data.
VetResult directoryRecord(
  Map row, {
  required String language,
  Map<String, IntakeReport> intake = const {},
}) {
  final id = '${row['id']}';
  final hebrewName = row['name_he'];
  final name =
      language == 'he' && hebrewName is String && hebrewName.trim().isNotEmpty
      ? hebrewName
      : row['name'];
  final address = [
    row['address'],
    row['city'],
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  return VetResult(
    key: 'f:$id',
    facilityId: id,
    name: '${name ?? ''}',
    address: address.isEmpty ? null : address,
    location: GeoPoint(
      (row['lat'] as num?)?.toDouble() ?? 0,
      (row['lng'] as num?)?.toDouble() ?? 0,
    ),
    phone: row['phone'] as String?,
    website: row['website'] as String?,
    fromCurated: true,
    emergency: EmergencyClaim.fromJson(row['emergency']),
    intake: intake[id] ?? IntakeReport.unknown,
    facts: [
      for (final fact in (row['facts'] as List? ?? const []))
        if (fact is Map) SourcedFact.fromJson(fact),
    ],
    lastCheckedAt: DateTime.tryParse('${row['last_checked_at']}'),
    reviewStatus: row['review_status'] as String?,
  );
}
