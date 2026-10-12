import '../../../access/access_provider.dart';
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
import '../widgets/scope_menu_chip.dart';
import '../widgets/small_tag.dart';
import '../widgets/section_state.dart';
import '../members/members_providers.dart';
import '../safety/safety_providers.dart';
import 'chat_providers.dart';
import 'private_chat_providers.dart';
import 'private_chat_widgets.dart';

/// The Chat section of the Community tab: invitations and the member's
/// private chats ("My chats"), then the topic rooms for the chosen animal
/// (or for everything).
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
        onAction: () {
          ref.invalidate(chatChannelsProvider);
          ref.invalidate(privateChatsProvider);
          ref.invalidate(chatInvitationsProvider);
        },
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

    final private = ref.watch(capabilityProvider(privateChatCapability));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(chatRoomSummariesProvider);
        ref.invalidate(privateChatsProvider);
        ref.invalidate(chatInvitationsProvider);
        await ref.read(chatRoomSummariesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Room under the last card for the "New chat" button.
        padding: EdgeInsets.only(top: 16, bottom: private ? 88 : 24),
        children: [
          if (private) const _PrivateChats(),
          // The animal menu filters only the topic rooms, so it sits on
          // their heading's line, below the member's own chats.
          _RoomsHeading(l10n.topicRooms),
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
                    ? tagForAudience(l10n, channel.audience)
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
                            style: AppText.rowTitle,
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

/// A heading above a part of the Chat section.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screen + 4,
      4,
      AppSpacing.screen + 4,
      8,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: AppText.label.copyWith(
          color: AppColors.brown,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// The "Topic rooms" heading, with the animal menu at the end of its line.
class _RoomsHeading extends StatelessWidget {
  const _RoomsHeading(this.text);

  final String text;

  static const rowKey = Key('rooms-heading');

  @override
  Widget build(BuildContext context) => Padding(
    key: rowKey,
    padding: const EdgeInsetsDirectional.fromSTEB(
      AppSpacing.screen + 4,
      0,
      AppSpacing.screen,
      8,
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: AppText.label.copyWith(
                color: AppColors.brown,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const ScopeMenuChip(),
      ],
    ),
  );
}

/// Invitations, then "My chats": the member's private chats, most recently
/// active first. A chat of two
/// with someone the member blocked is left out. Without any chat or
/// invitation the section shows only the rooms, as before private chats
/// (the "New chat" button starts one).
class _PrivateChats extends ConsumerWidget {
  const _PrivateChats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final invitations =
        ref.watch(chatInvitationsProvider).value ?? const <ChatInvitation>[];
    final chats = ref.watch(privateChatsProvider);
    final blocked = ref.watch(blockedIdsProvider);
    final summaries =
        ref.watch(chatRoomSummariesProvider).value ??
        const <String, ChatRoomSummary>{};
    final list = chats.value;

    DateTime activeAt(PrivateChat chat) {
      final last = summaries[chat.id]?.lastMessageAt;
      return last != null && last.isAfter(chat.createdAt)
          ? last
          : chat.createdAt;
    }

    final shown = [
      for (final chat in list ?? const <PrivateChat>[])
        if (!chat.direct || !blocked.contains(chat.directWith)) chat,
    ]..sort((a, b) => activeAt(b).compareTo(activeAt(a)));

    if (invitations.isEmpty &&
        (list == null ? chats.isLoading : shown.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final invitation in invitations)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.cardGap,
            ),
            child: ChatInvitationCard(invitation: invitation),
          ),
        _Heading(l10n.myChats),
        if (list == null)
          chats.isLoading
              ? const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        l10n.privateChatsLoadFailed,
                        style: AppText.body.copyWith(color: AppColors.brown),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(privateChatsProvider),
                        child: Text(context.l10n.commonTryAgain),
                      ),
                    ],
                  ),
                )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen + 4,
              0,
              AppSpacing.screen + 4,
              12,
            ),
            child: Text(
              l10n.noPrivateChats,
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
          )
        else
          for (final chat in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.cardGap,
              ),
              child: _PrivateChatCard(chat: chat, summary: summaries[chat.id]),
            ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// A private chat in "My chats": who or what it is, the latest line, when,
/// the unread count and whether it is muted.
class _PrivateChatCard extends ConsumerWidget {
  const _PrivateChatCard({required this.chat, this.summary});

  final PrivateChat chat;
  final ChatRoomSummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final format = AppFormat.of(context);
    final now = ref.watch(communityClockProvider)();
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final muted = privateChatMuted(ref, chat);
    final summary = this.summary;
    final unread = muted ? 0 : summary?.unread ?? 0;
    final when = summary?.lastMessageAt;
    String preview;
    if (summary == null) {
      preview = chat.direct
          ? l10n.privateChat
          : dotted([
              l10n.privateChat,
              l10n.participantCount(chat.participantCount),
            ]);
    } else if (summary.lastSystem case final line?) {
      preview = l10n.systemLine(
        line,
        actorId: summary.lastAuthorId ?? '',
        actorName: summary.lastAuthorName,
        viewerId: viewerId,
      );
    } else {
      final text = summary.lastHasPhoto && summary.lastText.isEmpty
          ? l10n.photoLabel
          : summary.lastText;
      preview = summary.lastAuthorId == viewerId
          ? l10n.roomLastMine(l10n.inLine(text))
          : chat.direct
          ? text
          : l10n.roomLastOther(
              l10n.inLine(l10n.memberName(summary.lastAuthorName)),
              l10n.inLine(text),
            );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('chat-${chat.id}'),
        onTap: () => openChat(context, chat.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              PrivateChatAvatar(chat: chat),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AutoDirectionText(
                            l10n.privateChatName(chat, viewerId),
                            style: AppText.rowTitle,
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
                        if (chat.closed) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: l10n.errChatClosed,
                            child: const AppIcon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: AppColors.brown,
                            ),
                          ),
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
                ),
              ),
              const SizedBox(width: 8),
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
