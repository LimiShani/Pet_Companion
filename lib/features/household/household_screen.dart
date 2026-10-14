import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_provider.dart';
import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../presentation/pet_avatar.dart';
import '../../presentation/pet_words.dart';
import '../../presentation/pets_widgets.dart';
import '../../services/household/data/household_models.dart';
import '../../services/household/state/household_providers.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/petloop_icon.dart';
import '../../widgets/primary_button.dart';
import 'household_routes.dart';
import 'household_words.dart';
import 'invite_sheet.dart';
import 'member_sheet.dart';
import 'widgets/member_avatar.dart';

/// The Household page (`/household`), from the You page: the people of the
/// account's household (the owner first, then the carers and the open
/// invitations), its pets, "Invite someone", and "I have an invitation
/// code". An account in several households sees each in turn.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  static const screenKey = Key('household-screen');
  static const inviteKey = Key('household-invite');
  static const haveCodeKey = Key('household-have-code');
  static const renameKey = Key('household-rename');
  static Key memberKey(String userId) => Key('household-member-$userId');
  static Key inviteRowKey(String code) => Key('household-invite-$code');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.householdL10n;
    final shown = ref.watch(shownHouseholdsProvider);
    final households = shown.value;

    if (households == null || households.isEmpty) {
      return PetsPage(
        key: screenKey,
        title: l10n.title,
        child: shown.hasError || (households != null && households.isEmpty)
            ? EmptyState(
                icon: Icons.home_rounded,
                title: l10n.loadFailed,
                message: householdErrorText(l10n, shown.error ?? ''),
                actionLabel: context.l10n.commonTryAgain,
                onAction: () => ref.read(householdsProvider.notifier).refresh(),
              )
            : const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
      );
    }

    final single = households.length == 1 ? households.first : null;
    return PetsPage(
      key: screenKey,
      // A pet-named title ("Kelly & Soya's household") does not fit beside
      // the arrow and the pencil at 320 px: it goes under "Household".
      title: l10n.title,
      actions: [
        if (single != null && single.amOwner)
          CoralHeaderAction(
            key: renameKey,
            icon: Icons.edit_rounded,
            tooltip: l10n.rename,
            onPressed: () => showRenameSheet(context, single),
          ),
      ],
      headerBottom: single == null ? null : _HeaderCounts(household: single),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, household) in households.indexed) ...[
            if (single == null) ...[
              if (i > 0) const SizedBox(height: 28),
              _HouseholdHeading(household: household),
            ],
            _HouseholdBody(household: household, onlyOne: single != null),
          ],
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              key: haveCodeKey,
              onPressed: () => openJoinHousehold(context),
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(l10n.haveCode),
            ),
          ),
        ],
      ),
    );
  }
}

/// Under "Household" on the coral: the household's name, and "3 people ·
/// 2 pets".
class _HeaderCounts extends StatelessWidget {
  const _HeaderCounts({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            householdName(l10n, household),
            style: AppText.sectionTitle.copyWith(color: AppColors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${l10n.peopleCount(household.members.length)} · '
            '${l10n.petsCount(household.pets.length)}',
            style: AppText.secondary.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A household's name above its sections, when the page shows several.
class _HouseholdHeading extends StatelessWidget {
  const _HouseholdHeading({required this.household});

  final Household household;

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            householdName(l10n, household),
            style: AppText.sectionTitle,
          ),
        ),
        if (household.amOwner)
          IconButton(
            tooltip: l10n.rename,
            onPressed: () => showRenameSheet(context, household),
            icon: const Icon(Icons.edit_rounded, color: AppColors.brown),
          ),
      ],
    );
  }
}

class _HouseholdBody extends ConsumerWidget {
  const _HouseholdBody({required this.household, required this.onlyOne});

  final Household household;

  /// The page shows this household alone: "Invite someone" is its one
  /// filled button.
  final bool onlyOne;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.householdL10n;
    final me = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final canInvite =
        ref.watch(capabilityProvider(HouseholdCapabilities.manage)) &&
        household.placesLeft > 0;
    final now = ref.watch(householdClockProvider)();
    final format = AppFormat.of(context);
    final store = ref.watch(petsStoreProvider);

    void invite() => showInviteSheet(context, household);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PetsLabel(l10n.sectionPeople, topGap: onlyOne ? 0 : 10),
        for (final member in household.members) ...[
          PetsRow(
            key: HouseholdScreen.memberKey(member.userId),
            leading: MemberAvatar(member: member),
            title: memberName(l10n, member),
            subtitle: member.userId == me
                ? l10n.you
                : l10n.joinedOn(format.date(member.joinedAt)),
            trailing: AppTag(
              roleName(l10n, member.role),
              tone: member.isOwner ? AppTagTone.yellow : AppTagTone.sage,
            ),
            onTap: memberHasActions(household, member, me)
                ? () => showMemberSheet(context, household, member)
                : null,
          ),
          const SizedBox(height: 8),
        ],
        for (final invitation in household.invites) ...[
          PetsRow(
            key: HouseholdScreen.inviteRowKey(invitation.code),
            dashed: true,
            leading: const _InviteDisc(),
            title: l10n.openInvitation,
            // The code reads left to right in a Hebrew line too.
            subtitle: [
              isolate(formatInviteCode(invitation.code)),
              if (invitation.createdByName.trim().isNotEmpty)
                l10n.invitedBy(invitation.createdByName.trim()),
              l10n.daysLeft(invitation.daysLeft(now)),
            ].join(' · '),
            trailing: AppTag(l10n.invitedTag),
            onTap: () => showInvitationSheet(context, household, invitation),
          ),
          const SizedBox(height: 8),
        ],
        if (household.isJustMe) ...[
          const SizedBox(height: 4),
          PetsFinePrint(l10n.soloLine),
        ],
        if (canInvite) ...[
          const SizedBox(height: 12),
          if (onlyOne)
            PrimaryButton(
              key: HouseholdScreen.inviteKey,
              label: l10n.inviteSomeone,
              onPressed: invite,
            )
          else
            PetsRow(
              key: HouseholdScreen.inviteKey,
              dashed: true,
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: l10n.inviteSomeone,
              onTap: invite,
            ),
        ],
        PetsLabel(l10n.sectionPets),
        if (household.pets.isEmpty) PetsFinePrint(l10n.petsEmpty),
        for (final pet in household.pets) ...[
          PetsRow(
            leading: switch (store.byId(pet.id)) {
              final known? => PetAvatar(pet: known, size: 40),
              null => const _PetDisc(),
            },
            title: pet.name,
            subtitle: petSpeciesText(context.petsL10n, pet.species),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _InviteDisc extends StatelessWidget {
  const _InviteDisc();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: AppColors.cream,
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.mail_outline_rounded, color: AppColors.brown),
  );
}

class _PetDisc extends StatelessWidget {
  const _PetDisc();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: AppColors.yellow,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: const PetLoopIcon(PetLoopGlyph.pet, size: 22, color: AppColors.ink),
  );
}
