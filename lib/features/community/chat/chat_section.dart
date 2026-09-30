import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../data/audience.dart';
import '../data/community_models.dart';
import '../widgets/icon_disc.dart';
import '../widgets/scope_bar.dart';
import '../widgets/small_tag.dart';
import 'chat_providers.dart';

/// The Chat section of the Community tab: the topic rooms for the chosen
/// animal (or for everything).
class ChatSection extends ConsumerWidget {
  const ChatSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(chatChannelsProvider);
    final scope = ref.watch(communityScopeProvider);
    final list = channels.value;

    if (list == null) {
      if (channels.isLoading) return const Center(child: CircularProgressIndicator());
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Cannot load the chat rooms',
        message: communityErrorMessage(channels.error ?? ''),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(chatChannelsProvider),
      );
    }

    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_rounded,
        title: 'No chat rooms yet',
        message: 'Rooms will appear here as soon as they open.',
      );
    }

    final visible = [
      for (final channel in list)
        if (scope.shows(channel.audience)) channel,
    ];

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        const ScopeBar(what: 'rooms'),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen + 4, vertical: 8),
            child: Text(
              'No rooms for ${scope.noun} yet. Tap Everything to see all rooms.',
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
          ),
        for (final channel in visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.cardGap),
            child: _ChannelCard(
              channel: channel,
              // Under Everything each room says which animal it is for.
              tag: scope == CommunityScope.everything ? SmallTag.forAudience(channel.audience) : null,
            ),
          ),
      ],
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, this.tag});

  final ChatChannel channel;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: AppText.cardTitle.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.description,
                      style: AppText.secondary.copyWith(color: AppColors.brown),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tag != null) ...[const SizedBox(height: 6), tag!],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Mirrors itself in a right-to-left layout.
              const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
            ],
          ),
        ),
      ),
    );
  }
}
