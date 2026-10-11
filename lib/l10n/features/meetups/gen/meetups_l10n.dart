import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'meetups_l10n_en.dart';
import 'meetups_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of MeetupsL10n
/// returned by `MeetupsL10n.of(context)`.
///
/// Applications need to include `MeetupsL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/meetups_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: MeetupsL10n.localizationsDelegates,
///   supportedLocales: MeetupsL10n.supportedLocales,
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
/// be consistent with the languages listed in the MeetupsL10n.supportedLocales
/// property.
abstract class MeetupsL10n {
  MeetupsL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static MeetupsL10n of(BuildContext context) {
    return Localizations.of<MeetupsL10n>(context, MeetupsL10n)!;
  }

  static const LocalizationsDelegate<MeetupsL10n> delegate = _MeetupsL10nDelegate();

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

  /// No description provided for @areaQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where do you go out?'**
  String get areaQuestion;

  /// No description provided for @areaWhy.
  ///
  /// In en, this message translates to:
  /// **'Pick a city to see walk and play ads around it. \"Near me\" asks the phone for your location once, only to find the nearest city. It is never saved or sent.'**
  String get areaWhy;

  /// No description provided for @problemOutsideRegion.
  ///
  /// In en, this message translates to:
  /// **'Partners are listed in Israel for now. Pick a city in Israel.'**
  String get problemOutsideRegion;

  /// The fixed safety line at the top of the board.
  ///
  /// In en, this message translates to:
  /// **'Meet in a public place and don\'t share a home address.'**
  String get safetyStrip;

  /// No description provided for @newAd.
  ///
  /// In en, this message translates to:
  /// **'New ad'**
  String get newAd;

  /// No description provided for @myAds.
  ///
  /// In en, this message translates to:
  /// **'My ads'**
  String get myAds;

  /// No description provided for @myAdsCount.
  ///
  /// In en, this message translates to:
  /// **'My ads ({count})'**
  String myAdsCount(int count);

  /// Filter chip: walks and play.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get kindAll;

  /// No description provided for @kindWalk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get kindWalk;

  /// No description provided for @kindPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get kindPlay;

  /// Filter chip: ads that happen today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get whenToday;

  /// Filter chip: within the next seven days.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get whenThisWeek;

  /// Filter chip: ads that repeat every week.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get whenRecurring;

  /// No description provided for @atMyParks.
  ///
  /// In en, this message translates to:
  /// **'At my parks'**
  String get atMyParks;

  /// The board's button that opens the filters sheet.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// The filters button when some filters are on: how many.
  ///
  /// In en, this message translates to:
  /// **'Filters · {count}'**
  String filtersCount(int count);

  /// What a screen reader says for the filters button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Filters: none on} =1{Filters: 1 on} other{Filters: {count} on}}'**
  String filtersLabel(int count);

  /// Beside the filters button: every filter back to the start.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filtersClear;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Which ads to show'**
  String get filtersTitle;

  /// No description provided for @filterDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get filterDistance;

  /// No description provided for @filterKind.
  ///
  /// In en, this message translates to:
  /// **'Walk or play'**
  String get filterKind;

  /// No description provided for @filterAnimal.
  ///
  /// In en, this message translates to:
  /// **'Animal'**
  String get filterAnimal;

  /// No description provided for @filterWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get filterWhen;

  /// No description provided for @filterWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get filterWhere;

  /// No description provided for @filtersClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get filtersClearAll;

  /// The filters sheet's button: closes it. The ads already follow the filters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No ads to show} =1{Show 1 ad} other{Show {count} ads}}'**
  String filtersShow(int count);

  /// The filters sheet's button while the ads are loading.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get filtersDone;

  /// Shown when the ads are made up (no backend).
  ///
  /// In en, this message translates to:
  /// **'Sample ads'**
  String get sampleAds;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No ads around here yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'Post the first one, and members nearby can answer it.'**
  String get emptyBody;

  /// No description provided for @emptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No ads match these filters.'**
  String get emptyFiltered;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @lookFurther.
  ///
  /// In en, this message translates to:
  /// **'Look up to 25 km'**
  String get lookFurther;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the ads.'**
  String get loadFailed;

  /// An ad posted without a pet.
  ///
  /// In en, this message translates to:
  /// **'Without a pet'**
  String get noPet;

  /// The ad's dog's size, in its summary line.
  ///
  /// In en, this message translates to:
  /// **'small'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'medium-sized'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'large'**
  String get sizeLarge;

  /// "For small and medium dogs".
  ///
  /// In en, this message translates to:
  /// **'For {sizes} dogs'**
  String suitsLine(String sizes);

  /// No description provided for @suitsSmall.
  ///
  /// In en, this message translates to:
  /// **'small'**
  String get suitsSmall;

  /// No description provided for @suitsMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get suitsMedium;

  /// No description provided for @suitsLarge.
  ///
  /// In en, this message translates to:
  /// **'large'**
  String get suitsLarge;

  /// Two sizes in a line.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String suitsTwo(String first, String second);

  /// Approximate distance, "about 5 km".
  ///
  /// In en, this message translates to:
  /// **'about {distance}'**
  String distanceAbout(String distance);

  /// No description provided for @distanceNear.
  ///
  /// In en, this message translates to:
  /// **'under 1 km'**
  String get distanceNear;

  /// No description provided for @answers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No answers yet} =1{1 answer} other{{count} answers}}'**
  String answers(int count);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'I want to join'**
  String get join;

  /// No description provided for @answeredTag.
  ///
  /// In en, this message translates to:
  /// **'You answered'**
  String get answeredTag;

  /// No description provided for @openChat.
  ///
  /// In en, this message translates to:
  /// **'Open the chat'**
  String get openChat;

  /// No description provided for @yourAd.
  ///
  /// In en, this message translates to:
  /// **'Your ad'**
  String get yourAd;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @hiddenTag.
  ///
  /// In en, this message translates to:
  /// **'Hidden after reports'**
  String get hiddenTag;

  /// No description provided for @endedTag.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get endedTag;

  /// No description provided for @closedTag.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedTag;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @menuReport.
  ///
  /// In en, this message translates to:
  /// **'Report ad'**
  String get menuReport;

  /// No description provided for @menuBlock.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String menuBlock(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this ad?'**
  String get reportTitle;

  /// No description provided for @reportBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is wrong. After three reports an ad is hidden until a moderator looks at it.'**
  String get reportBody;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks, the ad was reported.'**
  String get reportThanks;

  /// No description provided for @dayPartMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get dayPartMorning;

  /// No description provided for @dayPartNoon.
  ///
  /// In en, this message translates to:
  /// **'Noon'**
  String get dayPartNoon;

  /// No description provided for @dayPartEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get dayPartEvening;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @weekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get weekends;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @formNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New ad'**
  String get formNewTitle;

  /// No description provided for @formEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit ad'**
  String get formEditTitle;

  /// No description provided for @withWhom.
  ///
  /// In en, this message translates to:
  /// **'With whom?'**
  String get withWhom;

  /// No description provided for @whatQ.
  ///
  /// In en, this message translates to:
  /// **'What?'**
  String get whatQ;

  /// No description provided for @whereQ.
  ///
  /// In en, this message translates to:
  /// **'Where?'**
  String get whereQ;

  /// No description provided for @wherePark.
  ///
  /// In en, this message translates to:
  /// **'A park'**
  String get wherePark;

  /// No description provided for @whereOther.
  ///
  /// In en, this message translates to:
  /// **'Other place'**
  String get whereOther;

  /// No description provided for @choosePark.
  ///
  /// In en, this message translates to:
  /// **'Choose a park'**
  String get choosePark;

  /// No description provided for @changePark.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changePark;

  /// No description provided for @parkRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a park, or another place.'**
  String get parkRequired;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @placeLabel.
  ///
  /// In en, this message translates to:
  /// **'Where exactly?'**
  String get placeLabel;

  /// No description provided for @placeHint.
  ///
  /// In en, this message translates to:
  /// **'A public place, like the entrance to Yarkon Park'**
  String get placeHint;

  /// No description provided for @placeHelp.
  ///
  /// In en, this message translates to:
  /// **'No home addresses.'**
  String get placeHelp;

  /// No description provided for @placeRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a city and say where.'**
  String get placeRequired;

  /// No description provided for @whenQ.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get whenQ;

  /// No description provided for @once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get once;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get weekly;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @toLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toLabel;

  /// No description provided for @hoursProblem.
  ///
  /// In en, this message translates to:
  /// **'The meeting ends after it starts, within 12 hours.'**
  String get hoursProblem;

  /// No description provided for @pastProblem.
  ///
  /// In en, this message translates to:
  /// **'That time is already over.'**
  String get pastProblem;

  /// No description provided for @tooFarProblem.
  ///
  /// In en, this message translates to:
  /// **'Up to 60 days ahead.'**
  String get tooFarProblem;

  /// No description provided for @daysProblem.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get daysProblem;

  /// No description provided for @partQ.
  ///
  /// In en, this message translates to:
  /// **'Part of the day'**
  String get partQ;

  /// No description provided for @suitsQ.
  ///
  /// In en, this message translates to:
  /// **'Suits… (optional)'**
  String get suitsQ;

  /// No description provided for @sizeAny.
  ///
  /// In en, this message translates to:
  /// **'Any size'**
  String get sizeAny;

  /// No description provided for @sizeSmallChip.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmallChip;

  /// No description provided for @sizeMediumChip.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMediumChip;

  /// No description provided for @sizeLargeChip.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLargeChip;

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'A few words'**
  String get noteLabel;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'For example: a calm hour-long walk, all sizes welcome'**
  String get noteHint;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Your ad is up.'**
  String get posted;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get saved;

  /// No description provided for @recurringNote.
  ///
  /// In en, this message translates to:
  /// **'A regular ad stays up for 30 days, then it can be renewed.'**
  String get recurringNote;

  /// No description provided for @limitsNote.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 new ads a day and 5 open at once.'**
  String get limitsNote;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'That\'s three new ads today. Try again tomorrow.'**
  String get errRateLimited;

  /// No description provided for @errTooManyOpen.
  ///
  /// In en, this message translates to:
  /// **'There are five open ads already. Close one to post another.'**
  String get errTooManyOpen;

  /// No description provided for @errNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This ad is no longer open.'**
  String get errNotOpen;

  /// No description provided for @errBlocked.
  ///
  /// In en, this message translates to:
  /// **'This ad can\'t be answered.'**
  String get errBlocked;

  /// No description provided for @errInvalid.
  ///
  /// In en, this message translates to:
  /// **'Something in the ad no longer fits (the park or the time). Check it and try again.'**
  String get errInvalid;

  /// No description provided for @errUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No connection. Try again in a moment.'**
  String get errUnavailable;

  /// No description provided for @errOther.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again.'**
  String get errOther;

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Message to {name}'**
  String joinTitle(String name);

  /// No description provided for @joinBody.
  ///
  /// In en, this message translates to:
  /// **'A private chat opens between the two of you. {name} gets a notification when you send the message.'**
  String joinBody(String name);

  /// No description provided for @whoComing.
  ///
  /// In en, this message translates to:
  /// **'Who\'s coming?'**
  String get whoComing;

  /// No description provided for @justMe.
  ///
  /// In en, this message translates to:
  /// **'Just me'**
  String get justMe;

  /// The first message to the author, ready to edit.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, I saw your walk ad ({place}). I\'d love to join with {pet}.'**
  String draftWalkPet(String name, String place, String pet);

  /// No description provided for @draftWalk.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, I saw your walk ad ({place}). I\'d love to join.'**
  String draftWalk(String name, String place);

  /// No description provided for @draftPlayPet.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, I saw your playdate ad ({place}). I\'d love to join with {pet}.'**
  String draftPlayPet(String name, String place, String pet);

  /// No description provided for @draftPlay.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, I saw your playdate ad ({place}). I\'d love to join.'**
  String draftPlay(String name, String place);

  /// No description provided for @joinMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get joinMessageLabel;

  /// No description provided for @joinTip.
  ///
  /// In en, this message translates to:
  /// **'The first time, meet in an open place you both know.'**
  String get joinTip;

  /// No description provided for @joinSend.
  ///
  /// In en, this message translates to:
  /// **'Open the chat with this message'**
  String get joinSend;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @closeAd.
  ///
  /// In en, this message translates to:
  /// **'Found someone, close it'**
  String get closeAd;

  /// No description provided for @closeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this ad?'**
  String get closeConfirmTitle;

  /// No description provided for @closeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It leaves the board. A regular ad can be renewed later.'**
  String get closeConfirmBody;

  /// No description provided for @closeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeConfirm;

  /// No description provided for @closedDone.
  ///
  /// In en, this message translates to:
  /// **'The ad is closed.'**
  String get closedDone;

  /// No description provided for @renew.
  ///
  /// In en, this message translates to:
  /// **'Renew for 30 days'**
  String get renew;

  /// No description provided for @renewed.
  ///
  /// In en, this message translates to:
  /// **'Renewed for 30 more days.'**
  String get renewed;

  /// No description provided for @postAgain.
  ///
  /// In en, this message translates to:
  /// **'Post again'**
  String get postAgain;

  /// No description provided for @groupButton.
  ///
  /// In en, this message translates to:
  /// **'Group for everyone who answered ({count})'**
  String groupButton(int count);

  /// No description provided for @groupNone.
  ///
  /// In en, this message translates to:
  /// **'Nobody to add: whoever answered is no longer available.'**
  String get groupNone;

  /// When a regular ad stops showing.
  ///
  /// In en, this message translates to:
  /// **'Up until {date}'**
  String showsUntil(String date);

  /// No description provided for @myAdsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No ads yet'**
  String get myAdsEmptyTitle;

  /// No description provided for @myAdsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Post an ad to find a walk or play partner nearby.'**
  String get myAdsEmptyBody;

  /// No description provided for @sectionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get sectionOpen;

  /// No description provided for @sectionEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get sectionEnded;

  /// No description provided for @sectionClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get sectionClosed;

  /// No description provided for @adTitle.
  ///
  /// In en, this message translates to:
  /// **'Partner ad'**
  String get adTitle;

  /// No description provided for @adGone.
  ///
  /// In en, this message translates to:
  /// **'This ad is no longer up.'**
  String get adGone;

  /// No description provided for @postHere.
  ///
  /// In en, this message translates to:
  /// **'Post a meetup here'**
  String get postHere;

  /// No description provided for @atThisPark.
  ///
  /// In en, this message translates to:
  /// **'Meetups at this park'**
  String get atThisPark;

  /// No description provided for @noneAtPark.
  ///
  /// In en, this message translates to:
  /// **'No meetups here yet.'**
  String get noneAtPark;

  /// No description provided for @notifyHere.
  ///
  /// In en, this message translates to:
  /// **'Tell me about new meetups here'**
  String get notifyHere;

  /// No description provided for @notifySaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the park to My parks to hear about new meetups here.'**
  String get notifySaveFirst;

  /// No description provided for @notifyFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not save that. Try again.'**
  String get notifyFailed;

  /// On a park card.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 meetup this week} other{{count} meetups this week}}'**
  String cardMeetupsWeek(int count);

  /// On a park card.
  ///
  /// In en, this message translates to:
  /// **'Meetup today'**
  String get cardMeetupToday;

  /// A member page's section of their open ads.
  ///
  /// In en, this message translates to:
  /// **'Walk and play ads'**
  String get memberAds;
}

class _MeetupsL10nDelegate extends LocalizationsDelegate<MeetupsL10n> {
  const _MeetupsL10nDelegate();

  @override
  Future<MeetupsL10n> load(Locale locale) {
    return SynchronousFuture<MeetupsL10n>(lookupMeetupsL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_MeetupsL10nDelegate old) => false;
}

MeetupsL10n lookupMeetupsL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return MeetupsL10nEn();
    case 'he': return MeetupsL10nHe();
  }

  throw FlutterError(
    'MeetupsL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
