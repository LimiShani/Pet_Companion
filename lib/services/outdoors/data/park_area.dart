import 'dart:math' as math;

import '../../findvet/regions/region.dart';

/// How far around the chosen place to look. Shared with meetups (a city
/// and a radius).
enum ParkRadius {
  /// Only the parks of the city itself (by their locality code).
  cityOnly(null),
  km10(10000),
  km25(25000);

  const ParkRadius(this.metres);

  /// `null` for [cityOnly].
  final int? metres;

  int get km => (metres ?? 0) ~/ 1000;
}

/// Where the parks list looks: around the phone ("Near me") or a city.
///
/// The phone's position stays on the phone: it is never stored, and the
/// server only ever gets a coarse box ([coarseBox]).
sealed class ParkArea {
  const ParkArea(this.radius);

  final ParkRadius radius;

  /// The point distances are measured from.
  GeoPoint get centre;

  ParkArea withRadius(ParkRadius radius);
}

class NearMeArea extends ParkArea {
  const NearMeArea({
    required this.point,
    this.accuracyM,
    this.nearest,
    ParkRadius radius = ParkRadius.km10,
  }) : super(radius == ParkRadius.cityOnly ? ParkRadius.km10 : radius);

  final GeoPoint point;
  final double? accuracyM;

  /// The locality the phone is in or near, to say "Near me · Ra'anana".
  final Locality? nearest;

  @override
  GeoPoint get centre => point;

  /// A fix too rough to sort parks by (over 1.5 km off).
  bool get isApproximate => (accuracyM ?? 0) > 1500;

  @override
  NearMeArea withRadius(ParkRadius radius) => NearMeArea(
    point: point,
    accuracyM: accuracyM,
    nearest: nearest,
    radius: radius,
  );
}

class CityArea extends ParkArea {
  const CityArea(this.locality, {ParkRadius radius = ParkRadius.cityOnly})
    : super(radius);

  final Locality locality;

  @override
  GeoPoint get centre => locality.point;

  @override
  CityArea withRadius(ParkRadius radius) =>
      CityArea(locality, radius: radius);
}

const _earthRadiusM = 6371008.8;

/// The box that holds the circle ([centre], [radiusM]).
GeoBounds boxAround(GeoPoint centre, double radiusM) {
  final dLat = radiusM / _earthRadiusM * 180 / math.pi;
  final cos = math.max(0.01, math.cos(centre.lat * math.pi / 180));
  final dLng = dLat / cos;
  return GeoBounds(
    south: centre.lat - dLat,
    west: centre.lng - dLng,
    north: centre.lat + dLat,
    east: centre.lng + dLng,
  );
}

/// The grid the coarse boxes snap to, in degrees (about 5.5 km).
const coarseGridDegrees = 0.05;

/// [boxAround], widened outwards to the [coarseGridDegrees] grid: what the
/// server is told for "Near me". It holds every park within [radiusM] of
/// [centre], yet many positions give the same box, so it does not reveal
/// where the phone is.
GeoBounds coarseBox(GeoPoint centre, double radiusM) {
  final box = boxAround(centre, radiusM);
  double down(double v) => (v / coarseGridDegrees).floorToDouble() * coarseGridDegrees;
  double up(double v) => (v / coarseGridDegrees).ceilToDouble() * coarseGridDegrees;
  double tidy(double v) => double.parse(v.toStringAsFixed(2));
  return GeoBounds(
    south: tidy(down(box.south)),
    west: tidy(down(box.west)),
    north: tidy(up(box.north)),
    east: tidy(up(box.east)),
  );
}

/// What the parks repository is asked for one area: a coarse box, or the
/// parks of one locality ("City only").
class ParkQuery {
  const ParkQuery.box(GeoBounds this.box) : localityCode = null;
  const ParkQuery.locality(String this.localityCode) : box = null;

  final GeoBounds? box;
  final String? localityCode;

  /// The query for [area].
  factory ParkQuery.of(ParkArea area) => switch (area) {
    CityArea(radius: ParkRadius.cityOnly, :final locality) =>
      ParkQuery.locality(locality.code),
    _ => ParkQuery.box(coarseBox(area.centre, area.radius.metres!.toDouble())),
  };

  @override
  bool operator ==(Object other) =>
      other is ParkQuery &&
      other.localityCode == localityCode &&
      other.box?.south == box?.south &&
      other.box?.west == box?.west &&
      other.box?.north == box?.north &&
      other.box?.east == box?.east;

  @override
  int get hashCode =>
      Object.hash(localityCode, box?.south, box?.west, box?.north, box?.east);
}
