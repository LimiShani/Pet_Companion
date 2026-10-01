import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'health_l10n_en.dart';
import 'health_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of HealthL10n
/// returned by `HealthL10n.of(context)`.
///
/// Applications need to include `HealthL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/health_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: HealthL10n.localizationsDelegates,
///   supportedLocales: HealthL10n.supportedLocales,
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
/// be consistent with the languages listed in the HealthL10n.supportedLocales
/// property.
abstract class HealthL10n {
  HealthL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static HealthL10n of(BuildContext context) {
    return Localizations.of<HealthL10n>(context, HealthL10n)!;
  }

  static const LocalizationsDelegate<HealthL10n> delegate = _HealthL10nDelegate();

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

  /// Title of the Health tab's header.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get tabTitle;

  /// No description provided for @sectionOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get sectionOverview;

  /// No description provided for @sectionSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get sectionSchedule;

  /// No description provided for @sectionHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get sectionHistory;

  /// No description provided for @sectionInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get sectionInsights;

  /// No description provided for @quickLog.
  ///
  /// In en, this message translates to:
  /// **'Quick log'**
  String get quickLog;

  /// No description provided for @loadFailedHealth.
  ///
  /// In en, this message translates to:
  /// **'Could not load {name}\'s health'**
  String loadFailedHealth(String name);

  /// The line shown wherever the app offers to call or message someone.
  ///
  /// In en, this message translates to:
  /// **'Pet Companion never contacts anyone on its own, and it does not replace veterinary advice.'**
  String get safetyLine;

  /// Tooltip of the small x on a field; {label} is the name of the field.
  ///
  /// In en, this message translates to:
  /// **'Clear {label}'**
  String clearField(String label);

  /// What a screen reader says for a field that shows a picked value.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String labelWithValue(String label, String value);

  /// A short day name and a date: Thu 12.06.25.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {date}'**
  String weekdayAndDate(String weekday, String date);

  /// A short day name and a time: Thu 18:20.
  ///
  /// In en, this message translates to:
  /// **'{weekday} {time}'**
  String weekdayAndTime(String weekday, String time);

  /// A day (Today, or Thu 12.06.25) and a time.
  ///
  /// In en, this message translates to:
  /// **'{day} · {time}'**
  String dayAndTime(String day, String time);

  /// The quieter text after a heading: Today · Tue, Jun 10.
  ///
  /// In en, this message translates to:
  /// **'· {day}'**
  String sectionDetailDay(String day);

  /// Link: choose another vet, or another photo.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @notAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Not added yet'**
  String get notAddedYet;

  /// Shown in a date field while no date is chosen.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Tooltip: removes the file or the time called {name}.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeNamed(String name);

  /// No description provided for @couldNotOpenShareSheet.
  ///
  /// In en, this message translates to:
  /// **'Could not open the share sheet on this device.'**
  String get couldNotOpenShareSheet;

  /// No description provided for @fileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String fileSizeMb(String value);

  /// No description provided for @fileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String fileSizeKb(String value);

  /// No description provided for @fileSizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String fileSizeBytes(String value);

  /// What a screen reader says for a count tile: 3 Vaccinations.
  ///
  /// In en, this message translates to:
  /// **'{count} {label}'**
  String countAndLabel(int count, String label);

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @weightDownSince.
  ///
  /// In en, this message translates to:
  /// **'{weight} down since {date}'**
  String weightDownSince(String weight, String date);

  /// No description provided for @weightUpSince.
  ///
  /// In en, this message translates to:
  /// **'{weight} up since {date}'**
  String weightUpSince(String weight, String date);

  /// No description provided for @weightNoChangeSince.
  ///
  /// In en, this message translates to:
  /// **'No change since {date}'**
  String weightNoChangeSince(String date);

  /// No description provided for @daysEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get daysEveryDay;

  /// No description provided for @daysWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get daysWeekdays;

  /// No description provided for @daysWeekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get daysWeekends;

  /// A day on a chip and in a list of days.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get daySat;

  /// No description provided for @daySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get daySun;

  /// No description provided for @chooseAtLeastOneDay.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day.'**
  String get chooseAtLeastOneDay;

  /// No description provided for @loadFailedContacts.
  ///
  /// In en, this message translates to:
  /// **'Could not load the contacts'**
  String get loadFailedContacts;

  /// No description provided for @loadFailedEmergencyCard.
  ///
  /// In en, this message translates to:
  /// **'Could not load the Emergency card'**
  String get loadFailedEmergencyCard;

  /// No description provided for @loadFailedKit.
  ///
  /// In en, this message translates to:
  /// **'Could not load the emergency kit'**
  String get loadFailedKit;

  /// No description provided for @loadFailedProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load the health profile'**
  String get loadFailedProfile;

  /// No description provided for @loadFailedVets.
  ///
  /// In en, this message translates to:
  /// **'Could not load the vets'**
  String get loadFailedVets;

  /// No description provided for @loadFailedRecord.
  ///
  /// In en, this message translates to:
  /// **'Could not load the record'**
  String get loadFailedRecord;

  /// No description provided for @loadFailedDocuments.
  ///
  /// In en, this message translates to:
  /// **'Could not load the documents'**
  String get loadFailedDocuments;

  /// No description provided for @loadFailedPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not load the photo'**
  String get loadFailedPhoto;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get errSessionEnded;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that. Please sign in again.'**
  String get errNotAllowed;

  /// No description provided for @errInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some of the details are not valid. Please check them and try again.'**
  String get errInvalid;

  /// No description provided for @errPetNotStored.
  ///
  /// In en, this message translates to:
  /// **'This pet is not saved to your account yet, so nothing can be stored for it.'**
  String get errPetNotStored;

  /// No description provided for @errPetGone.
  ///
  /// In en, this message translates to:
  /// **'That pet is no longer in your list.'**
  String get errPetGone;

  /// No description provided for @errItemGone.
  ///
  /// In en, this message translates to:
  /// **'That item no longer exists. Go back and open it again.'**
  String get errItemGone;

  /// No description provided for @errRecordGone.
  ///
  /// In en, this message translates to:
  /// **'That record no longer exists.'**
  String get errRecordGone;

  /// No description provided for @errVetGone.
  ///
  /// In en, this message translates to:
  /// **'That vet no longer exists.'**
  String get errVetGone;

  /// No description provided for @errMedicineGone.
  ///
  /// In en, this message translates to:
  /// **'That medicine no longer exists.'**
  String get errMedicineGone;

  /// No description provided for @errReminderGone.
  ///
  /// In en, this message translates to:
  /// **'That reminder no longer exists.'**
  String get errReminderGone;

  /// No description provided for @errEntryGone.
  ///
  /// In en, this message translates to:
  /// **'That entry no longer exists.'**
  String get errEntryGone;

  /// No description provided for @errFileType.
  ///
  /// In en, this message translates to:
  /// **'Only photos (JPEG, PNG, WebP) and PDF files can be attached.'**
  String get errFileType;

  /// No description provided for @errFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file is empty.'**
  String get errFileEmpty;

  /// No description provided for @errFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is larger than 5 MB. Please choose a smaller one.'**
  String get errFileTooLarge;

  /// No description provided for @errFileGone.
  ///
  /// In en, this message translates to:
  /// **'That file is no longer available.'**
  String get errFileGone;

  /// No description provided for @errFileNotStored.
  ///
  /// In en, this message translates to:
  /// **'The file could not be stored. Please try again.'**
  String get errFileNotStored;

  /// No description provided for @errFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file.'**
  String get errFileUnreadable;

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

  /// No description provided for @errFiles.
  ///
  /// In en, this message translates to:
  /// **'Could not open your files.'**
  String get errFiles;

  /// No description provided for @errPdf.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the PDF. Please try again.'**
  String get errPdf;

  /// No description provided for @errLostCard.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the card. Please try again.'**
  String get errLostCard;

  /// The emergency pill on Home and in the Health header.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergencyButton;

  /// Tooltip of the emergency button.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts'**
  String get emergencyContacts;

  /// No description provided for @emergencyContactsFor.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts for {name}'**
  String emergencyContactsFor(String name);

  /// What a screen reader says for the emergency button while nothing can be called.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts. No phone number saved yet'**
  String get emergencyContactsNoPhone;

  /// No description provided for @emergencyContactsForNoPhone.
  ///
  /// In en, this message translates to:
  /// **'Emergency contacts for {name}. No phone number saved yet'**
  String emergencyContactsForNoPhone(String name);

  /// No description provided for @emergencySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency · {name}'**
  String emergencySheetTitle(String name);

  /// No description provided for @emergencySheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Call or message. You make the call or send the message yourself.'**
  String get emergencySheetSubtitle;

  /// No description provided for @openEmergencyCardOf.
  ///
  /// In en, this message translates to:
  /// **'Open {name}\'s Emergency card'**
  String openEmergencyCardOf(String name);

  /// No description provided for @vetRoleRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular vet'**
  String get vetRoleRegular;

  /// No description provided for @vetRoleEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency vet (24 h)'**
  String get vetRoleEmergency;

  /// No description provided for @emergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get emergencyContact;

  /// No description provided for @addPetsVet.
  ///
  /// In en, this message translates to:
  /// **'Add {name}\'s vet'**
  String addPetsVet(String name);

  /// No description provided for @vetPromptNote.
  ///
  /// In en, this message translates to:
  /// **'Phone and address, ready for an emergency'**
  String get vetPromptNote;

  /// No description provided for @noVetSavedFor.
  ///
  /// In en, this message translates to:
  /// **'No vet saved for {name} yet'**
  String noVetSavedFor(String name);

  /// No description provided for @noVetSavedNote.
  ///
  /// In en, this message translates to:
  /// **'Add the vet\'s phone now, so a call or a message is two taps away when you need it.'**
  String get noVetSavedNote;

  /// No description provided for @useSavedVet.
  ///
  /// In en, this message translates to:
  /// **'Use a vet you already saved'**
  String get useSavedVet;

  /// No description provided for @addNewVet.
  ///
  /// In en, this message translates to:
  /// **'Add a new vet'**
  String get addNewVet;

  /// No description provided for @actionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get actionCall;

  /// No description provided for @actionMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get actionMessage;

  /// No description provided for @actionMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get actionMap;

  /// No description provided for @addPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Add a phone number'**
  String get addPhoneNumber;

  /// No description provided for @couldNotOpenPhone.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone app'**
  String get couldNotOpenPhone;

  /// No description provided for @copyNumber.
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get copyNumber;

  /// No description provided for @couldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open the maps app'**
  String get couldNotOpenMaps;

  /// No description provided for @copyAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy address'**
  String get copyAddress;

  /// No description provided for @messageTo.
  ///
  /// In en, this message translates to:
  /// **'Message to {name}'**
  String messageTo(String name);

  /// No description provided for @whatIsHappening.
  ///
  /// In en, this message translates to:
  /// **'What is happening?'**
  String get whatIsHappening;

  /// No description provided for @messagePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'This is what will be written'**
  String get messagePreviewLabel;

  /// First line of the message to a vet when the owner has no name in the app.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am {pet}\'s owner.'**
  String greetingOwner(String pet);

  /// No description provided for @greetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hello, this is {owner}, {pet}\'s owner.'**
  String greetingNamed(String owner, String pet);

  /// The same greeting while the pet's details could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Hello, I am my pet\'s owner.'**
  String get greetingOwnerNoPet;

  /// No description provided for @greetingNamedNoPet.
  ///
  /// In en, this message translates to:
  /// **'Hello, this is {owner}, my pet\'s owner.'**
  String greetingNamedNoPet(String owner);

  /// A line of the message: the pet, then its kind, breed, age and weight.
  ///
  /// In en, this message translates to:
  /// **'{name}: {facts}'**
  String messagePetLine(String name, String facts);

  /// No description provided for @messageAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies: {list}'**
  String messageAllergies(String list);

  /// No description provided for @messageConditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions: {list}'**
  String messageConditions(String list);

  /// No description provided for @messageMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines: {list}'**
  String messageMedicines(String list);

  /// No description provided for @messageMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Microchip: {number}'**
  String messageMicrochip(String number);

  /// The answer "None known" inside a line of the message.
  ///
  /// In en, this message translates to:
  /// **'none known'**
  String get messageNoneKnown;

  /// A medicine and the vet's instructions for it, inside the message.
  ///
  /// In en, this message translates to:
  /// **'{name}, {instructions}'**
  String messageMedicineLine(String name, String instructions);

  /// No description provided for @messageDetailsNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s details could not be loaded, so only your own words will be sent.'**
  String messageDetailsNotLoaded(String name);

  /// No description provided for @messageDetailsNotLoadedNoPet.
  ///
  /// In en, this message translates to:
  /// **'The pet\'s details could not be loaded, so only your own words will be sent.'**
  String get messageDetailsNotLoadedNoPet;

  /// No description provided for @removeThisLine.
  ///
  /// In en, this message translates to:
  /// **'Remove this line'**
  String get removeThisLine;

  /// No description provided for @putRemovedLinesBack.
  ///
  /// In en, this message translates to:
  /// **'Put the removed lines back'**
  String get putRemovedLinesBack;

  /// No description provided for @openInMessages.
  ///
  /// In en, this message translates to:
  /// **'Open in Messages'**
  String get openInMessages;

  /// No description provided for @openInWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Open in WhatsApp'**
  String get openInWhatsApp;

  /// No description provided for @messageFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent until you press send in that app. In an emergency, calling is faster.'**
  String get messageFinePrint;

  /// No description provided for @couldNotOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp'**
  String get couldNotOpenWhatsApp;

  /// No description provided for @couldNotOpenMessaging.
  ///
  /// In en, this message translates to:
  /// **'Could not open the messaging app'**
  String get couldNotOpenMessaging;

  /// No description provided for @copyMessage.
  ///
  /// In en, this message translates to:
  /// **'Copy message'**
  String get copyMessage;

  /// No description provided for @emergencyCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency card'**
  String get emergencyCardTitle;

  /// No description provided for @shareSummary.
  ///
  /// In en, this message translates to:
  /// **'Share summary'**
  String get shareSummary;

  /// No description provided for @allergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @noneKnown.
  ///
  /// In en, this message translates to:
  /// **'None known'**
  String get noneKnown;

  /// No description provided for @activeMedicines.
  ///
  /// In en, this message translates to:
  /// **'Active medicines'**
  String get activeMedicines;

  /// No description provided for @microchip.
  ///
  /// In en, this message translates to:
  /// **'Microchip'**
  String get microchip;

  /// No description provided for @notChipped.
  ///
  /// In en, this message translates to:
  /// **'Not chipped'**
  String get notChipped;

  /// No description provided for @allergiesAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Allergies and conditions'**
  String get allergiesAndConditions;

  /// No description provided for @nothingSavedTapProfile.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. Tap to fill in the health profile.'**
  String get nothingSavedTapProfile;

  /// No description provided for @petsVets.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s vets'**
  String petsVets(String name);

  /// No description provided for @editHealthProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit health profile'**
  String get editHealthProfile;

  /// No description provided for @emergencyCardFinePrint.
  ///
  /// In en, this message translates to:
  /// **'You make the call or send the message yourself. Pet Companion never contacts anyone on its own, and it does not replace veterinary advice.'**
  String get emergencyCardFinePrint;

  /// No description provided for @emergencyKit.
  ///
  /// In en, this message translates to:
  /// **'Emergency kit'**
  String get emergencyKit;

  /// No description provided for @petsEmergencyKit.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s emergency kit'**
  String petsEmergencyKit(String name);

  /// No description provided for @kitAllReady.
  ///
  /// In en, this message translates to:
  /// **'All {total} ready'**
  String kitAllReady(int total);

  /// No description provided for @kitSomeReady.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} ready'**
  String kitSomeReady(int ready, int total);

  /// No description provided for @kitWhatToHaveReady.
  ///
  /// In en, this message translates to:
  /// **'What to have ready'**
  String get kitWhatToHaveReady;

  /// No description provided for @kitSummaryNote.
  ///
  /// In en, this message translates to:
  /// **'For sirens, a quick move to the protected room, or leaving home in a hurry.'**
  String get kitSummaryNote;

  /// No description provided for @kitCarrierDog.
  ///
  /// In en, this message translates to:
  /// **'Carrier or crate, lead and harness'**
  String get kitCarrierDog;

  /// No description provided for @kitCarrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get kitCarrier;

  /// No description provided for @kitTravelCage.
  ///
  /// In en, this message translates to:
  /// **'Travel cage'**
  String get kitTravelCage;

  /// No description provided for @kitTravelBox.
  ///
  /// In en, this message translates to:
  /// **'Travel box'**
  String get kitTravelBox;

  /// No description provided for @kitCarrierOrCage.
  ///
  /// In en, this message translates to:
  /// **'Carrier or travel cage'**
  String get kitCarrierOrCage;

  /// No description provided for @kitCarrierNote.
  ///
  /// In en, this message translates to:
  /// **'Within reach, near the door.'**
  String get kitCarrierNote;

  /// No description provided for @kitFoodWater.
  ///
  /// In en, this message translates to:
  /// **'Food and water for three days'**
  String get kitFoodWater;

  /// No description provided for @kitFoodWaterNote.
  ///
  /// In en, this message translates to:
  /// **'With a bowl, in one bag.'**
  String get kitFoodWaterNote;

  /// No description provided for @kitDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get kitDocuments;

  /// No description provided for @kitDocumentsNoteDog.
  ///
  /// In en, this message translates to:
  /// **'Vaccination booklet and licence, on paper or as photos.'**
  String get kitDocumentsNoteDog;

  /// No description provided for @kitDocumentsNote.
  ///
  /// In en, this message translates to:
  /// **'Vaccination booklet and vet papers, on paper or as photos.'**
  String get kitDocumentsNote;

  /// No description provided for @kitMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Microchip details up to date'**
  String get kitMicrochip;

  /// No description provided for @kitMicrochipNumber.
  ///
  /// In en, this message translates to:
  /// **'{number} · your phone number in the chip registry is current.'**
  String kitMicrochipNumber(String number);

  /// No description provided for @kitMicrochipNotChipped.
  ///
  /// In en, this message translates to:
  /// **'Marked as not chipped in the health profile.'**
  String get kitMicrochipNotChipped;

  /// No description provided for @kitMicrochipNone.
  ///
  /// In en, this message translates to:
  /// **'No microchip number saved yet.'**
  String get kitMicrochipNone;

  /// No description provided for @kitMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get kitMedicines;

  /// No description provided for @kitMedicinesNote.
  ///
  /// In en, this message translates to:
  /// **'{names} · a spare supply in the kit.'**
  String kitMedicinesNote(String names);

  /// No description provided for @kitShelterPlan.
  ///
  /// In en, this message translates to:
  /// **'A plan for the protected room'**
  String get kitShelterPlan;

  /// No description provided for @kitShelterPlanNote.
  ///
  /// In en, this message translates to:
  /// **'Who takes {name}, and where the carrier is.'**
  String kitShelterPlanNote(String name);

  /// No description provided for @kitDocumentsSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document saved here} other{{count} documents saved here}}'**
  String kitDocumentsSaved(int count);

  /// No description provided for @healthProfile.
  ///
  /// In en, this message translates to:
  /// **'Health profile'**
  String get healthProfile;

  /// When the owner ticked an item of the kit.
  ///
  /// In en, this message translates to:
  /// **'Ticked {date}'**
  String kitTicked(String date);

  /// No description provided for @kitOurPlan.
  ///
  /// In en, this message translates to:
  /// **'Our plan (optional)'**
  String get kitOurPlan;

  /// No description provided for @kitFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Your own list, not official guidance. During an emergency follow the Home Front Command\'s instructions.'**
  String get kitFinePrint;

  /// No description provided for @petsHealthProfile.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s health profile'**
  String petsHealthProfile(String name);

  /// No description provided for @identification.
  ///
  /// In en, this message translates to:
  /// **'Identification'**
  String get identification;

  /// No description provided for @microchipNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Microchip number (optional)'**
  String get microchipNumberOptional;

  /// No description provided for @validNumberTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the number under {count} characters.'**
  String validNumberTooLong(int count);

  /// No description provided for @knownAllergies.
  ///
  /// In en, this message translates to:
  /// **'Known allergies, one per line'**
  String get knownAllergies;

  /// No description provided for @medicalConditions.
  ///
  /// In en, this message translates to:
  /// **'Medical conditions'**
  String get medicalConditions;

  /// No description provided for @knownConditions.
  ///
  /// In en, this message translates to:
  /// **'Known conditions, one per line'**
  String get knownConditions;

  /// No description provided for @validKeepShorter.
  ///
  /// In en, this message translates to:
  /// **'Please keep this shorter.'**
  String get validKeepShorter;

  /// No description provided for @emergencyContactHeading.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact (someone who can help)'**
  String get emergencyContactHeading;

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @validPhone.
  ///
  /// In en, this message translates to:
  /// **'That does not look like a phone number.'**
  String get validPhone;

  /// No description provided for @anythingElseForVet.
  ///
  /// In en, this message translates to:
  /// **'Anything else a vet should know'**
  String get anythingElseForVet;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Everything here is optional. It fills the Emergency card and the message to the vet.'**
  String get profileFinePrint;

  /// No description provided for @vet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get vet;

  /// No description provided for @addVet.
  ///
  /// In en, this message translates to:
  /// **'Add a vet'**
  String get addVet;

  /// No description provided for @editVet.
  ///
  /// In en, this message translates to:
  /// **'Edit vet'**
  String get editVet;

  /// No description provided for @deleteVet.
  ///
  /// In en, this message translates to:
  /// **'Delete vet'**
  String get deleteVet;

  /// No description provided for @deleteVetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this vet?'**
  String get deleteVetTitle;

  /// No description provided for @deleteVetMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from your account and from every pet that uses it.'**
  String deleteVetMessage(String name);

  /// No description provided for @whoIsIt.
  ///
  /// In en, this message translates to:
  /// **'Who is it?'**
  String get whoIsIt;

  /// No description provided for @vetOrClinicName.
  ///
  /// In en, this message translates to:
  /// **'Vet or clinic name'**
  String get vetOrClinicName;

  /// No description provided for @validVetName.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of the vet or the clinic.'**
  String get validVetName;

  /// No description provided for @validNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the name under {count} characters.'**
  String validNameTooLong(int count);

  /// No description provided for @howToReachThem.
  ///
  /// In en, this message translates to:
  /// **'How to reach them'**
  String get howToReachThem;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get fieldPhone;

  /// No description provided for @validWhatsAppNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the number that is on WhatsApp.'**
  String get validWhatsAppNumber;

  /// No description provided for @validWhatsAppCountryCode.
  ///
  /// In en, this message translates to:
  /// **'For WhatsApp, start with the country code, like {example}.'**
  String validWhatsAppCountryCode(String example);

  /// No description provided for @onWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'This number is on WhatsApp'**
  String get onWhatsApp;

  /// No description provided for @onWhatsAppNote.
  ///
  /// In en, this message translates to:
  /// **'Adds a WhatsApp button next to the text message. Needs the country code, like {example}.'**
  String onWhatsAppNote(String example);

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get openingHours;

  /// No description provided for @openingHoursOptional.
  ///
  /// In en, this message translates to:
  /// **'Opening hours (optional)'**
  String get openingHoursOptional;

  /// No description provided for @saveVet.
  ///
  /// In en, this message translates to:
  /// **'Save vet'**
  String get saveVet;

  /// No description provided for @vetFormFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Saved once for your account, so your other pets can use the same vet.'**
  String get vetFormFinePrint;

  /// No description provided for @chooseRegularVet.
  ///
  /// In en, this message translates to:
  /// **'Choose the regular vet'**
  String get chooseRegularVet;

  /// No description provided for @chooseEmergencyVet.
  ///
  /// In en, this message translates to:
  /// **'Choose the emergency vet'**
  String get chooseEmergencyVet;

  /// No description provided for @vetPickerNote.
  ///
  /// In en, this message translates to:
  /// **'Vets you saved before can be used for any of your pets.'**
  String get vetPickerNote;

  /// No description provided for @removeVetFromPet.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this pet'**
  String removeVetFromPet(String name);

  /// No description provided for @noPhoneYet.
  ///
  /// In en, this message translates to:
  /// **'No phone number yet'**
  String get noPhoneYet;

  /// Tag on the vet the pet already uses.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get inUse;

  /// Button: use this saved vet for the pet.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get useVet;

  /// No description provided for @addEmergencyVet.
  ///
  /// In en, this message translates to:
  /// **'Add an emergency vet'**
  String get addEmergencyVet;

  /// No description provided for @emergencyVetPromptNote.
  ///
  /// In en, this message translates to:
  /// **'A 24-hour clinic for nights and weekends'**
  String get emergencyVetPromptNote;

  /// No description provided for @vetsFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Vets are saved once for your account, so your other pets can use the same ones.'**
  String get vetsFinePrint;

  /// Tooltip of the pencil beside a vet.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String editNamed(String name);

  /// Button and title of the page that builds a card for a lost pet.
  ///
  /// In en, this message translates to:
  /// **'{name} is lost'**
  String petIsLost(String name);

  /// No description provided for @lostCardSection.
  ///
  /// In en, this message translates to:
  /// **'What goes on the card'**
  String get lostCardSection;

  /// No description provided for @lostNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No photo on the card'**
  String get lostNoPhoto;

  /// No description provided for @lostPetsPhoto.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s photo'**
  String lostPetsPhoto(String name);

  /// No description provided for @lostPhotoChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen for this card only'**
  String get lostPhotoChosen;

  /// No description provided for @lostPhotoFromProfile.
  ///
  /// In en, this message translates to:
  /// **'From the pet profile'**
  String get lostPhotoFromProfile;

  /// No description provided for @lostPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'A recent, clear photo helps most'**
  String get lostPhotoHint;

  /// No description provided for @lostDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get lostDescription;

  /// No description provided for @lostDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Colour, size, collar, how {name} behaves with strangers'**
  String lostDescriptionHint(String name);

  /// No description provided for @lostArea.
  ///
  /// In en, this message translates to:
  /// **'Last seen: area'**
  String get lostArea;

  /// No description provided for @lostAreaExact.
  ///
  /// In en, this message translates to:
  /// **'This looks like an exact address. A neighbourhood or a street corner is safer.'**
  String get lostAreaExact;

  /// No description provided for @lostAreaHint.
  ///
  /// In en, this message translates to:
  /// **'A neighbourhood or a street corner is enough. Not your home address.'**
  String get lostAreaHint;

  /// No description provided for @lostWhen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: when'**
  String get lostWhen;

  /// Title of the date picker.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lostWhenHelp;

  /// No description provided for @lostTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Around what time?'**
  String get lostTimeHelp;

  /// No description provided for @lostYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Your phone number'**
  String get lostYourPhone;

  /// No description provided for @lostExtra.
  ///
  /// In en, this message translates to:
  /// **'Anything else (optional)'**
  String get lostExtra;

  /// No description provided for @lostExtraHint.
  ///
  /// In en, this message translates to:
  /// **'For example: needs a daily medicine'**
  String get lostExtraHint;

  /// No description provided for @lostLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language of the card'**
  String get lostLanguage;

  /// No description provided for @lostPreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'This is what will be shared'**
  String get lostPreviewLabel;

  /// No description provided for @lostShowPhone.
  ///
  /// In en, this message translates to:
  /// **'Show this phone number on the card: {phone}'**
  String lostShowPhone(String phone);

  /// No description provided for @lostAddPhoneFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your phone number, then confirm it here.'**
  String get lostAddPhoneFirst;

  /// No description provided for @shareAsImage.
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get shareAsImage;

  /// No description provided for @shareAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Share as PDF to print'**
  String get shareAsPdf;

  /// No description provided for @petIsBackHome.
  ///
  /// In en, this message translates to:
  /// **'{name} is back home'**
  String petIsBackHome(String name);

  /// No description provided for @lostGoodNews.
  ///
  /// In en, this message translates to:
  /// **'Good news. The card is put away.'**
  String get lostGoodNews;

  /// No description provided for @lostFinePrint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is posted by the app. You choose where the card goes. The microchip number and your vet are never on it.'**
  String get lostFinePrint;

  /// No description provided for @lostCardHeading.
  ///
  /// In en, this message translates to:
  /// **'Looking for {name}'**
  String lostCardHeading(String name);

  /// No description provided for @lostCardArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get lostCardArea;

  /// No description provided for @lostCardWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get lostCardWhen;

  /// No description provided for @lostCardMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Microchip'**
  String get lostCardMicrochip;

  /// No description provided for @lostCardMicrochipped.
  ///
  /// In en, this message translates to:
  /// **'Microchipped'**
  String get lostCardMicrochipped;

  /// Above the phone number on the card; speaks to the neighbours who read it.
  ///
  /// In en, this message translates to:
  /// **'Seen {name}? Please call'**
  String lostCardCall(String name);

  /// No description provided for @lostCardFooter.
  ///
  /// In en, this message translates to:
  /// **'Made with Pet Companion'**
  String get lostCardFooter;

  /// No description provided for @lostCardAround.
  ///
  /// In en, this message translates to:
  /// **'{date}, around {time}'**
  String lostCardAround(String date, String time);

  /// No description provided for @overviewNoCareDue.
  ///
  /// In en, this message translates to:
  /// **'No scheduled care due'**
  String get overviewNoCareDue;

  /// No description provided for @overviewLastRecord.
  ///
  /// In en, this message translates to:
  /// **'Last record {date}'**
  String overviewLastRecord(String date);

  /// No description provided for @comingUp.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get comingUp;

  /// Button beside a medicine reminder: record the dose.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordDose;

  /// No description provided for @remindersNeedReview.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reminder needs review} other{{count} reminders need review}}'**
  String remindersNeedReview(int count);

  /// No description provided for @addRecord.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get addRecord;

  /// No description provided for @medicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get medicines;

  /// Tag on the Medicines card: how many medicines are being given now.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String medicinesActive(int count);

  /// No description provided for @noDoseYet.
  ///
  /// In en, this message translates to:
  /// **'No dose recorded yet'**
  String get noDoseYet;

  /// No description provided for @lastDoseToday.
  ///
  /// In en, this message translates to:
  /// **'Last recorded dose: today {time}'**
  String lastDoseToday(String time);

  /// No description provided for @lastDoseYesterday.
  ///
  /// In en, this message translates to:
  /// **'Last recorded dose: yesterday {time}'**
  String lastDoseYesterday(String time);

  /// No description provided for @lastDoseOn.
  ///
  /// In en, this message translates to:
  /// **'Last recorded dose: {day} {time}'**
  String lastDoseOn(String day, String time);

  /// No description provided for @smallWeightChart.
  ///
  /// In en, this message translates to:
  /// **'Small weight chart'**
  String get smallWeightChart;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical records'**
  String get medicalRecords;

  /// No description provided for @vaccinations.
  ///
  /// In en, this message translates to:
  /// **'Vaccinations'**
  String get vaccinations;

  /// No description provided for @vetVisits.
  ///
  /// In en, this message translates to:
  /// **'Vet visits'**
  String get vetVisits;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @startWithOneThing.
  ///
  /// In en, this message translates to:
  /// **'Start with one thing'**
  String get startWithOneThing;

  /// No description provided for @startNote.
  ///
  /// In en, this message translates to:
  /// **'No need to enter {name}\'s whole history. Add things as they come up.'**
  String startNote(String name);

  /// No description provided for @startDocument.
  ///
  /// In en, this message translates to:
  /// **'Add a document you already have'**
  String get startDocument;

  /// No description provided for @startDocumentNote.
  ///
  /// In en, this message translates to:
  /// **'A photo or PDF of the vaccination booklet or a vet letter'**
  String get startDocumentNote;

  /// No description provided for @startAppointment.
  ///
  /// In en, this message translates to:
  /// **'Enter an upcoming appointment'**
  String get startAppointment;

  /// No description provided for @startAppointmentNote.
  ///
  /// In en, this message translates to:
  /// **'So it shows under Coming up'**
  String get startAppointmentNote;

  /// No description provided for @startMedicine.
  ///
  /// In en, this message translates to:
  /// **'Create a medicine reminder'**
  String get startMedicine;

  /// No description provided for @startMedicineNote.
  ///
  /// In en, this message translates to:
  /// **'With the vet\'s instructions and the times'**
  String get startMedicineNote;

  /// No description provided for @addToSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add to the schedule'**
  String get addToSchedule;

  /// No description provided for @addAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment or due date'**
  String get addAppointment;

  /// No description provided for @addAppointmentNote.
  ///
  /// In en, this message translates to:
  /// **'A vet visit, a vaccination, a treatment'**
  String get addAppointmentNote;

  /// No description provided for @medicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get medicine;

  /// No description provided for @addMedicineNote.
  ///
  /// In en, this message translates to:
  /// **'The vet\'s instructions and the reminder times'**
  String get addMedicineNote;

  /// No description provided for @routine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get routine;

  /// No description provided for @addRoutineNote.
  ///
  /// In en, this message translates to:
  /// **'Feeding, walks, grooming, cleaning'**
  String get addRoutineNote;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled yet'**
  String get scheduleEmpty;

  /// No description provided for @scheduleEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Appointments, medicine reminders and daily routines for {name} will show here.'**
  String scheduleEmptyNote(String name);

  /// No description provided for @nothingDueToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing is due today.'**
  String get nothingDueToday;

  /// No description provided for @allAnsweredToday.
  ///
  /// In en, this message translates to:
  /// **'Everything for today is answered.'**
  String get allAnsweredToday;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @noUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No appointments or due dates ahead.'**
  String get noUpcoming;

  /// No description provided for @needsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get needsReview;

  /// No description provided for @needsReviewNote.
  ///
  /// In en, this message translates to:
  /// **'No answer was recorded for these. Nothing is counted as missed; a medicine reminder leaves this list after {days} days.'**
  String needsReviewNote(int days);

  /// No description provided for @medicinesAndRoutines.
  ///
  /// In en, this message translates to:
  /// **'Medicines and routines'**
  String get medicinesAndRoutines;

  /// What a screen reader says for the tick box of a routine.
  ///
  /// In en, this message translates to:
  /// **'Mark {title} as done'**
  String markNamedAsDone(String title);

  /// When a medicine reminder is due today.
  ///
  /// In en, this message translates to:
  /// **'due {time}'**
  String dueAt(String time);

  /// No description provided for @doneTodayCount.
  ///
  /// In en, this message translates to:
  /// **'Done today · {count}'**
  String doneTodayCount(int count);

  /// One answered reminder in "Done today": a medicine given at a time.
  ///
  /// In en, this message translates to:
  /// **'{title} given {time}'**
  String doneLineGivenAt(String title, String time);

  /// No description provided for @doneLineGiven.
  ///
  /// In en, this message translates to:
  /// **'{title} given'**
  String doneLineGiven(String title);

  /// No description provided for @doneLineNotGiven.
  ///
  /// In en, this message translates to:
  /// **'{title} not given'**
  String doneLineNotGiven(String title);

  /// No description provided for @doneLineNotSure.
  ///
  /// In en, this message translates to:
  /// **'{title} not sure'**
  String doneLineNotSure(String title);

  /// A routine ticked today, with its time.
  ///
  /// In en, this message translates to:
  /// **'{title} {time}'**
  String doneLineAt(String title, String time);

  /// No description provided for @doneLineSkipped.
  ///
  /// In en, this message translates to:
  /// **'{title} skipped'**
  String doneLineSkipped(String title);

  /// Link: removes the answer, so the reminder is open again.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @dateGivenByVet.
  ///
  /// In en, this message translates to:
  /// **'date given by the vet'**
  String get dateGivenByVet;

  /// Title of the planned item made from a "next due" date.
  ///
  /// In en, this message translates to:
  /// **'{title} due'**
  String followUpDue(String title);

  /// No description provided for @noAnswerRecorded.
  ///
  /// In en, this message translates to:
  /// **'no answer recorded'**
  String get noAnswerRecorded;

  /// No description provided for @notMarkedAsDone.
  ///
  /// In en, this message translates to:
  /// **'not marked as done'**
  String get notMarkedAsDone;

  /// A dose was given.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get given;

  /// No description provided for @givenAt.
  ///
  /// In en, this message translates to:
  /// **'Given {time}'**
  String givenAt(String time);

  /// No description provided for @notGiven.
  ///
  /// In en, this message translates to:
  /// **'Not given'**
  String get notGiven;

  /// No description provided for @notSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSure;

  /// No description provided for @movedToHistory.
  ///
  /// In en, this message translates to:
  /// **'Moved to the History.'**
  String get movedToHistory;

  /// Button: the planned appointment took place.
  ///
  /// In en, this message translates to:
  /// **'It happened'**
  String get itHappened;

  /// No description provided for @changeOrDelete.
  ///
  /// In en, this message translates to:
  /// **'Change or delete'**
  String get changeOrDelete;

  /// No description provided for @onlyWhenNeeded.
  ///
  /// In en, this message translates to:
  /// **'Only when needed'**
  String get onlyWhenNeeded;

  /// No description provided for @medicineEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String medicineEnded(String date);

  /// No description provided for @medicineStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String medicineStarts(String date);

  /// No description provided for @medicineNotActive.
  ///
  /// In en, this message translates to:
  /// **'Not active'**
  String get medicineNotActive;

  /// Tag on a routine that is switched off.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @newMedicine.
  ///
  /// In en, this message translates to:
  /// **'New medicine'**
  String get newMedicine;

  /// No description provided for @editMedicine.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get editMedicine;

  /// No description provided for @deleteMedicine.
  ///
  /// In en, this message translates to:
  /// **'Delete medicine'**
  String get deleteMedicine;

  /// No description provided for @deleteMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this medicine?'**
  String get deleteMedicineTitle;

  /// No description provided for @deleteMedicineMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\", its reminders and its dose log will be removed. This cannot be undone.'**
  String deleteMedicineMessage(String name);

  /// No description provided for @fromVetInstructions.
  ///
  /// In en, this message translates to:
  /// **'From the vet\'s instructions'**
  String get fromVetInstructions;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @validMedicineName.
  ///
  /// In en, this message translates to:
  /// **'Enter the name of the medicine.'**
  String get validMedicineName;

  /// No description provided for @strengthOptional.
  ///
  /// In en, this message translates to:
  /// **'Strength (optional)'**
  String get strengthOptional;

  /// No description provided for @strengthHint.
  ///
  /// In en, this message translates to:
  /// **'50 mg'**
  String get strengthHint;

  /// No description provided for @doseOptional.
  ///
  /// In en, this message translates to:
  /// **'Dose (optional)'**
  String get doseOptional;

  /// No description provided for @doseHint.
  ///
  /// In en, this message translates to:
  /// **'1 tablet'**
  String get doseHint;

  /// No description provided for @howItIsGiven.
  ///
  /// In en, this message translates to:
  /// **'How it is given'**
  String get howItIsGiven;

  /// No description provided for @routeByMouth.
  ///
  /// In en, this message translates to:
  /// **'By mouth'**
  String get routeByMouth;

  /// No description provided for @routeOnSkin.
  ///
  /// In en, this message translates to:
  /// **'On the skin'**
  String get routeOnSkin;

  /// No description provided for @routeInEye.
  ///
  /// In en, this message translates to:
  /// **'In the eye'**
  String get routeInEye;

  /// No description provided for @routeInEar.
  ///
  /// In en, this message translates to:
  /// **'In the ear'**
  String get routeInEar;

  /// No description provided for @routeInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get routeInjection;

  /// No description provided for @routeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get routeOther;

  /// The dose and how it is given, as the owner entered them: 1 tablet by mouth.
  ///
  /// In en, this message translates to:
  /// **'{dose} {route}'**
  String medicineDoseAndRoute(String dose, String route);

  /// How a medicine is given and how often: 1 tablet by mouth, twice a day.
  ///
  /// In en, this message translates to:
  /// **'{how}, {often}'**
  String medicineHowAndOften(String how, String often);

  /// No description provided for @howOftenOptional.
  ///
  /// In en, this message translates to:
  /// **'How often (optional)'**
  String get howOftenOptional;

  /// No description provided for @howOftenHint.
  ///
  /// In en, this message translates to:
  /// **'Twice a day, with food'**
  String get howOftenHint;

  /// No description provided for @fieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get fieldStart;

  /// No description provided for @endOptional.
  ///
  /// In en, this message translates to:
  /// **'End (optional)'**
  String get endOptional;

  /// No description provided for @noEnd.
  ///
  /// In en, this message translates to:
  /// **'No end'**
  String get noEnd;

  /// No description provided for @firstDayOfMedicine.
  ///
  /// In en, this message translates to:
  /// **'First day of the medicine'**
  String get firstDayOfMedicine;

  /// No description provided for @lastDayOfMedicine.
  ///
  /// In en, this message translates to:
  /// **'Last day of the medicine'**
  String get lastDayOfMedicine;

  /// No description provided for @prescribedByOptional.
  ///
  /// In en, this message translates to:
  /// **'Prescribed by (optional)'**
  String get prescribedByOptional;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderTime;

  /// No description provided for @addATime.
  ///
  /// In en, this message translates to:
  /// **'Add a time'**
  String get addATime;

  /// No description provided for @medicineNoTimesNote.
  ///
  /// In en, this message translates to:
  /// **'No reminder times: a medicine given only when needed.'**
  String get medicineNoTimesNote;

  /// No description provided for @medicineReminderNote.
  ///
  /// In en, this message translates to:
  /// **'A reminder nobody answers waits under Needs review. It is never counted as missed.'**
  String get medicineReminderNote;

  /// No description provided for @validLastBeforeFirst.
  ///
  /// In en, this message translates to:
  /// **'The last day should not be before the first day.'**
  String get validLastBeforeFirst;

  /// No description provided for @validReminderDays.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one day for the reminders.'**
  String get validReminderDays;

  /// No description provided for @saveMedicine.
  ///
  /// In en, this message translates to:
  /// **'Save medicine'**
  String get saveMedicine;

  /// No description provided for @medicineFinePrint.
  ///
  /// In en, this message translates to:
  /// **'The app stores what you enter. It never suggests a dose.'**
  String get medicineFinePrint;

  /// No description provided for @doseLog.
  ///
  /// In en, this message translates to:
  /// **'Dose log'**
  String get doseLog;

  /// No description provided for @noDoseRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No dose recorded yet.'**
  String get noDoseRecordedYet;

  /// In the dose log: the reminder the dose answered.
  ///
  /// In en, this message translates to:
  /// **'reminder {time}'**
  String doseLogReminder(String time);

  /// No description provided for @doseLogWhenNeeded.
  ///
  /// In en, this message translates to:
  /// **'when needed'**
  String get doseLogWhenNeeded;

  /// No description provided for @doseLoggedBy.
  ///
  /// In en, this message translates to:
  /// **'logged by {name}'**
  String doseLoggedBy(String name);

  /// No description provided for @doseLoggedByYou.
  ///
  /// In en, this message translates to:
  /// **'logged by you'**
  String get doseLoggedByYou;

  /// No description provided for @doseGivenWhenNeeded.
  ///
  /// In en, this message translates to:
  /// **'Given when needed · {name}'**
  String doseGivenWhenNeeded(String name);

  /// No description provided for @reminderForToday.
  ///
  /// In en, this message translates to:
  /// **'Reminder for today · {time}'**
  String reminderForToday(String time);

  /// No description provided for @reminderForYesterday.
  ///
  /// In en, this message translates to:
  /// **'Reminder for yesterday · {time}'**
  String reminderForYesterday(String time);

  /// No description provided for @reminderForDay.
  ///
  /// In en, this message translates to:
  /// **'Reminder for {day} · {time}'**
  String reminderForDay(String day, String time);

  /// No description provided for @vetsInstructions.
  ///
  /// In en, this message translates to:
  /// **'Vet\'s instructions: {text}.'**
  String vetsInstructions(String text);

  /// No description provided for @givenNowAt.
  ///
  /// In en, this message translates to:
  /// **'Given now · {time}'**
  String givenNowAt(String time);

  /// No description provided for @givenAtAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Given at another time'**
  String get givenAtAnotherTime;

  /// No description provided for @whenWasItGiven.
  ///
  /// In en, this message translates to:
  /// **'When was it given?'**
  String get whenWasItGiven;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @doseNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: hidden in cheese'**
  String get doseNoteHint;

  /// No description provided for @validTimeAhead.
  ///
  /// In en, this message translates to:
  /// **'That time is still ahead. Record the dose once it is given.'**
  String get validTimeAhead;

  /// No description provided for @doseRecordedGiven.
  ///
  /// In en, this message translates to:
  /// **'Dose recorded as given.'**
  String get doseRecordedGiven;

  /// No description provided for @doseRecordedNotGiven.
  ///
  /// In en, this message translates to:
  /// **'Recorded as not given.'**
  String get doseRecordedNotGiven;

  /// No description provided for @doseRecordedNotSure.
  ///
  /// In en, this message translates to:
  /// **'Recorded as not sure.'**
  String get doseRecordedNotSure;

  /// No description provided for @doseFinePrintNamed.
  ///
  /// In en, this message translates to:
  /// **'Saved as logged by {name}, with the time. If you are unsure about a dose, ask your vet.'**
  String doseFinePrintNamed(String name);

  /// No description provided for @doseFinePrintYou.
  ///
  /// In en, this message translates to:
  /// **'Saved as logged by you, with the time. If you are unsure about a dose, ask your vet.'**
  String get doseFinePrintYou;

  /// No description provided for @newRoutine.
  ///
  /// In en, this message translates to:
  /// **'New routine'**
  String get newRoutine;

  /// No description provided for @editRoutine.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get editRoutine;

  /// No description provided for @deleteRoutine.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get deleteRoutine;

  /// No description provided for @deleteRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this routine?'**
  String get deleteRoutineTitle;

  /// No description provided for @deleteRoutineMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" leaves the Schedule. What was already ticked stays in the log.'**
  String deleteRoutineMessage(String title);

  /// No description provided for @whatKindOfRoutine.
  ///
  /// In en, this message translates to:
  /// **'What kind of routine?'**
  String get whatKindOfRoutine;

  /// No description provided for @careFeeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get careFeeding;

  /// No description provided for @careWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get careWalk;

  /// No description provided for @careGrooming.
  ///
  /// In en, this message translates to:
  /// **'Grooming'**
  String get careGrooming;

  /// No description provided for @careCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get careCleaning;

  /// No description provided for @careLitterCleaning.
  ///
  /// In en, this message translates to:
  /// **'Litter box cleaning'**
  String get careLitterCleaning;

  /// No description provided for @careLitterChange.
  ///
  /// In en, this message translates to:
  /// **'Litter change'**
  String get careLitterChange;

  /// No description provided for @careCageCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cage cleaning'**
  String get careCageCleaning;

  /// No description provided for @careEnclosureCleaning.
  ///
  /// In en, this message translates to:
  /// **'Enclosure cleaning'**
  String get careEnclosureCleaning;

  /// No description provided for @careOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get careOther;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @routineTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Breakfast, evening walk...'**
  String get routineTitleHint;

  /// No description provided for @validRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Give the routine a title.'**
  String get validRoutineTitle;

  /// No description provided for @validTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the title under {count} characters.'**
  String validTitleTooLong(int count);

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @timeOfRoutine.
  ///
  /// In en, this message translates to:
  /// **'Time of the routine'**
  String get timeOfRoutine;

  /// No description provided for @fieldDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get fieldDays;

  /// No description provided for @showInSchedule.
  ///
  /// In en, this message translates to:
  /// **'Show it in the Schedule'**
  String get showInSchedule;

  /// No description provided for @routineOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get routineOn;

  /// No description provided for @routinePausedNote.
  ///
  /// In en, this message translates to:
  /// **'Paused: kept here, but not due'**
  String get routinePausedNote;

  /// No description provided for @saveRoutine.
  ///
  /// In en, this message translates to:
  /// **'Save routine'**
  String get saveRoutine;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get historyEmpty;

  /// No description provided for @historyEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Vet visits, vaccinations, treatments and documents will build {name}\'s history here.'**
  String historyEmptyNote(String name);

  /// No description provided for @addARecord.
  ///
  /// In en, this message translates to:
  /// **'Add a record'**
  String get addARecord;

  /// No description provided for @searchRecords.
  ///
  /// In en, this message translates to:
  /// **'Search {name}\'s records'**
  String searchRecords(String name);

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear the search'**
  String get clearSearch;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @kindCheckup.
  ///
  /// In en, this message translates to:
  /// **'Vet visit'**
  String get kindCheckup;

  /// No description provided for @kindVaccination.
  ///
  /// In en, this message translates to:
  /// **'Vaccination'**
  String get kindVaccination;

  /// No description provided for @kindPreventive.
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get kindPreventive;

  /// No description provided for @kindProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get kindProcedure;

  /// No description provided for @kindMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get kindMedicine;

  /// No description provided for @kindDocument.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get kindDocument;

  /// No description provided for @kindOther.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get kindOther;

  /// Filter chip: every preventive treatment.
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get kindsPreventive;

  /// No description provided for @kindsProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedures'**
  String get kindsProcedure;

  /// Filter chip: every medicine record.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get kindsMedicine;

  /// No description provided for @recordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}}'**
  String recordsCount(int count);

  /// No description provided for @recordsShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} records'**
  String recordsShown(int shown, int total);

  /// No description provided for @nothingMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get nothingMatches;

  /// No description provided for @nothingMatchesNote.
  ///
  /// In en, this message translates to:
  /// **'No record fits this search and filter.'**
  String get nothingMatchesNote;

  /// No description provided for @showAllRecords.
  ///
  /// In en, this message translates to:
  /// **'Show all records'**
  String get showAllRecords;

  /// No description provided for @nextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due {date}'**
  String nextDue(String date);

  /// What a screen reader says for the cost tag.
  ///
  /// In en, this message translates to:
  /// **'Cost {amount}'**
  String costSemantics(String amount);

  /// No description provided for @attachmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String attachmentsCount(int count);

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @newRecord.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get newRecord;

  /// No description provided for @newAppointment.
  ///
  /// In en, this message translates to:
  /// **'New appointment'**
  String get newAppointment;

  /// No description provided for @editRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecord;

  /// No description provided for @deleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get deleteRecord;

  /// No description provided for @deleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get deleteRecordTitle;

  /// No description provided for @deleteRecordMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its attachments will be removed. This cannot be undone.'**
  String deleteRecordMessage(String title);

  /// No description provided for @whatKindOfRecord.
  ///
  /// In en, this message translates to:
  /// **'What kind of record?'**
  String get whatKindOfRecord;

  /// No description provided for @validRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Give the record a title.'**
  String get validRecordTitle;

  /// No description provided for @productOptional.
  ///
  /// In en, this message translates to:
  /// **'Product (optional)'**
  String get productOptional;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned for'**
  String get plannedFor;

  /// No description provided for @dateGiven.
  ///
  /// In en, this message translates to:
  /// **'Date given'**
  String get dateGiven;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @recordAheadNote.
  ///
  /// In en, this message translates to:
  /// **'This date is still ahead, so it is saved as an upcoming item in the Schedule.'**
  String get recordAheadNote;

  /// No description provided for @nextDueOptional.
  ///
  /// In en, this message translates to:
  /// **'Next due (optional)'**
  String get nextDueOptional;

  /// No description provided for @nextDueHelp.
  ///
  /// In en, this message translates to:
  /// **'Next due date, from your vet'**
  String get nextDueHelp;

  /// No description provided for @nextDueNote.
  ///
  /// In en, this message translates to:
  /// **'Enter the date your vet gave you. It will appear in the Schedule.'**
  String get nextDueNote;

  /// No description provided for @nextDueFromVet.
  ///
  /// In en, this message translates to:
  /// **'Next due (from the vet)'**
  String get nextDueFromVet;

  /// No description provided for @validNextDueAfter.
  ///
  /// In en, this message translates to:
  /// **'The next due date should be after the date given.'**
  String get validNextDueAfter;

  /// No description provided for @vetOrClinicOptional.
  ///
  /// In en, this message translates to:
  /// **'Vet or clinic (optional)'**
  String get vetOrClinicOptional;

  /// No description provided for @vetOrClinic.
  ///
  /// In en, this message translates to:
  /// **'Vet or clinic'**
  String get vetOrClinic;

  /// No description provided for @costOptional.
  ///
  /// In en, this message translates to:
  /// **'Cost (optional)'**
  String get costOptional;

  /// No description provided for @expectedCostOptional.
  ///
  /// In en, this message translates to:
  /// **'Expected cost (optional)'**
  String get expectedCostOptional;

  /// No description provided for @cost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get cost;

  /// No description provided for @expectedCost.
  ///
  /// In en, this message translates to:
  /// **'Expected cost'**
  String get expectedCost;

  /// No description provided for @validAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount, like 120 or 89.90.'**
  String get validAmount;

  /// No description provided for @costNotePaid.
  ///
  /// In en, this message translates to:
  /// **'What you paid. It stays with your records and is left out of anything you share with a vet.'**
  String get costNotePaid;

  /// No description provided for @costNoteExpected.
  ///
  /// In en, this message translates to:
  /// **'What you expect to pay. It stays with your records and is left out of anything you share with a vet.'**
  String get costNoteExpected;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Anything worth remembering'**
  String get notesHint;

  /// No description provided for @validNotesTooLong.
  ///
  /// In en, this message translates to:
  /// **'Please keep the notes shorter.'**
  String get validNotesTooLong;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @addPhotoOrPdf.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or PDF'**
  String get addPhotoOrPdf;

  /// No description provided for @saveRecord.
  ///
  /// In en, this message translates to:
  /// **'Save record'**
  String get saveRecord;

  /// {problem} is a whole sentence: why the file was refused.
  ///
  /// In en, this message translates to:
  /// **'The record is saved, but a file was not attached. {problem}'**
  String savedButFileNotAttached(String problem);

  /// Shown when a record was saved but its planned follow-up was not. {problem} is a whole sentence: why.
  ///
  /// In en, this message translates to:
  /// **'The record is saved, but its next due date was not added to the schedule. {problem} Saving again tries once more.'**
  String savedButNextDueNotPlanned(String problem);

  /// Shown when a medicine was saved but some of its reminders were not. {problem} is a whole sentence: why.
  ///
  /// In en, this message translates to:
  /// **'The medicine is saved, but not all of its reminders were set. {problem} Saving again tries once more.'**
  String savedButRemindersNotSet(String problem);

  /// No description provided for @removeFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this file?'**
  String get removeFileTitle;

  /// No description provided for @removeFileMessage.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed from the record.'**
  String removeFileMessage(String name);

  /// No description provided for @recordGone.
  ///
  /// In en, this message translates to:
  /// **'This record is gone'**
  String get recordGone;

  /// No description provided for @recordGoneNote.
  ///
  /// In en, this message translates to:
  /// **'It was deleted.'**
  String get recordGoneNote;

  /// No description provided for @fileAttached.
  ///
  /// In en, this message translates to:
  /// **'{name} is attached.'**
  String fileAttached(String name);

  /// No description provided for @inTheSchedule.
  ///
  /// In en, this message translates to:
  /// **'In the Schedule'**
  String get inTheSchedule;

  /// No description provided for @markAsDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markAsDone;

  /// No description provided for @noAttachmentsNote.
  ///
  /// In en, this message translates to:
  /// **'No photos or PDFs yet. A photo opens full screen; a PDF opens in the phone\'s viewer.'**
  String get noAttachmentsNote;

  /// No description provided for @shareThisRecord.
  ///
  /// In en, this message translates to:
  /// **'Share this record'**
  String get shareThisRecord;

  /// No description provided for @deleteInsideEdit.
  ///
  /// In en, this message translates to:
  /// **'Delete is inside Edit, and always asks first.'**
  String get deleteInsideEdit;

  /// No description provided for @attachSheetNote.
  ///
  /// In en, this message translates to:
  /// **'A booklet page, a vet letter, a lab result. Up to 5 MB.'**
  String get attachSheetNote;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @withTheCamera.
  ///
  /// In en, this message translates to:
  /// **'With the camera'**
  String get withTheCamera;

  /// No description provided for @chooseAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get chooseAPhoto;

  /// No description provided for @fromYourPhotos.
  ///
  /// In en, this message translates to:
  /// **'From your photos'**
  String get fromYourPhotos;

  /// No description provided for @chooseAPdf.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF file'**
  String get chooseAPdf;

  /// No description provided for @fromPhoneFiles.
  ///
  /// In en, this message translates to:
  /// **'From the phone\'s files'**
  String get fromPhoneFiles;

  /// No description provided for @fileKindPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get fileKindPdf;

  /// No description provided for @fileKindPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get fileKindPhoto;

  /// No description provided for @couldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open that file on this device.'**
  String get couldNotOpenFile;

  /// No description provided for @shareThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Share this photo'**
  String get shareThisPhoto;

  /// No description provided for @petsDocuments.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s documents'**
  String petsDocuments(String name);

  /// No description provided for @noDocumentsYet.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYet;

  /// No description provided for @noDocumentsNote.
  ///
  /// In en, this message translates to:
  /// **'Photos and PDFs you attach to a record show here.'**
  String get noDocumentsNote;

  /// No description provided for @documentsFinePrint.
  ///
  /// In en, this message translates to:
  /// **'A photo opens full screen; a PDF opens in the phone\'s viewer.'**
  String get documentsFinePrint;

  /// No description provided for @insightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get insightsEmpty;

  /// No description provided for @insightsEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Weight, appetite, energy and anything else you notice about {name} will build a picture here.'**
  String insightsEmptyNote(String name);

  /// No description provided for @openQuickLog.
  ///
  /// In en, this message translates to:
  /// **'Open the Quick log'**
  String get openQuickLog;

  /// No description provided for @observations.
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get observations;

  /// No description provided for @groupBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get groupBody;

  /// No description provided for @groupBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Behaviour'**
  String get groupBehaviour;

  /// No description provided for @insightsFinePrint.
  ///
  /// In en, this message translates to:
  /// **'What you noticed, in your own words. The app does not interpret it.'**
  String get insightsFinePrint;

  /// No description provided for @logWeight.
  ///
  /// In en, this message translates to:
  /// **'Log weight'**
  String get logWeight;

  /// No description provided for @noWeightYet.
  ///
  /// In en, this message translates to:
  /// **'No weight logged yet.'**
  String get noWeightYet;

  /// No description provided for @weighIns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 weigh-in} other{{count} weigh-ins}}'**
  String weighIns(int count);

  /// No description provided for @weightHighest.
  ///
  /// In en, this message translates to:
  /// **'highest {value}'**
  String weightHighest(String value);

  /// No description provided for @weightLowest.
  ///
  /// In en, this message translates to:
  /// **'lowest {value}'**
  String weightLowest(String value);

  /// What a screen reader says for the weight chart.
  ///
  /// In en, this message translates to:
  /// **'Weight trend from {from} on {fromDate} to {to} on {toDate}'**
  String weightTrendSemantics(String from, String fromDate, String to, String toDate);

  /// Legend of the small diamonds under the weight chart.
  ///
  /// In en, this message translates to:
  /// **'vet visit'**
  String get vetVisitMarker;

  /// Shown for a journal entry without an answer.
  ///
  /// In en, this message translates to:
  /// **'Noted'**
  String get noted;

  /// No description provided for @levelUsual.
  ///
  /// In en, this message translates to:
  /// **'Usual'**
  String get levelUsual;

  /// No description provided for @levelLess.
  ///
  /// In en, this message translates to:
  /// **'Less than usual'**
  String get levelLess;

  /// No description provided for @levelMore.
  ///
  /// In en, this message translates to:
  /// **'More than usual'**
  String get levelMore;

  /// No description provided for @levelDifferent.
  ///
  /// In en, this message translates to:
  /// **'Different from usual'**
  String get levelDifferent;

  /// No description provided for @logAppetite.
  ///
  /// In en, this message translates to:
  /// **'Appetite'**
  String get logAppetite;

  /// No description provided for @logEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get logEnergy;

  /// No description provided for @logMobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get logMobility;

  /// No description provided for @logDigestion.
  ///
  /// In en, this message translates to:
  /// **'Digestion'**
  String get logDigestion;

  /// No description provided for @logSkinCoat.
  ///
  /// In en, this message translates to:
  /// **'Skin or coat'**
  String get logSkinCoat;

  /// No description provided for @logDental.
  ///
  /// In en, this message translates to:
  /// **'Dental'**
  String get logDental;

  /// No description provided for @logDrinking.
  ///
  /// In en, this message translates to:
  /// **'Drinking'**
  String get logDrinking;

  /// No description provided for @logDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get logDiet;

  /// No description provided for @logDroppings.
  ///
  /// In en, this message translates to:
  /// **'Droppings'**
  String get logDroppings;

  /// No description provided for @logFeathers.
  ///
  /// In en, this message translates to:
  /// **'Feathers'**
  String get logFeathers;

  /// No description provided for @logActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get logActivity;

  /// No description provided for @logEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get logEnvironment;

  /// No description provided for @logEating.
  ///
  /// In en, this message translates to:
  /// **'Eating'**
  String get logEating;

  /// No description provided for @logFeeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get logFeeding;

  /// No description provided for @logShedding.
  ///
  /// In en, this message translates to:
  /// **'Shedding'**
  String get logShedding;

  /// No description provided for @logTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get logTemperature;

  /// No description provided for @logHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get logHumidity;

  /// No description provided for @logLighting.
  ///
  /// In en, this message translates to:
  /// **'Lighting'**
  String get logLighting;

  /// No description provided for @logOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get logOther;

  /// No description provided for @logSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get logSleep;

  /// No description provided for @logBarking.
  ///
  /// In en, this message translates to:
  /// **'Barking'**
  String get logBarking;

  /// No description provided for @logMeowing.
  ///
  /// In en, this message translates to:
  /// **'Meowing'**
  String get logMeowing;

  /// No description provided for @logVocalisation.
  ///
  /// In en, this message translates to:
  /// **'Vocalisation'**
  String get logVocalisation;

  /// No description provided for @logBiting.
  ///
  /// In en, this message translates to:
  /// **'Biting'**
  String get logBiting;

  /// No description provided for @logBitingScratching.
  ///
  /// In en, this message translates to:
  /// **'Biting or scratching'**
  String get logBitingScratching;

  /// No description provided for @logLeftAlone.
  ///
  /// In en, this message translates to:
  /// **'When left alone'**
  String get logLeftAlone;

  /// No description provided for @logLitterBox.
  ///
  /// In en, this message translates to:
  /// **'Litter box use'**
  String get logLitterBox;

  /// No description provided for @logOtherBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Other behaviour'**
  String get logOtherBehaviour;

  /// No description provided for @quickLogFor.
  ///
  /// In en, this message translates to:
  /// **'Quick log for {name}'**
  String quickLogFor(String name);

  /// No description provided for @whatDidYouNotice.
  ///
  /// In en, this message translates to:
  /// **'What did you notice?'**
  String get whatDidYouNotice;

  /// No description provided for @editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntry;

  /// No description provided for @weightInGrams.
  ///
  /// In en, this message translates to:
  /// **'Weight in grams'**
  String get weightInGrams;

  /// No description provided for @weightInKilograms.
  ///
  /// In en, this message translates to:
  /// **'Weight in kilograms'**
  String get weightInKilograms;

  /// No description provided for @lastTimeWeight.
  ///
  /// In en, this message translates to:
  /// **'Last time: {weight} on {date}'**
  String lastTimeWeight(String weight, String date);

  /// No description provided for @fieldWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get fieldWhen;

  /// No description provided for @whenDidYouNotice.
  ///
  /// In en, this message translates to:
  /// **'When did you notice it?'**
  String get whenDidYouNotice;

  /// No description provided for @validWeight.
  ///
  /// In en, this message translates to:
  /// **'That weight does not look right. Please check the number.'**
  String get validWeight;

  /// No description provided for @saveToJournal.
  ///
  /// In en, this message translates to:
  /// **'Save to journal'**
  String get saveToJournal;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @savedToJournal.
  ///
  /// In en, this message translates to:
  /// **'Saved to the journal.'**
  String get savedToJournal;

  /// No description provided for @entryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Entry updated.'**
  String get entryUpdated;

  /// No description provided for @deleteThisEntry.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry'**
  String get deleteThisEntry;

  /// No description provided for @deleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this entry?'**
  String get deleteEntryTitle;

  /// No description provided for @deleteEntryMessage.
  ///
  /// In en, this message translates to:
  /// **'It is removed from the journal. This cannot be undone.'**
  String get deleteEntryMessage;

  /// No description provided for @looksUrgent.
  ///
  /// In en, this message translates to:
  /// **'Looks urgent? Contact the vet'**
  String get looksUrgent;

  /// No description provided for @quickLogFinePrint.
  ///
  /// In en, this message translates to:
  /// **'A record of what you noticed. The app does not interpret it.'**
  String get quickLogFinePrint;

  /// No description provided for @reportSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}: health summary'**
  String reportSummaryTitle(String name);

  /// Title of the PDF of one record: the pet, then the record.
  ///
  /// In en, this message translates to:
  /// **'{name}: {title}'**
  String reportRecordTitle(String name, String title);

  /// No description provided for @reportPrepared.
  ///
  /// In en, this message translates to:
  /// **'Prepared on {date} with Pet Companion'**
  String reportPrepared(String date);

  /// No description provided for @reportPreparedBy.
  ///
  /// In en, this message translates to:
  /// **'Prepared on {date} by {owner} with Pet Companion'**
  String reportPreparedBy(String date, String owner);

  /// No description provided for @reportEmergencyVet.
  ///
  /// In en, this message translates to:
  /// **'Emergency vet'**
  String get reportEmergencyVet;

  /// No description provided for @reportMedicineLine.
  ///
  /// In en, this message translates to:
  /// **'{name}: {instructions}'**
  String reportMedicineLine(String name, String instructions);

  /// No description provided for @reportRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get reportRecords;

  /// No description provided for @reportRecentRecords.
  ///
  /// In en, this message translates to:
  /// **'Recent records'**
  String get reportRecentRecords;

  /// In the details of a record that has not happened yet.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get reportPlanned;

  /// No description provided for @reportColumnKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get reportColumnKind;

  /// No description provided for @reportFooter.
  ///
  /// In en, this message translates to:
  /// **'Written by the owner in Pet Companion. It is a record of what was entered, not veterinary advice.'**
  String get reportFooter;
}

class _HealthL10nDelegate extends LocalizationsDelegate<HealthL10n> {
  const _HealthL10nDelegate();

  @override
  Future<HealthL10n> load(Locale locale) {
    return SynchronousFuture<HealthL10n>(lookupHealthL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_HealthL10nDelegate old) => false;
}

HealthL10n lookupHealthL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return HealthL10nEn();
    case 'he': return HealthL10nHe();
  }

  throw FlutterError(
    'HealthL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
