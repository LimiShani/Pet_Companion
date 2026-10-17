// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'safety_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SafetyL10nEn extends SafetyL10n {
  SafetyL10nEn([String locale = 'en']) : super(locale);

  @override
  String get emergencyLead => 'Call first. The rows below help you decide and prepare.';

  @override
  String get confirmOpen => 'Call to confirm they are open';

  @override
  String get urgentRow => 'Is it urgent?';

  @override
  String get urgentRowNote => 'Signs that mean going to the vet now';

  @override
  String foodRow(String name) {
    return 'Can $name eat this?';
  }

  @override
  String get foodRowNote => 'Foods and plants: safe, a little or dangerous';

  @override
  String get lostRow => 'Lost mode';

  @override
  String get lostRowNote => 'Tell people nearby and share a card';

  @override
  String get lostRowCardNote => 'Make a card to share';

  @override
  String lostRowActive(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sightings',
      one: '1 sighting',
      zero: 'no sightings yet',
    );
    return '$name is missing · $_temp0';
  }

  @override
  String lostRowActiveNote(String when) {
    return 'Last seen $when';
  }

  @override
  String get findClinicNote => 'Emergency clinics near you';

  @override
  String get urgentLead => 'Any of these means going to a vet now. Call on the way.';

  @override
  String get urgentSectionDog => 'Signs in dogs';

  @override
  String get urgentSectionCat => 'Signs in cats';

  @override
  String get urgentSectionAny => 'Signs in any animal';

  @override
  String get urgentOtherNote => 'Signs that are only about dogs or cats are left out.';

  @override
  String get noVetFindClinic => 'No vet saved? Find a clinic nearby';

  @override
  String get sourcesTitle => 'Where this comes from';

  @override
  String get foodSearchHint => 'Search a food or a plant';

  @override
  String get foodSearchClear => 'Clear the search';

  @override
  String get animalMenuTooltip => 'Which animal';

  @override
  String get animalDog => 'Dog';

  @override
  String get animalCat => 'Cat';

  @override
  String get animalBird => 'Bird';

  @override
  String get animalOther => 'Other animals';

  @override
  String get kindFoods => 'Foods';

  @override
  String get kindPlants => 'Plants';

  @override
  String get kindHousehold => 'Around the house';

  @override
  String get levelSafe => 'Safe';

  @override
  String get levelLittle => 'A little';

  @override
  String get levelDangerous => 'Dangerous';

  @override
  String get levelAsk => 'Ask your vet';

  @override
  String get levelNotListed => 'not on our list';

  @override
  String get forDogs => 'For dogs';

  @override
  String get forCats => 'For cats';

  @override
  String get forBirds => 'For birds';

  @override
  String forAnimal(String animal, String level) {
    return '$animal: $level';
  }

  @override
  String foodAlso(String names) {
    return 'Also: $names';
  }

  @override
  String get foodCallVet => 'Call the vet';

  @override
  String get foodNotSure => 'Not sure? Call the vet';

  @override
  String get foodEatenAlready => 'Eaten already? Call even if all seems fine.';

  @override
  String foodNothing(String text) {
    return 'Nothing found for “$text”.';
  }

  @override
  String lostStep(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get lostChangePet => 'Change';

  @override
  String get lostWhichPet => 'Who is missing?';

  @override
  String get lostLastSeen => 'Last seen';

  @override
  String get lostTown => 'Town';

  @override
  String get lostTownChoose => 'Choose the town';

  @override
  String get lostTownHint => 'Type a town';

  @override
  String get lostTownNeeded => 'Choose the town first';

  @override
  String get lostWhere => 'Where exactly?';

  @override
  String get lostWhereHint => 'A public place, not an address';

  @override
  String get lostNote => 'Anything people should know?';

  @override
  String get lostNoteHint => 'For example: please do not chase, call the name';

  @override
  String get lostNext => 'Next';

  @override
  String get lostPreviewTitle => 'What people will see';

  @override
  String get lostPostTag => 'Lost and found';

  @override
  String get lostNow => 'Now';

  @override
  String lostUsePhoto(String name) {
    return 'Use $name\'s photo';
  }

  @override
  String lostWhoHears(String town) {
    return 'People in $town who use PetLoop get one notification. Sightings come as comments.';
  }

  @override
  String get lostCardNext => 'The card to share';

  @override
  String get lostCardNextNote => 'Comes next, filled in';

  @override
  String get lostStart => 'Start lost mode';

  @override
  String get lostStarted => 'Lost mode is on. People nearby are being told.';

  @override
  String lostAlertTitle(String name) {
    return '$name is missing';
  }

  @override
  String lostSince(String when) {
    return 'Since $when';
  }

  @override
  String get lostSightings => 'Sightings';

  @override
  String get lostNoSightings => 'No sightings yet. Sharing the card reaches more people.';

  @override
  String get lostSightingsFailed => 'Could not load the comments';

  @override
  String get lostOpenPost => 'Open the post';

  @override
  String get lostShareCard => 'Share the card';

  @override
  String lostHome(String name) {
    return '$name is home';
  }

  @override
  String get lostClose => 'Close the alert';

  @override
  String get lostCloseQuestion => 'Close the alert without “found”?';

  @override
  String get lostCloseNote => 'If nobody answered yet, the post is removed too.';

  @override
  String get lostCloseConfirm => 'Close';

  @override
  String get lostKeepLooking => 'Keep looking';

  @override
  String get lostFoundDone => 'Good news. The alert is closed.';

  @override
  String get lostClosedDone => 'The alert is closed.';

  @override
  String lostErrActive(String name) {
    return 'There is already an open alert for $name.';
  }

  @override
  String get lostErrRate => 'Three alerts today already. Please try again tomorrow.';

  @override
  String get lostErrInvalid => 'Something here is not right. Please check the place and the time.';

  @override
  String get lostErrNotAllowed => 'Lost mode is not available for this account.';

  @override
  String get lostErrGeneric => 'Could not do that. Please try again.';
}
