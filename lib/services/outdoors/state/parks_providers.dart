import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/settings_store.dart';
import '../../../platform/feature_module.dart';
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

/// Which side of Outside is showing: Partners first when a module fills it
/// (meetups) for this account, else Parks.
class OutsideViewController extends Notifier<OutsideView> {
  @override
  OutsideView build() {
    for (final module in ref.watch(featureModulesProvider)) {
      final slot = module.slots['outside-partners'];
      if (slot != null && ref.watch(capabilityProvider(slot.capability))) {
        return OutsideView.partners;
      }
    }
    return OutsideView.parks;
  }

  void show(OutsideView view) => state = view;
}

final outsideViewProvider =
    NotifierProvider<OutsideViewController, OutsideView>(
      OutsideViewController.new,
    );

// ---------------------------------------------------------------------------
// The area: one for the whole Outside tab, Parks and Partners alike.
// ---------------------------------------------------------------------------

/// The radius Outside starts on.
const outsideDefaultRadius = ParkRadius.km10;

/// The settings key of the area chosen on this phone, per account: a city
/// and its radius ("raanana|km10"). "Near me" is never kept.
String outsideAreaKey(String userId) => 'outdoors.area.$userId';

/// The city area kept as "raanana|km10", or `null`.
CityArea? parseCityArea(String? value) {
  if (value == null) return null;
  final parts = value.split('|');
  final city = [
    for (final region in vetRegions) region.localityByCode(parts.first),
  ].nonNulls.firstOrNull;
  if (city == null) return null;
  final radius = ParkRadius.values.asNameMap()[parts.length > 1 ? parts[1] : ''];
  return CityArea(city, radius: radius ?? outsideDefaultRadius);
}

/// Where Outside looks, and how "Near me" is going.
class OutsideAreaState {
  const OutsideAreaState({this.area, this.locating = false, this.problem});

  /// `null` until chosen: then each side asks once.
  final ParkArea? area;
  final bool locating;
  final AreaProblem? problem;
}

/// The one area of the Outside tab: the parks list and the partner ads
/// both look there, and the chip in the tab's header changes it. A chosen
/// city is kept on the phone with its radius; "Near me" (the phone's
/// position) lives in memory only and is forgotten on sign-out.
class OutsideAreaController extends Notifier<OutsideAreaState> {
  @override
  OutsideAreaState build() {
    ref.watch(sessionEpochProvider);
    final user = ref.watch(authControllerProvider.select((a) => a.value?.id));
    if (user == null) return const OutsideAreaState();
    return OutsideAreaState(
      area: parseCityArea(
        ref.read(settingsStoreProvider).read(outsideAreaKey(user)),
      ),
    );
  }

  /// "Near me": one fix, asked for only on the owner's tap (after the
  /// screen said why). The position stays on the phone and is not kept.
  Future<void> useMyLocation() async {
    final ticket = SessionTicket(ref);
    state = OutsideAreaState(area: state.area, locating: true);
    final result = await ref.read(locationServiceProvider).current();
    if (!ticket.current || !ref.mounted) return;
    final point = result.point;
    if (result.outcome != LocationOutcome.found || point == null) {
      state = OutsideAreaState(
        area: state.area,
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
      state = OutsideAreaState(
        area: state.area,
        problem: AreaProblem.outsideRegion,
      );
      return;
    }
    setArea(
      NearMeArea(
        point: point,
        accuracyM: result.accuracyM,
        nearest: region.nearestLocality(point),
        radius: state.area?.radius ?? outsideDefaultRadius,
      ),
    );
  }

  /// A city, with the radius already chosen.
  void chooseCity(Locality locality) => setArea(
    CityArea(locality, radius: state.area?.radius ?? outsideDefaultRadius),
  );

  void setArea(ParkArea area) {
    state = OutsideAreaState(area: area);
    _remember(area is CityArea ? area : null);
  }

  void setRadius(ParkRadius radius) {
    final area = state.area;
    if (area == null || area.radius == radius) return;
    setArea(area.withRadius(radius));
  }

  /// Back to choosing where to look (what the phone keeps stays).
  void changeArea() => state = const OutsideAreaState();

  /// A starting city when none is chosen yet (the member's profile city,
  /// from meetups). Kept on the phone only when [remember] is set.
  void suggest(CityArea area, {bool remember = false}) {
    if (state.area != null) return;
    state = OutsideAreaState(area: area);
    if (remember) _remember(area);
  }

  void _remember(CityArea? area) {
    final user = ref.read(authControllerProvider).value?.id;
    if (user == null) return;
    ref
        .read(settingsStoreProvider)
        .write(
          outsideAreaKey(user),
          area == null ? null : '${area.locality.code}|${area.radius.name}',
        );
  }
}

final outsideAreaProvider =
    NotifierProvider<OutsideAreaController, OutsideAreaState>(
      OutsideAreaController.new,
    );

/// The parks list: Outside's area, the filters, and what was found.
class ParksState {
  const ParksState({this.area, this.filters = const {}, this.parks});

  /// Outside's area ([outsideAreaProvider]).
  final ParkArea? area;

  /// Show only parks known to have all of these.
  final Set<ParkDetail> filters;

  /// The parks of [area]; `null` before an area is chosen.
  final AsyncValue<List<DogPark>>? parks;

  ParksState copyWith({
    ParkArea? area,
    bool clearArea = false,
    Set<ParkDetail>? filters,
    AsyncValue<List<DogPark>>? parks,
    bool clearParks = false,
  }) => ParksState(
    area: clearArea ? null : area ?? this.area,
    filters: filters ?? this.filters,
    parks: clearParks ? null : parks ?? this.parks,
  );
}

class ParksController extends Notifier<ParksState> {
  int _load = 0;

  @override
  ParksState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(capabilityProvider(ParkCapabilities.view));
    _load++;
    ref.listen(outsideAreaProvider.select((s) => s.area), (_, area) {
      _show(area);
    });
    final area = ref.read(outsideAreaProvider).area;
    if (area != null) Future.microtask(load);
    return ParksState(area: area);
  }

  ParksRepository get _repository => ref.read(parksRepositoryProvider);

  OutsideAreaController get _area => ref.read(outsideAreaProvider.notifier);

  void _show(ParkArea? area) {
    if (area == null) {
      _load++;
      state = state.copyWith(clearArea: true, clearParks: true);
      return;
    }
    state = state.copyWith(area: area);
    load();
  }

  /// "Near me" for the whole of Outside ([OutsideAreaController]).
  Future<void> useMyLocation() => _area.useMyLocation();

  void chooseCity(Locality locality) => _area.chooseCity(locality);

  void setArea(ParkArea area) => _area.setArea(area);

  void setRadius(ParkRadius radius) => _area.setRadius(radius);

  /// "Change": back to choosing where to look.
  void changeArea() => _area.changeArea();

  void toggleFilter(ParkDetail detail) {
    final filters = Set.of(state.filters);
    filters.contains(detail) ? filters.remove(detail) : filters.add(detail);
    state = state.copyWith(filters: filters);
  }

  void clearFilters() => state = state.copyWith(filters: const {});

  /// Loads the parks of the area. A slow answer never replaces a newer one.
  Future<void> load() async {
    if (!ref.mounted) return;
    final area = state.area;
    // An account with partners but no parks shares the area, not the list.
    if (area == null || !ref.read(capabilityProvider(ParkCapabilities.view))) {
      return;
    }
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
