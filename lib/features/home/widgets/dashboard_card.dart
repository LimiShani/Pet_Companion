import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Shared shell of the feeding / activity / health cards: colored rounded
/// box, illustrated icon disc on the left, content on the right.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.color,
    required this.iconAsset,
    required this.title,
    required this.child,
    this.trailing,
    this.iconRing = false,
  });

  final Color color;
  final String iconAsset;
  final String title;

  /// Small text at the top-right of the card (goal, "Upcoming"...).
  final String? trailing;
  final Widget child;

  /// Draw a faint white ring around the icon disc (used where the disc's
  /// yellow would otherwise blend into the card).
  final bool iconRing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSpacing.cardRadius)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: iconRing ? Border.all(color: AppColors.white.withValues(alpha: 0.6), width: 3) : null,
            ),
            child: ClipOval(child: Image.asset(iconAsset, fit: BoxFit.cover, excludeFromSemantics: true)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(title, style: AppText.cardTitle),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trailing!,
                          style: AppText.label.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Next feeding · 19:30" style line with a small clock.
class NextEventLine extends StatelessWidget {
  const NextEventLine({super.key, required this.label, required this.time});

  final String label;
  final TimeOfDay? time;

  @override
  Widget build(BuildContext context) {
    final text = time == null ? 'not set' : formatTimeOfDay(time!);
    return Row(
      children: [
        const Icon(Icons.schedule_rounded, size: 15, color: AppColors.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text('$label · $text', style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

String formatTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
