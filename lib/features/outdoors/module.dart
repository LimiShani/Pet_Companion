import 'package:flutter/material.dart';
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
  // Outside's "+" (meetups adds "Plan a walk or play date" and "Going out
  // now" before these).
  add: {
    AddTab.outside: [
      AddEntry(
        id: 'report-hazard',
        capability: HazardCapabilities.post,
        area: AppArea.community,
        icon: Icons.warning_amber_rounded,
        label: (c) => c.outdoorsL10n.addReportHazard,
        order: 5,
        open: (c, r) => openReportHazard(c),
      ),
      AddEntry(
        id: 'suggest-park',
        capability: ParkCapabilities.suggest,
        area: AppArea.community,
        icon: Icons.park_rounded,
        label: (c) => c.outdoorsL10n.suggestPark,
        order: 10,
        open: (c, r) => openSuggestPark(c),
      ),
    ],
  },
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
    // The hazard reports around Outside's area.
    'hazards': FeatureAction.task(
      capability: HazardCapabilities.view,
      open: (c, r) => openHazards(c),
    ),
    'parks-review': FeatureAction.task(
      capability: ParkCapabilities.review,
      open: (c, r) => openParksReview(c),
    ),
  },
);
