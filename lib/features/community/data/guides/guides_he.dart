import '../guides_repository.dart';

/// The Hebrew text of the guides, by guide id.
///
/// Empty for now: the Hebrew text is written once the app's language switch
/// exists, for the owner to read before release. Until a guide has an entry
/// here it is shown in English with an "English only" tag.
///
/// To add one, use the same id as in `guide_catalog.dart` and the same
/// number of sections as the English text (a test checks both):
///
/// ```dart
/// 'litter-count': GuideText(
///   author: ...,      // who wrote or translated THIS text, truthfully
///   updatedAt: ...,   // the day this text last changed
///   title: '...',
///   summary: '...',
///   intro: '...',
///   sections: [...],
/// ),
/// ```
///
/// A review is recorded per language: a reviewer who read the English text
/// has not reviewed the Hebrew one.
const guidesHe = <String, GuideText>{};
