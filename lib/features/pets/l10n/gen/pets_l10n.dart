import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'pets_l10n_en.dart';
import 'pets_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of PetsL10n
/// returned by `PetsL10n.of(context)`.
///
/// Applications need to include `PetsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/pets_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: PetsL10n.localizationsDelegates,
///   supportedLocales: PetsL10n.supportedLocales,
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
/// be consistent with the languages listed in the PetsL10n.supportedLocales
/// property.
abstract class PetsL10n {
  PetsL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static PetsL10n of(BuildContext context) {
    return Localizations.of<PetsL10n>(context, PetsL10n)!;
  }

  static const LocalizationsDelegate<PetsL10n> delegate = _PetsL10nDelegate();

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

  /// Title of the page that lists the owner's pets.
  ///
  /// In en, this message translates to:
  /// **'My pets'**
  String get myPetsTitle;

  /// No description provided for @speciesDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get speciesDog;

  /// No description provided for @speciesCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get speciesCat;

  /// No description provided for @speciesBird.
  ///
  /// In en, this message translates to:
  /// **'Bird'**
  String get speciesBird;

  /// No description provided for @speciesRabbit.
  ///
  /// In en, this message translates to:
  /// **'Rabbit'**
  String get speciesRabbit;

  /// No description provided for @speciesReptile.
  ///
  /// In en, this message translates to:
  /// **'Reptile'**
  String get speciesReptile;

  /// A kind of animal that is none of the listed ones.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get speciesOther;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// An honest answer to the questions about sex and neutering.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

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

  /// A pet's age in whole years.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 year} other{{count} years}}'**
  String ageYears(int count);

  /// An age with a fraction, such as 13.6 years.
  ///
  /// In en, this message translates to:
  /// **'{years} years'**
  String ageYearsExact(String years);

  /// No description provided for @ageMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String ageMonths(int count);

  /// No description provided for @ageWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String ageWeeks(int count);

  /// No description provided for @ageUnderAWeek.
  ///
  /// In en, this message translates to:
  /// **'Under a week'**
  String get ageUnderAWeek;

  /// An approximate age; {age} is one of the age phrases, e.g. 3 years.
  ///
  /// In en, this message translates to:
  /// **'About {age}'**
  String ageAbout(String age);

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String weightKg(String value);

  /// No description provided for @weightG.
  ///
  /// In en, this message translates to:
  /// **'{value} g'**
  String weightG(String value);

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// Shown as the breed when the owner chose "Mixed or not sure".
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get breedMixed;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcomeTitle;

  /// Greets a new account by the owner's name.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeTitleNamed(String name);

  /// No description provided for @welcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'Let\'s meet your first pet. A name and a kind are enough to start; the rest takes about a minute.'**
  String get welcomeIntro;

  /// No description provided for @welcomeWhyPhoto.
  ///
  /// In en, this message translates to:
  /// **'A photo, or a friendly icon'**
  String get welcomeWhyPhoto;

  /// No description provided for @welcomeWhyVet.
  ///
  /// In en, this message translates to:
  /// **'The vet\'s number, ready for an emergency'**
  String get welcomeWhyVet;

  /// No description provided for @welcomeWhyHealth.
  ///
  /// In en, this message translates to:
  /// **'Allergies and conditions: what a vet asks first'**
  String get welcomeWhyHealth;

  /// No description provided for @welcomeAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add my first pet'**
  String get welcomeAddFirst;

  /// No description provided for @welcomeArchivedPets.
  ///
  /// In en, this message translates to:
  /// **'Archived pets'**
  String get welcomeArchivedPets;

  /// No description provided for @welcomeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your pets'**
  String get welcomeLoadFailed;

  /// Button: brings an archived pet back.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @addPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a pet'**
  String get addPetTitle;

  /// Title of step 2; {name} is the pet.
  ///
  /// In en, this message translates to:
  /// **'About {name}'**
  String aboutPetTitle(String name);

  /// No description provided for @petVetTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s vet'**
  String petVetTitle(String name);

  /// No description provided for @healthBasics.
  ///
  /// In en, this message translates to:
  /// **'Health basics'**
  String get healthBasics;

  /// No description provided for @finishLater.
  ///
  /// In en, this message translates to:
  /// **'Finish later'**
  String get finishLater;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @whoIsJoining.
  ///
  /// In en, this message translates to:
  /// **'Who is joining the family?'**
  String get whoIsJoining;

  /// No description provided for @whoIsJoiningNote.
  ///
  /// In en, this message translates to:
  /// **'A name and a kind are enough to start. Everything else can wait.'**
  String get whoIsJoiningNote;

  /// No description provided for @addPhotoOrIcon.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or pick an icon'**
  String get addPhotoOrIcon;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @nameMissingNew.
  ///
  /// In en, this message translates to:
  /// **'What is your pet called?'**
  String get nameMissingNew;

  /// No description provided for @nameMissing.
  ///
  /// In en, this message translates to:
  /// **'A pet needs a name.'**
  String get nameMissing;

  /// No description provided for @nameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the name under {count} characters.'**
  String nameTooLong(int count);

  /// No description provided for @kindOfAnimal.
  ///
  /// In en, this message translates to:
  /// **'Kind of animal'**
  String get kindOfAnimal;

  /// No description provided for @savedOnContinue.
  ///
  /// In en, this message translates to:
  /// **'{name} is saved when you continue. You can change anything later.'**
  String savedOnContinue(String name);

  /// No description provided for @savedOnContinueNoName.
  ///
  /// In en, this message translates to:
  /// **'Your pet is saved when you continue. You can change anything later.'**
  String get savedOnContinueNoName;

  /// No description provided for @pictureNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The picture could not be saved. You can add it later from {name}\'s profile.'**
  String pictureNotSaved(String name);

  /// No description provided for @petIsSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} is saved'**
  String petIsSaved(String name);

  /// No description provided for @aboutNote.
  ///
  /// In en, this message translates to:
  /// **'Add what you know; skip what you don\'t.'**
  String get aboutNote;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// Heading of the vet step.
  ///
  /// In en, this message translates to:
  /// **'Who looks after {name}?'**
  String whoLooksAfter(String name);

  /// No description provided for @vetStepNote.
  ///
  /// In en, this message translates to:
  /// **'With the vet\'s phone saved, a call or a message is two taps away in an emergency.'**
  String get vetStepNote;

  /// No description provided for @regularVet.
  ///
  /// In en, this message translates to:
  /// **'Regular vet'**
  String get regularVet;

  /// No description provided for @emergencyVet.
  ///
  /// In en, this message translates to:
  /// **'Emergency vet (24 h)'**
  String get emergencyVet;

  /// No description provided for @noVetYet.
  ///
  /// In en, this message translates to:
  /// **'I don\'t have a vet yet'**
  String get noVetYet;

  /// No description provided for @noVetYetNote.
  ///
  /// In en, this message translates to:
  /// **'No vet yet? Carry on: {name}\'s dashboard will keep a small reminder.'**
  String noVetYetNote(String name);

  /// No description provided for @whatAVetAsksFirst.
  ///
  /// In en, this message translates to:
  /// **'What a vet asks first'**
  String get whatAVetAsksFirst;

  /// No description provided for @healthStepNote.
  ///
  /// In en, this message translates to:
  /// **'If there is nothing to list, tick \"None known\". That is a real answer.'**
  String get healthStepNote;

  /// Button of the last step of the add-a-pet flow.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @tagEssential.
  ///
  /// In en, this message translates to:
  /// **'Essential'**
  String get tagEssential;

  /// No description provided for @tagOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get tagOptional;

  /// No description provided for @allSetChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the essentials…'**
  String get allSetChecking;

  /// No description provided for @allSetAllFilled.
  ///
  /// In en, this message translates to:
  /// **'All {total} essentials filled'**
  String allSetAllFilled(int total);

  /// No description provided for @allSetSomeFilled.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} essentials filled'**
  String allSetSomeFilled(int answered, int total);

  /// No description provided for @allSetNoteUnknown.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s dashboard shows a small reminder while an essential is missing.'**
  String allSetNoteUnknown(String name);

  /// No description provided for @allSetNoteComplete.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s essentials are complete. You can change anything from the profile.'**
  String allSetNoteComplete(String name);

  /// No description provided for @allSetNoteVet.
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep a small reminder on {name}\'s dashboard until the vet\'s phone is added.'**
  String allSetNoteVet(String name);

  /// No description provided for @allSetNoteRest.
  ///
  /// In en, this message translates to:
  /// **'We\'ll keep a small reminder on {name}\'s dashboard until the rest is added.'**
  String allSetNoteRest(String name);

  /// No description provided for @petIsReady.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready'**
  String petIsReady(String name);

  /// No description provided for @addNow.
  ///
  /// In en, this message translates to:
  /// **'Add now'**
  String get addNow;

  /// No description provided for @goToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Go to {name}\'s dashboard'**
  String goToDashboard(String name);

  /// No description provided for @addAnotherPet.
  ///
  /// In en, this message translates to:
  /// **'Add another pet'**
  String get addAnotherPet;

  /// No description provided for @checklistTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s essentials'**
  String checklistTitle(String name);

  /// No description provided for @checklistChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking what is answered…'**
  String get checklistChecking;

  /// No description provided for @checklistAllAnswered.
  ///
  /// In en, this message translates to:
  /// **'All {total} answered. Thank you!'**
  String checklistAllAnswered(int total);

  /// No description provided for @checklistSomeAnswered.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered. \"None known\" counts.'**
  String checklistSomeAnswered(int answered, int total);

  /// No description provided for @goodToHave.
  ///
  /// In en, this message translates to:
  /// **'Good to have'**
  String get goodToHave;

  /// No description provided for @remindInAWeek.
  ///
  /// In en, this message translates to:
  /// **'Remind me in a week'**
  String get remindInAWeek;

  /// No description provided for @reminderHiddenUntil.
  ///
  /// In en, this message translates to:
  /// **'The reminder is hidden until {date}. The dot on {name}\'s name stays.'**
  String reminderHiddenUntil(String date, String name);

  /// Tooltip of a "good to have" chip; {item} is its label.
  ///
  /// In en, this message translates to:
  /// **'{item}: answered'**
  String chipAnswered(String item);

  /// No description provided for @chipNotAdded.
  ///
  /// In en, this message translates to:
  /// **'{item}: not added yet'**
  String chipNotAdded(String item);

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @couldNotCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not check this right now'**
  String get couldNotCheck;

  /// No description provided for @itemVetPhone.
  ///
  /// In en, this message translates to:
  /// **'A vet\'s phone number'**
  String get itemVetPhone;

  /// No description provided for @itemAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get itemAllergies;

  /// No description provided for @itemConditions.
  ///
  /// In en, this message translates to:
  /// **'Medical conditions'**
  String get itemConditions;

  /// No description provided for @itemAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get itemAge;

  /// No description provided for @itemWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get itemWeight;

  /// No description provided for @itemPhoto.
  ///
  /// In en, this message translates to:
  /// **'A real photo'**
  String get itemPhoto;

  /// No description provided for @itemBreed.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get itemBreed;

  /// No description provided for @itemSexAndNeutering.
  ///
  /// In en, this message translates to:
  /// **'Sex and neutering'**
  String get itemSexAndNeutering;

  /// No description provided for @itemMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Microchip'**
  String get itemMicrochip;

  /// No description provided for @hintVetPhone.
  ///
  /// In en, this message translates to:
  /// **'So Emergency can call'**
  String get hintVetPhone;

  /// No description provided for @hintListOrNone.
  ///
  /// In en, this message translates to:
  /// **'A list, or \"None known\"'**
  String get hintListOrNone;

  /// No description provided for @hintAge.
  ///
  /// In en, this message translates to:
  /// **'A birthday, or \"about 3 years\"'**
  String get hintAge;

  /// No description provided for @hintWeight.
  ///
  /// In en, this message translates to:
  /// **'A rough number is fine'**
  String get hintWeight;

  /// No description provided for @hintPhoto.
  ///
  /// In en, this message translates to:
  /// **'Helps most if your pet is lost'**
  String get hintPhoto;

  /// No description provided for @hintBreed.
  ///
  /// In en, this message translates to:
  /// **'\"Mixed or not sure\" is an answer'**
  String get hintBreed;

  /// No description provided for @hintSexAndNeutering.
  ///
  /// In en, this message translates to:
  /// **'Asked on vet forms'**
  String get hintSexAndNeutering;

  /// No description provided for @hintMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Finds a lost pet'**
  String get hintMicrochip;

  /// No description provided for @hintEmergencyVet.
  ///
  /// In en, this message translates to:
  /// **'A night-time fallback'**
  String get hintEmergencyVet;

  /// No description provided for @actionVetPhone.
  ///
  /// In en, this message translates to:
  /// **'Add the vet\'s phone'**
  String get actionVetPhone;

  /// No description provided for @actionAllergies.
  ///
  /// In en, this message translates to:
  /// **'Answer about allergies'**
  String get actionAllergies;

  /// No description provided for @actionConditions.
  ///
  /// In en, this message translates to:
  /// **'Answer about conditions'**
  String get actionConditions;

  /// No description provided for @actionAge.
  ///
  /// In en, this message translates to:
  /// **'Add {name}\'s age'**
  String actionAge(String name);

  /// No description provided for @actionWeight.
  ///
  /// In en, this message translates to:
  /// **'Add {name}\'s weight'**
  String actionWeight(String name);

  /// No description provided for @actionPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of {name}'**
  String actionPhoto(String name);

  /// No description provided for @actionBreed.
  ///
  /// In en, this message translates to:
  /// **'Add {name}\'s breed'**
  String actionBreed(String name);

  /// No description provided for @actionSexAndNeutering.
  ///
  /// In en, this message translates to:
  /// **'Add sex and neutering'**
  String get actionSexAndNeutering;

  /// No description provided for @actionMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Add the microchip number'**
  String get actionMicrochip;

  /// No description provided for @actionEmergencyVet.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency vet'**
  String get actionEmergencyVet;

  /// No description provided for @petAgeTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s age'**
  String petAgeTitle(String name);

  /// No description provided for @petAgeNote.
  ///
  /// In en, this message translates to:
  /// **'A birthday, or a guess: both count.'**
  String get petAgeNote;

  /// No description provided for @petWeightTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s weight'**
  String petWeightTitle(String name);

  /// No description provided for @petWeightNote.
  ///
  /// In en, this message translates to:
  /// **'Every dose starts with the weight.'**
  String get petWeightNote;

  /// No description provided for @petBreedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s breed'**
  String petBreedTitle(String name);

  /// No description provided for @sexAndNeuteringNote.
  ///
  /// In en, this message translates to:
  /// **'\"Not sure\" is an answer too.'**
  String get sexAndNeuteringNote;

  /// No description provided for @essentialsStillToAdd.
  ///
  /// In en, this message translates to:
  /// **'{missing} of {total} essentials still to add'**
  String essentialsStillToAdd(int missing, int total);

  /// What a screen reader says for the reminder.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s profile: {missing} of {total} essentials still to add'**
  String reminderSemantics(String name, int missing, int total);

  /// No description provided for @finishProfile.
  ///
  /// In en, this message translates to:
  /// **'Finish {name}\'s profile'**
  String finishProfile(String name);

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @remindAgainInAWeek.
  ///
  /// In en, this message translates to:
  /// **'We\'ll remind you again in a week'**
  String get remindAgainInAWeek;

  /// No description provided for @essentialsComplete.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s essentials are complete'**
  String essentialsComplete(String name);

  /// What a screen reader says for the dot on a pet's pill.
  ///
  /// In en, this message translates to:
  /// **'Essentials missing'**
  String get essentialsMissing;

  /// No description provided for @essentialsToAdd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 essential to add} other{{count} essentials to add}}'**
  String essentialsToAdd(int count);

  /// Tag on a pet whose essentials are all answered.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @birthdayOrAge.
  ///
  /// In en, this message translates to:
  /// **'Birthday or age'**
  String get birthdayOrAge;

  /// No description provided for @iKnowTheDate.
  ///
  /// In en, this message translates to:
  /// **'I know the date'**
  String get iKnowTheDate;

  /// The choice to give an approximate age instead of a date.
  ///
  /// In en, this message translates to:
  /// **'About…'**
  String get aboutEllipsis;

  /// Label of the number field of an approximate age: about [3] years.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutField;

  /// No description provided for @unitYears.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get unitYears;

  /// No description provided for @unitMonths.
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get unitMonths;

  /// No description provided for @ageGuessNote.
  ///
  /// In en, this message translates to:
  /// **'A guess is fine. Shown as \"About 3 years\", and it keeps counting.'**
  String get ageGuessNote;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @chooseTheDate.
  ///
  /// In en, this message translates to:
  /// **'Choose the date'**
  String get chooseTheDate;

  /// No description provided for @sex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get sex;

  /// No description provided for @neuteredOrSpayed.
  ///
  /// In en, this message translates to:
  /// **'Neutered or spayed'**
  String get neuteredOrSpayed;

  /// No description provided for @breedOptional.
  ///
  /// In en, this message translates to:
  /// **'Breed (optional)'**
  String get breedOptional;

  /// No description provided for @breedExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Labrador'**
  String get breedExample;

  /// No description provided for @mixedOrNotSure.
  ///
  /// In en, this message translates to:
  /// **'Mixed or not sure'**
  String get mixedOrNotSure;

  /// No description provided for @breedTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the breed under {count} characters.'**
  String breedTooLong(int count);

  /// No description provided for @enterANumberLike.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, for example {example}.'**
  String enterANumberLike(int example);

  /// No description provided for @tooHeavy.
  ///
  /// In en, this message translates to:
  /// **'That looks too heavy. Please check the number.'**
  String get tooHeavy;

  /// No description provided for @enterANumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a number.'**
  String get enterANumber;

  /// No description provided for @checkTheNumber.
  ///
  /// In en, this message translates to:
  /// **'Please check the number.'**
  String get checkTheNumber;

  /// No description provided for @petPictureTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s picture'**
  String petPictureTitle(String name);

  /// No description provided for @yourPetsPicture.
  ///
  /// In en, this message translates to:
  /// **'Your pet\'s picture'**
  String get yourPetsPicture;

  /// What a screen reader says for the picture of a pet without a name yet.
  ///
  /// In en, this message translates to:
  /// **'Pet picture'**
  String get petPicture;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @takeAPhotoNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the camera'**
  String get takeAPhotoNote;

  /// No description provided for @chooseFromPhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose from your photos'**
  String get chooseFromPhotos;

  /// No description provided for @chooseFromPhotosNote.
  ///
  /// In en, this message translates to:
  /// **'Then fit it into the circle'**
  String get chooseFromPhotosNote;

  /// No description provided for @pickAnIcon.
  ///
  /// In en, this message translates to:
  /// **'Pick an icon'**
  String get pickAnIcon;

  /// No description provided for @pickAnIconNote.
  ///
  /// In en, this message translates to:
  /// **'{count} animals in the app\'s colours'**
  String pickAnIconNote(int count);

  /// No description provided for @removePicture.
  ///
  /// In en, this message translates to:
  /// **'Remove picture'**
  String get removePicture;

  /// No description provided for @removePictureNoteDog.
  ///
  /// In en, this message translates to:
  /// **'Back to the default dog icon'**
  String get removePictureNoteDog;

  /// No description provided for @removePictureNoteCat.
  ///
  /// In en, this message translates to:
  /// **'Back to the default cat icon'**
  String get removePictureNoteCat;

  /// No description provided for @removePictureNoteBird.
  ///
  /// In en, this message translates to:
  /// **'Back to the default bird icon'**
  String get removePictureNoteBird;

  /// No description provided for @removePictureNoteRabbit.
  ///
  /// In en, this message translates to:
  /// **'Back to the default rabbit icon'**
  String get removePictureNoteRabbit;

  /// No description provided for @removePictureNoteReptile.
  ///
  /// In en, this message translates to:
  /// **'Back to the default reptile icon'**
  String get removePictureNoteReptile;

  /// No description provided for @removePictureNoteOther.
  ///
  /// In en, this message translates to:
  /// **'Back to the default icon'**
  String get removePictureNoteOther;

  /// No description provided for @cropTitle.
  ///
  /// In en, this message translates to:
  /// **'Move and zoom'**
  String get cropTitle;

  /// No description provided for @cropHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · pinch to zoom'**
  String get cropHint;

  /// No description provided for @cropPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get cropPreview;

  /// No description provided for @cropChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get cropChooseAnother;

  /// No description provided for @cropUsePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get cropUsePhoto;

  /// No description provided for @cropFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not crop that photo. Please try another one.'**
  String get cropFailed;

  /// No description provided for @iconsForDog.
  ///
  /// In en, this message translates to:
  /// **'For a dog'**
  String get iconsForDog;

  /// No description provided for @iconsForCat.
  ///
  /// In en, this message translates to:
  /// **'For a cat'**
  String get iconsForCat;

  /// No description provided for @iconsForBird.
  ///
  /// In en, this message translates to:
  /// **'For a bird'**
  String get iconsForBird;

  /// No description provided for @iconsForRabbit.
  ///
  /// In en, this message translates to:
  /// **'For a rabbit'**
  String get iconsForRabbit;

  /// No description provided for @iconsForReptile.
  ///
  /// In en, this message translates to:
  /// **'For a reptile'**
  String get iconsForReptile;

  /// Heading above the icons suggested for a pet of kind "Other".
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get iconsSuggested;

  /// No description provided for @iconsAll.
  ///
  /// In en, this message translates to:
  /// **'All animals'**
  String get iconsAll;

  /// No description provided for @iconsBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get iconsBackground;

  /// No description provided for @iconsBackgroundYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow background'**
  String get iconsBackgroundYellow;

  /// No description provided for @iconsBackgroundGreen.
  ///
  /// In en, this message translates to:
  /// **'Green background'**
  String get iconsBackgroundGreen;

  /// No description provided for @iconsBackgroundPeach.
  ///
  /// In en, this message translates to:
  /// **'Peach background'**
  String get iconsBackgroundPeach;

  /// No description provided for @iconsBackgroundWhite.
  ///
  /// In en, this message translates to:
  /// **'White background'**
  String get iconsBackgroundWhite;

  /// No description provided for @iconsUse.
  ///
  /// In en, this message translates to:
  /// **'Use this icon'**
  String get iconsUse;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get changesSaved;

  /// No description provided for @petArchived.
  ///
  /// In en, this message translates to:
  /// **'{name} is archived. You can bring {name} back from My pets.'**
  String petArchived(String name);

  /// No description provided for @petDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} was deleted'**
  String petDeleted(String name);

  /// No description provided for @petProfile.
  ///
  /// In en, this message translates to:
  /// **'Pet profile'**
  String get petProfile;

  /// No description provided for @petNoLongerHere.
  ///
  /// In en, this message translates to:
  /// **'This pet is no longer here.'**
  String get petNoLongerHere;

  /// No description provided for @changePicture.
  ///
  /// In en, this message translates to:
  /// **'Change picture'**
  String get changePicture;

  /// Heading of the name, kind, age and weight fields on the pet profile.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get basics;

  /// Label of the field for the kind of animal.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kind;

  /// No description provided for @vet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get vet;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @archivePet.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}'**
  String archivePet(String name);

  /// No description provided for @deletePet.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String deletePet(String name);

  /// No description provided for @noneKnown.
  ///
  /// In en, this message translates to:
  /// **'None known'**
  String get noneKnown;

  /// No description provided for @notAnsweredYet.
  ///
  /// In en, this message translates to:
  /// **'Not answered yet'**
  String get notAnsweredYet;

  /// No description provided for @notAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get notAdded;

  /// Link that opens a question which has no answer yet.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @removePetTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removePetTitle(String name);

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archiveNote.
  ///
  /// In en, this message translates to:
  /// **'{name} is hidden from the app. Everything is kept, and you can bring {name} back from My pets.'**
  String archiveNote(String name);

  /// No description provided for @archiveOnlyPetNote.
  ///
  /// In en, this message translates to:
  /// **'{name} is your only pet, so there is nothing to show in its place. Add another pet first, or delete {name}.'**
  String archiveOnlyPetNote(String name);

  /// No description provided for @deleteForGood.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get deleteForGood;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Erases {name}\'s profile, picture, health records, reminders and documents. This cannot be undone.'**
  String deleteNote(String name);

  /// Tag on the recommended choice (archive rather than delete).
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get suggested;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get archived;

  /// No description provided for @archivedNote.
  ///
  /// In en, this message translates to:
  /// **'Archived pets keep all their records and are hidden from the rest of the app.'**
  String get archivedNote;

  /// Second line of an archived pet: its kind and when it was archived.
  ///
  /// In en, this message translates to:
  /// **'{kind} · archived {date}'**
  String archivedRow(String kind, String date);

  /// No description provided for @petIsBack.
  ///
  /// In en, this message translates to:
  /// **'{name} is back'**
  String petIsBack(String name);

  /// No description provided for @errNotYours.
  ///
  /// In en, this message translates to:
  /// **'You can only change your own pets. Please sign in again.'**
  String get errNotYours;

  /// No description provided for @errInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some of that information is not valid. Please check it and try again.'**
  String get errInvalid;

  /// No description provided for @errDatabaseOutdated.
  ///
  /// In en, this message translates to:
  /// **'The database is not up to date for pets yet (migration 0005 has not been run).'**
  String get errDatabaseOutdated;

  /// No description provided for @errSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errSignInAgain;

  /// No description provided for @errSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save your pet. Please try again.'**
  String get errSave;

  /// No description provided for @errLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load your pets. Please try again.'**
  String get errLoad;

  /// No description provided for @errDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your pet. Please try again.'**
  String get errDelete;

  /// No description provided for @errPhotoSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save the photo. Please try again.'**
  String get errPhotoSave;

  /// No description provided for @errPhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Could not remove the photo. Please try again.'**
  String get errPhotoRemove;

  /// No description provided for @errPhotoLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the photo. Please try again.'**
  String get errPhotoLoad;

  /// No description provided for @errPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large.'**
  String get errPhotoTooLarge;

  /// No description provided for @errPhotoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'That kind of picture is not supported.'**
  String get errPhotoUnsupported;

  /// No description provided for @errPhotoUnsupportedChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'That kind of picture is not supported. Please choose another one.'**
  String get errPhotoUnsupportedChooseAnother;

  /// No description provided for @errPhotoGone.
  ///
  /// In en, this message translates to:
  /// **'That photo is no longer available.'**
  String get errPhotoGone;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errCameraNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the camera. Check that PetLoop is allowed to use it.'**
  String get errCameraNotAllowed;

  /// No description provided for @errPhotosNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open your photos. Check that PetLoop is allowed to see them.'**
  String get errPhotosNotAllowed;

  /// No description provided for @errCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not open the camera.'**
  String get errCamera;

  /// No description provided for @errPhotos.
  ///
  /// In en, this message translates to:
  /// **'Could not open your photos.'**
  String get errPhotos;
}

class _PetsL10nDelegate extends LocalizationsDelegate<PetsL10n> {
  const _PetsL10nDelegate();

  @override
  Future<PetsL10n> load(Locale locale) {
    return SynchronousFuture<PetsL10n>(lookupPetsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_PetsL10nDelegate old) => false;
}

PetsL10n lookupPetsL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return PetsL10nEn();
    case 'he': return PetsL10nHe();
  }

  throw FlutterError(
    'PetsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
