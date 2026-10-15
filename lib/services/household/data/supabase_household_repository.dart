import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../models/pet.dart';
import '../../../platform/session.dart';
import 'household_models.dart';
import 'household_repository.dart';

typedef _Row = Map<String, dynamic>;

/// [HouseholdRepository] on the functions of
/// `supabase/migrations/0030_household.sql`. The tables are read only
/// through them: `my_households()` gives fellow members' names, which the
/// profiles table keeps private.
class SupabaseHouseholdRepository implements HouseholdRepository {
  SupabaseHouseholdRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  static const _timeout = Duration(seconds: 20);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on HouseholdException {
      rethrow;
    } on StaleSessionException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw HouseholdException(HouseholdFailure.fromMessage(e.message));
    } catch (_) {
      throw const HouseholdException(HouseholdFailure.offline);
    }
  }

  @override
  Future<List<Household>> myHouseholds() => _guard(() async {
    final rows = await _client.rpc('my_households') as List;
    return [for (final row in rows) householdFromRow(_row(row))];
  });

  @override
  Future<NewInvite> createInvite(String householdId) => _guard(() async {
    final row = _row(
      await _client.rpc(
        'create_household_invite',
        params: {'p_household': householdId},
      ),
    );
    return NewInvite(
      code: row['code'] as String,
      expiresAt: _instant(row['expires_at']),
    );
  });

  @override
  Future<void> revokeInvite(String code) => _guard(() async {
    await _client.rpc('revoke_household_invite', params: {'p_code': code});
  });

  @override
  Future<InvitePreview> preview(String code) => _guard(() async {
    final row = _row(
      await _client.rpc(
        'preview_household_invite',
        params: {'p_code': normalInviteCode(code)},
      ),
    );
    return previewFromRow(row);
  });

  @override
  Future<String> accept(String code) => _guard(() async {
    return await _client.rpc(
          'accept_household_invite',
          params: {'p_code': normalInviteCode(code)},
        )
        as String;
  });

  @override
  Future<void> removeMember(String householdId, String userId) =>
      _guard(() async {
        await _client.rpc(
          'remove_household_member',
          params: {'p_household': householdId, 'p_user': userId},
        );
      });

  @override
  Future<void> leave(String householdId) => _guard(() async {
    await _client.rpc('leave_household', params: {'p_household': householdId});
  });

  @override
  Future<void> rename(String householdId, String name) => _guard(() async {
    await _client.rpc(
      'rename_household',
      params: {'p_household': householdId, 'p_name': name},
    );
  });
}

_Row _row(Object? value) => Map<String, dynamic>.from(value as Map);

DateTime _instant(Object? value) =>
    DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

List<_Row> _rows(Object? value) => [
  for (final row in (value as List?) ?? const []) _row(row),
];

HouseholdPet _pet(_Row row) => HouseholdPet(
  id: row['id'] as String? ?? '',
  name: row['name'] as String? ?? '',
  species: PetSpecies.fromName(row['species'] as String?),
  iconKey: row['icon_key'] as String?,
);

/// One element of `my_households()`.
Household householdFromRow(Map<String, dynamic> row) => Household(
  id: row['id'] as String,
  name: row['name'] as String? ?? '',
  ownerId: row['owner_id'] as String,
  myRole: HouseholdRole.fromDb(row['my_role']),
  members: [
    for (final m in _rows(row['members']))
      HouseholdMember(
        userId: m['user_id'] as String,
        name: m['name'] as String? ?? '',
        role: HouseholdRole.fromDb(m['role']),
        joinedAt: _instant(m['joined_at']),
      ),
  ],
  invites: [
    for (final i in _rows(row['invites']))
      HouseholdInvite(
        code: i['code'] as String,
        createdBy: i['created_by'] as String? ?? '',
        createdByName: i['created_by_name'] as String? ?? '',
        createdAt: _instant(i['created_at']),
        expiresAt: _instant(i['expires_at']),
      ),
  ],
  pets: [for (final p in _rows(row['pets'])) _pet(p)],
);

/// What `preview_household_invite()` answers.
InvitePreview previewFromRow(Map<String, dynamic> row) => InvitePreview(
  status: InviteStatus.fromDb(row['status']),
  code: row['code'] as String? ?? '',
  householdId: row['household_id'] as String? ?? '',
  householdName: row['household_name'] as String? ?? '',
  inviterName: row['inviter_name'] as String? ?? '',
  memberCount: (row['member_count'] as num?)?.toInt() ?? 0,
  pets: [for (final p in _rows(row['pets'])) _pet(p)],
);
