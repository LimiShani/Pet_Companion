import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import 'data/audience.dart';
import 'data/community_models.dart';
import 'data/guides_repository.dart';

// The bridge between the Community's values and its words.
//
// The words themselves live in `l10n/community_en.arb` and
// `l10n/community_he.arb` (wording: `lib/l10n/GLOSSARY.md`); in a widget
// they are `context.communityL10n`. What the data layer holds (a view, an
// audience, a room or category id, a report reason, a reason for failure)
// stays a key, and is put into words here in the language on screen.
//
// What members wrote (posts, comments, chat messages, display names) and
// the guides' own text are content: never translated, and shown in the
// direction of their own letters (`contentDirection`).

extension CommunityWords on CommunityL10n {
  bool get _rightToLeft => localeName != 'en';

  /// The chip's label: "Dogs", "Cats", "Everything".
  String scope(CommunityScope scope) => switch (scope) {
        CommunityScope.dogs => scopeDogs,
        CommunityScope.cats => scopeCats,
        CommunityScope.everything => scopeEverything,
      };

  /// The small tag next to an item under Everything; `null` for what is
  /// shared by everyone.
  String? audienceTag(Audience audience) => switch (audience) {
        Audience.everyone => null,
        Audience.dogs => scopeDogs,
        Audience.cats => scopeCats,
        Audience.other => tagOtherAnimals,
      };

  /// "For cats", as the reader's subtitle says it; `null` for everyone.
  String? forWhom(Audience audience) => switch (audience) {
        Audience.everyone => null,
        Audience.dogs => forDogs,
        Audience.cats => forCats,
        Audience.other => forOtherAnimals,
      };

  /// The line under the chips of the Chat section.
  String roomsCaption(CommunityScope scope, {String? matchedPet}) {
    if (matchedPet != null) return roomsMatchedTo(matchedPet);
    return switch (scope) {
      CommunityScope.dogs => roomsShownForDogs,
      CommunityScope.cats => roomsShownForCats,
      CommunityScope.everything => roomsShownForAll,
    };
  }

  /// The line under the chips of the Guides section.
  String guidesCaption(CommunityScope scope, {String? matchedPet}) {
    if (matchedPet != null) return guidesMatchedTo(matchedPet);
    return switch (scope) {
      CommunityScope.dogs => guidesShownForDogs,
      CommunityScope.cats => guidesShownForCats,
      CommunityScope.everything => guidesShownForAll,
    };
  }

  /// Said when a view has no room of its own.
  String noRoomsFor(CommunityScope scope) => switch (scope) {
        CommunityScope.dogs => noRoomsForDogs,
        CommunityScope.cats => noRoomsForCats,
        CommunityScope.everything => noRoomsTitle,
      };

  /// Title of "this search found nothing for this animal".
  String noGuidesFor(CommunityScope scope) => switch (scope) {
        CommunityScope.dogs => noGuidesForDogsMatch,
        CommunityScope.cats => noGuidesForCatsMatch,
        CommunityScope.everything => noGuidesMatchTitle,
      };

  /// A room's name: in the language on screen for the rooms the app ships
  /// with, as stored for any room added later.
  String roomName(ChatChannel channel) => switch (channel.id) {
        'general' => roomGeneral,
        'puppies' => roomPuppies,
        'training' => roomTraining,
        'seniors' => roomSeniors,
        'kittens' => roomKittens,
        'cat-litter' => roomCatLitter,
        'cat-behaviour' => roomCatBehaviour,
        'senior-cats' => roomSeniorCats,
        'health' => roomHealth,
        _ => channel.name,
      };

  /// A room's one-line description, chosen as [roomName] is.
  String roomAbout(ChatChannel channel) => switch (channel.id) {
        'general' => roomGeneralAbout,
        'puppies' => roomPuppiesAbout,
        'training' => roomTrainingAbout,
        'seniors' => roomSeniorsAbout,
        'kittens' => roomKittensAbout,
        'cat-litter' => roomCatLitterAbout,
        'cat-behaviour' => roomCatBehaviourAbout,
        'senior-cats' => roomSeniorCatsAbout,
        'health' => roomHealthAbout,
        _ => channel.description,
      };

  /// A guide category's name: in the language on screen for the shelves
  /// the app ships with, as stored for any added later.
  String categoryName(GuideCategory category) => switch (category.id) {
        'start' => categoryStart,
        'home' => categoryHome,
        'behaviour' => categoryBehaviour,
        'nutrition' => categoryNutrition,
        'health' => categoryHealth,
        'senior' => categorySenior,
        _ => category.name,
      };

  String reportReason(ReportReason reason) => switch (reason) {
        ReportReason.spam => reportSpam,
        ReportReason.abusive => reportAbusive,
        ReportReason.inappropriate => reportInappropriate,
        ReportReason.other => reportOther,
      };

  /// A member's name as shown: their own, or a friendly fallback for an
  /// account without one.
  String memberName(String stored) => stored.trim().isEmpty ? memberFallbackName : stored;

  /// What a failed action reports, in words. `null` for a failure the
  /// Community has no words of its own for.
  String? failure(CommunityFailure failure) => switch (failure) {
        CommunityFailure.unreachable => errUnreachable,
        CommunityFailure.chatUnreachable => errChatUnreachable,
        CommunityFailure.offline => errOffline,
        CommunityFailure.postGone => errPostGone,
        CommunityFailure.emptyPost => errEmptyPost,
        CommunityFailure.emptyMessage => errEmptyMessage,
        CommunityFailure.notYourPost => errNotYourPost,
        CommunityFailure.signInAgain => errSignInAgain,
        CommunityFailure.notAllowed => errNotAllowed,
        CommunityFailure.textInvalid => errTextInvalid,
        CommunityFailure.gone => errGone,
        CommunityFailure.notSetUp => errNotSetUp,
        CommunityFailure.photoTooLarge => errPhotoTooLarge,
        CommunityFailure.photoUnsupported => errPhotoUnsupported,
        CommunityFailure.photoUpload => errPhotoUpload,
        CommunityFailure.cameraNotAllowed => errCameraNotAllowed,
        CommunityFailure.photosNotAllowed => errPhotosNotAllowed,
        CommunityFailure.unknown => null,
      };

  /// Something a person wrote (a name, a profession), ready to sit in a
  /// line of the screen's language: kept as one unit when it runs the other
  /// way, so it cannot reorder the line around it.
  String inLine(String written) {
    final direction = directionOfText(written, fallback: _rightToLeft ? TextDirection.rtl : TextDirection.ltr);
    return (direction == TextDirection.rtl) == _rightToLeft ? written : isolate(written);
  }

  /// "just now", "12 min ago", "5 h ago", "Yesterday", "3 days ago", then
  /// the date: when a post or a comment was written.
  String relativeTime(AppL10n app, AppFormat format, DateTime when, DateTime now) {
    final elapsed = now.difference(when);
    if (elapsed.inMinutes < 1) return timeJustNow;
    if (elapsed.inMinutes < 60) return timeMinutesAgo(elapsed.inMinutes);
    if (elapsed.inHours < 24) return timeHoursAgo(elapsed.inHours);
    if (elapsed.inDays == 1) return app.commonYesterday;
    if (elapsed.inDays < 7) return timeDaysAgo(elapsed.inDays);
    return format.date(when);
  }
}

/// Parts of a line of details, such as "with Kelly · 2 h ago": each part is
/// a whole message of its own, and the dot only sets them apart.
String dotted(Iterable<String> parts) => parts.join(' · ');

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Heading above the first chat message of a day: "Today", "Yesterday" or
/// the date.
String dayLabel(AppL10n app, AppFormat format, DateTime when, DateTime now) {
  if (isSameDay(when, now)) return app.commonToday;
  if (isSameDay(when, now.subtract(const Duration(days: 1)))) return app.commonYesterday;
  return format.date(when);
}

/// User-facing text for a community failure, in the language of the given
/// strings.
String communityFailureText(CommunityL10n l10n, AppL10n app, Object? error) {
  final words = error is CommunityException ? l10n.failure(error.failure) : null;
  return words ?? app.errorGeneric;
}

/// User-facing text for a community failure, in the language on screen.
String communityErrorText(BuildContext context, Object? error) =>
    communityFailureText(context.communityL10n, context.l10n, error);

/// [communityErrorText] for after an `await`: the strings are looked up
/// now, while the screen is certainly there, and the words are put
/// together when the failure arrives.
String Function(Object? error) communityErrorWords(BuildContext context) {
  final l10n = context.communityL10n;
  final app = context.l10n;
  return (error) => communityFailureText(l10n, app, error);
}

/// The direction a piece of content reads in: a post, a comment, a chat
/// message, a member's name. Content is never translated, so an English
/// post stays left to right on a Hebrew screen and the other way round.
TextDirection contentDirection(BuildContext context, String text) =>
    directionOfText(text, fallback: Directionality.of(context));
