import 'fake_parks_repository.dart';
import 'hazard_models.dart';
import 'hazards_repository.dart';
import 'park_models.dart';

/// In-memory hazard reports for development and tests, with the server's
/// rules (five a day, no vote on one's own report, two "not there any
/// more" from others hide it, only the author deletes, seven days).
///
/// Seeded (unless [seed] is false) with made-up reports around Ra'anana,
/// Kfar Saba and Tel Aviv-Yafo, at the fake parks and elsewhere.
class FakeHazardsRepository implements HazardsRepository {
  FakeHazardsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    String Function()? viewerId,
    List<DogPark>? parks,
    bool seed = true,
  }) : _now = now ?? DateTime.now,
       _viewer = viewerId ?? (() => 'demo'),
       parks = parks ?? FakeParksRepository.demoParks() {
    if (seed) _seed();
  }

  final Duration latency;
  final DateTime Function() _now;
  final String Function() _viewer;

  /// The parks reports can be at (the fake parks by default).
  final List<DogPark> parks;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  /// The reports, with their authors.
  final reports = <(HazardReport, String)>[];

  /// Votes: report id to voter to "gone".
  final votes = <String, Map<String, bool>>{};

  /// What [report] was sent, for tests.
  final sent = <HazardDraft>[];
  var _next = 1;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failing) throw const HazardException(HazardFailure.unavailable);
  }

  HazardReport _seen((HazardReport, String) entry, String viewer) {
    final (report, author) = entry;
    final cast = votes[report.id] ?? const <String, bool>{};
    return report.copyWith(
      stillCount: cast.values.where((gone) => !gone).length,
      goneCount: cast.values.where((gone) => gone).length,
      myVote: () => cast[viewer],
      mine: author == viewer,
    );
  }

  @override
  bool get isDemo => true;

  @override
  Future<List<HazardReport>> current(Iterable<String> localityCodes) async {
    await _wait();
    final codes = localityCodes.toSet();
    final viewer = _viewer();
    final now = _now();
    return [
      for (final entry in reports)
        if (codes.contains(entry.$1.localityCode) &&
            entry.$1.expiresAt.isAfter(now) &&
            (!entry.$1.hidden || entry.$2 == viewer))
          _seen(entry, viewer),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<String> report(HazardDraft draft) async {
    await _wait();
    if (!draft.isComplete) throw const HazardException(HazardFailure.invalid);
    final now = _now();
    final viewer = _viewer();
    DogPark? park;
    if (draft.parkId != null) {
      park = parks.where((p) => p.id == draft.parkId).firstOrNull;
      if (park == null || park.status == ParkStatus.removed) {
        throw const HazardException(HazardFailure.invalid);
      }
    }
    final locality = park?.localityCode ?? draft.localityCode;
    if (locality == null) throw const HazardException(HazardFailure.invalid);
    final today = reports.where(
      (r) =>
          r.$2 == viewer &&
          r.$1.createdAt.isAfter(now.subtract(const Duration(days: 1))),
    );
    if (today.length >= HazardLimits.perDay) {
      throw const HazardException(HazardFailure.rateLimited);
    }
    sent.add(draft);
    final id = 'hazard-${_next++}';
    reports.add((
      HazardReport(
        id: id,
        localityCode: locality,
        parkId: park?.id,
        park: park,
        kind: draft.kind,
        note: draft.note.trim(),
        createdAt: now,
        expiresAt: now.add(const Duration(days: HazardLimits.days)),
      ),
      viewer,
    ));
    return id;
  }

  @override
  Future<bool> vote(String id, {required bool gone}) async {
    await _wait();
    final viewer = _viewer();
    final i = reports.indexWhere((r) => r.$1.id == id);
    if (i < 0 || !reports[i].$1.isCurrentAt(_now())) {
      throw const HazardException(HazardFailure.notOpen);
    }
    final (report, author) = reports[i];
    if (author == viewer) throw const HazardException(HazardFailure.invalid);
    final cast = votes.putIfAbsent(id, () => {});
    cast[viewer] = gone;
    final goneVotes = cast.entries
        .where((e) => e.value && e.key != author)
        .length;
    if (goneVotes >= HazardLimits.goneToHide) {
      reports[i] = (report.copyWith(hidden: true), author);
      return false;
    }
    return true;
  }

  @override
  Future<void> delete(String id) async {
    await _wait();
    final before = reports.length;
    reports.removeWhere((r) => r.$1.id == id && r.$2 == _viewer());
    if (reports.length == before) {
      throw const HazardException(HazardFailure.invalid);
    }
    votes.remove(id);
  }

  // -------------------------------------------------------------------------
  // Sample reports (made up), relative to the clock.
  // -------------------------------------------------------------------------
  void _seed() {
    final now = _now();
    DogPark? park(String id) => parks.where((p) => p.id == id).firstOrNull;
    void add(
      String id,
      String author,
      HazardKind kind, {
      String? parkId,
      String? locality,
      String note = '',
      required Duration age,
    }) {
      final p = parkId == null ? null : park(parkId);
      final code = p?.localityCode ?? locality;
      if (code == null) return;
      final created = now.subtract(age);
      reports.add((
        HazardReport(
          id: id,
          localityCode: code,
          parkId: p?.id,
          park: p,
          kind: kind,
          note: note,
          createdAt: created,
          expiresAt: created.add(const Duration(days: HazardLimits.days)),
        ),
        author,
      ));
    }

    add(
      'demo-hazard-caterpillars',
      'u-sam',
      HazardKind.caterpillars,
      parkId: 'demo-raanana-park',
      note: 'A line of them along the fence by the gate.',
      age: const Duration(hours: 5),
    );
    add(
      'demo-hazard-bait',
      'u-maya',
      HazardKind.bait,
      locality: 'kfar-saba',
      note: 'Sausage pieces by the river path.',
      age: const Duration(days: 1, hours: 2),
    );
    add(
      'demo-hazard-glass',
      'u-noa',
      HazardKind.glass,
      parkId: 'demo-tlv-yarkon',
      note: 'Broken bottle near the benches.',
      age: const Duration(days: 2),
    );
    votes['demo-hazard-caterpillars'] = {'u-dana': false};
  }
}
