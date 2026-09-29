import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/community/community_screen.dart';
import '../features/health/health_screen.dart';
import '../features/home/home_screen.dart';
import '../features/store/store_screen.dart';
import '../widgets/app_bottom_nav.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const signUp = '/signup';
  static const home = '/home';
  static const health = '/health';
  static const community = '/community';
  static const store = '/store';

  static const _public = {login, signUp};
  static bool isPublic(String location) => _public.contains(location);
}

/// The app's router. Built once; auth changes re-run [_redirect] through
/// [refreshListenable] instead of rebuilding the router.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (context, state) => const SignUpScreen()),
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
});

/// Sends signed-out users to the login screen, signed-in users away from
/// it, and everyone to the splash while the session is still loading.
String? _redirect(Ref ref, String location) {
  final auth = ref.read(authControllerProvider);
  final restoring = auth.isLoading && !auth.hasValue && !auth.hasError;
  if (restoring) return location == AppRoutes.splash ? null : AppRoutes.splash;

  final signedIn = auth.value != null;
  if (!signedIn) return AppRoutes.isPublic(location) ? null : AppRoutes.login;
  if (AppRoutes.isPublic(location) || location == AppRoutes.splash) return AppRoutes.home;
  return null;
}

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

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
