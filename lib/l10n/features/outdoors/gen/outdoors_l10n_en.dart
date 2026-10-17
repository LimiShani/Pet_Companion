// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'outdoors_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class OutdoorsL10nEn extends OutdoorsL10n {
  OutdoorsL10nEn([String locale = 'en']) : super(locale);

  @override
  String get sectionOutside => 'Outside';

  @override
  String get outsidePartners => 'Partners';

  @override
  String get outsideParks => 'Parks';

  @override
  String get partnersSoonTitle => 'Walk and play partners are on the way';

  @override
  String get partnersSoonBody => 'Soon you\'ll find people nearby for a walk or a playdate, right here. Meanwhile, the dog parks are one tap away.';

  @override
  String get partnersShowParks => 'Show the parks';

  @override
  String get areaQuestion => 'Where should we look?';

  @override
  String get locationWhy => '\"Near me\" asks the phone for its location once. It is never saved or sent.';

  @override
  String get nearMe => 'Near me';

  @override
  String get locating => 'Finding your location…';

  @override
  String get orPickCity => 'Or pick a city';

  @override
  String get cityHint => 'City or town';

  @override
  String get noCityMatch => 'No city by that name. Try another spelling.';

  @override
  String get problemDenied => 'Location access was not allowed. You can pick a city instead.';

  @override
  String get problemDeniedForever => 'Location access is off for PetLoop. It can be turned on in the phone\'s settings, or you can pick a city.';

  @override
  String get problemServiceOff => 'Location is switched off on this phone. Turn it on, or pick a city.';

  @override
  String get problemUnavailable => 'We could not get your location. Pick a city instead.';

  @override
  String get problemOutsideRegion => 'Dog parks are listed in Israel for now. Pick a city in Israel.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get areaNearMe => 'Near me';

  @override
  String areaNearMeIn(String place) {
    return 'Near me · $place';
  }

  @override
  String get changeArea => 'Change';

  @override
  String get changeAreaLabel => 'Change where to look';

  @override
  String areaChipLabel(String place) {
    return 'Area: $place. Change where to look';
  }

  @override
  String approximateLocation(int km) {
    return 'Your location is approximate (within about $km km).';
  }

  @override
  String get radiusCityOnly => 'City only';

  @override
  String radiusKm(int km) {
    return 'Up to $km km';
  }

  @override
  String get filtersLabel => 'Show parks with';

  @override
  String get detailFenced => 'Fenced';

  @override
  String get detailWater => 'Water tap';

  @override
  String get detailShade => 'Shade';

  @override
  String get detailLighting => 'Lighting';

  @override
  String get detailSmallDogs => 'Small-dog area';

  @override
  String get detailBenches => 'Benches';

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String get answerUnknown => 'Not known';

  @override
  String get answerUnknownShort => '?';

  @override
  String detailAnswer(String detail, String answer) {
    return '$detail: $answer';
  }

  @override
  String get myParks => 'My parks';

  @override
  String get parksInArea => 'Parks in the area';

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String get parkDefaultName => 'Dog park';

  @override
  String parkOnStreet(String street) {
    return 'Dog park · $street';
  }

  @override
  String parkInCity(String park, String city) {
    return '$park, $city';
  }

  @override
  String get closedLabel => 'Closed for renovation';

  @override
  String get searching => 'Looking for parks…';

  @override
  String get noParksTitle => 'No dog parks found here';

  @override
  String get noParksBody => 'The map doesn\'t list a dog park in this area yet. Know one? Tell us about it.';

  @override
  String get noParksWider => 'Look further';

  @override
  String get noFilterMatch => 'No park here is known to have all of these.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get loadFailed => 'We could not load the parks.';

  @override
  String get missingPark => 'Missing a park?';

  @override
  String get suggestPark => 'Suggest a park';

  @override
  String get sampleData => 'Sample parks: made-up places for trying the app.';

  @override
  String reviewEntry(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count park suggestions to review',
      one: '1 park suggestion to review',
    );
    return '$_temp0';
  }

  @override
  String get reviewEntryEmpty => 'Park suggestions';

  @override
  String get navigate => 'Navigate';

  @override
  String get navigateWith => 'Navigate with';

  @override
  String get waze => 'Waze';

  @override
  String get googleMaps => 'Google Maps';

  @override
  String get navigateFailed => 'We could not open the navigation app.';

  @override
  String get updateDetails => 'Update details';

  @override
  String get saveToMyParks => 'Save to My parks';

  @override
  String get removeFromMyParks => 'Remove from My parks';

  @override
  String get savedToMyParks => 'Saved to My parks';

  @override
  String get removedFromMyParks => 'Removed from My parks';

  @override
  String get saveFailed => 'That did not save. Try again.';

  @override
  String get whatsThere => 'What\'s there';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get unknownNote => 'Been there? \"Update details\" helps everyone know what to expect.';

  @override
  String get osmCredit => 'Map data © OpenStreetMap contributors';

  @override
  String get memberPark => 'Added by PetLoop members';

  @override
  String get parkGone => 'This park is no longer listed.';

  @override
  String get updateTitle => 'Update details';

  @override
  String get updateIntro => 'What did you see at the park? A reviewer checks it before it is shown to everyone.';

  @override
  String get closedSwitch => 'Closed for renovation';

  @override
  String get send => 'Send';

  @override
  String get nothingChanged => 'Change at least one detail first.';

  @override
  String get sentThanks => 'Thanks. A reviewer will check it soon.';

  @override
  String get rateLimited => 'That\'s a lot of suggestions for one day. Please try again tomorrow.';

  @override
  String get sendFailed => 'We could not send it. Try again.';

  @override
  String get suggestTitle => 'Suggest a park';

  @override
  String get suggestIntro => 'Tell us about a dog park the list is missing. A reviewer checks it before it is added.';

  @override
  String get parkNameLabel => 'Park name (optional)';

  @override
  String get whereIsIt => 'Where is it?';

  @override
  String get imHere => 'I\'m at the park now';

  @override
  String get imHereWhy => 'Your position is sent with the suggestion as the park\'s location, and nothing else.';

  @override
  String get hereSet => 'Location: where you are now';

  @override
  String get orTheCity => 'Or pick the city';

  @override
  String get placeLabel => 'Where in the city?';

  @override
  String get placeHint => 'For example: next to the community centre on Herzl St.';

  @override
  String get detailsOptional => 'What\'s there? (optional)';

  @override
  String get needLocation => 'Add the location: tap \"I\'m at the park now\", or pick the city and say where in it.';

  @override
  String get suggestSend => 'Send the suggestion';

  @override
  String get reviewTitle => 'Park suggestions';

  @override
  String get reviewEmpty => 'Nothing to review.';

  @override
  String get reviewNewPark => 'New park';

  @override
  String get reviewDetails => 'Details of a park';

  @override
  String get reviewVanished => 'No longer on OpenStreetMap';

  @override
  String get reviewVanishedBody => 'Keep it if it is still there, mark it closed, or remove it from the list.';

  @override
  String get reviewFromPhone => 'Location: the member\'s phone, at the park';

  @override
  String reviewFromCity(String city) {
    return 'Location: centre of $city. Check it on the map.';
  }

  @override
  String reviewPlace(String place) {
    return 'Place: $place';
  }

  @override
  String reviewChange(String detail, String from, String to) {
    return '$detail: $from → $to';
  }

  @override
  String get reviewClosed => 'Suggested: closed for renovation';

  @override
  String get reviewReopened => 'Suggested: open again';

  @override
  String get showOnMap => 'Show on the map';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get keepPark => 'Keep';

  @override
  String get markClosed => 'Mark closed';

  @override
  String get removePark => 'Remove';

  @override
  String get reviewDone => 'Done.';

  @override
  String get reviewFailed => 'That didn\'t work. Try again.';

  @override
  String get pickParkTitle => 'Choose a park';

  @override
  String get reviewerTools => 'For park reviewers';

  @override
  String get reopenPark => 'Open again';

  @override
  String get removeConfirm => 'Remove this park from the list? It is hidden, not deleted.';

  @override
  String get aboutMapData => 'Dog parks: map data © OpenStreetMap contributors, available under the Open Database License (ODbL).';

  @override
  String get addToOutside => 'Add to Outside';

  @override
  String hazardLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hazard reports near you this week.',
      one: '1 hazard report near you this week.',
    );
    return '$_temp0';
  }

  @override
  String get hazardKindCaterpillars => 'Caterpillars';

  @override
  String get hazardKindBait => 'Poison bait';

  @override
  String get hazardKindGlass => 'Broken glass';

  @override
  String get hazardKindInspector => 'Dog inspectors';

  @override
  String get hazardKindOther => 'Something else';

  @override
  String hazardAt(String kind, String place) {
    return '$kind at $place';
  }

  @override
  String hazardIn(String kind, String city) {
    return '$kind in $city';
  }

  @override
  String hazardNoted(String kind, String note) {
    return '$kind: $note';
  }
}
