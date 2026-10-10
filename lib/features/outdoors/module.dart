import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import 'outdoors.dart';

/// Community > Outside: dog parks today, walk and play partners (meetups)
/// later. The Community tab shows the section through the
/// 'community-outside' slot; see docs/dog_parks.md for the seams meetups
/// plugs into.
final outdoorsModule = FeatureModule(
  id: 'outdoors',
  slots: {
    'community-outside': FeatureSlot(
      capability: ParkCapabilities.view,
      build: (c, r) => const OutsideSection(),
    ),
    // The OpenStreetMap credit in Settings > About PetLoop.
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
