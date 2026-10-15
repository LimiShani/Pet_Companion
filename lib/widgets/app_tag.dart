import 'package:flutter/material.dart';

import '../theme/app_area.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';

/// What a tag's colour says, so every tag in the app says it the same way.
enum AppTagTone {
  /// A kind or a category: a question, a walk, a food deal.
  yellow,

  /// Something good or settled: answered, reviewed, you.
  sage,

  /// Something that asks for attention: lost and found, hidden, admin.
  peach,

  /// A plain fact: fenced, water tap, English only.
  neutral,

  /// Over: expired, closed, ended.
  ink,
}

/// The one small tag of the app: a stadium with a short label and an
/// optional icon, 12 px, tinted by its [tone] (or by its area, see
/// [AppTag.area]).
///
/// Used for post kinds, guide marks, chat roles, park details, meetup
/// kinds and deal states, so they all share one size and one voice.
class AppTag extends StatelessWidget {
  const AppTag(
    this.label, {
    super.key,
    this.tone = AppTagTone.neutral,
    this.icon,
  }) : area = null;

  /// A tag in the colour of the part of the app it points to (see
  /// [AppArea]): "Health" on a peach tag, "Store" on yellow.
  const AppTag.area(
    this.label, {
    super.key,
    required AppArea this.area,
    this.icon,
  }) : tone = AppTagTone.neutral;

  final String label;
  final AppTagTone tone;
  final IconData? icon;

  /// Set by [AppTag.area]: the tag takes the area's colour, not [tone]'s.
  final AppArea? area;

  Color get _background =>
      area?.disc ??
      switch (tone) {
        AppTagTone.yellow => AppColors.yellow,
        AppTagTone.sage => AppColors.sage,
        AppTagTone.peach => AppColors.peach,
        AppTagTone.neutral => const Color(0xFFFFF3D6),
        AppTagTone.ink => AppColors.ink,
      };

  Color get _foreground =>
      tone == AppTagTone.ink ? AppColors.white : AppColors.ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: ShapeDecoration(
        color: _background,
        shape: tone == AppTagTone.neutral && area == null
            ? const StadiumBorder(side: BorderSide(color: Color(0xFFE7D9B5)))
            : const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 13, color: _foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w800,
                color: _foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
