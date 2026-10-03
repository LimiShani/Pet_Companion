import '../regions/region.dart';
import 'vet_models.dart';

/// Why Find a vet could not answer; worded on screen by the feature.
enum VetFinderFailure {
  /// No connection, and no copy of the directory on the phone.
  offline,

  /// The server refused the request as invalid (bad place or radius).
  invalid,

  /// Too many searches in a short time.
  rateLimited,

  /// The place is outside every region Find a vet works in.
  unsupportedRegion,

  /// The server is down or answered nonsense.
  unavailable,
}

class VetFinderException implements Exception {
  const VetFinderException(this.failure, [this.detail]);

  final VetFinderFailure failure;
  final String? detail;

  @override
  String toString() => 'VetFinderException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// What Find a vet needs from a backend.
///
/// The live search runs on the server (the places provider's key never
/// reaches the phone). When it cannot be reached, implementations fall
/// back to PetLoop's own directory and mark the result with
/// [ProviderStatus.unreached] or the provider's failure, so the screen can
/// say where the results come from.
abstract class VetFinderRepository {
  /// Facilities around [center] for [mode]. The server widens [radiusM]
  /// when too little is found.
  Future<VetSearchResult> search({
    required VetRegion region,
    required VetSearchMode mode,
    required GeoPoint center,
    required int radiusM,
    required String language,
  });

  /// Places in [region] matching what the owner typed (an address, a
  /// postcode, a smaller town). Empty when nothing matches.
  Future<List<PlaceMatch>> geocode({required VetRegion region, required String query, required String language});

  /// Shows sample, not real, facilities (the demo without a backend).
  bool get isDemo;
}
