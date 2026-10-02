import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/brand.dart';

/// Shown while the previous session is being restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.coral,
      body: Center(
        child: Semantics(
          label: 'PetLoop',
          child: const PetLoopMark(size: 112, tone: BrandTone.white),
        ),
      ),
    );
  }
}
