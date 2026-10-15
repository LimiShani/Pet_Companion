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
  /// **'PetLoop'**
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

  /// Asked when leaving an edit page with changes that were not saved.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes will not be saved.'**
  String get discardChangesBody;

  /// No description provided for @discardChangesKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardChangesKeepEditing;

  /// No description provided for @discardChangesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardChangesDiscard;

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

  /// The two bracketed parts become links, in this order: the Terms of Use, then the Privacy Policy. Keep both, keep the brackets.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to the [Terms of Use] and [Privacy Policy].'**
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

  /// Header of the screen a password-recovery link opens.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get resetPasswordIntro;

  /// No description provided for @resetPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordLabel;

  /// No description provided for @resetPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get resetPasswordConfirm;

  /// No description provided for @resetPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get resetPasswordTooShort;

  /// No description provided for @resetPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get resetPasswordMismatch;

  /// No description provided for @resetPasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get resetPasswordSave;

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

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes your account for good: your pets, their records and documents, your photos, your posts and your messages. There is no way back.'**
  String get accountDeleteBody;

  /// The word the owner must type to confirm; compared ignoring case.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get accountDeleteWord;

  /// No description provided for @accountDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String accountDeleteHint(String word);

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get accountDeleted;

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

  /// The page behind the avatar in every header: the account, My pets, Budget, Settings, Sign out. Also the avatar's label.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get youTitle;

  /// No description provided for @youCommunitySafetySummary.
  ///
  /// In en, this message translates to:
  /// **'Rules, blocked members'**
  String get youCommunitySafetySummary;

  /// No description provided for @youAdminTools.
  ///
  /// In en, this message translates to:
  /// **'Admin tools'**
  String get youAdminTools;

  /// No description provided for @youAdminToolsSummary.
  ///
  /// In en, this message translates to:
  /// **'Feature access, directory review, park suggestions, usage'**
  String get youAdminToolsSummary;

  /// No description provided for @adminUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get adminUsage;

  /// No description provided for @adminUsageSummary.
  ///
  /// In en, this message translates to:
  /// **'Which actions people repeat'**
  String get adminUsageSummary;

  /// Admin tools > Usage: daily counts of the actions people repeat.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// No description provided for @usageDaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 28 days'**
  String get usageDaysTitle;

  /// No description provided for @usageColumnDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get usageColumnDay;

  /// No description provided for @usageColumnActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get usageColumnActive;

  /// No description provided for @usageColumnTicks.
  ///
  /// In en, this message translates to:
  /// **'Today ticks'**
  String get usageColumnTicks;

  /// No description provided for @usageNote.
  ///
  /// In en, this message translates to:
  /// **'Active: accounts that used the app that day. Today ticks: the share of them that ticked a row of the Today list.'**
  String get usageNote;

  /// No description provided for @usageKindsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get usageKindsTitle;

  /// No description provided for @usageColumnWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get usageColumnWeek;

  /// No description provided for @usageColumnMonth.
  ///
  /// In en, this message translates to:
  /// **'28 days'**
  String get usageColumnMonth;

  /// No description provided for @usageEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No usage yet'**
  String get usageEmptyTitle;

  /// No description provided for @usageEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Phones send their counts once a day, so each day shows up the day after.'**
  String get usageEmptyMessage;

  /// No description provided for @usageErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage'**
  String get usageErrorTitle;

  /// No description provided for @usageErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and try again.'**
  String get usageErrorMessage;

  /// No description provided for @usageKindTodayTick.
  ///
  /// In en, this message translates to:
  /// **'Today rows ticked'**
  String get usageKindTodayTick;

  /// No description provided for @usageKindCareLogged.
  ///
  /// In en, this message translates to:
  /// **'Care logged'**
  String get usageKindCareLogged;

  /// No description provided for @usageKindDoseRecorded.
  ///
  /// In en, this message translates to:
  /// **'Doses recorded'**
  String get usageKindDoseRecorded;

  /// No description provided for @usageKindRecordAdded.
  ///
  /// In en, this message translates to:
  /// **'Health records added'**
  String get usageKindRecordAdded;

  /// No description provided for @usageKindQuickLog.
  ///
  /// In en, this message translates to:
  /// **'Quick logs'**
  String get usageKindQuickLog;

  /// No description provided for @usageKindMeetupJoined.
  ///
  /// In en, this message translates to:
  /// **'Meetups joined'**
  String get usageKindMeetupJoined;

  /// No description provided for @usageKindMeetupPosted.
  ///
  /// In en, this message translates to:
  /// **'Meetups posted'**
  String get usageKindMeetupPosted;

  /// No description provided for @usageKindPostCreated.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get usageKindPostCreated;

  /// No description provided for @usageKindCommentCreated.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get usageKindCommentCreated;

  /// No description provided for @usageKindChatMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Chat messages'**
  String get usageKindChatMessageSent;

  /// No description provided for @usageKindDealOpened.
  ///
  /// In en, this message translates to:
  /// **'Deals opened'**
  String get usageKindDealOpened;

  /// No description provided for @usageKindDealShared.
  ///
  /// In en, this message translates to:
  /// **'Deals shared'**
  String get usageKindDealShared;

  /// No description provided for @usageKindBasketBoughtAgain.
  ///
  /// In en, this message translates to:
  /// **'Bought again'**
  String get usageKindBasketBoughtAgain;

  /// No description provided for @usageKindExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'Expenses added'**
  String get usageKindExpenseAdded;

  /// No description provided for @usageKindEmergencyOpened.
  ///
  /// In en, this message translates to:
  /// **'Emergency opened'**
  String get usageKindEmergencyOpened;

  /// No description provided for @usageKindFindVetOpened.
  ///
  /// In en, this message translates to:
  /// **'Find a vet opened'**
  String get usageKindFindVetOpened;

  /// No description provided for @usageKindHouseholdInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Household invites'**
  String get usageKindHouseholdInviteSent;

  /// No description provided for @usageKindAppOpened.
  ///
  /// In en, this message translates to:
  /// **'App opened'**
  String get usageKindAppOpened;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About PetLoop'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

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
  /// **'Language, week, notifications'**
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
  /// **'Your week: the first day and the weekdays. The Health schedule follows this choice.'**
  String get settingsWeekNote;

  /// No description provided for @settingsSavedNote.
  ///
  /// In en, this message translates to:
  /// **'These settings are saved on this phone.'**
  String get settingsSavedNote;

  /// Under 'Language' on the Settings page when the app follows the phone; {language} is the phone's language in its own letters (English, עברית).
  ///
  /// In en, this message translates to:
  /// **'Follow the phone · {language}'**
  String settingsLanguageFollowing(String language);

  /// Under 'Week' on the Settings page: the first day of the week (Sunday) and the weekdays (Sunday to Thursday).
  ///
  /// In en, this message translates to:
  /// **'Starts on {day} · {weekdays}'**
  String settingsWeekSummary(String day, String weekdays);

  /// No description provided for @legalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get legalTerms;

  /// No description provided for @legalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacy;

  /// No description provided for @legalOpensInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Opens in the browser.'**
  String get legalOpensInBrowser;

  /// No description provided for @legalOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'The page could not be opened. Try again later.'**
  String get legalOpenFailed;

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
  String homeGoal(String goal);

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
