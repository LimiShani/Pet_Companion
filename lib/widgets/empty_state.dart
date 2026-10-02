import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Friendly "nothing here yet" block: icon disc, title, message and an
/// optional call to action. Also fine for load errors (pass a retry action).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: AppColors.yellow, shape: BoxShape.circle),
              child: AppIcon(icon, size: 42, color: AppColors.coralDark),
            ),
            const SizedBox(height: 18),
            Text(title, style: AppText.cardTitle.copyWith(fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppText.body.copyWith(color: AppColors.brown), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
