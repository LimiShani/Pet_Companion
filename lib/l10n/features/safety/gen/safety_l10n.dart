import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'safety_l10n_en.dart';
import 'safety_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SafetyL10n
/// returned by `SafetyL10n.of(context)`.
///
/// Applications need to include `SafetyL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/safety_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SafetyL10n.localizationsDelegates,
///   supportedLocales: SafetyL10n.supportedLocales,
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
/// be consistent with the languages listed in the SafetyL10n.supportedLocales
/// property.
abstract class SafetyL10n {
  SafetyL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SafetyL10n of(BuildContext context) {
    return Localizations.of<SafetyL10n>(context, SafetyL10n)!;
  }

  static const LocalizationsDelegate<SafetyL10n> delegate = _SafetyL10nDelegate();

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

  /// The line under the Emergency sheet's title.
  ///
  /// In en, this message translates to:
  /// **'Call first. The rows below help you decide and prepare.'**
  String get emergencyLead;

  /// On the Emergency sheet's first contact (a clinic or a vet): opening hours change, so call before driving.
  ///
  /// In en, this message translates to:
  /// **'Call to confirm they are open'**
  String get confirmOpen;

  /// Emergency sheet row: opens the list of signs that mean going to a vet now.
  ///
  /// In en, this message translates to:
  /// **'Is it urgent?'**
  String get urgentRow;

  /// No description provided for @urgentRowNote.
  ///
  /// In en, this message translates to:
  /// **'Signs that mean going to the vet now'**
  String get urgentRowNote;

  /// Emergency sheet row: opens the searchable list of foods and plants.
  ///
  /// In en, this message translates to:
  /// **'Can {name} eat this?'**
  String foodRow(String name);

  /// No description provided for @foodRowNote.
  ///
  /// In en, this message translates to:
  /// **'Foods and plants: safe, a little or dangerous'**
  String get foodRowNote;

  /// Emergency sheet row: starts Lost mode (an alert to people nearby and a card to share).
  ///
  /// In en, this message translates to:
  /// **'Lost mode'**
  String get lostRow;

  /// No description provided for @lostRowNote.
  ///
  /// In en, this message translates to:
  /// **'Tell people nearby and share a card'**
  String get lostRowNote;

  /// Subtitle of the Lost mode row for an account without Lost mode: it opens the lost-pet card only.
  ///
  /// In en, this message translates to:
  /// **'Make a card to share'**
  String get lostRowCardNote;

  /// The Lost mode row while an alert is open: the pet and how many people commented on the post.
  ///
  /// In en, this message translates to:
  /// **'{name} is missing · {count, plural, =0{no sightings yet} =1{1 sighting} other{{count} sightings}}'**
  String lostRowActive(String name, int count);

  /// Under the open alert's row: when the pet was last seen, e.g. 'Today 14:30'.
  ///
  /// In en, this message translates to:
  /// **'Last seen {when}'**
  String lostRowActiveNote(String when);

  /// Under the Emergency sheet's Find a clinic nearby row.
  ///
  /// In en, this message translates to:
  /// **'Emergency clinics near you'**
  String get findClinicNote;

  /// Under the Is it urgent? page title.
  ///
  /// In en, this message translates to:
  /// **'Any of these means going to a vet now. Call on the way.'**
  String get urgentLead;

  /// No description provided for @urgentSectionDog.
  ///
  /// In en, this message translates to:
  /// **'Signs in dogs'**
  String get urgentSectionDog;

  /// No description provided for @urgentSectionCat.
  ///
  /// In en, this message translates to:
  /// **'Signs in cats'**
  String get urgentSectionCat;

  /// Heading of the signs for a bird, rabbit, reptile or other pet.
  ///
  /// In en, this message translates to:
  /// **'Signs in any animal'**
  String get urgentSectionAny;

  /// No description provided for @urgentOtherNote.
  ///
  /// In en, this message translates to:
  /// **'Signs that are only about dogs or cats are left out.'**
  String get urgentOtherNote;

  /// On the safety pages when the pet has no number to call.
  ///
  /// In en, this message translates to:
  /// **'No vet saved? Find a clinic nearby'**
  String get noVetFindClinic;

  /// The folded list of the sources of a safety list.
  ///
  /// In en, this message translates to:
  /// **'Where this comes from'**
  String get sourcesTitle;

  /// No description provided for @foodSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a food or a plant'**
  String get foodSearchHint;

  /// No description provided for @foodSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the search'**
  String get foodSearchClear;

  /// Tooltip of the animal menu chip of the foods list.
  ///
  /// In en, this message translates to:
  /// **'Which animal'**
  String get animalMenuTooltip;

  /// No description provided for @animalDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get animalDog;

  /// No description provided for @animalCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get animalCat;

  /// No description provided for @animalBird.
  ///
  /// In en, this message translates to:
  /// **'Bird'**
  String get animalBird;

  /// No description provided for @animalOther.
  ///
  /// In en, this message translates to:
  /// **'Other animals'**
  String get animalOther;

  /// No description provided for @kindFoods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get kindFoods;

  /// No description provided for @kindPlants.
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get kindPlants;

  /// No description provided for @kindHousehold.
  ///
  /// In en, this message translates to:
  /// **'Around the house'**
  String get kindHousehold;

  /// Food answer: fine in a pet-sized portion.
  ///
  /// In en, this message translates to:
  /// **'Safe'**
  String get levelSafe;

  /// Food answer: only a little, now and then.
  ///
  /// In en, this message translates to:
  /// **'A little'**
  String get levelLittle;

  /// Food answer: keep away; if eaten, call the vet.
  ///
  /// In en, this message translates to:
  /// **'Dangerous'**
  String get levelDangerous;

  /// Food answer when the list says nothing for this animal.
  ///
  /// In en, this message translates to:
  /// **'Ask your vet'**
  String get levelAsk;

  /// No description provided for @levelNotListed.
  ///
  /// In en, this message translates to:
  /// **'not on our list'**
  String get levelNotListed;

  /// No description provided for @forDogs.
  ///
  /// In en, this message translates to:
  /// **'For dogs'**
  String get forDogs;

  /// No description provided for @forCats.
  ///
  /// In en, this message translates to:
  /// **'For cats'**
  String get forCats;

  /// No description provided for @forBirds.
  ///
  /// In en, this message translates to:
  /// **'For birds'**
  String get forBirds;

  /// One other animal's answer in a food's sheet: "For cats: Dangerous".
  ///
  /// In en, this message translates to:
  /// **'{animal}: {level}'**
  String forAnimal(String animal, String level);

  /// The other names of a food.
  ///
  /// In en, this message translates to:
  /// **'Also: {names}'**
  String foodAlso(String names);

  /// No description provided for @foodCallVet.
  ///
  /// In en, this message translates to:
  /// **'Call the vet'**
  String get foodCallVet;

  /// No description provided for @foodNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure? Call the vet'**
  String get foodNotSure;

  /// No description provided for @foodEatenAlready.
  ///
  /// In en, this message translates to:
  /// **'Eaten already? Call even if all seems fine.'**
  String get foodEatenAlready;

  /// No description provided for @foodNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{text}”.'**
  String foodNothing(String text);

  /// No description provided for @lostStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String lostStep(int step, int total);

  /// Lost mode step 1: choose another pet.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get lostChangePet;

  /// Title of the sheet that picks the pet in Lost mode.
  ///
  /// In en, this message translates to:
  /// **'Who is missing?'**
  String get lostWhichPet;

  /// No description provided for @lostLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen'**
  String get lostLastSeen;

  /// No description provided for @lostTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get lostTown;

  /// No description provided for @lostTownChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the town'**
  String get lostTownChoose;

  /// No description provided for @lostTownHint.
  ///
  /// In en, this message translates to:
  /// **'Type a town'**
  String get lostTownHint;

  /// No description provided for @lostTownNeeded.
  ///
  /// In en, this message translates to:
  /// **'Choose the town first'**
  String get lostTownNeeded;

  /// No description provided for @lostWhere.
  ///
  /// In en, this message translates to:
  /// **'Where exactly?'**
  String get lostWhere;

  /// No description provided for @lostWhereHint.
  ///
  /// In en, this message translates to:
  /// **'A public place, not an address'**
  String get lostWhereHint;

  /// No description provided for @lostNote.
  ///
  /// In en, this message translates to:
  /// **'Anything people should know?'**
  String get lostNote;

  /// No description provided for @lostNoteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: please do not chase, call the name'**
  String get lostNoteHint;

  /// No description provided for @lostNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get lostNext;

  /// No description provided for @lostPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'What people will see'**
  String get lostPreviewTitle;

  /// No description provided for @lostPostTag.
  ///
  /// In en, this message translates to:
  /// **'Lost and found'**
  String get lostPostTag;

  /// When the previewed post was written.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get lostNow;

  /// No description provided for @lostUsePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use {name}\'s photo'**
  String lostUsePhoto(String name);

  /// No description provided for @lostWhoHears.
  ///
  /// In en, this message translates to:
  /// **'People in {town} who use PetLoop get one notification. Sightings come as comments.'**
  String lostWhoHears(String town);

  /// No description provided for @lostCardNext.
  ///
  /// In en, this message translates to:
  /// **'The card to share'**
  String get lostCardNext;

  /// No description provided for @lostCardNextNote.
  ///
  /// In en, this message translates to:
  /// **'Comes next, filled in'**
  String get lostCardNextNote;

  /// No description provided for @lostStart.
  ///
  /// In en, this message translates to:
  /// **'Start lost mode'**
  String get lostStart;

  /// No description provided for @lostStarted.
  ///
  /// In en, this message translates to:
  /// **'Lost mode is on. People nearby are being told.'**
  String get lostStarted;

  /// No description provided for @lostAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is missing'**
  String lostAlertTitle(String name);

  /// No description provided for @lostSince.
  ///
  /// In en, this message translates to:
  /// **'Since {when}'**
  String lostSince(String when);

  /// No description provided for @lostSightings.
  ///
  /// In en, this message translates to:
  /// **'Sightings'**
  String get lostSightings;

  /// No description provided for @lostNoSightings.
  ///
  /// In en, this message translates to:
  /// **'No sightings yet. Sharing the card reaches more people.'**
  String get lostNoSightings;

  /// No description provided for @lostSightingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the comments'**
  String get lostSightingsFailed;

  /// No description provided for @lostOpenPost.
  ///
  /// In en, this message translates to:
  /// **'Open the post'**
  String get lostOpenPost;

  /// No description provided for @lostShareCard.
  ///
  /// In en, this message translates to:
  /// **'Share the card'**
  String get lostShareCard;

  /// The one filled button of the open alert: closes it as found.
  ///
  /// In en, this message translates to:
  /// **'{name} is home'**
  String lostHome(String name);

  /// No description provided for @lostClose.
  ///
  /// In en, this message translates to:
  /// **'Close the alert'**
  String get lostClose;

  /// No description provided for @lostCloseQuestion.
  ///
  /// In en, this message translates to:
  /// **'Close the alert without “found”?'**
  String get lostCloseQuestion;

  /// No description provided for @lostCloseNote.
  ///
  /// In en, this message translates to:
  /// **'If nobody answered yet, the post is removed too.'**
  String get lostCloseNote;

  /// No description provided for @lostCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get lostCloseConfirm;

  /// No description provided for @lostKeepLooking.
  ///
  /// In en, this message translates to:
  /// **'Keep looking'**
  String get lostKeepLooking;

  /// No description provided for @lostFoundDone.
  ///
  /// In en, this message translates to:
  /// **'Good news. The alert is closed.'**
  String get lostFoundDone;

  /// No description provided for @lostClosedDone.
  ///
  /// In en, this message translates to:
  /// **'The alert is closed.'**
  String get lostClosedDone;

  /// No description provided for @lostErrActive.
  ///
  /// In en, this message translates to:
  /// **'There is already an open alert for {name}.'**
  String lostErrActive(String name);

  /// No description provided for @lostErrRate.
  ///
  /// In en, this message translates to:
  /// **'Three alerts today already. Please try again tomorrow.'**
  String get lostErrRate;

  /// No description provided for @lostErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'Something here is not right. Please check the place and the time.'**
  String get lostErrInvalid;

  /// No description provided for @lostErrNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Lost mode is not available for this account.'**
  String get lostErrNotAllowed;

  /// No description provided for @lostErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not do that. Please try again.'**
  String get lostErrGeneric;
}

class _SafetyL10nDelegate extends LocalizationsDelegate<SafetyL10n> {
  const _SafetyL10nDelegate();

  @override
  Future<SafetyL10n> load(Locale locale) {
    return SynchronousFuture<SafetyL10n>(lookupSafetyL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_SafetyL10nDelegate old) => false;
}

SafetyL10n lookupSafetyL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return SafetyL10nEn();
    case 'he': return SafetyL10nHe();
  }

  throw FlutterError(
    'SafetyL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
