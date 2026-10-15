import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/household/household.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/household/data/supabase_household_repository.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';

import 'household_test_helpers.dart';

void main() {
  group('codes', () {
    test('are typed in any case, with spaces or a dash', () {
      expect(normalInviteCode(' kely-7q4m '), 'KELY7Q4M');
      expect(looksLikeInviteCode('kely 7q4m'), isTrue);
      expect(looksLikeInviteCode('KELY7Q4'), isFalse, reason: 'seven letters');
      expect(looksLikeInviteCode('KELY7Q40'), isFalse, reason: 'no zero');
      expect(looksLikeInviteCode('IELY7Q4M'), isFalse, reason: 'no I');
    });

    test('read in two halves, and lead to the join page', () {
      expect(formatInviteCode('KELY7Q4M'), 'KELY-7Q4M');
      expect(inviteLink('KELY7Q4M'), 'https://petloop.app/join/KELY7Q4M');
    });
  });

  group('names', () {
    final en = lookupHouseholdL10n(englishLocale);
    final he = lookupHouseholdL10n(hebrewLocale);

    test('a household is named after its pets, else its owner', () {
      expect(
        householdTitle(en, name: '', petNames: ['Kelly']),
        "Kelly's household",
      );
      expect(
        householdTitle(en, name: '', petNames: ['Kelly', 'Soya']),
        "Kelly & Soya's household",
      );
      expect(
        householdTitle(
          en,
          name: '',
          petNames: ['A', 'B', 'C'],
          ownerName: 'Limi',
        ),
        "Limi's household",
      );
      expect(householdTitle(en, name: '', petNames: const []), 'Our household');
      expect(
        householdTitle(en, name: ' The Shanis ', petNames: ['Kelly']),
        'The Shanis',
      );
    });

    test('in Hebrew, each name is isolated and none takes a prefix', () {
      final two = householdTitle(he, name: '', petNames: ['Kelly', 'Soya']);
      expect(two, 'הבית של \u2068Kelly\u2069 ושל \u2068Soya\u2069');
    });
  });

  test('a meal or walk shows who logged it only when someone else did', () {
    CareLog log({String? by, String name = 'Dana'}) => CareLog(
      id: '1',
      petId: 'kelly',
      title: 'Breakfast',
      dueOn: DateTime(2026, 10, 14),
      status: CareLogStatus.done,
      loggedAt: DateTime(2026, 10, 14, 7, 40),
      loggedByName: name,
      loggedBy: by,
    );
    expect(log(by: 'dana').loggedByOther('demo'), 'Dana');
    expect(log(by: 'demo').loggedByOther('demo'), isNull, reason: 'my own');
    expect(log().loggedByOther('demo'), isNull, reason: 'nobody known');
    expect(
      log(by: 'dana', name: ' ').loggedByOther('demo'),
      isNull,
      reason: 'no name',
    );
  });

  test('the server words of a refusal become failures', () {
    expect(
      HouseholdFailure.fromMessage('invite_expired'),
      HouseholdFailure.inviteExpired,
    );
    expect(
      HouseholdFailure.fromMessage('household_full'),
      HouseholdFailure.full,
    );
    expect(
      HouseholdFailure.fromMessage('owner_only'),
      HouseholdFailure.ownerOnly,
    );
    expect(
      HouseholdFailure.fromMessage('Something else'),
      HouseholdFailure.offline,
    );
  });

  test('my_households() and preview_household_invite() rows are read', () {
    final household = householdFromRow({
      'id': 'h1',
      'name': '',
      'owner_id': 'u1',
      'my_role': 'carer',
      'members': [
        {
          'user_id': 'u1',
          'name': 'Limi',
          'role': 'owner',
          'joined_at': '2026-01-01T10:00:00Z',
        },
        {
          'user_id': 'u2',
          'name': 'Dana',
          'role': 'carer',
          'joined_at': '2026-02-01T10:00:00Z',
        },
      ],
      'invites': [
        {
          'code': 'KELY7Q4M',
          'created_by': 'u1',
          'created_by_name': 'Limi',
          'created_at': '2026-10-12T10:00:00Z',
          'expires_at': '2026-10-19T10:00:00Z',
        },
      ],
      'pets': [
        {'id': 'p1', 'name': 'Kelly', 'species': 'dog', 'icon_key': null},
      ],
    });
    expect(household.amOwner, isFalse);
    expect(household.owner?.name, 'Limi');
    expect(household.invites.single.code, 'KELY7Q4M');
    expect(household.pets.single.name, 'Kelly');
    expect(household.placesLeft, 7);

    final preview = previewFromRow({
      'status': 'expired',
      'code': 'KELY7Q4M',
      'household_id': 'h1',
      'household_name': '',
      'inviter_name': 'Limi',
      'member_count': 2,
      'pets': [
        {'name': 'Kelly', 'species': 'dog'},
      ],
    });
    expect(preview.status, InviteStatus.expired);
    expect(preview.memberCount, 2);
    expect(
      previewFromRow({'status': 'not_found'}).status,
      InviteStatus.notFound,
    );
  });

  test('the own household is left out while empty and there is another', () {
    Household h(
      String id,
      String owner, {
      int members = 1,
      bool pets = false,
    }) => Household(
      id: id,
      name: '',
      ownerId: owner,
      myRole: owner == 'me' ? HouseholdRole.owner : HouseholdRole.carer,
      members: [
        for (var i = 0; i < members; i++)
          HouseholdMember(
            userId: i == 0 ? owner : 'm$i',
            name: 'M$i',
            role: i == 0 ? HouseholdRole.owner : HouseholdRole.carer,
            joinedAt: DateTime(2026),
          ),
      ],
      pets: pets ? const [HouseholdPet(id: 'p', name: 'Kelly')] : const [],
    );
    final emptyOwn = h('own', 'me');
    final family = h('family', 'mum', members: 3, pets: true);
    expect(householdsToShow([emptyOwn, family], 'me'), [family]);
    expect(householdsToShow([emptyOwn], 'me'), [
      emptyOwn,
    ], reason: 'alone, it shows');
    final ownWithPet = h('own', 'me', pets: true);
    expect(householdsToShow([ownWithPet, family], 'me'), [ownWithPet, family]);
  });

  group("the demo backend keeps the server's rules", () {
    late FakeHouseholdRepository repo;
    setUp(() => repo = demoHouseholds());

    test(
      "the demo account owns Kelly and Soya's household with Dana and Noa",
      () async {
        final households = await repo.myHouseholds();
        expect(households, hasLength(1));
        final home = households.single;
        expect(home.amOwner, isTrue);
        expect([for (final m in home.members) m.name], ['Alex', 'Dana', 'Noa']);
        expect(
          home.invites.single.code,
          FakeHouseholdRepository.demoInviteCode,
        );
        expect([for (final p in home.pets) p.id], ['kelly', 'soya']);
      },
    );

    test(
      'only the owner removes and renames; the owner never leaves',
      () async {
        await repo.rename(
          FakeHouseholdRepository.demoHouseholdId,
          '  The Shanis ',
        );
        expect((await repo.myHouseholds()).single.name, 'The Shanis');
        await expectLater(
          repo.rename(FakeHouseholdRepository.demoHouseholdId, 'x' * 41),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.invalidName,
            ),
          ),
        );
        await expectLater(
          repo.leave(FakeHouseholdRepository.demoHouseholdId),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.ownerOnly,
            ),
          ),
        );
        await repo.removeMember(FakeHouseholdRepository.demoHouseholdId, 'noa');
        expect((await repo.myHouseholds()).single.members, hasLength(2));
      },
    );

    test(
      'a code joins once, as a carer; expired and used codes say why',
      () async {
        expect((await repo.preview('maya-2345')).status, InviteStatus.open);
        expect(
          (await repo.preview(FakeHouseholdRepository.demoExpiredCode)).status,
          InviteStatus.expired,
        );
        expect(
          (await repo.preview(FakeHouseholdRepository.demoUsedCode)).status,
          InviteStatus.used,
        );
        expect((await repo.preview('ZZZZ9999')).status, InviteStatus.notFound);
        final id = await repo.accept(FakeHouseholdRepository.demoJoinCode);
        final maya = (await repo.myHouseholds()).firstWhere((h) => h.id == id);
        expect(maya.myRole, HouseholdRole.carer);
        expect(maya.owner?.name, 'Maya');
        await expectLater(
          repo.accept(FakeHouseholdRepository.demoJoinCode),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.alreadyMember,
            ),
          ),
        );
        await expectLater(
          repo.removeMember(id, 'maya'),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.ownerOnly,
            ),
          ),
        );
        await repo.leave(id);
        expect(await repo.myHouseholds(), hasLength(1));
      },
    );

    test(
      'ten people at most, open invitations included; ten codes a day',
      () async {
        final id = FakeHouseholdRepository.demoHouseholdId;
        // Alex, Dana, Noa and one open invitation: six more places.
        for (var i = 0; i < 6; i++) {
          await repo.createInvite(id);
        }
        await expectLater(
          repo.createInvite(id),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.full,
            ),
          ),
        );
        final solo = demoHouseholds(shared: false);
        for (var i = 0; i < 10; i++) {
          await solo.revokeInvite((await solo.createInvite(id)).code);
        }
        await expectLater(
          solo.createInvite(id),
          throwsA(
            isA<HouseholdException>().having(
              (e) => e.failure,
              'failure',
              HouseholdFailure.rateLimited,
            ),
          ),
        );
      },
    );
  });
}
