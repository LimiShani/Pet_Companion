import '../guides_repository.dart';

// Who wrote the bundled guides, stated once. Keep this true.
//
// The guides were drafted with an AI writing assistant under the app
// owner's direction. Nobody with a veterinary or training qualification has
// written or reviewed them, and the app says so on every guide, in every
// language.
//
// The Hebrew text is a translation of the English guides, made with the
// same AI assistant. It has not been reviewed by a veterinarian either, and
// its credit says how it came to be.

/// The author line of every English guide today.
const petCompanionTeam = GuideAuthor(
  name: 'Pet Companion team',
  role: 'App content team, writing with an AI assistant. Not veterinarians or trainers.',
);

/// The author line of every Hebrew guide today: the same team, and the same
/// limits, with the translation stated. ("The app's content team, writing
/// and translating with the help of an AI assistant. Not veterinarians and
/// not trainers.")
const petCompanionTeamHe = GuideAuthor(
  name: 'צוות Pet Companion',
  role: 'צוות התוכן של האפליקציה, בכתיבה ובתרגום בעזרת עוזר בינה מלאכותית. לא וטרינרים ולא מאלפים.',
);

/// The day the first guides (dogs and cats) were written.
const firstWritten = GuideDate(2026, 9, 30);

/// The day the Hebrew text of the guides was written.
const hebrewWritten = GuideDate(2026, 9, 30);
