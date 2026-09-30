import 'package:flutter/material.dart';

import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import 'chat/chat_section.dart';
import 'feed/feed_section.dart';
import 'feed/post_composer_screen.dart';
import 'guides/guides_section.dart';

/// The Community tab: a social feed, topic chat rooms and a library of
/// guides, switched from the header.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  static const _feed = 0;
  static const _labels = ['Feed', 'Chat', 'Guides'];

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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: 'Community',
            bottom: CoralSegmentedControl(labels: _labels, selectedIndex: _index, onChanged: _select),
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
      floatingActionButton: _index == _feed
          ? FloatingActionButton.extended(
              onPressed: () => openPostComposer(context),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('New post'),
            )
          : null,
    );
  }
}
