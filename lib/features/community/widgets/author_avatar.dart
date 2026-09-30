import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/community_models.dart';

/// Round avatar with the author's initial. The colour is picked from the
/// app's pastels by the author's id, so a person keeps theirs everywhere.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({super.key, required this.name, required this.authorId, this.size = 40});

  final String name;
  final String authorId;
  final double size;

  static const _colors = [AppColors.yellow, AppColors.sage, AppColors.peach];

  @override
  Widget build(BuildContext context) {
    final seed = authorId.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _colors[seed % _colors.length], shape: BoxShape.circle),
        child: Text(
          initialOf(name),
          // A single letter: clip rather than overflow with wide test fonts.
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: AppText.cardTitle.copyWith(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
    );
  }
}
