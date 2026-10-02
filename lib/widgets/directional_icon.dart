import 'package:flutter/material.dart';

import 'app_icon.dart';

// Flutter mirrors some icons by itself on a right-to-left screen (the back
// arrow, the chevron, send) and leaves the others alone. For nearly every
// icon that is right. These two widgets are for the exceptions.

/// An icon that points somewhere (an arrow leaving a door, a walking
/// figure) but which Flutter does not mirror by itself: drawn as designed
/// on a left-to-right screen and mirrored on a right-to-left one.
class MirroredIcon extends StatelessWidget {
  const MirroredIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Drawn left-to-right first, so an icon Flutter would mirror by itself
    // is not mirrored twice.
    final drawn = AppIcon(icon, size: size, color: color, semanticLabel: semanticLabel, textDirection: TextDirection.ltr);
    return Directionality.of(context) == TextDirection.rtl ? Transform.flip(flipX: true, child: drawn) : drawn;
  }
}

/// An icon Flutter would mirror on a right-to-left screen although it must
/// look the same everywhere. The question mark is the known case: Hebrew
/// writes "?" exactly as English does.
class FixedIcon extends StatelessWidget {
  const FixedIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) =>
      AppIcon(icon, size: size, color: color, semanticLabel: semanticLabel, textDirection: TextDirection.ltr);
}
