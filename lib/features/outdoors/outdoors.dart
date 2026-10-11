/// Community > Outside: dog parks, and the seams for walk and play
/// partners (meetups), in one import:
///
/// ```dart
/// import 'package:pet_companion/features/outdoors/outdoors.dart';
/// ```
///
/// - `OutsideSection`: the "Partners | Parks" section the Community tab
///   shows. Partners shows the 'outside-partners' slot when a module fills
///   it, a "coming soon" card until then.
/// - `openParkPage(context, parkId)`: a park's page. Its slots
///   `ParkPageSlots.meetups` and `ParkPageSlots.postMeetup` receive
///   `parkId`, `parkName` and `parkTags`.
/// - `pickPark(context)`: choose a park ("My parks" first, nearest first);
///   answers a `PickedPark` (id, display name, tags).
/// - `openSuggestPark`, `openParksReview`.
/// - Areas and radii: `ParkArea`, `NearMeArea`, `CityArea`, `ParkRadius`,
///   `coarseBox` (services/outdoors/data/park_area.dart) over the shared
///   localities (`israelLocalities`, `VetRegion.localitiesWithin`).
///
/// Design, data source and owner steps: docs/dog_parks.md.
library;

export '../../services/outdoors/data/fake_parks_repository.dart';
export '../../services/outdoors/data/park_area.dart';
export '../../services/outdoors/data/park_launcher.dart';
export '../../services/outdoors/data/park_models.dart';
export '../../services/outdoors/data/parks_repository.dart';
export '../../services/outdoors/state/parks_providers.dart';
export 'outdoors_words.dart';
export 'outside_section.dart'
    show OutsideSection, OutdoorsKeeper, outsidePartnersSlot, slotAvailable;
export 'outside_screen.dart' show OutsideScreen;
export 'parks/park_area_picker.dart' show ParkAreaPicker, ParkAreaBar;
export 'parks/park_picker.dart' show PickedPark, ParkPickerScreen, pickPark;
export 'parks/park_screen.dart' show ParkScreen, ParkPageSlots, openParkPage;
export 'parks/parks_view.dart' show ParksView;
export 'parks/suggest_park_screen.dart' show SuggestParkScreen, openSuggestPark;
export 'parks/update_details_sheet.dart'
    show UpdateDetailsSheet, openUpdateDetails;
export 'review/parks_review_screen.dart'
    show ParksReviewScreen, openParksReview;
export 'widgets/about_credit.dart' show OsmAboutCredit;
export 'widgets/park_widgets.dart'
    show OsmCredit, ParkCard, ParkTags, parkDetailIcon;
