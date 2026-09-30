import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// One measurement on the trend line.
class TrendPoint {
  const TrendPoint(this.at, this.value);

  final DateTime at;
  final double value;
}

/// A simple trend line drawn by hand: a thin 2 px line through the
/// measurements, a small marker on the latest one, and optional event
/// markers (vet visits) along the bottom. It reads well with one point (a
/// single marker) and two (a straight line).
///
/// Time runs left to right in every language, as on any chart: a Hebrew
/// screen does not mirror it.
class WeightTrendChart extends StatelessWidget {
  const WeightTrendChart({
    super.key,
    required this.points,
    this.events = const [],
    this.height = 120,
    this.showGuides = true,
    this.semanticsLabel,
  });

  /// Oldest first.
  final List<TrendPoint> points;

  /// Moments marked under the line (only those inside the line's period).
  final List<DateTime> events;
  final double height;
  final bool showGuides;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: WeightTrendPainter(points: points, events: events, showGuides: showGuides),
        ),
      ),
    );
  }
}

class WeightTrendPainter extends CustomPainter {
  WeightTrendPainter({required this.points, this.events = const [], this.showGuides = true});

  final List<TrendPoint> points;
  final List<DateTime> events;
  final bool showGuides;

  static const _markerRadius = 5.0;
  static const _eventSize = 4.0;

  /// Where each point lands inside [size] (exposed for tests).
  List<Offset> layout(Size size) {
    if (points.isEmpty) return const [];
    final eventBand = events.isEmpty ? 0.0 : _eventSize * 2 + 6;
    const pad = _markerRadius + 2;
    final left = pad;
    final right = size.width - pad;
    final top = pad;
    final bottom = size.height - pad - eventBand;

    var min = points.first.value;
    var max = points.first.value;
    for (final p in points) {
      if (p.value < min) min = p.value;
      if (p.value > max) max = p.value;
    }
    final start = points.first.at.millisecondsSinceEpoch;
    final span = points.last.at.millisecondsSinceEpoch - start;

    Offset place(int index) {
      final p = points[index];
      // One point sits at the end of the chart, where "latest" always is.
      final tx = points.length == 1
          ? 1.0
          : span <= 0
          ? index / (points.length - 1)
          : (p.at.millisecondsSinceEpoch - start) / span;
      // A flat series runs through the middle.
      final ty = max == min ? 0.5 : (max - p.value) / (max - min);
      final x = left + (right - left) * tx;
      return Offset(x, top + (bottom - top) * ty);
    }

    return [for (var i = 0; i < points.length; i++) place(i)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final eventBand = events.isEmpty ? 0.0 : _eventSize * 2 + 6;
    const pad = _markerRadius + 2;

    if (showGuides) {
      final guide = Paint()
        ..color = const Color(0xFFE7D9B5)
        ..strokeWidth = 1;
      for (final t in const [0.0, 0.5, 1.0]) {
        final y = pad + (size.height - pad * 2 - eventBand) * t;
        for (var x = 0.0; x < size.width; x += 8) {
          canvas.drawLine(Offset(x, y), Offset(x + 3, y), guide);
        }
      }
    }

    final spots = layout(size);
    if (spots.isEmpty) return;

    if (spots.length > 1) {
      final path = Path()..moveTo(spots.first.dx, spots.first.dy);
      for (final spot in spots.skip(1)) {
        path.lineTo(spot.dx, spot.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.coralDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // The latest measurement.
    canvas.drawCircle(spots.last, _markerRadius, Paint()..color = AppColors.white);
    canvas.drawCircle(spots.last, _markerRadius - 1.5, Paint()..color = AppColors.coralDark);

    if (events.isNotEmpty && points.length > 1) {
      final start = points.first.at.millisecondsSinceEpoch;
      final span = points.last.at.millisecondsSinceEpoch - start;
      if (span > 0) {
        final paint = Paint()..color = AppColors.brown;
        final y = size.height - _eventSize - 1;
        for (final event in events) {
          final t = (event.millisecondsSinceEpoch - start) / span;
          if (t < 0 || t > 1) continue;
          final cx = pad + (size.width - pad * 2) * t;
          final diamond = Path()
            ..moveTo(cx, y - _eventSize)
            ..lineTo(cx + _eventSize, y)
            ..lineTo(cx, y + _eventSize)
            ..lineTo(cx - _eventSize, y)
            ..close();
          canvas.drawPath(diamond, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(WeightTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.events != events || oldDelegate.showGuides != showGuides;
}
