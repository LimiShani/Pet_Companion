import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../config/app_config.dart';
import '../../../platform/session.dart';
import '../../findvet/data/location_service.dart';
import '../../findvet/regions/regions.dart';
import '../../findvet/state/find_vet_providers.dart'
    show AreaProblem, locationServiceProvider;
import '../data/fake_parks_repository.dart';
import '../data/park_area.dart';
import '../data/park_launcher.dart';
import '../data/park_models.dart';
import '../data/parks_repository.dart';
import '../data/supabase_parks_repository.dart';

export '../../findvet/state/find_vet_providers.dart'
    show AreaProblem, locationServiceProvider;

/// Who may do what with parks (`0027_dog_parks.sql`).
abstract final class ParkCapabilities {
  static const view = 'community.parks.view';
  static const suggest = 'community.parks.suggest';
  static const review = 'community.parks.review';
}

final parksRepositoryProvider = Provider<ParksRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseParksRepository(sb.Supabase.instance.client)
      : FakeParksRepository(),
);

final parkLauncherProvider = Provider<ParkLauncher>(
  (ref) => const UrlParkLauncher(),
);

/// The two sides of Community > Outside.
enum OutsideView { partners, parks }

/// Which side of Outside is showing; Parks first while Partners (meetups)
/// is being built.
class OutsideViewController extends Notifier<OutsideView> {
  @override
  OutsideView build() => OutsideView.parks;

  void show(OutsideView view) => state = view;
}

final outsideViewProvider =
    NotifierProvider<OutsideViewController, OutsideView>(
      OutsideViewController.new,
    );

/// The parks list: where to look, the filters, and what was found. The
/// area lives in memory only (the phone's position is never stored) and is
/// forgotten on sign-out.
class ParksState {
  const ParksState({
    this.area,
    this.filters = const {},
    this.parks,
    this.locating = false,
    this.problem,
  });

  final ParkArea? area;

  /// Show only parks known to have all of these.
  final Set<ParkDetail> filters;

  /// The parks of [area]; `null` before an area is chosen.
  final AsyncValue<List<DogPark>>? parks;
  final bool locating;
  final AreaProblem? problem;

  ParksState copyWith({
    ParkArea? area,
    bool clearArea = false,
    Set<ParkDetail>? filters,
    AsyncValue<List<DogPark>>? parks,
    bool clearParks = false,
    bool? locating,
    AreaProblem? problem,
    bool clearProblem = false,
  }) => ParksState(
    area: clearArea ? null : area ?? this.area,
    filters: filters ?? this.filters,
    parks: clearParks ? null : parks ?? this.parks,
    locating: locating ?? this.locating,
    problem: clearProblem ? null : problem ?? this.problem,
  );
}

class ParksController extends Notifier<ParksState> {
  int _load = 0;

  @override
  ParksState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(capabilityProvider(ParkCapabilities.view));
    _load++;
    return const ParksState();
  }

  ParksRepository get _repository => ref.read(parksRepositoryProvider);

  /// "Near me": one fix, asked for only on the owner's tap (after the
  /// screen said why). The position stays on the phone.
  Future<void> useMyLocation() async {
    requireCapability(ref, ParkCapabilities.view);
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
    final region = vetRegionAt(point);
    if (region == null) {
      state = state.copyWith(
        locating: false,
        problem: AreaProblem.outsideRegion,
      );
      return;
    }
    state = state.copyWith(locating: false);
    setArea(
      NearMeArea(
        point: point,
        accuracyM: result.accuracyM,
        nearest: region.nearestLocality(point),
        radius: state.area?.radius ?? ParkRadius.km10,
      ),
    );
  }

  void chooseCity(Locality locality) => setArea(CityArea(locality));

  void setArea(ParkArea area) {
    state = state.copyWith(area: area, clearProblem: true);
    load();
  }

  void setRadius(ParkRadius radius) {
    final area = state.area;
    if (area == null || area.radius == radius) return;
    setArea(area.withRadius(radius));
  }

  /// "Change": back to choosing where to look.
  void changeArea() {
    _load++;
    state = state.copyWith(
      clearArea: true,
      clearParks: true,
      clearProblem: true,
    );
  }

  void toggleFilter(ParkDetail detail) {
    final filters = Set.of(state.filters);
    filters.contains(detail) ? filters.remove(detail) : filters.add(detail);
    state = state.copyWith(filters: filters);
  }

  void clearFilters() => state = state.copyWith(filters: const {});

  /// Loads the parks of the area. A slow answer never replaces a newer one.
  Future<void> load() async {
    final area = state.area;
    if (area == null) return;
    requireCapability(ref, ParkCapabilities.view);
    final ticket = SessionTicket(ref);
    final id = ++_load;
    state = state.copyWith(parks: const AsyncLoading());
    try {
      final parks = await _repository.parks(ParkQuery.of(area));
      if (!ticket.current || id != _load) return;
      state = state.copyWith(parks: AsyncData(parks));
    } catch (e, stack) {
      if (!ticket.current || id != _load) return;
      state = state.copyWith(parks: AsyncError(e, stack));
    }
  }

  /// A suggestion was approved or a park changed: refresh what is shown.
  Future<void> refresh() async {
    ref.invalidate(savedParksProvider);
    await load();
  }
}

final parksControllerProvider = NotifierProvider<ParksController, ParksState>(
  ParksController.new,
);

/// The ids of "My parks". Saving shows at once and is taken back if the
/// server refuses.
class ParkFavorites extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider(ParkCapabilities.view))) return {};
    return ref.read(parksRepositoryProvider).favoriteIds();
  }

  /// Saves or removes [parkId]; returns whether it is saved now.
  Future<bool> toggle(String parkId) async {
    requireCapability(ref, ParkCapabilities.view);
    final ticket = SessionTicket(ref);
    final before = state.value ?? await future;
    final save = !before.contains(parkId);
    state = AsyncData(
      save ? {...before, parkId} : ({...before}..remove(parkId)),
    );
    try {
      await ref.read(parksRepositoryProvider).setFavorite(parkId, save);
    } catch (_) {
      if (ticket.current) state = AsyncData(before);
      rethrow;
    }
    return save;
  }
}

final parkFavoritesProvider = AsyncNotifierProvider<ParkFavorites, Set<String>>(
  ParkFavorites.new,
  retry: (_, _) => null,
);

/// The saved parks themselves, wherever they are.
final savedParksProvider = FutureProvider<List<DogPark>>((ref) async {
  final ids = await ref.watch(parkFavoritesProvider.future);
  if (ids.isEmpty) return const [];
  return ref.read(parksRepositoryProvider).parksByIds(ids);
}, retry: (_, _) => null);

/// One park on the list, with how far it is from the area's centre.
class ParkListing {
  const ParkListing(this.park, {this.distanceM, this.saved = false});

  final DogPark park;
  final double? distanceM;
  final bool saved;
}

/// What the list shows: "My parks" first, then the area's other parks,
/// nearest first, both narrowed by the filters.
class ParksListing {
  const ParksListing({this.saved = const [], this.nearby = const []});

  final List<ParkListing> saved;
  final List<ParkListing> nearby;

  bool get isEmpty => saved.isEmpty && nearby.isEmpty;

  /// Saved first, then nearby: the order a park picker offers.
  List<ParkListing> get all => [...saved, ...nearby];
}

/// Pure, so tests check the rules without widgets.
ParksListing buildListing({
  required ParkArea? area,
  required List<DogPark> areaParks,
  required List<DogPark> savedParks,
  required Set<ParkDetail> filters,
}) {
  bool passes(DogPark p) =>
      filters.every((detail) => p.answer(detail) == ParkAnswer.yes);
  double? distance(DogPark p) => area?.centre.distanceTo(p.point);
  int byDistance(ParkListing a, ParkListing b) =>
      (a.distanceM ?? 0).compareTo(b.distanceM ?? 0);
  final savedIds = {for (final p in savedParks) p.id};
  final radius = area?.radius.metres;
  return ParksListing(
    saved: [
      for (final p in savedParks)
        if (passes(p)) ParkListing(p, distanceM: distance(p), saved: true),
    ]..sort(byDistance),
    nearby: [
      for (final p in areaParks)
        if (!savedIds.contains(p.id) &&
            passes(p) &&
            (radius == null || (distance(p) ?? 0) <= radius))
          ParkListing(p, distanceM: distance(p)),
    ]..sort(byDistance),
  );
}

/// The list as the screen shows it; `null` until an area is chosen.
final parksListingProvider = Provider<AsyncValue<ParksListing>?>((ref) {
  final state = ref.watch(parksControllerProvider);
  final parks = state.parks;
  if (parks == null) return null;
  final saved = ref.watch(savedParksProvider);
  if (parks.hasError && !parks.hasValue) {
    return AsyncError(parks.error!, parks.stackTrace ?? StackTrace.empty);
  }
  if (!parks.hasValue) return const AsyncLoading();
  return AsyncData(
    buildListing(
      area: state.area,
      areaParks: parks.value!,
      savedParks: saved.value ?? const [],
      filters: state.filters,
    ),
  );
});

/// One park, fresh from the server (the park page). `null` when it is no
/// longer shown.
final parkProvider = FutureProvider.autoDispose.family<DogPark?, String>(
  (ref, id) async {
    ref.watch(sessionEpochProvider);
    requireCapability(ref, ParkCapabilities.view);
    return ref.read(parksRepositoryProvider).park(id);
  },
  retry: (_, _) => null,
);

/// What waits for review; empty for anyone who is not a park reviewer.
final parkReviewQueueProvider = FutureProvider.autoDispose<ParkReviewQueue>((
  ref,
) async {
  ref.watch(sessionEpochProvider);
  if (!ref.watch(capabilityProvider(ParkCapabilities.review))) {
    return const ParkReviewQueue();
  }
  return ref.read(parksRepositoryProvider).reviewQueue();
}, retry: (_, _) => null);
