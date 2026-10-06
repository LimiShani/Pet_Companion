import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../../../services/community/data/audience.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/icon_disc.dart';
import '../widgets/scope_bar.dart';
import '../widgets/small_tag.dart';
import '../widgets/section_state.dart';
import '../members/members_providers.dart';
import '../safety/safety_providers.dart';
import 'chat_providers.dart';

/// The Chat section of the Community tab: the topic rooms for the chosen
/// animal (or for everything).
class ChatSection extends ConsumerWidget {
  const ChatSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final channels = ref.watch(chatChannelsProvider);
    final scope = ref.watch(communityScopeProvider);
    final list = channels.value;

    if (list == null) {
      if (channels.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.roomsLoadFailed,
        message: communityErrorText(context, channels.error),
        actionLabel: context.l10n.commonTryAgain,
        onAction: () => ref.invalidate(chatChannelsProvider),
      );
    }

    if (list.isEmpty) {
      return SectionState(
        icon: Icons.forum_rounded,
        title: l10n.noRoomsTitle,
        message: l10n.noRoomsMessage,
      );
    }

    final muted = ref.watch(mutedRoomsProvider);
    final blocked = ref.watch(blockedIdsProvider);
    // A room whose latest message is a blocked member's shows its
    // description instead (the server leaves such messages out already).
    final summaries = {
      for (final entry
          in (ref.watch(chatRoomSummariesProvider).value ??
                  const <String, ChatRoomSummary>{})
              .entries)
        if (!blocked.contains(entry.value.lastAuthorId)) entry.key: entry.value,
    };
    // The liveliest rooms first; rooms without messages keep their order
    // after them.
    final visible =
        [
          for (final (index, channel) in list.indexed)
            if (scope.shows(channel.audience)) (index, channel),
        ]..sort((a, b) {
          final at = summaries[a.$2.id]?.lastMessageAt;
          final bt = summaries[b.$2.id]?.lastMessageAt;
          if (at != null && bt != null && at != bt) return bt.compareTo(at);
          if (at != null && bt == null) return -1;
          if (at == null && bt != null) return 1;
          return a.$1.compareTo(b.$1);
        });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(chatRoomSummariesProvider);
        await ref.read(chatRoomSummariesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        children: [
          const ScopeBar(what: ScopeBarSubject.rooms),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen + 4,
                vertical: 8,
              ),
              child: Text(
                l10n.noRoomsFor(scope),
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
            ),
          for (final (_, channel) in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.cardGap,
              ),
              child: _ChannelCard(
                channel: channel,
                summary: summaries[channel.id],
                muted: muted.contains(channel.id),
                // Under Everything each room says which animal it is for.
                tag: scope == CommunityScope.everything
                    ? SmallTag.forAudience(l10n, channel.audience)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.channel,
    this.summary,
    this.tag,
    this.muted = false,
  });

  final ChatChannel channel;

  /// Muted on this phone: no unread count.
  final bool muted;

  /// The latest message and the unread count; `null` for a room without
  /// messages, or while they load.
  final ChatRoomSummary? summary;
  final Widget? tag;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final now = ref.watch(communityClockProvider)();
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final summary = this.summary;
    final unread = muted ? 0 : summary?.unread ?? 0;
    final when = summary?.lastMessageAt;
    String? preview;
    if (summary != null) {
      final text = summary.lastHasPhoto && summary.lastText.isEmpty
          ? l10n.photoLabel
          : summary.lastText;
      // The text is someone's own words: kept as one unit in the line.
      preview = summary.lastAuthorId == viewerId
          ? l10n.roomLastMine(l10n.inLine(text))
          : l10n.roomLastOther(
              l10n.inLine(l10n.memberName(summary.lastAuthorName)),
              l10n.inLine(text),
            );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('room-${channel.id}'),
        onTap: () => context.go(CommunityRoutes.chat(channel.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconDisc(icon: chatChannelIcon(channel.id)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // A room the app does not know by id keeps its
                        // stored name, which reads in its own direction.
                        Expanded(
                          child: AutoDirectionText(
                            l10n.roomName(channel),
                            style: AppText.cardTitle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (when != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            isSameDay(when, now)
                                ? format.time(when)
                                : dayLabel(app, format, when, now),
                            style: AppText.label.copyWith(
                              color: unread > 0
                                  ? AppColors.coralDark
                                  : AppColors.brown,
                              fontWeight: unread > 0 ? FontWeight.w800 : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // The latest message once there is one; the room's
                    // description (also in the room's info) until then.
                    if (preview == null)
                      AutoDirectionText(
                        l10n.roomAbout(channel),
                        style: AppText.secondary.copyWith(
                          color: AppColors.brown,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.secondary.copyWith(
                                color: AppColors.ink,
                                fontWeight: unread > 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 8),
                            _UnreadBadge(count: unread),
                          ],
                          if (muted) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: l10n.mutedTag,
                              child: const AppIcon(
                                Icons.notifications_off_outlined,
                                size: 18,
                                color: AppColors.brown,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (tag != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: tag!,
                      ),
                    ],
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

/// How many messages arrived since the room was last read.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final shown = count > 99 ? '99+' : AppFormat.of(context).integer(count);
    return Semantics(
      label: context.communityL10n.roomUnread(count),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: const ShapeDecoration(
          color: AppColors.coralDark,
          shape: StadiumBorder(),
        ),
        child: Text(
          shown,
          maxLines: 1,
          softWrap: false,
          style: AppText.label.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
