import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/guides/guides_en.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';

// Guides that exist only in the tests, to exercise what no bundled guide
// uses yet: a Hebrew text, a recorded review and cited sources. Every name
// below is a made-up fixture and says so; none of it ships in the app.

/// A Hebrew text for the "How many litter boxes" guide (same shape as the
/// English one: four sections).
const hebrewFixture = GuideText(
  author: GuideAuthor(name: 'מחבר לבדיקה', role: 'טקסט לבדיקה בלבד'),
  updatedAt: GuideDate(2026, 10, 1),
  title: 'כמה ארגזי חול צריך?',
  summary: 'ארגז לכל חתול, ועוד אחד.',
  intro: 'הכלל המקובל פשוט: ארגז חול אחד לכל חתול, ועוד אחד נוסף.',
  sections: [
    GuideSection(heading: 'למה צריך ארגז נוסף', paragraphs: ['חתולים רבים מעדיפים ארגז נקי.']),
    GuideSection(heading: 'איפה לשים', bullets: ['במקום שקט.', 'רחוק מהאוכל.', 'בכל קומה.', 'לא בפינה סגורה.']),
    GuideSection(heading: 'בבית קטן', paragraphs: ['כמה שאפשר, ולנקות לעתים קרובות.']),
    GuideSection(heading: 'כשחתול מפסיק להשתמש בארגז', paragraphs: ['להתקשר לווטרינר.']),
  ],
);

/// The bundled English guides, with the Hebrew fixture as the only Hebrew
/// text.
const bilingualGuides = BundledGuidesRepository(
  texts: {
    ContentLanguage.en: guidesEn,
    ContentLanguage.he: {'litter-count': hebrewFixture},
  },
);

const fixtureReview = GuideReview(
  reviewerName: 'Test Reviewer (fixture)',
  reviewerRole: 'Veterinarian',
  reviewedAt: GuideDate(2026, 10, 5),
);

GuideText _fixtureText({required String title, required GuideDate updatedAt, List<GuideSource> sources = const []}) =>
    GuideText(
      author: const GuideAuthor(name: 'Fixture team', role: 'Test fixture, not a real author.'),
      updatedAt: updatedAt,
      review: fixtureReview,
      sources: sources,
      title: title,
      summary: 'A guide that exists only in the tests.',
      intro: 'Fixture intro.',
      sections: const [
        GuideSection(heading: 'Fixture section', paragraphs: ['Fixture paragraph.']),
      ],
    );

/// Two fixture guides with the same recorded review: one whose text has not
/// changed since the review (with two sources, one of them linked), and one
/// whose text was changed after it.
final reviewedGuides = BundledGuidesRepository(
  records: const [
    GuideRecord(id: 'reviewed', categoryId: 'health', audience: Audience.cats),
    GuideRecord(id: 'stale', categoryId: 'health', audience: Audience.cats),
  ],
  texts: {
    ContentLanguage.en: {
      'reviewed': _fixtureText(
        title: 'Fixture: reviewed guide',
        updatedAt: const GuideDate(2026, 10, 1),
        sources: const [
          GuideSource(title: 'Fixture source with a link', publisher: 'Fixture Press', url: 'https://example.com/fixture'),
          GuideSource(title: 'Fixture source without a link'),
        ],
      ),
      'stale': _fixtureText(title: 'Fixture: changed after review', updatedAt: const GuideDate(2026, 10, 9)),
    },
  },
);
