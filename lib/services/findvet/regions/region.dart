import 'dart:math' as math;

/// A point on the map, in degrees.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// The great-circle distance to [other], in metres.
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(other.lat - lat);
    final dLng = rad(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat)) *
            math.cos(rad(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// A rectangle of latitudes and longitudes.
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(GeoPoint point) =>
      point.lat >= south &&
      point.lat <= north &&
      point.lng >= west &&
      point.lng <= east;
}

/// A place the owner can pick by name without any lookup on a server: a
/// city or town of the region, with its centre.
class Locality {
  const Locality({
    required this.names,
    required this.point,
    this.aliases = const [],
  });

  /// The name per language code ('en', 'he', ...).
  final Map<String, String> names;
  final GeoPoint point;

  /// Other spellings people type ("Beer Sheva", "Petach Tikva").
  final List<String> aliases;

  /// The name in [language], else English, else any.
  String nameIn(String language) =>
      names[language] ?? names['en'] ?? names.values.first;

  /// Whether [query] (already normalized) matches a name or an alias.
  bool matches(String query) => [
    ...names.values,
    ...aliases,
  ].any((name) => normalizePlaceName(name).contains(query));
}

/// [text] lowercased, with punctuation and repeated spaces removed, so
/// "Tel-Aviv", "tel aviv" and "Tel Aviv–Yafo" compare alike.
String normalizePlaceName(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[\-–—'’`״׳\.,()]"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Everything Find a vet knows about one country. The rest of the feature
/// takes a [VetRegion] and has no country knowledge of its own: adding a
/// country is one new file next to `il.dart` and one line in
/// `regions.dart` (see docs/find_a_vet.md, "Adding a country"). The server
/// has the matching module in `supabase/functions/_shared/regions/`.
class VetRegion {
  const VetRegion({
    required this.code,
    required this.bounds,
    required this.languages,
    required this.center,
    required this.localities,
    required this.emergencyLadderM,
    required this.longTermLadderM,
    this.minEmergencyResults = 2,
    this.minLongTermResults = 3,
  });

  /// ISO 3166-1 alpha-2, as the server expects it ('IL').
  final String code;

  /// Where searches are allowed (the server checks the same box).
  final GeoBounds bounds;

  /// Language codes the region's data and search work in, first = default.
  final List<String> languages;

  /// Where an "around the country" view would centre.
  final GeoPoint center;

  /// Cities and towns for manual search without a server call.
  final List<Locality> localities;

  /// The radii an emergency search widens through, in metres, until it
  /// has [minEmergencyResults] facilities advertising emergency care. The
  /// server uses the same ladder; the app uses it when it ranks our
  /// directory by itself (no connection to the live search).
  final List<int> emergencyLadderM;

  /// The same for long term care, until [minLongTermResults] practices.
  final List<int> longTermLadderM;
  final int minEmergencyResults;
  final int minLongTermResults;

  bool contains(GeoPoint point) => bounds.contains(point);

  /// The language the search should ask the server for: the app's language
  /// when the region has data in it, else the region's own.
  String searchLanguage(String appLanguage) =>
      languages.contains(appLanguage) ? appLanguage : languages.first;

  /// Localities matching [query], best first (names that start with it
  /// before names that only contain it). Empty for a query under 2 letters.
  List<Locality> findLocalities(String query, {int limit = 6}) {
    final q = normalizePlaceName(query);
    if (q.length < 2) return const [];
    final hits = localities.where((l) => l.matches(q)).toList();
    int rank(Locality l) =>
        [
          ...l.names.values,
          ...l.aliases,
        ].any((n) => normalizePlaceName(n).startsWith(q))
        ? 0
        : 1;
    hits.sort((a, b) => rank(a).compareTo(rank(b)));
    return hits.take(limit).toList();
  }
}
