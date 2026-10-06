import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../l10n/l10n.dart';
import '../../widgets/petloop_icon.dart';
import 'community_routes.dart';
import 'community_screen.dart';
import 'guides/guide_reader_screen.dart';

final communityModule = FeatureModule(
  id: 'community',
  tab: FeatureTab(
    capability: 'community.feed.view|community.chat.view|community.guides.view',
    glyph: PetLoopGlyph.community,
    label: (c) => c.l10n.navCommunity,
    routes: communityRoutes,
  ),
  actions: {
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
