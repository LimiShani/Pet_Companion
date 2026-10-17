import '../../../models/pet.dart';
import '../../community/data/community_models.dart' show ReportReason;
import '../../community/data/fake_chat_repository.dart';
import '../../outdoors/data/fake_parks_repository.dart';
import '../../outdoors/data/park_models.dart';
import 'meetup_models.dart';
import 'meetups_repository.dart';

/// In-memory ads for development and tests, with the server's rules (the
/// daily and open limits, editing only open ads, renewing only recurring
/// ones, no answer to one's own ad or across a block, three reports hide;
/// "going out now" ads: three a day of their own, one open at a time,
/// never edited).
///
/// Seeded (unless [seed] is false) with made-up ads around Ra'anana, Kfar
/// Saba and Tel Aviv-Yafo, at the fake parks and elsewhere, written by the
/// fake chat's people (so "I want to join" opens a real fake chat), and two
/// of the demo account's own: one open with two answers, one ended.
class FakeMeetupsRepository implements MeetupsRepository {
  FakeMeetupsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    String Function()? viewerId,
    List<DogPark>? parks,
    bool seed = true,
    bool goingNowSample = false,
  }) : _now = now ?? DateTime.now,
       _viewer = viewerId ?? (() => 'demo'),
       parks = parks ?? FakeParksRepository.demoParks() {
    if (seed) _seed();
    if (seed && goingNowSample) _seedGoingNow();
  }

  final Duration latency;
  final DateTime Function() _now;
  final String Function() _viewer;

  /// The parks ads can be at (the fake parks by default).
  final List<DogPark> parks;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  final ads = <Meetup>[];

  /// Who answered which ad, and when.
  final answers = <String, Map<String, DateTime>>{};

  /// Reports: ad id to the reporters.
  final reports = <String, Map<String, ReportReason>>{};

  /// Blocks, as (blocker, blocked).
  final blocks = <(String, String)>{};

  /// Saved parks with "Tell me about new meetups here" on.
  final notify = <String>{};

  /// What [save] was sent, for tests.
  final saved = <MeetupDraft>[];
  var _next = 1;

  static final _names = {
    for (final (id, name, _) in FakeChatRepository.samplePeople) id: name,
  };

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failing) throw const MeetupException(MeetupFailure.unavailable);
  }

  bool _blockedEitherWay(String a, String b) =>
      blocks.contains((a, b)) || blocks.contains((b, a));

  /// The ad as [viewer] sees it, or `null` when they may not.
  Meetup? _seen(Meetup ad, String viewer, {bool liveOnly = true}) {
    final own = ad.authorId == viewer;
    if (!own) {
      if (!ad.isLiveAt(_now())) return null;
      if (blocks.contains((viewer, ad.authorId))) return null;
      if (reports[ad.id]?.containsKey(viewer) ?? false) return null;
    } else if (liveOnly && !ad.isLiveAt(_now())) {
      return null;
    }
    return ad.copyWith(
      answered: answers[ad.id]?.containsKey(viewer) ?? false,
      answerCount: answers[ad.id]?.length ?? ad.answerCount,
    );
  }

  List<Meetup> _visible(bool Function(Meetup ad) where) {
    final viewer = _viewer();
    return [
      for (final ad in ads)
        if (where(ad)) ?_seen(ad, viewer),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  bool get isDemo => true;

  @override
  Future<List<Meetup>> openMeetups(Iterable<String> localityCodes) async {
    await _wait();
    final codes = localityCodes.toSet();
    return _visible((ad) => codes.contains(ad.localityCode));
  }

  @override
  Future<List<Meetup>> atParks(Iterable<String> parkIds) async {
    await _wait();
    final ids = parkIds.toSet();
    return _visible((ad) => ids.contains(ad.parkId));
  }

  @override
  Future<List<Meetup>> byAuthor(String authorId) async {
    await _wait();
    return _visible((ad) => ad.authorId == authorId);
  }

  @override
  Future<List<Meetup>> mine() async {
    await _wait();
    final viewer = _viewer();
    return [
      for (final ad in ads)
        if (ad.authorId == viewer) ?_seen(ad, viewer, liveOnly: false),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Meetup?> meetup(String id) async {
    await _wait();
    final viewer = _viewer();
    for (final ad in ads) {
      if (ad.id == id) return _seen(ad, viewer, liveOnly: ad.authorId != viewer);
    }
    return null;
  }

  int _index(String id) {
    final i = ads.indexWhere((ad) => ad.id == id && ad.authorId == _viewer());
    if (i < 0) throw const MeetupException(MeetupFailure.invalid);
    return i;
  }

  /// Planned ads open and not ended (hidden ones count too), as the server
  /// counts.
  int get _openCount => ads
      .where((ad) => ad.authorId == _viewer() && !ad.isGoingNow && _isOpen(ad))
      .length;

  bool _isOpen(Meetup ad) =>
      ad.status == MeetupStatus.open && ad.expiresAt.isAfter(_now());

  @override
  Future<String> save(MeetupDraft draft, {String? id}) async {
    await _wait();
    final now = _now();
    if (draftProblems(draft, now).isNotEmpty) {
      throw const MeetupException(MeetupFailure.invalid);
    }
    DogPark? park;
    if (draft.parkId != null) {
      park = parks
          .where((p) => p.id == draft.parkId && p.status == ParkStatus.active)
          .firstOrNull;
      if (park == null) throw const MeetupException(MeetupFailure.invalid);
    }
    final goingNow = draft.time is NowTime;
    Meetup? old;
    if (id != null) {
      old = ads[_index(id)];
      if (old.status != MeetupStatus.open || !old.expiresAt.isAfter(now)) {
        throw const MeetupException(MeetupFailure.notOpen);
      }
      // A "now" ad is closed and posted again, never edited.
      if (goingNow || old.isGoingNow) {
        throw const MeetupException(MeetupFailure.invalid);
      }
    } else {
      final today = ads.where(
        (ad) =>
            ad.authorId == _viewer() &&
            ad.isGoingNow == goingNow &&
            ad.createdAt.isAfter(now.subtract(const Duration(days: 1))),
      );
      if (today.length >=
          (goingNow ? MeetupLimits.nowPerDay : MeetupLimits.newPerDay)) {
        throw const MeetupException(MeetupFailure.rateLimited);
      }
      if (!goingNow && _openCount >= MeetupLimits.open) {
        throw const MeetupException(MeetupFailure.tooManyOpen);
      }
      if (goingNow) {
        // One at a time: the earlier one is closed.
        for (var i = 0; i < ads.length; i++) {
          final ad = ads[i];
          if (ad.authorId == _viewer() &&
              ad.isGoingNow &&
              ad.status == MeetupStatus.open) {
            ads[i] = ad.copyWith(status: MeetupStatus.closed);
          }
        }
      }
    }
    saved.add(draft);
    final time = draft.time;
    final ad = Meetup(
      id: id ?? 'meetup-${_next++}',
      authorId: _viewer(),
      authorName: _names[_viewer()] ?? 'Alex',
      kind: draft.kind,
      pet: draft.pet,
      parkId: park?.id,
      park: park,
      localityCode: park?.localityCode ?? draft.localityCode!,
      placeText: park == null ? draft.placeText!.trim() : null,
      time: time,
      suits: draft.suits.length == PetSize.values.length ? const {} : draft.suits,
      note: draft.note.trim(),
      createdAt: old?.createdAt ?? now,
      expiresAt: switch (time) {
        OneOffTime(:final end) => end,
        RecurringTime() when old != null && old.isRecurring => old.expiresAt,
        RecurringTime() => now.add(const Duration(days: MeetupLimits.recurringDays)),
      },
      answerCount: old?.answerCount ?? 0,
    );
    if (id == null) {
      ads.add(ad);
    } else {
      ads[_index(id)] = ad;
    }
    return ad.id;
  }

  @override
  Future<void> close(String id) async {
    await _wait();
    final i = _index(id);
    ads[i] = ads[i].copyWith(status: MeetupStatus.closed);
  }

  @override
  Future<void> renew(String id) async {
    await _wait();
    final i = _index(id);
    final ad = ads[i];
    if (!ad.isRecurring || ad.hidden) {
      throw const MeetupException(MeetupFailure.invalid);
    }
    if (!_isOpen(ad) && _openCount >= MeetupLimits.open) {
      throw const MeetupException(MeetupFailure.tooManyOpen);
    }
    ads[i] = ad.copyWith(
      status: MeetupStatus.open,
      expiresAt: _now().add(const Duration(days: MeetupLimits.recurringDays)),
    );
  }

  @override
  Future<int> answer(String id) async {
    await _wait();
    final viewer = _viewer();
    final ad = ads.where((a) => a.id == id).firstOrNull;
    if (ad == null || !ad.isLiveAt(_now())) {
      throw const MeetupException(MeetupFailure.notOpen);
    }
    if (ad.authorId == viewer) {
      throw const MeetupException(MeetupFailure.invalid);
    }
    if (_blockedEitherWay(viewer, ad.authorId)) {
      throw const MeetupException(MeetupFailure.blocked);
    }
    final who = answers.putIfAbsent(id, () => {});
    who.putIfAbsent(viewer, _now);
    return who.length;
  }

  @override
  Future<List<MeetupResponder>> responders(String id) async {
    await _wait();
    final ad = ads[_index(id)];
    final who = answers[ad.id] ?? const {};
    return [
      for (final MapEntry(key: user, value: at) in who.entries)
        if (!_blockedEitherWay(user, ad.authorId))
          MeetupResponder(id: user, name: _names[user] ?? '', answeredAt: at),
    ]..sort((a, b) => b.answeredAt.compareTo(a.answeredAt));
  }

  @override
  Future<void> report(String id, ReportReason reason) async {
    await _wait();
    final by = reports.putIfAbsent(id, () => {});
    by[_viewer()] = reason;
    if (by.length >= 3) {
      final i = ads.indexWhere((ad) => ad.id == id);
      if (i >= 0) ads[i] = ads[i].copyWith(hidden: true);
    }
  }

  @override
  Future<Set<String>> notifyParkIds() async {
    await _wait();
    return {...notify};
  }

  @override
  Future<void> setNotify(String parkId, bool on) async {
    await _wait();
    on ? notify.add(parkId) : notify.remove(parkId);
  }

  /// A sample "going out now" ad: Noa leaves for the Ra'anana park in 25
  /// minutes (the demo app shows it; tests opt in).
  void _seedGoingNow() {
    final now = _now();
    final park = parks.where((p) => p.id == 'demo-raanana-park').firstOrNull;
    if (park == null) return;
    ads.add(
      Meetup(
        id: 'demo-meetup-now',
        authorId: 'u-noa',
        authorName: _names['u-noa'] ?? '',
        kind: MeetupKind.walk,
        pet: const MeetupPet(
          name: 'Bagel',
          species: PetSpecies.dog,
          breed: 'Beagle',
          size: PetSize.small,
          iconKey: 'dog_floppy:peach',
        ),
        parkId: park.id,
        park: park,
        localityCode: park.localityCode ?? 'raanana',
        time: NowTime(
          now.add(const Duration(minutes: 25)),
          now.add(const Duration(minutes: 85)),
        ),
        note: 'A slow loop around the lawn.',
        createdAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(minutes: 85)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sample ads (made up), relative to the clock.
  // -------------------------------------------------------------------------
  void _seed() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    DogPark park(String id) => parks.firstWhere((p) => p.id == id);
    DateTime at(DateTime day, int hour) =>
        DateTime(day.year, day.month, day.day, hour);
    // The next Saturday (today when it is Saturday and still morning).
    var saturday = today;
    while (saturday.weekday != DateTime.saturday ||
        !at(saturday, 12).isAfter(now)) {
      saturday = DateTime(saturday.year, saturday.month, saturday.day + 1);
    }
    // This evening, or tomorrow evening once it is past.
    final evening = at(today, 19).isAfter(now)
        ? today
        : DateTime(today.year, today.month, today.day + 1);
    DateTime born(int months) =>
        DateTime(now.year, now.month - months, now.day);

    Meetup ad(
      String id,
      String author,
      MeetupKind kind,
      MeetupTime time, {
      MeetupPet? pet,
      String? parkId,
      String? locality,
      String? place,
      Set<PetSize> suits = const {},
      String note = '',
      Duration age = const Duration(hours: 2),
      DateTime? expires,
    }) {
      final p = parkId == null ? null : park(parkId);
      final created = now.subtract(age);
      return Meetup(
        id: id,
        authorId: author,
        authorName: _names[author] ?? '',
        kind: kind,
        pet: pet,
        parkId: p?.id,
        park: p,
        localityCode: p?.localityCode ?? locality!,
        placeText: place,
        time: time,
        suits: suits,
        note: note,
        createdAt: created,
        expiresAt:
            expires ??
            switch (time) {
              OneOffTime(:final end) => end,
              RecurringTime() => created.add(
                const Duration(days: MeetupLimits.recurringDays),
              ),
            },
      );
    }

    ads.addAll([
      ad(
        'demo-meetup-sam',
        'u-sam',
        MeetupKind.walk,
        const RecurringTime({7, 1, 2, 3, 4}, DayPart.morning),
        pet: MeetupPet(
          name: 'Pepper',
          species: PetSpecies.dog,
          breed: 'Mixed',
          bornOn: born(36),
          bornApprox: true,
          size: PetSize.medium,
          iconKey: 'dog_floppy:sage',
        ),
        parkId: 'demo-raanana-park',
        note:
            "Looking for a steady partner for an hour's morning walk. Pepper "
            'is calm and gets on with everyone.',
      ),
      ad(
        'demo-meetup-maya',
        'u-maya',
        MeetupKind.play,
        OneOffTime(at(saturday, 10), at(saturday, 12)),
        pet: MeetupPet(
          name: 'Biscuit',
          species: PetSpecies.dog,
          breed: 'Poodle',
          bornOn: born(5),
          size: PetSize.small,
          iconKey: 'dog_pointy:peach',
        ),
        parkId: 'demo-kfarsaba-weizmann',
        suits: const {PetSize.small},
        note: 'A playdate for puppies up to a year old.',
        age: const Duration(days: 1),
      ),
      ad(
        'demo-meetup-dana',
        'u-dana',
        MeetupKind.walk,
        const RecurringTime({5, 6}, DayPart.morning),
        locality: 'raanana',
        place: 'The path along Ahuza Park',
        note: "No dog of my own yet: happy to join someone's morning walk.",
        age: const Duration(days: 1, hours: 4),
      ),
      ad(
        'demo-meetup-priya',
        'u-priya',
        MeetupKind.play,
        OneOffTime(at(evening, 18), at(evening, 19)),
        pet: MeetupPet(
          name: 'Chico',
          species: PetSpecies.dog,
          breed: 'Chihuahua',
          bornOn: born(26),
          size: PetSize.small,
        ),
        parkId: 'demo-tlv-meir',
        suits: const {PetSize.small, PetSize.medium},
        note: 'Small dogs welcome, we bring a ball.',
        age: const Duration(hours: 3),
      ),
      ad(
        'demo-meetup-noa',
        'u-noa',
        MeetupKind.walk,
        const RecurringTime({1, 3}, DayPart.evening),
        pet: MeetupPet(
          name: 'Milo',
          species: PetSpecies.dog,
          breed: 'Labrador',
          bornOn: born(80),
          size: PetSize.large,
          iconKey: 'dog_floppy:yellow',
        ),
        locality: 'tel-aviv-yafo',
        place: 'Yarkon Park, by the Seven Mills',
        note: 'Slow evening walks: Milo is a gentle old man.',
        age: const Duration(days: 5),
      ),
      ad(
        'demo-meetup-jonas',
        'u-jonas',
        MeetupKind.walk,
        const RecurringTime({6}, DayPart.noon),
        pet: MeetupPet(
          name: 'Luna',
          species: PetSpecies.cat,
          bornOn: born(30),
          iconKey: 'cat_tabby:sage',
        ),
        locality: 'tel-aviv-yafo',
        place: 'The lawn at Meir Garden',
        note: 'Luna walks on a harness and likes calm company.',
        age: const Duration(days: 2),
      ),
      ad(
        'demo-meetup-mine',
        'demo',
        MeetupKind.walk,
        const RecurringTime({7, 2, 4}, DayPart.evening),
        pet: const MeetupPet(
          petId: 'kelly',
          name: 'Kelly',
          species: PetSpecies.dog,
          breed: 'Mix',
          size: PetSize.medium,
        ),
        parkId: 'demo-tlv-yarkon',
        note: 'An evening walk around the lawns, all sizes welcome.',
        age: const Duration(days: 6),
      ),
      ad(
        'demo-meetup-mine-ended',
        'demo',
        MeetupKind.play,
        const RecurringTime({6}, DayPart.morning),
        pet: const MeetupPet(petId: 'soya', name: 'Soya', species: PetSpecies.dog),
        parkId: 'demo-tlv-meir',
        note: 'Saturday play in the morning.',
        age: const Duration(days: 32),
        expires: now.subtract(const Duration(days: 2)),
      ),
    ]);
    answers['demo-meetup-mine'] = {
      'u-maya': now.subtract(const Duration(days: 2)),
      'u-sam': now.subtract(const Duration(hours: 20)),
    };
    answers['demo-meetup-sam'] = {
      'u-priya': now.subtract(const Duration(hours: 1)),
    };
    answers['demo-meetup-maya'] = {
      'u-noa': now.subtract(const Duration(hours: 9)),
      'u-dana': now.subtract(const Duration(hours: 7)),
      'u-jonas': now.subtract(const Duration(hours: 5)),
    };
  }
}
