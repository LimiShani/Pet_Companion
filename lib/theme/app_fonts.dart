import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The app's two fonts, and the one place that decides where they come
/// from.
///
/// Flutter picks the font per character: Latin letters and digits are drawn
/// in [latin] and Hebrew letters, which Nunito does not have, in [hebrew].
/// English screens therefore look exactly as before, and "23 ק״ג" shows a
/// Nunito number beside Fredoka letters.
///
/// **Today** both families are fetched by `google_fonts` the first time
/// they are needed (the phone must be online once). `google_fonts`
/// registers every weight as a family of its own, so only one weight of
/// each family is really in use: Nunito Regular, which the engine thickens
/// for bold text as it always did in this app, and Fredoka SemiBold for all
/// Hebrew text.
///
/// **To switch to bundled files** (every weight real, no network):
///  1. put the font files and their `OFL.txt` in `assets/fonts/`;
///  2. declare the two families in `pubspec.yaml` under `flutter: fonts:`
///     with the family names [latin] and [hebrew], one `asset` per weight
///     (400, 600, 700, 800 for Nunito; 400, 500, 600, 700 for Fredoka);
///  3. set [bundled] to `true`.
/// Nothing else in the app refers to a font family.
abstract final class AppFonts {
  static const latin = 'Nunito';
  static const hebrew = 'Fredoka';

  /// Whether [latin] and [hebrew] are declared in `pubspec.yaml`.
  static const bundled = false;

  /// [base] in the app's fonts.
  static TextTheme textTheme(TextTheme base) {
    if (bundled) return base.apply(fontFamily: latin, fontFamilyFallback: const [hebrew]);

    // Asking for the style is what makes google_fonts load the file.
    final hebrewFamily = GoogleFonts.fredoka(fontWeight: FontWeight.w600).fontFamily;
    return GoogleFonts.nunitoTextTheme(base).apply(
      fontFamilyFallback: [?hebrewFamily, latin, hebrew],
    );
  }
}
