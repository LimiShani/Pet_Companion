import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/guides/guide_catalog.dart';
import 'package:pet_companion/features/community/data/guides/guide_credits.dart';
import 'package:pet_companion/features/community/data/guides/guides_en.dart';
import 'package:pet_companion/features/community/data/guides/guides_he.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/widgets/small_tag.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'community_helpers.dart';

// The guides in Hebrew: the text bundled with the app, held to its English
// original, and the screens that show it.
//
// The Hebrew text is a translation. These checks cannot read Hebrew for
// meaning; what they can hold is its shape (guide for guide, section for
// section, point for point), that every mention of the vet or of a doctor
// in the English has its counterpart, that the sentences a reader's safety
// hangs on are there, and that the credit stays truthful: written and
// translated with an AI assistant, not reviewed by a veterinarian.

const hebrewTitles = {
  'first-week': 'השבוע הראשון של הגור בבית',
  'house-training': 'חינוך לצרכים בלי לחץ',
  'sit-stay-come': 'ישיבה, הישארות והגעה: שלושת היסודות',
  'loose-lead': 'הליכה נעימה ברצועה רפויה',
  'feeding': 'כמה להאכיל ובאיזו תדירות',
  'unsafe-foods': 'מאכלים שאסור לתת לכלב',
  'grooming': 'שגרת טיפוח פשוטה',
  'call-the-vet': 'מתי להתקשר לווטרינר',
  'senior-comfort': 'נוחות לכלב מבוגר',
  'cat-first-week': 'השבוע הראשון של החתול בבית',
  'second-cat': 'מביאים הביתה חתול שני',
  'litter-setup': 'מארגנים את ארגז החול',
  'litter-count': 'כמה ארגזי חול צריך?',
  'litter-smell': 'שומרים על הריח והלכלוך של החול בשליטה',
  'indoor-play': 'משחק והעשרה לחתולי בית',
  'cat-nights': 'כשהחתול לא נותן לישון בלילה',
  'scratch-bite': 'שריטות ונשיכות משחק',
  'cat-call-vet': 'מתי להתקשר לווטרינר בנוגע לחתול',
};

/// Every word of a guide's text.
String wordsOf(GuideText text) => [
      text.title,
      text.summary,
      text.intro,
      for (final s in text.sections) ...[s.heading, ...s.paragraphs, ...s.bullets, ...s.after],
    ].join(' ');

/// Every separate piece of a guide's text.
List<String> piecesOf(GuideText text) => [
      text.title,
      text.summary,
      text.intro,
      for (final s in text.sections) ...[s.heading, ...s.paragraphs, ...s.bullets, ...s.after],
    ];

int count(Pattern pattern, String text) => pattern.allMatches(text).length;

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

Finder tag(String label) => find.widgetWithText(SmallTag, label);

const small = Size(320, 568);

/// Scrolls the reader down until [finder] is on screen, and lets the page
/// settle there.
Future<void> readDownTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the Hebrew text of the guides', () {
    test('every guide has Hebrew text, with the title the owner was given to read', () {
      expect(guidesHe.keys.toSet(), {for (final record in guideRecords) record.id});
      expect({for (final MapEntry(:key, :value) in guidesHe.entries) key: value.title}, hebrewTitles);
      expect(hebrewTitles.values.toSet(), hasLength(18));
    });

    test('each one has the shape of its English guide: sections, paragraphs, points', () {
      for (final MapEntry(key: id, value: hebrew) in guidesHe.entries) {
        final english = guidesEn[id]!;
        expect(hebrew.sections.length, english.sections.length, reason: id);
        for (var i = 0; i < english.sections.length; i++) {
          final h = hebrew.sections[i];
          final e = english.sections[i];
          expect(h.paragraphs.length, e.paragraphs.length, reason: '$id section $i: paragraphs');
          expect(h.bullets.length, e.bullets.length, reason: '$id section $i: points');
          expect(h.after.length, e.after.length, reason: '$id section $i: closing paragraphs');
        }
      }
    });

    test('no piece is left empty, and none is still in English', () {
      final latin = RegExp('[A-Za-z]');
      final hebrewLetter = RegExp('[\u{05D0}-\u{05EA}]');
      for (final MapEntry(key: id, value: text) in guidesHe.entries) {
        for (final piece in piecesOf(text)) {
          expect(piece.trim(), isNotEmpty, reason: id);
          expect(hebrewLetter.hasMatch(piece), isTrue, reason: '$id: $piece');
          expect(latin.hasMatch(piece), isFalse, reason: '$id: $piece');
        }
      }
    });

    test('every mention of the vet, or of a doctor, in English has its counterpart', () {
      // A guide that sends the reader to the vet three times in English
      // does so three times in Hebrew: none dropped, none added.
      final vetEn = RegExp(r'\bvets?\b|veterinar', caseSensitive: false);
      final doctorEn = RegExp(r'\bdoctor\b', caseSensitive: false);
      var mentions = 0;
      for (final MapEntry(key: id, value: hebrew) in guidesHe.entries) {
        final english = wordsOf(guidesEn[id]!);
        final words = wordsOf(hebrew);
        expect(count('וטרינר', words), count(vetEn, english), reason: '$id: the vet');
        expect(count('רופא', words), count(doctorEn, english), reason: '$id: a doctor');
        mentions += count(vetEn, english);
      }
      expect(mentions, greaterThan(30));
    });

    test('the guides on when to call the vet keep their lists whole', () {
      List<int> points(GuideText text) => [for (final s in text.sections) s.bullets.length];

      final dog = guidesHe['call-the-vet']!;
      expect(dog.sections.map((s) => s.heading), ['להתקשר מיד', 'לקבוע ביקור בקרוב', 'להיות מוכנים']);
      expect(points(dog), [8, 5, 0]);
      expect(points(dog), points(guidesEn['call-the-vet']!));
      expect(wordsOf(dog), contains('כשיש ספק, מתקשרים למרפאה הווטרינרית'));
      expect(
        wordsOf(dog),
        contains('אף פעם לא נותנים משככי כאבים של בני אדם, כמו איבופרופן או פרצטמול: הם עלולים להיות מסוכנים לכלבים.'),
      );

      final cat = guidesHe['cat-call-vet']!;
      expect(
        cat.sections.map((s) => s.heading),
        ['להתקשר מיד', 'להתקשר באותו יום', 'לקבוע ביקור בקרוב', 'להיות מוכנים'],
      );
      expect(points(cat), [6, 3, 4, 0]);
      expect(points(cat), points(guidesEn['cat-call-vet']!));
      // It says what it cannot do, as the English guide does.
      expect(wordsOf(cat), contains('המדריך הזה לא יכול לומר מה לא בסדר אצל החתול שלך: רק וטרינר שבודק אותו יכול.'));
      expect(wordsOf(cat), contains('כשיש ספק, מתקשרים למרפאה הווטרינרית.'));
      expect(wordsOf(cat), contains('יום שלם בלי לאכול דבר. לא מחכים יותר מזה.'));
      expect(wordsOf(cat), contains('נותנים רק מה שהווטרינר רשם לחתול הזה.'));
    });

    test('the other cautions a reader\'s safety hangs on are there', () {
      String he(String id) => wordsOf(guidesHe[id]!);

      // What never to feed, and what to do if it was eaten.
      for (final food in ['שוקולד', 'ענבים וצימוקים', 'בצל, שום, כרישה ועירית', 'קסיליטול', 'אגוזי מקדמיה', 'אלכוהול']) {
        expect(he('unsafe-foods'), contains(food), reason: food);
      }
      expect(he('unsafe-foods'), contains('מתקשרים מיד לווטרינר או למוקד הרעלות לבעלי חיים, גם אם נראה שהכלב מרגיש טוב'));
      expect(he('unsafe-foods'), contains('לא מנסים לגרום לכלב להקיא, אלא אם וטרינר הורה לעשות זאת.'));
      // A cat that strains and passes no urine.
      expect(he('litter-count'), contains('ובמיוחד חתול זכר, צריך וטרינר בדחיפות.'));
      expect(he('litter-count'), contains('מתקשרים לווטרינר ולא מחכים.'));
      // A new cat that does not eat; lilies.
      expect(he('cat-first-week'), contains('מתקשרים לווטרינר ולא מחכים.'));
      expect(he('cat-first-week'), contains('רעילים מאוד לחתולים'));
      // Products for people are not for pets.
      expect(he('grooming'), contains('אף פעם לא משתמשים במשחת שיניים של בני אדם'));
      expect(he('grooming'), contains('לא דוחפים מקלוני צמר גפן לתוך תעלת האוזן.'));
      // No punishment; no declawing; a bite that breaks the skin.
      expect(he('house-training'), contains('אף פעם לא נוזפים ולא מענישים'));
      expect(he('scratch-bite'), contains('עקירת הציפורניים איננה פתרון: זו קטיעה'));
      expect(he('scratch-bite'), contains('כשנשיכה חודרת את העור פונים לרופא.'));
      expect(he('litter-smell'), contains('בזמן היריון'));
      expect(he('loose-lead'), contains('כדאי להימנע מקולרי חנק, מקולרי דוקרנים ומקולרים חשמליים'));
    });

    test('no doses, no exclamation marks, Hebrew quotation marks, nobody addressed as a man or a woman', () {
      final dose = RegExp(r'\d+\s?(מ״ג|מ״ל|מג|מל|מיליגרם|מיליליטר|mg|ml)');
      // A command to one person, as a word of its own.
      final command = RegExp(
        r'(?:^|[\s״(])(?:תן|תני|קח|קחי|שים|שימי|בדוק|בדקי|פנה|פני|התקשר|התקשרי|נסה|נסי|הקפד|הקפידי|אל תיתן|אל תיתני)(?:[\s.,:]|$)',
      );
      for (final MapEntry(key: id, value: text) in guidesHe.entries) {
        final words = wordsOf(text);
        expect(words, isNot(contains(dose)), reason: id);
        expect(words, isNot(contains('!')), reason: id);
        expect(words, isNot(contains('"')), reason: id);
        expect(words, isNot(contains("'")), reason: id);
        expect(words, isNot(contains('/')), reason: id);
        expect(words, isNot(contains(RegExp(r'(?:^|\s)אתה(?:[\s.,:]|$)'))), reason: id);
        for (final piece in piecesOf(text)) {
          expect(command.hasMatch(piece), isFalse, reason: '$id: $piece');
        }
      }
    });

    test('the credit is truthful: the team, an AI assistant, a translation, and no vet', () {
      for (final MapEntry(key: id, value: text) in guidesHe.entries) {
        expect(text.author, same(petCompanionTeamHe), reason: id);
        // Nobody has reviewed the Hebrew text, and it cites nothing.
        expect(text.review, isNull, reason: id);
        expect(text.currentReview, isNull, reason: id);
        expect(text.sources, isEmpty, reason: id);
        expect(text.updatedAt.toDateTime(), DateTime(2026, 9, 30), reason: id);
      }
      expect(petCompanionTeamHe.name, 'צוות Pet Companion');
      expect(
        petCompanionTeamHe.role,
        'צוות התוכן של האפליקציה, בכתיבה ובתרגום בעזרת עוזר בינה מלאכותית. לא וטרינרים ולא מאלפים.',
      );
      // No guide says, in its own words, that a vet wrote, checked or
      // approved it.
      for (final MapEntry(key: id, value: text) in guidesHe.entries) {
        final words = wordsOf(text);
        for (final claim in ['נבדק על ידי', 'אושר על ידי', 'באישור וטרינר', 'נכתב על ידי וטרינר', 'בפיקוח וטרינר']) {
          expect(words, isNot(contains(claim)), reason: '$id: $claim');
        }
      }
    });

    test('the repository serves every guide in Hebrew, none of them as "English only"', () async {
      final guides = await const BundledGuidesRepository().fetchGuides(ContentLanguage.he);
      expect(guides, hasLength(18));
      for (final guide in guides) {
        expect(guide.language, ContentLanguage.he, reason: guide.id);
        expect(guide.translated, isTrue, reason: guide.id);
        expect(guide.title, hebrewTitles[guide.id], reason: guide.id);
        expect(guide.review, isNull, reason: guide.id);
        expect(guide.readingMinutes, inInclusiveRange(1, 5), reason: guide.id);
      }
      expect(guides.where((g) => g.audience == Audience.dogs), hasLength(9));
      expect(guides.where((g) => g.audience == Audience.cats), hasLength(9));

      // A Hebrew search finds a Hebrew guide.
      List<String> search(String q) => [for (final g in guides) if (g.matches(q)) g.id];
      expect(search('קסיליטול שוקולד'), ['unsafe-foods']);
      expect(search('ארגז חול ועוד אחד'), contains('litter-count'));
      expect(search('zzzz'), isEmpty);

      // English stays what it was.
      final english = await const BundledGuidesRepository().fetchGuides(ContentLanguage.en);
      expect(english.every((g) => g.language == ContentLanguage.en && g.translated), isTrue);
    });
  });

  group('the guides on a Hebrew screen', () {
    for (final size in [const Size(390, 844), small]) {
      final width = size.width.toInt();

      testWidgets('the whole library reads in Hebrew, right to left, with its credit ($width px)', (tester) async {
        await pumpCommunity(tester, harness: CommunityHarness(appLanguage: AppLanguage.hebrew), size: size);
        await openSection(tester, he.sectionGuides);
        await chooseScope(tester, 'everything');

        // All 18 cards, in the library's order: none is tagged as English
        // only, none as reviewed, and each says who wrote it.
        final byline = reads('מאת צוות Pet Companion · עודכן בתאריך 30.09.26');
        for (final record in guideRecords) {
          final title = find.text(hebrewTitles[record.id]!);
          await scrollTo(tester, title);
          expect(screenDirection(tester, title), TextDirection.rtl, reason: record.id);
          expect(tag(he.tagEnglishOnly), findsNothing, reason: record.id);
          expect(tag(he.tagReviewed), findsNothing, reason: record.id);
        }
        expect(byline, findsWidgets);
        expect(find.textContaining('Pet Companion team'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the cat guide on calling the vet, to its end ($width px)', (tester) async {
        await pumpCommunity(
          tester,
          harness: CommunityHarness(appLanguage: AppLanguage.hebrew, pets: catFirst),
          size: size,
        );
        await openSection(tester, he.sectionGuides);
        await tapVisible(tester, find.byKey(const ValueKey('category-health')));
        await tapVisible(tester, find.text('מתי להתקשר לווטרינר בנוגע לחתול'));

        expect(headerTitle('מדריך'), findsOneWidget);
        expect(find.text('בריאות וטיפוח'), findsOneWidget);
        expect(tag(he.tagEnglishOnly), findsNothing);
        expect(screenDirection(tester, find.text('מתי להתקשר לווטרינר בנוגע לחתול')), TextDirection.rtl);

        // The box about the guide comes first, and says it plainly.
        final about = find.byKey(const Key('about-guide'));
        Finder inAbout(String text) => find.descendant(of: about, matching: find.text(text));
        await readDownTo(tester, inAbout('מקורות'));
        expect(inAbout('נכתב על ידי'), findsOneWidget);
        expect(inAbout('צוות Pet Companion'), findsOneWidget);
        expect(inAbout(petCompanionTeamHe.role), findsOneWidget);
        expect(inAbout('בדיקה מקצועית'), findsOneWidget);
        expect(inAbout('לא נבדק על ידי וטרינר'), findsOneWidget);
        expect(inAbout('30.09.26'), findsOneWidget);
        expect(inAbout('לא צוינו מקורות'), findsOneWidget);
        expect(find.byKey(const Key('guide-review')), findsNothing);
        expect(find.text('נבדק על ידי'), findsNothing);
        final intro = find.textContaining('רק וטרינר שבודק אותו יכול');
        await readDownTo(tester, intro);
        expect(screenDirection(tester, intro), TextDirection.rtl);

        // The four headed parts, in order, down to the closing note and the
        // way to a professional.
        for (final heading in ['להתקשר מיד', 'להתקשר באותו יום', 'לקבוע ביקור בקרוב', 'להיות מוכנים']) {
          await readDownTo(tester, find.text(heading));
          expect(screenDirection(tester, find.text(heading)), TextDirection.rtl);
        }
        await readDownTo(tester, find.textContaining('נותנים רק מה שהווטרינר רשם לחתול הזה.'));
        await readDownTo(tester, find.text(he.guideDisclaimer));
        final contact = find.text(he.contactProfessional);
        await readDownTo(tester, contact);
        await tapVisible(tester, contact);
        await settleHealth(tester);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a Hebrew search finds a Hebrew guide', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: AppLanguage.hebrew));
      await openSection(tester, he.sectionGuides);

      await tester.enterText(find.byType(TextField), 'קסיליטול');
      await tester.pumpAndSettle();
      expect(find.text('מאכלים שאסור לתת לכלב'), findsOneWidget);
      expect(find.text('השבוע הראשון של הגור בבית'), findsNothing);
      // The search field types in the direction of the search.
      expect(tester.widget<EditableText>(find.byType(EditableText)).textDirection, TextDirection.rtl);
    });

    testWidgets('a guide being read changes language with the app, both ways', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, en.sectionGuides);
      await scrollTo(tester, find.text('How many litter boxes do you need?'));
      await tester.tap(find.text('How many litter boxes do you need?'));
      await tester.pumpAndSettle();
      expect(find.text('Pet Companion team'), findsOneWidget);
      expect(find.text('Not reviewed by a veterinarian'), findsOneWidget);

      await switchLanguage(tester, AppLanguage.hebrew);
      expect(find.text('כמה ארגזי חול צריך?'), findsOneWidget);
      expect(find.text('How many litter boxes do you need?'), findsNothing);
      expect(find.text('צוות Pet Companion'), findsOneWidget);
      expect(find.text('לא נבדק על ידי וטרינר'), findsOneWidget);
      expect(tag(he.tagEnglishOnly), findsNothing);
      expect(
        screenDirection(tester, find.textContaining('הכלל המקובל פשוט')),
        TextDirection.rtl,
      );

      await switchLanguage(tester, AppLanguage.english);
      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(find.text('Pet Companion team'), findsOneWidget);
      expect(screenDirection(tester, find.textContaining('The usual guideline is simple')), TextDirection.ltr);
    });
  });
}
