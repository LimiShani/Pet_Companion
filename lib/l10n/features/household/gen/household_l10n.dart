import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'household_l10n_en.dart';
import 'household_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of HouseholdL10n
/// returned by `HouseholdL10n.of(context)`.
///
/// Applications need to include `HouseholdL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/household_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: HouseholdL10n.localizationsDelegates,
///   supportedLocales: HouseholdL10n.supportedLocales,
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
/// be consistent with the languages listed in the HouseholdL10n.supportedLocales
/// property.
abstract class HouseholdL10n {
  HouseholdL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static HouseholdL10n of(BuildContext context) {
    return Localizations.of<HouseholdL10n>(context, HouseholdL10n)!;
  }

  static const LocalizationsDelegate<HouseholdL10n> delegate = _HouseholdL10nDelegate();

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

  /// The feature's name: the people of one home who share their pets. A row on the You page and the page's header.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get title;

  /// A household without a name of its own, named after its one pet.
  ///
  /// In en, this message translates to:
  /// **'{pet}\'s household'**
  String nameOnePet(String pet);

  /// No description provided for @nameTwoPets.
  ///
  /// In en, this message translates to:
  /// **'{first} & {second}\'s household'**
  String nameTwoPets(String first, String second);

  /// A household without a name, with no pets or more than two: named after its owner.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s household'**
  String nameOfPerson(String name);

  /// No description provided for @nameOurs.
  ///
  /// In en, this message translates to:
  /// **'Our household'**
  String get nameOurs;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String peopleCount(int count);

  /// No description provided for @petsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pets yet} =1{1 pet} other{{count} pets}}'**
  String petsCount(int count);

  /// The You page's Household row while nobody else has joined.
  ///
  /// In en, this message translates to:
  /// **'Share your pets\' care with the people at home'**
  String get youRowSolo;

  /// No description provided for @sectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get sectionPeople;

  /// No description provided for @sectionPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get sectionPets;

  /// No description provided for @roleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwner;

  /// No description provided for @roleCarer.
  ///
  /// In en, this message translates to:
  /// **'Carer'**
  String get roleCarer;

  /// No description provided for @invitedTag.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get invitedTag;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @joinedOn.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedOn(String date);

  /// No description provided for @invitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String invitedBy(String name);

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{ends today} =1{1 day left} other{{days} days left}}'**
  String daysLeft(int days);

  /// A row for an invitation code nobody has used yet.
  ///
  /// In en, this message translates to:
  /// **'Open invitation'**
  String get openInvitation;

  /// No description provided for @inviteSomeone.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteSomeone;

  /// No description provided for @haveCode.
  ///
  /// In en, this message translates to:
  /// **'I have an invitation code'**
  String get haveCode;

  /// No description provided for @soloLine.
  ///
  /// In en, this message translates to:
  /// **'Whoever you invite sees the same pets, logs meals, walks and doses, and gets the reminders.'**
  String get soloLine;

  /// No description provided for @petsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pets in this household yet.'**
  String get petsEmpty;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'The household\'s name'**
  String get renameTitle;

  /// No description provided for @renameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty to name it after its pets.'**
  String get renameHint;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave this household'**
  String get leave;

  /// No description provided for @leaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this household?'**
  String get leaveConfirmTitle;

  /// No description provided for @leaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Its pets will no longer show in your app. What you logged stays with them.'**
  String get leaveConfirmBody;

  /// No description provided for @leaveAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveAction;

  /// No description provided for @leftSnack.
  ///
  /// In en, this message translates to:
  /// **'You left the household.'**
  String get leftSnack;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove from the household'**
  String get remove;

  /// No description provided for @removeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeConfirmTitle(String name);

  /// No description provided for @removeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The household\'s pets will no longer show for {name}. What was logged stays.'**
  String removeConfirmBody(String name);

  /// No description provided for @removeAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAction;

  /// No description provided for @removedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer in the household.'**
  String removedSnack(String name);

  /// No description provided for @takeBack.
  ///
  /// In en, this message translates to:
  /// **'Take back the invitation'**
  String get takeBack;

  /// No description provided for @takenBackSnack.
  ///
  /// In en, this message translates to:
  /// **'Invitation taken back.'**
  String get takenBackSnack;

  /// No description provided for @inviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get inviteTitle;

  /// No description provided for @inviteCanTitle.
  ///
  /// In en, this message translates to:
  /// **'Whoever joins can:'**
  String get inviteCanTitle;

  /// No description provided for @inviteCan1.
  ///
  /// In en, this message translates to:
  /// **'See and edit care, medicines and health records'**
  String get inviteCan1;

  /// No description provided for @inviteCan2.
  ///
  /// In en, this message translates to:
  /// **'Log meals, walks and doses'**
  String get inviteCan2;

  /// No description provided for @inviteCan3.
  ///
  /// In en, this message translates to:
  /// **'Get the reminders'**
  String get inviteCan3;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get inviteCodeLabel;

  /// No description provided for @inviteValidity.
  ///
  /// In en, this message translates to:
  /// **'Works for 7 days, for one person.'**
  String get inviteValidity;

  /// No description provided for @inviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share the invitation'**
  String get inviteShare;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy the code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied.'**
  String get codeCopied;

  /// The message the inviter sends, usually over WhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Join {household} on PetLoop. Open {link} or enter the code {code} in PetLoop (You › Household).'**
  String inviteShareText(String household, String link, String code);

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a household'**
  String get joinTitle;

  /// No description provided for @joinCodeHint.
  ///
  /// In en, this message translates to:
  /// **'For example KELY-7Q4M'**
  String get joinCodeHint;

  /// No description provided for @joinContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get joinContinue;

  /// No description provided for @joinInvitationFrom.
  ///
  /// In en, this message translates to:
  /// **'An invitation from {name}'**
  String joinInvitationFrom(String name);

  /// No description provided for @joinAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinAction;

  /// No description provided for @joinDecline.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get joinDecline;

  /// No description provided for @joinedSnack.
  ///
  /// In en, this message translates to:
  /// **'You joined the household.'**
  String get joinedSnack;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t lead to an invitation. Check it and try again.'**
  String get errNotFound;

  /// No description provided for @errExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has ended. Ask for a new one.'**
  String get errExpired;

  /// No description provided for @errUsed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already used.'**
  String get errUsed;

  /// No description provided for @errMember.
  ///
  /// In en, this message translates to:
  /// **'This household is already in your list.'**
  String get errMember;

  /// No description provided for @errFull.
  ///
  /// In en, this message translates to:
  /// **'This household is full (10 people).'**
  String get errFull;

  /// No description provided for @errSlowDown.
  ///
  /// In en, this message translates to:
  /// **'That was quick! Try again in a little while.'**
  String get errSlowDown;

  /// No description provided for @errNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Households aren\'t available for this account.'**
  String get errNotAvailable;

  /// No description provided for @errOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the household\'s owner can do that.'**
  String get errOwnerOnly;

  /// No description provided for @errName.
  ///
  /// In en, this message translates to:
  /// **'That name is too long.'**
  String get errName;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach PetLoop. Try again.'**
  String get errOffline;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your household.'**
  String get loadFailed;

  /// Under a shared pet's name on Home: the other people who look after it, e.g. 'with Dana, Noa'.
  ///
  /// In en, this message translates to:
  /// **'with {names}'**
  String heroWith(String names);

  /// No description provided for @heroWithLabel.
  ///
  /// In en, this message translates to:
  /// **'Looked after with {names}'**
  String heroWithLabel(String names);
}

class _HouseholdL10nDelegate extends LocalizationsDelegate<HouseholdL10n> {
  const _HouseholdL10nDelegate();

  @override
  Future<HouseholdL10n> load(Locale locale) {
    return SynchronousFuture<HouseholdL10n>(lookupHouseholdL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_HouseholdL10nDelegate old) => false;
}

HouseholdL10n lookupHouseholdL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return HouseholdL10nEn();
    case 'he': return HouseholdL10nHe();
  }

  throw FlutterError(
    'HouseholdL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
