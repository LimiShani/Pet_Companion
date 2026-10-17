import '../../../access/access_provider.dart';
import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../widgets/advice_notice.dart';
import '../widgets/scope_menu_chip.dart';
import '../widgets/section_state.dart';
import 'feed_controller.dart';
import 'near_me.dart';
import 'places_group.dart';
import 'post_actions.dart';
import 'post_card.dart';
import 'post_composer_screen.dart';

/// The Feed section of the Community tab: post cards, newest first, under
/// one row of filters (the animal menu, then the kinds of post) and the
/// line about advice. The search opens from the tab's header. More posts
/// load as the list nears its end.
class FeedSection extends ConsumerStatefulWidget {
  const FeedSection({super.key});

  @override
  ConsumerState<FeedSection> createState() => _FeedSectionState();
}

class _FeedSectionState extends ConsumerState<FeedSection> {
  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Future<void> _loadMore() async {
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    try {
      await ref.read(feedControllerProvider.notifier).loadMore();
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final feed = ref.watch(feedControllerProvider);
    final posts = ref.watch(visiblePostsProvider);
    final query = ref.watch(feedQueryProvider);
    final controller = ref.read(feedControllerProvider.notifier);

    if (posts == null) {
      if (feed.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return SectionState(
        icon: Icons.cloud_off_rounded,
        title: l10n.feedLoadFailed,
        message: communityErrorText(context, feed.error),
        actionLabel: context.l10n.commonTryAgain,
        onAction: () => ref.invalidate(feedControllerProvider),
      );
    }

    final canPost = ref.watch(capabilityProvider('community.feed.post'));
    const header = _FeedHeader();
    final Widget? empty = posts.isNotEmpty
        ? null
        : query.narrowed
        ? EmptyState(
            icon: Icons.search_off_rounded,
            title: l10n.noPostsMatchTitle,
            message: l10n.noPostsMatchMessage,
          )
        : EmptyState(
            icon: Icons.pets_rounded,
            title: l10n.noPostsTitle,
            message: l10n.noPostsMessage,
            actionLabel: l10n.writeAPost,
            onAction: canPost ? () => openPostComposer(context) : null,
          );
    final more = !controller.exhausted && posts.isNotEmpty;

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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (more && notification.metrics.extentAfter < 600) _loadMore();
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          // Room at the bottom for the "New post" button.
          padding: EdgeInsets.only(
            top: 16,
            bottom:
                AppSpacing.fabClearance + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: posts.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  // A new query is loading; the posts below are the last
                  // ones until it answers.
                  if (feed.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.screen,
                      ),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  ?empty,
                  // Searching: the places members recommend, above the posts.
                  if (query.search.trim().isNotEmpty) PlacesGroup(posts: posts),
                ],
              );
            }
            if (index == posts.length + 1) {
              return more
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            semanticsLabel: l10n.loadingMorePosts,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }
            final post = posts[index - 1];
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.cardGap,
              ),
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                onOpen: () => context.go(CommunityRoutes.post(post.id)),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Above the posts: one row of filters (the animal, then "All", "Near me"
/// and the kinds of post) and, until it is hidden, the line about advice. The words to look for
/// are typed in the tab's header.
class _FeedHeader extends ConsumerWidget {
  const _FeedHeader();

  static const filterRowKey = Key('feed-filter-row');
  static const nearMeKey = ValueKey('feed-near-me');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final filter = ref.watch(feedFilterProvider);
    final notifier = ref.read(feedFilterProvider.notifier);
    // "Near me" once the member's city or Outside's area is known.
    final nearMe = filter.nearMe || ref.watch(nearMeCodesProvider) != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScopeFilterRow(
            key: filterRowKey,
            chips: [
              ChoiceChip(
                key: const ValueKey('kind-all'),
                label: Text(l10n.kindsAll),
                selected: filter.kind == null,
                showCheckmark: false,
                onSelected: (_) => notifier.kind(null),
              ),
              if (nearMe)
                FilterChip(
                  key: nearMeKey,
                  avatar: const Icon(Icons.place_rounded, size: 18),
                  label: Text(l10n.feedNearMe),
                  selected: filter.nearMe,
                  showCheckmark: false,
                  onSelected: notifier.nearMe,
                ),
              for (final kind in PostKind.values)
                ChoiceChip(
                  key: ValueKey('kind-${kind.name}'),
                  label: Text(l10n.postKind(kind)),
                  selected: filter.kind == kind,
                  showCheckmark: false,
                  onSelected: (selected) =>
                      notifier.kind(selected ? kind : null),
                ),
            ],
          ),
          const FeedAdviceLine(),
        ],
      ),
    );
  }
}
