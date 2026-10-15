// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'household_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class HouseholdL10nEn extends HouseholdL10n {
  HouseholdL10nEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'Household';

  @override
  String nameOnePet(String pet) {
    return '$pet\'s household';
  }

  @override
  String nameTwoPets(String first, String second) {
    return '$first & $second\'s household';
  }

  @override
  String nameOfPerson(String name) {
    return '$name\'s household';
  }

  @override
  String get nameOurs => 'Our household';

  @override
  String peopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String petsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pets',
      one: '1 pet',
      zero: 'No pets yet',
    );
    return '$_temp0';
  }

  @override
  String get youRowSolo => 'Share your pets\' care with the people at home';

  @override
  String get sectionPeople => 'People';

  @override
  String get sectionPets => 'Pets';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleCarer => 'Carer';

  @override
  String get invitedTag => 'Invited';

  @override
  String get you => 'You';

  @override
  String joinedOn(String date) {
    return 'Joined $date';
  }

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'ends today',
    );
    return '$_temp0';
  }

  @override
  String get openInvitation => 'Open invitation';

  @override
  String get inviteSomeone => 'Invite someone';

  @override
  String get haveCode => 'I have an invitation code';

  @override
  String get soloLine => 'Whoever you invite sees the same pets, logs meals, walks and doses, and gets the reminders.';

  @override
  String get petsEmpty => 'No pets in this household yet.';

  @override
  String get rename => 'Rename';

  @override
  String get renameTitle => 'The household\'s name';

  @override
  String get renameHint => 'Leave it empty to name it after its pets.';

  @override
  String get leave => 'Leave this household';

  @override
  String get leaveConfirmTitle => 'Leave this household?';

  @override
  String get leaveConfirmBody => 'Its pets will no longer show in your app. What you logged stays with them.';

  @override
  String get leaveAction => 'Leave';

  @override
  String get leftSnack => 'You left the household.';

  @override
  String get remove => 'Remove from the household';

  @override
  String removeConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String removeConfirmBody(String name) {
    return 'The household\'s pets will no longer show for $name. What was logged stays.';
  }

  @override
  String get removeAction => 'Remove';

  @override
  String removedSnack(String name) {
    return '$name is no longer in the household.';
  }

  @override
  String get takeBack => 'Take back the invitation';

  @override
  String get takenBackSnack => 'Invitation taken back.';

  @override
  String get inviteTitle => 'Invite someone';

  @override
  String get inviteCanTitle => 'Whoever joins can:';

  @override
  String get inviteCan1 => 'See and edit care, medicines and health records';

  @override
  String get inviteCan2 => 'Log meals, walks and doses';

  @override
  String get inviteCan3 => 'Get the reminders';

  @override
  String get inviteCodeLabel => 'Invitation code';

  @override
  String get inviteValidity => 'Works for 7 days, for one person.';

  @override
  String get inviteShare => 'Share the invitation';

  @override
  String get copyCode => 'Copy the code';

  @override
  String get codeCopied => 'Code copied.';

  @override
  String inviteShareText(String household, String link, String code) {
    return 'Join $household on PetLoop. Open $link or enter the code $code in PetLoop (You › Household).';
  }

  @override
  String get joinTitle => 'Join a household';

  @override
  String get joinCodeHint => 'For example KELY-7Q4M';

  @override
  String get joinContinue => 'Continue';

  @override
  String joinInvitationFrom(String name) {
    return 'An invitation from $name';
  }

  @override
  String get joinAction => 'Join';

  @override
  String get joinDecline => 'No thanks';

  @override
  String get joinedSnack => 'You joined the household.';

  @override
  String get errNotFound => 'That code doesn\'t lead to an invitation. Check it and try again.';

  @override
  String get errExpired => 'This invitation has ended. Ask for a new one.';

  @override
  String get errUsed => 'This invitation was already used.';

  @override
  String get errMember => 'This household is already in your list.';

  @override
  String get errFull => 'This household is full (10 people).';

  @override
  String get errSlowDown => 'That was quick! Try again in a little while.';

  @override
  String get errNotAvailable => 'Households aren\'t available for this account.';

  @override
  String get errOwnerOnly => 'Only the household\'s owner can do that.';

  @override
  String get errName => 'That name is too long.';

  @override
  String get errOffline => 'We couldn\'t reach PetLoop. Try again.';

  @override
  String get loadFailed => 'We couldn\'t load your household.';

  @override
  String heroWith(String names) {
    return 'with $names';
  }

  @override
  String heroWithLabel(String names) {
    return 'Looked after with $names';
  }
}
