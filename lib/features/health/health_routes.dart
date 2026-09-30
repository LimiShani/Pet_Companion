import 'package:go_router/go_router.dart';

import 'health_screen.dart';

/// Paths owned by the Health feature.
abstract final class HealthRoutes {
  static const root = '/health';
}

/// Routes of the Health tab's navigation branch. The first entry is the
/// tab's root; add sub-pages as nested `routes` of it so the bottom bar
/// stays visible, or push a `MaterialPageRoute` on the root navigator for
/// full-screen flows.
final List<RouteBase> healthRoutes = [
  GoRoute(path: HealthRoutes.root, builder: (context, state) => const HealthScreen()),
];
