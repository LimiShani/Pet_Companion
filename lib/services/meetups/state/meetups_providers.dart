import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/settings_store.dart';
import '../../../platform/session.dart';
import '../../../platform/usage.dart';
import '../../community/data/community_models.dart' show ReportReason;
import '../../community/data/community_providers.dart'
    show communityMembersRepositoryProvider;
import '../../findvet/regions/regions.dart';
import '../../findvet/state/find_vet_providers.dart' show AreaProblem;
import '../../outdoors/data/park_area.dart';
import '../../outdoors/state/parks_providers.dart'
    show OutsideAreaController, outsideAreaProvider, outsideDefaultRadius;
import '../data/fake_meetups_repository.dart';
import '../data/meetup_models.dart';
import '../data/meetups_repository.dart';
import '../data/supabase_meetups_repository.dart';

/// Who may do what with partner ads (`0028_meetups.sql`).
abstract final class MeetupCapabilities {
  static const view = 'community.meetups.view';
  static const post = 'community.meetups.post';
}

/// The clock of the ads (their times, "today", what ended). Tests fix it.
final meetupsClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final meetupsRepositoryProvider = Provider<MeetupsRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseMeetupsRepository(sb.Supabase.instance.client)
      : FakeMeetupsRepository(
          now: ref.watch(meetupsClockProvider),
          viewerId: () => ref.read(authControllerProvider).value?.id ?? 'demo',
          goingNowSample: true,
        ),
);

/// Moves on every change the member makes (a new ad, an answer, a
/// report), so every list of ads loads again.
class MeetupsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final meetupsRevisionProvider = NotifierProvider<MeetupsRevision, int>(
  MeetupsRevision.new,
);

// ---------------------------------------------------------------------------
// The area: a city and how far around it.
// ---------------------------------------------------------------------------

/// Where the board looks: a city of the bundled list and a radius, read
/// from Outside's one area ("Near me" stands for its nearest city).
class MeetupsArea {
  const MeetupsArea(this.city, this.radius);

  final Locality city;
  final ParkRadius radius;

  /// The radius the board starts on.
  static const defaultRadius = outsideDefaultRadius;

  /// The board's view of Outside's [area]: the city, or the city nearest
  /// to "Near me", with the same radius.
  static MeetupsArea? of(ParkArea? area) => switch (area) {
    null => null,
    CityArea(:final locality, :final radius) => MeetupsArea(locality, radius),
    NearMeArea(:final point, :final nearest, :final radius) => switch (
        nearest ?? vetRegionAt(point)?.nearestLocality(point, maxM: 30000)) {
      final city? => MeetupsArea(city, radius),
      null => null,
    },
  };

  /// The localities in range, by their centres: what the server is asked
  /// for (the city itself for "City only").
  List<String> get codes {
    final metres = radius.metres;
    if (metres == null) return [city.code];
    final region = vetRegionAt(city.point);
    final near = region?.localitiesWithin(city.point, metres.toDouble()) ??
        const <Locality>[];
    return {city.code, for (final l in near) l.code}.toList();
  }

  /// "raanana|km10", as kept on the phone.
  String get key => '${city.code}|${radius.name}';

  static MeetupsArea? parse(String? value) {
    if (value == null) return null;
    final parts = value.split('|');
    final city = localityOfCode(parts.first);
    if (city == null) return null;
    final radius = ParkRadius.values.asNameMap()[parts.length > 1 ? parts[1] : ''];
    return MeetupsArea(city, radius ?? ParkRadius.km10);
  }

  @override
  bool operator ==(Object other) =>
      other is MeetupsArea &&
      other.city.code == city.code &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(city.code, radius);
}

class MeetupsAreaState {
  const MeetupsAreaState({
    this.area,
    this.resolving = false,
    this.locating = false,
    this.problem,
  });

  /// `null` until known: then the board asks once.
  final MeetupsArea? area;

  /// Looking up the city to start on (see [MeetupsAreaSeed]).
  final bool resolving;
  final bool locating;
  final AreaProblem? problem;
}

/// Where the board kept its own area before Outside had one: read once,
/// to carry the choice over to Outside's area, then removed.
String meetupsAreaKey(String userId) => 'meetups.area.$userId';

/// The locality a profile's free-text city names, if the bundled list knows
/// it ("Tel Aviv" is Tel Aviv-Yafo).
Locality? localityOfProfileCity(String city) {
  final text = city.trim();
  if (text.length < 2) return null;
  final query = normalizePlaceName(text);
  for (final region in vetRegions) {
    for (final locality in region.findLocalities(text, limit: 6)) {
      final names = [...locality.names.values, ...locality.aliases];
      if (names.any((n) => normalizePlaceName(n) == query)) return locality;
    }
  }
  return null;
}

/// The board's area: Outside's one area ([outsideAreaProvider]), shared
/// with the parks list. Choosing here chooses there.
class MeetupsAreaController extends Notifier<MeetupsAreaState> {
  @override
  MeetupsAreaState build() {
    final outside = ref.watch(outsideAreaProvider);
    return MeetupsAreaState(
      area: MeetupsArea.of(outside.area),
      resolving: outside.area == null && ref.watch(meetupsAreaSeedProvider),
      locating: outside.locating,
      problem: outside.problem,
    );
  }

  OutsideAreaController get _outside => ref.read(outsideAreaProvider.notifier);

  void chooseCity(Locality city) => _outside.chooseCity(city);

  void setRadius(ParkRadius radius) => _outside.setRadius(radius);

  /// "Change": back to choosing a city.
  void changeArea() => _outside.changeArea();

  /// "Near me": one fix, asked for only on the tap. The position is not
  /// kept; the board looks around the nearest city.
  Future<void> useMyLocation() => _outside.useMyLocation();
}

final meetupsAreaProvider =
    NotifierProvider<MeetupsAreaController, MeetupsAreaState>(
      MeetupsAreaController.new,
    );

/// The board's area, read straight from Outside's ([MeetupsArea.of]), for
/// the providers that list ads. They follow the area at once when it
/// changes, not when a screen next reads them: Riverpod 3 would otherwise
/// refresh them in the middle of a build.
ProviderListenable<MeetupsArea?> get meetupsAreaOfOutsideProvider =>
    outsideAreaProvider.select((s) => MeetupsArea.of(s.area));

/// The first time Outside has no area, the board starts on a city: the one
/// this phone chose for the board before Outside had one area, else the
/// city of the member's profile (not kept on the phone). `true` while it is
/// looked up.
class MeetupsAreaSeed extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(sessionEpochProvider);
    final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
    if (user == null || ref.read(outsideAreaProvider).area != null) {
      return false;
    }
    Future.microtask(() => _seed(user));
    return true;
  }

  Future<void> _seed(String user) async {
    if (!ref.mounted) return;
    final ticket = SessionTicket(ref);
    final settings = ref.read(settingsStoreProvider);
    final before = MeetupsArea.parse(settings.read(meetupsAreaKey(user)));
    var city = before?.city;
    if (city == null) {
      try {
        final profile = await ref
            .read(communityMembersRepositoryProvider)
            .fetchMember(user);
        city = localityOfProfileCity(profile?.city ?? '');
      } catch (_) {
        city = null;
      }
    }
    if (!ref.mounted || !ticket.current || !state) return;
    state = false;
    if (city == null) return;
    ref
        .read(outsideAreaProvider.notifier)
        .suggest(
          CityArea(city, radius: before?.radius ?? MeetupsArea.defaultRadius),
          remember: before != null,
        );
    if (before != null) settings.write(meetupsAreaKey(user), null);
  }
}

final meetupsAreaSeedProvider = NotifierProvider<MeetupsAreaSeed, bool>(
  MeetupsAreaSeed.new,
);

// ---------------------------------------------------------------------------
// Filters.
// ---------------------------------------------------------------------------

/// "When": any time, today, within the week, or recurring ads only.
enum MeetupWhen { any, today, thisWeek, recurring }

class MeetupFilters {
  const MeetupFilters({
    this.kind,
    this.when = MeetupWhen.any,
    this.atMyParks = false,
  });

  /// `null`: walks and play.
  final MeetupKind? kind;
  final MeetupWhen when;

  /// Only ads at one of "My parks".
  final bool atMyParks;

  bool get isEmpty => kind == null && when == MeetupWhen.any && !atMyParks;

  MeetupFilters copyWith({
    MeetupKind? kind,
    bool clearKind = false,
    MeetupWhen? when,
    bool? atMyParks,
  }) => MeetupFilters(
    kind: clearKind ? null : kind ?? this.kind,
    when: when ?? this.when,
    atMyParks: atMyParks ?? this.atMyParks,
  );
}

class MeetupFiltersController extends Notifier<MeetupFilters> {
  @override
  MeetupFilters build() {
    ref.watch(sessionEpochProvider);
    return const MeetupFilters();
  }

  void kind(MeetupKind? kind) =>
      state = state.copyWith(kind: kind, clearKind: kind == null);

  /// Tapping the chosen "when" again goes back to any time.
  void when(MeetupWhen when) => state = state.copyWith(
    when: state.when == when ? MeetupWhen.any : when,
  );

  void toggleMyParks() => state = state.copyWith(atMyParks: !state.atMyParks);

  void clear() => state = const MeetupFilters();
}

final meetupFiltersProvider =
    NotifierProvider<MeetupFiltersController, MeetupFilters>(
      MeetupFiltersController.new,
    );

/// Whether [ad] passes [filters] at [now] (the animal chips and blocks are
/// applied by the board).
bool passesFilters(
  Meetup ad,
  MeetupFilters filters,
  DateTime now, {
  Set<String> myParks = const {},
}) {
  if (filters.kind != null && ad.kind != filters.kind) return false;
  if (filters.atMyParks && !myParks.contains(ad.parkId)) return false;
  return switch (filters.when) {
    MeetupWhen.any => true,
    MeetupWhen.today => ad.time.occursOn(now),
    MeetupWhen.thisWeek => ad.time.occursWithinWeek(now),
    MeetupWhen.recurring => ad.isRecurring,
  };
}

// ---------------------------------------------------------------------------
// The ads.
// ---------------------------------------------------------------------------

/// The open ads of the area (before filters and blocks); empty until an
/// area is known.
final areaMeetupsProvider = FutureProvider<List<Meetup>>((ref) async {
  ref.watch(sessionEpochProvider);
  ref.watch(meetupsRevisionProvider);
  final area = ref.watch(meetupsAreaOfOutsideProvider);
  if (area == null) return const [];
  requireCapability(ref, MeetupCapabilities.view);
  return ref.read(meetupsRepositoryProvider).openMeetups(area.codes);
}, retry: (_, _) => null);

/// The member's own ads: open, ended and closed.
final myMeetupsProvider = FutureProvider<List<Meetup>>((ref) async {
  ref.watch(sessionEpochProvider);
  ref.watch(meetupsRevisionProvider);
  if (!ref.watch(capabilityProvider(MeetupCapabilities.view))) return const [];
  return ref.read(meetupsRepositoryProvider).mine();
}, retry: (_, _) => null);

/// The open ads at one park (its page).
final parkMeetupsProvider = FutureProvider.autoDispose
    .family<List<Meetup>, String>((ref, parkId) async {
      ref.watch(sessionEpochProvider);
      ref.watch(meetupsRevisionProvider);
      requireCapability(ref, MeetupCapabilities.view);
      return ref.read(meetupsRepositoryProvider).atParks([parkId]);
    }, retry: (_, _) => null);

/// The open ads at several parks (the parks list's "Meetup today").
final parksMeetupsProvider = FutureProvider.autoDispose
    .family<List<Meetup>, String>((ref, joinedIds) async {
      ref.watch(sessionEpochProvider);
      ref.watch(meetupsRevisionProvider);
      if (!ref.watch(capabilityProvider(MeetupCapabilities.view)) ||
          joinedIds.isEmpty) {
        return const [];
      }
      return ref
          .read(meetupsRepositoryProvider)
          .atParks(joinedIds.split(','));
    }, retry: (_, _) => null);

/// A member's open ads (their page).
final memberMeetupsProvider = FutureProvider.autoDispose
    .family<List<Meetup>, String>((ref, memberId) async {
      ref.watch(sessionEpochProvider);
      ref.watch(meetupsRevisionProvider);
      if (!ref.watch(capabilityProvider(MeetupCapabilities.view))) {
        return const [];
      }
      return ref.read(meetupsRepositoryProvider).byAuthor(memberId);
    }, retry: (_, _) => null);

/// One ad (a push, a link); `null` when it is gone or not shown.
final meetupProvider = FutureProvider.autoDispose.family<Meetup?, String>((
  ref,
  id,
) async {
  ref.watch(sessionEpochProvider);
  ref.watch(meetupsRevisionProvider);
  requireCapability(ref, MeetupCapabilities.view);
  return ref.read(meetupsRepositoryProvider).meetup(id);
}, retry: (_, _) => null);

/// The author's responders of an ad.
final meetupRespondersProvider = FutureProvider.autoDispose
    .family<List<MeetupResponder>, String>((ref, id) async {
      ref.watch(sessionEpochProvider);
      ref.watch(meetupsRevisionProvider);
      requireCapability(ref, MeetupCapabilities.view);
      return ref.read(meetupsRepositoryProvider).responders(id);
    }, retry: (_, _) => null);

/// Saved parks with "Tell me about new meetups here" on. Switching shows
/// at once and is taken back if the server refuses.
class MeetupNotifyParks extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider(MeetupCapabilities.view))) return {};
    return ref.read(meetupsRepositoryProvider).notifyParkIds();
  }

  Future<void> set(String parkId, bool on) async {
    requireCapability(ref, MeetupCapabilities.view);
    final ticket = SessionTicket(ref);
    final before = state.value ?? await future;
    state = AsyncData(on ? {...before, parkId} : ({...before}..remove(parkId)));
    try {
      await ref.read(meetupsRepositoryProvider).setNotify(parkId, on);
    } catch (_) {
      if (ticket.current) state = AsyncData(before);
      rethrow;
    }
  }
}

final meetupNotifyParksProvider =
    AsyncNotifierProvider<MeetupNotifyParks, Set<String>>(
      MeetupNotifyParks.new,
      retry: (_, _) => null,
    );

/// What the member does with ads. Each change reloads every list.
class MeetupsController extends Notifier<void> {
  @override
  void build() {}

  MeetupsRepository get _repository => ref.read(meetupsRepositoryProvider);

  Future<T> _change<T>(String capability, Future<T> Function() action) async {
    requireCapability(ref, capability);
    final ticket = SessionTicket(ref);
    try {
      return await action();
    } finally {
      if (ticket.current) {
        ref.read(meetupsRevisionProvider.notifier).bump();
      }
    }
  }

  Future<String> save(MeetupDraft draft, {String? id}) =>
      _change(MeetupCapabilities.post, () async {
        final saved = await _repository.save(draft, id: id);
        if (id == null) ref.read(usageProvider).count(UsageKind.meetupPosted);
        return saved;
      });

  Future<void> close(String id) =>
      _change(MeetupCapabilities.view, () => _repository.close(id));

  Future<void> renew(String id) =>
      _change(MeetupCapabilities.post, () => _repository.renew(id));

  Future<int> answer(String id) =>
      _change(MeetupCapabilities.view, () async {
        final answered = await _repository.answer(id);
        ref.read(usageProvider).count(UsageKind.meetupJoined);
        return answered;
      });

  Future<void> report(String id, ReportReason reason) =>
      _change(MeetupCapabilities.view, () => _repository.report(id, reason));
}

final meetupsControllerProvider = NotifierProvider<MeetupsController, void>(
  MeetupsController.new,
);
