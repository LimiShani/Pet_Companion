import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'lost_alert_models.dart';
import 'lost_alerts_repository.dart';

/// Lost mode on Supabase: the functions of `0034_lost_alerts.sql`.
class SupabaseLostAlertsRepository implements LostAlertsRepository {
  SupabaseLostAlertsRepository(this._client);

  final sb.SupabaseClient _client;

  Future<Object?> _rpc(String name, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc<Object?>(name, params: params);
    } on sb.PostgrestException catch (error) {
      throw LostAlertException(failureOf(error), error.details ?? error.message);
    } on LostAlertException {
      rethrow;
    } catch (error) {
      throw LostAlertException(LostAlertFailure.unknown, error);
    }
  }

  /// How the server's refusals read in the app.
  static LostAlertFailure failureOf(sb.PostgrestException error) {
    if (error.message.contains('lost_active')) {
      return LostAlertFailure.alreadyActive;
    }
    if (error.message.contains('rate_limited')) {
      return LostAlertFailure.rateLimited;
    }
    return switch (error.code) {
      '22023' => LostAlertFailure.invalid,
      '42501' => LostAlertFailure.notAllowed,
      _ => LostAlertFailure.unknown,
    };
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in (value as List?) ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static LostAlert _alert(Object? value) =>
      LostAlert.fromJson(Map<String, dynamic>.from(value! as Map));

  @override
  Future<List<LostAlert>> mine() async =>
      _rows(await _rpc('lost_alerts_mine')).map(LostAlert.fromJson).toList();

  @override
  Future<List<NearbyLostAlert>> near(String localityCode) async => _rows(
    await _rpc('lost_alerts_near', {'p_locality': localityCode}),
  ).map(NearbyLostAlert.fromJson).toList();

  @override
  Future<LostAlert> start(LostStart request) async => _alert(
    await _rpc('lost_start', {
      'p_pet': request.petId,
      'p_locality': request.localityCode,
      'p_place': request.place,
      'p_seen_at': request.seenAt.toUtc().toIso8601String(),
      'p_note': request.note,
      'p_language': request.language,
      'p_photo_path': request.photoPath,
      'p_area_name': request.areaName,
    }),
  );

  @override
  Future<LostAlert> markFound(String alertId) async =>
      _alert(await _rpc('lost_found', {'p_alert': alertId}));

  @override
  Future<LostAlert> cancel(String alertId) async =>
      _alert(await _rpc('lost_cancel', {'p_alert': alertId}));
}
