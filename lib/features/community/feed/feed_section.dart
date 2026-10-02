import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_theme.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../widgets/section_state.dart';
import 'feed_controller.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_composer_screen.dart';

/// The Feed section of the Community tab: post cards, newest first.
class FeedSection extends ConsumerWidget {
  const FeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final feed = ref.watch(feedControllerProvider);
    final posts = feed.value;

    if (posts == null) {
      if (feed.isLoading) return const Center(child: CircularProgressIndicator());
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.feedLoadFailed,
        message: communityErrorText(context, feed.error),
        actionLabel: context.l10n.commonTryAgain,
        onAction: () => ref.invalidate(feedControllerProvider),
      );
    }

    if (posts.isEmpty) {
      return SectionState(
        icon: Icons.pets_rounded,
        title: l10n.noPostsTitle,
        message: l10n.noPostsMessage,
        actionLabel: l10n.writeAPost,
        onAction: () => openPostComposer(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        final errorWords = communityErrorWords(context);
        try {
          await ref.read(feedControllerProvider.notifier).refresh();
        } catch (e) {
          showCommunitySnack(messenger, errorWords(e));
        }
      },
      child: ListView.separated(
        // Room at the bottom for the "New post" button.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          16,
          AppSpacing.screen,
          AppSpacing.fabClearance + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostCard(
            key: ValueKey(post.id),
            post: post,
            onOpen: () => context.go(CommunityRoutes.post(post.id)),
          );
        },
      ),
    );
  }
}
