import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../services/community/data/audience.dart';
import '../../services/meetups/data/meetup_models.dart';
import '../../services/meetups/state/meetups_providers.dart';
import '../../services/outdoors/state/parks_providers.dart';
import '../../state/pets_provider.dart';
import '../community/safety/safety_providers.dart' show blockedIdsProvider;

/// One ad on the board, with how far it is from the area's centre.
class MeetupListing {
  const MeetupListing(this.meetup, {this.distanceM});

  final Meetup meetup;
  final double? distanceM;
}

/// What the board shows: the area's open ads, without blocked members'
/// ones, narrowed by the filters and the animal chips (an ad without a pet
/// shows under every chip), the soonest first, then the nearest. Pure, so
/// tests check the rules without widgets.
List<MeetupListing> buildMeetupListing({
  required List<Meetup> ads,
  required MeetupsArea? area,
  required MeetupFilters filters,
  required CommunityScope scope,
  required Set<String> blocked,
  required Set<String> myParks,
  required DateTime now,
}) {
  final centre = area?.city.point;
  final far = DateTime(now.year + 1);
  final list = [
    for (final ad in ads)
      if (ad.isLiveAt(now) &&
          !blocked.contains(ad.authorId) &&
          scope.shows(ad.audience) &&
          passesFilters(ad, filters, now, myParks: myParks))
        MeetupListing(
          ad,
          distanceM: centre == null ? null : ad.point?.distanceTo(centre),
        ),
  ];
  list.sort((a, b) {
    final day = (a.meetup.time.nextDay(now) ?? far).compareTo(
      b.meetup.time.nextDay(now) ?? far,
    );
    if (day != 0) return day;
    return (a.distanceM ?? 0).compareTo(b.distanceM ?? 0);
  });
  return list;
}

/// The board as the screen shows it.
final partnersListingProvider = Provider<AsyncValue<List<MeetupListing>>>((
  ref,
) {
  final ads = ref.watch(areaMeetupsProvider);
  final area = ref.watch(meetupsAreaProvider.select((s) => s.area));
  final filters = ref.watch(meetupFiltersProvider);
  final scope = ref.watch(communityScopeProvider);
  final blocked = ref.watch(blockedIdsProvider);
  final myParks = ref.watch(parkFavoritesProvider).value ?? const <String>{};
  final now = ref.watch(meetupsClockProvider)();
  return ads.whenData(
    (list) => buildMeetupListing(
      ads: list,
      area: area,
      filters: filters,
      scope: scope,
      blocked: blocked,
      myParks: myParks,
      now: now,
    ),
  );
});

/// How many of the board's filters differ from where it starts: the
/// distance (up to 10 km), walk or play, the animal (the selected pet's
/// kind, as in the rest of the Community), when, and "At my parks".
final partnersFilterCountProvider = Provider<int>((ref) {
  final radius = ref.watch(meetupsAreaProvider.select((s) => s.area?.radius));
  final filters = ref.watch(meetupFiltersProvider);
  final scope = ref.watch(communityScopeProvider);
  final species = ref.watch(selectedPetProvider.select((pet) => pet.species));
  return [
    radius != null && radius != MeetupsArea.defaultRadius,
    filters.kind != null,
    scope != CommunityScope.forSpecies(species),
    filters.when != MeetupWhen.any,
    filters.atMyParks,
  ].where((on) => on).length;
});

/// "Clear": every filter back to where the board starts (the distance is
/// kept on the phone, as when it is chosen).
void clearPartnersFilters(WidgetRef ref) {
  ref.read(meetupFiltersProvider.notifier).clear();
  ref
      .read(communityScopeProvider.notifier)
      .select(CommunityScope.forSpecies(ref.read(selectedPetProvider).species));
  ref.read(meetupsAreaProvider.notifier).setRadius(MeetupsArea.defaultRadius);
}

/// What a park card says about meetups there.
class ParkMeetupSummary {
  const ParkMeetupSummary({this.thisWeek = 0, this.today = false});

  final int thisWeek;
  final bool today;
}

/// The parks the parks list (and the picker) can show, joined for one
/// fetch: the area's and the saved ones. Read from the sources, not from
/// the derived listing, which is worked out while the list builds.
final _listedParkIdsProvider = Provider<String>((ref) {
  final area = ref.watch(parksControllerProvider.select((s) => s.parks?.value));
  final saved = ref.watch(savedParksProvider).value;
  final ids = {
    for (final park in area ?? const []) park.id,
    for (final park in saved ?? const []) park.id,
  }.toList()..sort();
  return ids.join(',');
});

/// "Meetup today" / "2 meetups this week" for each listed park.
final parkMeetupSummariesProvider =
    Provider<Map<String, ParkMeetupSummary>>((ref) {
      final ids = ref.watch(_listedParkIdsProvider);
      final ads = ref.watch(parksMeetupsProvider(ids)).value ?? const [];
      final blocked = ref.watch(blockedIdsProvider);
      final now = ref.watch(meetupsClockProvider)();
      final counts = <String, ParkMeetupSummary>{};
      for (final ad in ads) {
        final park = ad.parkId;
        if (park == null ||
            !ad.isLiveAt(now) ||
            blocked.contains(ad.authorId) ||
            !ad.time.occursWithinWeek(now)) {
          continue;
        }
        final old = counts[park] ?? const ParkMeetupSummary();
        counts[park] = ParkMeetupSummary(
          thisWeek: old.thisWeek + 1,
          today: old.today || ad.time.occursOn(now),
        );
      }
      return counts;
    });

/// Keeps the board's lists active while a form, an ad's page or a chat
/// covers it, for the reason given on `CommunityKeeper`: Riverpod 3 pauses
/// covered subscriptions and would flush them in the middle of a build
/// when the route comes back. [also] keeps more (a park's ads); without
/// [board] only those (a park card, a member page).
class MeetupsKeeper extends StatefulWidget {
  const MeetupsKeeper({
    super.key,
    required this.child,
    this.also = const [],
    this.board = true,
  });

  final Widget child;
  final List<ProviderListenable<Object?>> also;
  final bool board;

  @override
  State<MeetupsKeeper> createState() => _MeetupsKeeperState();
}

class _MeetupsKeeperState extends State<MeetupsKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  void _listen() {
    _close();
    final container = _container!;
    void keep(ProviderListenable<Object?> provider) => _subscriptions.add(
      container.listen<Object?>(provider, (_, _) {}, onError: (_, _) {}),
    );
    if (widget.board) {
      keep(meetupsAreaProvider);
      keep(meetupFiltersProvider);
      keep(areaMeetupsProvider);
      keep(myMeetupsProvider);
      keep(partnersListingProvider);
      keep(meetupNotifyParksProvider);
      keep(blockedIdsProvider);
    }
    widget.also.forEach(keep);
  }

  void _close() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
