import 'package:url_launcher/url_launcher.dart';

import '../../findvet/regions/region.dart';

/// The navigation apps "Navigate" offers.
enum NavigationApp { waze, googleMaps }

/// Waze's "drive there" link for [point].
Uri wazeUri(GeoPoint point) => Uri.https('waze.com', '/ul', {
  'll': '${point.lat},${point.lng}',
  'navigate': 'yes',
});

/// Google Maps' directions link for [point].
Uri googleMapsUri(GeoPoint point) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.lat},${point.lng}',
    });

/// Google Maps showing [point] (reviewers check a suggested location).
Uri mapPinUri(GeoPoint point) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': '${point.lat},${point.lng}',
});

/// Opens a navigation app or a map. Behind an interface so tests see what
/// would have opened.
abstract class ParkLauncher {
  Future<bool> navigate(NavigationApp app, GeoPoint point);
  Future<bool> showOnMap(GeoPoint point);
}

class UrlParkLauncher implements ParkLauncher {
  const UrlParkLauncher();

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> navigate(NavigationApp app, GeoPoint point) => _open(
    switch (app) {
      NavigationApp.waze => wazeUri(point),
      NavigationApp.googleMaps => googleMapsUri(point),
    },
  );

  @override
  Future<bool> showOnMap(GeoPoint point) => _open(mapPinUri(point));
}

/// A [ParkLauncher] for tests: opens nothing, remembers every link.
class RecordingParkLauncher implements ParkLauncher {
  final opened = <Uri>[];
  bool succeeds = true;

  @override
  Future<bool> navigate(NavigationApp app, GeoPoint point) async {
    opened.add(
      app == NavigationApp.waze ? wazeUri(point) : googleMapsUri(point),
    );
    return succeeds;
  }

  @override
  Future<bool> showOnMap(GeoPoint point) async {
    opened.add(mapPinUri(point));
    return succeeds;
  }
}
