import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/community/community_screen.dart';
import '../features/health/health_screen.dart';
import '../features/home/home_screen.dart';
import '../features/store/store_screen.dart';
import '../widgets/app_bottom_nav.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const health = '/health';
  static const community = '/community';
  static const store = '/store';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.health, builder: (context, state) => const HealthScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.community, builder: (context, state) => const CommunityScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.store, builder: (context, state) => const StoreScreen()),
        ]),
      ],
    ),
  ],
);

/// Scaffold shared by the four tabs: keeps each tab's state and hosts the
/// bottom navigation bar.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        onSelect: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
      ),
    );
  }
}
