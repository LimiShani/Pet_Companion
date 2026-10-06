import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../../services/findvet/data/vet_finder_repository.dart';

/// Codes from the server and the directory, in the screen's language. An
/// unknown code shows as it is rather than disappearing.
extension FindVetWords on FindVetL10n {
  String speciesName(String code) => switch (code) {
    'dog' => speciesDog,
    'cat' => speciesCat,
    'rabbit' => speciesRabbit,
    'bird' => speciesBird,
    'reptile' => speciesReptile,
    'rodent' => speciesRodent,
    'exotic' => speciesExotic,
    'horse' => speciesHorse,
    'farm' => speciesFarm,
    _ => code,
  };

  String reviewStatus(String status) => switch (status) {
    'pending' => adminStatusPending,
    'approved' => adminStatusApproved,
    'needs_review' => adminStatusNeedsReview,
    'withdrawn' => adminStatusWithdrawn,
    _ => status,
  };

  String claimStatus(String status) => switch (status) {
    'current' => adminClaimStatusCurrent,
    'unverified' => adminClaimStatusUnverified,
    'conflict' => adminClaimStatusConflict,
    'withdrawn' => adminClaimStatusWithdrawn,
    _ => status,
  };

  String factKey(String key) => switch (key) {
    'emergency' => adminFactKeyEmergency,
    'schedule' => adminFactKeySchedule,
    'phone' => adminFactKeyPhone,
    'address' => adminFactKeyAddress,
    'website' => adminFactKeyWebsite,
    'species' => adminFactKeySpecies,
    'services' => adminFactKeyServices,
    _ => key,
  };

  String reviewKind(String kind) => switch (kind) {
    'emergency_evidence_missing' => adminKindEmergencyEvidenceMissing,
    'phone_conflict' => adminKindPhoneConflict,
    'address_conflict' => adminKindAddressConflict,
    'closure' => adminKindClosure,
    'source_unreachable' => adminKindSourceUnreachable,
    'new_emergency_evidence' => adminKindNewEmergencyEvidence,
    'verify_coordinates' => adminKindVerifyCoordinates,
    'link_candidate' => adminKindLinkCandidate,
    'robots_disallowed' => adminKindRobotsDisallowed,
    _ => kind,
  };

  String severity(String severity) => switch (severity) {
    'high' => adminSeverityHigh,
    'medium' => adminSeverityMedium,
    'low' => adminSeverityLow,
    _ => severity,
  };

  /// Why a search failed, as one sentence.
  String failure(Object error) => switch (error) {
    VetFinderException(failure: VetFinderFailure.offline) => errorOffline,
    VetFinderException(failure: VetFinderFailure.rateLimited) =>
      errorRateLimited,
    VetFinderException(failure: VetFinderFailure.invalid) => errorInvalid,
    VetFinderException(failure: VetFinderFailure.unsupportedRegion) =>
      problemOutsideRegion,
    _ => errorUnavailable,
  };
}

/// Distances: "850 m" under a kilometre, "2.4 km" under ten, "37 km" above.
String formatDistance(BuildContext context, int metres) {
  final l10n = context.findVetL10n;
  final format = AppFormat.of(context);
  if (metres < 1000) return l10n.distanceM((metres / 10).round() * 10);
  final km = metres / 1000;
  return l10n.distanceKm(
    km < 10 ? format.decimal(km) : format.integer(km.round()),
  );
}

/// Whole kilometres of a radius.
int radiusKm(int metres) => (metres / 1000).round();
