import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/community_routes.dart';
import 'package:pet_companion/features/community/community_screen.dart';
import 'package:pet_companion/features/community/data/chat_repository.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/widgets/advice_notice.dart';
import 'package:pet_companion/features/community/widgets/message_bar.dart';
import 'package:pet_companion/features/community/widgets/small_tag.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:pet_companion/widgets/directional_icon.dart';

import '../helpers.dart';
import 'community_helpers.dart';
import 'guide_fixtures.dart';

// The Community tab in Hebrew, right to left, through the whole app. An
// overflow anywhere fails a test by itself, and the test font makes Hebrew
// letters as wide as Latin ones, so these layouts are checked as strictly
// as the English ones.
//
// What members wrote (the sample posts, comments, messages and names) stays
// as written, in its own direction. "Contact a professional" opens Health's
// emergency sheet, whose own words are Health's to translate: the tests
// only check that it opens.

const wide = Size(390, 844);
const small = Size(320, 568);

const mayaPost = 'First full night without a toilet trip! Four months old and we both finally slept. '
    'Taking him out right before bed made all the difference.';
const hebrewPost = 'שלום לכולם, זה הפוסט הראשון שלנו כאן.';

CommunityHarness hebrew({
  FakeFeedRepository? feed,
  FakeChatRepository? chat,
  List<Pet>? pets,
  GuidesRepository? guides,
}) =>
    CommunityHarness(appLanguage: AppLanguage.hebrew, feed: feed, chat: chat, pets: pets, guides: guides);

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

Finder cardOf(String author) => find.widgetWithText(PostCard, author);

Finder inCard(String author, Finder matching) => find.descendant(of: cardOf(author), matching: matching);

Finder tag(String label) => find.widgetWithText(SmallTag, label);

final adviceLine = find.byType(AdviceNotice);

Finder adviceWordsIn(CommunityL10n words) => find.descendant(
      of: adviceLine,
      matching: find.textContaining('${words.adviceNotice} ${words.contactProfessional}', findRichText: true),
    );

double screenWidth(WidgetTester tester) => tester.view.physicalSize.width / tester.view.devicePixelRatio;

/// Where the first letter of the text found by [finder] is drawn, inside
/// the text's own box: at its left for a line that reads left to right, at
/// its right for one that reads right to left.
({double left, double right, double width}) firstLetter(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final box = paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1)).first;
  return (left: box.left, right: box.right, width: paragraph.size.width);
}

/// The direction the message field is typing in.
TextDirection? typingDirection(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).textDirection;

/// Scrolls the screen's main list back to its top.
Future<void> toTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 8000));
  await tester.pumpAndSettle();
}

/// Lets the snack bar on screen run its time and leave.
Future<void> snackGone(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Goes to [location] inside the running app, as a link would.
Future<void> goTo(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(CommunityScreen))).go(location);
  await tester.pumpAndSettle();
}

/// One room with nobody in it yet.
class _QuietRoom implements ChatRepository {
  @override
  Future<List<ChatChannel>> fetchChannels() async =>
      const [ChatChannel(id: 'general', name: 'General', description: 'Say hello and share your day')];

  @override
  Stream<List<ChatMessage>> watchMessages(String channelId) => Stream.value(const []);

  @override
  Future<void> sendMessage({required AppUser author, required String channelId, required String text}) async {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [wide, small]) {
    final width = size.width.toInt();

    group('in Hebrew at $width px:', () {
      testWidgets('the feed, a post with its comments, the report sheet and the delete dialog', (tester) async {
        await pumpCommunity(tester, harness: hebrew(), size: size);

        expect(screenDirection(tester, find.byType(CommunityScreen)), TextDirection.rtl);
        // The tab's name: once in the header, once in the bottom bar.
        expect(find.text('קהילה'), findsNWidgets(2));
        for (final label in ['פיד', 'צ׳אט', 'מדריכים', 'פוסט חדש']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        for (final english in ['Community', 'Feed', 'Chat', 'Guides', 'New post']) {
          expect(find.text(english), findsNothing, reason: english);
        }

        // A sample post stays as written, left to right; the line under the
        // author's name is the app's, in Hebrew.
        expect(find.text('Maya'), findsOneWidget);
        expect(tester.widget<Text>(find.text(mayaPost)).textDirection, TextDirection.ltr);
        expect(reads('עם Biscuit · לפני 12 דקות'), findsOneWidget);
        expect(find.textContaining('min ago'), findsNothing);
        // The pet's name is one unit inside the Hebrew line.
        expect(tester.widget<Text>(reads('עם Biscuit · לפני 12 דקות')).data, contains(isolate('Biscuit')));

        // The numbers are read out in words, with the Hebrew form for two.
        expect(tester.widget<Text>(inCard('Maya', find.text('14'))).semanticsLabel, '14 לייקים');
        expect(tester.widget<Text>(inCard('Maya', find.text('2'))).semanticsLabel, 'שתי תגובות');

        await tester.tap(inCard('Maya', find.byTooltip('לייק')));
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(inCard('Maya', find.text('15'))).semanticsLabel, '15 לייקים');
        expect(inCard('Maya', find.byTooltip('ביטול הלייק')), findsOneWidget);

        // The other sample posts: "two hours", "two days", many.
        await scrollTo(tester, reads('עם Kelly · לפני שעתיים'));
        await scrollTo(tester, find.text('לפני 22 שעות'));
        await scrollTo(tester, reads('עם Pepper · לפני יומיים'));
        await scrollTo(tester, reads('עם Milo · לפני 6 ימים'));
        await toTop(tester);

        // The post with its comments.
        await tester.tap(find.text(mayaPost));
        await tester.pumpAndSettle();
        expect(headerTitle('פוסט'), findsOneWidget);
        await scrollTo(tester, find.text('תגובות'));
        expect(adviceWordsIn(he), findsOneWidget);
        await scrollTo(tester, reads('Jonas · לפני 9 דקות'));
        expect(
          tester.widget<Text>(find.text('Well done Biscuit! The early weeks are the hardest part.')).textDirection,
          TextDirection.ltr,
        );

        expect(find.text('הוספת תגובה'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'כל הכבוד, לילה טוב');
        await tester.pump();
        expect(typingDirection(tester), TextDirection.rtl);
        await tester.tap(find.byTooltip('שליחת התגובה'));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('כל הכבוד, לילה טוב'));
        expect(tester.widget<Text>(find.text('כל הכבוד, לילה טוב')).textDirection, TextDirection.rtl);
        expect(reads('Alex · ממש עכשיו'), findsOneWidget);
        await toTop(tester);
        expect(tester.widget<Text>(inCard('Maya', find.text('3'))).semanticsLabel, '3 תגובות');

        // Somebody else's post can be reported.
        await tester.tap(find.byTooltip('אפשרויות הפוסט').hitTestable().first);
        await tester.pumpAndSettle();
        expect(find.text('מחיקה'), findsNothing);
        await tester.tap(find.text('דיווח'));
        await tester.pumpAndSettle();
        expect(find.text('דיווח על הפוסט'), findsOneWidget);
        expect(find.text('מה לא בסדר בפוסט? נסתיר אותו אצלך מיד ונבדוק אותו.'), findsOneWidget);
        for (final reason in ['ספאם או פרסומת', 'פוגעני או לא מכבד', 'לא הולם או מטריד', 'משהו אחר']) {
          expect(find.text(reason), findsOneWidget, reason: reason);
        }
        await tester.tap(find.text('ספאם או פרסומת'));
        await tester.pumpAndSettle();
        expect(find.text('תודה. הסתרנו את הפוסט ונבדוק אותו.'), findsOneWidget);
        expect(find.text(mayaPost), findsNothing);
        expect(headerTitle('קהילה'), findsOneWidget);

        // One's own post can be deleted.
        await scrollTo(tester, reads('עם Kelly · לפני שעתיים'));
        await tapVisible(tester, inCard('Alex', find.byTooltip('אפשרויות הפוסט')));
        expect(find.text('דיווח'), findsNothing);
        await tester.tap(find.text('מחיקה'));
        await tester.pumpAndSettle();
        expect(find.text('למחוק את הפוסט?'), findsOneWidget);
        expect(
          find.text('התגובות והלייקים שלו יימחקו יחד איתו. אי אפשר לבטל את הפעולה הזאת.'),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextButton, 'ביטול'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'מחיקה'));
        await tester.pumpAndSettle();
        expect(find.text('הפוסט שלך נמחק.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the composer and its discard dialog', (tester) async {
        final h = await pumpCommunity(tester, harness: hebrew(), size: size);

        await tester.tap(find.text('פוסט חדש'));
        await tester.pumpAndSettle();
        expect(headerTitle('פוסט חדש'), findsOneWidget);
        expect(find.text('הפוסט גלוי לכל הקהילה'), findsOneWidget);
        expect(find.text('מה חדש אצל החיה שלך?'), findsOneWidget);
        expect(find.text('על מי הפוסט'), findsOneWidget);
        expect(find.text('תמונה'), findsOneWidget);
        final publish = find.widgetWithText(FilledButton, 'פרסום');
        expect(tester.widget<FilledButton>(publish).onPressed, isNull); // nothing to publish yet
        // An empty field follows the screen.
        expect(typingDirection(tester), TextDirection.rtl);

        // What is typed reads in its own direction, as it will in the feed.
        await tester.enterText(find.byType(TextField), 'Half a thought');
        await tester.pumpAndSettle();
        expect(typingDirection(tester), TextDirection.ltr);
        await tester.enterText(find.byType(TextField), hebrewPost);
        await tester.pumpAndSettle();
        expect(typingDirection(tester), TextDirection.rtl);

        await scrollTo(tester, find.text('גלריה'));
        await tapVisible(tester, find.text('מצלמה'));
        expect(find.byTooltip('הסרת התמונה'), findsOneWidget);

        // Leaving asks first.
        await tester.tap(find.byTooltip('חזרה'));
        await tester.pumpAndSettle();
        expect(find.text('לוותר על הפוסט?'), findsOneWidget);
        expect(find.text('מה שכתבת לא יישמר.'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'לוותר'), findsOneWidget);
        await tester.tap(find.text('להמשיך לכתוב'));
        await tester.pumpAndSettle();

        await tester.tap(publish);
        await tester.pumpAndSettle();
        expect(headerTitle('קהילה'), findsOneWidget);
        expect(tester.widget<Text>(find.text(hebrewPost)).textDirection, TextDirection.rtl);
        expect(reads('עם Kelly · ממש עכשיו'), findsOneWidget);
        expect((await storedPosts(tester, h)).first.text, hebrewPost);
        expect(tester.takeException(), isNull);
      });

      testWidgets('chat: the rooms, the three views and a conversation', (tester) async {
        final h = await pumpCommunity(tester, harness: hebrew(), size: size);
        await openSection(tester, 'צ׳אט');

        expect(reads('מותאם עבור Kelly. לחיצה על ״הכול״ מציגה את כל החדרים.'), findsOneWidget);
        for (final chip in ['כלבים', 'חתולים', 'הכול']) {
          expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
        }
        for (final room in ['כללי', 'גורים', 'טיפים לאילוף', 'כלבים מבוגרים', 'שאלות בריאות']) {
          await scrollTo(tester, find.text(room));
        }
        expect(find.text('Puppies'), findsNothing);
        expect(find.text('First weeks, teething and sleep'), findsNothing);
        await toTop(tester);
        expect(find.text('השבועות הראשונים, בקיעת שיניים ושינה'), findsOneWidget);

        await chooseScope(tester, 'cats');
        expect(find.text('מוצגים חדרים עבור חתולים.'), findsOneWidget);
        for (final room in ['גורי חתולים', 'חול וניקיון', 'התנהגות ומשחק של חתולים', 'חתולים מבוגרים']) {
          await scrollTo(tester, find.text(room));
        }
        await toTop(tester);

        await chooseScope(tester, 'everything');
        expect(find.text('מוצגים החדרים של כל החיות.'), findsOneWidget);
        expect(tag('כלבים'), findsWidgets);
        await scrollTo(tester, find.text('חתולים מבוגרים'));
        expect(tag('חתולים'), findsWidgets);
        await toTop(tester);

        // A conversation.
        await chooseScope(tester, 'dogs');
        await tapVisible(tester, find.text('גורים'));
        expect(headerTitle('גורים'), findsOneWidget);
        expect(adviceWordsIn(he), findsOneWidget);
        expect(reads('הודעה בחדר ״גורים״'), findsOneWidget);
        expect(find.text('היום'), findsOneWidget);
        expect(find.text('Priya'), findsOneWidget);

        const theirs = 'Until about six months for us. Frozen carrot sticks were a big help.';
        expect(tester.widget<Text>(find.text(theirs)).textDirection, TextDirection.ltr);

        await tester.enterText(find.byType(TextField), 'גם אצלנו זה לקח חצי שנה');
        await tester.pump();
        expect(typingDirection(tester), TextDirection.rtl);
        await tester.tap(find.byTooltip('שליחת ההודעה'));
        await tester.pumpAndSettle();
        expect(find.text('09:41'), findsOneWidget);
        expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

        // Mine at the end of the line: the left. Theirs at the start: the
        // right. Whatever language each message is written in.
        final screen = screenWidth(tester);
        expect(tester.getTopLeft(find.text('גם אצלנו זה לקח חצי שנה')).dx, lessThan(60));
        expect(tester.getTopRight(find.text(theirs)).dx, greaterThan(screen - 60));
        h.chat.receive(channelId: 'puppies', authorId: 'u-maya', authorName: 'Maya', text: 'ברוכים הבאים');
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.text('ברוכים הבאים')).textDirection, TextDirection.rtl);
        expect(tester.getTopRight(find.text('ברוכים הבאים')).dx, greaterThan(screen - 60));

        // The send button follows the field: on the left.
        expect(
          tester.getCenter(find.byTooltip('שליחת ההודעה')).dx,
          lessThan(tester.getCenter(find.byType(TextField)).dx),
        );

        // The way to a professional opens the pet's emergency and vet sheet.
        await tester.tap(adviceLine);
        await settleHealth(tester);
        expect(find.byType(BottomSheet), findsOneWidget);
        await closeSheet(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('guides: the list, a search with no match, and the reader to its end', (tester) async {
        await pumpCommunity(tester, harness: hebrew(pets: catFirst, guides: bilingualGuides), size: size);
        await openSection(tester, 'מדריכים');

        expect(reads('מותאם עבור Mitzi. לחיצה על ״הכול״ מציגה את כל המדריכים.'), findsOneWidget);
        expect(find.text('חיפוש מדריכים'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'הכול'), findsNWidgets(2)); // the view and the category
        for (final id in ['start', 'home', 'behaviour', 'health']) {
          expect(find.byKey(ValueKey('category-$id'), skipOffstage: false), findsOneWidget, reason: id);
        }
        expect(find.widgetWithText(ChoiceChip, 'צעדים ראשונים'), findsOneWidget);

        await tapVisible(tester, find.byKey(const ValueKey('category-home')));
        expect(find.widgetWithText(ChoiceChip, 'בית וניקיון'), findsOneWidget);
        // One of the three has Hebrew text; the other two say so.
        await scrollTo(tester, find.text('Setting up the litter box'));
        expect(screenDirection(tester, find.text('Setting up the litter box')), TextDirection.ltr);
        expect(tag('באנגלית בלבד'), findsWidgets);
        expect(reads('מאת Pet Companion team · עודכן בתאריך 30.09.26'), findsWidgets);
        expect(find.textContaining('min read'), findsNothing);
        expect(find.textContaining('Updated'), findsNothing);
        await scrollTo(tester, find.text(hebrewFixture.title));
        expect(screenDirection(tester, find.text(hebrewFixture.title)), TextDirection.rtl);
        await scrollTo(tester, reads('מאת מחבר לבדיקה · עודכן בתאריך 01.10.26'));
        expect(reads('דקת קריאה · בית וניקיון'), findsOneWidget);
        await toTop(tester);
        await tapVisible(tester, find.byKey(const ValueKey('category-all')));
        await toTop(tester);

        // A search that finds nothing for this animal.
        await tester.enterText(find.byType(TextField), 'xylitol');
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('חיפוש בכל המדריכים'));
        expect(find.text('לא נמצאו מדריכים מתאימים עבור חתולים'), findsOneWidget);
        expect(find.text('יש התאמה אחת במדריכים של כל החיות.'), findsOneWidget);
        await tester.tap(find.text('חיפוש בכל המדריכים'));
        await tester.pumpAndSettle();
        await toTop(tester);
        expect(find.text('מוצגים המדריכים של כל החיות.'), findsOneWidget);
        await scrollTo(tester, find.text('Foods your dog should never eat'));
        expect(tag('כלבים'), findsOneWidget);
        await toTop(tester);

        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('אפשר לנסות מילה אחרת או קטגוריה אחרת.'));
        expect(find.text('לא נמצאו מדריכים מתאימים'), findsOneWidget);
        await toTop(tester);
        await tester.tap(find.byTooltip('ניקוי החיפוש'));
        await tester.pumpAndSettle();
        await chooseScope(tester, 'cats');

        // The reader, for the guide that has Hebrew text.
        await tapVisible(tester, find.byKey(const ValueKey('category-home')));
        await tapVisible(tester, find.text(hebrewFixture.title));
        expect(headerTitle('מדריך'), findsOneWidget);
        expect(find.text('בית וניקיון'), findsOneWidget);
        expect(tag('באנגלית בלבד'), findsNothing);
        expect(reads('דקת קריאה · עבור חתולים'), findsOneWidget);

        final about = find.byKey(const Key('about-guide'));
        Finder inAbout(String text) => find.descendant(of: about, matching: find.text(text));
        await tester.scrollUntilVisible(inAbout('מקורות'), 200);
        for (final words in [
          'על המדריך הזה',
          'נכתב על ידי',
          'מחבר לבדיקה',
          'בדיקה מקצועית',
          'לא נבדק על ידי וטרינר',
          'עדכון אחרון',
          '01.10.26',
          'מקורות',
          'לא צוינו מקורות',
          'מידע כללי ומקובל על טיפול בחיות.',
        ]) {
          expect(inAbout(words), findsOneWidget, reason: words);
        }
        for (final english in ['About this guide', 'Written by', 'Not reviewed by a veterinarian', 'Sources']) {
          expect(find.text(english), findsNothing, reason: english);
        }
        // Nothing suggests a review.
        expect(find.byKey(const Key('guide-review')), findsNothing);
        expect(find.text('נבדק על ידי'), findsNothing);
        expect(tag('נבדק'), findsNothing);

        await tester.scrollUntilVisible(find.text('המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר.'), 300);
        final contact = find.text('פנייה לאיש מקצוע');
        await tester.scrollUntilVisible(contact, 200);
        await tapVisible(tester, contact);
        await settleHealth(tester);
        expect(find.byType(BottomSheet), findsOneWidget);
        await closeSheet(tester);
        await goBack(tester);

        // A guide with no Hebrew text: shown in English, left to right, and
        // tagged; the box around it still speaks Hebrew.
        await toTop(tester);
        await scrollTo(tester, find.text('Setting up the litter box'));
        await tapVisible(tester, find.text('Setting up the litter box'));
        expect(tag('באנגלית בלבד'), findsOneWidget);
        expect(inAbout('לא נבדק על ידי וטרינר'), findsOneWidget);
        expect(tester.widget<Text>(inAbout('Pet Companion team')).textDirection, TextDirection.ltr);
        final intro = find.textContaining('Most cats take to a litter box');
        await tester.scrollUntilVisible(intro, 200);
        expect(screenDirection(tester, intro), TextDirection.ltr);
        await tester.scrollUntilVisible(find.text('המדריך נותן מידע כללי ואינו תחליף לייעוץ של וטרינר.'), 300);
        expect(tester.takeException(), isNull);
      });

      testWidgets('guides: a recorded review and its sources (fixtures)', (tester) async {
        final h = await pumpCommunity(tester, harness: hebrew(pets: catFirst, guides: reviewedGuides), size: size);
        await openSection(tester, 'מדריכים');

        expect(tag('נבדק'), findsOneWidget);
        expect(tag('באנגלית בלבד'), findsWidgets);

        await tapVisible(tester, find.text('Fixture: reviewed guide'));
        final review = find.byKey(const Key('guide-review'));
        await tester.scrollUntilVisible(review, 200);
        expect(find.descendant(of: review, matching: find.text('נבדק על ידי')), findsOneWidget);
        expect(find.descendant(of: review, matching: reads('Test Reviewer (fixture)')), findsOneWidget);
        expect(find.descendant(of: review, matching: reads('Veterinarian · נבדק בתאריך 05.10.26')), findsOneWidget);
        expect(find.text('לא נבדק על ידי וטרינר'), findsNothing);

        final linked = reads('Fixture source with a link, Fixture Press');
        await tester.scrollUntilVisible(linked, 200);
        expect(find.text('לא צוינו מקורות'), findsNothing);
        await tapVisible(tester, linked);
        expect(h.openedSources, [Uri.parse('https://example.com/fixture')]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty and error states', (tester) async {
        final feed = FakeFeedRepository(latency: Duration.zero, now: testClock)..failing = true;
        final h = await pumpCommunity(tester, harness: hebrew(feed: feed), size: size);

        // The feed cannot load.
        expect(find.text('לא הצלחנו לטעון את הפיד'), findsOneWidget);
        expect(find.text('לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.'), findsOneWidget);
        expect(find.textContaining('Cannot'), findsNothing);
        feed.failing = false;
        await tapVisible(tester, find.text('לנסות שוב'));
        expect(find.text(mayaPost), findsOneWidget);

        // A like the backend refuses is put back, with the reason.
        feed.failing = true;
        await tester.tap(inCard('Maya', find.byTooltip('לייק')));
        await tester.pumpAndSettle();
        expect(inCard('Maya', find.text('14')), findsOneWidget);
        expect(find.text('לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.'), findsOneWidget);
        feed.failing = false;
        await snackGone(tester);

        // A post that is gone.
        await goTo(tester, CommunityRoutes.post('no-such-post'));
        expect(find.text('הפוסט כבר לא זמין'), findsOneWidget);
        expect(find.text('ייתכן שהוא נמחק.'), findsOneWidget);
        await tapVisible(tester, find.text('חזרה לפיד'));
        expect(headerTitle('קהילה'), findsOneWidget);

        // A guide that is gone.
        await goTo(tester, CommunityRoutes.guide('no-such-guide'));
        expect(find.text('המדריך לא נמצא'), findsOneWidget);
        expect(find.text('המדריך הזה כבר לא נמצא בספרייה.'), findsOneWidget);
        await tapVisible(tester, find.text('חזרה למדריכים'));

        // The rooms cannot load.
        h.chat.failing = true;
        await openSection(tester, 'צ׳אט');
        expect(find.text('לא הצלחנו לטעון את חדרי הצ׳אט'), findsOneWidget);
        expect(find.text('לא הצלחנו להתחבר לצ׳אט כרגע. אפשר לנסות שוב.'), findsOneWidget);
        h.chat.failing = false;
        await tapVisible(tester, find.text('לנסות שוב'));
        expect(find.text('כללי'), findsOneWidget);

        // A conversation cannot load; then a message cannot be sent.
        h.chat.failing = true;
        await tester.tap(find.text('כללי'));
        await tester.pumpAndSettle();
        expect(find.text('לא הצלחנו לטעון את השיחה'), findsOneWidget);
        expect(adviceWordsIn(he), findsOneWidget);
        h.chat.failing = false;
        await tapVisible(tester, find.text('לנסות שוב'));
        expect(find.text('Luna barks at it from behind the sofa. Very brave.'), findsOneWidget);

        h.chat.failing = true;
        await tester.enterText(find.byType(TextField), 'בוקר טוב');
        await tester.tap(find.byTooltip('שליחת ההודעה'));
        await tester.pumpAndSettle();
        expect(find.text('לא הצלחנו להתחבר לצ׳אט כרגע. אפשר לנסות שוב.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('nothing yet: no posts, no rooms, no messages, no comments', (tester) async {
        final feed = FakeFeedRepository(latency: Duration.zero, now: testClock, seeded: false);
        final chat = FakeChatRepository(latency: Duration.zero, now: testClock, seeded: false);
        await pumpCommunity(tester, harness: hebrew(feed: feed, chat: chat), size: size);

        expect(find.text('עדיין אין פוסטים'), findsOneWidget);
        expect(find.text('הפוסט הראשון יכול להיות שלך: תמונה או סיפור על החיה שלך.'), findsOneWidget);

        await openSection(tester, 'צ׳אט');
        expect(find.text('עדיין אין חדרי צ׳אט'), findsOneWidget);
        expect(find.text('חדרים יופיעו כאן ברגע שייפתחו.'), findsOneWidget);

        // The first post, written from the empty feed; it has no comments.
        await openSection(tester, 'פיד');
        await tapVisible(tester, find.text('כתיבת פוסט'));
        await tester.enterText(find.byType(TextField), hebrewPost);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'פרסום'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(hebrewPost));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('עדיין אין תגובות. התגובה הראשונה יכולה להיות שלך.'));
        expect(tester.widget<Text>(inCard('Alex', find.text('0')).first).semanticsLabel, 'אין לייקים');
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('a room with nobody in it, and the comments that cannot load', () {
    testWidgets('an empty conversation invites the first message', (tester) async {
      final h = CommunityHarness(appLanguage: AppLanguage.hebrew, chatBackend: _QuietRoom());
      await pumpCommunity(tester, harness: h);
      await openSection(tester, 'צ׳אט');
      await tester.tap(find.text('כללי'));
      await tester.pumpAndSettle();

      expect(find.text('עדיין אין הודעות'), findsOneWidget);
      expect(find.text('אפשר לכתוב שלום ולהתחיל את השיחה.'), findsOneWidget);
      expect(reads('הודעה בחדר ״כללי״'), findsOneWidget);
    });

    testWidgets('comments that cannot load say what failed, then why', (tester) async {
      final h = await pumpCommunity(tester, harness: hebrew());
      h.feed.failing = true;
      await tester.tap(find.text(mayaPost));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.text('לא הצלחנו לטעון את התגובות.'));
      expect(find.text('לא הצלחנו להתחבר לקהילה כרגע. אפשר לנסות שוב.'), findsOneWidget);
      h.feed.failing = false;
      await tapVisible(tester, find.widgetWithText(TextButton, 'לנסות שוב'));
      await scrollTo(tester, reads('Jonas · לפני 9 דקות'));
    });
  });

  group('direction', () {
    testWidgetsInBothLanguages('the tab opens on the feed, in the direction of its language', (
      tester,
      language,
    ) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: language));
      final words = language == AppLanguage.hebrew ? he : en;
      final rtl = language == AppLanguage.hebrew;

      expect(headerTitle(words.tabTitle), findsOneWidget);
      expect(find.text(words.newPost), findsOneWidget);
      expect(screenDirection(tester, find.byType(CommunityScreen)), rtl ? TextDirection.rtl : TextDirection.ltr);

      // A post card: the avatar leads, the menu closes the row.
      final name = tester.getCenter(inCard('Maya', find.text('Maya'))).dx;
      final avatar = tester.getCenter(inCard('Maya', find.text('M'))).dx;
      final menu = tester.getCenter(inCard('Maya', find.byTooltip(words.postOptions))).dx;
      expect(avatar > name, rtl);
      expect(menu < name, rtl);

      // The speech bubble of the comments is drawn for the side the line
      // starts at: flipped in Hebrew, as designed in English.
      final bubble = inCard('Maya', find.byType(MirroredIcon));
      expect(bubble, findsOneWidget);
      expect(find.descendant(of: bubble, matching: find.byType(Transform)), rtl ? findsOneWidget : findsNothing);
    });

    testWidgetsInBothLanguages('a Hebrew post and an English post each read in their own direction', (
      tester,
      language,
    ) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: language));
      final words = language == AppLanguage.hebrew ? he : en;

      await tester.tap(find.text(words.newPost));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), hebrewPost);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, words.postButton));
      await tester.pumpAndSettle();

      // The Hebrew post starts at the right of its box, on either screen.
      final hebrewText = find.text(hebrewPost);
      expect(tester.widget<Text>(hebrewText).textDirection, TextDirection.rtl);
      final first = firstLetter(tester, hebrewText);
      expect(first.right, closeTo(first.width, 1));

      // The English post starts at the left of its box, on either screen.
      await scrollTo(tester, find.text(mayaPost));
      final englishText = find.text(mayaPost);
      expect(tester.widget<Text>(englishText).textDirection, TextDirection.ltr);
      expect(firstLetter(tester, englishText).left, closeTo(0, 1));
    });

    testWidgetsInBothLanguages('chat bubbles: mine at the end of the line, theirs at the start', (
      tester,
      language,
    ) async {
      final h = await pumpCommunity(tester, harness: CommunityHarness(appLanguage: language));
      final words = language == AppLanguage.hebrew ? he : en;
      final rtl = language == AppLanguage.hebrew;
      final screen = screenWidth(tester);

      await openSection(tester, words.sectionChat);
      await tester.tap(find.text(words.roomGeneral));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello everyone');
      await tester.tap(find.byTooltip(words.sendMessage));
      await tester.pumpAndSettle();
      h.chat.receive(channelId: 'general', authorId: 'u-noa', authorName: 'Noa', text: 'שלום לכולם');
      await tester.pumpAndSettle();

      final mine = find.text('Hello everyone');
      final theirs = find.text('שלום לכולם');
      if (rtl) {
        expect(tester.getTopLeft(mine).dx, lessThan(60));
        expect(tester.getTopRight(theirs).dx, greaterThan(screen - 60));
      } else {
        expect(tester.getTopRight(mine).dx, greaterThan(screen - 60));
        expect(tester.getTopLeft(theirs).dx, lessThan(60));
      }
      // Each message still reads in its own direction.
      expect(tester.widget<Text>(mine).textDirection, TextDirection.ltr);
      expect(tester.widget<Text>(theirs).textDirection, TextDirection.rtl);

      // The send arrow points the way the line reads: Flutter mirrors it on
      // a right-to-left screen, and the button follows the field.
      expect(Icons.send_rounded.matchTextDirection, isTrue);
      final arrow = find.descendant(of: find.byType(MessageBar), matching: find.byIcon(Icons.send_rounded));
      expect(screenDirection(tester, arrow), rtl ? TextDirection.rtl : TextDirection.ltr);
      expect(tester.getCenter(arrow).dx < tester.getCenter(find.byType(TextField)).dx, rtl);
    });

    testWidgetsInBothLanguages('a room card: the icon leads, the chevron closes the row', (tester, language) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: language));
      final words = language == AppLanguage.hebrew ? he : en;
      final rtl = language == AppLanguage.hebrew;
      await openSection(tester, words.sectionChat);

      final room = find.byKey(const ValueKey('room-general'));
      final name = tester.getCenter(find.descendant(of: room, matching: find.text(words.roomGeneral))).dx;
      final icon = tester.getCenter(find.descendant(of: room, matching: find.byIcon(Icons.chat_bubble_rounded))).dx;
      final chevron = find.descendant(of: room, matching: find.byIcon(Icons.chevron_right_rounded));
      expect(icon > name, rtl);
      expect(tester.getCenter(chevron).dx < name, rtl);
      // The chevron mirrors by itself; the speech bubble is mirrored here.
      expect(Icons.chevron_right_rounded.matchTextDirection, isTrue);
      expect(screenDirection(tester, chevron), rtl ? TextDirection.rtl : TextDirection.ltr);
      expect(find.descendant(of: room, matching: find.byType(MirroredIcon)), findsOneWidget);
    });
  });

  group('switching the language', () {
    testWidgets('the guides follow the switch at once, both ways, in the list and in the reader', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst, guides: bilingualGuides));
      await openSection(tester, 'Guides');
      await tapVisible(tester, find.byKey(const ValueKey('category-home')));

      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(find.text(hebrewFixture.title), findsNothing);
      expect(tag('English only'), findsNothing);

      await switchLanguage(tester, AppLanguage.hebrew);
      expect(headerTitle('קהילה'), findsOneWidget);
      expect(screenDirection(tester, find.byType(CommunityScreen)), TextDirection.rtl);
      // The guide that has Hebrew text is now in Hebrew; the others say so.
      expect(find.text(hebrewFixture.title), findsOneWidget);
      expect(find.text('How many litter boxes do you need?'), findsNothing);
      expect(find.text('Setting up the litter box'), findsOneWidget);
      expect(tag('באנגלית בלבד'), findsNWidgets(2));
      expect(tag('English only'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'בית וניקיון'), findsOneWidget);

      // In the reader too.
      await tapVisible(tester, find.text(hebrewFixture.title));
      expect(headerTitle('מדריך'), findsOneWidget);
      expect(screenDirection(tester, find.text(hebrewFixture.intro)), TextDirection.rtl);

      await switchLanguage(tester, AppLanguage.english);
      expect(headerTitle('Guide'), findsOneWidget);
      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(find.text(hebrewFixture.title), findsNothing);
      expect(find.text('About this guide'), findsOneWidget);
      expect(screenDirection(tester, find.textContaining('The usual guideline is simple')), TextDirection.ltr);

      await goBack(tester);
      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(tag('English only'), findsNothing);
      expect(tag('באנגלית בלבד'), findsNothing);
    });

    testWidgets('the feed and the chat follow it too; what members wrote does not change', (tester) async {
      await pumpCommunity(tester);
      expect(find.text('with Biscuit · 12 min ago'), findsOneWidget);

      await switchLanguage(tester, AppLanguage.hebrew);
      expect(reads('עם Biscuit · לפני 12 דקות'), findsOneWidget);
      expect(find.text('with Biscuit · 12 min ago'), findsNothing);
      expect(find.text(mayaPost), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);

      await openSection(tester, 'צ׳אט');
      expect(find.text('גורים'), findsOneWidget);
      await tester.tap(find.text('גורים'));
      await tester.pumpAndSettle();
      expect(find.text('Until about six months for us. Frozen carrot sticks were a big help.'), findsOneWidget);

      await switchLanguage(tester, AppLanguage.english);
      expect(headerTitle('Puppies'), findsOneWidget);
      expect(find.text('Message Puppies'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });
  });

  test('the Hebrew words used above come from the strings files', () {
    expect(he.tabTitle, 'קהילה');
    expect(he.newPost, 'פוסט חדש');
    expect(he.contactProfessional, 'פנייה לאיש מקצוע');
    expect(he.tagEnglishOnly, 'באנגלית בלבד');
    expect(he.tagReviewed, 'נבדק');
    expect(appHe.commonBack, 'חזרה');
  });
}
