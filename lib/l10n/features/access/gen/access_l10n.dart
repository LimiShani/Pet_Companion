import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'access_l10n_en.dart';
import 'access_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AccessL10n
/// returned by `AccessL10n.of(context)`.
///
/// Applications need to include `AccessL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/access_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AccessL10n.localizationsDelegates,
///   supportedLocales: AccessL10n.supportedLocales,
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
/// be consistent with the languages listed in the AccessL10n.supportedLocales
/// property.
abstract class AccessL10n {
  AccessL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AccessL10n of(BuildContext context) {
    return Localizations.of<AccessL10n>(context, AccessL10n)!;
  }

  static const LocalizationsDelegate<AccessL10n> delegate = _AccessL10nDelegate();

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

  /// The side-menu entry and the header of the administration screen.
  ///
  /// In en, this message translates to:
  /// **'Feature access'**
  String get title;

  /// Tooltip of the header button that reloads the administration data.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @tabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get tabUsers;

  /// No description provided for @tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get tabGroups;

  /// No description provided for @tabFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get tabFeatures;

  /// No description provided for @tabAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get tabAudit;

  /// Shown when the administration data could not be loaded or a change could not be saved.
  ///
  /// In en, this message translates to:
  /// **'Could not load the access settings. Try again.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Label of the drop-down that picks the user to manage.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @groupMembership.
  ///
  /// In en, this message translates to:
  /// **'Group membership'**
  String get groupMembership;

  /// Heading of a user's own permission rules, which override the group rules.
  ///
  /// In en, this message translates to:
  /// **'Individual overrides'**
  String get individualOverrides;

  /// Label of the drop-down that picks the group to manage.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @featuresNote.
  ///
  /// In en, this message translates to:
  /// **'A disabled feature is blocked for everyone. Individual rules override group rules; group denial wins over group allowance.'**
  String get featuresNote;

  /// Switch that lets people search for a vet without an account.
  ///
  /// In en, this message translates to:
  /// **'Public vet search'**
  String get publicVetSearch;

  /// No description provided for @ruleInherit.
  ///
  /// In en, this message translates to:
  /// **'Inherit'**
  String get ruleInherit;

  /// No description provided for @ruleAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get ruleAllow;

  /// No description provided for @ruleDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get ruleDeny;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// Under a capability: whether the user may use it (allowed/blocked) and why.
  ///
  /// In en, this message translates to:
  /// **'{status} · {reason}'**
  String ruleSummary(String status, String reason);

  /// A capability named by its feature and the action it allows, e.g. "Health · Edit".
  ///
  /// In en, this message translates to:
  /// **'{feature} · {action}'**
  String capabilityLabel(String feature, String action);

  /// No description provided for @featurePets.
  ///
  /// In en, this message translates to:
  /// **'Pet profiles'**
  String get featurePets;

  /// No description provided for @featureCare.
  ///
  /// In en, this message translates to:
  /// **'Daily care'**
  String get featureCare;

  /// No description provided for @featureHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get featureHealth;

  /// No description provided for @featureHealthRecords.
  ///
  /// In en, this message translates to:
  /// **'Health records'**
  String get featureHealthRecords;

  /// No description provided for @featureHealthSchedule.
  ///
  /// In en, this message translates to:
  /// **'Health schedule'**
  String get featureHealthSchedule;

  /// No description provided for @featureHealthEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency tools'**
  String get featureHealthEmergency;

  /// No description provided for @featureCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get featureCommunity;

  /// No description provided for @featureCommunityFeed.
  ///
  /// In en, this message translates to:
  /// **'Community feed'**
  String get featureCommunityFeed;

  /// No description provided for @featureCommunityChat.
  ///
  /// In en, this message translates to:
  /// **'Community chat'**
  String get featureCommunityChat;

  /// No description provided for @featureCommunityGuides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get featureCommunityGuides;

  /// No description provided for @featureCommunityParks.
  ///
  /// In en, this message translates to:
  /// **'Dog parks'**
  String get featureCommunityParks;

  /// No description provided for @featureCommunityMeetups.
  ///
  /// In en, this message translates to:
  /// **'Walk and play partners'**
  String get featureCommunityMeetups;

  /// No description provided for @featureHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get featureHousehold;

  /// No description provided for @featureDeals.
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get featureDeals;

  /// No description provided for @featureBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get featureBudget;

  /// No description provided for @featureBasket.
  ///
  /// In en, this message translates to:
  /// **'Basket'**
  String get featureBasket;

  /// No description provided for @featureFirstDays.
  ///
  /// In en, this message translates to:
  /// **'First days'**
  String get featureFirstDays;

  /// No description provided for @featureFindVet.
  ///
  /// In en, this message translates to:
  /// **'Find a vet'**
  String get featureFindVet;

  /// No description provided for @actionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get actionView;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get actionExport;

  /// No description provided for @actionPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get actionPost;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionAdmin.
  ///
  /// In en, this message translates to:
  /// **'Review directory'**
  String get actionAdmin;

  /// No description provided for @actionModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate reports'**
  String get actionModerate;

  /// No description provided for @actionSuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest changes'**
  String get actionSuggest;

  /// No description provided for @actionReview.
  ///
  /// In en, this message translates to:
  /// **'Review suggestions'**
  String get actionReview;

  /// No description provided for @actionPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private chats'**
  String get actionPrivate;

  /// No description provided for @auditIntroDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo history resets when the app closes. Tap an entry for details.'**
  String get auditIntroDemo;

  /// No description provided for @auditIntroSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved administration history. Tap an entry for details.'**
  String get auditIntroSaved;

  /// No description provided for @auditActorFilter.
  ///
  /// In en, this message translates to:
  /// **'Administrator email or ID'**
  String get auditActorFilter;

  /// No description provided for @auditActionType.
  ///
  /// In en, this message translates to:
  /// **'Action type'**
  String get auditActionType;

  /// No description provided for @auditAllActions.
  ///
  /// In en, this message translates to:
  /// **'All actions'**
  String get auditAllActions;

  /// No description provided for @auditAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get auditAnyDate;

  /// No description provided for @auditSearch.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get auditSearch;

  /// No description provided for @auditClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get auditClearFilters;

  /// No description provided for @auditLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved history. Check the connection and migration 0017.'**
  String get auditLoadFailed;

  /// No description provided for @auditEmpty.
  ///
  /// In en, this message translates to:
  /// **'No administration actions found.'**
  String get auditEmpty;

  /// No description provided for @auditLoadOlder.
  ///
  /// In en, this message translates to:
  /// **'Load older actions'**
  String get auditLoadOlder;

  /// Who made a change when no signed-in administrator did.
  ///
  /// In en, this message translates to:
  /// **'System / database owner'**
  String get auditSystemActor;

  /// No description provided for @auditEntryNumber.
  ///
  /// In en, this message translates to:
  /// **'Entry #{id}'**
  String auditEntryNumber(int id);

  /// No description provided for @auditBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get auditBefore;

  /// No description provided for @auditAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get auditAfter;

  /// No description provided for @auditNoPreviousValue.
  ///
  /// In en, this message translates to:
  /// **'No previous value'**
  String get auditNoPreviousValue;

  /// No description provided for @auditRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get auditRemoved;

  /// No description provided for @categoryFeatureSettings.
  ///
  /// In en, this message translates to:
  /// **'Feature settings'**
  String get categoryFeatureSettings;

  /// No description provided for @categoryGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get categoryGroups;

  /// No description provided for @categoryGroupMembership.
  ///
  /// In en, this message translates to:
  /// **'Group membership'**
  String get categoryGroupMembership;

  /// No description provided for @categoryUserRules.
  ///
  /// In en, this message translates to:
  /// **'Individual permissions'**
  String get categoryUserRules;

  /// No description provided for @categoryGroupRules.
  ///
  /// In en, this message translates to:
  /// **'Group permissions'**
  String get categoryGroupRules;

  /// No description provided for @categoryAdmins.
  ///
  /// In en, this message translates to:
  /// **'Administrators'**
  String get categoryAdmins;

  /// No description provided for @categoryCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Capability catalog'**
  String get categoryCapabilities;

  /// No description provided for @categoryVetDirectory.
  ///
  /// In en, this message translates to:
  /// **'Vet directory review'**
  String get categoryVetDirectory;

  /// Full-screen message when the app cannot find out what the account may use.
  ///
  /// In en, this message translates to:
  /// **'Could not load account permissions'**
  String get unavailableTitle;

  /// No description provided for @unavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and try again.'**
  String get unavailableMessage;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// Header of the page shown instead of a feature the account may not use.
  ///
  /// In en, this message translates to:
  /// **'Feature access'**
  String get gateTitle;

  /// No description provided for @gateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Feature unavailable'**
  String get gateUnavailable;

  /// No description provided for @gateMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have access to this feature right now.'**
  String get gateMessage;
}

class _AccessL10nDelegate extends LocalizationsDelegate<AccessL10n> {
  const _AccessL10nDelegate();

  @override
  Future<AccessL10n> load(Locale locale) {
    return SynchronousFuture<AccessL10n>(lookupAccessL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AccessL10nDelegate old) => false;
}

AccessL10n lookupAccessL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AccessL10nEn();
    case 'he': return AccessL10nHe();
  }

  throw FlutterError(
    'AccessL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
