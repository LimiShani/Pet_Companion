// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'pets_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class PetsL10nEn extends PetsL10n {
  PetsL10nEn([String locale = 'en']) : super(locale);

  @override
  String get myPetsTitle => 'My pets';

  @override
  String get speciesDog => 'Dog';

  @override
  String get speciesCat => 'Cat';

  @override
  String get speciesBird => 'Bird';

  @override
  String get speciesRabbit => 'Rabbit';

  @override
  String get speciesReptile => 'Reptile';

  @override
  String get speciesOther => 'Other';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get notSure => 'Not sure';

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String ageYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return '$_temp0';
  }

  @override
  String ageYearsExact(String years) {
    return '$years years';
  }

  @override
  String ageMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String ageWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get ageUnderAWeek => 'Under a week';

  @override
  String ageAbout(String age) {
    return 'About $age';
  }

  @override
  String weightKg(String value) {
    return '$value kg';
  }

  @override
  String weightG(String value) {
    return '$value g';
  }

  @override
  String get unitKg => 'kg';

  @override
  String get unitG => 'g';

  @override
  String get breedMixed => 'Mixed';

  @override
  String get welcomeTitle => 'Welcome';

  @override
  String welcomeTitleNamed(String name) {
    return 'Welcome, $name';
  }

  @override
  String get welcomeIntro => 'Let\'s meet your first pet. A name and a kind are enough to start; the rest takes about a minute.';

  @override
  String get welcomeWhyPhoto => 'A photo, or a friendly icon';

  @override
  String get welcomeWhyVet => 'The vet\'s number, ready for an emergency';

  @override
  String get welcomeWhyHealth => 'Allergies and conditions: what a vet asks first';

  @override
  String get welcomeAddFirst => 'Add my first pet';

  @override
  String get welcomeArchivedPets => 'Archived pets';

  @override
  String get welcomeLoadFailed => 'Could not load your pets';

  @override
  String get restore => 'Restore';

  @override
  String get addPetTitle => 'Add a pet';

  @override
  String aboutPetTitle(String name) {
    return 'About $name';
  }

  @override
  String petVetTitle(String name) {
    return '$name\'s vet';
  }

  @override
  String get healthBasics => 'Health basics';

  @override
  String get finishLater => 'Finish later';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get whoIsJoining => 'Who is joining the family?';

  @override
  String get whoIsJoiningNote => 'A name and a kind are enough to start. Everything else can wait.';

  @override
  String get addPhotoOrIcon => 'Add a photo or pick an icon';

  @override
  String get fieldName => 'Name';

  @override
  String get nameMissingNew => 'What is your pet called?';

  @override
  String get nameMissing => 'A pet needs a name.';

  @override
  String nameTooLong(int count) {
    return 'Keep the name under $count characters.';
  }

  @override
  String get kindOfAnimal => 'Kind of animal';

  @override
  String savedOnContinue(String name) {
    return '$name is saved when you continue. You can change anything later.';
  }

  @override
  String get savedOnContinueNoName => 'Your pet is saved when you continue. You can change anything later.';

  @override
  String pictureNotSaved(String name) {
    return 'The picture could not be saved. You can add it later from $name\'s profile.';
  }

  @override
  String petIsSaved(String name) {
    return '$name is saved';
  }

  @override
  String get aboutNote => 'Add what you know; skip what you don\'t.';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String whoLooksAfter(String name) {
    return 'Who looks after $name?';
  }

  @override
  String get vetStepNote => 'With the vet\'s phone saved, a call or a message is two taps away in an emergency.';

  @override
  String get regularVet => 'Regular vet';

  @override
  String get emergencyVet => 'Emergency vet (24 h)';

  @override
  String get noVetYet => 'I don\'t have a vet yet';

  @override
  String noVetYetNote(String name) {
    return 'No vet yet? Carry on: $name\'s dashboard will keep a small reminder.';
  }

  @override
  String get whatAVetAsksFirst => 'What a vet asks first';

  @override
  String get healthStepNote => 'If there is nothing to list, tick \"None known\". That is a real answer.';

  @override
  String get finish => 'Finish';

  @override
  String get tagEssential => 'Essential';

  @override
  String get tagOptional => 'Optional';

  @override
  String get allSetChecking => 'Checking the essentials…';

  @override
  String allSetAllFilled(int total) {
    return 'All $total essentials filled';
  }

  @override
  String allSetSomeFilled(int answered, int total) {
    return '$answered of $total essentials filled';
  }

  @override
  String allSetNoteUnknown(String name) {
    return '$name\'s dashboard shows a small reminder while an essential is missing.';
  }

  @override
  String allSetNoteComplete(String name) {
    return '$name\'s essentials are complete. You can change anything from the profile.';
  }

  @override
  String allSetNoteVet(String name) {
    return 'We\'ll keep a small reminder on $name\'s dashboard until the vet\'s phone is added.';
  }

  @override
  String allSetNoteRest(String name) {
    return 'We\'ll keep a small reminder on $name\'s dashboard until the rest is added.';
  }

  @override
  String petIsReady(String name) {
    return '$name is ready';
  }

  @override
  String get addNow => 'Add now';

  @override
  String goToDashboard(String name) {
    return 'Go to $name\'s dashboard';
  }

  @override
  String get addAnotherPet => 'Add another pet';

  @override
  String checklistTitle(String name) {
    return '$name\'s essentials';
  }

  @override
  String get checklistChecking => 'Checking what is answered…';

  @override
  String checklistAllAnswered(int total) {
    return 'All $total answered. Thank you!';
  }

  @override
  String checklistSomeAnswered(int answered, int total) {
    return '$answered of $total answered. \"None known\" counts.';
  }

  @override
  String get goodToHave => 'Good to have';

  @override
  String get remindInAWeek => 'Remind me in a week';

  @override
  String reminderHiddenUntil(String date, String name) {
    return 'The reminder is hidden until $date. The dot on $name\'s name stays.';
  }

  @override
  String chipAnswered(String item) {
    return '$item: answered';
  }

  @override
  String chipNotAdded(String item) {
    return '$item: not added yet';
  }

  @override
  String get checking => 'Checking…';

  @override
  String get couldNotCheck => 'Could not check this right now';

  @override
  String get itemVetPhone => 'A vet\'s phone number';

  @override
  String get itemAllergies => 'Allergies';

  @override
  String get itemConditions => 'Medical conditions';

  @override
  String get itemAge => 'Age';

  @override
  String get itemWeight => 'Weight';

  @override
  String get itemPhoto => 'A real photo';

  @override
  String get itemBreed => 'Breed';

  @override
  String get itemSexAndNeutering => 'Sex and neutering';

  @override
  String get itemMicrochip => 'Microchip';

  @override
  String get hintVetPhone => 'So Emergency can call';

  @override
  String get hintListOrNone => 'A list, or \"None known\"';

  @override
  String get hintAge => 'A birthday, or \"about 3 years\"';

  @override
  String get hintWeight => 'A rough number is fine';

  @override
  String get hintPhoto => 'Helps most if your pet is lost';

  @override
  String get hintBreed => '\"Mixed or not sure\" is an answer';

  @override
  String get hintSexAndNeutering => 'Asked on vet forms';

  @override
  String get hintMicrochip => 'Finds a lost pet';

  @override
  String get hintEmergencyVet => 'A night-time fallback';

  @override
  String get actionVetPhone => 'Add the vet\'s phone';

  @override
  String get actionAllergies => 'Answer about allergies';

  @override
  String get actionConditions => 'Answer about conditions';

  @override
  String actionAge(String name) {
    return 'Add $name\'s age';
  }

  @override
  String actionWeight(String name) {
    return 'Add $name\'s weight';
  }

  @override
  String actionPhoto(String name) {
    return 'Add a photo of $name';
  }

  @override
  String actionBreed(String name) {
    return 'Add $name\'s breed';
  }

  @override
  String get actionSexAndNeutering => 'Add sex and neutering';

  @override
  String get actionMicrochip => 'Add the microchip number';

  @override
  String get actionEmergencyVet => 'Add an emergency vet';

  @override
  String petAgeTitle(String name) {
    return '$name\'s age';
  }

  @override
  String get petAgeNote => 'A birthday, or a guess: both count.';

  @override
  String petWeightTitle(String name) {
    return '$name\'s weight';
  }

  @override
  String get petWeightNote => 'Every dose starts with the weight.';

  @override
  String petBreedTitle(String name) {
    return '$name\'s breed';
  }

  @override
  String get sexAndNeuteringNote => '\"Not sure\" is an answer too.';

  @override
  String essentialsStillToAdd(int missing, int total) {
    return '$missing of $total essentials still to add';
  }

  @override
  String reminderSemantics(String name, int missing, int total) {
    return '$name\'s profile: $missing of $total essentials still to add';
  }

  @override
  String finishProfile(String name) {
    return 'Finish $name\'s profile';
  }

  @override
  String get notNow => 'Not now';

  @override
  String get remindAgainInAWeek => 'We\'ll remind you again in a week';

  @override
  String essentialsComplete(String name) {
    return '$name\'s essentials are complete';
  }

  @override
  String get essentialsMissing => 'Essentials missing';

  @override
  String essentialsToAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count essentials to add',
      one: '1 essential to add',
    );
    return '$_temp0';
  }

  @override
  String get complete => 'Complete';

  @override
  String get birthdayOrAge => 'Birthday or age';

  @override
  String get iKnowTheDate => 'I know the date';

  @override
  String get aboutEllipsis => 'About…';

  @override
  String get aboutField => 'About';

  @override
  String get unitYears => 'years';

  @override
  String get unitMonths => 'months';

  @override
  String get ageGuessNote => 'A guess is fine. Shown as \"About 3 years\", and it keeps counting.';

  @override
  String get birthday => 'Birthday';

  @override
  String get chooseTheDate => 'Choose the date';

  @override
  String get sex => 'Sex';

  @override
  String get neuteredOrSpayed => 'Neutered or spayed';

  @override
  String get breedOptional => 'Breed (optional)';

  @override
  String get breedExample => 'e.g. Labrador';

  @override
  String get mixedOrNotSure => 'Mixed or not sure';

  @override
  String breedTooLong(int count) {
    return 'Keep the breed under $count characters.';
  }

  @override
  String enterANumberLike(int example) {
    return 'Enter a number, for example $example.';
  }

  @override
  String get tooHeavy => 'That looks too heavy. Please check the number.';

  @override
  String get enterANumber => 'Enter a number.';

  @override
  String get checkTheNumber => 'Please check the number.';

  @override
  String petPictureTitle(String name) {
    return '$name\'s picture';
  }

  @override
  String get yourPetsPicture => 'Your pet\'s picture';

  @override
  String get petPicture => 'Pet picture';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get takeAPhotoNote => 'Opens the camera';

  @override
  String get chooseFromPhotos => 'Choose from your photos';

  @override
  String get chooseFromPhotosNote => 'Then fit it into the circle';

  @override
  String get pickAnIcon => 'Pick an icon';

  @override
  String pickAnIconNote(int count) {
    return '$count animals in the app\'s colours';
  }

  @override
  String get removePicture => 'Remove picture';

  @override
  String get removePictureNoteDog => 'Back to the default dog icon';

  @override
  String get removePictureNoteCat => 'Back to the default cat icon';

  @override
  String get removePictureNoteBird => 'Back to the default bird icon';

  @override
  String get removePictureNoteRabbit => 'Back to the default rabbit icon';

  @override
  String get removePictureNoteReptile => 'Back to the default reptile icon';

  @override
  String get removePictureNoteOther => 'Back to the default icon';

  @override
  String get cropTitle => 'Move and zoom';

  @override
  String get cropHint => 'Drag to move · pinch to zoom';

  @override
  String get cropPreview => 'Preview';

  @override
  String get cropChooseAnother => 'Choose another';

  @override
  String get cropUsePhoto => 'Use photo';

  @override
  String get cropFailed => 'Could not crop that photo. Please try another one.';

  @override
  String get iconsForDog => 'For a dog';

  @override
  String get iconsForCat => 'For a cat';

  @override
  String get iconsForBird => 'For a bird';

  @override
  String get iconsForRabbit => 'For a rabbit';

  @override
  String get iconsForReptile => 'For a reptile';

  @override
  String get iconsSuggested => 'Suggested';

  @override
  String get iconsAll => 'All animals';

  @override
  String get iconsBackground => 'Background';

  @override
  String get iconsBackgroundYellow => 'Yellow background';

  @override
  String get iconsBackgroundGreen => 'Green background';

  @override
  String get iconsBackgroundPeach => 'Peach background';

  @override
  String get iconsBackgroundWhite => 'White background';

  @override
  String get iconsUse => 'Use this icon';

  @override
  String get changesSaved => 'Changes saved';

  @override
  String petArchived(String name) {
    return '$name is archived. You can bring $name back from My pets.';
  }

  @override
  String petDeleted(String name) {
    return '$name was deleted';
  }

  @override
  String get petProfile => 'Pet profile';

  @override
  String get petNoLongerHere => 'This pet is no longer here.';

  @override
  String get changePicture => 'Change picture';

  @override
  String get basics => 'Basics';

  @override
  String get kind => 'Kind';

  @override
  String get vet => 'Vet';

  @override
  String get saveChanges => 'Save changes';

  @override
  String archivePet(String name) {
    return 'Archive $name';
  }

  @override
  String deletePet(String name) {
    return 'Delete $name';
  }

  @override
  String get noneKnown => 'None known';

  @override
  String get notAnsweredYet => 'Not answered yet';

  @override
  String get notAdded => 'Not added';

  @override
  String get answer => 'Answer';

  @override
  String removePetTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get archive => 'Archive';

  @override
  String archiveNote(String name) {
    return '$name is hidden from the app. Everything is kept, and you can bring $name back from My pets.';
  }

  @override
  String archiveOnlyPetNote(String name) {
    return '$name is your only pet, so there is nothing to show in its place. Add another pet first, or delete $name.';
  }

  @override
  String get deleteForGood => 'Delete for good';

  @override
  String deleteNote(String name) {
    return 'Erases $name\'s profile, picture, health records, reminders and documents. This cannot be undone.';
  }

  @override
  String get suggested => 'Suggested';

  @override
  String get archived => 'Archived';

  @override
  String get archivedNote => 'Archived pets keep all their records and are hidden from the rest of the app.';

  @override
  String archivedRow(String kind, String date) {
    return '$kind · archived $date';
  }

  @override
  String petIsBack(String name) {
    return '$name is back';
  }

  @override
  String get errNotYours => 'You can only change your own pets. Please sign in again.';

  @override
  String get errInvalid => 'Some of that information is not valid. Please check it and try again.';

  @override
  String get errDatabaseOutdated => 'The database is not up to date for pets yet (migration 0005 has not been run).';

  @override
  String get errSignInAgain => 'Please sign in again.';

  @override
  String get errSave => 'Could not save your pet. Please try again.';

  @override
  String get errLoad => 'Could not load your pets. Please try again.';

  @override
  String get errDelete => 'Could not delete your pet. Please try again.';

  @override
  String get errPhotoSave => 'Could not save the photo. Please try again.';

  @override
  String get errPhotoRemove => 'Could not remove the photo. Please try again.';

  @override
  String get errPhotoLoad => 'Could not load the photo. Please try again.';

  @override
  String get errPhotoTooLarge => 'That photo is too large.';

  @override
  String get errPhotoUnsupported => 'That kind of picture is not supported.';

  @override
  String get errPhotoUnsupportedChooseAnother => 'That kind of picture is not supported. Please choose another one.';

  @override
  String get errPhotoGone => 'That photo is no longer available.';

  @override
  String get errOffline => 'Cannot reach the server. Check your connection and try again.';

  @override
  String get errCameraNotAllowed => 'Cannot open the camera. Check that PetLoop is allowed to use it.';

  @override
  String get errPhotosNotAllowed => 'Cannot open your photos. Check that PetLoop is allowed to see them.';

  @override
  String get errCamera => 'Could not open the camera.';

  @override
  String get errPhotos => 'Could not open your photos.';
}
