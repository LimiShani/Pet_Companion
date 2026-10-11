import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/coral_header.dart' show HeaderAvatar;
import 'about_screen.dart';
import 'admin_tools_screen.dart';
import 'settings_screen.dart';
import 'you_screen.dart';

/// The locations of the You page, Settings, About and Admin tools. Only
/// the router uses them; the rest of the app opens the pages with
/// [openYou] and [openSettings] (and the headers' [HeaderAvatar]).
abstract final class SettingsRoutes {
  static const you = HeaderAvatar.route;
  static const root = '/settings';
  static const about = '/about';
  static const admin = '/admin';
}

/// Full-screen routes (no bottom bar), placed beside the tabs.
final settingsRoutes = <RouteBase>[
  GoRoute(
    path: SettingsRoutes.you,
    builder: (context, state) => const YouScreen(),
  ),
  GoRoute(
    path: SettingsRoutes.root,
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: SettingsRoutes.about,
    builder: (context, state) => const AboutScreen(),
  ),
  GoRoute(
    path: SettingsRoutes.admin,
    builder: (context, state) => const AdminToolsScreen(),
  ),
];

/// Opens the You page (the avatar of every header), full screen above the
/// current tab. Completes when it is closed.
Future<void> openYou(BuildContext context) => _push(
  context,
  SettingsRoutes.you,
  (_) => const YouScreen(),
);

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

/// Opens the About page.
Future<void> openAbout(BuildContext context) => _push(
  context,
  SettingsRoutes.about,
  (_) => const AboutScreen(),
);

/// Opens the Admin tools page.
Future<void> openAdminTools(BuildContext context) => _push(
  context,
  SettingsRoutes.admin,
  (_) => const AdminToolsScreen(),
);

/// Pushes [location] on the app's router, so the page opens on the root
/// navigator above the tabs; a widget shown on its own, outside the
/// router (a test), gets a plain route built by [builder] instead.
Future<void> _push(
  BuildContext context,
  String location,
  WidgetBuilder builder,
) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push<void>(location);
  } else {
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<void>(MaterialPageRoute(builder: builder));
  }
}
