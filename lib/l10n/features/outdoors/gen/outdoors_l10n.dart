import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'outdoors_l10n_en.dart';
import 'outdoors_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of OutdoorsL10n
/// returned by `OutdoorsL10n.of(context)`.
///
/// Applications need to include `OutdoorsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/outdoors_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: OutdoorsL10n.localizationsDelegates,
///   supportedLocales: OutdoorsL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the OutdoorsL10n.supportedLocales
/// property.
abstract class OutdoorsL10n {
  OutdoorsL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static OutdoorsL10n of(BuildContext context) {
    return Localizations.of<OutdoorsL10n>(context, OutdoorsL10n)!;
  }

  static const LocalizationsDelegate<OutdoorsL10n> delegate = _OutdoorsL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// The fourth section of the Community tab: partners and dog parks.
  ///
  /// In en, this message translates to:
  /// **'Outside'**
  String get sectionOutside;

  /// Switch in Outside: people to walk or play with (coming later).
  ///
  /// In en, this message translates to:
  /// **'Partners'**
  String get outsidePartners;

  /// Switch in Outside: dog parks.
  ///
  /// In en, this message translates to:
  /// **'Parks'**
  String get outsideParks;

  /// No description provided for @partnersSoonTitle.
  ///
  /// In en, this message translates to:
  /// **'Walk and play partners are on the way'**
  String get partnersSoonTitle;

  /// No description provided for @partnersSoonBody.
  ///
  /// In en, this message translates to:
  /// **'Soon you\'ll find people nearby for a walk or a playdate, right here. Meanwhile, the dog parks are one tap away.'**
  String get partnersSoonBody;

  /// No description provided for @partnersShowParks.
  ///
  /// In en, this message translates to:
  /// **'Show the parks'**
  String get partnersShowParks;

  /// No description provided for @areaQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where should we look?'**
  String get areaQuestion;

  /// The one sentence about location privacy, under every "Near me" button of Outside (the parks and the partners).
  ///
  /// In en, this message translates to:
  /// **'\"Near me\" asks the phone for its location once. It is never saved or sent.'**
  String get locationWhy;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearMe;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get locating;

  /// No description provided for @orPickCity.
  ///
  /// In en, this message translates to:
  /// **'Or pick a city'**
  String get orPickCity;

  /// No description provided for @cityHint.
  ///
  /// In en, this message translates to:
  /// **'City or town'**
  String get cityHint;

  /// No description provided for @noCityMatch.
  ///
  /// In en, this message translates to:
  /// **'No city by that name. Try another spelling.'**
  String get noCityMatch;

  /// No description provided for @problemDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access was not allowed. You can pick a city instead.'**
  String get problemDenied;

  /// No description provided for @problemDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is off for PetLoop. It can be turned on in the phone\'s settings, or you can pick a city.'**
  String get problemDeniedForever;

  /// No description provided for @problemServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone. Turn it on, or pick a city.'**
  String get problemServiceOff;

  /// No description provided for @problemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not get your location. Pick a city instead.'**
  String get problemUnavailable;

  /// No description provided for @problemOutsideRegion.
  ///
  /// In en, this message translates to:
  /// **'Dog parks are listed in Israel for now. Pick a city in Israel.'**
  String get problemOutsideRegion;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @areaNearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get areaNearMe;

  /// "Near me" and the town the phone is in.
  ///
  /// In en, this message translates to:
  /// **'Near me · {place}'**
  String areaNearMeIn(String place);

  /// No description provided for @changeArea.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeArea;

  /// No description provided for @changeAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Change where to look'**
  String get changeAreaLabel;

  /// Screen-reader label of the area chip in the Outside header.
  ///
  /// In en, this message translates to:
  /// **'Area: {place}. Change where to look'**
  String areaChipLabel(String place);

  /// No description provided for @approximateLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is approximate (within about {km} km).'**
  String approximateLocation(int km);

  /// No description provided for @radiusCityOnly.
  ///
  /// In en, this message translates to:
  /// **'City only'**
  String get radiusCityOnly;

  /// No description provided for @radiusKm.
  ///
  /// In en, this message translates to:
  /// **'Up to {km} km'**
  String radiusKm(int km);

  /// Label before the filter chips.
  ///
  /// In en, this message translates to:
  /// **'Show parks with'**
  String get filtersLabel;

  /// No description provided for @detailFenced.
  ///
  /// In en, this message translates to:
  /// **'Fenced'**
  String get detailFenced;

  /// No description provided for @detailWater.
  ///
  /// In en, this message translates to:
  /// **'Water tap'**
  String get detailWater;

  /// No description provided for @detailShade.
  ///
  /// In en, this message translates to:
  /// **'Shade'**
  String get detailShade;

  /// No description provided for @detailLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get detailLighting;

  /// No description provided for @detailSmallDogs.
  ///
  /// In en, this message translates to:
  /// **'Small-dog area'**
  String get detailSmallDogs;

  /// No description provided for @detailBenches.
  ///
  /// In en, this message translates to:
  /// **'Benches'**
  String get detailBenches;

  /// No description provided for @answerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get answerYes;

  /// No description provided for @answerNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get answerNo;

  /// No description provided for @answerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not known'**
  String get answerUnknown;

  /// "Not known" on the small Yes · No · ? switch of a park detail (screen readers say answerUnknown).
  ///
  /// In en, this message translates to:
  /// **'?'**
  String get answerUnknownShort;

  /// A detail and its answer, read by screen readers.
  ///
  /// In en, this message translates to:
  /// **'{detail}: {answer}'**
  String detailAnswer(String detail, String answer);

  /// No description provided for @myParks.
  ///
  /// In en, this message translates to:
  /// **'My parks'**
  String get myParks;

  /// No description provided for @parksInArea.
  ///
  /// In en, this message translates to:
  /// **'Parks in the area'**
  String get parksInArea;

  /// A distance, e.g. "0.8 km".
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @distanceM.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distanceM(int m);

  /// The name of a park that has none on the map.
  ///
  /// In en, this message translates to:
  /// **'Dog park'**
  String get parkDefaultName;

  /// An unnamed park, named after the nearest street.
  ///
  /// In en, this message translates to:
  /// **'Dog park · {street}'**
  String parkOnStreet(String street);

  /// No description provided for @parkInCity.
  ///
  /// In en, this message translates to:
  /// **'{park}, {city}'**
  String parkInCity(String park, String city);

  /// No description provided for @closedLabel.
  ///
  /// In en, this message translates to:
  /// **'Closed for renovation'**
  String get closedLabel;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Looking for parks…'**
  String get searching;

  /// No description provided for @noParksTitle.
  ///
  /// In en, this message translates to:
  /// **'No dog parks found here'**
  String get noParksTitle;

  /// No description provided for @noParksBody.
  ///
  /// In en, this message translates to:
  /// **'The map doesn\'t list a dog park in this area yet. Know one? Tell us about it.'**
  String get noParksBody;

  /// No description provided for @noParksWider.
  ///
  /// In en, this message translates to:
  /// **'Look further'**
  String get noParksWider;

  /// No description provided for @noFilterMatch.
  ///
  /// In en, this message translates to:
  /// **'No park here is known to have all of these.'**
  String get noFilterMatch;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the parks.'**
  String get loadFailed;

  /// No description provided for @missingPark.
  ///
  /// In en, this message translates to:
  /// **'Missing a park?'**
  String get missingPark;

  /// No description provided for @suggestPark.
  ///
  /// In en, this message translates to:
  /// **'Suggest a park'**
  String get suggestPark;

  /// No description provided for @sampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample parks: made-up places for trying the app.'**
  String get sampleData;

  /// No description provided for @reviewEntry.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 park suggestion to review} other{{count} park suggestions to review}}'**
  String reviewEntry(int count);

  /// No description provided for @reviewEntryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Park suggestions'**
  String get reviewEntryEmpty;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @navigateWith.
  ///
  /// In en, this message translates to:
  /// **'Navigate with'**
  String get navigateWith;

  /// Brand name: never translated.
  ///
  /// In en, this message translates to:
  /// **'Waze'**
  String get waze;

  /// Brand name: never translated.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get googleMaps;

  /// No description provided for @navigateFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not open the navigation app.'**
  String get navigateFailed;

  /// No description provided for @updateDetails.
  ///
  /// In en, this message translates to:
  /// **'Update details'**
  String get updateDetails;

  /// No description provided for @saveToMyParks.
  ///
  /// In en, this message translates to:
  /// **'Save to My parks'**
  String get saveToMyParks;

  /// No description provided for @removeFromMyParks.
  ///
  /// In en, this message translates to:
  /// **'Remove from My parks'**
  String get removeFromMyParks;

  /// No description provided for @savedToMyParks.
  ///
  /// In en, this message translates to:
  /// **'Saved to My parks'**
  String get savedToMyParks;

  /// No description provided for @removedFromMyParks.
  ///
  /// In en, this message translates to:
  /// **'Removed from My parks'**
  String get removedFromMyParks;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not save. Try again.'**
  String get saveFailed;

  /// No description provided for @whatsThere.
  ///
  /// In en, this message translates to:
  /// **'What\'s there'**
  String get whatsThere;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @unknownNote.
  ///
  /// In en, this message translates to:
  /// **'Been there? \"Update details\" helps everyone know what to expect.'**
  String get unknownNote;

  /// The licence credit; "OpenStreetMap contributors" stays in English.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors'**
  String get osmCredit;

  /// No description provided for @memberPark.
  ///
  /// In en, this message translates to:
  /// **'Added by PetLoop members'**
  String get memberPark;

  /// No description provided for @parkGone.
  ///
  /// In en, this message translates to:
  /// **'This park is no longer listed.'**
  String get parkGone;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update details'**
  String get updateTitle;

  /// No description provided for @updateIntro.
  ///
  /// In en, this message translates to:
  /// **'What did you see at the park? A reviewer checks it before it is shown to everyone.'**
  String get updateIntro;

  /// No description provided for @closedSwitch.
  ///
  /// In en, this message translates to:
  /// **'Closed for renovation'**
  String get closedSwitch;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @nothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Change at least one detail first.'**
  String get nothingChanged;

  /// No description provided for @sentThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks. A reviewer will check it soon.'**
  String get sentThanks;

  /// No description provided for @rateLimited.
  ///
  /// In en, this message translates to:
  /// **'That\'s a lot of suggestions for one day. Please try again tomorrow.'**
  String get rateLimited;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send it. Try again.'**
  String get sendFailed;

  /// No description provided for @suggestTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest a park'**
  String get suggestTitle;

  /// No description provided for @suggestIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell us about a dog park the list is missing. A reviewer checks it before it is added.'**
  String get suggestIntro;

  /// No description provided for @parkNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Park name (optional)'**
  String get parkNameLabel;

  /// No description provided for @whereIsIt.
  ///
  /// In en, this message translates to:
  /// **'Where is it?'**
  String get whereIsIt;

  /// No description provided for @imHere.
  ///
  /// In en, this message translates to:
  /// **'I\'m at the park now'**
  String get imHere;

  /// No description provided for @imHereWhy.
  ///
  /// In en, this message translates to:
  /// **'Your position is sent with the suggestion as the park\'s location, and nothing else.'**
  String get imHereWhy;

  /// No description provided for @hereSet.
  ///
  /// In en, this message translates to:
  /// **'Location: where you are now'**
  String get hereSet;

  /// No description provided for @orTheCity.
  ///
  /// In en, this message translates to:
  /// **'Or pick the city'**
  String get orTheCity;

  /// No description provided for @placeLabel.
  ///
  /// In en, this message translates to:
  /// **'Where in the city?'**
  String get placeLabel;

  /// No description provided for @placeHint.
  ///
  /// In en, this message translates to:
  /// **'For example: next to the community centre on Herzl St.'**
  String get placeHint;

  /// No description provided for @detailsOptional.
  ///
  /// In en, this message translates to:
  /// **'What\'s there? (optional)'**
  String get detailsOptional;

  /// No description provided for @needLocation.
  ///
  /// In en, this message translates to:
  /// **'Add the location: tap \"I\'m at the park now\", or pick the city and say where in it.'**
  String get needLocation;

  /// No description provided for @suggestSend.
  ///
  /// In en, this message translates to:
  /// **'Send the suggestion'**
  String get suggestSend;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Park suggestions'**
  String get reviewTitle;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review.'**
  String get reviewEmpty;

  /// No description provided for @reviewNewPark.
  ///
  /// In en, this message translates to:
  /// **'New park'**
  String get reviewNewPark;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'Details of a park'**
  String get reviewDetails;

  /// No description provided for @reviewVanished.
  ///
  /// In en, this message translates to:
  /// **'No longer on OpenStreetMap'**
  String get reviewVanished;

  /// No description provided for @reviewVanishedBody.
  ///
  /// In en, this message translates to:
  /// **'Keep it if it is still there, mark it closed, or remove it from the list.'**
  String get reviewVanishedBody;

  /// No description provided for @reviewFromPhone.
  ///
  /// In en, this message translates to:
  /// **'Location: the member\'s phone, at the park'**
  String get reviewFromPhone;

  /// No description provided for @reviewFromCity.
  ///
  /// In en, this message translates to:
  /// **'Location: centre of {city}. Check it on the map.'**
  String reviewFromCity(String city);

  /// No description provided for @reviewPlace.
  ///
  /// In en, this message translates to:
  /// **'Place: {place}'**
  String reviewPlace(String place);

  /// No description provided for @reviewChange.
  ///
  /// In en, this message translates to:
  /// **'{detail}: {from} → {to}'**
  String reviewChange(String detail, String from, String to);

  /// No description provided for @reviewClosed.
  ///
  /// In en, this message translates to:
  /// **'Suggested: closed for renovation'**
  String get reviewClosed;

  /// No description provided for @reviewReopened.
  ///
  /// In en, this message translates to:
  /// **'Suggested: open again'**
  String get reviewReopened;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on the map'**
  String get showOnMap;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @keepPark.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepPark;

  /// No description provided for @markClosed.
  ///
  /// In en, this message translates to:
  /// **'Mark closed'**
  String get markClosed;

  /// No description provided for @removePark.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removePark;

  /// No description provided for @reviewDone.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get reviewDone;

  /// No description provided for @reviewFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again.'**
  String get reviewFailed;

  /// No description provided for @pickParkTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a park'**
  String get pickParkTitle;

  /// No description provided for @reviewerTools.
  ///
  /// In en, this message translates to:
  /// **'For park reviewers'**
  String get reviewerTools;

  /// No description provided for @reopenPark.
  ///
  /// In en, this message translates to:
  /// **'Open again'**
  String get reopenPark;

  /// No description provided for @removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this park from the list? It is hidden, not deleted.'**
  String get removeConfirm;

  /// No description provided for @aboutMapData.
  ///
  /// In en, this message translates to:
  /// **'Dog parks: map data © OpenStreetMap contributors, available under the Open Database License (ODbL).'**
  String get aboutMapData;

  /// The Outside tab's "+" button (for a screen reader) and the title of the sheet it opens.
  ///
  /// In en, this message translates to:
  /// **'Add to Outside'**
  String get addToOutside;

  /// The line above the Partners and Parks lists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hazard report near you this week.} other{{count} hazard reports near you this week.}}'**
  String hazardLineCount(int count);

  /// Hazard kind: pine processionary caterpillars.
  ///
  /// In en, this message translates to:
  /// **'Caterpillars'**
  String get hazardKindCaterpillars;

  /// No description provided for @hazardKindBait.
  ///
  /// In en, this message translates to:
  /// **'Poison bait'**
  String get hazardKindBait;

  /// No description provided for @hazardKindGlass.
  ///
  /// In en, this message translates to:
  /// **'Broken glass'**
  String get hazardKindGlass;

  /// Hazard kind: municipal inspectors handing out fines.
  ///
  /// In en, this message translates to:
  /// **'Dog inspectors'**
  String get hazardKindInspector;

  /// No description provided for @hazardKindOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get hazardKindOther;

  /// No description provided for @hazardAt.
  ///
  /// In en, this message translates to:
  /// **'{kind} at {place}'**
  String hazardAt(String kind, String place);

  /// No description provided for @hazardIn.
  ///
  /// In en, this message translates to:
  /// **'{kind} in {city}'**
  String hazardIn(String kind, String city);

  /// No description provided for @hazardNoted.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {note}'**
  String hazardNoted(String kind, String note);
}

class _OutdoorsL10nDelegate extends LocalizationsDelegate<OutdoorsL10n> {
  const _OutdoorsL10nDelegate();

  @override
  Future<OutdoorsL10n> load(Locale locale) {
    return SynchronousFuture<OutdoorsL10n>(lookupOutdoorsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_OutdoorsL10nDelegate old) => false;
}

OutdoorsL10n lookupOutdoorsL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return OutdoorsL10nEn();
    case 'he': return OutdoorsL10nHe();
  }

  throw FlutterError(
    'OutdoorsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
