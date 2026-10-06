import '../../../platform/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../pet_records/data/health_models.dart';
import 'care_models.dart';
import 'care_repository.dart';

typedef Row = Map<String, dynamic>;

/// [CareRepository] on the `pet_care_settings` table of
/// `supabase/migrations/0009_daily_care.sql`.
class SupabaseCareRepository implements CareRepository {
  SupabaseCareRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  static const _table = 'pet_care_settings';

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<CareSettings> fetchSettings(String petId) => _guard(() async {
    if (!_uuid.hasMatch(petId)) return CareSettings(petId: petId);
    final row = await _client
        .from(_table)
        .select()
        .eq('pet_id', petId)
        .maybeSingle();
    return row == null ? CareSettings(petId: petId) : settingsFromRow(row);
  });

  @override
  Future<CareSettings> saveSettings(CareSettings settings) => _guard(() async {
    if (!_uuid.hasMatch(settings.petId)) {
      throw HealthException.of(HealthFailure.petNotStored);
    }
    final row = await _client
        .from(_table)
        .upsert(settingsToRow(settings), onConflict: 'pet_id')
        .select()
        .single();
    return settingsFromRow(row);
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      checkSession();
      final result = await action();
      checkSession();
      return result;
    } on HealthException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == '42501' || message.contains('row-level security')) {
        throw HealthException.of(HealthFailure.notAllowed);
      }
      if (e.code == 'PGRST301' || message.contains('jwt')) {
        throw HealthException.of(HealthFailure.sessionEnded);
      }
      if (e.code == '23514') throw HealthException.of(HealthFailure.invalid);
      if (e.code == '23503') throw HealthException.of(HealthFailure.petGone);
      throw HealthException.of(HealthFailure.unknown);
    } catch (_) {
      throw HealthException.of(HealthFailure.offline);
    }
  }
}

double? _number(Object? value) => (value as num?)?.toDouble();

CareSettings settingsFromRow(Row row) => CareSettings(
  petId: row['pet_id'] as String,
  foodName: (row['food_name'] as String?) ?? '',
  kcalPer100g: _number(row['kcal_per_100g']),
  gramsPerCup: _number(row['grams_per_cup']),
  portionGrams: _number(row['portion_grams']),
  calorieGoal: (row['calorie_goal'] as num?)?.toInt(),
  activityGoalMinutes: (row['activity_goal_minutes'] as num?)?.toInt(),
);

Row settingsToRow(CareSettings s) => {
  'pet_id': s.petId,
  'food_name': s.foodName,
  'kcal_per_100g': s.kcalPer100g,
  'grams_per_cup': s.gramsPerCup,
  'portion_grams': s.portionGrams,
  'calorie_goal': s.calorieGoal,
  'activity_goal_minutes': s.activityGoalMinutes,
};
