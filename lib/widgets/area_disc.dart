import 'package:flutter/material.dart';

import '../theme/app_area.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';
import 'petloop_icon.dart';

/// A line icon in ink on a circle of its [area]'s colour: the mark that
/// tells which part of the app a row belongs to (an Add sheet row, a
/// menu row, an activity). 34 px by default; the icon is about half of it.
///
/// Give either [icon] (drawn through [AppIcon], so the brand pack's icon
/// when it has one) or [glyph].
class AreaDisc extends StatelessWidget {
  const AreaDisc(
    IconData this.icon, {
    super.key,
    required this.area,
    this.size = defaultSize,
  }) : glyph = null;

  const AreaDisc.glyph(
    PetLoopGlyph this.glyph, {
    super.key,
    required this.area,
    this.size = defaultSize,
  }) : icon = null;

  static const defaultSize = 34.0;

  final IconData? icon;
  final PetLoopGlyph? glyph;
  final AppArea area;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = (size * 0.53).roundToDouble();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: area.disc, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: glyph != null
          ? PetLoopIcon(glyph!, size: iconSize, color: AppColors.ink)
          : AppIcon(icon, size: iconSize, color: AppColors.ink),
    );
  }
}
