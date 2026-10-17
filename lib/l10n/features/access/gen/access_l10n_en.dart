// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'access_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AccessL10nEn extends AccessL10n {
  AccessL10nEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Feature access';

  @override
  String get refresh => 'Refresh';

  @override
  String get tabUsers => 'Users';

  @override
  String get tabGroups => 'Groups';

  @override
  String get tabFeatures => 'Features';

  @override
  String get tabAudit => 'Audit';

  @override
  String get loadFailed => 'Could not load the access settings. Try again.';

  @override
  String get retry => 'Retry';

  @override
  String get user => 'User';

  @override
  String get groupMembership => 'Group membership';

  @override
  String get individualOverrides => 'Individual overrides';

  @override
  String get group => 'Group';

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get create => 'Create';

  @override
  String get featuresNote => 'A disabled feature is blocked for everyone. Individual rules override group rules; group denial wins over group allowance.';

  @override
  String get publicVetSearch => 'Public vet search';

  @override
  String get ruleInherit => 'Inherit';

  @override
  String get ruleAllow => 'Allow';

  @override
  String get ruleDeny => 'Deny';

  @override
  String get allowed => 'Allowed';

  @override
  String get blocked => 'Blocked';

  @override
  String ruleSummary(String status, String reason) {
    return '$status · $reason';
  }

  @override
  String capabilityLabel(String feature, String action) {
    return '$feature · $action';
  }

  @override
  String get featurePets => 'Pet profiles';

  @override
  String get featureCare => 'Daily care';

  @override
  String get featureHealth => 'Health';

  @override
  String get featureHealthRecords => 'Health records';

  @override
  String get featureHealthSchedule => 'Health schedule';

  @override
  String get featureHealthEmergency => 'Emergency tools';

  @override
  String get featureCommunity => 'Community';

  @override
  String get featureCommunityFeed => 'Community feed';

  @override
  String get featureCommunityChat => 'Community chat';

  @override
  String get featureCommunityGuides => 'Guides';

  @override
  String get featureCommunityParks => 'Dog parks';

  @override
  String get featureCommunityMeetups => 'Walk and play partners';

  @override
  String get featureHousehold => 'Household';

  @override
  String get featureSafety => 'Safety';

  @override
  String get featureDeals => 'Deals';

  @override
  String get featureBudget => 'Budget';

  @override
  String get featureBasket => 'Basket';

  @override
  String get featureFirstDays => 'First days';

  @override
  String get featureFindVet => 'Find a vet';

  @override
  String get actionView => 'View';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionExport => 'Export';

  @override
  String get actionPost => 'Post';

  @override
  String get actionSend => 'Send';

  @override
  String get actionShare => 'Share';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionAdmin => 'Review directory';

  @override
  String get actionModerate => 'Moderate reports';

  @override
  String get actionSuggest => 'Suggest changes';

  @override
  String get actionReview => 'Review suggestions';

  @override
  String get actionPrivate => 'Private chats';

  @override
  String get actionLists => 'Urgent signs and foods lists';

  @override
  String get actionLost => 'Lost mode';

  @override
  String get auditIntroDemo => 'Demo history resets when the app closes. Tap an entry for details.';

  @override
  String get auditIntroSaved => 'Saved administration history. Tap an entry for details.';

  @override
  String get auditActorFilter => 'Administrator email or ID';

  @override
  String get auditActionType => 'Action type';

  @override
  String get auditAllActions => 'All actions';

  @override
  String get auditAnyDate => 'Any date';

  @override
  String get auditSearch => 'Search history';

  @override
  String get auditClearFilters => 'Clear filters';

  @override
  String get auditLoadFailed => 'Could not load saved history. Check the connection and migration 0017.';

  @override
  String get auditEmpty => 'No administration actions found.';

  @override
  String get auditLoadOlder => 'Load older actions';

  @override
  String get auditSystemActor => 'System / database owner';

  @override
  String auditEntryNumber(int id) {
    return 'Entry #$id';
  }

  @override
  String get auditBefore => 'Before';

  @override
  String get auditAfter => 'After';

  @override
  String get auditNoPreviousValue => 'No previous value';

  @override
  String get auditRemoved => 'Removed';

  @override
  String get categoryFeatureSettings => 'Feature settings';

  @override
  String get categoryGroups => 'Groups';

  @override
  String get categoryGroupMembership => 'Group membership';

  @override
  String get categoryUserRules => 'Individual permissions';

  @override
  String get categoryGroupRules => 'Group permissions';

  @override
  String get categoryAdmins => 'Administrators';

  @override
  String get categoryCapabilities => 'Capability catalog';

  @override
  String get categoryVetDirectory => 'Vet directory review';

  @override
  String get unavailableTitle => 'Could not load account permissions';

  @override
  String get unavailableMessage => 'Check the connection and try again.';

  @override
  String get signOut => 'Sign out';

  @override
  String get gateTitle => 'Feature access';

  @override
  String get gateUnavailable => 'Feature unavailable';

  @override
  String get gateMessage => 'Your account does not have access to this feature right now.';

  @override
  String get featureCommunityHazards => 'Hazard reports';
}
