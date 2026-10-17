import 'lost_alert_models.dart';
import 'lost_alerts_repository.dart';

/// Lost mode in memory, with the server's rules: one open alert per pet,
/// three a day per account. Seeded with one neighbour's alert in Tel Aviv;
/// the demo pets are all at home.
class FakeLostAlertsRepository implements LostAlertsRepository {
  FakeLostAlertsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    this.ownerId = 'demo',
    this.petFacts,
    this.postWriter,
    bool seeded = true,
  }) : _now = now ?? DateTime.now {
    if (seeded) {
      final at = _now();
      _nearby.add(
        NearbyLostAlert(
          id: 'lost-nearby-1',
          petName: 'Mitzi',
          petSpecies: 'cat',
          localityCode: 'tel-aviv-yafo',
          lastSeenAt: at.subtract(const Duration(hours: 5)),
          lastSeenPlace: 'Dizengoff Square',
          postId: 'post-lost-nearby-1',
          createdAt: at.subtract(const Duration(hours: 4)),
        ),
      );
    }
  }

  final Duration latency;
  final DateTime Function() _now;

  /// Who starts alerts here.
  final String ownerId;

  /// The pet's name and kind, as the server copies them from `pets`.
  final ({String name, String species}) Function(String petId)? petFacts;

  /// Writes the alert's post (the demo's fake feed) and gives its id;
  /// without it the post is only an id.
  final Future<String?> Function(LostAlert alert)? postWriter;

  /// Makes every call fail, for error states in tests.
  bool failing = false;

  final _alerts = <LostAlert>[];
  final _nearby = <NearbyLostAlert>[];
  var _next = 1;

  /// Every alert, open or closed (tests).
  List<LostAlert> get alerts => List.unmodifiable(_alerts);

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failing) throw const LostAlertException(LostAlertFailure.unknown);
  }

  /// A neighbour comments on the alert's post (tests and the demo).
  void addSighting(String alertId) {
    final i = _alerts.indexWhere((a) => a.id == alertId);
    if (i >= 0) {
      _alerts[i] = _alerts[i].copyWith(sightings: _alerts[i].sightings + 1);
    }
  }

  @override
  Future<List<LostAlert>> mine() async {
    await _wait();
    return [
      for (final a in _alerts.reversed)
        if (a.isActive) a,
    ];
  }

  @override
  Future<List<NearbyLostAlert>> near(String localityCode) async {
    await _wait();
    return [
      for (final a in _nearby)
        if (a.localityCode == localityCode) a,
      for (final a in _alerts.reversed)
        if (a.isActive && a.localityCode == localityCode)
          NearbyLostAlert(
            id: a.id,
            petName: a.petName,
            petSpecies: a.petSpecies,
            localityCode: a.localityCode,
            lastSeenAt: a.lastSeenAt,
            lastSeenPlace: a.lastSeenPlace,
            postId: a.postId,
            createdAt: a.createdAt,
          ),
    ];
  }

  @override
  Future<LostAlert> start(LostStart request) async {
    await _wait();
    final now = _now();
    if (!RegExp(r'^[a-z0-9-]{2,60}$').hasMatch(request.localityCode) ||
        request.place.trim().length > 120 ||
        request.note.trim().length > 300 ||
        request.seenAt.isAfter(now.add(const Duration(minutes: 5)))) {
      throw const LostAlertException(LostAlertFailure.invalid);
    }
    if (_alerts.any((a) => a.petId == request.petId && a.isActive)) {
      throw const LostAlertException(LostAlertFailure.alreadyActive);
    }
    final today = _alerts.where(
      (a) => now.difference(a.createdAt) < const Duration(days: 1),
    );
    if (today.length >= 3) {
      throw const LostAlertException(LostAlertFailure.rateLimited);
    }
    final n = _next++;
    final facts = petFacts?.call(request.petId);
    final alert = LostAlert(
      id: 'lost-$n',
      petId: request.petId,
      ownerId: ownerId,
      petName: facts?.name ?? request.petId,
      petSpecies: facts?.species ?? 'other',
      localityCode: request.localityCode,
      lastSeenAt: request.seenAt.isAfter(now) ? now : request.seenAt,
      lastSeenPlace: request.place.trim(),
      note: request.note.trim(),
      language: request.language,
      postId: 'post-lost-$n',
      createdAt: now,
    );
    final postId = await postWriter?.call(alert);
    final posted = postId == null
        ? alert
        : LostAlert(
            id: alert.id,
            petId: alert.petId,
            ownerId: alert.ownerId,
            petName: alert.petName,
            petSpecies: alert.petSpecies,
            localityCode: alert.localityCode,
            lastSeenAt: alert.lastSeenAt,
            createdAt: alert.createdAt,
            lastSeenPlace: alert.lastSeenPlace,
            note: alert.note,
            language: alert.language,
            postId: postId,
          );
    _alerts.add(posted);
    return posted;
  }

  Future<LostAlert> _close(String alertId, LostAlertStatus status) async {
    await _wait();
    final i = _alerts.indexWhere((a) => a.id == alertId);
    if (i < 0) throw const LostAlertException(LostAlertFailure.invalid);
    final alert = _alerts[i];
    if (!alert.isActive) return alert;
    final closed = alert.copyWith(
      status: status,
      closedAt: _now(),
      // A cancelled alert nobody answered takes its post with it.
      clearPost: status == LostAlertStatus.cancelled && alert.sightings == 0,
    );
    _alerts[i] = closed;
    return closed;
  }

  @override
  Future<LostAlert> markFound(String alertId) =>
      _close(alertId, LostAlertStatus.found);

  @override
  Future<LostAlert> cancel(String alertId) =>
      _close(alertId, LostAlertStatus.cancelled);
}
