import '../../access/feature_gate.dart';
import '../../access/access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import 'chat/chat_section.dart';
import 'community_routes.dart';
import 'widgets/community_keeper.dart';
import 'members/members_providers.dart';
import '../../theme/app_colors.dart';
import 'feed/feed_controller.dart';
import 'feed/feed_section.dart';
import 'feed/post_composer_screen.dart';
import 'guides/guides_section.dart';

/// Set by another part of the app to have the Community tab show its
/// guides (the first 30 days of a new pet links to them). The tab switches
/// to the guides the next time it is built and clears the request.
class CommunityGuidesRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  void clear() => state = false;
}

final communityGuidesRequestProvider =
    NotifierProvider<CommunityGuidesRequest, bool>(CommunityGuidesRequest.new);

/// The Community tab: a social feed, topic chat rooms and a library of
/// guides, switched from the header.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  static const _feed = 0;
  static const _guides = 2;

  var _index = _feed;

  /// Sections are built on first visit and then kept, so each one keeps
  /// its scroll position and state when the user switches.
  final _visited = <int>{_feed};

  void _select(int index) => setState(() {
    _index = index;
    _visited.add(index);
  });

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.view|community.chat.view|community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final visible = [
      if (ref.watch(capabilityProvider('community.feed.view'))) 0,
      if (ref.watch(capabilityProvider('community.chat.view'))) 1,
      if (ref.watch(capabilityProvider('community.guides.view'))) 2,
    ];
    final index = visible.contains(_index) ? _index : visible.first;
    if (ref.watch(communityGuidesRequestProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(communityGuidesRequestProvider.notifier).clear();
        _select(_guides);
      });
    }
    // The "New post" button floats over the list of posts. A feed with no
    // posts, or one that could not load, shows a block of its own with its
    // own button in the middle of the page; the floating one would sit on
    // top of it on a small phone (in Hebrew it is on the left, right over
    // that button), so it waits until there are posts.
    final feedShowsPosts = ref.watch(
      feedControllerProvider.select(
        (feed) => feed.value == null ? feed.isLoading : feed.value!.isNotEmpty,
      ),
    );

    return CommunityKeeper(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(
              title: l10n.tabTitle,
              actions: [
                Badge(
                  isLabelVisible: ref.watch(hasNewActivityProvider),
                  smallSize: 9,
                  backgroundColor: AppColors.yellow,
                  offset: const Offset(-6, 6),
                  child: CoralHeaderAction(
                    icon: Icons.notifications_none_rounded,
                    tooltip: ref.watch(hasNewActivityProvider)
                        ? l10n.activityNew
                        : l10n.activityTooltip,
                    onPressed: () => context.go(CommunityRoutes.activity),
                  ),
                ),
                CoralHeaderAction(
                  icon: Icons.shield_outlined,
                  tooltip: l10n.safetyTitle,
                  onPressed: () => context.go(CommunityRoutes.safety),
                ),
              ],
              bottom: CoralSegmentedControl(
                labels: [
                  for (final section in visible)
                    [
                      l10n.sectionFeed,
                      l10n.sectionChat,
                      l10n.sectionGuides,
                    ][section],
                ],
                selectedIndex: visible.indexOf(index),
                onChanged: (selected) => _select(visible[selected]),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  const FeedSection(),
                  (_visited.contains(1) || index == 1) && visible.contains(1)
                      ? const ChatSection()
                      : const SizedBox.shrink(),
                  (_visited.contains(2) || index == 2) && visible.contains(2)
                      ? const GuidesSection()
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton:
            index == _feed &&
                feedShowsPosts &&
                ref.watch(capabilityProvider('community.feed.post'))
            ? FloatingActionButton.extended(
                onPressed: () => openPostComposer(context),
                icon: const AppIcon(Icons.edit_rounded),
                label: Text(l10n.newPost),
              )
            : null,
      ),
    );
  }
}
