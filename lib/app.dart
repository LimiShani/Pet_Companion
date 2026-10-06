import 'config/app_config.dart';
import 'platform/storage_cleanup.dart';
import 'platform/session_navigation_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
import 'navigation/app_router.dart';
import 'notifications/notifications_host.dart';
import 'theme/app_theme.dart';

/// Root widget: wires the theme, the language and the router.
class PetLoopApp extends ConsumerWidget {
  const PetLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // The app's name stays in Latin letters in every language.
      title: 'PetLoop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // The owner's choice in the language switch, or the phone's language
      // (see appLocaleProvider). The layout direction follows it.
      locale: ref.watch(appLocaleProvider),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      // Reminders: every pet's are kept scheduled, and a tapped one opens
      // its page (inert in tests, which have no phone notifications).
      builder: (context, child) => StorageMaintenanceHost(
        child: SessionNavigationHost(
          child: NotificationsHost(
            child: AppConfig.isDemo
                ? Banner(
                    message: 'DEMO',
                    location: BannerLocation.topEnd,
                    child: child ?? const SizedBox.shrink(),
                  )
                : child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
