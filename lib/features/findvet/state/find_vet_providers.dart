import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../l10n/app_language.dart';
import '../../../l10n/settings_store.dart';
import '../data/fake_vet_finder_repository.dart';
import '../data/location_service.dart';
import '../data/supabase_vet_finder_repository.dart';
import '../data/vet_admin_repository.dart';
import '../data/vet_finder_repository.dart';
import '../data/vet_launcher.dart';
import '../data/vet_models.dart';
import '../regions/regions.dart';

final findVetRepositoryProvider = Provider<VetFinderRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseVetFinderRepository(sb.Supabase.instance.client, store: ref.watch(settingsStoreProvider))
      : FakeVetFinderRepository(),
);

final locationServiceProvider = Provider<LocationService>((ref) => const GeolocatorLocationService());

final vetLauncherProvider = Provider<VetLauncher>((ref) => const UrlVetLauncher());

/// The clock live statuses expire by (tests pin it).
final findVetClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final vetAdminRepositoryProvider = Provider<VetAdminRepository>(
  (ref) => AppConfig.hasSupabase ? SupabaseVetAdminRepository(sb.Supabase.instance.client) : FakeVetAdminRepository(),
);

/// Whether the signed-in account may review the directory. False when
/// signed out or on any error: the entry is simply not shown.
final vetIsAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return false;
  try {
    return await ref.watch(vetAdminRepositoryProvider).isAdmin();
  } catch (_) {
    return false;
  }
}, retry: (_, _) => null);

/// Why the area could not be set from the phone's location.
enum AreaProblem { denied, deniedForever, serviceOff, unavailable, outsideRegion }

/// Everything the Find a vet page shows. Lives while the page is open and
/// is forgotten when it closes: no search, place or result is stored.
class FindVetState {
  const FindVetState({
    this.mode,
    this.area,
    this.region,
    this.locating = false,
    this.problem,
    this.results,
  });

  /// Which path; `null` on the first screen (the choice).
  final VetSearchMode? mode;

  /// Where to look; `null` until the owner chose.
  final SearchArea? area;

  /// The region the area lies in.
  final VetRegion? region;

  /// Waiting for the phone's location.
  final bool locating;

  /// Why "Use my location" did not work, until the owner tries again or
  /// picks a place.
  final AreaProblem? problem;

  /// The search for [mode] around [area]; `null` before one runs.
  final AsyncValue<VetSearchResult>? results;

  FindVetState copyWith({
    VetSearchMode? mode,
    bool clearMode = false,
    SearchArea? area,
    bool clearArea = false,
    VetRegion? region,
    bool? locating,
    AreaProblem? problem,
    bool clearProblem = false,
    AsyncValue<VetSearchResult>? results,
    bool clearResults = false,
  }) => FindVetState(
    mode: clearMode ? null : mode ?? this.mode,
    area: clearArea ? null : area ?? this.area,
    region: clearArea ? null : region ?? this.region,
    locating: locating ?? this.locating,
    problem: clearProblem ? null : problem ?? this.problem,
    results: clearResults ? null : results ?? this.results,
  );
}

class FindVetController extends Notifier<FindVetState> {
  FindVetController(this.initialMode);

  /// The path the page opened on (from the Emergency sheet: emergency).
  final VetSearchMode? initialMode;

  /// Counts searches, so a slow answer never replaces a newer one.
  int _searchId = 0;

  @override
  FindVetState build() => FindVetState(mode: initialMode);

  VetFinderRepository get _repository => ref.read(findVetRepositoryProvider);

  /// The language to ask the server in for [region].
  String _language(VetRegion region) => region.searchLanguage(ref.read(appLocaleProvider).languageCode);

  void chooseMode(VetSearchMode mode) {
    state = state.copyWith(mode: mode, clearResults: true);
    if (state.area != null) search();
  }

  /// Back to the choice of path; the area stays for the next choice.
  void backToChoice() {
    _searchId++;
    state = state.copyWith(clearMode: true, clearResults: true);
  }

  /// Asks the phone where it is (permission first if needed). Called only
  /// from the owner's tap on "Use my location".
  Future<void> useMyLocation() async {
    state = state.copyWith(locating: true, clearProblem: true);
    final result = await ref.read(locationServiceProvider).current();
    if (!ref.mounted) return;
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
    state = state.copyWith(locating: false);
    setArea(SearchArea(label: '', point: point, source: AreaSource.device, accuracyM: result.accuracyM));
  }

  /// Searches around [area] (a picked city, a typed address or the phone's
  /// location). Outside every region Find a vet works in, says so instead.
  void setArea(SearchArea area) {
    final region = vetRegionAt(area.point);
    if (region == null) {
      state = state.copyWith(problem: AreaProblem.outsideRegion, clearResults: true);
      return;
    }
    state = state.copyWith(area: area, region: region, clearProblem: true, clearResults: true);
    if (state.mode != null) search();
  }

  /// "Change area": back to choosing where to look.
  void changeArea() {
    _searchId++;
    state = state.copyWith(clearArea: true, clearResults: true, clearProblem: true);
  }

  /// Runs the search for the current path and area. [radiusM] overrides
  /// the region's first radius (used by "Search further").
  Future<void> search({int? radiusM}) async {
    final mode = state.mode;
    final area = state.area;
    final region = state.region;
    if (mode == null || area == null || region == null) return;
    final id = ++_searchId;
    state = state.copyWith(results: const AsyncLoading());
    final ladder = mode == VetSearchMode.emergency ? region.emergencyLadderM : region.longTermLadderM;
    try {
      final result = await _repository.search(
        region: region,
        mode: mode,
        center: area.point,
        radiusM: radiusM ?? ladder.first,
        language: _language(region),
      );
      if (!ref.mounted || id != _searchId) return;
      state = state.copyWith(results: AsyncData(result));
    } catch (e, stack) {
      if (!ref.mounted || id != _searchId) return;
      state = state.copyWith(results: AsyncError(e, stack));
    }
  }

  /// The next radius of the ladder after the one last searched, or `null`
  /// when the search already covered the widest.
  int? get widerRadius {
    final region = state.region;
    final mode = state.mode;
    final searched = state.results?.value?.radiusM;
    if (region == null || mode == null || searched == null) return null;
    final ladder = mode == VetSearchMode.emergency ? region.emergencyLadderM : region.longTermLadderM;
    for (final step in ladder) {
      if (step > searched) return step;
    }
    return null;
  }

  Future<void> searchWider() async {
    final radius = widerRadius;
    if (radius != null) await search(radiusM: radius);
  }

  /// Places for what the owner typed: the region's own list of cities
  /// first (no server call), then the server's geocoder.
  Future<List<PlaceMatch>> lookUp(String query, {required String appLanguage}) async {
    final region = state.region ?? vetRegions.first;
    final local = region.findLocalities(query);
    if (local.isNotEmpty) {
      return [for (final l in local) PlaceMatch(label: l.nameIn(appLanguage), point: l.point)];
    }
    return _repository.geocode(region: region, query: query.trim(), language: _language(region));
  }
}

final findVetControllerProvider =
    NotifierProvider.autoDispose.family<FindVetController, FindVetState, VetSearchMode?>(FindVetController.new);
