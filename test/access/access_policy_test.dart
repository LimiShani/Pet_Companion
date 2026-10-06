import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/access/access_repository.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';

void main() {
  test(
    'individual overrides beat group deny; feature off and read prerequisites beat overrides',
    () {
      AccessPolicy policy({
        bool enabled = true,
        AccessRule read = AccessRule.allow,
      }) => AccessPolicy(
        enabled: {'care': enabled},
        individual: {'care.edit': AccessRule.allow, 'care.view': read},
        groups: [
          {'care.edit': AccessRule.deny},
          {'care.edit': AccessRule.allow},
        ],
      );
      expect(policy().evaluate('care.edit').allowed, isTrue);
      expect(policy(enabled: false).evaluate('care.edit').allowed, isFalse);
      expect(
        policy(read: AccessRule.deny).evaluate('care.edit').allowed,
        isFalse,
      );
    },
  );
  test('group denial wins regardless of group ordering', () {
    for (final groups in [
      [
        {'care.view': AccessRule.allow},
        {'care.view': AccessRule.deny},
      ],
      [
        {'care.view': AccessRule.deny},
        {'care.view': AccessRule.allow},
      ],
    ]) {
      expect(
        AccessPolicy(
          enabled: {'care': true},
          groups: groups,
        ).evaluate('care.view').allowed,
        isFalse,
      );
    }
  });
  test('unknown, ungranted and anonymous private capabilities fail closed', () {
    final policy = AccessPolicy(
      enabled: {'care': true, 'findvet': true},
      groups: [
        {'care.view': AccessRule.allow},
      ],
      publicCapabilities: {'findvet.search'},
    );
    expect(policy.evaluate('unknown.view').allowed, isFalse);
    expect(policy.evaluate('care.edit').allowed, isFalse);
    expect(policy.evaluate('care.view', anonymous: true).allowed, isFalse);
    expect(policy.evaluate('findvet.search', anonymous: true).allowed, isTrue);
  });
  test('new demo accounts have standard features but no administration', () {
    final access = FakeAccessRepository().snapshot('new-owner');
    expect(access.can('pets.edit'), isTrue);
    expect(access.can('care.edit'), isTrue);
    expect(access.can('access.admin'), isFalse);
    expect(access.can('findvet.admin'), isFalse);
  });
  test('signup and subsequent sign-in never grant administrator roles', () async {
    final auth = FakeAuthRepository(latency: Duration.zero);
    final repository = FakeAccessRepository();
    final user = await auth.signUp(
      displayName: 'Administrator',
      email: 'new-owner@example.test',
      password: 'owner1234',
    );
    final access = await repository.fetch(user.id);
    expect(access.can('pets.edit'), isTrue);
    expect(access.can('care.edit'), isTrue);
    expect(access.can('access.admin'), isFalse);
    expect(access.can('findvet.admin'), isFalse);
    await auth.signOut();
    final signedIn = await auth.signIn(
      email: user.email,
      password: 'owner1234',
    );
    final restored = await repository.fetch(signedIn.id);
    expect(restored.can('access.admin'), isFalse);
    expect(restored.can('findvet.admin'), isFalse);
  });
  test(
    'group memberships, overrides, inherited rules and audit round trip',
    () async {
      final repository = FakeAccessRepository();
      await repository.change('group', {
        'id': 'restricted',
        'name': 'Restricted',
      });
      await repository.change('member', {
        'user_id': 'owner',
        'group_id': 'restricted',
        'member': true,
      });
      await repository.change('group_rule', {
        'group_id': 'restricted',
        'capability': 'care.view',
        'allowed': false,
      });
      expect((await repository.preview('owner')).can('care.view'), isFalse);
      await repository.change('user_rule', {
        'user_id': 'owner',
        'capability': 'care.view',
        'allowed': true,
      });
      expect((await repository.preview('owner')).can('care.view'), isTrue);
      await repository.change('user_rule', {
        'user_id': 'owner',
        'capability': 'care.view',
        'allowed': null,
      });
      expect((await repository.preview('owner')).can('care.view'), isFalse);
      await repository.change('member', {
        'user_id': 'owner',
        'group_id': 'restricted',
        'member': false,
      });
      expect((await repository.preview('owner')).can('care.view'), isTrue);
      final state = await repository.administration();
      expect(
        (state['members'] as List)
            .where((r) => r['user_id'] == 'owner')
            .single['group_id'],
        'standard',
      );
      expect(state['audit'], hasLength(6));
    },
  );
}
