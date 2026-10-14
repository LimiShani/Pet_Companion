import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../presentation/pets_widgets.dart';
import '../../services/household/data/household_models.dart';
import '../../services/household/state/household_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/primary_button.dart';
import 'household_words.dart';
import 'invite_sheet.dart';
import 'widgets/member_avatar.dart';

/// Whether a member's row opens a sheet: the owner may remove a carer; a
/// carer may leave. Nobody acts on the owner's row.
bool memberHasActions(Household household, HouseholdMember member, String? me) {
  if (member.isOwner) return false;
  return household.amOwner || member.userId == me;
}

/// A member's sheet: their name and role, and "Remove from the household"
/// (the owner, for a carer) or "Leave this household" (a carer, for
/// themself). Each asks first.
Future<void> showMemberSheet(
  BuildContext context,
  Household household,
  HouseholdMember member,
) => showPetsSheet<void>(
  context,
  _MemberSheet(household: household, member: member),
);

/// An open invitation's sheet: share it again, or take it back.
Future<void> showInvitationSheet(
  BuildContext context,
  Household household,
  HouseholdInvite invitation,
) => showPetsSheet<void>(
  context,
  _InvitationSheet(household: household, invitation: invitation),
);

/// The owner's sheet for the household's name.
Future<void> showRenameSheet(BuildContext context, Household household) =>
    showPetsSheet<void>(
      context,
      _RenameSheet(household: household),
      enableDrag: false,
    );

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Text(text, style: AppText.sectionTitle),
  );
}

class _MemberSheet extends ConsumerStatefulWidget {
  const _MemberSheet({required this.household, required this.member});

  final Household household;
  final HouseholdMember member;

  static const removeKey = Key('member-remove');
  static const leaveKey = Key('member-leave');

  @override
  ConsumerState<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends ConsumerState<_MemberSheet> {
  bool _busy = false;

  Future<void> _act({required bool leaving}) async {
    final l10n = context.householdL10n;
    final name = memberName(l10n, widget.member);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          leaving ? l10n.leaveConfirmTitle : l10n.removeConfirmTitle(name),
        ),
        content: Text(
          leaving ? l10n.leaveConfirmBody : l10n.removeConfirmBody(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('member-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(leaving ? l10n.leaveAction : l10n.removeAction),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final households = ref.read(householdsProvider.notifier);
      if (leaving) {
        await households.leave(widget.household.id);
      } else {
        await households.removeMember(
          widget.household.id,
          widget.member.userId,
        );
      }
      navigator.pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(leaving ? l10n.leftSnack : l10n.removedSnack(name)),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPetsSnack(context, householdErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    final member = widget.member;
    // The sheet opens for the owner on a carer's row (remove) and for a
    // carer on their own row (leave); see [memberHasActions].
    final mine = !widget.household.amOwner;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            MemberAvatar(member: member, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                memberName(l10n, member),
                style: AppText.sectionTitle,
              ),
            ),
            AppTag(roleName(l10n, member.role), tone: AppTagTone.sage),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          key: mine ? _MemberSheet.leaveKey : _MemberSheet.removeKey,
          onPressed: _busy ? null : () => _act(leaving: mine),
          icon: Icon(mine ? Icons.logout_rounded : Icons.person_remove_rounded),
          label: Text(mine ? l10n.leave : l10n.remove),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coralDark,
            side: const BorderSide(color: AppColors.coralDark, width: 1.5),
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
  }
}

class _InvitationSheet extends ConsumerStatefulWidget {
  const _InvitationSheet({required this.household, required this.invitation});

  final Household household;
  final HouseholdInvite invitation;

  static const takeBackKey = Key('invitation-take-back');

  @override
  ConsumerState<_InvitationSheet> createState() => _InvitationSheetState();
}

class _InvitationSheetState extends ConsumerState<_InvitationSheet> {
  bool _busy = false;

  Future<void> _takeBack() async {
    final l10n = context.householdL10n;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(householdsProvider.notifier)
          .revokeInvite(widget.invitation.code);
      navigator.pop();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.takenBackSnack)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPetsSnack(context, householdErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(l10n.openInvitation),
        InviteCodeBox(code: widget.invitation.code),
        const SizedBox(height: 16),
        PrimaryButton(
          label: l10n.inviteShare,
          onPressed: _busy
              ? null
              : () => shareInvitation(
                  context,
                  ref,
                  widget.household,
                  widget.invitation.code,
                ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: _InvitationSheet.takeBackKey,
          onPressed: _busy ? null : _takeBack,
          style: TextButton.styleFrom(foregroundColor: AppColors.coralDark),
          child: Text(l10n.takeBack),
        ),
      ],
    );
  }
}

class _RenameSheet extends ConsumerStatefulWidget {
  const _RenameSheet({required this.household});

  final Household household;

  static const fieldKey = Key('household-name-field');

  @override
  ConsumerState<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends ConsumerState<_RenameSheet> {
  late final _name = TextEditingController(text: widget.household.name);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.householdL10n;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(householdsProvider.notifier)
          .rename(widget.household.id, _name.text);
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showPetsSnack(context, householdErrorText(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(l10n.renameTitle),
        TextField(
          key: _RenameSheet.fieldKey,
          controller: _name,
          maxLength: 40,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: householdTitle(
              l10n,
              name: '',
              petNames: [for (final pet in widget.household.pets) pet.name],
              ownerName: widget.household.owner?.name ?? '',
            ),
          ),
          onSubmitted: (_) => _busy ? null : _save(),
        ),
        PetsFinePrint(l10n.renameHint),
        const SizedBox(height: 12),
        PrimaryButton(
          label: context.l10n.commonSave,
          loading: _busy,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}
