import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'community_l10n_en.dart';
import 'community_l10n_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of CommunityL10n
/// returned by `CommunityL10n.of(context)`.
///
/// Applications need to include `CommunityL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/community_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: CommunityL10n.localizationsDelegates,
///   supportedLocales: CommunityL10n.supportedLocales,
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
/// be consistent with the languages listed in the CommunityL10n.supportedLocales
/// property.
abstract class CommunityL10n {
  CommunityL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static CommunityL10n of(BuildContext context) {
    return Localizations.of<CommunityL10n>(context, CommunityL10n)!;
  }

  static const LocalizationsDelegate<CommunityL10n> delegate = _CommunityL10nDelegate();

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

  /// Title of the Community tab's header.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabTitle;

  /// No description provided for @sectionFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get sectionFeed;

  /// The Chat section of the tab; also the title of a chat room whose name is not known yet.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get sectionChat;

  /// No description provided for @sectionGuides.
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get sectionGuides;

  /// The button that opens the composer, and the composer's title.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newPost;

  /// A chip at the top of Chat and Guides, and the small tag on a room or guide for dogs.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get scopeDogs;

  /// No description provided for @scopeCats.
  ///
  /// In en, this message translates to:
  /// **'Cats'**
  String get scopeCats;

  /// No description provided for @scopeEverything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get scopeEverything;

  /// The small tag on a room or guide for an animal that has no view of its own (rabbits, birds).
  ///
  /// In en, this message translates to:
  /// **'Other animals'**
  String get tagOtherAnimals;

  /// Under a guide's title in the reader: who the guide is for.
  ///
  /// In en, this message translates to:
  /// **'For dogs'**
  String get forDogs;

  /// No description provided for @forCats.
  ///
  /// In en, this message translates to:
  /// **'For cats'**
  String get forCats;

  /// No description provided for @forOtherAnimals.
  ///
  /// In en, this message translates to:
  /// **'For other animals'**
  String get forOtherAnimals;

  /// Under the chips in Chat, when the view is the selected pet's kind. Everything is the name of the third chip.
  ///
  /// In en, this message translates to:
  /// **'Matched to {pet}. Tap Everything to see all rooms.'**
  String roomsMatchedTo(String pet);

  /// No description provided for @guidesMatchedTo.
  ///
  /// In en, this message translates to:
  /// **'Matched to {pet}. Tap Everything to see all guides.'**
  String guidesMatchedTo(String pet);

  /// No description provided for @roomsShownForDogs.
  ///
  /// In en, this message translates to:
  /// **'Showing rooms for dogs.'**
  String get roomsShownForDogs;

  /// No description provided for @roomsShownForCats.
  ///
  /// In en, this message translates to:
  /// **'Showing rooms for cats.'**
  String get roomsShownForCats;

  /// No description provided for @roomsShownForAll.
  ///
  /// In en, this message translates to:
  /// **'Showing rooms for every animal.'**
  String get roomsShownForAll;

  /// No description provided for @guidesShownForDogs.
  ///
  /// In en, this message translates to:
  /// **'Showing guides for dogs.'**
  String get guidesShownForDogs;

  /// No description provided for @guidesShownForCats.
  ///
  /// In en, this message translates to:
  /// **'Showing guides for cats.'**
  String get guidesShownForCats;

  /// No description provided for @guidesShownForAll.
  ///
  /// In en, this message translates to:
  /// **'Showing guides for every animal.'**
  String get guidesShownForAll;

  /// No description provided for @noRoomsForDogs.
  ///
  /// In en, this message translates to:
  /// **'No rooms for dogs yet. Tap Everything to see all rooms.'**
  String get noRoomsForDogs;

  /// No description provided for @noRoomsForCats.
  ///
  /// In en, this message translates to:
  /// **'No rooms for cats yet. Tap Everything to see all rooms.'**
  String get noRoomsForCats;

  /// No description provided for @feedLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot load the feed'**
  String get feedLoadFailed;

  /// No description provided for @noPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsTitle;

  /// No description provided for @noPostsMessage.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share a photo or a story about your pet.'**
  String get noPostsMessage;

  /// No description provided for @writeAPost.
  ///
  /// In en, this message translates to:
  /// **'Write a post'**
  String get writeAPost;

  /// Under the author's name on a post: the pet the post is about.
  ///
  /// In en, this message translates to:
  /// **'with {pet}'**
  String postWithPet(String pet);

  /// Shown as the author when an account has no display name.
  ///
  /// In en, this message translates to:
  /// **'Pet lover'**
  String get memberFallbackName;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min ago} other{{minutes} min ago}}'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 h ago} other{{hours} h ago}}'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String timeDaysAgo(int days);

  /// No description provided for @postOptions.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get postOptions;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @unlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlike;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// What a screen reader says for the number next to the heart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No likes} =1{1 like} other{{count} likes}}'**
  String likeCount(int count);

  /// What a screen reader says for the number next to the speech bubble.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No comments} =1{1 comment} other{{count} comments}}'**
  String commentCount(int count);

  /// What a screen reader says for a post's picture.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoLabel;

  /// No description provided for @reportThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We have hidden this post and will review it.'**
  String get reportThanks;

  /// No description provided for @deletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get deletePostTitle;

  /// No description provided for @deletePostBody.
  ///
  /// In en, this message translates to:
  /// **'Its comments and likes go with it. This cannot be undone.'**
  String get deletePostBody;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your post was deleted.'**
  String get postDeleted;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportTitle;

  /// No description provided for @reportBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is wrong. We hide the post for you right away and review it.'**
  String get reportBody;

  /// No description provided for @reportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reportSpam;

  /// No description provided for @reportAbusive.
  ///
  /// In en, this message translates to:
  /// **'Unkind or abusive'**
  String get reportAbusive;

  /// No description provided for @reportInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate or upsetting'**
  String get reportInappropriate;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// The button that publishes a new post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postButton;

  /// No description provided for @composerAudience.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the community can see this'**
  String get composerAudience;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'What is your pet up to?'**
  String get composerHint;

  /// Label above the chips of the owner's pets in the composer: the pet the post is about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get composerAbout;

  /// No description provided for @composerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get composerPhoto;

  /// No description provided for @composerPhotoPreview.
  ///
  /// In en, this message translates to:
  /// **'The photo for this post'**
  String get composerPhotoPreview;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this post?'**
  String get discardTitle;

  /// No description provided for @discardBody.
  ///
  /// In en, this message translates to:
  /// **'What you have written will be lost.'**
  String get discardBody;

  /// No description provided for @keepWriting.
  ///
  /// In en, this message translates to:
  /// **'Keep writing'**
  String get keepWriting;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// Title of the page that shows one post with its comments.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// No description provided for @postGoneTitle.
  ///
  /// In en, this message translates to:
  /// **'This post is no longer available'**
  String get postGoneTitle;

  /// No description provided for @postGoneMessage.
  ///
  /// In en, this message translates to:
  /// **'It may have been deleted.'**
  String get postGoneMessage;

  /// No description provided for @backToFeed.
  ///
  /// In en, this message translates to:
  /// **'Back to the feed'**
  String get backToFeed;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get commentHint;

  /// No description provided for @sendComment.
  ///
  /// In en, this message translates to:
  /// **'Send comment'**
  String get sendComment;

  /// No description provided for @commentsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot load the comments.'**
  String get commentsLoadFailed;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first.'**
  String get noComments;

  /// Hint in a chat room's message field. room is the room's name.
  ///
  /// In en, this message translates to:
  /// **'Message {room}'**
  String messageHint(String room);

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessage;

  /// No description provided for @chatLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot load this conversation'**
  String get chatLoadFailed;

  /// No description provided for @noMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesTitle;

  /// No description provided for @noMessagesMessage.
  ///
  /// In en, this message translates to:
  /// **'Say hello to get the conversation going.'**
  String get noMessagesMessage;

  /// What a screen reader says before one of the reader's own chat messages.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get ownMessage;

  /// No description provided for @roomsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot load the chat rooms'**
  String get roomsLoadFailed;

  /// No description provided for @noRoomsTitle.
  ///
  /// In en, this message translates to:
  /// **'No chat rooms yet'**
  String get noRoomsTitle;

  /// No description provided for @noRoomsMessage.
  ///
  /// In en, this message translates to:
  /// **'Rooms will appear here as soon as they open.'**
  String get noRoomsMessage;

  /// No description provided for @roomGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get roomGeneral;

  /// No description provided for @roomGeneralAbout.
  ///
  /// In en, this message translates to:
  /// **'Say hello and share your day'**
  String get roomGeneralAbout;

  /// No description provided for @roomPuppies.
  ///
  /// In en, this message translates to:
  /// **'Puppies'**
  String get roomPuppies;

  /// No description provided for @roomPuppiesAbout.
  ///
  /// In en, this message translates to:
  /// **'First weeks, teething and sleep'**
  String get roomPuppiesAbout;

  /// No description provided for @roomTraining.
  ///
  /// In en, this message translates to:
  /// **'Training tips'**
  String get roomTraining;

  /// No description provided for @roomTrainingAbout.
  ///
  /// In en, this message translates to:
  /// **'What works, one small step at a time'**
  String get roomTrainingAbout;

  /// No description provided for @roomSeniors.
  ///
  /// In en, this message translates to:
  /// **'Senior dogs'**
  String get roomSeniors;

  /// No description provided for @roomSeniorsAbout.
  ///
  /// In en, this message translates to:
  /// **'Comfort and care for older friends'**
  String get roomSeniorsAbout;

  /// No description provided for @roomKittens.
  ///
  /// In en, this message translates to:
  /// **'Kittens'**
  String get roomKittens;

  /// No description provided for @roomKittensAbout.
  ///
  /// In en, this message translates to:
  /// **'First weeks, litter habits and play'**
  String get roomKittensAbout;

  /// No description provided for @roomCatLitter.
  ///
  /// In en, this message translates to:
  /// **'Litter and cleaning'**
  String get roomCatLitter;

  /// No description provided for @roomCatLitterAbout.
  ///
  /// In en, this message translates to:
  /// **'Litter, smell and how many boxes'**
  String get roomCatLitterAbout;

  /// No description provided for @roomCatBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Cat behaviour and play'**
  String get roomCatBehaviour;

  /// No description provided for @roomCatBehaviourAbout.
  ///
  /// In en, this message translates to:
  /// **'Scratching, night-time energy, a second cat'**
  String get roomCatBehaviourAbout;

  /// No description provided for @roomSeniorCats.
  ///
  /// In en, this message translates to:
  /// **'Senior cats'**
  String get roomSeniorCats;

  /// No description provided for @roomSeniorCatsAbout.
  ///
  /// In en, this message translates to:
  /// **'Comfort and care for older cats'**
  String get roomSeniorCatsAbout;

  /// No description provided for @roomHealth.
  ///
  /// In en, this message translates to:
  /// **'Health questions'**
  String get roomHealth;

  /// No description provided for @roomHealthAbout.
  ///
  /// In en, this message translates to:
  /// **'Ask other owners. For anything urgent, call your vet'**
  String get roomHealthAbout;

  /// No description provided for @guidesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot load the guides'**
  String get guidesLoadFailed;

  /// No description provided for @searchGuides.
  ///
  /// In en, this message translates to:
  /// **'Search guides'**
  String get searchGuides;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categoryStart.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get categoryStart;

  /// No description provided for @categoryHome.
  ///
  /// In en, this message translates to:
  /// **'Home and cleaning'**
  String get categoryHome;

  /// No description provided for @categoryBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Training and behaviour'**
  String get categoryBehaviour;

  /// No description provided for @categoryNutrition.
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get categoryNutrition;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health and grooming'**
  String get categoryHealth;

  /// No description provided for @categorySenior.
  ///
  /// In en, this message translates to:
  /// **'Senior care'**
  String get categorySenior;

  /// No description provided for @noGuidesForDogsMatch.
  ///
  /// In en, this message translates to:
  /// **'No guides for dogs match'**
  String get noGuidesForDogsMatch;

  /// No description provided for @noGuidesForCatsMatch.
  ///
  /// In en, this message translates to:
  /// **'No guides for cats match'**
  String get noGuidesForCatsMatch;

  /// No description provided for @matchesElsewhere.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{There is 1 match among the guides for every animal.} other{There are {count} matches among the guides for every animal.}}'**
  String matchesElsewhere(int count);

  /// No description provided for @searchEverything.
  ///
  /// In en, this message translates to:
  /// **'Search everything'**
  String get searchEverything;

  /// No description provided for @noGuidesMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No guides match'**
  String get noGuidesMatchTitle;

  /// No description provided for @noGuidesMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different word or another category.'**
  String get noGuidesMatchMessage;

  /// How long a guide takes to read.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min read} other{{minutes} min read}}'**
  String readTime(int minutes);

  /// On a guide's card: who wrote it.
  ///
  /// In en, this message translates to:
  /// **'By {author}'**
  String guideBy(String author);

  /// On a guide's card: the day its text last changed, as 30.09.26.
  ///
  /// In en, this message translates to:
  /// **'Updated {date}'**
  String guideUpdated(String date);

  /// Tag on a guide shown in English because it has no text in the reader's language.
  ///
  /// In en, this message translates to:
  /// **'English only'**
  String get tagEnglishOnly;

  /// Tag on a guide that a named professional has reviewed. Shown only when a real review is recorded.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get tagReviewed;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guideTitle;

  /// No description provided for @guideNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Guide not found'**
  String get guideNotFoundTitle;

  /// No description provided for @guideNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This guide is not in the library any more.'**
  String get guideNotFoundMessage;

  /// No description provided for @backToGuides.
  ///
  /// In en, this message translates to:
  /// **'Back to the guides'**
  String get backToGuides;

  /// No description provided for @aboutThisGuide.
  ///
  /// In en, this message translates to:
  /// **'About this guide'**
  String get aboutThisGuide;

  /// No description provided for @writtenBy.
  ///
  /// In en, this message translates to:
  /// **'Written by'**
  String get writtenBy;

  /// No description provided for @professionalReview.
  ///
  /// In en, this message translates to:
  /// **'Professional review'**
  String get professionalReview;

  /// Must stay true: no veterinarian has reviewed the guide. Never soften it.
  ///
  /// In en, this message translates to:
  /// **'Not reviewed by a veterinarian'**
  String get notReviewedByVet;

  /// No description provided for @reviewedBy.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by'**
  String get reviewedBy;

  /// After the reviewer's profession: 'Veterinarian · reviewed 05.10.26'.
  ///
  /// In en, this message translates to:
  /// **'reviewed {date}'**
  String reviewedOn(String date);

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @noSources.
  ///
  /// In en, this message translates to:
  /// **'None cited'**
  String get noSources;

  /// No description provided for @noSourcesDetail.
  ///
  /// In en, this message translates to:
  /// **'General, widely accepted pet-care guidance.'**
  String get noSourcesDetail;

  /// A cited source with its publisher.
  ///
  /// In en, this message translates to:
  /// **'{title}, {publisher}'**
  String sourceWithPublisher(String title, String publisher);

  /// No description provided for @sourceOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open this source right now.'**
  String get sourceOpenFailed;

  /// The closing note of every guide.
  ///
  /// In en, this message translates to:
  /// **'This guide is general guidance and not a substitute for advice from your veterinarian.'**
  String get guideDisclaimer;

  /// The standing line in chat rooms and above a post's comments. It is followed by contactProfessional.
  ///
  /// In en, this message translates to:
  /// **'Members share personal experience, not professional advice.'**
  String get adviceNotice;

  /// Opens the selected pet's emergency and vet sheet.
  ///
  /// In en, this message translates to:
  /// **'Contact a professional'**
  String get contactProfessional;

  /// No description provided for @errUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the community right now. Please try again.'**
  String get errUnreachable;

  /// No description provided for @errChatUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the chat right now. Please try again.'**
  String get errChatUnreachable;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the community right now. Check your connection and try again.'**
  String get errOffline;

  /// No description provided for @errPostGone.
  ///
  /// In en, this message translates to:
  /// **'This post is no longer available.'**
  String get errPostGone;

  /// No description provided for @errEmptyPost.
  ///
  /// In en, this message translates to:
  /// **'Write something before posting.'**
  String get errEmptyPost;

  /// No description provided for @errEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Write something before sending.'**
  String get errEmptyMessage;

  /// No description provided for @errNotYourPost.
  ///
  /// In en, this message translates to:
  /// **'You can only delete your own posts.'**
  String get errNotYourPost;

  /// No description provided for @errSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errSignInAgain;

  /// No description provided for @errNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to do that.'**
  String get errNotAllowed;

  /// No description provided for @errTextInvalid.
  ///
  /// In en, this message translates to:
  /// **'That text is empty or too long.'**
  String get errTextInvalid;

  /// No description provided for @errGone.
  ///
  /// In en, this message translates to:
  /// **'This is no longer available.'**
  String get errGone;

  /// No description provided for @errNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'The community is not set up on the server yet.'**
  String get errNotSetUp;

  /// No description provided for @errPhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large. Please choose a smaller one.'**
  String get errPhotoTooLarge;

  /// No description provided for @errPhotoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Please choose a JPEG, PNG or WebP photo.'**
  String get errPhotoUnsupported;

  /// No description provided for @errPhotoUpload.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be uploaded. Please try again.'**
  String get errPhotoUpload;

  /// No description provided for @errCameraNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the camera. Check that PetLoop is allowed to use it.'**
  String get errCameraNotAllowed;

  /// No description provided for @errPhotosNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cannot open your photos. Check that PetLoop is allowed to see them.'**
  String get errPhotosNotAllowed;
}

class _CommunityL10nDelegate extends LocalizationsDelegate<CommunityL10n> {
  const _CommunityL10nDelegate();

  @override
  Future<CommunityL10n> load(Locale locale) {
    return SynchronousFuture<CommunityL10n>(lookupCommunityL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_CommunityL10nDelegate old) => false;
}

CommunityL10n lookupCommunityL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return CommunityL10nEn();
    case 'he': return CommunityL10nHe();
  }

  throw FlutterError(
    'CommunityL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
