import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../../../services/community/data/audience.dart';
import '../../../services/community/data/community_models.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/icon_disc.dart';
import '../widgets/scope_bar.dart';
import '../widgets/small_tag.dart';
import '../widgets/section_state.dart';
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

    final visible = [
      for (final channel in list)
        if (scope.shows(channel.audience)) channel,
    ];

    return ListView(
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
        for (final channel in visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.cardGap,
            ),
            child: _ChannelCard(
              channel: channel,
              // Under Everything each room says which animal it is for.
              tag: scope == CommunityScope.everything
                  ? SmallTag.forAudience(l10n, channel.audience)
                  : null,
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
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.chat.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;

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
                    // A room the app does not know by id keeps its stored
                    // name, which reads in its own direction.
                    AutoDirectionText(
                      l10n.roomName(channel),
                      style: AppText.cardTitle.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    AutoDirectionText(
                      l10n.roomAbout(channel),
                      style: AppText.secondary.copyWith(color: AppColors.brown),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
