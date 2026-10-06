import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'settings_screen.dart';

/// The location of the Settings page. Only the router uses it; the rest of
/// the app opens the page with [openSettings].
abstract final class SettingsRoutes {
  static const root = '/settings';
}

/// A full-screen route (no bottom bar), placed beside the tabs.
final settingsRoutes = <RouteBase>[
  GoRoute(
    path: SettingsRoutes.root,
    builder: (context, state) => const SettingsScreen(),
  ),
];

/// Opens the Settings page, full screen. Completes when it is closed.
Future<void> openSettings(BuildContext context) => pushSettings(
  router: GoRouter.maybeOf(context),
  navigator: Navigator.of(context, rootNavigator: true),
);

/// As [openSettings], for a caller that is about to close itself (a sheet):
/// take the [router] and the [navigator] first, close, then call this.
Future<void> pushSettings({
  required GoRouter? router,
  required NavigatorState navigator,
}) async {
  if (router != null) {
    await router.push<void>(SettingsRoutes.root);
  } else {
    // A page shown on its own, outside the app's router.
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
