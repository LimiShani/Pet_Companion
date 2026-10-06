import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'findvet_l10n_en.dart';
import 'findvet_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FindVetL10n
/// returned by `FindVetL10n.of(context)`.
///
/// Applications need to include `FindVetL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/findvet_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FindVetL10n.localizationsDelegates,
///   supportedLocales: FindVetL10n.supportedLocales,
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
/// be consistent with the languages listed in the FindVetL10n.supportedLocales
/// property.
abstract class FindVetL10n {
  FindVetL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FindVetL10n of(BuildContext context) {
    return Localizations.of<FindVetL10n>(context, FindVetL10n)!;
  }

  static const LocalizationsDelegate<FindVetL10n> delegate =
      _FindVetL10nDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @findVetTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a vet'**
  String get findVetTitle;

  /// No description provided for @findVetMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency or regular care nearby'**
  String get findVetMenuSubtitle;

  /// Link on the sign-in screen: opens the emergency search without an account.
  ///
  /// In en, this message translates to:
  /// **'Pet emergency? Find a vet'**
  String get loginEmergencyLink;

  /// No description provided for @emergencySheetFindVet.
  ///
  /// In en, this message translates to:
  /// **'Find an emergency vet nearby'**
  String get emergencySheetFindVet;

  /// No description provided for @choiceQuestion.
  ///
  /// In en, this message translates to:
  /// **'What do you need?'**
  String get choiceQuestion;

  /// No description provided for @emergencyChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency care'**
  String get emergencyChoiceTitle;

  /// No description provided for @emergencyChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'The nearest places that advertise emergency care, with Call and Directions.'**
  String get emergencyChoiceBody;

  /// No description provided for @longTermChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Long term care'**
  String get longTermChoiceTitle;

  /// No description provided for @longTermChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Nearby practices with their details, and a regular vet to save.'**
  String get longTermChoiceBody;

  /// No description provided for @modeEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get modeEmergency;

  /// No description provided for @modeLongTerm.
  ///
  /// In en, this message translates to:
  /// **'Long term'**
  String get modeLongTerm;

  /// No description provided for @areaQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where should we look?'**
  String get areaQuestion;

  /// No description provided for @locationWhy.
  ///
  /// In en, this message translates to:
  /// **'To find vets near you, PetLoop asks the phone for your location once. It is used for this search only and is not saved.'**
  String get locationWhy;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get locating;

  /// No description provided for @orTypePlace.
  ///
  /// In en, this message translates to:
  /// **'Or type a city, address or postcode'**
  String get orTypePlace;

  /// No description provided for @placeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'City, address or postcode'**
  String get placeSearchHint;

  /// No description provided for @placeSearchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get placeSearchButton;

  /// No description provided for @placeNoMatch.
  ///
  /// In en, this message translates to:
  /// **'We could not find that place. Try the name of a city.'**
  String get placeNoMatch;

  /// No description provided for @placeLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not look that up right now. Try the name of a city.'**
  String get placeLookupFailed;

  /// No description provided for @problemDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access was not allowed. You can type a place instead.'**
  String get problemDenied;

  /// No description provided for @problemDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is off for PetLoop. It can be turned on in the phone\'s settings, or you can type a place.'**
  String get problemDeniedForever;

  /// No description provided for @problemServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone. Turn it on, or type a place.'**
  String get problemServiceOff;

  /// No description provided for @problemUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We could not get your location. Type a place instead.'**
  String get problemUnavailable;

  /// No description provided for @problemOutsideRegion.
  ///
  /// In en, this message translates to:
  /// **'Find a vet works in Israel for now. Type a place in Israel.'**
  String get problemOutsideRegion;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @searchingNear.
  ///
  /// In en, this message translates to:
  /// **'Searching near {place}'**
  String searchingNear(String place);

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'your location'**
  String get yourLocation;

  /// No description provided for @approximateLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is approximate (within about {km} km). Change the area if it looks wrong.'**
  String approximateLocation(int km);

  /// No description provided for @changeArea.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeArea;

  /// No description provided for @changeAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Change the area'**
  String get changeAreaLabel;

  /// No description provided for @withinKm.
  ///
  /// In en, this message translates to:
  /// **'Within {km} km'**
  String withinKm(int km);

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Looking for vets…'**
  String get searching;

  /// No description provided for @callFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Call before you go'**
  String get callFirstTitle;

  /// No description provided for @callFirstBody.
  ///
  /// In en, this message translates to:
  /// **'Opening hours and \"24/7\" do not tell us whether they can take your pet right now.'**
  String get callFirstBody;

  /// No description provided for @callToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Call to confirm they can receive your pet'**
  String get callToConfirm;

  /// No description provided for @evidenceListed.
  ///
  /// In en, this message translates to:
  /// **'Listed nearby'**
  String get evidenceListed;

  /// No description provided for @evidenceListedNote.
  ///
  /// In en, this message translates to:
  /// **'Found in a map listing. Emergency care is not confirmed by PetLoop.'**
  String get evidenceListedNote;

  /// No description provided for @evidenceAdvertised.
  ///
  /// In en, this message translates to:
  /// **'Emergency service advertised'**
  String get evidenceAdvertised;

  /// No description provided for @evidenceAdvertisedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Emergency service advertised · {schedule}'**
  String evidenceAdvertisedSchedule(String schedule);

  /// No description provided for @evidenceSourceChecked.
  ///
  /// In en, this message translates to:
  /// **'On their own website, last checked {date}'**
  String evidenceSourceChecked(String date);

  /// No description provided for @evidenceSourceNotChecked.
  ///
  /// In en, this message translates to:
  /// **'On their own website, not checked again yet'**
  String get evidenceSourceNotChecked;

  /// No description provided for @evidenceUnverified.
  ///
  /// In en, this message translates to:
  /// **'Emergency service not re-confirmed'**
  String get evidenceUnverified;

  /// No description provided for @evidenceUnverifiedNote.
  ///
  /// In en, this message translates to:
  /// **'Their website did not show it when we last looked ({date}). Ask when you call.'**
  String evidenceUnverifiedNote(String date);

  /// No description provided for @evidenceUnverifiedNoDate.
  ///
  /// In en, this message translates to:
  /// **'We could not confirm it on their website lately. Ask when you call.'**
  String get evidenceUnverifiedNoDate;

  /// No description provided for @evidenceOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Published hours: open now'**
  String get evidenceOpenNow;

  /// No description provided for @evidenceClosedNow.
  ///
  /// In en, this message translates to:
  /// **'Published hours: closed now'**
  String get evidenceClosedNow;

  /// No description provided for @evidenceHoursUnknown.
  ///
  /// In en, this message translates to:
  /// **'Opening hours not published'**
  String get evidenceHoursUnknown;

  /// No description provided for @evidenceAccepting.
  ///
  /// In en, this message translates to:
  /// **'Accepting patients now'**
  String get evidenceAccepting;

  /// No description provided for @evidenceLimited.
  ///
  /// In en, this message translates to:
  /// **'Accepting patients, with limits'**
  String get evidenceLimited;

  /// No description provided for @evidenceDiverting.
  ///
  /// In en, this message translates to:
  /// **'Sending patients elsewhere right now'**
  String get evidenceDiverting;

  /// No description provided for @evidenceReported.
  ///
  /// In en, this message translates to:
  /// **'Reported by the facility at {time}, valid until {until}'**
  String evidenceReported(String time, String until);

  /// No description provided for @staleNote.
  ///
  /// In en, this message translates to:
  /// **'PetLoop last checked these details on {date}.'**
  String staleNote(String date);

  /// No description provided for @staleNever.
  ///
  /// In en, this message translates to:
  /// **'PetLoop has not checked these details yet.'**
  String get staleNever;

  /// No description provided for @closedTemporarily.
  ///
  /// In en, this message translates to:
  /// **'Listed as temporarily closed'**
  String get closedTemporarily;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @distanceM.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distanceM(int m);

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @callName.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String callName(String name);

  /// No description provided for @noPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number listed'**
  String get noPhone;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @directionsName.
  ///
  /// In en, this message translates to:
  /// **'Directions to {name}'**
  String directionsName(String name);

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @viewOnMaps.
  ///
  /// In en, this message translates to:
  /// **'View on Google Maps'**
  String get viewOnMaps;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveName.
  ///
  /// In en, this message translates to:
  /// **'Save {name} as a regular vet'**
  String saveName(String name);

  /// No description provided for @saveChoosePet.
  ///
  /// In en, this message translates to:
  /// **'Save as the regular vet of…'**
  String get saveChoosePet;

  /// No description provided for @saveForPet.
  ///
  /// In en, this message translates to:
  /// **'Save for {pet}'**
  String saveForPet(String pet);

  /// No description provided for @saveNeedsPet.
  ///
  /// In en, this message translates to:
  /// **'Add a pet first to save a regular vet.'**
  String get saveNeedsPet;

  /// No description provided for @savedVet.
  ///
  /// In en, this message translates to:
  /// **'Saved as a regular vet.'**
  String get savedVet;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @fewerDetails.
  ///
  /// In en, this message translates to:
  /// **'Fewer details'**
  String get fewerDetails;

  /// No description provided for @hoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Published hours'**
  String get hoursTitle;

  /// No description provided for @speciesLine.
  ///
  /// In en, this message translates to:
  /// **'Treats: {list}'**
  String speciesLine(String list);

  /// No description provided for @servicesLine.
  ///
  /// In en, this message translates to:
  /// **'Services: {list}'**
  String servicesLine(String list);

  /// No description provided for @factSource.
  ///
  /// In en, this message translates to:
  /// **'From their website, checked {date}'**
  String factSource(String date);

  /// No description provided for @factSourceNoDate.
  ///
  /// In en, this message translates to:
  /// **'From their website'**
  String get factSourceNoDate;

  /// No description provided for @speciesDog.
  ///
  /// In en, this message translates to:
  /// **'dogs'**
  String get speciesDog;

  /// No description provided for @speciesCat.
  ///
  /// In en, this message translates to:
  /// **'cats'**
  String get speciesCat;

  /// No description provided for @speciesRabbit.
  ///
  /// In en, this message translates to:
  /// **'rabbits'**
  String get speciesRabbit;

  /// No description provided for @speciesBird.
  ///
  /// In en, this message translates to:
  /// **'birds'**
  String get speciesBird;

  /// No description provided for @speciesReptile.
  ///
  /// In en, this message translates to:
  /// **'reptiles'**
  String get speciesReptile;

  /// No description provided for @speciesRodent.
  ///
  /// In en, this message translates to:
  /// **'small rodents'**
  String get speciesRodent;

  /// No description provided for @speciesExotic.
  ///
  /// In en, this message translates to:
  /// **'exotic animals'**
  String get speciesExotic;

  /// No description provided for @speciesHorse.
  ///
  /// In en, this message translates to:
  /// **'horses'**
  String get speciesHorse;

  /// No description provided for @speciesFarm.
  ///
  /// In en, this message translates to:
  /// **'farm animals'**
  String get speciesFarm;

  /// No description provided for @sectionAdvertised.
  ///
  /// In en, this message translates to:
  /// **'Advertising emergency service'**
  String get sectionAdvertised;

  /// No description provided for @sectionOther.
  ///
  /// In en, this message translates to:
  /// **'Other vets nearby'**
  String get sectionOther;

  /// No description provided for @sectionOtherNote.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed as emergency services. Call to ask.'**
  String get sectionOtherNote;

  /// No description provided for @sectionUnverified.
  ///
  /// In en, this message translates to:
  /// **'Emergency service not re-confirmed'**
  String get sectionUnverified;

  /// No description provided for @firstOption.
  ///
  /// In en, this message translates to:
  /// **'Nearest option'**
  String get firstOption;

  /// No description provided for @secondOption.
  ///
  /// In en, this message translates to:
  /// **'Second option'**
  String get secondOption;

  /// No description provided for @onlyOneAdvertised.
  ///
  /// In en, this message translates to:
  /// **'Only one place advertising emergency care was found within {km} km.'**
  String onlyOneAdvertised(int km);

  /// No description provided for @noticeExpanded.
  ///
  /// In en, this message translates to:
  /// **'Nothing close enough, so we searched up to {km} km.'**
  String noticeExpanded(int km);

  /// No description provided for @noticeProviderDown.
  ///
  /// In en, this message translates to:
  /// **'Live search is not working right now. These are emergency facilities from PetLoop\'s own directory, each with the date we last checked it.'**
  String get noticeProviderDown;

  /// No description provided for @noticeProviderDownLongTerm.
  ///
  /// In en, this message translates to:
  /// **'Live search is not working right now. These practices come from PetLoop\'s own directory.'**
  String get noticeProviderDownLongTerm;

  /// No description provided for @noticeDirectoryCopy.
  ///
  /// In en, this message translates to:
  /// **'No connection. This is the copy of PetLoop\'s directory saved on this phone on {date}.'**
  String noticeDirectoryCopy(String date);

  /// No description provided for @noResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No vets found nearby'**
  String get noResultsTitle;

  /// No description provided for @noResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing within {km} km.'**
  String noResultsBody(int km);

  /// No description provided for @noEmergencyResultsBody.
  ///
  /// In en, this message translates to:
  /// **'No place advertising emergency care within {km} km.'**
  String noEmergencyResultsBody(int km);

  /// No description provided for @searchWider.
  ///
  /// In en, this message translates to:
  /// **'Search up to {km} km'**
  String searchWider(int km);

  /// No description provided for @tryAnotherArea.
  ///
  /// In en, this message translates to:
  /// **'Try another area'**
  String get tryAnotherArea;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not search'**
  String get errorTitle;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection, and no saved copy of the directory yet. Check the connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many searches in a short time. Please try again in a few minutes.'**
  String get errorRateLimited;

  /// No description provided for @errorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Search is not available right now. Please try again.'**
  String get errorUnavailable;

  /// No description provided for @errorInvalid.
  ///
  /// In en, this message translates to:
  /// **'That place cannot be searched. Try another one.'**
  String get errorInvalid;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @demoBanner.
  ///
  /// In en, this message translates to:
  /// **'Sample data: these places are made up. The real search works once the app is connected to its server.'**
  String get demoBanner;

  /// Followed by the untranslated text "Google Maps" (Google requires it as is).
  ///
  /// In en, this message translates to:
  /// **'Map listings:'**
  String get listingsFrom;

  /// No description provided for @legendLink.
  ///
  /// In en, this message translates to:
  /// **'What the labels mean'**
  String get legendLink;

  /// No description provided for @legendListedBody.
  ///
  /// In en, this message translates to:
  /// **'Found in a map listing near the area. That alone says nothing about emergency care, whatever the name says.'**
  String get legendListedBody;

  /// No description provided for @legendAdvertisedBody.
  ///
  /// In en, this message translates to:
  /// **'The facility\'s own website (or the facility itself) says it offers emergency care. PetLoop checks this every week and shows the date of the last check.'**
  String get legendAdvertisedBody;

  /// No description provided for @legendOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Its published hours say it is open now. That does not mean a vet is free to see your pet.'**
  String get legendOpenBody;

  /// No description provided for @legendAcceptingBody.
  ///
  /// In en, this message translates to:
  /// **'Shown only when the facility itself has reported that it is taking patients, and only until that report expires. Otherwise you will see \"Call to confirm\".'**
  String get legendAcceptingBody;

  /// No description provided for @legendCallBody.
  ///
  /// In en, this message translates to:
  /// **'Calling does not mark anything as confirmed. Only the facility can tell you whether it can take your pet now.'**
  String get legendCallBody;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Directory review'**
  String get adminTitle;

  /// No description provided for @adminMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approve, correct or withdraw facilities'**
  String get adminMenuSubtitle;

  /// No description provided for @adminNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get adminNeedsAttention;

  /// No description provided for @adminNoItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review.'**
  String get adminNoItems;

  /// No description provided for @adminFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get adminFacilities;

  /// No description provided for @adminResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminResolve;

  /// No description provided for @adminDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get adminDismiss;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminMarkReview.
  ///
  /// In en, this message translates to:
  /// **'Mark for review'**
  String get adminMarkReview;

  /// No description provided for @adminWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get adminWithdraw;

  /// No description provided for @adminWithdrawEmergency.
  ///
  /// In en, this message translates to:
  /// **'Withdraw emergency'**
  String get adminWithdrawEmergency;

  /// No description provided for @adminCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct a fact'**
  String get adminCorrect;

  /// No description provided for @adminNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note: what you checked'**
  String get adminNoteHint;

  /// No description provided for @adminFact.
  ///
  /// In en, this message translates to:
  /// **'Fact'**
  String get adminFact;

  /// No description provided for @adminValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get adminValue;

  /// No description provided for @adminValueHint.
  ///
  /// In en, this message translates to:
  /// **'For lists, separate with commas'**
  String get adminValueHint;

  /// No description provided for @adminSourceUrl.
  ///
  /// In en, this message translates to:
  /// **'Source link (https://…)'**
  String get adminSourceUrl;

  /// No description provided for @adminSourceRequired.
  ///
  /// In en, this message translates to:
  /// **'A source link starting with https:// is needed.'**
  String get adminSourceRequired;

  /// No description provided for @adminValueRequired.
  ///
  /// In en, this message translates to:
  /// **'A value is needed.'**
  String get adminValueRequired;

  /// No description provided for @adminStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get adminStatusPending;

  /// No description provided for @adminStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminStatusApproved;

  /// No description provided for @adminStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get adminStatusNeedsReview;

  /// No description provided for @adminStatusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get adminStatusWithdrawn;

  /// No description provided for @adminClaimStatusCurrent.
  ///
  /// In en, this message translates to:
  /// **'current'**
  String get adminClaimStatusCurrent;

  /// No description provided for @adminClaimStatusUnverified.
  ///
  /// In en, this message translates to:
  /// **'not re-confirmed'**
  String get adminClaimStatusUnverified;

  /// No description provided for @adminClaimStatusConflict.
  ///
  /// In en, this message translates to:
  /// **'conflict'**
  String get adminClaimStatusConflict;

  /// No description provided for @adminClaimStatusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'withdrawn'**
  String get adminClaimStatusWithdrawn;

  /// No description provided for @adminFactKeyEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency service'**
  String get adminFactKeyEmergency;

  /// No description provided for @adminFactKeySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get adminFactKeySchedule;

  /// No description provided for @adminFactKeyPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get adminFactKeyPhone;

  /// No description provided for @adminFactKeyAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get adminFactKeyAddress;

  /// No description provided for @adminFactKeyWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get adminFactKeyWebsite;

  /// No description provided for @adminFactKeySpecies.
  ///
  /// In en, this message translates to:
  /// **'Species'**
  String get adminFactKeySpecies;

  /// No description provided for @adminFactKeyServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get adminFactKeyServices;

  /// No description provided for @adminKindEmergencyEvidenceMissing.
  ///
  /// In en, this message translates to:
  /// **'Emergency evidence missing'**
  String get adminKindEmergencyEvidenceMissing;

  /// No description provided for @adminKindPhoneConflict.
  ///
  /// In en, this message translates to:
  /// **'Phone number differs'**
  String get adminKindPhoneConflict;

  /// No description provided for @adminKindAddressConflict.
  ///
  /// In en, this message translates to:
  /// **'Address differs'**
  String get adminKindAddressConflict;

  /// No description provided for @adminKindClosure.
  ///
  /// In en, this message translates to:
  /// **'May have closed'**
  String get adminKindClosure;

  /// No description provided for @adminKindSourceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Source page unreachable'**
  String get adminKindSourceUnreachable;

  /// No description provided for @adminKindNewEmergencyEvidence.
  ///
  /// In en, this message translates to:
  /// **'New emergency wording found'**
  String get adminKindNewEmergencyEvidence;

  /// No description provided for @adminKindVerifyCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Check the map position'**
  String get adminKindVerifyCoordinates;

  /// No description provided for @adminKindLinkCandidate.
  ///
  /// In en, this message translates to:
  /// **'Possible map listing match'**
  String get adminKindLinkCandidate;

  /// No description provided for @adminKindRobotsDisallowed.
  ///
  /// In en, this message translates to:
  /// **'Site does not allow checks'**
  String get adminKindRobotsDisallowed;

  /// No description provided for @adminSeverityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get adminSeverityHigh;

  /// No description provided for @adminSeverityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get adminSeverityMedium;

  /// No description provided for @adminSeverityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get adminSeverityLow;

  /// No description provided for @adminLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked {date}'**
  String adminLastChecked(String date);

  /// No description provided for @adminNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'Never checked'**
  String get adminNeverChecked;

  /// No description provided for @adminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the review queue.'**
  String get adminLoadFailed;

  /// No description provided for @adminSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get adminSaved;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save. Please try again.'**
  String get adminActionFailed;

  /// No description provided for @adminNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This page is for directory reviewers.'**
  String get adminNotAllowed;

  /// No description provided for @adminLinkAction.
  ///
  /// In en, this message translates to:
  /// **'Link to a directory facility'**
  String get adminLinkAction;

  /// No description provided for @adminLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link this Google listing to…'**
  String get adminLinkTitle;

  /// No description provided for @adminLinkNote.
  ///
  /// In en, this message translates to:
  /// **'Pick the facility this listing belongs to. From then on they show as one place, with PetLoop\'s checked details.'**
  String get adminLinkNote;

  /// No description provided for @adminLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Link \"{listing}\" to {facility}?'**
  String adminLinkConfirm(String listing, String facility);

  /// No description provided for @adminLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked. The search now shows them as one place.'**
  String get adminLinked;

  /// No description provided for @adminLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not link. Please try again.'**
  String get adminLinkFailed;

  /// No description provided for @adminLinkNoFacilities.
  ///
  /// In en, this message translates to:
  /// **'There are no facilities in the directory yet.'**
  String get adminLinkNoFacilities;

  /// No description provided for @adminLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get adminLink;
}

class _FindVetL10nDelegate extends LocalizationsDelegate<FindVetL10n> {
  const _FindVetL10nDelegate();

  @override
  Future<FindVetL10n> load(Locale locale) {
    return SynchronousFuture<FindVetL10n>(lookupFindVetL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_FindVetL10nDelegate old) => false;
}

FindVetL10n lookupFindVetL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FindVetL10nEn();
    case 'he':
      return FindVetL10nHe();
  }

  throw FlutterError(
    'FindVetL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
