import 'package:go_router/go_router.dart';

import 'chat/chat_screen.dart';
import 'community_screen.dart';
import 'feed/post_detail_screen.dart';
import 'guides/guide_reader_screen.dart';
import 'safety/community_safety_screen.dart';
import 'safety/moderation_screen.dart';

/// Paths owned by the Community feature.
abstract final class CommunityRoutes {
  static const root = '/community';

  static String post(String postId) =>
      '$root/post/${Uri.encodeComponent(postId)}';
  static String chat(String channelId) =>
      '$root/chat/${Uri.encodeComponent(channelId)}';
  static String guide(String guideId) =>
      '$root/guide/${Uri.encodeComponent(guideId)}';
  static const safety = '$root/safety';
  static const review = '$root/safety/review';
}

/// Routes of the Community tab's navigation branch. The first entry is the
/// tab's root; its sub-pages are nested so the bottom bar stays visible.
/// The new-post composer is a full-screen route pushed on the root
/// navigator (see `openPostComposer`).
final List<RouteBase> communityRoutes = [
  GoRoute(
    path: CommunityRoutes.root,
    builder: (context, state) => const CommunityScreen(),
    routes: [
      GoRoute(
        path: 'post/:postId',
        builder: (context, state) =>
            PostDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: 'chat/:channelId',
        builder: (context, state) =>
            ChatScreen(channelId: state.pathParameters['channelId']!),
      ),
      GoRoute(
        path: 'safety',
        builder: (context, state) => const CommunitySafetyScreen(),
        routes: [
          GoRoute(
            path: 'review',
            builder: (context, state) => const ModerationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: 'guide/:guideId',
        builder: (context, state) =>
            GuideReaderScreen(guideId: state.pathParameters['guideId']!),
      ),
    ],
  ),
];
