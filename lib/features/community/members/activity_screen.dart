import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../theme/app_area.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../chat/private_chat_providers.dart';
import '../chat/private_chat_widgets.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/feed_controller.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/section_state.dart';
import 'members_providers.dart';

/// What happened to the member's posts and messages: invitations to a
/// private chat first, then comments, likes and answers, newest first.
/// Opening it clears the header's dot.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh each time the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(activityProvider);
      ref.invalidate(chatInvitationsProvider);
      ref
          .read(activitySeenProvider.notifier)
          .markSeen(ref.read(communityClockProvider)());
    });
  }

  Future<void> _open(ActivityItem item) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    if (item.kind == ActivityKind.reply) {
      router.push(CommunityRoutes.chat(item.targetId));
      return;
    }
    try {
      await ref.read(feedControllerProvider.notifier).open(item.targetId);
      router.push(CommunityRoutes.post(item.targetId));
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final now = ref.watch(communityClockProvider)();
    final activity = ref.watch(activityProvider);
    final list = activity.value;
    final invitations =
        ref.watch(chatInvitationsProvider).value ?? const <ChatInvitation>[];

    final Widget body;
    if (list == null) {
      body = activity.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SectionState(
              icon: Icons.cloud_off_rounded,
              title: l10n.activityLoadFailed,
              message: communityErrorText(context, activity.error),
              actionLabel: app.commonTryAgain,
              onAction: () => ref.invalidate(activityProvider),
            );
    } else if (list.isEmpty && invitations.isEmpty) {
      body = SectionState(
        icon: Icons.notifications_none_rounded,
        title: l10n.activityEmptyTitle,
        message: l10n.activityEmptyMessage,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activityProvider);
          await ref.read(activityProvider.future);
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            16,
            AppSpacing.screen,
            24,
          ),
          itemCount: list.length + (invitations.isEmpty ? 0 : 1),
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (invitations.isNotEmpty) {
              if (index == 0) return _Invitations(invitations: invitations);
              index -= 1;
            }
            final item = list[index];
            final name = l10n.inLine(l10n.memberName(item.actorName));
            final title = switch (item.kind) {
              ActivityKind.comment => l10n.activityComment(name),
              ActivityKind.like => l10n.activityLike(name),
              ActivityKind.reply => l10n.activityReply(name),
            };
            final icon = switch (item.kind) {
              ActivityKind.comment => Icons.chat_bubble_outline_rounded,
              ActivityKind.like => Icons.favorite_rounded,
              ActivityKind.reply => Icons.reply_rounded,
            };
            return Card(
              key: ValueKey('${item.kind.name}-${item.id}-${item.actorId}'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _open(item),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AuthorAvatar(
                            name: item.actorName,
                            authorId: item.actorId,
                            size: 36,
                          ),
                          PositionedDirectional(
                            end: -4,
                            bottom: -4,
                            // The Community area's disc, ringed in white
                            // so it stands off the avatar.
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppArea.community.disc,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: AppIcon(
                                icon,
                                size: 13,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              title,
                              style: AppText.secondary.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            if (item.preview.isNotEmpty)
                              AutoDirectionText(
                                item.preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.secondary.copyWith(
                                  color: AppColors.brown,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.relativeTime(app, format, item.at, now),
                              style: AppText.label.copyWith(
                                color: AppColors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.activityTitle, showBack: true),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The invitations to private chats waiting for the member.
class _Invitations extends StatelessWidget {
  const _Invitations({required this.invitations});

  final List<ChatInvitation> invitations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              context.communityL10n.invitationsTitle,
              style: AppText.label.copyWith(
                color: AppColors.brown,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        for (final invitation in invitations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ChatInvitationCard(invitation: invitation),
          ),
      ],
    );
  }
}
