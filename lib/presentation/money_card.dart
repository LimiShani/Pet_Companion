import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import 'dashboard_card.dart';

class MoneyCard extends StatelessWidget {
  const MoneyCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
    required this.tapLabel,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? trailing;
  final Widget child;
  final VoidCallback onTap;
  final String tapLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          onTapHint: tapLabel,
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white.withValues(alpha: 0.6),
                  ),
                  child: AppIcon(icon, size: 30, color: AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CardTitleRow(title: title, trailing: trailing),
                      const SizedBox(height: 6),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
