import 'package:flutter/material.dart';

import 'navigation/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget: wires the theme and the router.
class PetCompanionApp extends StatelessWidget {
  const PetCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pet Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
