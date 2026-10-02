import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import 'chat/chat_section.dart';
import 'feed/feed_controller.dart';
import 'feed/feed_section.dart';
import 'feed/post_composer_screen.dart';
import 'guides/guides_section.dart';

/// The Community tab: a social feed, topic chat rooms and a library of
/// guides, switched from the header.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  static const _feed = 0;

  var _index = _feed;

  /// Sections are built on first visit and then kept, so each one keeps
  /// its scroll position and state when the user switches.
  final _visited = <int>{_feed};

  void _select(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    // The "New post" button floats over the list of posts. A feed with no
    // posts, or one that could not load, shows a block of its own with its
    // own button in the middle of the page; the floating one would sit on
    // top of it on a small phone (in Hebrew it is on the left, right over
    // that button), so it waits until there are posts.
    final feedShowsPosts = ref.watch(
      feedControllerProvider.select((feed) => feed.value == null ? feed.isLoading : feed.value!.isNotEmpty),
    );

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: l10n.tabTitle,
            bottom: CoralSegmentedControl(
              labels: [l10n.sectionFeed, l10n.sectionChat, l10n.sectionGuides],
              selectedIndex: _index,
              onChanged: _select,
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                const FeedSection(),
                _visited.contains(1) ? const ChatSection() : const SizedBox.shrink(),
                _visited.contains(2) ? const GuidesSection() : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _index == _feed && feedShowsPosts
          ? FloatingActionButton.extended(
              onPressed: () => openPostComposer(context),
              icon: const AppIcon(Icons.edit_rounded),
              label: Text(l10n.newPost),
            )
          : null,
    );
  }
}
