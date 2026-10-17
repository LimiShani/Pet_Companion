import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../services/meetups/state/meetups_providers.dart';
import '../community/members/member_screen.dart' show memberPageMeetupsSlot;
import '../outdoors/outdoors.dart'
    show ParkCard, ParkPageSlots, outsidePartnersSlot;
import 'board/going_now.dart';
import 'board/partners_view.dart';
import 'meetup_actions.dart';
import 'slots/meetup_slots.dart';

/// Walk and play partners: Community > Outside > Partners, the park page's
/// meetups, the park cards' badge and a member page's ads. Design and
/// owner steps: docs/meetups.md.
final meetupsModule = FeatureModule(
  id: 'meetups',
  slots: {
    outsidePartnersSlot: FeatureSlot(
      capability: MeetupCapabilities.view,
      build: (c, r) => const PartnersView(),
    ),
    ParkPageSlots.meetups: FeatureSlot(
      capability: MeetupCapabilities.view,
      build: (c, r) => ParkMeetupsSection(parkId: r.value<String>('parkId')!),
    ),
    ParkPageSlots.postMeetup: FeatureSlot(
      capability: MeetupCapabilities.post,
      build: (c, r) =>
          PostMeetupHereButton(parkId: r.value<String>('parkId')!),
    ),
    ParkCard.meetupsSlot: FeatureSlot(
      capability: MeetupCapabilities.view,
      build: (c, r) => ParkCardMeetups(parkId: r.value<String>('parkId')!),
    ),
    memberPageMeetupsSlot: FeatureSlot(
      capability: MeetupCapabilities.view,
      build: (c, r) =>
          MemberMeetupsSection(memberId: r.value<String>('memberId')!),
    ),
  },
  // A new ad from the Outside tab's "+".
  add: {
    AddTab.outside: [
      AddEntry(
        id: 'plan-walk',
        capability: MeetupCapabilities.post,
        area: AppArea.community,
        icon: Icons.directions_walk_rounded,
        label: (c) => c.meetupsL10n.addPlanWalk,
        order: 0,
        open: (c, r) => openMeetupForm(c),
      ),
      // "Going out now": the short sheet of the Partners card.
      AddEntry(
        id: 'going-now',
        capability: MeetupCapabilities.post,
        area: AppArea.community,
        icon: Icons.schedule_rounded,
        label: (c) => c.meetupsL10n.addGoingNow,
        order: 1,
        open: (c, r) => openGoingNowSheet(c),
      ),
    ],
  },
  actions: {
    // An ad's page: {'id': '...'} (a push's 'meetup:<id>').
    'meetup': FeatureAction.task(
      capability: MeetupCapabilities.view,
      open: (c, r) async {
        final id = r.value<String>('id');
        if (id != null) await openMeetupPage(c, id);
      },
    ),
    'new-meetup': FeatureAction.task(
      capability: MeetupCapabilities.post,
      open: (c, r) => openMeetupForm(c),
    ),
  },
);
