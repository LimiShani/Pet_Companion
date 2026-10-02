import 'package:flutter/material.dart';

/// The palette of PetLoop.
///
/// [coral], [yellow], [sage], [brown] and [cream] are the five brand
/// colours of the PetLoop asset pack, exactly. The others are shades the
/// pack does not define: [coralDark] for buttons and links (white text on
/// it passes 4.5:1), [ink] for primary text (a deeper shade of [brown], so
/// small text still reads on sage and peach) and [peach] for the Health
/// card.
abstract final class AppColors {
  /// Header and accent (brand coral).
  static const coral = Color(0xFFF56F51);
  static const coralDeep = Color(0xFFCC603E);

  /// Buttons and links: deep enough for white or small text to pass 4.5:1.
  static const coralDark = Color(0xFFC4502F);

  /// Info pills, activity card, icon discs (brand yellow).
  static const yellow = Color(0xFFFFD27A);

  /// Feeding card and soft panels (brand sage).
  static const sage = Color(0xFFA7B882);

  /// Health card.
  static const peach = Color(0xFFE8AC73);

  /// Label / secondary text and line icons (brand brown).
  static const brown = Color(0xFF5B4636);

  /// Primary text. Darker than [brown] so it reads on sage and peach.
  static const ink = Color(0xFF4A3829);

  /// Main screen background (brand cream).
  static const cream = Color(0xFFFFF7E9);

  static const white = Color(0xFFFFFFFF);

  /// Translucent overlays used on the coral header.
  static const onCoralPill = Color(0x483C190A);
  static const onCoralOutline = Color(0x59FFFFFF);
}
