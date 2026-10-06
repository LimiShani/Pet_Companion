import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/access/access_repository.dart';

void main() {
  test('saved changes contain actor, timestamp and both values', () async {
    final repository = FakeAccessRepository();
    await repository.change('feature', {'id': 'care', 'enabled': false});
    final entry = (await repository.history(
      const AccessAuditQuery(),
    )).entries.single;
    expect(entry.actorEmail, 'demo@petloop.app');
    expect(entry.actorId, 'demo');
    expect(entry.action, 'feature_catalog:UPDATE');
    expect(entry.before?['enabled'], isTrue);
    expect(entry.after?['enabled'], isFalse);
    expect(entry.createdAt.isUtc, isTrue);
    // A later change cannot rewrite an earlier snapshot.
    await repository.change('feature', {'id': 'care', 'enabled': true});
    expect(
      (await repository.history(
        const AccessAuditQuery(),
      )).entries.last.after?['enabled'],
      isFalse,
    );
    await expectLater(
      repository.change('feature', {'id': 'access', 'enabled': false}),
      throwsArgumentError,
    );
    expect(repository.audit, hasLength(2));
  });

  test(
    'cursor paging reaches more than 100 records without duplicates during new changes',
    () async {
      final repository = FakeAccessRepository();
      for (var i = 0; i < 121; i++) {
        await repository.change('feature', {'id': 'care', 'enabled': i.isEven});
      }
      final first = await repository.history(const AccessAuditQuery());
      await repository.change('feature', {'id': 'care', 'enabled': false});
      final second = await repository.history(
        const AccessAuditQuery(),
        beforeId: first.nextCursor,
      );
      final third = await repository.history(
        const AccessAuditQuery(),
        beforeId: second.nextCursor,
      );
      final ids = [
        ...first.entries,
        ...second.entries,
        ...third.entries,
      ].map((e) => e.id).toList();
      expect(ids, hasLength(121));
      expect(ids.toSet(), hasLength(121));
      expect(third.entries, hasLength(21));
      expect(third.nextCursor, isNull);
      expect(ids, orderedEquals(List.generate(121, (i) => 121 - i)));
    },
  );

  test(
    'actor/action/date filters use saved identity and exclusive end',
    () async {
      final repository = FakeAccessRepository();
      final instant = DateTime.utc(2026, 10, 5, 12);
      repository.audit.addAll([
        {
          'id': 1,
          'actor_id': 'deleted-admin',
          'actor_email': 'former@example.test',
          'action': 'feature_catalog:UPDATE',
          'created_at': instant.toIso8601String(),
        },
        {
          'id': 2,
          'actor_id': 'demo',
          'actor_email': 'demo@petloop.app',
          'action': 'access_groups:INSERT',
          'created_at': instant.add(const Duration(days: 1)).toIso8601String(),
        },
      ]);
      final query = AccessAuditQuery(
        actor: 'FORMER',
        action: 'feature_catalog',
        from: instant,
        until: instant.add(const Duration(days: 1)),
      );
      expect((await repository.history(query)).entries.single.id, 1);
      expect(
        (await repository.history(AccessAuditQuery(until: instant))).entries,
        isEmpty,
      );
      expect(
        (await repository.history(
          const AccessAuditQuery(actor: 'deleted-admin'),
        )).entries.single.actorEmail,
        'former@example.test',
      );
      expect(query.parameters(beforeId: 99)['p_before_id'], 99);
      expect(
        query.parameters()['p_until'],
        instant.add(const Duration(days: 1)).toIso8601String(),
      );
    },
  );
}
