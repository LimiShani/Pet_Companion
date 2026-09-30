import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../data/community_models.dart';
import 'feed_controller.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_composer_screen.dart';

/// The Feed section of the Community tab: post cards, newest first.
class FeedSection extends ConsumerWidget {
  const FeedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedControllerProvider);
    final posts = feed.value;

    if (posts == null) {
      if (feed.isLoading) return const Center(child: CircularProgressIndicator());
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Cannot load the feed',
        message: communityErrorMessage(feed.error ?? ''),
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(feedControllerProvider),
      );
    }

    if (posts.isEmpty) {
      return EmptyState(
        icon: Icons.pets_rounded,
        title: 'No posts yet',
        message: 'Be the first to share a photo or a story about your pet.',
        actionLabel: 'Write a post',
        onAction: () => openPostComposer(context),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref.read(feedControllerProvider.notifier).refresh();
        } catch (e) {
          showCommunitySnack(messenger, communityErrorMessage(e));
        }
      },
      child: ListView.separated(
        // Room at the bottom for the "New post" button.
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 96),
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
