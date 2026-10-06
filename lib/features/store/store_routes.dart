import 'package:go_router/go_router.dart';

import 'deal_detail_screen.dart';
import 'saved_deals_screen.dart';
import 'store_screen.dart';

/// Paths owned by the Store feature.
abstract final class StoreRoutes {
  static const root = '/store';

  /// The signed-in user's saved deals.
  static const saved = '$root/saved';

  /// The page of one deal.
  static String deal(String id) => '$root/deal/${Uri.encodeComponent(id)}';
}

/// Routes of the Store tab's navigation branch. The first entry is the
/// tab's root; sub-pages are nested so the bottom bar stays visible. The
/// "Share a deal" form is a full-screen route pushed on the root navigator.
final List<RouteBase> storeRoutes = [
  GoRoute(
    path: StoreRoutes.root,
    builder: (context, state) => const StoreScreen(),
    routes: [
      GoRoute(
        path: 'saved',
        builder: (context, state) => const SavedDealsScreen(),
      ),
      GoRoute(
        path: 'deal/:id',
        builder: (context, state) =>
            DealDetailScreen(dealId: state.pathParameters['id']!),
      ),
    ],
  ),
];
