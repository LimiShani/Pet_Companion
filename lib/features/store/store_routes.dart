import 'package:go_router/go_router.dart';

import 'store_screen.dart';

/// Paths owned by the Store feature.
abstract final class StoreRoutes {
  static const root = '/store';
}

/// Routes of the Store tab's navigation branch. The first entry is the
/// tab's root; add sub-pages as nested `routes` of it so the bottom bar
/// stays visible, or push a `MaterialPageRoute` on the root navigator for
/// full-screen flows.
final List<RouteBase> storeRoutes = [
  GoRoute(path: StoreRoutes.root, builder: (context, state) => const StoreScreen()),
];
