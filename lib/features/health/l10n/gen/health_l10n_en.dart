// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'health_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class HealthL10nEn extends HealthL10n {
  HealthL10nEn([String locale = 'en']) : super(locale);

  @override
  String get tabTitle => 'Health';

  @override
  String get sectionOverview => 'Overview';

  @override
  String get sectionSchedule => 'Schedule';

  @override
  String get sectionHistory => 'History';

  @override
  String get sectionInsights => 'Insights';

  @override
  String get quickLog => 'Quick log';

  @override
  String loadFailedHealth(String name) {
    return 'Could not load $name\'s health';
  }

  @override
  String get safetyLine => 'Pet Companion never contacts anyone on its own, and it does not replace veterinary advice.';

  @override
  String clearField(String label) {
    return 'Clear $label';
  }

  @override
  String labelWithValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String weekdayAndDate(String weekday, String date) {
    return '$weekday $date';
  }

  @override
  String weekdayAndTime(String weekday, String time) {
    return '$weekday $time';
  }

  @override
  String dayAndTime(String day, String time) {
    return '$day · $time';
  }

  @override
  String sectionDetailDay(String day) {
    return '· $day';
  }

  @override
  String get change => 'Change';

  @override
  String get details => 'Details';

  @override
  String get notes => 'Notes';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get notAddedYet => 'Not added yet';

  @override
  String get notSet => 'Not set';

  @override
  String get remove => 'Remove';

  @override
  String removeNamed(String name) {
    return 'Remove $name';
  }

  @override
  String get couldNotOpenShareSheet => 'Could not open the share sheet on this device.';

  @override
  String fileSizeMb(String value) {
    return '$value MB';
  }

  @override
  String fileSizeKb(String value) {
    return '$value KB';
  }

  @override
  String fileSizeBytes(String value) {
    return '$value B';
  }

  @override
  String countAndLabel(int count, String label) {
    return '$count $label';
  }

  @override
  String get weight => 'Weight';

  @override
  String weightDownSince(String weight, String date) {
    return '$weight down since $date';
  }

  @override
  String weightUpSince(String weight, String date) {
    return '$weight up since $date';
  }

  @override
  String weightNoChangeSince(String date) {
    return 'No change since $date';
  }

  @override
  String get daysEveryDay => 'Every day';

  @override
  String get daysWeekdays => 'Weekdays';

  @override
  String get daysWeekends => 'Weekends';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get chooseAtLeastOneDay => 'Choose at least one day.';

  @override
  String get loadFailedContacts => 'Could not load the contacts';

  @override
  String get loadFailedEmergencyCard => 'Could not load the Emergency card';

  @override
  String get loadFailedKit => 'Could not load the emergency kit';

  @override
  String get loadFailedProfile => 'Could not load the health profile';

  @override
  String get loadFailedVets => 'Could not load the vets';

  @override
  String get loadFailedRecord => 'Could not load the record';

  @override
  String get loadFailedDocuments => 'Could not load the documents';

  @override
  String get loadFailedPhoto => 'Could not load the photo';

  @override
  String get errOffline => 'Could not reach the server. Check your connection and try again.';

  @override
  String get errSessionEnded => 'Your session has ended. Please sign in again.';

  @override
  String get errNotAllowed => 'You are not allowed to do that. Please sign in again.';

  @override
  String get errInvalid => 'Some of the details are not valid. Please check them and try again.';

  @override
  String get errPetNotStored => 'This pet is not saved to your account yet, so nothing can be stored for it.';

  @override
  String get errPetGone => 'That pet is no longer in your list.';

  @override
  String get errItemGone => 'That item no longer exists. Go back and open it again.';

  @override
  String get errRecordGone => 'That record no longer exists.';

  @override
  String get errVetGone => 'That vet no longer exists.';

  @override
  String get errMedicineGone => 'That medicine no longer exists.';

  @override
  String get errReminderGone => 'That reminder no longer exists.';

  @override
  String get errEntryGone => 'That entry no longer exists.';

  @override
  String get errFileType => 'Only photos (JPEG, PNG, WebP) and PDF files can be attached.';

  @override
  String get errFileEmpty => 'That file is empty.';

  @override
  String get errFileTooLarge => 'That file is larger than 5 MB. Please choose a smaller one.';

  @override
  String get errFileGone => 'That file is no longer available.';

  @override
  String get errFileNotStored => 'The file could not be stored. Please try again.';

  @override
  String get errFileUnreadable => 'Could not read that file.';

  @override
  String get errCamera => 'Could not open the camera.';

  @override
  String get errPhotos => 'Could not open your photos.';

  @override
  String get errFiles => 'Could not open your files.';

  @override
  String get errPdf => 'Could not prepare the PDF. Please try again.';

  @override
  String get errLostCard => 'Could not prepare the card. Please try again.';

  @override
  String get emergencyButton => 'Emergency';

  @override
  String get emergencyContacts => 'Emergency contacts';

  @override
  String emergencyContactsFor(String name) {
    return 'Emergency contacts for $name';
  }

  @override
  String get emergencyContactsNoPhone => 'Emergency contacts. No phone number saved yet';

  @override
  String emergencyContactsForNoPhone(String name) {
    return 'Emergency contacts for $name. No phone number saved yet';
  }

  @override
  String emergencySheetTitle(String name) {
    return 'Emergency · $name';
  }

  @override
  String get emergencySheetSubtitle => 'Call or message. You make the call or send the message yourself.';

  @override
  String openEmergencyCardOf(String name) {
    return 'Open $name\'s Emergency card';
  }

  @override
  String get vetRoleRegular => 'Regular vet';

  @override
  String get vetRoleEmergency => 'Emergency vet (24 h)';

  @override
  String get emergencyContact => 'Emergency contact';

  @override
  String addPetsVet(String name) {
    return 'Add $name\'s vet';
  }

  @override
  String get vetPromptNote => 'Phone and address, ready for an emergency';

  @override
  String noVetSavedFor(String name) {
    return 'No vet saved for $name yet';
  }

  @override
  String get noVetSavedNote => 'Add the vet\'s phone now, so a call or a message is two taps away when you need it.';

  @override
  String get useSavedVet => 'Use a vet you already saved';

  @override
  String get addNewVet => 'Add a new vet';

  @override
  String get actionCall => 'Call';

  @override
  String get actionMessage => 'Message';

  @override
  String get actionMap => 'Map';

  @override
  String get addPhoneNumber => 'Add a phone number';

  @override
  String get couldNotOpenPhone => 'Could not open the phone app';

  @override
  String get copyNumber => 'Copy number';

  @override
  String get couldNotOpenMaps => 'Could not open the maps app';

  @override
  String get copyAddress => 'Copy address';

  @override
  String messageTo(String name) {
    return 'Message to $name';
  }

  @override
  String get whatIsHappening => 'What is happening?';

  @override
  String get messagePreviewLabel => 'This is what will be written';

  @override
  String greetingOwner(String pet) {
    return 'Hello, I am $pet\'s owner.';
  }

  @override
  String greetingNamed(String owner, String pet) {
    return 'Hello, this is $owner, $pet\'s owner.';
  }

  @override
  String get greetingOwnerNoPet => 'Hello, I am my pet\'s owner.';

  @override
  String greetingNamedNoPet(String owner) {
    return 'Hello, this is $owner, my pet\'s owner.';
  }

  @override
  String messagePetLine(String name, String facts) {
    return '$name: $facts';
  }

  @override
  String messageAllergies(String list) {
    return 'Allergies: $list';
  }

  @override
  String messageConditions(String list) {
    return 'Conditions: $list';
  }

  @override
  String messageMedicines(String list) {
    return 'Medicines: $list';
  }

  @override
  String messageMicrochip(String number) {
    return 'Microchip: $number';
  }

  @override
  String get messageNoneKnown => 'none known';

  @override
  String messageMedicineLine(String name, String instructions) {
    return '$name, $instructions';
  }

  @override
  String messageDetailsNotLoaded(String name) {
    return '$name\'s details could not be loaded, so only your own words will be sent.';
  }

  @override
  String get messageDetailsNotLoadedNoPet => 'The pet\'s details could not be loaded, so only your own words will be sent.';

  @override
  String get removeThisLine => 'Remove this line';

  @override
  String get putRemovedLinesBack => 'Put the removed lines back';

  @override
  String get openInMessages => 'Open in Messages';

  @override
  String get openInWhatsApp => 'Open in WhatsApp';

  @override
  String get messageFinePrint => 'Nothing is sent until you press send in that app. In an emergency, calling is faster.';

  @override
  String get couldNotOpenWhatsApp => 'Could not open WhatsApp';

  @override
  String get couldNotOpenMessaging => 'Could not open the messaging app';

  @override
  String get copyMessage => 'Copy message';

  @override
  String get emergencyCardTitle => 'Emergency card';

  @override
  String get shareSummary => 'Share summary';

  @override
  String get allergies => 'Allergies';

  @override
  String get conditions => 'Conditions';

  @override
  String get noneKnown => 'None known';

  @override
  String get activeMedicines => 'Active medicines';

  @override
  String get microchip => 'Microchip';

  @override
  String get notChipped => 'Not chipped';

  @override
  String get allergiesAndConditions => 'Allergies and conditions';

  @override
  String get nothingSavedTapProfile => 'Nothing saved yet. Tap to fill in the health profile.';

  @override
  String petsVets(String name) {
    return '$name\'s vets';
  }

  @override
  String get editHealthProfile => 'Edit health profile';

  @override
  String get emergencyCardFinePrint => 'You make the call or send the message yourself. Pet Companion never contacts anyone on its own, and it does not replace veterinary advice.';

  @override
  String get emergencyKit => 'Emergency kit';

  @override
  String petsEmergencyKit(String name) {
    return '$name\'s emergency kit';
  }

  @override
  String kitAllReady(int total) {
    return 'All $total ready';
  }

  @override
  String kitSomeReady(int ready, int total) {
    return '$ready of $total ready';
  }

  @override
  String get kitWhatToHaveReady => 'What to have ready';

  @override
  String get kitSummaryNote => 'For sirens, a quick move to the protected room, or leaving home in a hurry.';

  @override
  String get kitCarrierDog => 'Carrier or crate, lead and harness';

  @override
  String get kitCarrier => 'Carrier';

  @override
  String get kitTravelCage => 'Travel cage';

  @override
  String get kitTravelBox => 'Travel box';

  @override
  String get kitCarrierOrCage => 'Carrier or travel cage';

  @override
  String get kitCarrierNote => 'Within reach, near the door.';

  @override
  String get kitFoodWater => 'Food and water for three days';

  @override
  String get kitFoodWaterNote => 'With a bowl, in one bag.';

  @override
  String get kitDocuments => 'Documents';

  @override
  String get kitDocumentsNoteDog => 'Vaccination booklet and licence, on paper or as photos.';

  @override
  String get kitDocumentsNote => 'Vaccination booklet and vet papers, on paper or as photos.';

  @override
  String get kitMicrochip => 'Microchip details up to date';

  @override
  String kitMicrochipNumber(String number) {
    return '$number · your phone number in the chip registry is current.';
  }

  @override
  String get kitMicrochipNotChipped => 'Marked as not chipped in the health profile.';

  @override
  String get kitMicrochipNone => 'No microchip number saved yet.';

  @override
  String get kitMedicines => 'Medicines';

  @override
  String kitMedicinesNote(String names) {
    return '$names · a spare supply in the kit.';
  }

  @override
  String get kitShelterPlan => 'A plan for the protected room';

  @override
  String kitShelterPlanNote(String name) {
    return 'Who takes $name, and where the carrier is.';
  }

  @override
  String kitDocumentsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents saved here',
      one: '1 document saved here',
    );
    return '$_temp0';
  }

  @override
  String get healthProfile => 'Health profile';

  @override
  String kitTicked(String date) {
    return 'Ticked $date';
  }

  @override
  String get kitOurPlan => 'Our plan (optional)';

  @override
  String get kitFinePrint => 'Your own list, not official guidance. During an emergency follow the Home Front Command\'s instructions.';

  @override
  String petsHealthProfile(String name) {
    return '$name\'s health profile';
  }

  @override
  String get identification => 'Identification';

  @override
  String get microchipNumberOptional => 'Microchip number (optional)';

  @override
  String validNumberTooLong(int count) {
    return 'Keep the number under $count characters.';
  }

  @override
  String get knownAllergies => 'Known allergies, one per line';

  @override
  String get medicalConditions => 'Medical conditions';

  @override
  String get knownConditions => 'Known conditions, one per line';

  @override
  String get validKeepShorter => 'Please keep this shorter.';

  @override
  String get emergencyContactHeading => 'Emergency contact (someone who can help)';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get validPhone => 'That does not look like a phone number.';

  @override
  String get anythingElseForVet => 'Anything else a vet should know';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileFinePrint => 'Everything here is optional. It fills the Emergency card and the message to the vet.';

  @override
  String get vet => 'Vet';

  @override
  String get addVet => 'Add a vet';

  @override
  String get editVet => 'Edit vet';

  @override
  String get deleteVet => 'Delete vet';

  @override
  String get deleteVetTitle => 'Delete this vet?';

  @override
  String deleteVetMessage(String name) {
    return '\"$name\" will be removed from your account and from every pet that uses it.';
  }

  @override
  String get whoIsIt => 'Who is it?';

  @override
  String get vetOrClinicName => 'Vet or clinic name';

  @override
  String get validVetName => 'Enter the name of the vet or the clinic.';

  @override
  String validNameTooLong(int count) {
    return 'Keep the name under $count characters.';
  }

  @override
  String get howToReachThem => 'How to reach them';

  @override
  String get fieldPhone => 'Phone';

  @override
  String get validWhatsAppNumber => 'Enter the number that is on WhatsApp.';

  @override
  String validWhatsAppCountryCode(String example) {
    return 'For WhatsApp, start with the country code, like $example.';
  }

  @override
  String get onWhatsApp => 'This number is on WhatsApp';

  @override
  String onWhatsAppNote(String example) {
    return 'Adds a WhatsApp button next to the text message. Needs the country code, like $example.';
  }

  @override
  String get fieldAddress => 'Address';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get openingHours => 'Opening hours';

  @override
  String get openingHoursOptional => 'Opening hours (optional)';

  @override
  String get saveVet => 'Save vet';

  @override
  String get vetFormFinePrint => 'Saved once for your account, so your other pets can use the same vet.';

  @override
  String get chooseRegularVet => 'Choose the regular vet';

  @override
  String get chooseEmergencyVet => 'Choose the emergency vet';

  @override
  String get vetPickerNote => 'Vets you saved before can be used for any of your pets.';

  @override
  String removeVetFromPet(String name) {
    return 'Remove $name from this pet';
  }

  @override
  String get noPhoneYet => 'No phone number yet';

  @override
  String get inUse => 'In use';

  @override
  String get useVet => 'Use';

  @override
  String get addEmergencyVet => 'Add an emergency vet';

  @override
  String get emergencyVetPromptNote => 'A 24-hour clinic for nights and weekends';

  @override
  String get vetsFinePrint => 'Vets are saved once for your account, so your other pets can use the same ones.';

  @override
  String editNamed(String name) {
    return 'Edit $name';
  }

  @override
  String petIsLost(String name) {
    return '$name is lost';
  }

  @override
  String get lostCardSection => 'What goes on the card';

  @override
  String get lostNoPhoto => 'No photo on the card';

  @override
  String lostPetsPhoto(String name) {
    return '$name\'s photo';
  }

  @override
  String get lostPhotoChosen => 'Chosen for this card only';

  @override
  String get lostPhotoFromProfile => 'From the pet profile';

  @override
  String get lostPhotoHint => 'A recent, clear photo helps most';

  @override
  String get lostDescription => 'Description';

  @override
  String lostDescriptionHint(String name) {
    return 'Colour, size, collar, how $name behaves with strangers';
  }

  @override
  String get lostArea => 'Last seen: area';

  @override
  String get lostAreaExact => 'This looks like an exact address. A neighbourhood or a street corner is safer.';

  @override
  String get lostAreaHint => 'A neighbourhood or a street corner is enough. Not your home address.';

  @override
  String get lostWhen => 'Last seen: when';

  @override
  String get lostWhenHelp => 'Last seen';

  @override
  String get lostTimeHelp => 'Around what time?';

  @override
  String get lostYourPhone => 'Your phone number';

  @override
  String get lostExtra => 'Anything else (optional)';

  @override
  String get lostExtraHint => 'For example: needs a daily medicine';

  @override
  String get lostLanguage => 'Language of the card';

  @override
  String get lostPreviewLabel => 'This is what will be shared';

  @override
  String lostShowPhone(String phone) {
    return 'Show this phone number on the card: $phone';
  }

  @override
  String get lostAddPhoneFirst => 'Add your phone number, then confirm it here.';

  @override
  String get shareAsImage => 'Share as image';

  @override
  String get shareAsPdf => 'Share as PDF to print';

  @override
  String petIsBackHome(String name) {
    return '$name is back home';
  }

  @override
  String get lostGoodNews => 'Good news. The card is put away.';

  @override
  String get lostFinePrint => 'Nothing is posted by the app. You choose where the card goes. The microchip number and your vet are never on it.';

  @override
  String lostCardHeading(String name) {
    return 'Looking for $name';
  }

  @override
  String get lostCardArea => 'Area';

  @override
  String get lostCardWhen => 'When';

  @override
  String get lostCardMicrochip => 'Microchip';

  @override
  String get lostCardMicrochipped => 'Microchipped';

  @override
  String lostCardCall(String name) {
    return 'Seen $name? Please call';
  }

  @override
  String get lostCardFooter => 'Made with Pet Companion';

  @override
  String lostCardAround(String date, String time) {
    return '$date, around $time';
  }

  @override
  String get overviewNoCareDue => 'No scheduled care due';

  @override
  String overviewLastRecord(String date) {
    return 'Last record $date';
  }

  @override
  String get comingUp => 'Coming up';

  @override
  String get recordDose => 'Record';

  @override
  String remindersNeedReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders need review',
      one: '1 reminder needs review',
    );
    return '$_temp0';
  }

  @override
  String get addRecord => 'Add record';

  @override
  String get medicines => 'Medicines';

  @override
  String medicinesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String get noDoseYet => 'No dose recorded yet';

  @override
  String lastDoseToday(String time) {
    return 'Last recorded dose: today $time';
  }

  @override
  String lastDoseYesterday(String time) {
    return 'Last recorded dose: yesterday $time';
  }

  @override
  String lastDoseOn(String day, String time) {
    return 'Last recorded dose: $day $time';
  }

  @override
  String get smallWeightChart => 'Small weight chart';

  @override
  String get medicalRecords => 'Medical records';

  @override
  String get vaccinations => 'Vaccinations';

  @override
  String get vetVisits => 'Vet visits';

  @override
  String get documents => 'Documents';

  @override
  String get startWithOneThing => 'Start with one thing';

  @override
  String startNote(String name) {
    return 'No need to enter $name\'s whole history. Add things as they come up.';
  }

  @override
  String get startDocument => 'Add a document you already have';

  @override
  String get startDocumentNote => 'A photo or PDF of the vaccination booklet or a vet letter';

  @override
  String get startAppointment => 'Enter an upcoming appointment';

  @override
  String get startAppointmentNote => 'So it shows under Coming up';

  @override
  String get startMedicine => 'Create a medicine reminder';

  @override
  String get startMedicineNote => 'With the vet\'s instructions and the times';

  @override
  String get addToSchedule => 'Add to the schedule';

  @override
  String get addAppointment => 'Appointment or due date';

  @override
  String get addAppointmentNote => 'A vet visit, a vaccination, a treatment';

  @override
  String get medicine => 'Medicine';

  @override
  String get addMedicineNote => 'The vet\'s instructions and the reminder times';

  @override
  String get routine => 'Routine';

  @override
  String get addRoutineNote => 'Feeding, walks, grooming, cleaning';

  @override
  String get scheduleEmpty => 'Nothing scheduled yet';

  @override
  String scheduleEmptyNote(String name) {
    return 'Appointments, medicine reminders and daily routines for $name will show here.';
  }

  @override
  String get nothingDueToday => 'Nothing is due today.';

  @override
  String get allAnsweredToday => 'Everything for today is answered.';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get noUpcoming => 'No appointments or due dates ahead.';

  @override
  String get needsReview => 'Needs review';

  @override
  String needsReviewNote(int days) {
    return 'No answer was recorded for these. Nothing is counted as missed; a medicine reminder leaves this list after $days days.';
  }

  @override
  String get medicinesAndRoutines => 'Medicines and routines';

  @override
  String markNamedAsDone(String title) {
    return 'Mark $title as done';
  }

  @override
  String dueAt(String time) {
    return 'due $time';
  }

  @override
  String doneTodayCount(int count) {
    return 'Done today · $count';
  }

  @override
  String doneLineGivenAt(String title, String time) {
    return '$title given $time';
  }

  @override
  String doneLineGiven(String title) {
    return '$title given';
  }

  @override
  String doneLineNotGiven(String title) {
    return '$title not given';
  }

  @override
  String doneLineNotSure(String title) {
    return '$title not sure';
  }

  @override
  String doneLineAt(String title, String time) {
    return '$title $time';
  }

  @override
  String doneLineSkipped(String title) {
    return '$title skipped';
  }

  @override
  String get undo => 'Undo';

  @override
  String get dateGivenByVet => 'date given by the vet';

  @override
  String followUpDue(String title) {
    return '$title due';
  }

  @override
  String get noAnswerRecorded => 'no answer recorded';

  @override
  String get notMarkedAsDone => 'not marked as done';

  @override
  String get given => 'Given';

  @override
  String givenAt(String time) {
    return 'Given $time';
  }

  @override
  String get notGiven => 'Not given';

  @override
  String get notSure => 'Not sure';

  @override
  String get movedToHistory => 'Moved to the History.';

  @override
  String get itHappened => 'It happened';

  @override
  String get changeOrDelete => 'Change or delete';

  @override
  String get onlyWhenNeeded => 'Only when needed';

  @override
  String medicineEnded(String date) {
    return 'Ended $date';
  }

  @override
  String medicineStarts(String date) {
    return 'Starts $date';
  }

  @override
  String get medicineNotActive => 'Not active';

  @override
  String get paused => 'Paused';

  @override
  String get newMedicine => 'New medicine';

  @override
  String get editMedicine => 'Edit medicine';

  @override
  String get deleteMedicine => 'Delete medicine';

  @override
  String get deleteMedicineTitle => 'Delete this medicine?';

  @override
  String deleteMedicineMessage(String name) {
    return '\"$name\", its reminders and its dose log will be removed. This cannot be undone.';
  }

  @override
  String get fromVetInstructions => 'From the vet\'s instructions';

  @override
  String get fieldName => 'Name';

  @override
  String get validMedicineName => 'Enter the name of the medicine.';

  @override
  String get strengthOptional => 'Strength (optional)';

  @override
  String get strengthHint => '50 mg';

  @override
  String get doseOptional => 'Dose (optional)';

  @override
  String get doseHint => '1 tablet';

  @override
  String get howItIsGiven => 'How it is given';

  @override
  String get routeByMouth => 'By mouth';

  @override
  String get routeOnSkin => 'On the skin';

  @override
  String get routeInEye => 'In the eye';

  @override
  String get routeInEar => 'In the ear';

  @override
  String get routeInjection => 'Injection';

  @override
  String get routeOther => 'Other';

  @override
  String medicineDoseAndRoute(String dose, String route) {
    return '$dose $route';
  }

  @override
  String medicineHowAndOften(String how, String often) {
    return '$how, $often';
  }

  @override
  String get howOftenOptional => 'How often (optional)';

  @override
  String get howOftenHint => 'Twice a day, with food';

  @override
  String get fieldStart => 'Start';

  @override
  String get endOptional => 'End (optional)';

  @override
  String get noEnd => 'No end';

  @override
  String get firstDayOfMedicine => 'First day of the medicine';

  @override
  String get lastDayOfMedicine => 'Last day of the medicine';

  @override
  String get prescribedByOptional => 'Prescribed by (optional)';

  @override
  String get reminders => 'Reminders';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get addATime => 'Add a time';

  @override
  String get medicineNoTimesNote => 'No reminder times: a medicine given only when needed.';

  @override
  String get medicineReminderNote => 'A reminder nobody answers waits under Needs review. It is never counted as missed.';

  @override
  String get validLastBeforeFirst => 'The last day should not be before the first day.';

  @override
  String get validReminderDays => 'Choose at least one day for the reminders.';

  @override
  String get saveMedicine => 'Save medicine';

  @override
  String get medicineFinePrint => 'The app stores what you enter. It never suggests a dose.';

  @override
  String get doseLog => 'Dose log';

  @override
  String get noDoseRecordedYet => 'No dose recorded yet.';

  @override
  String doseLogReminder(String time) {
    return 'reminder $time';
  }

  @override
  String get doseLogWhenNeeded => 'when needed';

  @override
  String doseLoggedBy(String name) {
    return 'logged by $name';
  }

  @override
  String get doseLoggedByYou => 'logged by you';

  @override
  String doseGivenWhenNeeded(String name) {
    return 'Given when needed · $name';
  }

  @override
  String reminderForToday(String time) {
    return 'Reminder for today · $time';
  }

  @override
  String reminderForYesterday(String time) {
    return 'Reminder for yesterday · $time';
  }

  @override
  String reminderForDay(String day, String time) {
    return 'Reminder for $day · $time';
  }

  @override
  String vetsInstructions(String text) {
    return 'Vet\'s instructions: $text.';
  }

  @override
  String givenNowAt(String time) {
    return 'Given now · $time';
  }

  @override
  String get givenAtAnotherTime => 'Given at another time';

  @override
  String get whenWasItGiven => 'When was it given?';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get doseNoteHint => 'For example: hidden in cheese';

  @override
  String get validTimeAhead => 'That time is still ahead. Record the dose once it is given.';

  @override
  String get doseRecordedGiven => 'Dose recorded as given.';

  @override
  String get doseRecordedNotGiven => 'Recorded as not given.';

  @override
  String get doseRecordedNotSure => 'Recorded as not sure.';

  @override
  String doseFinePrintNamed(String name) {
    return 'Saved as logged by $name, with the time. If you are unsure about a dose, ask your vet.';
  }

  @override
  String get doseFinePrintYou => 'Saved as logged by you, with the time. If you are unsure about a dose, ask your vet.';

  @override
  String get newRoutine => 'New routine';

  @override
  String get editRoutine => 'Edit routine';

  @override
  String get deleteRoutine => 'Delete routine';

  @override
  String get deleteRoutineTitle => 'Delete this routine?';

  @override
  String deleteRoutineMessage(String title) {
    return '\"$title\" leaves the Schedule. What was already ticked stays in the log.';
  }

  @override
  String get whatKindOfRoutine => 'What kind of routine?';

  @override
  String get careFeeding => 'Feeding';

  @override
  String get careWalk => 'Walk';

  @override
  String get careGrooming => 'Grooming';

  @override
  String get careCleaning => 'Cleaning';

  @override
  String get careLitterCleaning => 'Litter box cleaning';

  @override
  String get careLitterChange => 'Litter change';

  @override
  String get careCageCleaning => 'Cage cleaning';

  @override
  String get careEnclosureCleaning => 'Enclosure cleaning';

  @override
  String get careOther => 'Other';

  @override
  String get fieldTitle => 'Title';

  @override
  String get routineTitleHint => 'Breakfast, evening walk...';

  @override
  String get validRoutineTitle => 'Give the routine a title.';

  @override
  String validTitleTooLong(int count) {
    return 'Keep the title under $count characters.';
  }

  @override
  String get fieldTime => 'Time';

  @override
  String get timeOfRoutine => 'Time of the routine';

  @override
  String get fieldDays => 'Days';

  @override
  String get showInSchedule => 'Show it in the Schedule';

  @override
  String get routineOn => 'On';

  @override
  String get routinePausedNote => 'Paused: kept here, but not due';

  @override
  String get saveRoutine => 'Save routine';

  @override
  String get historyEmpty => 'No records yet';

  @override
  String historyEmptyNote(String name) {
    return 'Vet visits, vaccinations, treatments and documents will build $name\'s history here.';
  }

  @override
  String get addARecord => 'Add a record';

  @override
  String searchRecords(String name) {
    return 'Search $name\'s records';
  }

  @override
  String get clearSearch => 'Clear the search';

  @override
  String get filterAll => 'All';

  @override
  String get kindCheckup => 'Vet visit';

  @override
  String get kindVaccination => 'Vaccination';

  @override
  String get kindPreventive => 'Preventive';

  @override
  String get kindProcedure => 'Procedure';

  @override
  String get kindMedicine => 'Medicine';

  @override
  String get kindDocument => 'Document';

  @override
  String get kindOther => 'Note';

  @override
  String get kindsPreventive => 'Preventive';

  @override
  String get kindsProcedure => 'Procedures';

  @override
  String get kindsMedicine => 'Medicine';

  @override
  String recordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
    );
    return '$_temp0';
  }

  @override
  String recordsShown(int shown, int total) {
    return '$shown of $total records';
  }

  @override
  String get nothingMatches => 'Nothing matches';

  @override
  String get nothingMatchesNote => 'No record fits this search and filter.';

  @override
  String get showAllRecords => 'Show all records';

  @override
  String nextDue(String date) {
    return 'Next due $date';
  }

  @override
  String costSemantics(String amount) {
    return 'Cost $amount';
  }

  @override
  String attachmentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get record => 'Record';

  @override
  String get newRecord => 'New record';

  @override
  String get newAppointment => 'New appointment';

  @override
  String get editRecord => 'Edit record';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get deleteRecordTitle => 'Delete this record?';

  @override
  String deleteRecordMessage(String title) {
    return '\"$title\" and its attachments will be removed. This cannot be undone.';
  }

  @override
  String get whatKindOfRecord => 'What kind of record?';

  @override
  String get validRecordTitle => 'Give the record a title.';

  @override
  String get productOptional => 'Product (optional)';

  @override
  String get product => 'Product';

  @override
  String get plannedFor => 'Planned for';

  @override
  String get dateGiven => 'Date given';

  @override
  String get fieldDate => 'Date';

  @override
  String get recordAheadNote => 'This date is still ahead, so it is saved as an upcoming item in the Schedule.';

  @override
  String get nextDueOptional => 'Next due (optional)';

  @override
  String get nextDueHelp => 'Next due date, from your vet';

  @override
  String get nextDueNote => 'Enter the date your vet gave you. It will appear in the Schedule.';

  @override
  String get nextDueFromVet => 'Next due (from the vet)';

  @override
  String get validNextDueAfter => 'The next due date should be after the date given.';

  @override
  String get vetOrClinicOptional => 'Vet or clinic (optional)';

  @override
  String get vetOrClinic => 'Vet or clinic';

  @override
  String get costOptional => 'Cost (optional)';

  @override
  String get expectedCostOptional => 'Expected cost (optional)';

  @override
  String get cost => 'Cost';

  @override
  String get expectedCost => 'Expected cost';

  @override
  String get validAmount => 'Enter an amount, like 120 or 89.90.';

  @override
  String get costNotePaid => 'What you paid. It stays with your records and is left out of anything you share with a vet.';

  @override
  String get costNoteExpected => 'What you expect to pay. It stays with your records and is left out of anything you share with a vet.';

  @override
  String get notesHint => 'Anything worth remembering';

  @override
  String get validNotesTooLong => 'Please keep the notes shorter.';

  @override
  String get attachments => 'Attachments';

  @override
  String get addPhotoOrPdf => 'Add a photo or PDF';

  @override
  String get saveRecord => 'Save record';

  @override
  String savedButFileNotAttached(String problem) {
    return 'The record is saved, but a file was not attached. $problem';
  }

  @override
  String savedButNextDueNotPlanned(String problem) {
    return 'The record is saved, but its next due date was not added to the schedule. $problem Saving again tries once more.';
  }

  @override
  String get removeFileTitle => 'Remove this file?';

  @override
  String removeFileMessage(String name) {
    return '\"$name\" will be removed from the record.';
  }

  @override
  String get recordGone => 'This record is gone';

  @override
  String get recordGoneNote => 'It was deleted.';

  @override
  String fileAttached(String name) {
    return '$name is attached.';
  }

  @override
  String get inTheSchedule => 'In the Schedule';

  @override
  String get markAsDone => 'Mark as done';

  @override
  String get noAttachmentsNote => 'No photos or PDFs yet. A photo opens full screen; a PDF opens in the phone\'s viewer.';

  @override
  String get shareThisRecord => 'Share this record';

  @override
  String get deleteInsideEdit => 'Delete is inside Edit, and always asks first.';

  @override
  String get attachSheetNote => 'A booklet page, a vet letter, a lab result. Up to 5 MB.';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get withTheCamera => 'With the camera';

  @override
  String get chooseAPhoto => 'Choose a photo';

  @override
  String get fromYourPhotos => 'From your photos';

  @override
  String get chooseAPdf => 'Choose a PDF file';

  @override
  String get fromPhoneFiles => 'From the phone\'s files';

  @override
  String get fileKindPdf => 'PDF';

  @override
  String get fileKindPhoto => 'Photo';

  @override
  String get couldNotOpenFile => 'Could not open that file on this device.';

  @override
  String get shareThisPhoto => 'Share this photo';

  @override
  String petsDocuments(String name) {
    return '$name\'s documents';
  }

  @override
  String get noDocumentsYet => 'No documents yet';

  @override
  String get noDocumentsNote => 'Photos and PDFs you attach to a record show here.';

  @override
  String get documentsFinePrint => 'A photo opens full screen; a PDF opens in the phone\'s viewer.';

  @override
  String get insightsEmpty => 'Nothing logged yet';

  @override
  String insightsEmptyNote(String name) {
    return 'Weight, appetite, energy and anything else you notice about $name will build a picture here.';
  }

  @override
  String get openQuickLog => 'Open the Quick log';

  @override
  String get observations => 'Observations';

  @override
  String get groupBody => 'Body';

  @override
  String get groupBehaviour => 'Behaviour';

  @override
  String get insightsFinePrint => 'What you noticed, in your own words. The app does not interpret it.';

  @override
  String get logWeight => 'Log weight';

  @override
  String get noWeightYet => 'No weight logged yet.';

  @override
  String weighIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weigh-ins',
      one: '1 weigh-in',
    );
    return '$_temp0';
  }

  @override
  String weightHighest(String value) {
    return 'highest $value';
  }

  @override
  String weightLowest(String value) {
    return 'lowest $value';
  }

  @override
  String weightTrendSemantics(String from, String fromDate, String to, String toDate) {
    return 'Weight trend from $from on $fromDate to $to on $toDate';
  }

  @override
  String get vetVisitMarker => 'vet visit';

  @override
  String get noted => 'Noted';

  @override
  String get levelUsual => 'Usual';

  @override
  String get levelLess => 'Less than usual';

  @override
  String get levelMore => 'More than usual';

  @override
  String get levelDifferent => 'Different from usual';

  @override
  String get logAppetite => 'Appetite';

  @override
  String get logEnergy => 'Energy';

  @override
  String get logMobility => 'Mobility';

  @override
  String get logDigestion => 'Digestion';

  @override
  String get logSkinCoat => 'Skin or coat';

  @override
  String get logDental => 'Dental';

  @override
  String get logDrinking => 'Drinking';

  @override
  String get logDiet => 'Diet';

  @override
  String get logDroppings => 'Droppings';

  @override
  String get logFeathers => 'Feathers';

  @override
  String get logActivity => 'Activity';

  @override
  String get logEnvironment => 'Environment';

  @override
  String get logEating => 'Eating';

  @override
  String get logFeeding => 'Feeding';

  @override
  String get logShedding => 'Shedding';

  @override
  String get logTemperature => 'Temperature';

  @override
  String get logHumidity => 'Humidity';

  @override
  String get logLighting => 'Lighting';

  @override
  String get logOther => 'Other';

  @override
  String get logSleep => 'Sleep';

  @override
  String get logBarking => 'Barking';

  @override
  String get logMeowing => 'Meowing';

  @override
  String get logVocalisation => 'Vocalisation';

  @override
  String get logBiting => 'Biting';

  @override
  String get logBitingScratching => 'Biting or scratching';

  @override
  String get logLeftAlone => 'When left alone';

  @override
  String get logLitterBox => 'Litter box use';

  @override
  String get logOtherBehaviour => 'Other behaviour';

  @override
  String quickLogFor(String name) {
    return 'Quick log for $name';
  }

  @override
  String get whatDidYouNotice => 'What did you notice?';

  @override
  String get editEntry => 'Edit entry';

  @override
  String get weightInGrams => 'Weight in grams';

  @override
  String get weightInKilograms => 'Weight in kilograms';

  @override
  String lastTimeWeight(String weight, String date) {
    return 'Last time: $weight on $date';
  }

  @override
  String get fieldWhen => 'When';

  @override
  String get whenDidYouNotice => 'When did you notice it?';

  @override
  String get validWeight => 'That weight does not look right. Please check the number.';

  @override
  String get saveToJournal => 'Save to journal';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get savedToJournal => 'Saved to the journal.';

  @override
  String get entryUpdated => 'Entry updated.';

  @override
  String get deleteThisEntry => 'Delete this entry';

  @override
  String get deleteEntryTitle => 'Delete this entry?';

  @override
  String get deleteEntryMessage => 'It is removed from the journal. This cannot be undone.';

  @override
  String get looksUrgent => 'Looks urgent? Contact the vet';

  @override
  String get quickLogFinePrint => 'A record of what you noticed. The app does not interpret it.';

  @override
  String reportSummaryTitle(String name) {
    return '$name: health summary';
  }

  @override
  String reportRecordTitle(String name, String title) {
    return '$name: $title';
  }

  @override
  String reportPrepared(String date) {
    return 'Prepared on $date with Pet Companion';
  }

  @override
  String reportPreparedBy(String date, String owner) {
    return 'Prepared on $date by $owner with Pet Companion';
  }

  @override
  String get reportEmergencyVet => 'Emergency vet';

  @override
  String reportMedicineLine(String name, String instructions) {
    return '$name: $instructions';
  }

  @override
  String get reportRecords => 'Records';

  @override
  String get reportRecentRecords => 'Recent records';

  @override
  String get reportPlanned => 'Planned';

  @override
  String get reportColumnKind => 'Kind';

  @override
  String get reportFooter => 'Written by the owner in Pet Companion. It is a record of what was entered, not veterinary advice.';
}
