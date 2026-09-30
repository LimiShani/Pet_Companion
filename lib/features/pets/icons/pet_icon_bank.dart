import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';

/// The 13 animals of the icon bank. Each is drawn in code from simple
/// shapes in the app's colours (see [PetIconPainter]): nothing is
/// downloaded and the drawing is sharp at any size.
///
/// Stored in `pets.icon_key` by [name], together with a [PetIconBackground].
enum PetIcon {
  dogFloppy('dog_floppy', 'Dog with floppy ears'),
  dogPointy('dog_pointy', 'Dog with pointy ears'),
  catGinger('cat_ginger', 'Ginger cat'),
  catTabby('cat_tabby', 'Sleepy cat'),
  parrot('parrot', 'Parrot'),
  budgie('budgie', 'Budgie'),
  rabbitUpright('rabbit_upright', 'Rabbit'),
  rabbitLop('rabbit_lop', 'Lop-eared rabbit'),
  turtle('turtle', 'Turtle'),
  gecko('gecko', 'Gecko'),
  hamster('hamster', 'Hamster'),
  fish('fish', 'Fish'),
  paw('paw', 'Paw print');

  const PetIcon(this.key, this.label);

  /// The stored name, e.g. `dog_floppy`.
  final String key;

  /// What a screen reader says.
  final String label;

  static PetIcon? fromKey(String? key) {
    for (final icon in values) {
      if (icon.key == key) return icon;
    }
    return null;
  }

  /// The icon a pet of [species] shows until the owner picks a picture.
  static PetIcon defaultFor(PetSpecies species) => forSpecies(species).first;

  /// The icons that suit [species], its default first.
  static List<PetIcon> forSpecies(PetSpecies species) => switch (species) {
        PetSpecies.dog => const [dogFloppy, dogPointy, paw],
        PetSpecies.cat => const [catGinger, catTabby, paw],
        PetSpecies.bird => const [parrot, budgie],
        PetSpecies.rabbit => const [rabbitUpright, rabbitLop],
        PetSpecies.reptile => const [turtle, gecko],
        PetSpecies.other => const [paw, hamster, fish],
      };
}

/// The four backgrounds an icon can sit on.
enum PetIconBackground {
  yellow(AppColors.yellow, 'Yellow'),
  sage(AppColors.sage, 'Green'),
  peach(AppColors.peach, 'Peach'),
  white(AppColors.white, 'White');

  const PetIconBackground(this.color, this.label);

  final Color color;
  final String label;

  static PetIconBackground? fromName(String? name) {
    for (final background in values) {
      if (background.name == name) return background;
    }
    return null;
  }
}

/// An icon on a background: what `pets.icon_key` holds, e.g.
/// `dog_floppy:sage`.
class PetIconChoice {
  const PetIconChoice(this.icon, [this.background = PetIconBackground.yellow]);

  final PetIcon icon;
  final PetIconBackground background;

  String get key => '${icon.key}:${background.name}';

  /// Reads a stored key. An unknown icon (a newer version of the app) falls
  /// back to the default of [species], an unknown background to yellow.
  static PetIconChoice parse(String? key, {PetSpecies species = PetSpecies.other}) {
    if (key == null || key.trim().isEmpty) return PetIconChoice(PetIcon.defaultFor(species));
    final parts = key.split(':');
    return PetIconChoice(
      PetIcon.fromKey(parts.first) ?? PetIcon.defaultFor(species),
      PetIconBackground.fromName(parts.length > 1 ? parts[1] : null) ?? PetIconBackground.yellow,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PetIconChoice && other.icon == icon && other.background == background;

  @override
  int get hashCode => Object.hash(icon, background);
}

/// One animal of the bank, drawn at [size] (no background).
class PetIconImage extends StatelessWidget {
  const PetIconImage(this.icon, {super.key, this.size = 44});

  final PetIcon icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: PetIconPainter(icon));
  }
}

/// Paints a [PetIcon] scaled to the canvas. The drawings are made on a
/// 64 x 64 grid.
class PetIconPainter extends CustomPainter {
  const PetIconPainter(this.icon);

  final PetIcon icon;

  static const _grid = 64.0;
  static final _cache = <PetIcon, List<_Drawn>>{};

  @override
  void paint(Canvas canvas, Size size) {
    final shapes = _cache.putIfAbsent(icon, () => [for (final s in _drawings[icon]!) _Drawn(s)]);
    canvas.save();
    canvas.scale(size.width / _grid, size.height / _grid);
    for (final shape in shapes) {
      final fill = shape.spec.fill;
      if (fill != null) canvas.drawPath(shape.path, Paint()..color = fill);
      final stroke = shape.spec.stroke;
      if (stroke != null) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = shape.spec.strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PetIconPainter oldDelegate) => oldDelegate.icon != icon;
}

const _ink = AppColors.ink;
const _brown = AppColors.brown;
const _cream = AppColors.cream;
const _white = AppColors.white;
const _peach = AppColors.peach;
const _coral = AppColors.coral;
const _yellow = AppColors.yellow;
const _sage = AppColors.sage;

/// One shape of a drawing: an outline (a path in SVG path notation, an
/// ellipse or a rounded rectangle), how it is filled and how it is outlined.
class _Shape {
  const _Shape.path(String this.d, {this.fill, this.stroke = _ink})
      : cx = 0,
        cy = 0,
        rx = 0,
        ry = 0,
        corner = 0,
        rotate = 0,
        strokeWidth = 2.2,
        isRect = false;

  const _Shape.ellipse(
    this.cx,
    this.cy,
    this.rx,
    this.ry, {
    this.fill,
    this.stroke = _ink,
    this.rotate = 0,
  })  : d = null,
        corner = 0,
        strokeWidth = 2.2,
        isRect = false;

  const _Shape.circle(this.cx, this.cy, double r, {this.fill, this.stroke = _ink, this.strokeWidth = 2.2})
      : d = null,
        rx = r,
        ry = r,
        corner = 0,
        rotate = 0,
        isRect = false;

  /// A rectangle given by its top-left corner ([cx], [cy]) and its size
  /// ([rx], [ry]).
  const _Shape.rect(
    this.cx,
    this.cy,
    this.rx,
    this.ry, {
    this.corner = 0,
    this.fill,
    this.strokeWidth = 2.2,
  })  : d = null,
        rotate = 0,
        stroke = _ink,
        isRect = true;

  final String? d;
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final double corner;

  /// Degrees, around the shape's centre.
  final double rotate;
  final bool isRect;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
}

class _Drawn {
  _Drawn(this.spec) : path = _build(spec);

  final _Shape spec;
  final Path path;

  static Path _build(_Shape s) {
    final d = s.d;
    if (d != null) return parseSvgPath(d);
    if (s.isRect) {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.cx, s.cy, s.rx, s.ry), Radius.circular(s.corner)));
    }
    final oval = Path()..addOval(Rect.fromCenter(center: Offset(s.cx, s.cy), width: s.rx * 2, height: s.ry * 2));
    if (s.rotate == 0) return oval;
    final turn = Matrix4.identity()
      ..translateByDouble(s.cx, s.cy, 0, 1)
      ..rotateZ(s.rotate * math.pi / 180)
      ..translateByDouble(-s.cx, -s.cy, 0, 1);
    return oval.transform(turn.storage);
  }
}

final _pathToken = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)');

/// Builds a [Path] from SVG path notation. Understands the commands the
/// drawings use: M, L, H, V, C, S and Z, absolute and relative.
@visibleForTesting
Path parseSvgPath(String d) {
  final tokens = [for (final m in _pathToken.allMatches(d)) m.group(0)!];
  final path = Path();
  var i = 0;
  var x = 0.0, y = 0.0; // current point
  var startX = 0.0, startY = 0.0; // start of the current sub-path
  var ctrlX = 0.0, ctrlY = 0.0; // last control point, for S
  var lastWasCurve = false;
  var command = '';

  bool isNumber(int index) => index < tokens.length && !RegExp(r'^[A-Za-z]$').hasMatch(tokens[index]);
  double next() => double.parse(tokens[i++]);

  while (i < tokens.length) {
    if (!isNumber(i)) {
      command = tokens[i++];
    } else if (command.toUpperCase() == 'Z' || command.isEmpty) {
      throw FormatException('A number where a command was expected in "$d"');
    } else if (command == 'M') {
      command = 'L'; // more coordinates after a move are lines
    } else if (command == 'm') {
      command = 'l';
    }
    final relative = command == command.toLowerCase();
    var curve = false;
    switch (command.toUpperCase()) {
      case 'M':
        final nx = next() + (relative ? x : 0);
        final ny = next() + (relative ? y : 0);
        path.moveTo(nx, ny);
        x = startX = nx;
        y = startY = ny;
      case 'L':
        final nx = next() + (relative ? x : 0);
        final ny = next() + (relative ? y : 0);
        path.lineTo(nx, ny);
        x = nx;
        y = ny;
      case 'H':
        x = next() + (relative ? x : 0);
        path.lineTo(x, y);
      case 'V':
        y = next() + (relative ? y : 0);
        path.lineTo(x, y);
      case 'C':
        final ox = relative ? x : 0.0, oy = relative ? y : 0.0;
        final x1 = next() + ox, y1 = next() + oy;
        final x2 = next() + ox, y2 = next() + oy;
        final nx = next() + ox, ny = next() + oy;
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        ctrlX = x2;
        ctrlY = y2;
        x = nx;
        y = ny;
        curve = true;
      case 'S':
        final ox = relative ? x : 0.0, oy = relative ? y : 0.0;
        // The first control point mirrors the previous curve's last one.
        final x1 = lastWasCurve ? 2 * x - ctrlX : x;
        final y1 = lastWasCurve ? 2 * y - ctrlY : y;
        final x2 = next() + ox, y2 = next() + oy;
        final nx = next() + ox, ny = next() + oy;
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        ctrlX = x2;
        ctrlY = y2;
        x = nx;
        y = ny;
        curve = true;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Unsupported path command "$command" in "$d"');
    }
    lastWasCurve = curve;
  }
  return path;
}

const _catNose = 'M30.3 36.5h3.4L32 38.8z';
const _catMouthAndWhiskers = 'M32 39v1.6M32 40.6c-1.2 1.7-3.2 1.7-4.2.4M32 40.6c1.2 1.7 3.2 1.7 4.2.4'
    'M19 37l-8-1.5M19 40.5 11 43M45 37l8-1.5M45 40.5l8 2.5';
const _pointyDogHead = 'M16 31c0-10 7-16 16-16s16 6 16 16c0 12-7 19-16 19s-16-7-16-19z';

const _drawings = <PetIcon, List<_Shape>>{
  PetIcon.dogFloppy: [
    _Shape.path('M18 22c-7 1-10 9-8 18 1 5 5 6 8 3z', fill: _brown),
    _Shape.path('M46 22c7 1 10 9 8 18-1 5-5 6-8 3z', fill: _brown),
    _Shape.path('M16 30c0-10 7-16 16-16s16 6 16 16c0 12-7 20-16 20s-16-8-16-20z', fill: _cream),
    _Shape.ellipse(32, 40, 8, 6.5, fill: _white),
    _Shape.ellipse(32, 36.5, 3.2, 2.4, fill: _ink),
    _Shape.path('M32 39v3.5M32 42.5c-1.5 2-4 2-5 .5M32 42.5c1.5 2 4 2 5 .5'),
    _Shape.circle(25, 29, 1.4, fill: _ink),
    _Shape.circle(39, 29, 1.4, fill: _ink),
  ],
  PetIcon.dogPointy: [
    _Shape.path('M18 28 15 9l14 9z', fill: _peach),
    _Shape.path('M46 28 49 9 35 18z', fill: _peach),
    _Shape.path(_pointyDogHead, fill: _white),
    _Shape.path('M33 17c8 0 13 5 14 11-3 4-8 5-11 3-3-3-4-9-3-14z', fill: _peach, stroke: null),
    _Shape.path(_pointyDogHead),
    _Shape.ellipse(32, 38, 3.2, 2.4, fill: _ink),
    _Shape.path('M32 40.5v3M32 43.5c-1.5 2-4 2-5 .5M32 43.5c1.5 2 4 2 5 .5'),
    _Shape.circle(25, 30, 1.4, fill: _ink),
    _Shape.circle(39, 30, 1.4, fill: _ink),
  ],
  PetIcon.catGinger: [
    _Shape.path('M17 30 14 11l14 8z', fill: _peach),
    _Shape.path('M47 30 50 11 36 19z', fill: _peach),
    _Shape.ellipse(32, 34, 18, 15.5, fill: _peach),
    _Shape.path(_catNose, fill: _coral),
    _Shape.path(_catMouthAndWhiskers),
    _Shape.circle(24.5, 31.5, 1.5, fill: _ink),
    _Shape.circle(39.5, 31.5, 1.5, fill: _ink),
  ],
  PetIcon.catTabby: [
    _Shape.path('M17 30 14 11l14 8z', fill: _brown),
    _Shape.path('M47 30 50 11 36 19z', fill: _brown),
    _Shape.ellipse(32, 34, 18, 15.5, fill: _white),
    _Shape.path('M32 19.5v6M26.5 20.5l1.2 5M37.5 20.5l-1.2 5', stroke: _brown),
    _Shape.path(_catNose, fill: _coral),
    _Shape.path(_catMouthAndWhiskers),
    _Shape.path('M22.5 32c1.2-1.6 3-1.6 4.2 0M37.3 32c1.2-1.6 3-1.6 4.2 0'),
  ],
  PetIcon.parrot: [
    _Shape.path('M27 17c0-5 3-8 7-8M33 17c1-4 4-6 8-5'),
    _Shape.path('M14 36c0-11 7-19 17-19s17 8 17 19c0 8-7 14-17 14s-17-6-17-14z', fill: _coral),
    _Shape.circle(27, 31, 6.5, fill: _white, stroke: null),
    _Shape.circle(27, 31, 1.8, fill: _ink),
    _Shape.path('M37 29c9-1 13 5 10 13-2-3-5-5-10-5z', fill: _yellow),
    _Shape.path('M20 44c3 2 7 3 11 3'),
  ],
  PetIcon.budgie: [
    _Shape.path('M32 19c-1-4 1-7 4-8'),
    _Shape.ellipse(32, 35, 16, 15, fill: _yellow),
    _Shape.path('M17 37c-3 1-5 4-5 8 3 0 6-1 8-3', fill: _sage),
    _Shape.path('M47 37c3 1 5 4 5 8-3 0-6-1-8-3', fill: _sage),
    _Shape.path('M28.5 34h7L32 39z', fill: _coral),
    _Shape.circle(25, 30.5, 1.6, fill: _ink),
    _Shape.circle(39, 30.5, 1.6, fill: _ink),
    _Shape.path('M27 44.5h.1M32 46h.1M37 44.5h.1'),
  ],
  PetIcon.rabbitUpright: [
    _Shape.ellipse(24.5, 17, 4.8, 12, fill: _white, rotate: -8),
    _Shape.ellipse(39.5, 17, 4.8, 12, fill: _white, rotate: 8),
    _Shape.path('M24.3 11v10M39.7 11v10', stroke: _peach),
    _Shape.ellipse(32, 39, 16, 13.5, fill: _white),
    _Shape.path('M30.3 40.5h3.4L32 42.6z', fill: _coral),
    _Shape.path('M32 43v2.2M32 45.2c-1.2 1.4-3 1.4-4 .2M32 45.2c1.2 1.4 3 1.4 4 .2M20 42l-7-.5M44 42l7-.5'),
    _Shape.circle(25.5, 36, 1.5, fill: _ink),
    _Shape.circle(38.5, 36, 1.5, fill: _ink),
  ],
  PetIcon.rabbitLop: [
    _Shape.path('M20 22c-7 2-11 12-8 22 2 5 7 4 8-1z', fill: _brown),
    _Shape.path('M44 22c7 2 11 12 8 22-2 5-7 4-8-1z', fill: _brown),
    _Shape.ellipse(32, 33, 15.5, 15, fill: _cream),
    _Shape.path('M30.3 35.5h3.4L32 37.6z', fill: _coral),
    _Shape.path('M32 38v2.2M32 40.2c-1.2 1.4-3 1.4-4 .2M32 40.2c1.2 1.4 3 1.4 4 .2'),
    _Shape.circle(25.5, 30.5, 1.5, fill: _ink),
    _Shape.circle(38.5, 30.5, 1.5, fill: _ink),
  ],
  PetIcon.turtle: [
    _Shape.rect(14, 40, 9, 8, corner: 3.5, fill: _cream),
    _Shape.rect(35, 40, 9, 8, corner: 3.5, fill: _cream),
    _Shape.circle(50.5, 36, 6.5, fill: _cream),
    _Shape.circle(52.5, 34.5, 1.2, fill: _ink),
    _Shape.path('M8 42c0-13 9-22 21-22s21 9 21 22z', fill: _sage),
    _Shape.path('M21 42l3.5-10h9L37 42M24.5 32l-5-7M33.5 32l5-7'),
    _Shape.path('M8 42l-4 2'),
  ],
  PetIcon.gecko: [
    _Shape.path('M12 36c0-10 9-16 20-16s20 6 20 16c0 9-9 14-20 14s-20-5-20-14z', fill: _sage),
    _Shape.circle(21, 24, 7, fill: _yellow),
    _Shape.circle(43, 24, 7, fill: _yellow),
    _Shape.ellipse(21, 24, 1.5, 3.8, fill: _ink, stroke: null),
    _Shape.ellipse(43, 24, 1.5, 3.8, fill: _ink, stroke: null),
    _Shape.path('M21 40c6 5 16 5 22 0M29 35h.1M35 35h.1'),
  ],
  PetIcon.hamster: [
    _Shape.circle(18, 20, 6.5, fill: _peach),
    _Shape.circle(46, 20, 6.5, fill: _peach),
    _Shape.ellipse(32, 35, 19, 15.5, fill: _cream),
    _Shape.ellipse(20.5, 40, 6, 5, fill: _peach, stroke: null),
    _Shape.ellipse(43.5, 40, 6, 5, fill: _peach, stroke: null),
    _Shape.path('M30.3 36h3.4L32 38.1z', fill: _coral),
    _Shape.rect(30.3, 40.5, 3.4, 3.6, corner: 0.8, fill: _white, strokeWidth: 1.6),
    _Shape.path('M32 38.3v2.2'),
    _Shape.circle(25, 31, 1.6, fill: _ink),
    _Shape.circle(39, 31, 1.6, fill: _ink),
  ],
  PetIcon.fish: [
    _Shape.path('M42 32l13-10v20z', fill: _yellow),
    _Shape.path('M27 21c3-5 8-6 12-4l-2 6z', fill: _yellow),
    _Shape.path('M8 32c7-13 25-14 36 0-11 14-29 13-36 0z', fill: _coral),
    _Shape.circle(18.5, 29.5, 2.6, fill: _white, strokeWidth: 1.6),
    _Shape.circle(18.5, 29.5, 0.9, fill: _ink, stroke: null),
    _Shape.path('M26 25c2.5 4 2.5 10 0 14M33 36c1.5-1 3-1 4.5 0'),
  ],
  PetIcon.paw: [
    _Shape.path('M32 31c7 0 13 6 13 12 0 5-5 6-13 6s-13-1-13-6c0-6 6-12 13-12z', fill: _brown),
    _Shape.ellipse(15.5, 29, 4.6, 5.6, fill: _brown, rotate: -18),
    _Shape.ellipse(25.5, 19, 4.6, 5.8, fill: _brown, rotate: -6),
    _Shape.ellipse(38.5, 19, 4.6, 5.8, fill: _brown, rotate: 6),
    _Shape.ellipse(48.5, 29, 4.6, 5.6, fill: _brown, rotate: 18),
  ],
};
