import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../l10n/l10n.dart';
import '../../widgets/petloop_icon.dart';
import 'community_routes.dart';
import 'community_screen.dart';
import 'feed/feed_controller.dart';
import 'guides/guide_reader_screen.dart';
import 'members/community_push_card.dart';

final communityModule = FeatureModule(
  id: 'community',
  tab: FeatureTab(
    capability: 'community.feed.view|community.chat.view|community.guides.view',
    glyph: PetLoopGlyph.community,
    label: (c) => c.l10n.navCommunity,
    routes: communityRoutes,
  ),
  // The community's push choices, on the Settings page.
  slots: {
    'community-push-settings': FeatureSlot(
      capability: 'community.feed.view|community.chat.view',
      build: (c, r) => const CommunityPushCard(),
    ),
  },
  actions: {
    // Opened from a push notification ('post:<id>', 'room:<id>').
    'post': FeatureAction.task(
      capability: 'community.feed.view',
      open: (c, r) async {
        final id = r.value<String>('id');
        if (id == null) return;
        final router = GoRouter.of(c);
        // Fetched first, so the post page finds it outside the feed.
        try {
          await ProviderScope.containerOf(
            c,
            listen: false,
          ).read(feedControllerProvider.notifier).open(id);
        } catch (_) {
          // The post page says it is gone.
        }
        router.go(CommunityRoutes.post(id));
      },
    ),
    'room': FeatureAction.task(
      capability: 'community.chat.view',
      open: (c, r) async {
        final id = r.value<String>('id');
        if (id == null) return;
        GoRouter.of(c).go(CommunityRoutes.chat(id));
      },
    ),
    'guide': FeatureAction.task(
      capability: 'community.guides.view',
      open: (c, r) async {
        await Navigator.of(c, rootNavigator: true).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                GuideReaderScreen(guideId: r.value<String>('guideId')!),
          ),
        );
      },
    ),
    'guides': FeatureAction.task(
      capability: 'community.guides.view',
      open: (c, r) async {
        ProviderScope.containerOf(
          c,
          listen: false,
        ).read(communityGuidesRequestProvider.notifier).request();
        Navigator.of(c).maybePop();
        GoRouter.maybeOf(c)?.go(CommunityRoutes.root);
      },
    ),
  },
);
