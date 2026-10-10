import '../../findvet/regions/region.dart';

/// What a park offers, as the database names it (`dog_parks.<column>`).
enum ParkDetail {
  fenced('fenced'),
  water('water'),
  shade('shade'),
  lighting('lighting'),
  smallDogs('small_dogs'),
  benches('benches');

  const ParkDetail(this.column);

  /// The column and the key in a suggestion's changes.
  final String column;

  static ParkDetail? fromColumn(String column) {
    for (final detail in values) {
      if (detail.column == column) return detail;
    }
    return null;
  }

  /// The ones the list can filter on, in the order of the chips.
  static const filters = [fenced, smallDogs, lighting, water];
}

/// Yes, no, or nobody told us yet.
enum ParkAnswer {
  yes,
  no,
  unknown;

  static ParkAnswer parse(Object? value) => switch ('$value') {
    'yes' => yes,
    'no' => no,
    _ => unknown,
  };
}

enum ParkStatus {
  active('active'),
  closed('closed'),
  pendingReview('pending_review'),
  removed('removed');

  const ParkStatus(this.code);
  final String code;

  static ParkStatus parse(Object? value) {
    for (final status in values) {
      if (status.code == '$value') return status;
    }
    return active;
  }
}

/// Where a park came from: the map, a member's approved suggestion, or by
/// hand.
enum ParkSource {
  osm,
  member,
  admin;

  static ParkSource parse(Object? value) => switch ('$value') {
    'member' => member,
    'admin' => admin,
    _ => osm,
  };
}

/// A dog park: a public area for dogs.
class DogPark {
  const DogPark({
    required this.id,
    required this.point,
    this.source = ParkSource.osm,
    this.nameHe,
    this.nameEn,
    this.streetHe,
    this.streetEn,
    this.localityCode,
    this.details = const {},
    this.openingHours,
    this.status = ParkStatus.active,
    this.reviewReason,
  });

  final String id;
  final ParkSource source;
  final String? nameHe;
  final String? nameEn;

  /// The nearest named street (or the member's place text): an unnamed
  /// park is shown as "Dog park ·" and the street.
  final String? streetHe;
  final String? streetEn;
  final GeoPoint point;

  /// The code of the nearest locality (`israelLocalities`).
  final String? localityCode;
  final Map<ParkDetail, ParkAnswer> details;
  final String? openingHours;
  final ParkStatus status;

  /// Why it waits for review ('osm_vanished'); reviewers only.
  final String? reviewReason;

  /// The park's own name in [language], else in the other language.
  String? name(String language) =>
      language == 'he' ? nameHe ?? nameEn : nameEn ?? nameHe;

  /// The nearest street in [language], else in the other language.
  String? street(String language) =>
      language == 'he' ? streetHe ?? streetEn : streetEn ?? streetHe;

  ParkAnswer answer(ParkDetail detail) =>
      details[detail] ?? ParkAnswer.unknown;

  /// The details we know the park has, in the order of [ParkDetail].
  List<ParkDetail> get has => [
    for (final detail in ParkDetail.values)
      if (answer(detail) == ParkAnswer.yes) detail,
  ];

  bool get isClosed => status == ParkStatus.closed;

  DogPark copyWith({
    Map<ParkDetail, ParkAnswer>? details,
    ParkStatus? status,
  }) => DogPark(
    id: id,
    point: point,
    source: source,
    nameHe: nameHe,
    nameEn: nameEn,
    streetHe: streetHe,
    streetEn: streetEn,
    localityCode: localityCode,
    details: details ?? this.details,
    openingHours: openingHours,
    status: status ?? this.status,
    reviewReason: reviewReason,
  );

  /// A `dog_parks` row (or the review queue's park object).
  factory DogPark.fromRow(Map row) => DogPark(
    id: '${row['id']}',
    source: ParkSource.parse(row['source']),
    nameHe: _text(row['name_he']),
    nameEn: _text(row['name_en']),
    streetHe: _text(row['street_he']),
    streetEn: _text(row['street_en']),
    point: GeoPoint(_number(row['lat']), _number(row['lng'])),
    localityCode: _text(row['locality_code']),
    details: {
      for (final detail in ParkDetail.values)
        detail: ParkAnswer.parse(row[detail.column]),
    },
    openingHours: _text(row['opening_hours']),
    status: ParkStatus.parse(row['status']),
    reviewReason: _text(row['review_reason']),
  );
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

/// How a suggested park was placed.
enum SuggestedLocation {
  /// The phone's position, the member standing at the park.
  device('device'),

  /// The centre of the chosen locality, with a place text.
  locality('locality');

  const SuggestedLocation(this.code);
  final String code;

  static SuggestedLocation parse(Object? value) =>
      '$value' == 'locality' ? locality : device;
}

/// "Suggest a park": a park the map is missing.
class NewParkSuggestion {
  const NewParkSuggestion({
    required this.point,
    required this.location,
    this.name,
    this.localityCode,
    this.placeNote,
    this.details = const {},
  });

  final String? name;
  final GeoPoint point;
  final SuggestedLocation location;
  final String? localityCode;
  final String? placeNote;

  /// Only the details the member answered (yes or no).
  final Map<ParkDetail, ParkAnswer> details;
}

enum SuggestionKind { newPark, details }

/// A member's suggestion as a reviewer sees it.
class ParkSuggestion {
  const ParkSuggestion({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.park,
    this.name,
    this.point,
    this.location,
    this.localityCode,
    this.placeNote,
    this.changes = const {},
    this.closed,
  });

  final String id;
  final SuggestionKind kind;
  final DateTime createdAt;

  /// The park a detail change is about, as it is now.
  final DogPark? park;
  final String? name;
  final GeoPoint? point;
  final SuggestedLocation? location;
  final String? localityCode;
  final String? placeNote;
  final Map<ParkDetail, ParkAnswer> changes;

  /// "Closed for renovation" (true), "open again" (false), or not said.
  final bool? closed;

  factory ParkSuggestion.fromJson(Map json) {
    final changes = json['changes'] is Map
        ? Map<String, Object?>.from(json['changes'] as Map)
        : const <String, Object?>{};
    final lat = json['lat'];
    final lng = json['lng'];
    return ParkSuggestion(
      id: '${json['id']}',
      kind: json['kind'] == 'details'
          ? SuggestionKind.details
          : SuggestionKind.newPark,
      createdAt:
          DateTime.tryParse('${json['created_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      park: json['park'] is Map ? DogPark.fromRow(json['park'] as Map) : null,
      name: _text(json['name']),
      point: lat == null || lng == null
          ? null
          : GeoPoint(_number(lat), _number(lng)),
      location: json['location_kind'] == null
          ? null
          : SuggestedLocation.parse(json['location_kind']),
      localityCode: _text(json['locality_code']),
      placeNote: _text(json['place_note']),
      changes: {
        for (final entry in changes.entries)
          ?ParkDetail.fromColumn(entry.key): ParkAnswer.parse(entry.value),
      },
      closed: changes['closed'] is bool ? changes['closed'] as bool : null,
    );
  }
}

/// What waits for park reviewers.
class ParkReviewQueue {
  const ParkReviewQueue({this.suggestions = const [], this.parks = const []});

  final List<ParkSuggestion> suggestions;

  /// Parks that vanished from OpenStreetMap: keep, close or remove.
  final List<DogPark> parks;

  int get count => suggestions.length + parks.length;

  factory ParkReviewQueue.fromJson(Map json) => ParkReviewQueue(
    suggestions: [
      for (final s in (json['suggestions'] as List? ?? const []))
        if (s is Map) ParkSuggestion.fromJson(s),
    ],
    parks: [
      for (final p in (json['parks'] as List? ?? const []))
        if (p is Map) DogPark.fromRow(p),
    ],
  );
}

/// Why sending a suggestion did not work.
enum ParkFailure {
  /// Ten suggestions today already.
  rateLimited,

  /// No connection, or the server is down.
  unavailable,

  /// Anything else.
  other,
}

class ParkException implements Exception {
  const ParkException(this.failure);
  final ParkFailure failure;

  @override
  String toString() => 'ParkException(${failure.name})';
}
