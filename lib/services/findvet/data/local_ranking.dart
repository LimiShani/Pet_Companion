import '../regions/region.dart';
import 'vet_models.dart';

/// Ranks PetLoop's own directory records around [center] without the
/// server, the same way the server does (docs/find_a_vet.md, "Ranking"):
/// used when the live search cannot be reached, so the owner still sees
/// the facilities we maintain, each with its own check date.
///
/// Emergency: only records with an emergency claim (advertised or no
/// longer confirmed); a fresh accepting/limited report first, then
/// advertised, then diverting, then unverified; nearest first within each.
/// The radius widens through the region's ladder until enough advertised
/// records are found. Long term: every record, nearest first, widening
/// until enough are found.
VetSearchResult rankDirectoryLocally({
  required VetRegion region,
  required VetSearchMode mode,
  required GeoPoint center,
  required List<VetResult> directory,
  required DateTime now,
  required ProviderStatus providerStatus,
  DateTime? directoryCopyFrom,
}) {
  final emergency = mode == VetSearchMode.emergency;
  final ladder = emergency ? region.emergencyLadderM : region.longTermLadderM;
  final pool = [
    for (final record in directory)
      if (!emergency || record.emergencyState != EmergencyClaimState.notListed)
        record.withDistanceFrom(center),
  ];

  var radius = ladder.first;
  List<VetResult> inside = const [];
  for (final step in ladder) {
    radius = step;
    inside = pool.where((r) => (r.distanceM ?? 0) <= step).toList();
    final enough = emergency
        ? inside
                  .where(
                    (r) => r.emergencyState == EmergencyClaimState.advertised,
                  )
                  .length >=
              region.minEmergencyResults
        : inside.length >= region.minLongTermResults;
    if (enough) break;
  }

  int tier(VetResult r) {
    if (!emergency) return 0;
    final intake = r.intake.effectiveAt(now);
    if (intake == IntakeState.accepting || intake == IntakeState.limited) {
      return 0;
    }
    if (intake == IntakeState.diverting) return 2;
    return r.emergencyState == EmergencyClaimState.advertised ? 1 : 3;
  }

  inside.sort((a, b) {
    final byTier = tier(a).compareTo(tier(b));
    return byTier != 0
        ? byTier
        : (a.distanceM ?? 0).compareTo(b.distanceM ?? 0);
  });

  return VetSearchResult(
    mode: mode,
    region: region.code,
    center: center,
    radiusM: radius,
    expanded: radius != ladder.first,
    providerStatus: providerStatus,
    results: inside,
    notices: {
      'provider_unavailable',
      if (radius != ladder.first) 'radius_expanded',
      if (inside.isEmpty) 'no_results',
    },
    searchedAt: now,
    directoryCopyFrom: directoryCopyFrom,
  );
}
