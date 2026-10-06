import '../platform/feature_module.dart';
import '../features/auth/reset_password_screen.dart';
import '../access/access_provider.dart';
import '../access/access_unavailable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_routes.dart';
import '../features/settings/side_menu.dart';
import '../state/pets_provider.dart';
import '../widgets/app_bottom_nav.dart';

abstract final class AppRoutes {
  static const resetPassword = '/reset-password';
  static const accessUnavailable = '/access-unavailable';
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
  final modules = ref.watch(featureModulesProvider);
  final tabs = modules.where((m) => m.tab != null).map((m) => m.tab!).toList();
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  // The first-pet gate: loading, failed, no pet yet, or ready for the tabs.
  ref.listen(passwordRecoveryProvider, (_, _) => refresh.ping());
  ref.listen(accessProvider, (_, _) => refresh.ping());
  ref.listen(installedFeaturesProvider, (_, _) => refresh.ping());
  ref.listen(petsGateProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.accessUnavailable,
        builder: (_, _) => const AccessUnavailableScreen(),
      ),
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell, tabs: tabs),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          for (final tab in tabs) StatefulShellBranch(routes: tab.routes),
        ],
      ),
      // The first-pet welcome, the add-a-pet flow, the pet profile and "My
      // pets": full screen, beside the tabs (see pets_routes.dart).
      for (final module in modules) ...module.routes,
      // The Settings page: full screen too, opened from the side menu and
      // the account sheet.
      ...settingsRoutes,
    ],
  );
});

/// Sends signed-out users to the login screen, signed-in users away from
/// it, and everyone to the splash while the session is still loading. A
/// signed-in owner reaches the tabs once their pets are loaded and there is
/// at least one; until then the first-pet welcome is all they can open.
String? _redirect(Ref ref, String location) {
  final auth = ref.read(authControllerProvider);
  final restoring = auth.isLoading && !auth.hasValue && !auth.hasError;
  if (restoring) return location == AppRoutes.splash ? null : AppRoutes.splash;

  final signedIn = auth.value != null;
  if (!signedIn) return AppRoutes.isPublic(location) ? null : AppRoutes.login;

  if (ref.read(passwordRecoveryProvider)) {
    return location == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (location == AppRoutes.resetPassword) return AppRoutes.home;
  final access = ref.read(accessProvider);
  if (access.isLoading) {
    return location == AppRoutes.splash ? null : AppRoutes.splash;
  }
  if (access.hasError) {
    return location == AppRoutes.accessUnavailable
        ? null
        : AppRoutes.accessUnavailable;
  }
  if (location == AppRoutes.accessUnavailable) return AppRoutes.home;
  final routeCapability = location.startsWith('/health')
      ? 'health.records.view|health.schedule.view|health.emergency.view'
      : location.startsWith('/community/chat')
      ? 'community.chat.view'
      : location.startsWith('/community/guide')
      ? 'community.guides.view'
      : location.startsWith('/community')
      ? 'community.feed.view|community.chat.view|community.guides.view'
      : location.startsWith('/store')
      ? 'store.deals.view'
      : null;
  if (routeCapability != null && !canUse(ref, routeCapability)) {
    return AppRoutes.home;
  }

  switch (ref.read(petsGateProvider)) {
    case PetsGate.loading:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case PetsGate.failed:
      if (!canUse(ref, 'pets.view')) {
        return location == AppRoutes.home ? null : AppRoutes.home;
      }
      return location == '/welcome' ? null : '/welcome';
    case PetsGate.empty:
      if (!canUse(ref, 'pets.edit')) {
        return location == AppRoutes.home ? null : AppRoutes.home;
      }
      return (location == '/welcome' || location == '/pets/new')
          ? null
          : '/welcome';
    case PetsGate.ready:
      final leave =
          AppRoutes.isPublic(location) ||
          location == AppRoutes.splash ||
          location == '/welcome';
      return leave ? AppRoutes.home : null;
  }
}

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Scaffold shared by the four tabs: keeps each tab's state and hosts the
/// bottom navigation bar and the side menu.
///
/// The menu is this scaffold's drawer, so it covers the bottom bar and
/// comes in from the start side (the left in English, the right in Hebrew).
/// Its button is on Home, and only there can it also be pulled in from the
/// screen's edge.
class _AppShell extends StatefulWidget {
  const _AppShell({required this.shell, required this.tabs});
  final List<FeatureTab> tabs;

  final StatefulNavigationShell shell;

  /// The index of the Home branch.
  static const _homeTab = 0;

  @override
  State<_AppShell> createState() => _AppShellState();
}

/// The phone's back button: a page open inside a tab closes first (its own
/// navigator handles that); at the root of any other tab, back goes to
/// Home; only on Home does it leave the app.
///
/// On Android 14+ (predictive back, the default from Android 16) the app
/// gets the back press only if it told the system beforehand that it will
/// handle it. Flutter says so from the navigators' [NavigationNotification]s,
/// and the tabs' own navigators, which have nothing to close at their
/// root, report "cannot pop": the system then closed the app from the root
/// of every tab. Away from Home this shell turns their reports into "can
/// pop", and says so itself whenever the tab changes.
class _AppShellState extends State<_AppShell> {
  bool get _onHome => widget.shell.currentIndex == _AppShell._homeTab;

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(_AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shell.currentIndex != widget.shell.currentIndex) _report();
  }

  /// Tells the navigators above (and through them the system) whether back
  /// is handled here, once this frame is built.
  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NavigationNotification(canHandlePop: !_onHome).dispatch(context);
      }
    });
  }

  bool _onChildNavigation(NavigationNotification notification) {
    if (_onHome || notification.canHandlePop) return false;
    const NavigationNotification(canHandlePop: true).dispatch(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final onHome = _onHome;
    return NotificationListener<NavigationNotification>(
      onNotification: _onChildNavigation,
      child: PopScope(
        canPop: onHome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) shell.goBranch(_AppShell._homeTab);
        },
        child: Scaffold(
          body: shell,
          drawer: const AppSideMenu(),
          drawerEnableOpenDragGesture: onHome,
          bottomNavigationBar: AppBottomNav(
            tabs: widget.tabs,
            currentIndex: shell.currentIndex,
            onSelect: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
          ),
        ),
      ),
    );
  }
}
