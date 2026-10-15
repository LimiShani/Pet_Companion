import 'dart:math';

import 'household_models.dart';
import 'household_repository.dart';

/// [HouseholdRepository] in memory, with the rules of `0030_household.sql`:
/// any member invites, a code is for one person and seven days, up to ten
/// people, only the owner renames and removes, the owner never leaves.
///
/// The demo account (Alex) owns the household of the sample pets, Kelly
/// and Soya, shared with Dana and Noa, with one invitation still open.
/// Other codes for trying the join page: [demoJoinCode] (Maya's household,
/// open), [demoExpiredCode] and [demoUsedCode].
class FakeHouseholdRepository implements HouseholdRepository {
  FakeHouseholdRepository({
    required String Function() viewerId,
    required String Function() viewerName,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 300),
    bool shared = true,
    Random? random,
  }) : _viewerId = viewerId,
       _viewerName = viewerName,
       _now = now ?? DateTime.now,
       _random = random ?? Random() {
    _seed(shared);
  }

  final String Function() _viewerId;
  final String Function() _viewerName;
  final DateTime Function() _now;
  final Random _random;
  final Duration latency;

  static const demoHouseholdId = 'household-demo';
  static const demoInviteCode = 'KELY7Q4M';
  static const demoJoinCode = 'MAYA2345';
  static const demoExpiredCode = 'XPRD2345';
  static const demoUsedCode = 'USED2345';

  final _households = <String, _House>{};
  final _invites = <String, _Invite>{};
  final _names = <String, String>{};

  void _seed(bool shared) {
    final now = _now();
    final me = _viewerId();
    _names
      ..[me] = _viewerName()
      ..['dana'] = 'Dana'
      ..['noa'] = 'Noa'
      ..['maya'] = 'Maya';
    _households[demoHouseholdId] = _House(
      id: demoHouseholdId,
      ownerId: me,
      members: {
        me: (HouseholdRole.owner, now.subtract(const Duration(days: 300))),
        if (shared) ...{
          'dana': (
            HouseholdRole.carer,
            now.subtract(const Duration(days: 220)),
          ),
          'noa': (HouseholdRole.carer, now.subtract(const Duration(days: 213))),
        },
      },
      pets: const [
        HouseholdPet(id: 'kelly', name: 'Kelly'),
        HouseholdPet(id: 'soya', name: 'Soya'),
      ],
    );
    if (shared) {
      _invites[demoInviteCode] = _Invite(
        code: demoInviteCode,
        householdId: demoHouseholdId,
        createdBy: me,
        createdAt: now.subtract(const Duration(days: 2)),
      );
    }
    _households['household-maya'] = _House(
      id: 'household-maya',
      ownerId: 'maya',
      members: {
        'maya': (HouseholdRole.owner, now.subtract(const Duration(days: 90))),
      },
      pets: const [HouseholdPet(id: 'bamba', name: 'Bamba')],
    );
    _invites[demoJoinCode] = _Invite(
      code: demoJoinCode,
      householdId: 'household-maya',
      createdBy: 'maya',
      createdAt: now.subtract(const Duration(days: 1)),
    );
    _invites[demoExpiredCode] = _Invite(
      code: demoExpiredCode,
      householdId: 'household-maya',
      createdBy: 'maya',
      createdAt: now.subtract(const Duration(days: 9)),
    );
    _invites[demoUsedCode] = _Invite(
      code: demoUsedCode,
      householdId: 'household-maya',
      createdBy: 'maya',
      createdAt: now.subtract(const Duration(days: 3)),
    )..acceptedBy = 'someone';
  }

  Future<void> _wait() => latency == Duration.zero
      ? Future<void>.value()
      : Future<void>.delayed(latency);

  String get _me => _viewerId();

  HouseholdRole? _roleIn(String householdId, String user) =>
      _households[householdId]?.members[user]?.$1;

  bool _isOpen(_Invite invite) =>
      invite.acceptedBy == null &&
      !invite.revoked &&
      invite.expiresAt.isAfter(_now());

  int _placesLeft(String householdId) {
    final house = _households[householdId]!;
    final open = _invites.values
        .where((i) => i.householdId == householdId && _isOpen(i))
        .length;
    return Household.maxPeople - house.members.length - open;
  }

  Household _view(_House house) => Household(
    id: house.id,
    name: house.name,
    ownerId: house.ownerId,
    myRole: _roleIn(house.id, _me) ?? HouseholdRole.carer,
    members: [
      for (final entry
          in house.members.entries.toList()..sort((a, b) {
            if (a.value.$1 != b.value.$1) {
              return a.value.$1 == HouseholdRole.owner ? -1 : 1;
            }
            return a.value.$2.compareTo(b.value.$2);
          }))
        HouseholdMember(
          userId: entry.key,
          name: _names[entry.key] ?? '',
          role: entry.value.$1,
          joinedAt: entry.value.$2,
        ),
    ],
    invites: [
      for (final invite in _invites.values)
        if (invite.householdId == house.id && _isOpen(invite))
          HouseholdInvite(
            code: invite.code,
            createdBy: invite.createdBy,
            createdByName: _names[invite.createdBy] ?? '',
            createdAt: invite.createdAt,
            expiresAt: invite.expiresAt,
          ),
    ],
    pets: house.pets,
  );

  @override
  Future<List<Household>> myHouseholds() async {
    await _wait();
    final mine =
        [
          for (final house in _households.values)
            if (house.members.containsKey(_me)) house,
        ]..sort(
          (a, b) =>
              (a.ownerId == _me ? 0 : 1).compareTo(b.ownerId == _me ? 0 : 1),
        );
    return [for (final house in mine) _view(house)];
  }

  @override
  Future<NewInvite> createInvite(String householdId) async {
    await _wait();
    if (_roleIn(householdId, _me) == null) {
      throw const HouseholdException(HouseholdFailure.notMember);
    }
    final today = _invites.values
        .where(
          (i) =>
              i.createdBy == _me &&
              _now().difference(i.createdAt) < const Duration(days: 1),
        )
        .length;
    if (today >= 10) {
      throw const HouseholdException(HouseholdFailure.rateLimited);
    }
    if (_placesLeft(householdId) <= 0) {
      throw const HouseholdException(HouseholdFailure.full);
    }
    String code;
    do {
      code = String.fromCharCodes([
        for (var i = 0; i < 8; i++)
          inviteAlphabet.codeUnitAt(_random.nextInt(inviteAlphabet.length)),
      ]);
    } while (_invites.containsKey(code));
    final invite = _Invite(
      code: code,
      householdId: householdId,
      createdBy: _me,
      createdAt: _now(),
    );
    _invites[code] = invite;
    return NewInvite(code: code, expiresAt: invite.expiresAt);
  }

  @override
  Future<void> revokeInvite(String code) async {
    await _wait();
    final invite = _invites[normalInviteCode(code)];
    if (invite == null || _roleIn(invite.householdId, _me) == null) {
      throw const HouseholdException(HouseholdFailure.inviteNotFound);
    }
    if (invite.acceptedBy == null) invite.revoked = true;
  }

  InvitePreview _preview(String code) {
    final invite = _invites[normalInviteCode(code)];
    if (invite == null) {
      return const InvitePreview(status: InviteStatus.notFound);
    }
    final house = _households[invite.householdId]!;
    return InvitePreview(
      status: house.members.containsKey(_me)
          ? InviteStatus.member
          : invite.revoked
          ? InviteStatus.revoked
          : invite.acceptedBy != null
          ? InviteStatus.used
          : !invite.expiresAt.isAfter(_now())
          ? InviteStatus.expired
          : InviteStatus.open,
      code: invite.code,
      householdId: house.id,
      householdName: house.name,
      inviterName: _names[invite.createdBy] ?? '',
      memberCount: house.members.length,
      pets: house.pets,
    );
  }

  @override
  Future<InvitePreview> preview(String code) async {
    await _wait();
    return _preview(code);
  }

  @override
  Future<String> accept(String code) async {
    await _wait();
    final preview = _preview(code);
    switch (preview.status) {
      case InviteStatus.notFound:
        throw const HouseholdException(HouseholdFailure.inviteNotFound);
      case InviteStatus.member:
        throw const HouseholdException(HouseholdFailure.alreadyMember);
      case InviteStatus.used || InviteStatus.revoked:
        throw const HouseholdException(HouseholdFailure.inviteUsed);
      case InviteStatus.expired:
        throw const HouseholdException(HouseholdFailure.inviteExpired);
      case InviteStatus.open:
        break;
    }
    final invite = _invites[preview.code]!..acceptedBy = _me;
    _households[invite.householdId]!.members[_me] = (
      HouseholdRole.carer,
      _now(),
    );
    return invite.householdId;
  }

  @override
  Future<void> removeMember(String householdId, String userId) async {
    await _wait();
    if (_roleIn(householdId, _me) != HouseholdRole.owner || userId == _me) {
      throw const HouseholdException(HouseholdFailure.ownerOnly);
    }
    if (_households[householdId]!.members.remove(userId) == null) {
      throw const HouseholdException(HouseholdFailure.notMember);
    }
  }

  @override
  Future<void> leave(String householdId) async {
    await _wait();
    final role = _roleIn(householdId, _me);
    if (role == null) {
      throw const HouseholdException(HouseholdFailure.notMember);
    }
    if (role == HouseholdRole.owner) {
      throw const HouseholdException(HouseholdFailure.ownerOnly);
    }
    _households[householdId]!.members.remove(_me);
  }

  @override
  Future<void> rename(String householdId, String name) async {
    await _wait();
    if (_roleIn(householdId, _me) != HouseholdRole.owner) {
      throw const HouseholdException(HouseholdFailure.ownerOnly);
    }
    final clean = name.trim();
    if (clean.length > 40) {
      throw const HouseholdException(HouseholdFailure.invalidName);
    }
    _households[householdId]!.name = clean;
  }
}

class _House {
  _House({
    required this.id,
    required this.ownerId,
    required this.members,
    required this.pets,
  });

  final String id;
  final String ownerId;
  String name = '';
  final Map<String, (HouseholdRole, DateTime)> members;
  final List<HouseholdPet> pets;
}

class _Invite {
  _Invite({
    required this.code,
    required this.householdId,
    required this.createdBy,
    required this.createdAt,
  }) : expiresAt = createdAt.add(const Duration(days: 7));

  final String code;
  final String householdId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  String? acceptedBy;
  bool revoked = false;
}
