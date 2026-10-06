// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'community_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class CommunityL10nEn extends CommunityL10n {
  CommunityL10nEn([String locale = 'en']) : super(locale);

  @override
  String get tabTitle => 'Community';

  @override
  String get sectionFeed => 'Feed';

  @override
  String get sectionChat => 'Chat';

  @override
  String get sectionGuides => 'Guides';

  @override
  String get newPost => 'New post';

  @override
  String get scopeDogs => 'Dogs';

  @override
  String get scopeCats => 'Cats';

  @override
  String get scopeEverything => 'Everything';

  @override
  String get tagOtherAnimals => 'Other animals';

  @override
  String get forDogs => 'For dogs';

  @override
  String get forCats => 'For cats';

  @override
  String get forOtherAnimals => 'For other animals';

  @override
  String roomsMatchedTo(String pet) {
    return 'Matched to $pet. Tap Everything to see all rooms.';
  }

  @override
  String guidesMatchedTo(String pet) {
    return 'Matched to $pet. Tap Everything to see all guides.';
  }

  @override
  String get roomsShownForDogs => 'Showing rooms for dogs.';

  @override
  String get roomsShownForCats => 'Showing rooms for cats.';

  @override
  String get roomsShownForAll => 'Showing rooms for every animal.';

  @override
  String get guidesShownForDogs => 'Showing guides for dogs.';

  @override
  String get guidesShownForCats => 'Showing guides for cats.';

  @override
  String get guidesShownForAll => 'Showing guides for every animal.';

  @override
  String get noRoomsForDogs => 'No rooms for dogs yet. Tap Everything to see all rooms.';

  @override
  String get noRoomsForCats => 'No rooms for cats yet. Tap Everything to see all rooms.';

  @override
  String get feedLoadFailed => 'Cannot load the feed';

  @override
  String get noPostsTitle => 'No posts yet';

  @override
  String get noPostsMessage => 'Be the first to share a photo or a story about your pet.';

  @override
  String get writeAPost => 'Write a post';

  @override
  String postWithPet(String pet) {
    return 'with $pet';
  }

  @override
  String get memberFallbackName => 'Pet lover';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours h ago',
      one: '1 h ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get postOptions => 'Post options';

  @override
  String get report => 'Report';

  @override
  String get like => 'Like';

  @override
  String get unlike => 'Unlike';

  @override
  String get comments => 'Comments';

  @override
  String likeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
      zero: 'No likes',
    );
    return '$_temp0';
  }

  @override
  String commentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'No comments',
    );
    return '$_temp0';
  }

  @override
  String get photoLabel => 'Photo';

  @override
  String get reportThanks => 'Thanks. We have hidden this post and will review it.';

  @override
  String get deletePostTitle => 'Delete this post?';

  @override
  String get deletePostBody => 'Its comments and likes go with it. This cannot be undone.';

  @override
  String get postDeleted => 'Your post was deleted.';

  @override
  String get reportTitle => 'Report this post';

  @override
  String get reportBody => 'Tell us what is wrong. We hide the post for you right away and review it.';

  @override
  String get reportSpam => 'Spam or advertising';

  @override
  String get reportAbusive => 'Unkind or abusive';

  @override
  String get reportInappropriate => 'Inappropriate or upsetting';

  @override
  String get reportOther => 'Something else';

  @override
  String get postButton => 'Post';

  @override
  String get composerAudience => 'Everyone in the community can see this';

  @override
  String get composerHint => 'What is your pet up to?';

  @override
  String get composerAbout => 'About';

  @override
  String get composerPhoto => 'Photo';

  @override
  String get composerPhotoPreview => 'The photo for this post';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get discardTitle => 'Discard this post?';

  @override
  String get discardBody => 'What you have written will be lost.';

  @override
  String get keepWriting => 'Keep writing';

  @override
  String get discard => 'Discard';

  @override
  String get postTitle => 'Post';

  @override
  String get postGoneTitle => 'This post is no longer available';

  @override
  String get postGoneMessage => 'It may have been deleted.';

  @override
  String get backToFeed => 'Back to the feed';

  @override
  String get commentHint => 'Add a comment';

  @override
  String get sendComment => 'Send comment';

  @override
  String get commentsLoadFailed => 'Cannot load the comments.';

  @override
  String get noComments => 'No comments yet. Be the first.';

  @override
  String messageHint(String room) {
    return 'Message $room';
  }

  @override
  String get sendMessage => 'Send message';

  @override
  String get chatLoadFailed => 'Cannot load this conversation';

  @override
  String get noMessagesTitle => 'No messages yet';

  @override
  String get noMessagesMessage => 'Say hello to get the conversation going.';

  @override
  String get ownMessage => 'You';

  @override
  String get roomsLoadFailed => 'Cannot load the chat rooms';

  @override
  String get noRoomsTitle => 'No chat rooms yet';

  @override
  String get noRoomsMessage => 'Rooms will appear here as soon as they open.';

  @override
  String get roomGeneral => 'General';

  @override
  String get roomGeneralAbout => 'Say hello and share your day';

  @override
  String get roomPuppies => 'Puppies';

  @override
  String get roomPuppiesAbout => 'First weeks, teething and sleep';

  @override
  String get roomTraining => 'Training tips';

  @override
  String get roomTrainingAbout => 'What works, one small step at a time';

  @override
  String get roomSeniors => 'Senior dogs';

  @override
  String get roomSeniorsAbout => 'Comfort and care for older friends';

  @override
  String get roomKittens => 'Kittens';

  @override
  String get roomKittensAbout => 'First weeks, litter habits and play';

  @override
  String get roomCatLitter => 'Litter and cleaning';

  @override
  String get roomCatLitterAbout => 'Litter, smell and how many boxes';

  @override
  String get roomCatBehaviour => 'Cat behaviour and play';

  @override
  String get roomCatBehaviourAbout => 'Scratching, night-time energy, a second cat';

  @override
  String get roomSeniorCats => 'Senior cats';

  @override
  String get roomSeniorCatsAbout => 'Comfort and care for older cats';

  @override
  String get roomHealth => 'Health questions';

  @override
  String get roomHealthAbout => 'Ask other owners. For anything urgent, call your vet';

  @override
  String get guidesLoadFailed => 'Cannot load the guides';

  @override
  String get searchGuides => 'Search guides';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get categoryAll => 'All';

  @override
  String get categoryStart => 'Getting started';

  @override
  String get categoryHome => 'Home and cleaning';

  @override
  String get categoryBehaviour => 'Training and behaviour';

  @override
  String get categoryNutrition => 'Nutrition';

  @override
  String get categoryHealth => 'Health and grooming';

  @override
  String get categorySenior => 'Senior care';

  @override
  String get noGuidesForDogsMatch => 'No guides for dogs match';

  @override
  String get noGuidesForCatsMatch => 'No guides for cats match';

  @override
  String matchesElsewhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'There are $count matches among the guides for every animal.',
      one: 'There is 1 match among the guides for every animal.',
    );
    return '$_temp0';
  }

  @override
  String get searchEverything => 'Search everything';

  @override
  String get noGuidesMatchTitle => 'No guides match';

  @override
  String get noGuidesMatchMessage => 'Try a different word or another category.';

  @override
  String readTime(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min read',
      one: '1 min read',
    );
    return '$_temp0';
  }

  @override
  String guideBy(String author) {
    return 'By $author';
  }

  @override
  String guideUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get tagEnglishOnly => 'English only';

  @override
  String get tagReviewed => 'Reviewed';

  @override
  String get guideTitle => 'Guide';

  @override
  String get guideNotFoundTitle => 'Guide not found';

  @override
  String get guideNotFoundMessage => 'This guide is not in the library any more.';

  @override
  String get backToGuides => 'Back to the guides';

  @override
  String get aboutThisGuide => 'About this guide';

  @override
  String get writtenBy => 'Written by';

  @override
  String get professionalReview => 'Professional review';

  @override
  String get notReviewedByVet => 'Not reviewed by a veterinarian';

  @override
  String get reviewedBy => 'Reviewed by';

  @override
  String reviewedOn(String date) {
    return 'reviewed $date';
  }

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get sources => 'Sources';

  @override
  String get noSources => 'None cited';

  @override
  String get noSourcesDetail => 'General, widely accepted pet-care guidance.';

  @override
  String sourceWithPublisher(String title, String publisher) {
    return '$title, $publisher';
  }

  @override
  String get sourceOpenFailed => 'Cannot open this source right now.';

  @override
  String get guideDisclaimer => 'This guide is general guidance and not a substitute for advice from your veterinarian.';

  @override
  String get adviceNotice => 'Members share personal experience, not professional advice.';

  @override
  String get contactProfessional => 'Contact a professional';

  @override
  String get errUnreachable => 'Cannot reach the community right now. Please try again.';

  @override
  String get errChatUnreachable => 'Cannot reach the chat right now. Please try again.';

  @override
  String get errOffline => 'Cannot reach the community right now. Check your connection and try again.';

  @override
  String get errPostGone => 'This post is no longer available.';

  @override
  String get errEmptyPost => 'Write something before posting.';

  @override
  String get errEmptyMessage => 'Write something before sending.';

  @override
  String get errNotYourPost => 'You can only delete your own posts.';

  @override
  String get errSignInAgain => 'Please sign in again.';

  @override
  String get errNotAllowed => 'You are not allowed to do that.';

  @override
  String get errTextInvalid => 'That text is empty or too long.';

  @override
  String get errGone => 'This is no longer available.';

  @override
  String get errNotSetUp => 'The community is not set up on the server yet.';

  @override
  String get errPhotoTooLarge => 'That photo is too large. Please choose a smaller one.';

  @override
  String get errPhotoUnsupported => 'Please choose a JPEG, PNG or WebP photo.';

  @override
  String get errPhotoUpload => 'The photo could not be uploaded. Please try again.';

  @override
  String get errCameraNotAllowed => 'Cannot open the camera. Check that PetLoop is allowed to use it.';

  @override
  String get errPhotosNotAllowed => 'Cannot open your photos. Check that PetLoop is allowed to see them.';

  @override
  String get errSlowDown => 'That was quick! Please wait a minute before sending more.';

  @override
  String get errNotModerator => 'Only community moderators can do this.';

  @override
  String roomLastMine(String text) {
    return 'You: $text';
  }

  @override
  String roomLastOther(String name, String text) {
    return '$name: $text';
  }

  @override
  String roomUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get chatReply => 'Reply';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Message copied';

  @override
  String get chatDeleteTitle => 'Delete this message?';

  @override
  String get chatDeleteBody => 'It disappears for everyone in the room.';

  @override
  String get chatDeleted => 'Message deleted';

  @override
  String get chatReportTitle => 'Report this message';

  @override
  String get chatReportBody => 'Tell us what is wrong. We hide the message for you right away and review it.';

  @override
  String get chatReportThanks => 'Thanks. We have hidden this message and will review it.';

  @override
  String get commentOptions => 'Comment options';

  @override
  String get commentReportTitle => 'Report this comment';

  @override
  String get commentReportBody => 'Tell us what is wrong. We hide the comment for you right away and review it.';

  @override
  String get commentReportThanks => 'Thanks. We have hidden this comment and will review it.';

  @override
  String get messageOptions => 'Message options';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get replyUnavailable => 'The original message is not available';

  @override
  String get messageSending => 'Sending…';

  @override
  String get messageNotSent => 'Not sent. Tap to try again.';

  @override
  String get messageNotSentTitle => 'This message was not sent';

  @override
  String newMessages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new messages',
      one: '1 new message',
    );
    return '$_temp0';
  }

  @override
  String get jumpToLatest => 'Go to the latest message';

  @override
  String get conversationStart => 'This is the start of the conversation';

  @override
  String get addPhoto => 'Add a photo';

  @override
  String get chatPhotoPreview => 'The photo to send';

  @override
  String get openPhoto => 'Open the photo';

  @override
  String reactWith(String emoji) {
    return 'React with $emoji';
  }

  @override
  String reactionsSummary(String emoji, int count) {
    return '$emoji $count';
  }

  @override
  String get hideNotice => 'Hide this note';

  @override
  String get roomInfo => 'About this room';

  @override
  String blockMember(String name) {
    return 'Block $name';
  }

  @override
  String blockTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get blockBody => 'Their posts, comments and messages will no longer appear for you. Nobody is told. You can undo this any time under Community safety.';

  @override
  String get blockConfirm => 'Block';

  @override
  String blockedDone(String name) {
    return 'You blocked $name';
  }

  @override
  String get unblock => 'Unblock';

  @override
  String unblockedDone(String name) {
    return '$name is unblocked';
  }

  @override
  String get rulesTitle => 'Community rules';

  @override
  String get rulesIntro => 'PetLoop is a friendly place for pet owners. Before you share for the first time:';

  @override
  String get rule1 => 'Be kind. Disagree with ideas, not with people.';

  @override
  String get rule2 => 'No selling animals, no ads and no spam.';

  @override
  String get rule3 => 'Share experience, not diagnoses. For anything urgent, call a vet.';

  @override
  String get rule4 => 'Keep private details private, yours and other people\'s.';

  @override
  String get rule5 => 'Report what breaks the rules. Three reports hide something until a moderator looks at it.';

  @override
  String get rulesAgree => 'Agree and continue';

  @override
  String get safetyTitle => 'Community safety';

  @override
  String get safetyIntro => 'Blocking and reporting are private: nobody is told who did it.';

  @override
  String get blockedTitle => 'Blocked members';

  @override
  String get noBlocked => 'You have not blocked anyone.';

  @override
  String get blockedLoadFailed => 'Cannot load your blocked members';

  @override
  String get reviewReports => 'Review reports';

  @override
  String reviewWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting',
      one: '1 waiting',
      zero: 'Nothing waiting',
    );
    return '$_temp0';
  }

  @override
  String get reviewEmptyTitle => 'All clear';

  @override
  String get reviewEmptyMessage => 'No reports are waiting for review.';

  @override
  String get reviewLoadFailed => 'Cannot load the reports';

  @override
  String get kindPost => 'Post';

  @override
  String get kindComment => 'Comment';

  @override
  String get kindMessage => 'Chat message';

  @override
  String reportCountLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
    );
    return '$_temp0';
  }

  @override
  String get hiddenTag => 'Hidden';

  @override
  String inRoom(String room) {
    return 'In $room';
  }

  @override
  String get keepItem => 'Keep';

  @override
  String get removeItem => 'Remove';

  @override
  String get removeItemTitle => 'Remove it for everyone?';

  @override
  String get removeItemBody => 'It is deleted and cannot be brought back.';

  @override
  String get keptDone => 'Kept. It shows again for everyone.';

  @override
  String get removedDone => 'Removed';
}
