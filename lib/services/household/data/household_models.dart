import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../models/pet.dart';

/// What a member may do in a household (`0030_household.sql`): the owner
/// of its pets, or a carer who looks after them.
enum HouseholdRole {
  owner,
  carer;

  static HouseholdRole fromDb(Object? value) =>
      value == 'owner' ? HouseholdRole.owner : HouseholdRole.carer;
}

/// One person of a household.
class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.joinedAt,
  });

  final String userId;

  /// Their display name; may be empty for an account that never set one.
  final String name;
  final HouseholdRole role;
  final DateTime joinedAt;

  bool get isOwner => role == HouseholdRole.owner;

  /// The letter on their avatar.
  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}

/// An invitation nobody used yet: a code for one person, for seven days.
class HouseholdInvite {
  const HouseholdInvite({
    required this.code,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
  });

  final String code;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// Whole days until it ends, never below zero.
  int daysLeft(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? 0 : left.inDays;
  }
}

/// A pet of a household, as the household page lists it.
class HouseholdPet {
  const HouseholdPet({
    required this.id,
    required this.name,
    this.species = PetSpecies.dog,
    this.iconKey,
  });

  final String id;
  final String name;
  final PetSpecies species;
  final String? iconKey;
}

/// The people of one home and the pets they share.
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.myRole,
    required this.members,
    this.invites = const [],
    this.pets = const [],
  });

  final String id;

  /// The owner's name for it; empty means "named after its pets".
  final String name;
  final String ownerId;
  final HouseholdRole myRole;

  /// The owner first, then by when they joined.
  final List<HouseholdMember> members;

  /// The invitations still open.
  final List<HouseholdInvite> invites;
  final List<HouseholdPet> pets;

  bool get amOwner => myRole == HouseholdRole.owner;

  HouseholdMember? get owner {
    for (final member in members) {
      if (member.isOwner) return member;
    }
    return null;
  }

  /// Nobody else is in it or invited to it.
  bool get isJustMe => members.length <= 1 && invites.isEmpty;

  /// The other members, as seen by [me].
  List<HouseholdMember> othersThan(String? me) => [
    for (final member in members)
      if (member.userId != me) member,
  ];

  /// Up to 10 people, open invitations included.
  static const maxPeople = 10;

  int get placesLeft => maxPeople - members.length - invites.length;
}

/// What an invitation code leads to.
enum InviteStatus {
  open,
  member,
  used,
  revoked,
  expired,
  notFound;

  static InviteStatus fromDb(Object? value) => switch (value) {
    'open' => InviteStatus.open,
    'member' => InviteStatus.member,
    'used' => InviteStatus.used,
    'revoked' => InviteStatus.revoked,
    'expired' => InviteStatus.expired,
    _ => InviteStatus.notFound,
  };
}

/// An invitation before joining: the household's name, who invited, its
/// pets and how many people. Nothing else of the household.
class InvitePreview {
  const InvitePreview({
    required this.status,
    this.code = '',
    this.householdId = '',
    this.householdName = '',
    this.inviterName = '',
    this.memberCount = 0,
    this.pets = const [],
  });

  final InviteStatus status;
  final String code;
  final String householdId;
  final String householdName;
  final String inviterName;
  final int memberCount;
  final List<HouseholdPet> pets;
}

/// A code just made.
class NewInvite {
  const NewInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Why a household call failed; the server names these words.
enum HouseholdFailure {
  signIn,
  notAvailable,
  notMember,
  ownerOnly,
  inviteNotFound,
  inviteExpired,
  inviteUsed,
  alreadyMember,
  full,
  rateLimited,
  invalidName,
  offline;

  /// The failure a refusal of 0030's functions names.
  static HouseholdFailure fromMessage(String message) {
    final text = message.toLowerCase();
    for (final (word, failure) in const [
      ('sign_in', HouseholdFailure.signIn),
      ('not_available', HouseholdFailure.notAvailable),
      ('not_member', HouseholdFailure.notMember),
      ('owner_only', HouseholdFailure.ownerOnly),
      ('invite_not_found', HouseholdFailure.inviteNotFound),
      ('invite_expired', HouseholdFailure.inviteExpired),
      ('invite_used', HouseholdFailure.inviteUsed),
      ('already_member', HouseholdFailure.alreadyMember),
      ('household_full', HouseholdFailure.full),
      ('rate_limited', HouseholdFailure.rateLimited),
      ('invalid_name', HouseholdFailure.invalidName),
    ]) {
      if (text.contains(word)) return failure;
    }
    return HouseholdFailure.offline;
  }
}

class HouseholdException implements Exception {
  const HouseholdException(this.failure);

  final HouseholdFailure failure;

  @override
  String toString() => 'HouseholdException(${failure.name})';
}

/// The letters a code is made of: no 0/O, 1/I.
const inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// A code as typed: any case, spaces and dashes dropped.
String normalInviteCode(String typed) =>
    typed.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Whether [typed] can be a code (8 letters and digits of [inviteAlphabet]).
bool looksLikeInviteCode(String typed) {
  final code = normalInviteCode(typed);
  return code.length == 8 && code.split('').every(inviteAlphabet.contains);
}

/// A code as shown and read aloud: KELY-7Q4M.
String formatInviteCode(String code) =>
    code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

/// The link that opens the join page.
String inviteLink(String code) => 'https://petloop.app/join/$code';
