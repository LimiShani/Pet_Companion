// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'meetups_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MeetupsL10nEn extends MeetupsL10n {
  MeetupsL10nEn([String locale = 'en']) : super(locale);

  @override
  String get areaQuestion => 'Where do you go out?';

  @override
  String get problemOutsideRegion => 'Partners are listed in Israel for now. Pick a city in Israel.';

  @override
  String get safetyStrip => 'Meet in a public place and don\'t share a home address.';

  @override
  String get newAd => 'New ad';

  @override
  String get myAds => 'My ads';

  @override
  String myAdsCount(int count) {
    return 'My ads ($count)';
  }

  @override
  String get kindAll => 'All';

  @override
  String get kindWalk => 'Walk';

  @override
  String get kindPlay => 'Play';

  @override
  String get whenToday => 'Today';

  @override
  String get whenThisWeek => 'This week';

  @override
  String get whenRecurring => 'Regular';

  @override
  String get atMyParks => 'At my parks';

  @override
  String get filters => 'Filters';

  @override
  String filtersCount(int count) {
    return 'Filters · $count';
  }

  @override
  String filtersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filters: $count on',
      one: 'Filters: 1 on',
      zero: 'Filters: none on',
    );
    return '$_temp0';
  }

  @override
  String get filtersTitle => 'Which ads to show';

  @override
  String get filterKind => 'Walk or play';

  @override
  String get filterAnimal => 'Animal';

  @override
  String get filterWhen => 'When';

  @override
  String get filterWhere => 'Where';

  @override
  String get filtersClearAll => 'Clear all';

  @override
  String filtersShow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count ads',
      one: 'Show 1 ad',
      zero: 'No ads to show',
    );
    return '$_temp0';
  }

  @override
  String get filtersDone => 'Done';

  @override
  String get sampleAds => 'Sample ads';

  @override
  String get emptyTitle => 'No ads around here yet';

  @override
  String get emptyBody => 'Post the first one, and members nearby can answer it.';

  @override
  String get emptyFiltered => 'No ads match these filters.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get lookFurther => 'Look up to 25 km';

  @override
  String get loadFailed => 'We could not load the ads.';

  @override
  String get noPet => 'Without a pet';

  @override
  String get sizeSmall => 'small';

  @override
  String get sizeMedium => 'medium-sized';

  @override
  String get sizeLarge => 'large';

  @override
  String suitsLine(String sizes) {
    return 'For $sizes dogs';
  }

  @override
  String get suitsSmall => 'small';

  @override
  String get suitsMedium => 'medium';

  @override
  String get suitsLarge => 'large';

  @override
  String suitsTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String distanceAbout(String distance) {
    return 'about $distance';
  }

  @override
  String get distanceNear => 'under 1 km';

  @override
  String answers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answers',
      one: '1 answer',
      zero: 'No answers yet',
    );
    return '$_temp0';
  }

  @override
  String get join => 'I want to join';

  @override
  String get answeredTag => 'You answered';

  @override
  String get openChat => 'Open the chat';

  @override
  String get yourAd => 'Your ad';

  @override
  String get manage => 'Manage';

  @override
  String get hiddenTag => 'Hidden after reports';

  @override
  String get endedTag => 'Ended';

  @override
  String get closedTag => 'Closed';

  @override
  String get more => 'More';

  @override
  String get menuReport => 'Report ad';

  @override
  String menuBlock(String name) {
    return 'Block $name';
  }

  @override
  String get reportTitle => 'Report this ad?';

  @override
  String get reportBody => 'Tell us what is wrong. After three reports an ad is hidden until a moderator looks at it.';

  @override
  String get reportThanks => 'Thanks, the ad was reported.';

  @override
  String get dayPartMorning => 'Morning';

  @override
  String get dayPartNoon => 'Noon';

  @override
  String get dayPartEvening => 'Evening';

  @override
  String get everyDay => 'Every day';

  @override
  String get weekdays => 'Weekdays';

  @override
  String get weekends => 'Weekends';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get formNewTitle => 'New ad';

  @override
  String get formEditTitle => 'Edit ad';

  @override
  String get withWhom => 'With whom?';

  @override
  String get whatQ => 'What?';

  @override
  String get whereQ => 'Where?';

  @override
  String get wherePark => 'A park';

  @override
  String get whereOther => 'Other place';

  @override
  String get choosePark => 'Choose a park';

  @override
  String get changePark => 'Change';

  @override
  String get parkRequired => 'Choose a park, or another place.';

  @override
  String get cityLabel => 'City';

  @override
  String get placeLabel => 'Where exactly?';

  @override
  String get placeHint => 'A public place, like the entrance to Yarkon Park';

  @override
  String get placeHelp => 'No home addresses.';

  @override
  String get placeRequired => 'Pick a city and say where.';

  @override
  String get whenQ => 'When?';

  @override
  String get once => 'Once';

  @override
  String get weekly => 'Every week';

  @override
  String get dateLabel => 'Date';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get hoursProblem => 'The meeting ends after it starts, within 12 hours.';

  @override
  String get pastProblem => 'That time is already over.';

  @override
  String get tooFarProblem => 'Up to 60 days ahead.';

  @override
  String get daysProblem => 'Pick at least one day.';

  @override
  String get partQ => 'Part of the day';

  @override
  String get suitsQ => 'Suits… (optional)';

  @override
  String get sizeAny => 'Any size';

  @override
  String get sizeSmallChip => 'Small';

  @override
  String get sizeMediumChip => 'Medium';

  @override
  String get sizeLargeChip => 'Large';

  @override
  String get noteLabel => 'A few words';

  @override
  String get noteHint => 'For example: a calm hour-long walk, all sizes welcome';

  @override
  String get post => 'Post';

  @override
  String get save => 'Save';

  @override
  String get posted => 'Your ad is up.';

  @override
  String get saved => 'Saved.';

  @override
  String get recurringNote => 'A regular ad stays up for 30 days, then it can be renewed.';

  @override
  String get limitsNote => 'Up to 3 new ads a day and 5 open at once.';

  @override
  String get errRateLimited => 'That\'s three new ads today. Try again tomorrow.';

  @override
  String get errTooManyOpen => 'There are five open ads already. Close one to post another.';

  @override
  String get errNotOpen => 'This ad is no longer open.';

  @override
  String get errBlocked => 'This ad can\'t be answered.';

  @override
  String get errInvalid => 'Something in the ad no longer fits (the park or the time). Check it and try again.';

  @override
  String get errUnavailable => 'No connection. Try again in a moment.';

  @override
  String get errOther => 'That didn\'t work. Try again.';

  @override
  String joinTitle(String name) {
    return 'Message to $name';
  }

  @override
  String joinBody(String name) {
    return 'A private chat opens between the two of you. $name gets a notification when you send the message.';
  }

  @override
  String get whoComing => 'Who\'s coming?';

  @override
  String get justMe => 'Just me';

  @override
  String draftWalkPet(String name, String place, String pet) {
    return 'Hi $name, I saw your walk ad ($place). I\'d love to join with $pet.';
  }

  @override
  String draftWalk(String name, String place) {
    return 'Hi $name, I saw your walk ad ($place). I\'d love to join.';
  }

  @override
  String draftPlayPet(String name, String place, String pet) {
    return 'Hi $name, I saw your playdate ad ($place). I\'d love to join with $pet.';
  }

  @override
  String draftPlay(String name, String place) {
    return 'Hi $name, I saw your playdate ad ($place). I\'d love to join.';
  }

  @override
  String get joinMessageLabel => 'Your message';

  @override
  String get joinTip => 'The first time, meet in an open place you both know.';

  @override
  String get joinSend => 'Open the chat with this message';

  @override
  String get edit => 'Edit';

  @override
  String get closeAd => 'Found someone, close it';

  @override
  String get closeConfirmTitle => 'Close this ad?';

  @override
  String get closeConfirmBody => 'It leaves the board. A regular ad can be renewed later.';

  @override
  String get closeConfirm => 'Close';

  @override
  String get closedDone => 'The ad is closed.';

  @override
  String get renew => 'Renew for 30 days';

  @override
  String get renewed => 'Renewed for 30 more days.';

  @override
  String get postAgain => 'Post again';

  @override
  String groupButton(int count) {
    return 'Group for everyone who answered ($count)';
  }

  @override
  String get groupNone => 'Nobody to add: whoever answered is no longer available.';

  @override
  String showsUntil(String date) {
    return 'Up until $date';
  }

  @override
  String get myAdsEmptyTitle => 'No ads yet';

  @override
  String get myAdsEmptyBody => 'Post an ad to find a walk or play partner nearby.';

  @override
  String get sectionOpen => 'Open';

  @override
  String get sectionEnded => 'Ended';

  @override
  String get sectionClosed => 'Closed';

  @override
  String get adTitle => 'Partner ad';

  @override
  String get adGone => 'This ad is no longer up.';

  @override
  String get postHere => 'Post a meetup here';

  @override
  String get atThisPark => 'Meetups at this park';

  @override
  String get noneAtPark => 'No meetups here yet.';

  @override
  String get notifyHere => 'Tell me about new meetups here';

  @override
  String get notifySaveFirst => 'Save the park to My parks to hear about new meetups here.';

  @override
  String get notifyFailed => 'We could not save that. Try again.';

  @override
  String cardMeetupsWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meetups this week',
      one: '1 meetup this week',
    );
    return '$_temp0';
  }

  @override
  String get cardMeetupToday => 'Meetup today';

  @override
  String get memberAds => 'Walk and play ads';

  @override
  String get addPlanWalk => 'Plan a walk or play date';

  @override
  String get goingSoonTitle => 'Going out soon?';

  @override
  String get goingSoonBody => 'Tell people who saved your parks. Lasts 90 min.';

  @override
  String get goingNowButton => 'Going now';

  @override
  String get addGoingNow => 'Going out now';

  @override
  String goingInTag(int minutes) {
    return 'in $minutes min';
  }

  @override
  String get goingOutTag => 'Out now';

  @override
  String leavingAt(String time) {
    return 'Leaving $time';
  }

  @override
  String get goingWhere => 'Where to';

  @override
  String get goingOtherPark => 'Another park';

  @override
  String get goingLeavingIn => 'Leaving in';

  @override
  String goingMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String goingWith(String pet) {
    return 'With $pet';
  }

  @override
  String get goingNoteHint => 'Anything to add? (optional)';

  @override
  String get goingPost => 'Tell them';

  @override
  String get goingPosted => 'Posted for the next 90 minutes';

  @override
  String get goingPickPark => 'Choose a park first';

  @override
  String get errNowLimit => 'That\'s three for today. You can post again tomorrow.';
}
