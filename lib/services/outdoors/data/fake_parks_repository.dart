import '../../findvet/regions/region.dart';
import 'park_area.dart';
import 'park_models.dart';
import 'parks_repository.dart';

/// In memory, for the demo (no backend) and the tests.
///
/// The sample parks are made up: invented places around Ra'anana, Kfar
/// Saba, Tel Aviv-Yafo and Jerusalem, some named and some named after a
/// street, with details known and unknown, one closed for renovation. The
/// list shows a "sample parks" note while this repository is in use. One
/// member suggestion waits for review.
class FakeParksRepository implements ParksRepository {
  FakeParksRepository({
    this.latency = const Duration(milliseconds: 300),
    List<DogPark>? parks,
    Set<String>? favorites,
    List<ParkSuggestion>? pending,
    List<DogPark>? vanished,
    DateTime Function()? now,
  }) : parkList = parks ?? demoParks(),
       favoriteSet = favorites ?? <String>{},
       pendingSuggestions = pending ?? demoSuggestions(),
       vanishedParks = vanished ?? <DogPark>[],
       _now = now ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _now;

  final List<DogPark> parkList;
  final Set<String> favoriteSet;
  final List<ParkSuggestion> pendingSuggestions;
  final List<DogPark> vanishedParks;

  /// Test hook: every call fails with this.
  Object? failure;

  /// Test hook: suggestions fail with this.
  ParkFailure? suggestFailure;

  /// Every query received (what tests check: never the phone's position).
  final queries = <ParkQuery>[];

  /// Every suggestion sent, as the server would store it.
  final sentSuggestions = <Map<String, Object?>>[];

  /// Every review action, as "action:target".
  final reviewActions = <String>[];

  int _next = 1;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failure != null) throw failure!;
  }

  bool _shown(DogPark p) =>
      p.status == ParkStatus.active || p.status == ParkStatus.closed;

  @override
  bool get isDemo => true;

  @override
  Future<List<DogPark>> parks(ParkQuery query) async {
    queries.add(query);
    await _wait();
    return [
      for (final p in parkList)
        if (_shown(p) &&
            (query.localityCode != null
                ? p.localityCode == query.localityCode
                : query.box!.contains(p.point)))
          p,
    ];
  }

  @override
  Future<List<DogPark>> parksByIds(Iterable<String> ids) async {
    await _wait();
    final wanted = ids.toSet();
    return [
      for (final p in parkList)
        if (_shown(p) && wanted.contains(p.id)) p,
    ];
  }

  @override
  Future<DogPark?> park(String id) async {
    await _wait();
    for (final p in parkList) {
      if (p.id == id && _shown(p)) return p;
    }
    return null;
  }

  @override
  Future<Set<String>> favoriteIds() async {
    await _wait();
    return Set.of(favoriteSet);
  }

  @override
  Future<void> setFavorite(String parkId, bool saved) async {
    await _wait();
    saved ? favoriteSet.add(parkId) : favoriteSet.remove(parkId);
  }

  Future<void> _suggest(Map<String, Object?> row) async {
    await _wait();
    if (suggestFailure != null) throw ParkException(suggestFailure!);
    sentSuggestions.add(row);
  }

  @override
  Future<void> suggestPark(NewParkSuggestion suggestion) async {
    final row = {
      'kind': 'new_park',
      'name': suggestion.name,
      'lat': suggestion.point.lat,
      'lng': suggestion.point.lng,
      'location_kind': suggestion.location.code,
      'locality_code': suggestion.localityCode,
      'place_note': suggestion.placeNote,
      'changes': suggestionChanges(suggestion.details),
    };
    await _suggest(row);
    pendingSuggestions.add(
      ParkSuggestion.fromJson({
        ...row,
        'id': 'demo-suggestion-${_next++}',
        'created_at': _now().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> suggestDetails(
    String parkId,
    Map<ParkDetail, ParkAnswer> changes, {
    bool? closed,
  }) async {
    final row = {
      'kind': 'details',
      'park_id': parkId,
      'changes': suggestionChanges(changes, closed: closed),
    };
    await _suggest(row);
    pendingSuggestions.add(
      ParkSuggestion.fromJson({
        ...row,
        'id': 'demo-suggestion-${_next++}',
        'created_at': _now().toIso8601String(),
      }).withPark(parkList.where((p) => p.id == parkId).firstOrNull),
    );
  }

  @override
  Future<ParkReviewQueue> reviewQueue() async {
    await _wait();
    return ParkReviewQueue(
      suggestions: List.of(pendingSuggestions),
      parks: List.of(vanishedParks),
    );
  }

  @override
  Future<String?> decide(
    String suggestionId, {
    required bool approve,
    Map<String, Object?> edits = const {},
  }) async {
    await _wait();
    final index = pendingSuggestions.indexWhere((s) => s.id == suggestionId);
    if (index < 0) throw const ParkException(ParkFailure.other);
    final s = pendingSuggestions.removeAt(index);
    reviewActions.add('${approve ? 'approve' : 'reject'}:$suggestionId');
    if (!approve) return null;
    if (s.kind == SuggestionKind.details) {
      final i = parkList.indexWhere((p) => p.id == s.park?.id);
      if (i < 0) return null;
      final park = parkList[i];
      parkList[i] = park.copyWith(
        details: {...park.details, ...s.changes},
        status: switch (s.closed) {
          true => ParkStatus.closed,
          false => ParkStatus.active,
          null => park.status,
        },
      );
      return park.id;
    }
    final id = 'demo-park-${_next++}';
    final name = (edits['name'] as String?) ?? s.name;
    final hebrew = name != null && RegExp('[א-ת]').hasMatch(name);
    parkList.add(
      DogPark(
        id: id,
        source: ParkSource.member,
        nameHe: hebrew ? name : null,
        nameEn: hebrew ? null : name,
        streetEn: s.placeNote,
        point: GeoPoint(
          (edits['lat'] as num?)?.toDouble() ?? s.point!.lat,
          (edits['lng'] as num?)?.toDouble() ?? s.point!.lng,
        ),
        localityCode: s.localityCode,
        details: s.changes,
      ),
    );
    return id;
  }

  @override
  Future<void> setParkStatus(String parkId, ParkStatus status) async {
    await _wait();
    reviewActions.add('status:$parkId:${status.code}');
    final vanished = vanishedParks.indexWhere((p) => p.id == parkId);
    if (vanished >= 0) {
      final park = vanishedParks.removeAt(vanished);
      parkList.add(park.copyWith(status: status));
      return;
    }
    final i = parkList.indexWhere((p) => p.id == parkId);
    if (i >= 0) parkList[i] = parkList[i].copyWith(status: status);
  }

  /// The sample parks (made-up places).
  static List<DogPark> demoParks() => [
    _park('demo-raanana-ahuza', 32.1866, 34.8722, 'raanana',
        streetHe: 'אחוזה', streetEn: 'Ahuza',
        yes: [ParkDetail.fenced, ParkDetail.water, ParkDetail.lighting],
        no: [ParkDetail.smallDogs]),
    _park('demo-raanana-park', 32.1902, 34.8648, 'raanana',
        nameHe: 'גינת הכלבים בפארק רעננה', nameEn: "Ra'anana Park dog run",
        yes: [ParkDetail.fenced, ParkDetail.smallDogs, ParkDetail.shade, ParkDetail.water],
        hours: '06:00-23:00'),
    _park('demo-raanana-nesiim', 32.1781, 34.8806, 'raanana',
        streetHe: 'הנשיאים', streetEn: "HaNesi'im"),
    _park('demo-kfarsaba-weizmann', 32.1768, 34.9047, 'kfar-saba',
        streetHe: 'ויצמן', streetEn: 'Weizmann', yes: [ParkDetail.fenced]),
    _park('demo-kfarsaba-garden', 32.1702, 34.9118, 'kfar-saba',
        nameHe: 'גינת הכלבים בגן העיר', nameEn: 'City Garden dog park',
        yes: [ParkDetail.fenced, ParkDetail.smallDogs, ParkDetail.water],
        status: ParkStatus.closed),
    _park('demo-tlv-meir', 32.0741, 34.7738, 'tel-aviv-yafo',
        nameHe: 'גינת הכלבים בגן מאיר', nameEn: 'Meir Garden dog run',
        yes: [ParkDetail.fenced, ParkDetail.water, ParkDetail.shade, ParkDetail.lighting, ParkDetail.benches]),
    _park('demo-tlv-dizengoff', 32.0868, 34.7746, 'tel-aviv-yafo',
        streetHe: 'דיזנגוף', streetEn: 'Dizengoff',
        yes: [ParkDetail.water], no: [ParkDetail.fenced]),
    _park('demo-tlv-yarkon', 32.0979, 34.8012, 'tel-aviv-yafo',
        nameHe: 'גינת הכלבים בפארק הירקון', nameEn: 'Yarkon Park dog run',
        yes: [ParkDetail.fenced, ParkDetail.lighting, ParkDetail.benches], no: [ParkDetail.shade]),
    _park('demo-jlm-refaim', 31.7593, 35.2188, 'jerusalem',
        nameHe: 'גינת הכלבים בעמק רפאים', nameEn: 'Emek Refaim dog park',
        yes: [ParkDetail.fenced], no: [ParkDetail.lighting]),
    _park('demo-jlm-herzl', 31.7769, 35.1896, 'jerusalem',
        streetHe: 'הרצל', streetEn: 'Herzl'),
  ];

  /// One member's suggestion: shade at the Ahuza park.
  static List<ParkSuggestion> demoSuggestions() => [
    ParkSuggestion(
      id: 'demo-suggestion-shade',
      kind: SuggestionKind.details,
      createdAt: DateTime(2026, 10, 9, 18, 30),
      park: demoParks().first,
      changes: const {ParkDetail.shade: ParkAnswer.yes},
    ),
  ];

  static DogPark _park(
    String id,
    double lat,
    double lng,
    String locality, {
    String? nameHe,
    String? nameEn,
    String? streetHe,
    String? streetEn,
    List<ParkDetail> yes = const [],
    List<ParkDetail> no = const [],
    String? hours,
    ParkStatus status = ParkStatus.active,
  }) => DogPark(
    id: id,
    point: GeoPoint(lat, lng),
    nameHe: nameHe,
    nameEn: nameEn,
    streetHe: streetHe,
    streetEn: streetEn,
    localityCode: locality,
    details: {
      for (final d in yes) d: ParkAnswer.yes,
      for (final d in no) d: ParkAnswer.no,
    },
    openingHours: hours,
    status: status,
  );
}

extension on ParkSuggestion {
  ParkSuggestion withPark(DogPark? park) => ParkSuggestion(
    id: id,
    kind: kind,
    createdAt: createdAt,
    park: park,
    changes: changes,
    closed: closed,
  );
}
