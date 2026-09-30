import 'package:go_router/go_router.dart';

import 'community_screen.dart';

/// Paths owned by the Community feature.
abstract final class CommunityRoutes {
  static const root = '/community';
}

/// Routes of the Community tab's navigation branch. The first entry is the
/// tab's root; add sub-pages as nested `routes` of it so the bottom bar
/// stays visible, or push a `MaterialPageRoute` on the root navigator for
/// full-screen flows.
final List<RouteBase> communityRoutes = [
  GoRoute(path: CommunityRoutes.root, builder: (context, state) => const CommunityScreen()),
];
