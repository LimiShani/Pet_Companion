import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/community/community_words.dart';
import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/guides/guide_catalog.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'community_helpers.dart';

// The Community's words in both languages, without a screen: the strings
// files themselves, the plural forms, and the bridge from what the data
// layer holds (a reason, a room id, a view) to what the screen says.

final _hebrewLetter = RegExp('[\u{05D0}-\u{05EA}]');
final _latinLetter = RegExp('[A-Za-z]');

final now = DateTime(2026, 5, 14, 9, 41);

String _agoHe(Duration d) => he.relativeTime(appHe, const AppFormat('he'), now.subtract(d), now);
String _agoEn(Duration d) => en.relativeTime(appEn, const AppFormat('en'), now.subtract(d), now);

Map<String, String> _messages(String path) {
  final arb = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in arb.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value as String,
  };
}

void main() {
  // The app's language looks at the phone's languages, through the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the strings files', () {
    final english = _messages('lib/features/community/l10n/community_en.arb');
    final hebrew = _messages('lib/features/community/l10n/community_he.arb');

    test('every Community string is in Hebrew', () {
      expect(hebrew.keys.toSet(), english.keys.toSet());
      final report = jsonDecode(File('lib/features/community/l10n/gen/untranslated.json').readAsStringSync());
      expect(report, isEmpty);
    });

    test('every Hebrew message is written in Hebrew', () {
      for (final MapEntry(:key, :value) in hebrew.entries) {
        // "{title}, {publisher}" is punctuation around two placeholders.
        if (key == 'sourceWithPublisher') continue;
        expect(_hebrewLetter.hasMatch(value), isTrue, reason: key);
      }
    });

    test('the only Latin words in Hebrew messages are names that stay as they are', () {
      const kept = ['PetLoop', 'JPEG', 'PNG', 'WebP'];
      for (final MapEntry(:key, :value) in hebrew.entries) {
        var text = value.replaceAll(RegExp(r'\{[a-zA-Z]+(, plural,)?'), '').replaceAll(RegExp(r'other\{|=\d\{'), '');
        for (final name in kept) {
          text = text.replaceAll(name, '');
        }
        expect(_latinLetter.hasMatch(text), isFalse, reason: '$key: $value');
      }
    });

    test('Hebrew punctuation: no exclamation marks, Hebrew quotation marks, geresh in צ׳אט', () {
      for (final MapEntry(:key, :value) in hebrew.entries) {
        expect(value, isNot(contains('!')), reason: key);
        expect(value, isNot(contains('"')), reason: key);
        expect(value, isNot(contains("'")), reason: key);
        expect(value, isNot(contains('צאט')), reason: key);
      }
      expect(he.sectionChat, 'צ׳אט');
      expect(he.roomsMatchedTo('Kelly'), contains('״הכול״'));
    });

    test('nobody is addressed as a man or as a woman: no slashed forms, no singular commands', () {
      // A command to one person, as a word of its own ("לכתוב" is fine).
      final command = RegExp(
        r'(?:^|[\s״(])(?:לחץ|לחצי|הקלד|הקלידי|בחר|בחרי|נסה|נסי|כתוב|כתבי|שלח|שלחי|הוסף|הוסיפי|שמור|שמרי|פנה|פני|בדוק|בדקי)(?:[\s.,:]|$)',
      );
      for (final MapEntry(:key, :value) in hebrew.entries) {
        expect(value, isNot(contains('/')), reason: key);
        expect(command.hasMatch(value), isFalse, reason: '$key: $value');
      }
    });

    test('the words the glossary fixes are used as they are', () {
      expect(he.tabTitle, 'קהילה');
      expect([he.sectionFeed, he.sectionChat, he.sectionGuides], ['פיד', 'צ׳אט', 'מדריכים']);
      expect(he.newPost, 'פוסט חדש');
      expect(he.postButton, 'פרסום');
      expect([he.like, he.comments, he.report], ['לייק', 'תגובות', 'דיווח']);
      expect(plain(he.messageHint(he.roomGeneral)), 'הודעה בחדר ״כללי״');
      expect(
        [he.roomGeneral, he.roomPuppies, he.roomTraining, he.roomSeniors, he.roomHealth],
        ['כללי', 'גורים', 'טיפים לאילוף', 'כלבים מבוגרים', 'שאלות בריאות'],
      );
      expect(he.noMessagesTitle, 'עדיין אין הודעות');
      expect(he.guideDisclaimer, 'המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר.');
      expect(appHe.commonTryAgain, 'לנסות שוב');
    });

    test('the attribution says the same thing in both languages: no vet reviewed the guides', () {
      expect(en.notReviewedByVet, 'Not reviewed by a veterinarian');
      expect(he.notReviewedByVet, 'לא נבדק על ידי וטרינר');
      expect(he.professionalReview, 'בדיקה מקצועית');
      expect(he.aboutThisGuide, 'על המדריך הזה');
      expect(he.writtenBy, 'נכתב על ידי');
      expect(he.adviceNotice, 'חברי הקהילה משתפים מניסיון אישי, לא ייעוץ מקצועי.');
    });
  });

  group('plural forms: one, two and many', () {
    test('likes', () {
      expect([for (final n in [0, 1, 2, 3, 14]) he.likeCount(n)], ['אין לייקים', 'לייק אחד', 'שני לייקים', '3 לייקים', '14 לייקים']);
      expect([for (final n in [0, 1, 2, 14]) en.likeCount(n)], ['No likes', '1 like', '2 likes', '14 likes']);
    });

    test('comments', () {
      expect(
        [for (final n in [0, 1, 2, 3, 11]) he.commentCount(n)],
        ['אין תגובות', 'תגובה אחת', 'שתי תגובות', '3 תגובות', '11 תגובות'],
      );
      expect([for (final n in [0, 1, 2]) en.commentCount(n)], ['No comments', '1 comment', '2 comments']);
    });

    test('minutes, hours and days ago', () {
      expect(_agoHe(const Duration(seconds: 20)), 'ממש עכשיו');
      expect(_agoHe(const Duration(minutes: 1)), 'לפני דקה');
      expect(_agoHe(const Duration(minutes: 2)), 'לפני שתי דקות');
      expect(_agoHe(const Duration(minutes: 12)), 'לפני 12 דקות');
      expect(_agoHe(const Duration(hours: 1)), 'לפני שעה');
      expect(_agoHe(const Duration(hours: 2)), 'לפני שעתיים');
      expect(_agoHe(const Duration(hours: 5)), 'לפני 5 שעות');
      expect(_agoHe(const Duration(hours: 30)), 'אתמול');
      expect(_agoHe(const Duration(days: 2)), 'לפני יומיים');
      expect(_agoHe(const Duration(days: 3)), 'לפני 3 ימים');
      expect(_agoHe(const Duration(days: 30)), '14.04.26');

      expect(_agoEn(const Duration(minutes: 1)), '1 min ago');
      expect(_agoEn(const Duration(hours: 1)), '1 h ago');
      expect(_agoEn(const Duration(days: 2)), '2 days ago');
    });

    test('reading time and matches elsewhere', () {
      expect([for (final n in [1, 2, 3]) he.readTime(n)], ['דקת קריאה', 'שתי דקות קריאה', '3 דקות קריאה']);
      expect([for (final n in [1, 2, 3]) en.readTime(n)], ['1 min read', '2 min read', '3 min read']);
      expect(he.matchesElsewhere(1), 'יש התאמה אחת במדריכים של כל החיות.');
      expect(he.matchesElsewhere(2), 'יש שתי התאמות במדריכים של כל החיות.');
      expect(he.matchesElsewhere(5), 'יש 5 התאמות במדריכים של כל החיות.');
      expect(en.matchesElsewhere(1), 'There is 1 match among the guides for every animal.');
      expect(en.matchesElsewhere(5), 'There are 5 matches among the guides for every animal.');
    });

    test('chat day headings', () {
      const format = AppFormat('he');
      expect(dayLabel(appHe, format, DateTime(2026, 5, 14, 0, 5), now), 'היום');
      expect(dayLabel(appHe, format, DateTime(2026, 5, 13, 23, 50), now), 'אתמול');
      expect(dayLabel(appHe, format, DateTime(2026, 5, 1, 12), now), '01.05.26');
      expect(format.time(DateTime(2026, 5, 14, 8, 5)), '08:05');
    });
  });

  group('failures are reasons, worded on the screen', () {
    const englishWords = {
      CommunityFailure.unreachable: 'Cannot reach the community right now. Please try again.',
      CommunityFailure.chatUnreachable: 'Cannot reach the chat right now. Please try again.',
      CommunityFailure.offline: 'Cannot reach the community right now. Check your connection and try again.',
      CommunityFailure.postGone: 'This post is no longer available.',
      CommunityFailure.emptyPost: 'Write something before posting.',
      CommunityFailure.emptyMessage: 'Write something before sending.',
      CommunityFailure.notYourPost: 'You can only delete your own posts.',
      CommunityFailure.signInAgain: 'Please sign in again.',
      CommunityFailure.notAllowed: 'You are not allowed to do that.',
      CommunityFailure.textInvalid: 'That text is empty or too long.',
      CommunityFailure.gone: 'This is no longer available.',
      CommunityFailure.notSetUp: 'The community is not set up on the server yet.',
      CommunityFailure.photoTooLarge: 'That photo is too large. Please choose a smaller one.',
      CommunityFailure.photoUnsupported: 'Please choose a JPEG, PNG or WebP photo.',
      CommunityFailure.photoUpload: 'The photo could not be uploaded. Please try again.',
      CommunityFailure.cameraNotAllowed: 'Cannot open the camera. Check that PetLoop is allowed to use it.',
      CommunityFailure.photosNotAllowed: 'Cannot open your photos. Check that PetLoop is allowed to see them.',
      CommunityFailure.slowDown: 'That was quick! Please wait a minute before sending more.',
      CommunityFailure.notModerator: 'Only community moderators can do this.',
      CommunityFailure.unknown: 'Something went wrong. Please try again.',
    };
    const hebrewWords = {
      CommunityFailure.unreachable: 'לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.',
      CommunityFailure.chatUnreachable: 'לא הצלחנו להתחבר לצ׳אט כרגע. אפשר לנסות שוב.',
      CommunityFailure.offline: 'אין חיבור לקהילה כרגע. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.',
      CommunityFailure.postGone: 'הפוסט הזה כבר לא זמין.',
      CommunityFailure.emptyPost: 'צריך לכתוב משהו לפני הפרסום.',
      CommunityFailure.emptyMessage: 'צריך לכתוב משהו לפני השליחה.',
      CommunityFailure.notYourPost: 'אפשר למחוק רק פוסטים שלך.',
      CommunityFailure.signInAgain: 'צריך להיכנס שוב לחשבון.',
      CommunityFailure.notAllowed: 'אין הרשאה לפעולה הזאת.',
      CommunityFailure.textInvalid: 'הטקסט ריק או ארוך מדי.',
      CommunityFailure.gone: 'התוכן הזה כבר לא זמין.',
      CommunityFailure.notSetUp: 'הקהילה עדיין לא הוגדרה בשרת.',
      CommunityFailure.photoTooLarge: 'התמונה גדולה מדי. אפשר לבחור תמונה קטנה יותר.',
      CommunityFailure.photoUnsupported: 'צריך לבחור תמונה מסוג JPEG, PNG או WebP.',
      CommunityFailure.photoUpload: 'לא הצלחנו להעלות את התמונה. אפשר לנסות שוב.',
      CommunityFailure.cameraNotAllowed:
          'אי אפשר לפתוח את המצלמה. כדאי לבדוק שיש ל־PetLoop הרשאה להשתמש בה.',
      CommunityFailure.photosNotAllowed:
          'אי אפשר לפתוח את התמונות שלך. כדאי לבדוק שיש ל־PetLoop הרשאה לראות אותן.',
      CommunityFailure.slowDown: 'רגע, זה היה מהר. כדאי לחכות דקה לפני שליחה נוספת.',
      CommunityFailure.notModerator: 'רק מנהלי הקהילה יכולים לעשות את זה.',
      CommunityFailure.unknown: 'משהו השתבש. אפשר לנסות שוב.',
    };

    for (final failure in CommunityFailure.values) {
      test('${failure.name} has words in both languages', () {
        final error = CommunityException(failure, 'a detail for the logs');
        expect(communityFailureText(en, appEn, error), englishWords[failure], reason: 'English');
        expect(communityFailureText(he, appHe, error), hebrewWords[failure], reason: 'Hebrew');
        // The detail is for logs: it never reaches the screen.
        expect(communityFailureText(he, appHe, error), isNot(contains('detail')));
      });
    }

    test('anything that is not a community failure gets the plain line of the language', () {
      expect(communityFailureText(en, appEn, StateError('boom')), 'Something went wrong. Please try again.');
      expect(communityFailureText(he, appHe, StateError('boom')), 'משהו השתבש. אפשר לנסות שוב.');
      expect(communityFailureText(he, appHe, null), 'משהו השתבש. אפשר לנסות שוב.');
    });
  });

  group('values into words', () {
    test('views, tags and "for whom"', () {
      expect([for (final s in CommunityScope.values) he.scope(s)], ['כלבים', 'חתולים', 'הכול']);
      expect([for (final s in CommunityScope.values) en.scope(s)], ['Dogs', 'Cats', 'Everything']);
      expect(
        [for (final a in Audience.values) he.audienceTag(a)],
        [null, 'כלבים', 'חתולים', 'חיות אחרות'],
      );
      expect(
        [for (final a in Audience.values) he.forWhom(a)],
        [null, 'עבור כלבים', 'עבור חתולים', 'עבור חיות אחרות'],
      );
      expect([for (final a in Audience.values) en.forWhom(a)], [null, 'For dogs', 'For cats', 'For other animals']);
    });

    test('the captions under the chips are whole sentences', () {
      expect(plain(he.roomsCaption(CommunityScope.dogs, matchedPet: 'Kelly')),
          'מותאם עבור Kelly. לחיצה על ״הכול״ מציגה את כל החדרים.');
      expect(plain(he.guidesCaption(CommunityScope.cats, matchedPet: 'Mitzi')),
          'מותאם עבור Mitzi. לחיצה על ״הכול״ מציגה את כל המדריכים.');
      // The pet's name is wrapped, so a Latin name cannot reorder the line.
      expect(he.roomsCaption(CommunityScope.dogs, matchedPet: 'Kelly'), contains(isolate('Kelly')));
      expect(he.roomsCaption(CommunityScope.cats), 'מוצגים חדרים עבור חתולים.');
      expect(he.roomsCaption(CommunityScope.everything), 'מוצגים החדרים של כל החיות.');
      expect(he.guidesCaption(CommunityScope.dogs), 'מוצגים מדריכים עבור כלבים.');
      expect(he.guidesCaption(CommunityScope.everything), 'מוצגים המדריכים של כל החיות.');
      expect(en.roomsCaption(CommunityScope.dogs, matchedPet: 'Kelly'),
          'Matched to Kelly. Tap Everything to see all rooms.');
    });

    test('every room the app ships with has a Hebrew name and description', () {
      for (final room in FakeChatRepository.defaultChannels) {
        // English: exactly what is stored.
        expect(en.roomName(room), room.name, reason: room.id);
        expect(en.roomAbout(room), room.description, reason: room.id);
        expect(_hebrewLetter.hasMatch(he.roomName(room)), isTrue, reason: room.id);
        expect(_hebrewLetter.hasMatch(he.roomAbout(room)), isTrue, reason: room.id);
        expect(_latinLetter.hasMatch(he.roomName(room) + he.roomAbout(room)), isFalse, reason: room.id);
      }
      expect({for (final room in FakeChatRepository.defaultChannels) he.roomName(room)}, hasLength(9));
    });

    test('a room added later keeps its stored name', () {
      const added = ChatChannel(id: 'rabbits', name: 'Rabbits', description: 'Hay, hutches and hops');
      expect(he.roomName(added), 'Rabbits');
      expect(he.roomAbout(added), 'Hay, hutches and hops');
    });

    test('every guide category has a Hebrew name; one added later keeps its stored name', () {
      expect(
        [for (final c in guideCategories) he.categoryName(c)],
        ['צעדים ראשונים', 'בית וניקיון', 'אילוף והתנהגות', 'תזונה', 'בריאות וטיפוח', 'טיפול בגיל מבוגר'],
      );
      expect([for (final c in guideCategories) en.categoryName(c)], [for (final c in guideCategories) c.name]);
      const added = GuideCategory(id: 'travel', name: 'Travel', icon: IconData(0));
      expect(he.categoryName(added), 'Travel');
    });

    test('report reasons', () {
      expect(
        [for (final r in ReportReason.values) he.reportReason(r)],
        ['ספאם או פרסומת', 'פוגעני או לא מכבד', 'לא הולם או מטריד', 'משהו אחר'],
      );
      expect(
        [for (final r in ReportReason.values) en.reportReason(r)],
        ['Spam or advertising', 'Unkind or abusive', 'Inappropriate or upsetting', 'Something else'],
      );
      // What is stored is the reason's name, not its words.
      expect([for (final r in ReportReason.values) r.name], ['spam', 'abusive', 'inappropriate', 'other']);
    });

    test('a member without a name gets a friendly one in the language of the screen', () {
      expect(en.memberName(''), 'Pet lover');
      expect(he.memberName('  '), 'אוהבי חיות');
      expect(he.memberName('Maya'), 'Maya');
      expect(storedAuthorName('  Maya '), 'Maya');
      expect(storedAuthorName(null), '');
    });

    test('a name in the other script is kept as one unit inside a line', () {
      expect(he.inLine('Maya'), isolate('Maya'));
      expect(he.inLine('מאיה'), 'מאיה');
      expect(en.inLine('Maya'), 'Maya');
      expect(en.inLine('מאיה'), isolate('מאיה'));
      // Nothing to reorder: digits follow the line they are in.
      expect(he.inLine('123'), '123');
      expect(plain(he.postWithPet(he.inLine('Biscuit'))), 'עם Biscuit');
      expect(plain(he.guideBy('PetLoop team')), 'מאת PetLoop team');
      expect(plain(he.guideUpdated('30.09.26')), 'עודכן בתאריך 30.09.26');
      expect(plain(he.reviewedOn('05.10.26')), 'נבדק בתאריך 05.10.26');
      expect(dotted(['a', 'b']), 'a · b');
    });
  });

  group('the content language', () {
    ProviderContainer containerWith(AppLanguage? language) {
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(MemorySettingsStore({languageSettingKey: ?language?.code})),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('follows the language the app is showing', () {
      expect(containerWith(null).read(communityLanguageProvider), ContentLanguage.en);
      expect(containerWith(AppLanguage.english).read(communityLanguageProvider), ContentLanguage.en);
      expect(containerWith(AppLanguage.hebrew).read(communityLanguageProvider), ContentLanguage.he);
    });

    test('and changes with the language switch', () async {
      final container = containerWith(AppLanguage.english);
      expect(container.read(communityLanguageProvider), ContentLanguage.en);

      await container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew);
      expect(container.read(communityLanguageProvider), ContentLanguage.he);
      await container.read(appLanguageProvider.notifier).choose(AppLanguage.english);
      expect(container.read(communityLanguageProvider), ContentLanguage.en);
    });
  });
}
