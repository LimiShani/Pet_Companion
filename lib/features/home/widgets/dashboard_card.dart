import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';

/// Shared shell of the feeding / activity / health cards: colored rounded
/// box, illustrated icon disc at the start (an SVG drawing), content after
/// it (mirrored by itself on a right-to-left screen).
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

  /// Small text at the top end of the card (goal, "Upcoming"...).
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
            child: ClipOval(child: SvgPicture.asset(iconAsset, fit: BoxFit.cover, excludeFromSemantics: true)),
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

/// "Next feeding · 19:30" style line with a small clock. [text] is the
/// whole line, already in the screen's language.
class NextEventLine extends StatelessWidget {
  const NextEventLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppIcon(Icons.schedule_rounded, size: 15, color: AppColors.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: AppText.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
