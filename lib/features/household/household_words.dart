import '../../l10n/l10n.dart';
import '../../services/household/data/household_models.dart';

/// The household's name as people read it: the owner's name for it, else
/// after its pets ("Kelly & Soya's household"), else after its owner.
String householdTitle(
  HouseholdL10n l10n, {
  required String name,
  required List<String> petNames,
  String ownerName = '',
}) {
  final own = name.trim();
  if (own.isNotEmpty) return own;
  final pets = [
    for (final pet in petNames)
      if (pet.trim().isNotEmpty) pet.trim(),
  ];
  if (pets.length == 1) return l10n.nameOnePet(pets.first);
  if (pets.length == 2) return l10n.nameTwoPets(pets[0], pets[1]);
  final owner = ownerName.trim();
  return owner.isEmpty ? l10n.nameOurs : l10n.nameOfPerson(owner);
}

String householdName(HouseholdL10n l10n, Household household) => householdTitle(
  l10n,
  name: household.name,
  petNames: [for (final pet in household.pets) pet.name],
  ownerName: household.owner?.name ?? '',
);

String previewName(HouseholdL10n l10n, InvitePreview preview) => householdTitle(
  l10n,
  name: preview.householdName,
  petNames: [for (final pet in preview.pets) pet.name],
  ownerName: preview.inviterName,
);

String roleName(HouseholdL10n l10n, HouseholdRole role) => switch (role) {
  HouseholdRole.owner => l10n.roleOwner,
  HouseholdRole.carer => l10n.roleCarer,
};

/// A member's name, never blank.
String memberName(HouseholdL10n l10n, HouseholdMember member) =>
    member.name.trim().isEmpty ? '?' : member.name.trim();

/// "Dana, Noa": the names of [members], in the order given.
String namesOf(HouseholdL10n l10n, List<HouseholdMember> members) =>
    [for (final m in members) memberName(l10n, m)].join(', ');

/// What a failed household call says.
String householdErrorText(HouseholdL10n l10n, Object error) {
  final failure = error is HouseholdException
      ? error.failure
      : HouseholdFailure.offline;
  return switch (failure) {
    HouseholdFailure.inviteNotFound => l10n.errNotFound,
    HouseholdFailure.inviteExpired => l10n.errExpired,
    HouseholdFailure.inviteUsed => l10n.errUsed,
    HouseholdFailure.alreadyMember => l10n.errMember,
    HouseholdFailure.full => l10n.errFull,
    HouseholdFailure.rateLimited => l10n.errSlowDown,
    HouseholdFailure.notAvailable ||
    HouseholdFailure.signIn => l10n.errNotAvailable,
    HouseholdFailure.ownerOnly ||
    HouseholdFailure.notMember => l10n.errOwnerOnly,
    HouseholdFailure.invalidName => l10n.errName,
    HouseholdFailure.offline => l10n.errOffline,
  };
}
