import 'park_models.dart';

/// Hazard reports (Outside): "caterpillars at Yarkon park", "poison bait
/// by the river path". The database is `0035_neighbourhood.sql`; design in
/// docs/hazards.md.

/// What was seen. [key] is what the database stores.
enum HazardKind {
  caterpillars('caterpillars'),
  bait('bait'),
  glass('glass'),
  inspector('inspector'),
  other('other');

  const HazardKind(this.key);

  final String key;

  static HazardKind? parse(Object? value) {
    for (final kind in values) {
      if (kind.key == '$value') return kind;
    }
    return null;
  }
}

/// The limits the server holds (and the fake follows).
abstract final class HazardLimits {
  static const note = 140;

  /// New reports per account a day.
  static const perDay = 5;

  /// A report shows for this long.
  static const days = 7;

  /// "Not there any more" from this many others hides it.
  static const goneToHide = 2;
}

/// One report, as the reader sees it.
class HazardReport {
  const HazardReport({
    required this.id,
    required this.localityCode,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
    this.parkId,
    this.park,
    this.note = '',
    this.mine = false,
    this.hidden = false,
    this.stillCount = 0,
    this.goneCount = 0,
    this.myVote,
  });

  final String id;

  /// The city (a code of the bundled localities list).
  final String localityCode;

  /// The park, when it is at one; [park] is `null` when the reader cannot
  /// see the park.
  final String? parkId;
  final DogPark? park;
  final HazardKind kind;
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// The reader wrote it (and may delete it).
  final bool mine;

  /// Hidden by "not there any more" votes (only its author still sees it).
  final bool hidden;
  final int stillCount;
  final int goneCount;

  /// The reader's vote: `true` "not there any more", `false` "still
  /// there", `null` none.
  final bool? myVote;

  /// Shown to members at [now]: not hidden, not expired.
  bool isCurrentAt(DateTime now) => !hidden && expiresAt.isAfter(now);

  HazardReport copyWith({
    bool? mine,
    bool? hidden,
    int? stillCount,
    int? goneCount,
    bool? Function()? myVote,
  }) => HazardReport(
    id: id,
    localityCode: localityCode,
    kind: kind,
    createdAt: createdAt,
    expiresAt: expiresAt,
    parkId: parkId,
    park: park,
    note: note,
    mine: mine ?? this.mine,
    hidden: hidden ?? this.hidden,
    stillCount: stillCount ?? this.stillCount,
    goneCount: goneCount ?? this.goneCount,
    myVote: myVote == null ? this.myVote : myVote(),
  );
}

/// What the report form sends: a kind, a park or a city, a short note.
class HazardDraft {
  const HazardDraft({
    required this.kind,
    this.parkId,
    this.localityCode,
    this.note = '',
  });

  final HazardKind kind;
  final String? parkId;

  /// The city, when not at a park ("somewhere else in Petah Tikva").
  final String? localityCode;
  final String note;

  /// Whether the server would take it ("other" says what it is).
  bool get isComplete =>
      (parkId != null || localityCode != null) &&
      note.trim().length <= HazardLimits.note &&
      (kind != HazardKind.other || note.trim().isNotEmpty);
}

enum HazardFailure {
  /// Five reports today already.
  rateLimited,

  /// The report is gone, hidden or expired.
  notOpen,

  /// The server refused what was sent.
  invalid,

  /// No connection, or the server is down.
  unavailable,

  /// Anything else (no access).
  other,
}

class HazardException implements Exception {
  const HazardException(this.failure);
  final HazardFailure failure;

  @override
  String toString() => 'HazardException(${failure.name})';
}
