import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../access/access_provider.dart';
import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import 'safety_flows.dart';
import 'safety_providers.dart';

/// Community safety: the rules, the members the user blocked (with a way
/// to unblock them), and for moderators the way to the reports.
class CommunitySafetyScreen extends ConsumerWidget {
  const CommunitySafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final blocked = ref.watch(blockedMembersProvider);
    final moderator = ref.watch(capabilityProvider('community.moderate'));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.safetyTitle, showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                16,
                AppSpacing.screen,
                24,
              ),
              children: [
                Text(
                  l10n.safetyIntro,
                  style: AppText.body.copyWith(color: AppColors.brown),
                ),
                const SizedBox(height: 14),
                _LinkCard(
                  icon: Icons.rule_rounded,
                  title: l10n.rulesTitle,
                  onTap: () => showCommunityRules(context),
                ),
                if (moderator) ...[
                  const SizedBox(height: AppSpacing.cardGap),
                  const _ReviewCard(),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
                  child: Text(
                    l10n.blockedTitle,
                    style: AppText.label.copyWith(
                      color: AppColors.brown,
                      fontSize: 13,
                    ),
                  ),
                ),
                switch (blocked) {
                  AsyncData(:final value) when value.isEmpty => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.noBlocked,
                      style: AppText.body.copyWith(color: AppColors.brown),
                    ),
                  ),
                  AsyncData(:final value) => Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          for (var i = 0; i < value.length; i++) ...[
                            if (i > 0) const Divider(indent: 16, endIndent: 16),
                            _BlockedRow(member: value[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AsyncError(:final error) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.blockedLoadFailed,
                            style: AppText.body.copyWith(
                              color: AppColors.brown,
                            ),
                          ),
                          Text(
                            communityErrorText(context, error),
                            style: AppText.body.copyWith(
                              color: AppColors.brown,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(blockedMembersProvider),
                            child: Text(context.l10n.commonTryAgain),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final waiting = ref.watch(moderationQueueProvider).value?.length;
    return _LinkCard(
      icon: Icons.fact_check_outlined,
      title: l10n.reviewReports,
      subtitle: waiting == null ? null : l10n.reviewWaiting(waiting),
      highlight: (waiting ?? 0) > 0,
      onTap: () => context.go(CommunityRoutes.review),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIcon(icon, color: AppColors.coralDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.cardTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: AppText.secondary.copyWith(
                          color: highlight
                              ? AppColors.coralDark
                              : AppColors.brown,
                          fontWeight: highlight ? FontWeight.w800 : null,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Mirrors itself in a right-to-left layout.
              const AppIcon(
                Icons.chevron_right_rounded,
                color: AppColors.brown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedRow extends ConsumerWidget {
  const _BlockedRow({required this.member});

  final BlockedMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          AuthorAvatar(name: member.name, authorId: member.id, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: AutoDirectionText(
              l10n.memberName(member.name),
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final errorWords = communityErrorWords(context);
              final done = l10n.unblockedDone(
                l10n.inLine(l10n.memberName(member.name)),
              );
              try {
                await ref
                    .read(blockedMembersProvider.notifier)
                    .unblock(member.id);
                showCommunitySnack(messenger, done);
              } catch (e) {
                showCommunitySnack(messenger, errorWords(e));
              }
            },
            child: Text(l10n.unblock),
          ),
        ],
      ),
    );
  }
}
