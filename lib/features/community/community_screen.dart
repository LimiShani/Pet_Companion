import '../../access/feature_gate.dart';
import '../../access/access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../platform/feature_ui.dart' show AddTab;
import '../../state/pets_provider.dart';
import '../../widgets/add_sheet.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/coral_segmented_control.dart';
import '../../widgets/header_search.dart';
import 'chat/chat_section.dart';
import 'community_routes.dart';
import 'widgets/community_keeper.dart';
import 'members/members_providers.dart';
import '../../theme/app_colors.dart';
import 'feed/feed_controller.dart';
import 'feed/feed_section.dart';
import 'guides/guides_providers.dart' show guidesQueryProvider;
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
///
/// The header's magnifier searches the section on screen (the posts or the
/// guides; Chat has no search): while it is open the search field takes
/// the place of the sections switch, and closing it clears the words and
/// gives the switch back.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  static const _feed = 0;
  static const _chat = 1;
  static const _guides = 2;

  var _index = _feed;

  /// Sections are built on first visit and then kept, so each one keeps
  /// its scroll position and state when the user switches.
  final _visited = <int>{_feed};

  /// The search field is open in the header.
  var _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() {
    if (index != _index) _endSearch();
    _index = index;
    _visited.add(index);
  });

  /// The words [section] is searched for now.
  String _queryOf(int section) => section == _guides
      ? ref.read(guidesQueryProvider)
      : ref.read(feedFilterProvider).search;

  void _openSearch(int section) {
    _search.text = _queryOf(section);
    setState(() => _searching = true);
  }

  /// The guides filter as the words are typed. The feed asks the server,
  /// so it searches when the words are sent, and shows every post again
  /// as soon as the field is emptied.
  void _onSearchChanged(int section, String words) {
    if (section == _guides) {
      ref.read(guidesQueryProvider.notifier).set(words);
    } else if (words.trim().isEmpty && _queryOf(_feed).isNotEmpty) {
      ref.read(feedFilterProvider.notifier).search('');
    }
  }

  void _onSearchSubmitted(int section, String words) {
    if (section == _feed) ref.read(feedFilterProvider.notifier).search(words);
  }

  /// Closes the search and clears its words, as the field's close button
  /// does.
  void _endSearch() {
    _searching = false;
    _search.clear();
    if (_queryOf(_feed).isNotEmpty) {
      ref.read(feedFilterProvider.notifier).search('');
    }
    if (_queryOf(_guides).isNotEmpty) {
      ref.read(guidesQueryProvider.notifier).set('');
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.view|community.chat.view|community.guides.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    // A recommended place tapped in the results searches for it: the
    // field shows the new words.
    ref.listen(feedFilterProvider.select((f) => f.search), (_, words) {
      if (_searching && _search.text.trim() != words) _search.text = words;
    });
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
    // Chat has no search: no magnifier there.
    final searchable = index != _chat;
    final searching = _searching && searchable;
    final query = index == _guides
        ? ref.watch(guidesQueryProvider)
        : ref.watch(feedFilterProvider.select((filter) => filter.search));

    return CommunityKeeper(
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(
              title: l10n.tabTitle,
              actions: [
                if (searchable)
                  HeaderSearchButton(
                    tooltip: index == _guides
                        ? l10n.searchGuides
                        : l10n.searchPosts,
                    active: !searching && query.isNotEmpty,
                    onPressed: () => _openSearch(index),
                  ),
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
              ],
              bottom: searching
                  ? HeaderSearchField(
                      controller: _search,
                      hint: index == _guides
                          ? l10n.searchGuides
                          : l10n.searchPostsHint,
                      onChanged: (words) => _onSearchChanged(index, words),
                      onSubmitted: (words) => _onSearchSubmitted(index, words),
                      onClose: () => setState(_endSearch),
                      clearTooltip: l10n.clearSearch,
                      closeTooltip: context.l10n.commonClose,
                    )
                  : CoralSegmentedControl(
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
        // The tab's one "+", on every section: a post of a chosen kind or
        // a new chat (the rows the account may use).
        floatingActionButton: AddFab.available(ref, AddTab.community)
            ? AddFab(
                tab: AddTab.community,
                title: l10n.addToCommunity,
                petId: ref.watch(selectedPetProvider).id,
              )
            : null,
      ),
    );
  }
}
