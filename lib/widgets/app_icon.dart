import 'package:flutter/material.dart';

import 'petloop_icon.dart';

/// Draws [icon] like an [Icon], in the line style of the PetLoop brand pack
/// when the pack has a matching icon ([glyphFor]), and as the Material icon
/// otherwise. Use it wherever an [Icon] would go: the app's icons then
/// follow the brand from this one table.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.textDirection,
  });

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// As on [Icon]: the direction that decides whether an icon that follows
  /// the text direction (a chevron) is mirrored. Defaults to the ambient one.
  final TextDirection? textDirection;

  /// The Material icons the brand pack draws instead.
  static final Map<IconData, PetLoopGlyph> _glyphs = {
    Icons.home_rounded: PetLoopGlyph.home,
    Icons.home_outlined: PetLoopGlyph.home,
    Icons.add_rounded: PetLoopGlyph.add,
    Icons.close_rounded: PetLoopGlyph.close,
    Icons.check_rounded: PetLoopGlyph.check,
    Icons.chevron_right_rounded: PetLoopGlyph.chevronRight,
    Icons.edit_rounded: PetLoopGlyph.edit,
    Icons.search_rounded: PetLoopGlyph.search,
    Icons.ios_share_rounded: PetLoopGlyph.share,
    Icons.settings_rounded: PetLoopGlyph.settings,
    Icons.logout_rounded: PetLoopGlyph.logout,
    Icons.menu_rounded: PetLoopGlyph.menu,
    Icons.pets_rounded: PetLoopGlyph.pet,
    Icons.event_rounded: PetLoopGlyph.calendar,
    Icons.calendar_today_rounded: PetLoopGlyph.calendar,
    Icons.calendar_month_rounded: PetLoopGlyph.calendar,
    Icons.restaurant_rounded: PetLoopGlyph.food,
    Icons.vaccines_rounded: PetLoopGlyph.vaccine,
    Icons.directions_walk_rounded: PetLoopGlyph.walk,
    Icons.water_drop_rounded: PetLoopGlyph.water,
    Icons.local_drink_rounded: PetLoopGlyph.water,
    Icons.monitor_weight_rounded: PetLoopGlyph.weight,
    Icons.description_rounded: PetLoopGlyph.document,
    Icons.image_rounded: PetLoopGlyph.gallery,
    Icons.photo_library_rounded: PetLoopGlyph.gallery,
    Icons.place_rounded: PetLoopGlyph.location,
    Icons.chat_bubble_rounded: PetLoopGlyph.message,
    Icons.chat_bubble_outline_rounded: PetLoopGlyph.message,
    Icons.forum_rounded: PetLoopGlyph.community,
    Icons.people_rounded: PetLoopGlyph.community,
    Icons.people_outline_rounded: PetLoopGlyph.community,
    Icons.person_rounded: PetLoopGlyph.profile,
    Icons.storefront_rounded: PetLoopGlyph.shop,
    Icons.shopping_bag_rounded: PetLoopGlyph.shop,
    Icons.shopping_bag_outlined: PetLoopGlyph.shop,
    Icons.medical_services_rounded: PetLoopGlyph.health,
    Icons.monitor_heart_rounded: PetLoopGlyph.health,
    Icons.monitor_heart_outlined: PetLoopGlyph.health,
    Icons.emergency_rounded: PetLoopGlyph.emergency,
    Icons.local_hospital_rounded: PetLoopGlyph.emergency,
    Icons.warning_amber_rounded: PetLoopGlyph.emergency,
  };

  /// The brand-pack icon drawn for [icon], or null when it has none.
  static PetLoopGlyph? glyphFor(IconData? icon) => _glyphs[icon];

  @override
  Widget build(BuildContext context) {
    final glyph = glyphFor(icon);
    if (glyph == null) {
      return Icon(
        icon,
        size: size,
        color: color,
        semanticLabel: semanticLabel,
        textDirection: textDirection,
      );
    }
    final direction = textDirection ?? Directionality.maybeOf(context);
    final drawn = PetLoopIcon(
      glyph,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
    return icon!.matchTextDirection && direction == TextDirection.rtl
        ? Transform.flip(flipX: true, child: drawn)
        : drawn;
  }
}
