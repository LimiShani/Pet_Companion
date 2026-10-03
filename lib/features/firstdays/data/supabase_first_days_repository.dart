import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../health/data/health_models.dart';
import 'first_days_models.dart';
import 'first_days_repository.dart';

typedef Row = Map<String, dynamic>;

/// [FirstDaysRepository] on the `pet_first_days` table of
/// `supabase/migrations/0011_first_days.sql`.
class SupabaseFirstDaysRepository implements FirstDaysRepository {
  SupabaseFirstDaysRepository(this._client);

  final sb.SupabaseClient _client;

  static const _table = 'pet_first_days';

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  @override
  Future<FirstDaysPath?> fetch(String petId) => _guard(() async {
    if (!_uuid.hasMatch(petId)) return null;
    final row = await _client.from(_table).select().eq('pet_id', petId).maybeSingle();
    return row == null ? null : firstDaysFromRow(row);
  });

  @override
  Future<FirstDaysPath> save(FirstDaysPath path) => _guard(() async {
    if (!_uuid.hasMatch(path.petId)) throw HealthException.of(HealthFailure.petNotStored);
    final row = await _client.from(_table).upsert(firstDaysToRow(path), onConflict: 'pet_id').select().single();
    return firstDaysFromRow(row);
  });

  @override
  Future<void> delete(String petId) => _guard(() async {
    if (!_uuid.hasMatch(petId)) return;
    await _client.from(_table).delete().eq('pet_id', petId);
  });

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on HealthException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (e.code == '42501' || message.contains('row-level security')) {
        throw HealthException.of(HealthFailure.notAllowed);
      }
      if (e.code == 'PGRST301' || message.contains('jwt')) throw HealthException.of(HealthFailure.sessionEnded);
      if (e.code == '23514') throw HealthException.of(HealthFailure.invalid);
      if (e.code == '23503') throw HealthException.of(HealthFailure.petGone);
      throw HealthException.of(HealthFailure.unknown);
    } catch (_) {
      throw HealthException.of(HealthFailure.offline);
    }
  }
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

FirstDaysPath firstDaysFromRow(Row row) => FirstDaysPath(
  petId: row['pet_id'] as String,
  arrivedOn: DateTime.parse(row['arrived_on'] as String),
  closedAt: row['closed_at'] == null ? null : DateTime.parse(row['closed_at'] as String).toLocal(),
  doneTasks: {for (final id in (row['done_tasks'] as List<dynamic>?) ?? const []) id as String},
);

Row firstDaysToRow(FirstDaysPath path) => {
  'pet_id': path.petId,
  'arrived_on': _date(path.arrivedOn),
  'closed_at': path.closedAt?.toUtc().toIso8601String(),
  'done_tasks': (path.doneTasks.toList()..sort()),
};
