import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/primary_button.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import 'safety_providers.dart';

/// Asks why something is being reported. `null` when the sheet was closed.
Future<ReportReason?> askReportReason(
  BuildContext context, {
  required String title,
  required String body,
}) => showModalBottomSheet<ReportReason>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (context) => ReportReasonSheet(title: title, body: body),
);

/// Confirms, then blocks a member. Returns whether they were blocked.
Future<bool> blockMemberFlow(
  BuildContext context,
  WidgetRef ref, {
  required String memberId,
  required String memberName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.communityL10n;
  final app = context.l10n;
  final errorWords = communityErrorWords(context);
  final shown = l10n.inLine(l10n.memberName(memberName));

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.blockTitle(shown)),
      content: Text(l10n.blockBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(app.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.blockConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  try {
    await ref
        .read(blockedMembersProvider.notifier)
        .block(BlockedMember(id: memberId, name: memberName));
    showCommunitySnack(messenger, l10n.blockedDone(shown));
    return true;
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
    return false;
  }
}

/// Shows the community rules once per member on this phone, before their
/// first post, comment or message. Returns whether they agreed (at once,
/// when they already had).
Future<bool> ensureCommunityRules(BuildContext context, WidgetRef ref) async {
  if (ref.read(communityRulesProvider)) return true;
  final agreed = await showCommunityRules(context, asking: true);
  if (agreed != true) return false;
  await ref.read(communityRulesProvider.notifier).accept();
  return true;
}

/// The rules sheet. [asking] adds the "Agree and continue" button.
Future<bool?> showCommunityRules(BuildContext context, {bool asking = false}) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => _RulesSheet(asking: asking),
    );

class _RulesSheet extends StatelessWidget {
  const _RulesSheet({required this.asking});

  final bool asking;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final rules = [l10n.rule1, l10n.rule2, l10n.rule3, l10n.rule4, l10n.rule5];
    const icons = [
      Icons.favorite_outline_rounded,
      Icons.block_rounded,
      Icons.medical_services_outlined,
      Icons.lock_outline_rounded,
      Icons.flag_outlined,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rulesTitle,
              style: AppText.cardTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.rulesIntro,
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < rules.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(icons[i], size: 20, color: AppColors.coralDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        rules[i],
                        style: AppText.body.copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            if (asking) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: l10n.rulesAgree,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A list of report reasons under a title, as a bottom sheet's content.
class ReportReasonSheet extends StatelessWidget {
  const ReportReasonSheet({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final radius = BorderRadius.circular(AppSpacing.fieldRadius);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppText.cardTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(body, style: AppText.body.copyWith(color: AppColors.brown)),
            const SizedBox(height: 12),
            for (final reason in ReportReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.white,
                  borderRadius: radius,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: () => Navigator.of(context).pop(reason),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.reportReason(reason),
                              style: AppText.body.copyWith(fontSize: 15),
                            ),
                          ),
                          // Mirrors itself in a right-to-left layout.
                          const AppIcon(
                            Icons.chevron_right_rounded,
                            color: AppColors.brown,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
