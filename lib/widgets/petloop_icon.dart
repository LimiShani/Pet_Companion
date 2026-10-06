import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The line icons of the PetLoop brand pack (assets/icons).
enum PetLoopGlyph {
  activity,
  add,
  calendar,
  check,
  chevronLeft,
  chevronRight,
  close,
  community,
  document,
  edit,
  emergency,
  food,
  gallery,
  health,
  home,
  location,
  logout,
  menu,
  message,
  pet,
  profile,
  reminder,
  search,
  settings,
  share,
  shop,
  vaccine,
  walk,
  water,
  weight;

  /// The pack names its files in kebab case: chevronLeft -> chevron-left.svg.
  String get asset =>
      'assets/icons/${name.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}')}.svg';
}

/// A brand-pack icon drawn like an [Icon]: size and colour default to the
/// surrounding [IconTheme], so it drops in where an [Icon] was.
class PetLoopIcon extends StatelessWidget {
  const PetLoopIcon(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.mirrorInRtl = false,
  });

  final PetLoopGlyph glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// Flip the drawing on a right-to-left screen (arrows such as sign-out).
  final bool mirrorInRtl;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    var tint = color ?? theme.color ?? const Color(0xFF000000);
    // As an [Icon] does: a dimmed theme (a disabled button) dims the icon.
    final opacity = theme.opacity ?? 1;
    if (opacity != 1) tint = tint.withValues(alpha: tint.a * opacity);

    Widget drawn = SvgPicture.asset(
      glyph.asset,
      width: side,
      height: side,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
    if (mirrorInRtl && Directionality.of(context) == TextDirection.rtl) {
      drawn = Transform.flip(flipX: true, child: drawn);
    }
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      // Centred at its own size when the parent forces a bigger box, as an
      // [Icon] is.
      child: SizedBox.square(
        dimension: side,
        child: Center(child: drawn),
      ),
    );
  }
}
