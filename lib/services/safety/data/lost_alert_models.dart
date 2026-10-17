/// Lost mode's data (`0034_lost_alerts.sql`): an alert for a missing pet,
/// what members nearby may see of one, and the request that starts one.
library;

enum LostAlertStatus {
  active,
  found,
  cancelled;

  static LostAlertStatus fromName(String? name) => LostAlertStatus.values
      .firstWhere((s) => s.name == name, orElse: () => LostAlertStatus.active);
}

/// One time a pet went missing, as its household sees it.
class LostAlert {
  const LostAlert({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.petName,
    required this.petSpecies,
    required this.localityCode,
    required this.lastSeenAt,
    required this.createdAt,
    this.lastSeenPlace = '',
    this.note = '',
    this.language = 'he',
    this.postId,
    this.status = LostAlertStatus.active,
    this.closedAt,
    this.sightings = 0,
  });

  final String id;
  final String petId;

  /// The account that started it (and wrote the post).
  final String ownerId;
  final String petName;

  /// `pets.species` as stored ('dog', 'cat', ...).
  final String petSpecies;
  final String localityCode;
  final DateTime lastSeenAt;
  final String lastSeenPlace;
  final String note;

  /// The language of the post's fixed words ('he' or 'en').
  final String language;

  /// The community post; `null` once it is gone.
  final String? postId;
  final LostAlertStatus status;
  final DateTime createdAt;
  final DateTime? closedAt;

  /// Comments on the post by people outside the pet's household.
  final int sightings;

  bool get isActive => status == LostAlertStatus.active;

  factory LostAlert.fromJson(Map<String, dynamic> json) => LostAlert(
    id: json['id'] as String,
    petId: json['pet_id'] as String,
    ownerId: json['owner_id'] as String? ?? '',
    petName: json['pet_name'] as String? ?? '',
    petSpecies: json['pet_species'] as String? ?? 'other',
    localityCode: json['locality_code'] as String? ?? '',
    lastSeenAt: DateTime.parse(json['last_seen_at'] as String).toLocal(),
    lastSeenPlace: json['last_seen_place'] as String? ?? '',
    note: json['note'] as String? ?? '',
    language: json['language'] as String? ?? 'he',
    postId: json['post_id'] as String?,
    status: LostAlertStatus.fromName(json['status'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    closedAt: json['closed_at'] == null
        ? null
        : DateTime.parse(json['closed_at'] as String).toLocal(),
    sightings: (json['sightings'] as num?)?.toInt() ?? 0,
  );

  LostAlert copyWith({
    LostAlertStatus? status,
    DateTime? closedAt,
    int? sightings,
    String? postId,
    bool clearPost = false,
  }) => LostAlert(
    id: id,
    petId: petId,
    ownerId: ownerId,
    petName: petName,
    petSpecies: petSpecies,
    localityCode: localityCode,
    lastSeenAt: lastSeenAt,
    createdAt: createdAt,
    lastSeenPlace: lastSeenPlace,
    note: note,
    language: language,
    postId: clearPost ? null : postId ?? this.postId,
    status: status ?? this.status,
    closedAt: closedAt ?? this.closedAt,
    sightings: sightings ?? this.sightings,
  );
}

/// What any member may see of an open alert in their area.
class NearbyLostAlert {
  const NearbyLostAlert({
    required this.id,
    required this.petName,
    required this.petSpecies,
    required this.localityCode,
    required this.lastSeenAt,
    required this.createdAt,
    this.lastSeenPlace = '',
    this.postId,
  });

  final String id;
  final String petName;
  final String petSpecies;
  final String localityCode;
  final DateTime lastSeenAt;
  final String lastSeenPlace;
  final String? postId;
  final DateTime createdAt;

  factory NearbyLostAlert.fromJson(Map<String, dynamic> json) =>
      NearbyLostAlert(
        id: json['id'] as String,
        petName: json['pet_name'] as String? ?? '',
        petSpecies: json['pet_species'] as String? ?? 'other',
        localityCode: json['locality_code'] as String? ?? '',
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String).toLocal(),
        lastSeenPlace: json['last_seen_place'] as String? ?? '',
        postId: json['post_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

/// Everything Lost mode's first step asks for.
class LostStart {
  const LostStart({
    required this.petId,
    required this.localityCode,
    required this.seenAt,
    this.place = '',
    this.note = '',
    this.language = 'he',
    this.photoPath,
    this.areaName = '',
  });

  final String petId;

  /// A locality code of the app's list (`lib/services/findvet/regions`).
  final String localityCode;
  final DateTime seenAt;

  /// A public place, up to 120 characters ("the bridge in Yarkon Park").
  final String place;

  /// Up to 300 characters ("Shy, please do not chase her").
  final String note;

  /// The post's fixed words: 'he' or 'en'.
  final String language;

  /// A photo already uploaded for the post (community-photos, the
  /// caller's folder); `null` posts without one.
  final String? photoPath;

  /// The locality's name in [language], for the post's text.
  final String areaName;
}

/// Why Lost mode refused.
enum LostAlertFailure {
  /// The pet has an open alert already.
  alreadyActive,

  /// Three alerts today already.
  rateLimited,

  /// Something in the request is not right (place too long, a time in the
  /// future, a pet of another household).
  invalid,

  /// The account may not do this.
  notAllowed,

  /// Anything else (offline, the server).
  unknown,
}

class LostAlertException implements Exception {
  const LostAlertException(this.failure, [this.detail]);

  final LostAlertFailure failure;
  final Object? detail;

  @override
  String toString() => 'LostAlertException(${failure.name}, $detail)';
}
