import 'package:petloop_access/petloop_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'access_audit.dart';

export 'package:petloop_access/petloop_access.dart';
export 'access_audit.dart';

abstract interface class AccessRepository {
  Future<AccessSnapshot> fetch(String? userId);
  Future<Map<String, dynamic>> administration();
  Future<AccessSnapshot> preview(String userId);
  Future<void> change(String action, Map<String, dynamic> values);
  Future<AccessAuditPage> history(
    AccessAuditQuery query, {
    int? beforeId,
    int limit = 50,
  });
}

class SupabaseAccessRepository implements AccessRepository {
  SupabaseAccessRepository(this.client);
  final SupabaseClient client;

  @override
  Future<AccessAuditPage> history(
    AccessAuditQuery query, {
    int? beforeId,
    int limit = 50,
  }) async => AccessAuditPage.fromJson(
    Map<String, dynamic>.from(
      await client.rpc(
            'access_admin_history',
            params: query.parameters(beforeId: beforeId, limit: limit),
          )
          as Map,
    ),
  );

  @override
  Future<AccessSnapshot> fetch(String? userId) async => AccessSnapshot.fromJson(
    Map<String, dynamic>.from(await client.rpc('get_my_access') as Map),
  );
  @override
  Future<Map<String, dynamic>> administration() async =>
      Map<String, dynamic>.from(await client.rpc('access_admin_state') as Map);
  @override
  Future<AccessSnapshot> preview(String userId) async =>
      AccessSnapshot.fromJson(
        Map<String, dynamic>.from(
          await client.rpc('access_admin_preview', params: {'p_user': userId})
              as Map,
        ),
      );
  @override
  Future<void> change(String action, Map<String, dynamic> values) async {
    await client.rpc(
      'access_admin_change',
      params: {'p_action': action, 'p_values': values},
    );
  }
}

/// Demo policy uses the same precedence as the database. Overrides remain
/// in this instance; no real account receives demo permissions.
class FakeAccessRepository implements AccessRepository {
  final features = {for (final c in capabilityCatalog) featureOf(c): true};
  final users = <String, Map<String, AccessRule>>{};
  final groups = <String, Map<String, AccessRule>>{
    'standard': {
      for (final c in capabilityCatalog.where(
        (c) => c != 'access.admin' && c != 'findvet.admin',
      ))
        c: AccessRule.allow,
    },
  };
  final memberships = <String, Set<String>>{};
  final names = <String, String>{'standard': 'Standard owners'};
  final audit = <Map<String, dynamic>>[];
  int revision = 1;
  bool publicVetSearch = true;

  @override
  Future<AccessAuditPage> history(
    AccessAuditQuery query, {
    int? beforeId,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) throw ArgumentError.value(limit);
    final rows =
        audit
            .map(AccessAuditEntry.fromJson)
            .where(
              (entry) =>
                  (beforeId == null || entry.id < beforeId) &&
                  query.matches(entry),
            )
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    final page = rows.take(limit).toList();
    return AccessAuditPage(page, rows.length > limit ? page.last.id : null);
  }

  Map<String, dynamic>? _currentRow(
    String action,
    Map<String, dynamic> values,
  ) {
    switch (action) {
      case 'feature':
        final id = values['id'] as String;
        return features.containsKey(id)
            ? {
                'id': id,
                'enabled': features[id],
                'public_enabled': id == 'findvet' && publicVetSearch,
              }
            : null;
      case 'group':
        final id = values['id'] as String;
        return groups.containsKey(id)
            ? {'id': id, 'name': names[id] ?? id}
            : null;
      case 'member':
        final user = values['user_id'] as String;
        return (memberships[user] ?? {'standard'}).contains(values['group_id'])
            ? {'user_id': user, 'group_id': values['group_id']}
            : null;
      case 'user_rule' || 'group_rule':
        final key = action == 'user_rule' ? 'user_id' : 'group_id';
        final rules = action == 'user_rule'
            ? users[values[key]]
            : groups[values[key]];
        final rule = rules?[values['capability']];
        return rule == null
            ? null
            : {
                key: values[key],
                'capability': values['capability'],
                'allowed': rule == AccessRule.allow,
              };
      default:
        return null;
    }
  }

  @override
  Future<AccessSnapshot> fetch(String? userId) async => snapshot(userId);

  AccessSnapshot snapshot(String? userId) {
    final policy = AccessPolicy(
      enabled: features,
      individual: users[userId] ?? const {},
      groups: [
        for (final id in memberships[userId] ?? {'standard'})
          groups[id] ?? const {},
      ],
      publicCapabilities: publicVetSearch ? const {'findvet.search'} : const {},
    );
    // Standalone fake-backed widget tests have no auth session. The router
    // still protects the demo app's signed-out UI; real guests use the RPC.
    final decisions = {
      for (final c in capabilityCatalog) c: policy.evaluate(c),
    };
    for (final capability in ['access.admin', 'findvet.admin']) {
      final allowed =
          (userId == 'demo' || userId == null) &&
          features[featureOf(capability)] == true;
      decisions[capability] = AccessDecision(
        allowed,
        allowed ? 'Administrator' : 'Administrator role required',
      );
    }
    return AccessSnapshot(
      userId: userId,
      allowed: decisions.entries
          .where((e) => e.value.allowed)
          .map((e) => e.key),
      reasons: decisions.map((c, d) => MapEntry(c, d.reason)),
      enabled: features,
      revision: revision,
    );
  }

  @override
  Future<AccessSnapshot> preview(String userId) => fetch(userId);

  @override
  Future<Map<String, dynamic>> administration() async => {
    'users': [
      for (final id in {'demo', ...users.keys, ...memberships.keys})
        {'id': id, 'email': id == 'demo' ? 'demo@petloop.app' : id},
    ],
    'groups': [
      for (final id in groups.keys) {'id': id, 'name': names[id] ?? id},
    ],
    'members': [
      for (final user in {'demo', ...users.keys, ...memberships.keys})
        for (final group in memberships[user] ?? {'standard'})
          {'user_id': user, 'group_id': group},
    ],
    'group_rules': [
      for (final e in groups.entries)
        for (final rule in e.value.entries)
          {
            'group_id': e.key,
            'capability': rule.key,
            'allowed': rule.value == AccessRule.allow,
          },
    ],
    'user_rules': [
      for (final e in users.entries)
        for (final rule in e.value.entries)
          {
            'user_id': e.key,
            'capability': rule.key,
            'allowed': rule.value == AccessRule.allow,
          },
    ],
    'features': [
      for (final e in features.entries)
        {
          'id': e.key,
          'enabled': e.value,
          'public_enabled': e.key == 'findvet' && publicVetSearch,
        },
    ],
    'audit': audit.reversed.toList(),
  };

  @override
  Future<void> change(String action, Map<String, dynamic> values) async {
    final before = _currentRow(action, values);
    switch (action) {
      case 'feature':
        final id = values['id'] as String;
        if (id == 'access' || !features.containsKey(id)) {
          throw ArgumentError.value(id);
        }
        features[id] = values['enabled'] as bool;
        if (id == 'findvet' && values.containsKey('public_enabled')) {
          publicVetSearch = values['public_enabled'] as bool;
        }
      case 'group':
        final id = values['id'] as String;
        groups.putIfAbsent(id, () => {});
        names[id] = values['name'] as String;
      case 'member':
        final user = values['user_id'] as String;
        final group = values['group_id'] as String;
        final set = memberships.putIfAbsent(user, () => {'standard'});
        if (values['member'] == true) {
          set.add(group);
        } else {
          set.remove(group);
        }
      case 'user_rule' || 'group_rule':
        final key =
            values[action == 'user_rule' ? 'user_id' : 'group_id'] as String;
        final rules = action == 'user_rule'
            ? users.putIfAbsent(key, () => {})
            : groups.putIfAbsent(key, () => {});
        final capability = values['capability'] as String;
        if (capability == 'access.admin' ||
            !capabilityCatalog.contains(capability)) {
          throw ArgumentError.value(capability);
        }
        if (values['allowed'] == null) {
          rules.remove(capability);
        } else {
          rules[capability] = values['allowed'] == true
              ? AccessRule.allow
              : AccessRule.deny;
        }
      default:
        throw ArgumentError.value(action);
    }
    final after = _currentRow(action, values);
    final table = switch (action) {
      'feature' => 'feature_catalog',
      'group' => 'access_groups',
      'member' => 'access_group_members',
      'user_rule' => 'user_capability_rules',
      'group_rule' => 'group_capability_rules',
      _ => action,
    };
    audit.add({
      'id': audit.isEmpty ? 1 : (audit.last['id'] as int) + 1,
      'actor_id': 'demo',
      'actor_email': 'demo@petloop.app',
      'action':
          '$table:${after == null
              ? 'DELETE'
              : before == null
              ? 'INSERT'
              : 'UPDATE'}',
      'before_value': before,
      'after_value': after,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    revision++;
  }
}
