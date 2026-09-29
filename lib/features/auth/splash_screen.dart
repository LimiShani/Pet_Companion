import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shown while the previous session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.coral,
      body: Center(
        child: Icon(Icons.pets_rounded, size: 72, color: AppColors.white),
      ),
    );
  }
}
