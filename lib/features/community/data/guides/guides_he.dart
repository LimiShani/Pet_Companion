import '../guides_repository.dart';
import 'guides_he_cats.dart';
import 'guides_he_dogs.dart';

/// The Hebrew text of the guides, by guide id: a translation of the English
/// guides (`guides_en.dart`), guide for guide, section for section and
/// point for point. A guide with no entry here is shown in English with an
/// "English only" tag.
///
/// The rules for this text, which tests hold it to:
///
/// - the same id as in `guide_catalog.dart`, and the same shape as the
///   English text (sections, paragraphs and bullets);
/// - nothing added and nothing dropped: no new claim, no new medical
///   statement, and every caution of the English guide kept with its
///   meaning (when to call the vet, what never to give);
/// - its own author line, which says truthfully how this text came to be
///   (`petCompanionTeamHe`), and its own `updatedAt`;
/// - no review: a review is recorded per language, and a reviewer who read
///   the English text has not reviewed the Hebrew one.
///
/// Wording follows `lib/l10n/GLOSSARY.md`: nobody is addressed as a man or
/// as a woman (impersonal phrasing, "כדאי", "אפשר", plural "we"), no
/// exclamation marks, Hebrew quotation marks.
const guidesHe = <String, GuideText>{...dogGuidesHe, ...catGuidesHe};
