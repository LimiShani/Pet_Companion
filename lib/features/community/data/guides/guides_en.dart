import '../guides_repository.dart';
import 'guides_en_cats.dart';
import 'guides_en_dogs.dart';

/// The English text of every guide, by guide id. English is the language
/// every guide must have: it is what a reader sees when a guide has no text
/// in their own language yet.
const guidesEn = <String, GuideText>{...dogGuidesEn, ...catGuidesEn};
