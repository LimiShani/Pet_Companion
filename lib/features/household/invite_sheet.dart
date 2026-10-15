import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/l10n.dart';
import '../../presentation/pets_widgets.dart';
import '../../services/household/data/household_models.dart';
import '../../services/household/state/household_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'household_words.dart';

/// Hands text to the phone's share sheet. Tests replace it.
final householdShareProvider = Provider<Future<void> Function(String text)>(
  (ref) => (text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  },
);

/// Shares the invitation [code] to [household], usually over WhatsApp.
Future<void> shareInvitation(
  BuildContext context,
  WidgetRef ref,
  Household household,
  String code,
) {
  final l10n = context.householdL10n;
  return ref.read(householdShareProvider)(
    l10n.inviteShareText(
      householdName(l10n, household),
      inviteLink(code),
      formatInviteCode(code),
    ),
  );
}

/// "Invite someone": what joining allows, a code (the account's open one
/// when it has a day left, else a new one), Copy and Share.
Future<void> showInviteSheet(BuildContext context, Household household) =>
    showPetsSheet<void>(context, InviteSheet(household: household));

class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.household});

  final Household household;

  static const shareKey = Key('invite-share');

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  late Future<HouseholdInvite> _invite = _make();

  Future<HouseholdInvite> _make() {
    final me = ref.read(authControllerProvider).value?.id ?? '';
    return ref
        .read(householdsProvider.notifier)
        .inviteFor(widget.household, me);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    return FutureBuilder<HouseholdInvite>(
      future: _invite,
      builder: (context, snapshot) {
        final invite = snapshot.data;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(l10n.inviteTitle, style: AppText.sectionTitle),
            ),
            const InviteAllows(),
            PetsLabel(l10n.inviteCodeLabel),
            if (snapshot.hasError) ...[
              Text(
                householdErrorText(l10n, snapshot.error!),
                style: AppText.body,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: context.l10n.commonTryAgain,
                onPressed: () => setState(() => _invite = _make()),
              ),
            ] else if (invite == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              InviteCodeBox(code: invite.code),
              const SizedBox(height: 6),
              PetsFinePrint(l10n.inviteValidity),
              const SizedBox(height: 14),
              PrimaryButton(
                key: InviteSheet.shareKey,
                label: l10n.inviteShare,
                onPressed: () => shareInvitation(
                  context,
                  ref,
                  widget.household,
                  invite.code,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Whoever joins can:" and its three lines.
class InviteAllows extends StatelessWidget {
  const InviteAllows({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.householdL10n;
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: AppColors.sage,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.body)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.inviteCanTitle,
          style: AppText.body.copyWith(fontWeight: FontWeight.w700),
        ),
        line(l10n.inviteCan1),
        line(l10n.inviteCan2),
        line(l10n.inviteCan3),
      ],
    );
  }
}

/// The code, large and spaced (KELY-7Q4M), with a Copy button.
class InviteCodeBox extends StatelessWidget {
  const InviteCodeBox({super.key, required this.code});

  final String code;

  static const copyKey = Key('invite-copy');

  Future<void> _copy(BuildContext context) async {
    final text = context.householdL10n.codeCopied;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: formatInviteCode(code)));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatInviteCode(code),
              // A code reads left to right on every screen.
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            key: copyKey,
            tooltip: context.householdL10n.copyCode,
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, color: AppColors.coralDark),
          ),
        ],
      ),
    );
  }
}
