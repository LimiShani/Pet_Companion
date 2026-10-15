import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../widgets/petloop_icon.dart';
import 'outdoors.dart';

/// The Outside tab: dog parks, and walk and play partners from the meetups
/// module, for anyone who may see either side; see docs/dog_parks.md for
/// the seams meetups plugs into.
final outdoorsModule = FeatureModule(
  id: 'outdoors',
  tab: FeatureTab(
    capability: OutsideScreen.capability,
    glyph: PetLoopGlyph.walk,
    area: AppArea.community,
    label: (c) => c.outdoorsL10n.sectionOutside,
    routes: [
      GoRoute(
        path: '/outside',
        builder: (context, state) => const OutsideScreen(),
      ),
    ],
  ),
  slots: {
    // The OpenStreetMap credit in Settings > About PetLoop. Settings shows
    // credits whatever the account may use (a licence notice).
    'about-credits': FeatureSlot(
      capability: ParkCapabilities.view,
      build: (c, r) => const OsmAboutCredit(),
    ),
  },
  actions: {
    // A park's page: {'parkId': '...'}.
    'park': FeatureAction.task(
      capability: ParkCapabilities.view,
      open: (c, r) async {
        final id = r.value<String>('parkId');
        if (id != null) await openParkPage(c, id);
      },
    ),
    // Choose a park (meetups' form); answers a PickedPark or null.
    'pick-park': FeatureAction(
      capability: ParkCapabilities.view,
      open: (c, r) => pickPark(c),
    ),
    'suggest-park': FeatureAction.task(
      capability: ParkCapabilities.suggest,
      open: (c, r) => openSuggestPark(c),
    ),
    'parks-review': FeatureAction.task(
      capability: ParkCapabilities.review,
      open: (c, r) => openParksReview(c),
    ),
  },
);
