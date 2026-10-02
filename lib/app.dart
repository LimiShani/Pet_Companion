import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
import 'navigation/app_router.dart';
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
    );
  }
}
