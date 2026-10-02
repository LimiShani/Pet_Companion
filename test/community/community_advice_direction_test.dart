import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/widgets/advice_notice.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/app_icon.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'community_helpers.dart';
import 'guide_fixtures.dart';

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

final adviceLine = find.byType(AdviceNotice);

/// The words of the advice line, which are one rich text.
final adviceWords = find.descendant(
  of: adviceLine,
  matching: find.textContaining('$adviceNoticeText $contactProfessionalLabel', findRichText: true),
);

const mayaPost = 'First full night without a toilet trip! Four months old and we both finally slept. '
    'Taking him out right before bed made all the difference.';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('advice is not a diagnosis', () {
    testWidgets('every chat room carries the line, and it opens the pet\'s emergency and vet sheet', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Chat');

      await tester.tap(find.text('Puppies'));
      await tester.pumpAndSettle();
      expect(adviceWords, findsOneWidget);
      // Pinned under the header, above the conversation.
      final header = tester.getRect(find.byType(CoralHeader).hitTestable());
      final line = tester.getRect(adviceLine);
      final firstMessage = tester.getRect(find.text('Today'));
      expect(line.top, greaterThanOrEqualTo(header.bottom));
      expect(line.bottom, lessThanOrEqualTo(firstMessage.top));
      expect(line.height, greaterThanOrEqualTo(44)); // the whole line is the tap target

      await tester.tap(adviceLine);
      await settleHealth(tester);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      await closeSheet(tester);
      expect(find.text('Emergency · Kelly'), findsNothing);
      expect(adviceWords, findsOneWidget); // nothing to dismiss: it stays

      // And in another room.
      await goBack(tester);
      await tester.tap(find.text('Health questions'));
      await tester.pumpAndSettle();
      expect(headerTitle('Health questions'), findsOneWidget);
      expect(adviceWords, findsOneWidget);
    });

    testWidgets('a room that cannot load carries it too', (tester) async {
      final h = await pumpCommunity(tester);
      await openSection(tester, 'Chat');

      h.chat.failing = true;
      await tester.tap(find.text('Senior dogs'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot load this conversation'), findsOneWidget);
      expect(adviceWords, findsOneWidget);
    });

    testWidgets('a post\'s comments carry the line, above the first comment', (tester) async {
      await pumpCommunity(tester);

      await tester.tap(find.text(mayaPost));
      await tester.pumpAndSettle();
      expect(headerTitle('Post'), findsOneWidget);
      expect(adviceWords, findsOneWidget);

      final heading = tester.getRect(find.text('Comments'));
      final line = tester.getRect(adviceLine);
      final firstComment = tester.getRect(find.text('Well done Biscuit! The early weeks are the hardest part.'));
      expect(line.top, greaterThanOrEqualTo(heading.bottom));
      expect(line.bottom, lessThanOrEqualTo(firstComment.top));

      await tester.tap(adviceLine);
      await settleHealth(tester);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
    });

    testWidgets('the sheet is the selected pet\'s', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Chat');
      await tester.tap(find.text('Kittens'));
      await tester.pumpAndSettle();

      await tester.tap(adviceLine);
      await settleHealth(tester);
      expect(find.text('Emergency · Mitzi'), findsOneWidget);
      expect(find.text('Emergency · Kelly'), findsNothing);
    });

    testWidgets('the feed itself has no such line', (tester) async {
      await pumpCommunity(tester);
      expect(adviceLine, findsNothing);
    });
  });

  group('member text in its own direction', () {
    test('the direction of a text goes by its first letter', () {
      for (final screen in TextDirection.values) {
        expect(directionOfText('Hello everyone', fallback: screen), TextDirection.ltr);
        expect(directionOfText('שלום לכולם', fallback: screen), TextDirection.rtl);
        expect(directionOfText('3 חתולים', fallback: screen), TextDirection.rtl);
        // No letters at all: it follows the screen.
        expect(directionOfText('12:30 ...', fallback: screen), screen);
      }
    });

    testWidgets('a Hebrew message reads right to left in an English app', (tester) async {
      final h = await pumpCommunity(tester);
      await openSection(tester, 'Chat');
      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();

      h.chat.receive(channelId: 'general', authorId: 'u-noa', authorName: 'Noa', text: 'שלום לכולם');
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.text('שלום לכולם')).textDirection, TextDirection.rtl);
      expect(
        tester.widget<Text>(find.text('Luna barks at it from behind the sofa. Very brave.')).textDirection,
        TextDirection.ltr,
      );
      // Still someone else's message: at the start of the line (the left).
      expect(tester.getTopLeft(find.text('שלום לכולם')).dx, lessThan(60));
    });
  });

  // Every Community screen on a small phone, in both directions. The test
  // font is wide, so anything that would overflow fails here.
  for (final direction in TextDirection.values) {
    group('small phone, ${direction.name}', () {
      Future<CommunityHarness> pump(WidgetTester tester, {CommunityHarness? harness}) =>
          pumpCommunityHost(tester, harness: harness, direction: direction, size: const Size(320, 640));

      testWidgets('feed, a post with its comments, and the composer', (tester) async {
        await pump(tester);
        expect(find.text(mayaPost), findsOneWidget);
        await scrollTo(tester, find.text('with Milo · 6 days ago'));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        await tester.pumpAndSettle();

        await tester.tap(find.text(mayaPost));
        await tester.pumpAndSettle();
        expect(headerTitle('Post'), findsOneWidget);
        expect(adviceLine, findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Sleep well, Biscuit!');
        await tester.tap(find.byTooltip('Send comment'));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('Sleep well, Biscuit!'));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Post options').hitTestable().first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report'));
        await tester.pumpAndSettle();
        expect(find.text('Report this post'), findsOneWidget);
        await closeSheet(tester);
        await goBack(tester);

        await tester.tap(find.text('New post'));
        await tester.pumpAndSettle();
        expect(headerTitle('New post'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'A post from a small phone.');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Camera'));
        expect(find.byTooltip('Remove photo'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Post'));
        await tester.pumpAndSettle();
        expect(find.text('A post from a small phone.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('chat: the three views, a room and the emergency sheet', (tester) async {
        await pump(tester, harness: CommunityHarness(pets: catFirst));
        await openSection(tester, 'Chat');
        expect(find.text('Kittens'), findsOneWidget);
        await chooseScope(tester, 'dogs');
        expect(find.text('Puppies'), findsOneWidget);
        await chooseScope(tester, 'everything');
        await scrollTo(tester, find.text('Health questions'));
        await scrollTo(tester, find.text('Litter and cleaning'));

        await tester.tap(find.text('Litter and cleaning'));
        await tester.pumpAndSettle();
        expect(headerTitle('Litter and cleaning'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'We scoop morning and evening now.');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(find.text('We scoop morning and evening now.'), findsOneWidget);

        await tester.tap(adviceLine);
        await settleHealth(tester);
        expect(find.text('Emergency · Mitzi'), findsOneWidget);
        await closeSheet(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('guides: the list, a search with no match, and the reader to its end', (tester) async {
        await pump(tester, harness: CommunityHarness(pets: catFirst));
        await openSection(tester, 'Guides');
        expect(find.text("Your cat's first week at home"), findsOneWidget);
        await chooseScope(tester, 'everything');
        await scrollTo(tester, find.text('Keeping an older dog comfortable'));
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 8000));
        await tester.pumpAndSettle();

        await chooseScope(tester, 'cats');
        await tester.enterText(find.byType(TextField), 'xylitol');
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('Search everything'));
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        await scrollTo(tester, find.text('Knowing when to call the vet about your cat'));
        await tester.tap(find.text('Knowing when to call the vet about your cat'));
        await tester.pumpAndSettle();
        expect(find.text('About this guide'), findsOneWidget);
        expect(find.text('Not reviewed by a veterinarian'), findsOneWidget);
        await tester.scrollUntilVisible(find.text(guideDisclaimer), 300);
        await tester.scrollUntilVisible(find.text(contactProfessionalLabel), 200);
        expect(tester.takeException(), isNull);
      });

      testWidgets('guides: a reviewed guide with sources, and a Hebrew one (fixtures)', (tester) async {
        await pump(tester, harness: CommunityHarness(pets: catFirst, guides: reviewedGuides));
        await openSection(tester, 'Guides');
        await tapVisible(tester, find.text('Fixture: reviewed guide'));
        expect(find.byKey(const Key('guide-review')), findsOneWidget);
        await tester.scrollUntilVisible(find.text(guideDisclaimer), 300);
        expect(tester.takeException(), isNull);
      });

      testWidgets('guides in Hebrew: translated and "English only" side by side (fixture)', (tester) async {
        await pump(
          tester,
          harness: CommunityHarness(pets: catFirst, guides: bilingualGuides, language: ContentLanguage.he),
        );
        await openSection(tester, 'Guides');
        await scrollTo(tester, find.text(hebrewFixture.title));
        await tester.tap(find.text(hebrewFixture.title));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text(guideDisclaimer), 300);
        expect(tester.takeException(), isNull);
      });
    });
  }

  group('right to left', () {
    testWidgets('own messages sit on the left, other people\'s on the right', (tester) async {
      await pumpCommunityHost(tester, direction: TextDirection.rtl);
      await openSection(tester, 'Chat');
      await tester.tap(find.text('Puppies'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello puppies');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      const others = 'Until about six months for us. Frozen carrot sticks were a big help.';
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      // Mine at the end of the line: the left. Theirs at the start: the right.
      expect(tester.getTopLeft(find.text('Hello puppies')).dx, lessThan(60));
      expect(tester.getTopRight(find.text(others)).dx, greaterThan(width - 60));
      // The send button moves to the left of the field.
      expect(
        tester.getCenter(find.byTooltip('Send message')).dx,
        lessThan(tester.getCenter(find.byType(TextField)).dx),
      );
    });

    testWidgets('a post card mirrors: avatar on the right, menu on the left', (tester) async {
      await pumpCommunityHost(tester, direction: TextDirection.rtl);

      final card = find.widgetWithText(PostCard, 'Maya');
      final name = tester.getCenter(find.descendant(of: card, matching: find.text('Maya')));
      final initial = tester.getCenter(find.descendant(of: card, matching: find.text('M')));
      final menu = tester.getCenter(find.descendant(of: card, matching: find.byTooltip('Post options')));
      expect(initial.dx, greaterThan(name.dx));
      expect(menu.dx, lessThan(name.dx));
    });

    testWidgets('a room card and a guide card mirror: icon on the right', (tester) async {
      await pumpCommunityHost(tester, direction: TextDirection.rtl);
      await openSection(tester, 'Chat');
      final room = find.byKey(const ValueKey('room-general'));
      expect(
        tester.getCenter(find.descendant(of: room, matching: find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.chat_bubble_rounded))).dx,
        greaterThan(tester.getCenter(find.descendant(of: room, matching: find.text('General'))).dx),
      );
      expect(
        tester.getCenter(find.descendant(of: room, matching: find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.chevron_right_rounded))).dx,
        lessThan(tester.getCenter(find.descendant(of: room, matching: find.text('General'))).dx),
      );

      await openSection(tester, 'Guides');
      final guide = find.byKey(const ValueKey('guide-first-week'));
      expect(
        tester.getCenter(find.descendant(of: guide, matching: find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.pets_rounded))).dx,
        greaterThan(tester.getCenter(find.descendant(of: guide, matching: find.textContaining('min read'))).dx),
      );
    });
  });
}
