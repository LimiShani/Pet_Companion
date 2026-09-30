import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_l10n_en.dart';
import 'app_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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

  /// The app's name. It stays in Latin letters in every language.
  ///
  /// In en, this message translates to:
  /// **'Pet Companion'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get navHealth;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get navStore;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get commonTomorrow;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Screen-reader label of the round + button after the pet pills.
  ///
  /// In en, this message translates to:
  /// **'Add a pet'**
  String get petSelectorAdd;

  /// No description provided for @placeholderComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{title} coming soon'**
  String placeholderComingSoon(String title);

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see how your pets are doing today.'**
  String get authSignInSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get authPasswordHint;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNewHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authNewHere;

  /// Link on the sign-in screen that opens the sign-up screen.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAnAccount;

  /// No description provided for @authForgotNeedsEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address above first, then tap Forgot password.'**
  String get authForgotNeedsEmail;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account uses {email}, a reset link is on its way.'**
  String authResetSent(String email);

  /// No description provided for @authResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send a reset link. Please try again.'**
  String get authResetFailed;

  /// No description provided for @authCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateTitle;

  /// No description provided for @authCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One account for all of your pets.'**
  String get authCreateSubtitle;

  /// No description provided for @authYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authYourName;

  /// No description provided for @authYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get authYourNameHint;

  /// No description provided for @authPasswordMinHint.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String authPasswordMinHint(int count);

  /// No description provided for @authRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get authRepeatPassword;

  /// No description provided for @authRepeatPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Same as above'**
  String get authRepeatPasswordHint;

  /// The button that submits the sign-up form.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authTerms.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to the Terms of Use and Privacy Policy.'**
  String get authTerms;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @validEmailEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get validEmailEmpty;

  /// No description provided for @validEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'That does not look like an email address.'**
  String get validEmailInvalid;

  /// No description provided for @validPasswordEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get validPasswordEmpty;

  /// No description provided for @validMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters.'**
  String validMinLength(int count);

  /// No description provided for @validConfirmEmpty.
  ///
  /// In en, this message translates to:
  /// **'Repeat your password.'**
  String get validConfirmEmpty;

  /// No description provided for @validConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match.'**
  String get validConfirmMismatch;

  /// No description provided for @validNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tell us what to call you.'**
  String get validNameEmpty;

  /// No description provided for @authErrNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account uses that email address.'**
  String get authErrNoAccount;

  /// No description provided for @authErrWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get authErrWrongPassword;

  /// No description provided for @authErrEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists.'**
  String get authErrEmailTaken;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password. Please try again.'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your email address first. Check your inbox for the link.'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again.'**
  String get authErrRateLimited;

  /// No description provided for @authErrWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Please choose a longer password.'**
  String get authErrWeakPassword;

  /// No description provided for @authErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get authErrNetwork;

  /// No description provided for @authErrSignInIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sign in did not return a user. Please try again.'**
  String get authErrSignInIncomplete;

  /// No description provided for @authErrSignUpIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Sign up did not return a user. Please try again.'**
  String get authErrSignUpIncomplete;

  /// No description provided for @authErrConfirmEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Almost there: open the confirmation email we just sent, then sign in.'**
  String get authErrConfirmEmailSent;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// No description provided for @languageFollowPhone.
  ///
  /// In en, this message translates to:
  /// **'Follow the phone'**
  String get languageFollowPhone;

  /// Under 'Follow the phone': the language the phone is set to, in its own letters.
  ///
  /// In en, this message translates to:
  /// **'Now: {language}'**
  String languageFollowPhoneNow(String language);

  /// Small tag beside a language whose translation is not complete yet.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get languagePreviewTag;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'You can change this at any time. What people write stays in the language it was written in.'**
  String get languageNote;

  /// Screen-reader label of the language pill on the sign-in screens.
  ///
  /// In en, this message translates to:
  /// **'Change the language: {language}'**
  String languageSwitchTo(String language);

  /// No description provided for @menuMyPets.
  ///
  /// In en, this message translates to:
  /// **'My pets'**
  String get menuMyPets;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Under 'Settings' in the side menu and the account sheet: what the page holds.
  ///
  /// In en, this message translates to:
  /// **'Language, week'**
  String get settingsSummary;

  /// No description provided for @settingsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get settingsWeek;

  /// No description provided for @settingsFirstDay.
  ///
  /// In en, this message translates to:
  /// **'First day of the week'**
  String get settingsFirstDay;

  /// No description provided for @settingsDaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get settingsDaySaturday;

  /// No description provided for @settingsDaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get settingsDaySunday;

  /// No description provided for @settingsDayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get settingsDayMonday;

  /// No description provided for @settingsWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get settingsWeekdays;

  /// No description provided for @settingsWeekdaysSunThu.
  ///
  /// In en, this message translates to:
  /// **'Sunday to Thursday'**
  String get settingsWeekdaysSunThu;

  /// No description provided for @settingsWeekdaysMonFri.
  ///
  /// In en, this message translates to:
  /// **'Monday to Friday'**
  String get settingsWeekdaysMonFri;

  /// Screen-reader text of the row of seven day letters; the days are short names, e.g. 'Fri, Sat'.
  ///
  /// In en, this message translates to:
  /// **'The weekend: {days}'**
  String settingsWeekendIs(String days);

  /// No description provided for @settingsWeekNote.
  ///
  /// In en, this message translates to:
  /// **'Sets the order of the day chips and what \"Weekdays\" and \"Weekends\" mean in the schedule. The dimmed days are the weekend.'**
  String get settingsWeekNote;

  /// No description provided for @settingsSavedNote.
  ///
  /// In en, this message translates to:
  /// **'These settings are saved on this phone.'**
  String get settingsSavedNote;

  /// No description provided for @homeMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenu;

  /// No description provided for @homeAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get homeAccount;

  /// No description provided for @homePetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pet} other{{count} pets}}'**
  String homePetCount(int count);

  /// No description provided for @homeBreed.
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get homeBreed;

  /// No description provided for @homeAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get homeAge;

  /// No description provided for @homeWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get homeWeight;

  /// No description provided for @homeWeightKg.
  ///
  /// In en, this message translates to:
  /// **'{value} kg'**
  String homeWeightKg(String value);

  /// No description provided for @homeFeeding.
  ///
  /// In en, this message translates to:
  /// **'Feeding'**
  String get homeFeeding;

  /// No description provided for @homeNoGoal.
  ///
  /// In en, this message translates to:
  /// **'No goal set'**
  String get homeNoGoal;

  /// No description provided for @homeGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal {goal} cal/day'**
  String homeGoal(int goal);

  /// Follows the big number of calories eaten today: '375 cal today'.
  ///
  /// In en, this message translates to:
  /// **'cal today'**
  String get homeCalToday;

  /// No description provided for @homeCaloriesSemantics.
  ///
  /// In en, this message translates to:
  /// **'Calories toward daily goal'**
  String get homeCaloriesSemantics;

  /// No description provided for @homeCaloriesOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{eaten} of {goal}'**
  String homeCaloriesOfGoal(int eaten, int goal);

  /// No description provided for @homeNextFeeding.
  ///
  /// In en, this message translates to:
  /// **'Next feeding · {time}'**
  String homeNextFeeding(String time);

  /// No description provided for @homeNextFeedingUnset.
  ///
  /// In en, this message translates to:
  /// **'Next feeding · not set'**
  String get homeNextFeedingUnset;

  /// No description provided for @homeActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get homeActivity;

  /// No description provided for @homeSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get homeSteps;

  /// No description provided for @homeActivityTime.
  ///
  /// In en, this message translates to:
  /// **'Activity time'**
  String get homeActivityTime;

  /// No description provided for @homeNextWalk.
  ///
  /// In en, this message translates to:
  /// **'Next walk · {time}'**
  String homeNextWalk(String time);

  /// No description provided for @homeNextWalkUnset.
  ///
  /// In en, this message translates to:
  /// **'Next walk · not set'**
  String get homeNextWalkUnset;

  /// No description provided for @homeHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get homeHealth;

  /// No description provided for @homeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get homeUpcoming;

  /// No description provided for @homeNoHealthEvents.
  ///
  /// In en, this message translates to:
  /// **'No health events yet'**
  String get homeNoHealthEvents;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppL10nEn();
    case 'he': return AppL10nHe();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
