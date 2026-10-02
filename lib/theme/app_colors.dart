import 'package:flutter/material.dart';

/// The warm pastel palette of PetLoop.
///
/// Values come from the original dashboard screenshot; [coral] is a touch
/// darker than the original header so white text on it passes contrast.
abstract final class AppColors {
  /// Header and accent. Original screenshot value was 0xFFF17459.
  static const coral = Color(0xFFEC6A48);
  static const coralDeep = Color(0xFFCC603E);

  /// Buttons and links: deep enough for white or small text to pass 4.5:1.
  static const coralDark = Color(0xFFC4502F);

  /// Info pills, activity card, icon discs.
  static const yellow = Color(0xFFFFD98B);

  /// Feeding card.
  static const sage = Color(0xFFCDD29B);

  /// Health card.
  static const peach = Color(0xFFE8AC73);

  /// Label / secondary text (the brief's "dark warm brown").
  static const brown = Color(0xFF75562E);

  /// Primary text. Darker than [brown] so it reads on sage and peach.
  static const ink = Color(0xFF5C4322);

  /// Main screen background.
  static const cream = Color(0xFFFFF7E1);

  static const white = Color(0xFFFFFFFF);

  /// Translucent overlays used on the coral header.
  static const onCoralPill = Color(0x483C190A);
  static const onCoralOutline = Color(0x59FFFFFF);
}
