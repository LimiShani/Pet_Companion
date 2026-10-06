// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'findvet_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FindVetL10nEn extends FindVetL10n {
  FindVetL10nEn([String locale = 'en']) : super(locale);

  @override
  String get findVetTitle => 'Find a vet';

  @override
  String get findVetMenuSubtitle => 'Emergency or regular care nearby';

  @override
  String get loginEmergencyLink => 'Pet emergency? Find a vet';

  @override
  String get emergencySheetFindVet => 'Find an emergency vet nearby';

  @override
  String get choiceQuestion => 'What do you need?';

  @override
  String get emergencyChoiceTitle => 'Emergency care';

  @override
  String get emergencyChoiceBody =>
      'The nearest places that advertise emergency care, with Call and Directions.';

  @override
  String get longTermChoiceTitle => 'Long term care';

  @override
  String get longTermChoiceBody =>
      'Nearby practices with their details, and a regular vet to save.';

  @override
  String get modeEmergency => 'Emergency';

  @override
  String get modeLongTerm => 'Long term';

  @override
  String get areaQuestion => 'Where should we look?';

  @override
  String get locationWhy =>
      'To find vets near you, PetLoop asks the phone for your location once. It is used for this search only and is not saved.';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get locating => 'Finding your location…';

  @override
  String get orTypePlace => 'Or type a city, address or postcode';

  @override
  String get placeSearchHint => 'City, address or postcode';

  @override
  String get placeSearchButton => 'Search';

  @override
  String get placeNoMatch =>
      'We could not find that place. Try the name of a city.';

  @override
  String get placeLookupFailed =>
      'Could not look that up right now. Try the name of a city.';

  @override
  String get problemDenied =>
      'Location access was not allowed. You can type a place instead.';

  @override
  String get problemDeniedForever =>
      'Location access is off for PetLoop. It can be turned on in the phone\'s settings, or you can type a place.';

  @override
  String get problemServiceOff =>
      'Location is switched off on this phone. Turn it on, or type a place.';

  @override
  String get problemUnavailable =>
      'We could not get your location. Type a place instead.';

  @override
  String get problemOutsideRegion =>
      'Find a vet works in Israel for now. Type a place in Israel.';

  @override
  String get openSettings => 'Open settings';

  @override
  String searchingNear(String place) {
    return 'Searching near $place';
  }

  @override
  String get yourLocation => 'your location';

  @override
  String approximateLocation(int km) {
    return 'Your location is approximate (within about $km km). Change the area if it looks wrong.';
  }

  @override
  String get changeArea => 'Change';

  @override
  String get changeAreaLabel => 'Change the area';

  @override
  String withinKm(int km) {
    return 'Within $km km';
  }

  @override
  String get searching => 'Looking for vets…';

  @override
  String get callFirstTitle => 'Call before you go';

  @override
  String get callFirstBody =>
      'Opening hours and \"24/7\" do not tell us whether they can take your pet right now.';

  @override
  String get callToConfirm => 'Call to confirm they can receive your pet';

  @override
  String get evidenceListed => 'Listed nearby';

  @override
  String get evidenceListedNote =>
      'Found in a map listing. Emergency care is not confirmed by PetLoop.';

  @override
  String get evidenceAdvertised => 'Emergency service advertised';

  @override
  String evidenceAdvertisedSchedule(String schedule) {
    return 'Emergency service advertised · $schedule';
  }

  @override
  String evidenceSourceChecked(String date) {
    return 'On their own website, last checked $date';
  }

  @override
  String get evidenceSourceNotChecked =>
      'On their own website, not checked again yet';

  @override
  String get evidenceUnverified => 'Emergency service not re-confirmed';

  @override
  String evidenceUnverifiedNote(String date) {
    return 'Their website did not show it when we last looked ($date). Ask when you call.';
  }

  @override
  String get evidenceUnverifiedNoDate =>
      'We could not confirm it on their website lately. Ask when you call.';

  @override
  String get evidenceOpenNow => 'Published hours: open now';

  @override
  String get evidenceClosedNow => 'Published hours: closed now';

  @override
  String get evidenceHoursUnknown => 'Opening hours not published';

  @override
  String get evidenceAccepting => 'Accepting patients now';

  @override
  String get evidenceLimited => 'Accepting patients, with limits';

  @override
  String get evidenceDiverting => 'Sending patients elsewhere right now';

  @override
  String evidenceReported(String time, String until) {
    return 'Reported by the facility at $time, valid until $until';
  }

  @override
  String staleNote(String date) {
    return 'PetLoop last checked these details on $date.';
  }

  @override
  String get staleNever => 'PetLoop has not checked these details yet.';

  @override
  String get closedTemporarily => 'Listed as temporarily closed';

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String get call => 'Call';

  @override
  String callName(String name) {
    return 'Call $name';
  }

  @override
  String get noPhone => 'No phone number listed';

  @override
  String get directions => 'Directions';

  @override
  String directionsName(String name) {
    return 'Directions to $name';
  }

  @override
  String get website => 'Website';

  @override
  String get viewOnMaps => 'View on Google Maps';

  @override
  String get save => 'Save';

  @override
  String saveName(String name) {
    return 'Save $name as a regular vet';
  }

  @override
  String get saveChoosePet => 'Save as the regular vet of…';

  @override
  String saveForPet(String pet) {
    return 'Save for $pet';
  }

  @override
  String get saveNeedsPet => 'Add a pet first to save a regular vet.';

  @override
  String get savedVet => 'Saved as a regular vet.';

  @override
  String get details => 'Details';

  @override
  String get fewerDetails => 'Fewer details';

  @override
  String get hoursTitle => 'Published hours';

  @override
  String speciesLine(String list) {
    return 'Treats: $list';
  }

  @override
  String servicesLine(String list) {
    return 'Services: $list';
  }

  @override
  String factSource(String date) {
    return 'From their website, checked $date';
  }

  @override
  String get factSourceNoDate => 'From their website';

  @override
  String get speciesDog => 'dogs';

  @override
  String get speciesCat => 'cats';

  @override
  String get speciesRabbit => 'rabbits';

  @override
  String get speciesBird => 'birds';

  @override
  String get speciesReptile => 'reptiles';

  @override
  String get speciesRodent => 'small rodents';

  @override
  String get speciesExotic => 'exotic animals';

  @override
  String get speciesHorse => 'horses';

  @override
  String get speciesFarm => 'farm animals';

  @override
  String get sectionAdvertised => 'Advertising emergency service';

  @override
  String get sectionOther => 'Other vets nearby';

  @override
  String get sectionOtherNote =>
      'Not confirmed as emergency services. Call to ask.';

  @override
  String get sectionUnverified => 'Emergency service not re-confirmed';

  @override
  String get firstOption => 'Nearest option';

  @override
  String get secondOption => 'Second option';

  @override
  String onlyOneAdvertised(int km) {
    return 'Only one place advertising emergency care was found within $km km.';
  }

  @override
  String noticeExpanded(int km) {
    return 'Nothing close enough, so we searched up to $km km.';
  }

  @override
  String get noticeProviderDown =>
      'Live search is not working right now. These are emergency facilities from PetLoop\'s own directory, each with the date we last checked it.';

  @override
  String get noticeProviderDownLongTerm =>
      'Live search is not working right now. These practices come from PetLoop\'s own directory.';

  @override
  String noticeDirectoryCopy(String date) {
    return 'No connection. This is the copy of PetLoop\'s directory saved on this phone on $date.';
  }

  @override
  String get noResultsTitle => 'No vets found nearby';

  @override
  String noResultsBody(int km) {
    return 'Nothing within $km km.';
  }

  @override
  String noEmergencyResultsBody(int km) {
    return 'No place advertising emergency care within $km km.';
  }

  @override
  String searchWider(int km) {
    return 'Search up to $km km';
  }

  @override
  String get tryAnotherArea => 'Try another area';

  @override
  String get errorTitle => 'Could not search';

  @override
  String get errorOffline =>
      'No connection, and no saved copy of the directory yet. Check the connection and try again.';

  @override
  String get errorRateLimited =>
      'Too many searches in a short time. Please try again in a few minutes.';

  @override
  String get errorUnavailable =>
      'Search is not available right now. Please try again.';

  @override
  String get errorInvalid => 'That place cannot be searched. Try another one.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get demoBanner =>
      'Sample data: these places are made up. The real search works once the app is connected to its server.';

  @override
  String get listingsFrom => 'Map listings:';

  @override
  String get legendLink => 'What the labels mean';

  @override
  String get legendListedBody =>
      'Found in a map listing near the area. That alone says nothing about emergency care, whatever the name says.';

  @override
  String get legendAdvertisedBody =>
      'The facility\'s own website (or the facility itself) says it offers emergency care. PetLoop checks this every week and shows the date of the last check.';

  @override
  String get legendOpenBody =>
      'Its published hours say it is open now. That does not mean a vet is free to see your pet.';

  @override
  String get legendAcceptingBody =>
      'Shown only when the facility itself has reported that it is taking patients, and only until that report expires. Otherwise you will see \"Call to confirm\".';

  @override
  String get legendCallBody =>
      'Calling does not mark anything as confirmed. Only the facility can tell you whether it can take your pet now.';

  @override
  String get adminTitle => 'Directory review';

  @override
  String get adminMenuSubtitle => 'Approve, correct or withdraw facilities';

  @override
  String get adminNeedsAttention => 'Needs attention';

  @override
  String get adminNoItems => 'Nothing to review.';

  @override
  String get adminFacilities => 'Facilities';

  @override
  String get adminResolve => 'Resolved';

  @override
  String get adminDismiss => 'Dismiss';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminMarkReview => 'Mark for review';

  @override
  String get adminWithdraw => 'Withdraw';

  @override
  String get adminWithdrawEmergency => 'Withdraw emergency';

  @override
  String get adminCorrect => 'Correct a fact';

  @override
  String get adminNoteHint => 'Note: what you checked';

  @override
  String get adminFact => 'Fact';

  @override
  String get adminValue => 'Value';

  @override
  String get adminValueHint => 'For lists, separate with commas';

  @override
  String get adminSourceUrl => 'Source link (https://…)';

  @override
  String get adminSourceRequired =>
      'A source link starting with https:// is needed.';

  @override
  String get adminValueRequired => 'A value is needed.';

  @override
  String get adminStatusPending => 'Pending approval';

  @override
  String get adminStatusApproved => 'Approved';

  @override
  String get adminStatusNeedsReview => 'Needs review';

  @override
  String get adminStatusWithdrawn => 'Withdrawn';

  @override
  String get adminClaimStatusCurrent => 'current';

  @override
  String get adminClaimStatusUnverified => 'not re-confirmed';

  @override
  String get adminClaimStatusConflict => 'conflict';

  @override
  String get adminClaimStatusWithdrawn => 'withdrawn';

  @override
  String get adminFactKeyEmergency => 'Emergency service';

  @override
  String get adminFactKeySchedule => 'Schedule';

  @override
  String get adminFactKeyPhone => 'Phone';

  @override
  String get adminFactKeyAddress => 'Address';

  @override
  String get adminFactKeyWebsite => 'Website';

  @override
  String get adminFactKeySpecies => 'Species';

  @override
  String get adminFactKeyServices => 'Services';

  @override
  String get adminKindEmergencyEvidenceMissing => 'Emergency evidence missing';

  @override
  String get adminKindPhoneConflict => 'Phone number differs';

  @override
  String get adminKindAddressConflict => 'Address differs';

  @override
  String get adminKindClosure => 'May have closed';

  @override
  String get adminKindSourceUnreachable => 'Source page unreachable';

  @override
  String get adminKindNewEmergencyEvidence => 'New emergency wording found';

  @override
  String get adminKindVerifyCoordinates => 'Check the map position';

  @override
  String get adminKindLinkCandidate => 'Possible map listing match';

  @override
  String get adminKindRobotsDisallowed => 'Site does not allow checks';

  @override
  String get adminSeverityHigh => 'High';

  @override
  String get adminSeverityMedium => 'Medium';

  @override
  String get adminSeverityLow => 'Low';

  @override
  String adminLastChecked(String date) {
    return 'Last checked $date';
  }

  @override
  String get adminNeverChecked => 'Never checked';

  @override
  String get adminLoadFailed => 'Could not load the review queue.';

  @override
  String get adminSaved => 'Saved.';

  @override
  String get adminActionFailed => 'Could not save. Please try again.';

  @override
  String get adminNotAllowed => 'This page is for directory reviewers.';

  @override
  String get adminLinkAction => 'Link to a directory facility';

  @override
  String get adminLinkTitle => 'Link this Google listing to…';

  @override
  String get adminLinkNote =>
      'Pick the facility this listing belongs to. From then on they show as one place, with PetLoop\'s checked details.';

  @override
  String adminLinkConfirm(String listing, String facility) {
    return 'Link \"$listing\" to $facility?';
  }

  @override
  String get adminLinked => 'Linked. The search now shows them as one place.';

  @override
  String get adminLinkFailed => 'Could not link. Please try again.';

  @override
  String get adminLinkNoFacilities =>
      'There are no facilities in the directory yet.';

  @override
  String get adminLink => 'Link';
}
