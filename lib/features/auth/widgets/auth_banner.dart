import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/brand.dart';

/// The illustrated top of the sign-in screens: a dog, a cat, a bird and
/// leaves on coral around the PetLoop logo, from the banner pack in
/// assets/banner.
///
/// Laid out on the pack's 840 x 672 canvas, scaled evenly to the width (up
/// to 40% of the screen's height). The design is drawn for
/// Hebrew, with the bird at the top right; on a left-to-right screen the
/// picture is mirrored so the bird stays clear of the language pill, which
/// sits at the end of the line. The logo itself is never mirrored.
///
/// Decorative: the caller announces the app's name.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, this.showBird = true});

  /// False on screens with a back button: the bird sits in the corner the
  /// button takes.
  final bool showBird;

  static const _canvasWidth = 840.0;
  static const _canvasHeight = 672.0;

  /// The most of the screen's height the banner takes.
  static const _maxScreenShare = 0.4;

  /// The rounding of the bottom corners, as background.svg draws them.
  static const _cornerRadius = 90.0;

  /// Where each picture sits, in canvas units: its visible part placed
  /// where the approved design (reference.png in the pack) draws it. The
  /// pack's layout.json frames fit the pictures with their transparent
  /// margins, which left the leaves small and the bird off its branch.
  static const _foliageLeft = Rect.fromLTWH(-50, 157, 394, 361);
  static const _foliageRight = Rect.fromLTWH(373, 48, 467, 347);
  static const _bird = Rect.fromLTWH(655, 59, 157, 126);
  static const _dog = Rect.fromLTWH(-11, 377, 362, 295);
  static const _cat = Rect.fromLTWH(547, 442, 309, 247);

  /// Frames of the logo pieces, in canvas units, measured on the approved
  /// design (reference.png in the pack): the outlined mark, and the white
  /// lettering under it.
  static const _mark = Rect.fromLTWH(283, 222, 280, 268);
  static const _wordmarkLeft = 283.0;
  static const _wordmarkTop = 489.0;
  static const _wordmarkWidth = 309.0;

  @override
  Widget build(BuildContext context) {
    final mirrored = Directionality.of(context) == TextDirection.ltr;

    final maxHeight = MediaQuery.sizeOf(context).height * _maxScreenShare;

    return LayoutBuilder(
      builder: (context, box) {
        // The canvas fills the width, unless that would make it taller than
        // its share of the screen (a tablet, a phone on its side): then it
        // keeps that height and sits in the middle, on coral.
        final k = math.min(box.maxWidth / _canvasWidth, maxHeight / _canvasHeight);

        Widget svg(String file) => Positioned.fill(
          child: SvgPicture.asset('assets/banner/$file', fit: BoxFit.fill, excludeFromSemantics: true),
        );
        Widget picture(String file, Rect frame) => Positioned(
          left: frame.left * k,
          top: frame.top * k,
          width: frame.width * k,
          height: frame.height * k,
          child: Image.asset(
            'assets/banner/$file',
            fit: BoxFit.fill,
            excludeFromSemantics: true,
            filterQuality: FilterQuality.medium,
          ),
        );

        // Mirrored with the picture, so the logo keeps its place in it.
        double left(double x, double width) => (mirrored ? _canvasWidth - x - width : x) * k;

        final art = Stack(
          clipBehavior: Clip.none,
          children: [
            svg('background.svg'),
            svg('accents.svg'),
            picture('foliage_left.png', _foliageLeft),
            picture('foliage_right.png', _foliageRight),
            if (showBird) picture('bird.png', _bird),
            picture('dog.png', _dog),
            picture('cat.png', _cat),
          ],
        );

        return ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(_cornerRadius * k)),
          child: ColoredBox(
            color: AppColors.coral,
            child: Center(
              child: SizedBox(
                width: _canvasWidth * k,
                height: _canvasHeight * k,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: mirrored ? Transform.flip(flipX: true, child: art) : art),
                    Positioned(
                      left: left(_mark.left, _mark.width),
                      top: _mark.top * k,
                      width: _mark.width * k,
                      height: _mark.height * k,
                      child: SvgPicture.asset('assets/banner/logo-mark-outlined.svg', excludeFromSemantics: true),
                    ),
                    Positioned(
                      left: left(_wordmarkLeft, _wordmarkWidth),
                      top: _wordmarkTop * k,
                      child: PetLoopWordmark(
                        height: _wordmarkWidth / PetLoopWordmark.aspectRatio * k,
                        tone: BrandTone.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
