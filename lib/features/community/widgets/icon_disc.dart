import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'speech_icon.dart';

/// A disc in the Community area's sage with an icon: leads a chat room or
/// guide card.
class IconDisc extends StatelessWidget {
  const IconDisc({super.key, required this.icon, this.size = 48});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
      ),
      child: DirectionalCommunityIcon(
        icon,
        size: size * 0.5,
        color: AppColors.ink,
      ),
    );
  }
}
