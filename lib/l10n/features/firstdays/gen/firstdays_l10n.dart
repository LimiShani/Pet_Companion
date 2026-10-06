import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'firstdays_l10n_en.dart';
import 'firstdays_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FirstDaysL10n
/// returned by `FirstDaysL10n.of(context)`.
///
/// Applications need to include `FirstDaysL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/firstdays_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FirstDaysL10n.localizationsDelegates,
///   supportedLocales: FirstDaysL10n.supportedLocales,
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
/// be consistent with the languages listed in the FirstDaysL10n.supportedLocales
/// property.
abstract class FirstDaysL10n {
  FirstDaysL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FirstDaysL10n of(BuildContext context) {
    return Localizations.of<FirstDaysL10n>(context, FirstDaysL10n)!;
  }

  static const LocalizationsDelegate<FirstDaysL10n> delegate =
      _FirstDaysL10nDelegate();

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

  /// Header of the first 30 days page.
  ///
  /// In en, this message translates to:
  /// **'The first 30 days · {name}'**
  String pageTitle(String name);

  /// Under the header; the date is like 01.06.25.
  ///
  /// In en, this message translates to:
  /// **'Arrived home {date}'**
  String arrivedOn(String date);

  /// Day 1 is the arrival day.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String dayOfTotal(String day, String total);

  /// count is like "5/12".
  ///
  /// In en, this message translates to:
  /// **'{count} done'**
  String doneCount(String count);

  /// Heading of the tasks of days 1 to 7.
  ///
  /// In en, this message translates to:
  /// **'First week'**
  String get firstWeek;

  /// Heading of the tasks of days 8 to 30.
  ///
  /// In en, this message translates to:
  /// **'Weeks 2–4'**
  String get laterWeeks;

  /// Under a task the app ticked by itself (a vet visit was added, meal times set...).
  ///
  /// In en, this message translates to:
  /// **'Done in the app'**
  String get tickedForYou;

  /// Screen reader label of an empty tick.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get markDone;

  /// Screen reader label of a ticked tick.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get markNotDone;

  /// Button at the end of the page: ends the path early.
  ///
  /// In en, this message translates to:
  /// **'Close the first 30 days'**
  String get closePath;

  /// Title of the confirmation.
  ///
  /// In en, this message translates to:
  /// **'Close the first 30 days?'**
  String get closeQuestion;

  /// No description provided for @closeMessage.
  ///
  /// In en, this message translates to:
  /// **'The card leaves Home. This list stays on {name}\'s profile as a summary.'**
  String closeMessage(String name);

  /// Confirm button of the confirmation.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeConfirm;

  /// Summary line of a path the owner closed early.
  ///
  /// In en, this message translates to:
  /// **'Closed on {date}'**
  String closedOn(String date);

  /// Summary line after day 30.
  ///
  /// In en, this message translates to:
  /// **'The 30 days are over'**
  String get overLine;

  /// Shown when every task is done before day 30.
  ///
  /// In en, this message translates to:
  /// **'Everything is done. Nice work.'**
  String get allDoneLine;

  /// Under the summary line of a path that ended.
  ///
  /// In en, this message translates to:
  /// **'A look back at the first 30 days.'**
  String get summaryNote;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the first 30 days'**
  String get loadFailed;

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'The first 30 days have not started for {name}.'**
  String notStarted(String name);

  /// Title of the Home card.
  ///
  /// In en, this message translates to:
  /// **'The first 30 days of {name}'**
  String cardTitle(String name);

  /// On the Home card.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String cardDay(String day);

  /// On the Home card; task is the text of the next task.
  ///
  /// In en, this message translates to:
  /// **'Next: {task}'**
  String cardNext(String task);

  /// Pill on the Home card and the pet profile.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// Screen reader hint of the Home card.
  ///
  /// In en, this message translates to:
  /// **'Open the first 30 days'**
  String get openTapLabel;

  /// Question on step 2 of add-a-pet.
  ///
  /// In en, this message translates to:
  /// **'Just arrived home?'**
  String get arrivedQuestion;

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

  /// Label of the date field, and the date picker title.
  ///
  /// In en, this message translates to:
  /// **'Arrival day'**
  String get arrivalDay;

  /// No description provided for @arrivalNote.
  ///
  /// In en, this message translates to:
  /// **'We\'ll make a short checklist for the first 30 days.'**
  String get arrivalNote;

  /// Label of the block on the pet profile.
  ///
  /// In en, this message translates to:
  /// **'The first 30 days'**
  String get sectionTitle;

  /// Button on the pet profile.
  ///
  /// In en, this message translates to:
  /// **'Start the first 30 days'**
  String get startPath;

  /// No description provided for @startNote.
  ///
  /// In en, this message translates to:
  /// **'A short checklist for a pet that just arrived home.'**
  String get startNote;

  /// Pill on the pet profile once the path ended.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewSummary;

  /// No description provided for @taskDogBasics.
  ///
  /// In en, this message translates to:
  /// **'Get the basics: a bed, bowls, a lead and food'**
  String get taskDogBasics;

  /// No description provided for @taskDogRestSpot.
  ///
  /// In en, this message translates to:
  /// **'Set up a quiet spot to rest'**
  String get taskDogRestSpot;

  /// No description provided for @taskFood.
  ///
  /// In en, this message translates to:
  /// **'Keep to the food they know for now, and add it here'**
  String get taskFood;

  /// No description provided for @taskMealTimes.
  ///
  /// In en, this message translates to:
  /// **'Set regular meal times'**
  String get taskMealTimes;

  /// No description provided for @taskWalkTimes.
  ///
  /// In en, this message translates to:
  /// **'Plan regular walk times'**
  String get taskWalkTimes;

  /// No description provided for @taskDogNameTag.
  ///
  /// In en, this message translates to:
  /// **'A collar with a name tag and your phone number'**
  String get taskDogNameTag;

  /// No description provided for @taskFirstVet.
  ///
  /// In en, this message translates to:
  /// **'Book a first check-up with a vet'**
  String get taskFirstVet;

  /// No description provided for @taskDogGuide.
  ///
  /// In en, this message translates to:
  /// **'Read the guide on the first week at home'**
  String get taskDogGuide;

  /// No description provided for @taskMicrochip.
  ///
  /// In en, this message translates to:
  /// **'Check the microchip and register your details'**
  String get taskMicrochip;

  /// No description provided for @taskVaccines.
  ///
  /// In en, this message translates to:
  /// **'Plan vaccinations with your vet'**
  String get taskVaccines;

  /// No description provided for @taskDogFirstWalks.
  ///
  /// In en, this message translates to:
  /// **'Short first walks and calm hellos with people and dogs'**
  String get taskDogFirstWalks;

  /// No description provided for @taskDogHouseRules.
  ///
  /// In en, this message translates to:
  /// **'Agree on house rules with everyone at home'**
  String get taskDogHouseRules;

  /// No description provided for @taskCatBasics.
  ///
  /// In en, this message translates to:
  /// **'Get the basics: a litter box, bowls and food'**
  String get taskCatBasics;

  /// No description provided for @taskCatSafeRoom.
  ///
  /// In en, this message translates to:
  /// **'A quiet room to settle in, with everything close by'**
  String get taskCatSafeRoom;

  /// No description provided for @taskCatGuide.
  ///
  /// In en, this message translates to:
  /// **'Read the guide on a cat\'s first week at home'**
  String get taskCatGuide;

  /// No description provided for @taskCatScratching.
  ///
  /// In en, this message translates to:
  /// **'A scratching post near a favourite spot'**
  String get taskCatScratching;

  /// No description provided for @taskCatExplore.
  ///
  /// In en, this message translates to:
  /// **'Open up the rest of the home, one room at a time'**
  String get taskCatExplore;

  /// No description provided for @taskCatPlay.
  ///
  /// In en, this message translates to:
  /// **'A short play session every day'**
  String get taskCatPlay;

  /// No description provided for @taskOtherHome.
  ///
  /// In en, this message translates to:
  /// **'Set up their home: a cage, tank or corner, with food and water'**
  String get taskOtherHome;

  /// No description provided for @taskOtherQuiet.
  ///
  /// In en, this message translates to:
  /// **'Give them a few quiet days to settle in'**
  String get taskOtherQuiet;

  /// No description provided for @taskCleaning.
  ///
  /// In en, this message translates to:
  /// **'Plan a cleaning routine for their home'**
  String get taskCleaning;

  /// No description provided for @taskGuides.
  ///
  /// In en, this message translates to:
  /// **'Have a look at the guides in Community'**
  String get taskGuides;

  /// Opens the Store on deals that suit the pet.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get actionDeals;

  /// Opens the food and portion page.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get actionFood;

  /// Opens the feeding page.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get actionFeeding;

  /// Opens the activity page.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get actionActivity;

  /// Opens a new vet visit record in Health.
  ///
  /// In en, this message translates to:
  /// **'Add visit'**
  String get actionAddVisit;

  /// Opens the pet's health profile.
  ///
  /// In en, this message translates to:
  /// **'Microchip'**
  String get actionMicrochip;

  /// Opens the Health schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get actionSchedule;

  /// Opens a new cleaning routine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get actionRoutine;

  /// Opens a guide.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get actionRead;

  /// Opens the guides library.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get actionGuides;
}

class _FirstDaysL10nDelegate extends LocalizationsDelegate<FirstDaysL10n> {
  const _FirstDaysL10nDelegate();

  @override
  Future<FirstDaysL10n> load(Locale locale) {
    return SynchronousFuture<FirstDaysL10n>(lookupFirstDaysL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_FirstDaysL10nDelegate old) => false;
}

FirstDaysL10n lookupFirstDaysL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FirstDaysL10nEn();
    case 'he':
      return FirstDaysL10nHe();
  }

  throw FlutterError(
    'FirstDaysL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
