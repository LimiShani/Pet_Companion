import 'package:flutter/material.dart';

/// The app's two fonts.
///
/// Flutter picks the font per character: Latin letters and digits are drawn
/// in [latin] and Hebrew letters, which Nunito does not have, in [hebrew].
/// English screens therefore look the same in both languages, and "23 ק״ג"
/// shows a Nunito number beside Fredoka letters.
///
/// Both families are bundled in `assets/fonts/` with one file per weight
/// (declared in `pubspec.yaml`), so the app needs no network for its fonts
/// and every weight is a real one. Nunito has 400 to 800; Fredoka stops at
/// 700, which is what Hebrew text gets when 800 is asked for.
///
/// Nothing else in the app refers to a font family.
abstract final class AppFonts {
  static const latin = 'Nunito';
  static const hebrew = 'Fredoka';

  /// [base] in the app's fonts.
  static TextTheme textTheme(TextTheme base) => base.apply(fontFamily: latin, fontFamilyFallback: const [hebrew]);
}
