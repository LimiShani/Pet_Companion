import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'healthplan_l10n_en.dart';
import 'healthplan_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of HealthPlanL10n
/// returned by `HealthPlanL10n.of(context)`.
///
/// Applications need to include `HealthPlanL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/healthplan_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: HealthPlanL10n.localizationsDelegates,
///   supportedLocales: HealthPlanL10n.supportedLocales,
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
/// be consistent with the languages listed in the HealthPlanL10n.supportedLocales
/// property.
abstract class HealthPlanL10n {
  HealthPlanL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static HealthPlanL10n of(BuildContext context) {
    return Localizations.of<HealthPlanL10n>(context, HealthPlanL10n)!;
  }

  static const LocalizationsDelegate<HealthPlanL10n> delegate = _HealthPlanL10nDelegate();

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

  /// The insight line on the Health Overview: walk minutes of the last 4 weeks more than 20% below the 4 before. Calm, never a diagnosis.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s walks were shorter than last month. Worth a word with your vet if it goes on.'**
  String insightShorterWalks(String pet);

  /// Insight: weight up more than 5% within 8 weeks.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s weight went up by about {percent}% in the last few weeks. Worth a word with your vet if it goes on.'**
  String insightWeightUp(String pet, int percent);

  /// Insight: weight down more than 5% within 8 weeks.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s weight went down by about {percent}% in the last few weeks. Worth a word with your vet if it goes on.'**
  String insightWeightDown(String pet, int percent);

  /// Insight: three or more "less than usual" appetite entries in 14 days.
  ///
  /// In en, this message translates to:
  /// **'In the last two weeks you noted {count} times that {pet} ate less than usual. Worth a word with your vet if it goes on.'**
  String insightAppetiteLess(String pet, int count);

  /// The insight's link to the pet's activity page.
  ///
  /// In en, this message translates to:
  /// **'See walks'**
  String get insightSeeWalks;

  /// The insight's link to the weight in Records.
  ///
  /// In en, this message translates to:
  /// **'See weight'**
  String get insightSeeWeight;

  /// The insight's link to the journal in Records.
  ///
  /// In en, this message translates to:
  /// **'See journal'**
  String get insightSeeJournal;

  /// Row of the Health "+" sheet that opens the yearly plan.
  ///
  /// In en, this message translates to:
  /// **'Yearly plan'**
  String get planAddRow;

  /// Under the yearly plan row of the "+" sheet.
  ///
  /// In en, this message translates to:
  /// **'Vaccines and treatments'**
  String get planAddRowNote;

  /// Title of the yearly plan sheet.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s yearly plan'**
  String planTitle(String pet);

  /// Under the title of a dog's yearly plan.
  ///
  /// In en, this message translates to:
  /// **'A common plan for dogs in Israel. Your vet may suggest another.'**
  String get planIntroDog;

  /// Under the title of a cat's yearly plan.
  ///
  /// In en, this message translates to:
  /// **'A common plan for cats in Israel. Your vet may suggest another.'**
  String get planIntroCat;

  /// The yearly plan sheet of an animal other than a dog or a cat.
  ///
  /// In en, this message translates to:
  /// **'There is no yearly plan for this kind of animal yet.'**
  String get planNoPlan;

  /// Tag of rabies for dogs.
  ///
  /// In en, this message translates to:
  /// **'Required by law'**
  String get planRequired;

  /// Tag of rabies for cats.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get planRecommended;

  /// When a plan item is first planned. {date} is e.g. 31.10.26.
  ///
  /// In en, this message translates to:
  /// **'First date {date}'**
  String planFirstDate(String date);

  /// A plan item planned for today.
  ///
  /// In en, this message translates to:
  /// **'First date today'**
  String get planFirstDateToday;

  /// Where the first date comes from: the last time it was done.
  ///
  /// In en, this message translates to:
  /// **'Last time {date}'**
  String planLastTime(String date);

  /// The last time is longer ago than the interval.
  ///
  /// In en, this message translates to:
  /// **'Last time {date} · due now'**
  String planOverdue(String date);

  /// A plan item with nothing on record: planned in two weeks.
  ///
  /// In en, this message translates to:
  /// **'Nothing on record. Check the vaccination booklet first.'**
  String get planNoHistory;

  /// The pet is too young: the item starts at this age.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{From {count} weeks old}}'**
  String planFromWeeks(int count);

  /// The pet is too young: the item starts at this age.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{From 1 month old} other{From {count} months old}}'**
  String planFromMonths(int count);

  /// The next doses of the puppy or kitten series.
  ///
  /// In en, this message translates to:
  /// **'Then at {first} and {second} weeks, then once a year'**
  String planSeriesTwo(int first, int second);

  /// The last dose of the series still to come.
  ///
  /// In en, this message translates to:
  /// **'Then at {weeks} weeks, then once a year'**
  String planSeriesOne(int weeks);

  /// After the last dose of the series.
  ///
  /// In en, this message translates to:
  /// **'Then once a year'**
  String get planSeriesLast;

  /// A plan item that is already planned: it is not planned twice.
  ///
  /// In en, this message translates to:
  /// **'Already in the schedule for {date}'**
  String planAlreadyPlanned(String date);

  /// The interval chips of the flea treatment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String planEveryMonths(int count);

  /// Link and page title: the sources of the yearly plan.
  ///
  /// In en, this message translates to:
  /// **'Where this comes from'**
  String get planSources;

  /// Intro of the sources page.
  ///
  /// In en, this message translates to:
  /// **'The plan follows these sources. Your vet knows {pet} best.'**
  String planSourcesIntro(String pet);

  /// Fine print of the yearly plan sheet.
  ///
  /// In en, this message translates to:
  /// **'Not a substitute for your vet\'s advice.'**
  String get planFinePrint;

  /// Main button of the yearly plan sheet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 date to the schedule} other{Add {count} dates to the schedule}}'**
  String planAddDates(int count);

  /// Title after the plan was added.
  ///
  /// In en, this message translates to:
  /// **'In {pet}\'s schedule'**
  String planAdded(String pet);

  /// Under the title after the plan was added.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 date was added. When you mark it done, the next one is planned.} other{{count} dates were added. When you mark one done, the next one is planned.}}'**
  String planAddedNote(int count);

  /// Shares the planned dates as a calendar (.ics) file.
  ///
  /// In en, this message translates to:
  /// **'Add to my calendar'**
  String get planAddToCalendar;

  /// Under "Add to my calendar".
  ///
  /// In en, this message translates to:
  /// **'Shares a calendar file. PetLoop does not read your calendar.'**
  String get planCalendarNote;

  /// Closes the yearly plan sheet after the plan was added.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planDone;

  /// The Health Overview's invitation to the yearly plan, while the pet has no vaccination on record.
  ///
  /// In en, this message translates to:
  /// **'No vaccinations on record for {pet} yet. A yearly plan puts the next dates in the schedule.'**
  String planInvite(String pet);

  /// Link of the Overview invitation: opens the yearly plan.
  ///
  /// In en, this message translates to:
  /// **'Plan the year'**
  String get planInviteAction;

  /// Small line under a planned record made from the yearly plan (Coming up, the calendar file).
  ///
  /// In en, this message translates to:
  /// **'From {pet}\'s yearly plan'**
  String planFromPlan(String pet);
}

class _HealthPlanL10nDelegate extends LocalizationsDelegate<HealthPlanL10n> {
  const _HealthPlanL10nDelegate();

  @override
  Future<HealthPlanL10n> load(Locale locale) {
    return SynchronousFuture<HealthPlanL10n>(lookupHealthPlanL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_HealthPlanL10nDelegate old) => false;
}

HealthPlanL10n lookupHealthPlanL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return HealthPlanL10nEn();
    case 'he': return HealthPlanL10nHe();
  }

  throw FlutterError(
    'HealthPlanL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
