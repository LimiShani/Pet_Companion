// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pet Companion';

  @override
  String get navHome => 'Home';

  @override
  String get navHealth => 'Health';

  @override
  String get navCommunity => 'Community';

  @override
  String get navStore => 'Store';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonShare => 'Share';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonToday => 'Today';

  @override
  String get commonTomorrow => 'Tomorrow';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get petSelectorAdd => 'Add a pet';

  @override
  String placeholderComingSoon(String title) {
    return '$title coming soon';
  }

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInSubtitle => 'Sign in to see how your pets are doing today.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'Your password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNewHere => 'New here?';

  @override
  String get authCreateAnAccount => 'Create an account';

  @override
  String get authForgotNeedsEmail => 'Enter your email address above first, then tap Forgot password.';

  @override
  String authResetSent(String email) {
    return 'If an account uses $email, a reset link is on its way.';
  }

  @override
  String get authResetFailed => 'Could not send a reset link. Please try again.';

  @override
  String get authCreateTitle => 'Create your account';

  @override
  String get authCreateSubtitle => 'One account for all of your pets.';

  @override
  String get authYourName => 'Your name';

  @override
  String get authYourNameHint => 'What should we call you?';

  @override
  String authPasswordMinHint(int count) {
    return 'At least $count characters';
  }

  @override
  String get authRepeatPassword => 'Repeat password';

  @override
  String get authRepeatPasswordHint => 'Same as above';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authTerms => 'By creating an account you agree to the Terms of Use and Privacy Policy.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get validEmailEmpty => 'Enter your email address.';

  @override
  String get validEmailInvalid => 'That does not look like an email address.';

  @override
  String get validPasswordEmpty => 'Enter your password.';

  @override
  String validMinLength(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String get validConfirmEmpty => 'Repeat your password.';

  @override
  String get validConfirmMismatch => 'The passwords do not match.';

  @override
  String get validNameEmpty => 'Tell us what to call you.';

  @override
  String get authErrNoAccount => 'No account uses that email address.';

  @override
  String get authErrWrongPassword => 'Incorrect password. Please try again.';

  @override
  String get authErrEmailTaken => 'An account with that email already exists.';

  @override
  String get authErrInvalidCredentials => 'Incorrect email or password. Please try again.';

  @override
  String get authErrEmailNotConfirmed => 'Please confirm your email address first. Check your inbox for the link.';

  @override
  String get authErrRateLimited => 'Too many attempts. Please wait a moment and try again.';

  @override
  String get authErrWeakPassword => 'Please choose a longer password.';

  @override
  String get authErrNetwork => 'Cannot reach the server. Check your connection and try again.';

  @override
  String get authErrSignInIncomplete => 'Sign in did not return a user. Please try again.';

  @override
  String get authErrSignUpIncomplete => 'Sign up did not return a user. Please try again.';

  @override
  String get authErrConfirmEmailSent => 'Almost there: open the confirmation email we just sent, then sign in.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountLanguage => 'Language';

  @override
  String get languageFollowPhone => 'Follow the phone';

  @override
  String languageFollowPhoneNow(String language) {
    return 'Now: $language';
  }

  @override
  String get languagePreviewTag => 'Preview';

  @override
  String get languageNote => 'You can change this at any time. What people write stays in the language it was written in.';

  @override
  String languageSwitchTo(String language) {
    return 'Change the language: $language';
  }

  @override
  String get menuMyPets => 'My pets';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSummary => 'Language, week';

  @override
  String get settingsWeek => 'Week';

  @override
  String get settingsFirstDay => 'First day of the week';

  @override
  String get settingsDaySaturday => 'Saturday';

  @override
  String get settingsDaySunday => 'Sunday';

  @override
  String get settingsDayMonday => 'Monday';

  @override
  String get settingsWeekdays => 'Weekdays';

  @override
  String get settingsWeekdaysSunThu => 'Sunday to Thursday';

  @override
  String get settingsWeekdaysMonFri => 'Monday to Friday';

  @override
  String settingsWeekendIs(String days) {
    return 'The weekend: $days';
  }

  @override
  String get settingsWeekNote => 'Sets the order of the day chips and what \"Weekdays\" and \"Weekends\" mean in the schedule. The dimmed days are the weekend.';

  @override
  String get settingsSavedNote => 'These settings are saved on this phone.';

  @override
  String get homeMenu => 'Menu';

  @override
  String get homeAccount => 'Account';

  @override
  String homePetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pets',
      one: '1 pet',
    );
    return '$_temp0';
  }

  @override
  String get homeBreed => 'Breed';

  @override
  String get homeAge => 'Age';

  @override
  String get homeWeight => 'Weight';

  @override
  String homeWeightKg(String value) {
    return '$value kg';
  }

  @override
  String get homeFeeding => 'Feeding';

  @override
  String get homeNoGoal => 'No goal set';

  @override
  String homeGoal(int goal) {
    return 'Goal $goal cal/day';
  }

  @override
  String get homeCalToday => 'cal today';

  @override
  String get homeCaloriesSemantics => 'Calories toward daily goal';

  @override
  String homeCaloriesOfGoal(int eaten, int goal) {
    return '$eaten of $goal';
  }

  @override
  String homeNextFeeding(String time) {
    return 'Next feeding · $time';
  }

  @override
  String get homeNextFeedingUnset => 'Next feeding · not set';

  @override
  String get homeActivity => 'Activity';

  @override
  String get homeSteps => 'Steps';

  @override
  String get homeActivityTime => 'Activity time';

  @override
  String homeNextWalk(String time) {
    return 'Next walk · $time';
  }

  @override
  String get homeNextWalkUnset => 'Next walk · not set';

  @override
  String get homeHealth => 'Health';

  @override
  String get homeUpcoming => 'Upcoming';

  @override
  String get homeNoHealthEvents => 'No health events yet';
}
