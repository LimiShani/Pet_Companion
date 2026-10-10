import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/settings_store.dart';
import '../../../platform/session.dart';
import '../../community/data/community_models.dart' show ReportReason;
import '../../community/data/community_providers.dart'
    show communityMembersRepositoryProvider;
import '../../findvet/data/location_service.dart';
import '../../findvet/regions/regions.dart';
import '../../findvet/state/find_vet_providers.dart'
    show AreaProblem, locationServiceProvider;
import '../../outdoors/data/park_area.dart';
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

/// Where the board looks: a city of the bundled list and a radius. "Near
/// me" only picks the nearest city; the position is neither stored nor
/// sent.
class MeetupsArea {
  const MeetupsArea(this.city, this.radius);

  final Locality city;
  final ParkRadius radius;

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
    this.fromProfile = false,
  });

  /// `null` until known: then the board asks once.
  final MeetupsArea? area;

  /// Looking up the city of the member's profile.
  final bool resolving;
  final bool locating;
  final AreaProblem? problem;

  /// The area is the profile's city (not chosen on this phone).
  final bool fromProfile;

  MeetupsAreaState copyWith({
    MeetupsArea? area,
    bool clearArea = false,
    bool? resolving,
    bool? locating,
    AreaProblem? problem,
    bool clearProblem = false,
    bool? fromProfile,
  }) => MeetupsAreaState(
    area: clearArea ? null : area ?? this.area,
    resolving: resolving ?? this.resolving,
    locating: locating ?? this.locating,
    problem: clearProblem ? null : problem ?? this.problem,
    fromProfile: fromProfile ?? this.fromProfile,
  );
}

/// The settings key of the area chosen on this phone, per account.
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

class MeetupsAreaController extends Notifier<MeetupsAreaState> {
  @override
  MeetupsAreaState build() {
    ref.watch(sessionEpochProvider);
    final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
    if (user == null) return const MeetupsAreaState();
    final saved = MeetupsArea.parse(
      ref.read(settingsStoreProvider).read(meetupsAreaKey(user)),
    );
    if (saved != null) return MeetupsAreaState(area: saved);
    Future.microtask(() => _fromProfile(user));
    return const MeetupsAreaState(resolving: true);
  }

  /// The city of the member's profile, the first time.
  Future<void> _fromProfile(String user) async {
    final ticket = SessionTicket(ref);
    Locality? city;
    try {
      final profile = await ref
          .read(communityMembersRepositoryProvider)
          .fetchMember(user);
      city = localityOfProfileCity(profile?.city ?? '');
    } catch (_) {
      city = null;
    }
    if (!ticket.current || !state.resolving) return;
    state = city == null
        ? state.copyWith(resolving: false)
        : MeetupsAreaState(
            area: MeetupsArea(city, ParkRadius.km10),
            fromProfile: true,
          );
  }

  void _set(MeetupsArea area) {
    state = MeetupsAreaState(area: area);
    final user = ref.read(authControllerProvider).value?.id;
    if (user != null) {
      ref.read(settingsStoreProvider).write(meetupsAreaKey(user), area.key);
    }
  }

  void chooseCity(Locality city) =>
      _set(MeetupsArea(city, state.area?.radius ?? ParkRadius.km10));

  void setRadius(ParkRadius radius) {
    final area = state.area;
    if (area == null || area.radius == radius) return;
    _set(MeetupsArea(area.city, radius));
  }

  /// "Change": back to choosing a city.
  void changeArea() => state = state.copyWith(
    clearArea: true,
    resolving: false,
    clearProblem: true,
  );

  /// "Near me": one fix, asked for only on the tap, to pick the nearest
  /// city. The position is forgotten at once.
  Future<void> useMyLocation() async {
    requireCapability(ref, MeetupCapabilities.view);
    final ticket = SessionTicket(ref);
    state = state.copyWith(locating: true, clearProblem: true);
    final result = await ref.read(locationServiceProvider).current();
    if (!ticket.current) return;
    final point = result.point;
    if (result.outcome != LocationOutcome.found || point == null) {
      state = state.copyWith(
        locating: false,
        problem: switch (result.outcome) {
          LocationOutcome.denied => AreaProblem.denied,
          LocationOutcome.deniedForever => AreaProblem.deniedForever,
          LocationOutcome.serviceOff => AreaProblem.serviceOff,
          _ => AreaProblem.unavailable,
        },
      );
      return;
    }
    final city = vetRegionAt(point)?.nearestLocality(point, maxM: 30000);
    if (city == null) {
      state = state.copyWith(
        locating: false,
        problem: AreaProblem.outsideRegion,
      );
      return;
    }
    _set(MeetupsArea(city, state.area?.radius ?? ParkRadius.km10));
  }
}

final meetupsAreaProvider =
    NotifierProvider<MeetupsAreaController, MeetupsAreaState>(
      MeetupsAreaController.new,
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
  final area = ref.watch(meetupsAreaProvider.select((s) => s.area));
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
      _change(MeetupCapabilities.post, () => _repository.save(draft, id: id));

  Future<void> close(String id) =>
      _change(MeetupCapabilities.view, () => _repository.close(id));

  Future<void> renew(String id) =>
      _change(MeetupCapabilities.post, () => _repository.renew(id));

  Future<int> answer(String id) =>
      _change(MeetupCapabilities.view, () => _repository.answer(id));

  Future<void> report(String id, ReportReason reason) =>
      _change(MeetupCapabilities.view, () => _repository.report(id, reason));
}

final meetupsControllerProvider = NotifierProvider<MeetupsController, void>(
  MeetupsController.new,
);
