import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/audience.dart';

/// A small rounded label on a card: "Cats", "English only", "Reviewed".
class SmallTag extends StatelessWidget {
  const SmallTag(this.label, {super.key, required this.color, this.icon});

  /// The tag for an item that is for one animal; nothing for what is shared
  /// by everyone.
  static Widget? forAudience(Audience audience) {
    final label = audience.tag;
    if (label == null) return null;
    return SmallTag(
      label,
      color: switch (audience) {
        Audience.cats => AppColors.sage,
        Audience.dogs => AppColors.peach,
        _ => AppColors.yellow,
      },
    );
  }

  /// Marks a guide shown in English because it has no text in the reader's
  /// language yet.
  static const englishOnly = SmallTag('English only', color: Color(0xFFFBE9BD), icon: Icons.translate_rounded);

  /// Marks a guide with a professional review that still applies.
  static const reviewed = SmallTag('Reviewed', color: AppColors.sage, icon: Icons.verified_user_rounded);

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.ink),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppText.navLabel.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
