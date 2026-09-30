import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Yellow disc with an icon: leads a chat room or guide card.
class IconDisc extends StatelessWidget {
  const IconDisc({super.key, required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: AppColors.ink),
    );
  }
}
