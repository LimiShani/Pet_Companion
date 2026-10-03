import 'il.dart';
import 'region.dart';

export 'il.dart' show israelRegion;
export 'region.dart';

/// Every country Find a vet works in. To add one, write its module next to
/// `il.dart` and list it here (and register the same code on the server).
final vetRegions = <VetRegion>[israelRegion];

/// The region whose bounds hold [point], or `null` outside all of them.
VetRegion? vetRegionAt(GeoPoint point) {
  for (final region in vetRegions) {
    if (region.contains(point)) return region;
  }
  return null;
}

/// The region with [code], or `null`.
VetRegion? vetRegionByCode(String code) {
  for (final region in vetRegions) {
    if (region.code == code.toUpperCase()) return region;
  }
  return null;
}
