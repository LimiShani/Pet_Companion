import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../l10n/l10n.dart';
import '../../widgets/petloop_icon.dart';
import '../../services/community/data/community_models.dart' show PostKind;
import 'chat/new_chat_screen.dart';
import 'chat/private_chat_providers.dart' show privateChatCapability;
import 'feed/post_card.dart' show postKindIcon;
import 'feed/post_composer_screen.dart';
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
    area: AppArea.community,
  ),
  // The Community tab's "+": a post of a chosen kind, or a new chat.
  add: {
    AddTab.community: [
      for (final (i, kind, label) in [
        (0, PostKind.moment, (BuildContext c) => c.communityL10n.addMoment),
        (1, PostKind.question, (BuildContext c) => c.communityL10n.addQuestion),
        (
          2,
          PostKind.recommendation,
          (BuildContext c) => c.communityL10n.addRecommendation,
        ),
        (3, PostKind.lostFound, (BuildContext c) => c.communityL10n.addLostFound),
      ])
        AddEntry(
          id: 'post-${kind.name}',
          capability: 'community.feed.post',
          area: AppArea.community,
          icon: postKindIcon(kind),
          label: label,
          order: i * 10,
          open: (c, r) => openPostComposer(c, kind: kind),
        ),
      AddEntry(
        id: 'new-chat',
        capability: privateChatCapability,
        area: AppArea.community,
        icon: Icons.add_comment_rounded,
        label: (c) => c.communityL10n.newChat,
        order: 40,
        open: (c, r) => openNewChat(c),
      ),
    ],
  },
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
