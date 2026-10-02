import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which colouring of the PetLoop logo to draw: the full brand colours for
/// light backgrounds, or all white for coral, sage and photos.
enum BrandTone { color, white }

/// The PetLoop paw-and-loop symbol, from the brand pack in assets/brand.
///
/// Decorative: the caller announces the app's name. Like every part of the
/// logo it is never mirrored on a right-to-left screen.
class PetLoopMark extends StatelessWidget {
  const PetLoopMark({super.key, this.size = 24, this.tone = BrandTone.color});

  final double size;
  final BrandTone tone;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/petloop-mark-${tone.name}.svg',
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// The "PetLoop" lettering with its infinity "oo", from the brand pack.
///
/// The name stays in Latin letters in every language, so there is one
/// wordmark for English and Hebrew screens alike. Decorative, as
/// [PetLoopMark].
class PetLoopWordmark extends StatelessWidget {
  const PetLoopWordmark({super.key, this.height = 24, this.tone = BrandTone.color});

  /// Width over height of the artwork (its viewBox is 455 x 124).
  static const aspectRatio = 455 / 124;

  final double height;
  final BrandTone tone;

  double get width => height * aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/petloop-wordmark-en-${tone.name}.svg',
      width: width,
      height: height,
      excludeFromSemantics: true,
    );
  }
}
