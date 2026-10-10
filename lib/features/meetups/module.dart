import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../services/meetups/state/meetups_providers.dart';
import '../community/members/member_screen.dart' show memberPageMeetupsSlot;
import '../outdoors/outdoors.dart'
    show ParkCard, ParkPageSlots, outsidePartnersSlot;
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
