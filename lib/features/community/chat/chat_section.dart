import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../data/community_models.dart';
import '../widgets/icon_disc.dart';
import 'chat_providers.dart';

/// The Chat section of the Community tab: the list of topic rooms.
class ChatSection extends ConsumerWidget {
  const ChatSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(chatChannelsProvider);
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 24),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (context, index) => _ChannelCard(channel: list[index]),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final ChatChannel channel;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
            ],
          ),
        ),
      ),
    );
  }
}
