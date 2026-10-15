/// Walk and play partners (Community > Outside > Partners), in one import:
///
/// ```dart
/// import 'package:pet_companion/features/meetups/meetups.dart';
/// ```
///
/// - `PartnersView`: the board (the module fills Outside's
///   'outside-partners' slot with it).
/// - `openMeetupForm`, `openMeetupPage`, `openMyMeetups` and the flows of
///   an ad (join, the responders' group, close, renew, report).
/// - The slots it fills elsewhere: the park page's `ParkPageSlots.meetups`
///   and `ParkPageSlots.postMeetup`, `ParkCard.meetupsSlot` on park cards,
///   `memberPageMeetupsSlot` on member pages.
/// - Data, state and rules: `services/meetups/`.
///
/// Design and owner steps: docs/meetups.md.
library;

export '../../services/meetups/data/fake_meetups_repository.dart';
export '../../services/meetups/data/meetup_models.dart';
export '../../services/meetups/data/meetups_repository.dart';
export '../../services/meetups/state/meetups_providers.dart';
export 'board/meetup_card.dart' show MeetupCard;
export 'board/meetups_area_picker.dart' show MeetupsAreaPicker;
export 'board/partners_filters_sheet.dart'
    show PartnersFiltersSheet, openPartnersFilters;
export 'board/partners_view.dart' show PartnersView;
export 'form/meetup_form_screen.dart' show MeetupFormScreen;
export 'meetup_actions.dart';
export 'meetups_state.dart';
export 'meetups_words.dart';
export 'mine/meetup_screen.dart' show MeetupScreen;
export 'mine/my_meetups_screen.dart' show MyMeetupsScreen;
export 'slots/meetup_slots.dart';
