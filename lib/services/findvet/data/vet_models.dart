import '../regions/region.dart';

/// The two paths of Find a vet.
enum VetSearchMode {
  /// The nearest facilities that advertise emergency care; Call first.
  emergency('emergency'),

  /// Nearby practices to choose a regular vet from.
  longTerm('long_term');

  const VetSearchMode(this.wire);

  /// The value the server uses.
  final String wire;
}

/// How much a card may claim about a facility. One label per level; each
/// level comes only from the sources written next to it, and a stronger
/// level is never derived from a weaker one (docs/find_a_vet.md).
enum EvidenceLevel {
  /// Found through a places provider in this search. Says nothing about
  /// emergency care.
  listedNearby,

  /// The facility's own current publication (or a direct submission),
  /// held in PetLoop's directory with its source and check date. Never
  /// from a business name or a directory listing.
  emergencyAdvertised,

  /// Published opening hours say it is open at the moment. Not staffing,
  /// not capacity.
  publishedOpen,

  /// The facility itself reported, recently enough, that it is taking
  /// patients. The only level that speaks about "now".
  acceptingNow,
}

/// What PetLoop's directory holds about a facility's emergency service.
enum EmergencyClaimState {
  /// Its own current publication says it offers emergency care.
  advertised,

  /// It used to, but the latest check could not find the evidence again
  /// (or nobody could check for too long): call to ask.
  unverified,

  /// No emergency claim of ours: nothing is known either way.
  notListed;

  static EmergencyClaimState parse(Object? value) => switch (value) {
    'advertised' => advertised,
    'unverified' => unverified,
    _ => notListed,
  };
}

/// Whether published hours say the place is open now.
enum OpenState {
  open,
  closed,

  /// No hours published, or none we can read.
  unknown;

  static OpenState parse(Object? value) => switch (value) {
    'open' => open,
    'closed' => closed,
    _ => unknown,
  };
}

/// Where the opening hours came from.
enum OpenBasis {
  /// The places provider's live listing.
  providerHours,

  /// Our directory's sourced schedule.
  curatedSchedule,
  none;

  static OpenBasis parse(Object? value) => switch (value) {
    'provider_hours' => providerHours,
    'curated_schedule' => curatedSchedule,
    _ => none,
  };
}

/// A facility's own, live answer to "can you take patients?".
enum IntakeState {
  accepting,
  limited,
  diverting,

  /// No fresh report from the facility: the owner has to call to confirm.
  unknown;

  static IntakeState parse(Object? value) => switch (value) {
    'accepting' => accepting,
    'limited' => limited,
    'diverting' => diverting,
    _ => unknown,
  };
}

/// The emergency side of a result.
class EmergencyClaim {
  const EmergencyClaim({
    required this.state,
    this.schedule,
    this.sourceUrl,
    this.checkedAt,
    this.confirmedAt,
  });

  static const none = EmergencyClaim(state: EmergencyClaimState.notListed);

  final EmergencyClaimState state;

  /// As published: "24/7" or free text.
  final String? schedule;

  /// Where the claim was read (the facility's own page).
  final String? sourceUrl;

  /// When a check last found the evidence.
  final DateTime? checkedAt;

  /// When a person last confirmed it.
  final DateTime? confirmedAt;

  factory EmergencyClaim.fromJson(Object? json) {
    if (json is! Map) return none;
    return EmergencyClaim(
      state: EmergencyClaimState.parse(json['state']),
      schedule: _string(json['schedule']),
      sourceUrl: _string(json['sourceUrl']),
      checkedAt: _date(json['checkedAt']),
      confirmedAt: _date(json['confirmedAt']),
    );
  }

  Map<String, Object?> toJson() => {
    'state': switch (state) {
      EmergencyClaimState.advertised => 'advertised',
      EmergencyClaimState.unverified => 'unverified',
      EmergencyClaimState.notListed => 'not_listed',
    },
    'schedule': schedule,
    'sourceUrl': sourceUrl,
    'checkedAt': checkedAt?.toUtc().toIso8601String(),
    'confirmedAt': confirmedAt?.toUtc().toIso8601String(),
  };
}

/// Published hours.
class OpeningInfo {
  const OpeningInfo({
    this.state = OpenState.unknown,
    this.basis = OpenBasis.none,
    this.weekdayText = const [],
  });

  static const unknown = OpeningInfo();

  final OpenState state;
  final OpenBasis basis;

  /// One line per day, as published.
  final List<String> weekdayText;

  factory OpeningInfo.fromJson(Object? json) {
    if (json is! Map) return unknown;
    return OpeningInfo(
      state: OpenState.parse(json['state']),
      basis: OpenBasis.parse(json['basis']),
      weekdayText: _strings(json['weekdayText']),
    );
  }
}

/// A live intake report, sent by the facility itself. It is only good
/// until [expiresAt]: after that it says nothing, whatever it said.
class IntakeReport {
  const IntakeReport({
    this.state = IntakeState.unknown,
    this.species = const [],
    this.updatedAt,
    this.expiresAt,
  });

  static const unknown = IntakeReport();

  final IntakeState state;

  /// Species the report covers (codes such as 'dog', 'cat').
  final List<String> species;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  /// What the report says at [now]: [IntakeState.unknown] once it has
  /// expired, or when it has no expiry at all (a report must expire).
  IntakeState effectiveAt(DateTime now) {
    final expires = expiresAt;
    if (state == IntakeState.unknown || expires == null || updatedAt == null) {
      return IntakeState.unknown;
    }
    return now.isBefore(expires) ? state : IntakeState.unknown;
  }

  factory IntakeReport.fromJson(Object? json) {
    if (json is! Map) return unknown;
    return IntakeReport(
      state: IntakeState.parse(json['state']),
      species: _strings(json['species']),
      updatedAt: _date(json['updatedAt']),
      expiresAt: _date(json['expiresAt']),
    );
  }
}

/// A sourced fact from our directory (species treated, services).
class SourcedFact {
  const SourcedFact({
    required this.key,
    required this.values,
    this.sourceUrl,
    this.checkedAt,
  });

  /// 'species' or 'services'.
  final String key;
  final List<String> values;
  final String? sourceUrl;
  final DateTime? checkedAt;

  factory SourcedFact.fromJson(Map json) => SourcedFact(
    key: _string(json['key']) ?? '',
    values: _strings(json['value']),
    sourceUrl: _string(json['sourceUrl']),
    checkedAt: _date(json['checkedAt']),
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'value': values,
    'sourceUrl': sourceUrl,
    'checkedAt': checkedAt?.toUtc().toIso8601String(),
  };
}

/// How old a directory fact may be before the card calls it stale.
const staleAfter = Duration(days: 30);

/// One facility in the results.
class VetResult {
  const VetResult({
    required this.key,
    required this.name,
    required this.location,
    this.facilityId,
    this.placeId,
    this.address,
    this.distanceM,
    this.phone,
    this.website,
    this.mapsUri,
    this.fromProvider = false,
    this.fromCurated = false,
    this.businessStatus,
    this.emergency = EmergencyClaim.none,
    this.opening = OpeningInfo.unknown,
    this.intake = IntakeReport.unknown,
    this.facts = const [],
    this.lastCheckedAt,
    this.reviewStatus,
  });

  final String key;
  final String? facilityId;
  final String? placeId;
  final String name;
  final String? address;
  final GeoPoint location;
  final int? distanceM;
  final String? phone;
  final String? website;

  /// The place on the provider's map (Google requires a way to reach it).
  final String? mapsUri;

  /// Found through the places provider in this search.
  final bool fromProvider;

  /// Held in PetLoop's own directory.
  final bool fromCurated;

  /// 'operational', 'closed_temporarily', 'closed_permanently' or null.
  final String? businessStatus;
  final EmergencyClaim emergency;
  final OpeningInfo opening;
  final IntakeReport intake;
  final List<SourcedFact> facts;
  final DateTime? lastCheckedAt;

  /// 'approved' or 'needs_review' for directory records.
  final String? reviewStatus;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  /// The emergency claim, but only when it can be trusted as one: it must
  /// come from our directory with a source. A provider listing never
  /// carries one, whatever its name says.
  EmergencyClaimState get emergencyState {
    if (!fromCurated || emergency.sourceUrl == null) {
      return EmergencyClaimState.notListed;
    }
    return emergency.state;
  }

  /// The evidence levels this result reaches at [now].
  Set<EvidenceLevel> evidenceAt(DateTime now) => {
    if (fromProvider) EvidenceLevel.listedNearby,
    if (emergencyState == EmergencyClaimState.advertised)
      EvidenceLevel.emergencyAdvertised,
    if (opening.state == OpenState.open) EvidenceLevel.publishedOpen,
    if (const {
      IntakeState.accepting,
      IntakeState.limited,
    }.contains(intake.effectiveAt(now)))
      EvidenceLevel.acceptingNow,
  };

  /// A directory record nobody has checked for [staleAfter] (or ever).
  bool isStaleAt(DateTime now) =>
      fromCurated &&
      (lastCheckedAt == null || now.difference(lastCheckedAt!) > staleAfter);

  /// The sourced fact with [key] ('species', 'services'), if any.
  SourcedFact? fact(String key) {
    for (final fact in facts) {
      if (fact.key == key && fact.values.isNotEmpty) return fact;
    }
    return null;
  }

  VetResult withDistanceFrom(GeoPoint point) => VetResult(
    key: key,
    name: name,
    location: location,
    facilityId: facilityId,
    placeId: placeId,
    address: address,
    distanceM: location.distanceTo(point).round(),
    phone: phone,
    website: website,
    mapsUri: mapsUri,
    fromProvider: fromProvider,
    fromCurated: fromCurated,
    businessStatus: businessStatus,
    emergency: emergency,
    opening: opening,
    intake: intake,
    facts: facts,
    lastCheckedAt: lastCheckedAt,
    reviewStatus: reviewStatus,
  );

  factory VetResult.fromJson(Map json) {
    final location = json['location'];
    return VetResult(
      key: _string(json['key']) ?? '',
      facilityId: _string(json['facilityId']),
      placeId: _string(json['placeId']),
      name: _string(json['name']) ?? '',
      address: _string(json['address']),
      location: location is Map
          ? GeoPoint(_double(location['lat']), _double(location['lng']))
          : const GeoPoint(0, 0),
      distanceM: (json['distanceM'] as num?)?.round(),
      phone: _string(json['phone']),
      website: _string(json['website']),
      mapsUri: _string(json['mapsUri']),
      fromProvider: json['fromProvider'] == true,
      fromCurated: json['fromCurated'] == true,
      businessStatus: _string(json['businessStatus']),
      emergency: EmergencyClaim.fromJson(json['emergency']),
      opening: OpeningInfo.fromJson(json['open']),
      intake: IntakeReport.fromJson(json['intake']),
      facts: [
        for (final fact in (json['facts'] as List? ?? const []))
          if (fact is Map) SourcedFact.fromJson(fact),
      ],
      lastCheckedAt: _date(json['lastCheckedAt']),
      reviewStatus: _string(json['reviewStatus']),
    );
  }
}

/// How the places provider did in a search.
enum ProviderStatus {
  ok,
  error,

  /// No provider is set up on the server.
  disabled,

  /// The daily cost cap was reached.
  quota,
  timeout,

  /// The live search was not reached at all; results come from our
  /// directory (or the copy kept on the phone).
  unreached;

  static ProviderStatus parse(Object? value) => switch (value) {
    'ok' => ok,
    'disabled' => disabled,
    'quota' => quota,
    'timeout' => timeout,
    'error' => error,
    _ => error,
  };

  bool get isLive => this == ok;
}

/// One answer to a search.
class VetSearchResult {
  const VetSearchResult({
    required this.mode,
    required this.center,
    required this.radiusM,
    required this.results,
    required this.searchedAt,
    this.region = 'IL',
    this.expanded = false,
    this.providerStatus = ProviderStatus.ok,
    this.attribution,
    this.notices = const {},
    this.directoryCopyFrom,
  });

  final VetSearchMode mode;
  final String region;
  final GeoPoint center;

  /// The radius finally searched (after any widening).
  final int radiusM;
  final bool expanded;
  final ProviderStatus providerStatus;

  /// The text the provider's content must be credited with ("Google
  /// Maps"), when any result came from it.
  final String? attribution;
  final List<VetResult> results;
  final Set<String> notices;
  final DateTime searchedAt;

  /// Set when the results are the copy of our directory kept on the phone
  /// (no connection): when that copy was made.
  final DateTime? directoryCopyFrom;

  bool get usedFallback => !providerStatus.isLive;
  bool get anyFromProvider => results.any((r) => r.fromProvider);

  factory VetSearchResult.fromJson(Map json, {required VetSearchMode mode}) {
    final center = json['center'];
    final provider = json['provider'];
    return VetSearchResult(
      mode: mode,
      region: _string(json['region']) ?? 'IL',
      center: center is Map
          ? GeoPoint(_double(center['lat']), _double(center['lng']))
          : const GeoPoint(0, 0),
      radiusM: (json['radiusM'] as num?)?.round() ?? 0,
      expanded: json['expanded'] == true,
      providerStatus: provider is Map
          ? ProviderStatus.parse(provider['status'])
          : ProviderStatus.error,
      attribution: provider is Map ? _string(provider['attribution']) : null,
      results: [
        for (final r in (json['results'] as List? ?? const []))
          if (r is Map) VetResult.fromJson(r),
      ],
      notices: {for (final n in (json['notices'] as List? ?? const [])) '$n'},
      searchedAt: _date(json['searchedAt']) ?? DateTime.now(),
    );
  }
}

/// One answer of the geocoder: a place the owner typed, resolved.
class PlaceMatch {
  const PlaceMatch({required this.label, required this.point});

  final String label;
  final GeoPoint point;
}

/// Where a search looks, and how the app learned it.
enum AreaSource {
  /// The phone's location.
  device,

  /// A city picked from the bundled list.
  locality,

  /// An address or postcode resolved by the server.
  typed,
}

/// The area being searched. Kept in memory for as long as Find a vet is
/// open, never stored.
class SearchArea {
  const SearchArea({
    required this.label,
    required this.point,
    required this.source,
    this.accuracyM,
  });

  /// What to show: "Rehovot", "your location", "Herzl 10, Rehovot".
  final String label;
  final GeoPoint point;
  final AreaSource source;

  /// For [AreaSource.device]: how far off the fix may be, in metres.
  final double? accuracyM;

  /// A device fix too rough to rank nearby vets by.
  bool get isApproximate =>
      source == AreaSource.device && (accuracyM ?? 0) > 1500;
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

List<String> _strings(Object? value) => [
  if (value is List)
    for (final v in value)
      if (_string(v) != null) _string(v)!,
];

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse('$value');
