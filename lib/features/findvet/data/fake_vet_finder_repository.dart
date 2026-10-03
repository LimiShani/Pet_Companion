import '../regions/region.dart';
import 'local_ranking.dart';
import 'vet_finder_repository.dart';
import 'vet_models.dart';

/// One search as a [FakeVetFinderRepository] received it (what tests check).
class VetSearchRequest {
  const VetSearchRequest({
    required this.region,
    required this.mode,
    required this.center,
    required this.radiusM,
    required this.language,
  });

  final String region;
  final VetSearchMode mode;
  final GeoPoint center;
  final int radiusM;
  final String language;
}

/// In memory, for the demo (no backend) and the tests.
///
/// The demo facilities are made up and say so in their names ("Demo ..."),
/// and the screen shows a "sample data" banner while this repository is in
/// use. They are placed around wherever the owner searches. None of them
/// ever carries a live intake report: nothing in the demo pretends a
/// facility is accepting patients.
class FakeVetFinderRepository implements VetFinderRepository {
  FakeVetFinderRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    this.respond,
  }) : _now = now ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _now;

  /// Test hook: answers every search instead of the demo data.
  VetSearchResult Function(VetSearchRequest request)? respond;

  /// Test hook: every search and geocode fails with this.
  VetFinderFailure? failure;

  /// Test hook: the live provider "fails" with this status; the answer then
  /// holds only the demo directory records, as the server does.
  ProviderStatus providerStatus = ProviderStatus.ok;

  /// Test hook: what the geocoder answers (default: nothing found).
  List<PlaceMatch> geocodeResults = const [];

  /// Every search received, oldest first.
  final requests = <VetSearchRequest>[];

  @override
  bool get isDemo => true;

  @override
  Future<VetSearchResult> search({
    required VetRegion region,
    required VetSearchMode mode,
    required GeoPoint center,
    required int radiusM,
    required String language,
  }) async {
    final request = VetSearchRequest(
      region: region.code,
      mode: mode,
      center: center,
      radiusM: radiusM,
      language: language,
    );
    requests.add(request);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = this.failure;
    if (failure != null) throw VetFinderException(failure);
    final respond = this.respond;
    if (respond != null) return respond(request);

    final now = _now();
    final all = demoFacilities(center, now);
    if (!providerStatus.isLive) {
      return rankDirectoryLocally(
        region: region,
        mode: mode,
        center: center,
        directory: all.where((r) => r.fromCurated).toList(),
        now: now,
        providerStatus: providerStatus,
      );
    }
    final ranked = rankDirectoryLocally(
      region: region,
      mode: mode,
      center: center,
      directory: mode == VetSearchMode.emergency
          ? all.where((r) => r.emergencyState != EmergencyClaimState.notListed).toList()
          : all.where((r) => r.businessStatus != 'closed_permanently').toList(),
      now: now,
      providerStatus: ProviderStatus.ok,
    );
    // Live listings with no emergency claim of ours come after the
    // directory's emergency records, as on the server.
    final listings = mode == VetSearchMode.emergency
        ? (all.where((r) => r.fromProvider && r.emergencyState == EmergencyClaimState.notListed).toList()
            ..sort((a, b) => a.distanceM!.compareTo(b.distanceM!)))
        : const <VetResult>[];
    final results = [...ranked.results, ...listings];
    return VetSearchResult(
      mode: mode,
      region: region.code,
      center: center,
      radiusM: ranked.radiusM,
      expanded: ranked.expanded,
      providerStatus: ProviderStatus.ok,
      attribution: 'Google Maps',
      results: results,
      notices: {
        if (ranked.expanded) 'radius_expanded',
        if (results.isEmpty) 'no_results',
      },
      searchedAt: now,
    );
  }

  @override
  Future<List<PlaceMatch>> geocode({
    required VetRegion region,
    required String query,
    required String language,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = this.failure;
    if (failure != null) throw VetFinderException(failure);
    return geocodeResults;
  }
}

/// The made-up facilities of the demo, placed around [center].
List<VetResult> demoFacilities(GeoPoint center, DateTime now) {
  GeoPoint at(double northKm, double eastKm) =>
      GeoPoint(center.lat + northKm / 111.0, center.lng + eastKm / 94.0);
  VetResult place(VetResult r) => r.withDistanceFrom(center);
  const demoSite = 'https://example.org/petloop-demo';

  return [
    place(
      VetResult(
        key: 'demo-emergency-centre',
        facilityId: 'demo-1',
        name: 'Demo Animal Emergency Centre',
        address: 'Demo street 1',
        location: at(1.5, 1.4),
        phone: '000-0000001',
        website: demoSite,
        fromCurated: true,
        fromProvider: true,
        placeId: 'demo-place-1',
        mapsUri: demoSite,
        businessStatus: 'operational',
        emergency: EmergencyClaim(
          state: EmergencyClaimState.advertised,
          schedule: '24/7',
          sourceUrl: '$demoSite/emergency',
          checkedAt: now.subtract(const Duration(days: 3)),
        ),
        opening: const OpeningInfo(state: OpenState.open, basis: OpenBasis.curatedSchedule),
        facts: [
          SourcedFact(
            key: 'species',
            values: const ['dog', 'cat'],
            sourceUrl: '$demoSite/emergency',
            checkedAt: now.subtract(const Duration(days: 3)),
          ),
        ],
        lastCheckedAt: now.subtract(const Duration(days: 3)),
        reviewStatus: 'approved',
      ),
    ),
    place(
      VetResult(
        key: 'demo-vet-hospital',
        facilityId: 'demo-2',
        name: 'Demo Veterinary Hospital',
        address: 'Demo road 20',
        location: at(-4.5, 4.8),
        phone: '000-0000002',
        website: demoSite,
        fromCurated: true,
        emergency: EmergencyClaim(
          state: EmergencyClaimState.advertised,
          schedule: '24/7',
          sourceUrl: '$demoSite/hospital',
          checkedAt: now.subtract(const Duration(days: 10)),
        ),
        lastCheckedAt: now.subtract(const Duration(days: 10)),
        reviewStatus: 'approved',
      ),
    ),
    // A listing whose name says "emergency": the name proves nothing, so it
    // gets no emergency label.
    place(
      VetResult(
        key: 'g:demo-place-3',
        placeId: 'demo-place-3',
        name: 'Demo Emergency Animal Hospital 24/7',
        address: 'Demo square 3',
        location: at(0.8, -0.6),
        phone: '000-0000003',
        mapsUri: demoSite,
        fromProvider: true,
        businessStatus: 'operational',
        opening: const OpeningInfo(
          state: OpenState.open,
          basis: OpenBasis.providerHours,
          weekdayText: ['Sunday-Thursday: 08:00-20:00', 'Friday: 08:00-13:00', 'Saturday: Closed'],
        ),
      ),
    ),
    // A directory record whose evidence disappeared and that nobody has
    // checked for a while: shown honestly, never as advertised.
    place(
      VetResult(
        key: 'demo-night-clinic',
        facilityId: 'demo-4',
        name: 'Demo Night Clinic',
        address: 'Demo lane 4',
        location: at(6.0, -5.5),
        phone: '000-0000004',
        fromCurated: true,
        emergency: EmergencyClaim(
          state: EmergencyClaimState.unverified,
          schedule: 'Nights 20:00-08:00',
          sourceUrl: '$demoSite/night',
          checkedAt: now.subtract(const Duration(days: 45)),
        ),
        lastCheckedAt: now.subtract(const Duration(days: 45)),
        reviewStatus: 'needs_review',
      ),
    ),
    place(
      VetResult(
        key: 'g:demo-place-5',
        placeId: 'demo-place-5',
        name: 'Demo Family Vet Clinic',
        address: 'Demo avenue 5',
        location: at(-1.1, 0.7),
        phone: '000-0000005',
        website: demoSite,
        mapsUri: demoSite,
        fromProvider: true,
        businessStatus: 'operational',
        opening: const OpeningInfo(
          state: OpenState.closed,
          basis: OpenBasis.providerHours,
          weekdayText: ['Sunday-Thursday: 09:00-19:00', 'Friday: 09:00-13:00', 'Saturday: Closed'],
        ),
      ),
    ),
    place(
      VetResult(
        key: 'g:demo-place-6',
        placeId: 'demo-place-6',
        name: 'Demo Cat Clinic',
        address: 'Demo street 6',
        location: at(2.4, -2.0),
        mapsUri: demoSite,
        fromProvider: true,
        businessStatus: 'operational',
      ),
    ),
  ];
}
