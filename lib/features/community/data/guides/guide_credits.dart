import '../guides_repository.dart';

// Who wrote the bundled guides, stated once. Keep this true.
//
// The guides were drafted with an AI writing assistant under the app
// owner's direction. Nobody with a veterinary or training qualification has
// written or reviewed them, and the app says so on every guide.

/// The author line of every English guide today.
const petCompanionTeam = GuideAuthor(
  name: 'Pet Companion team',
  role: 'App content team, writing with an AI assistant. Not veterinarians or trainers.',
);

/// The day the first guides (dogs and cats) were written.
const firstWritten = GuideDate(2026, 9, 30);
