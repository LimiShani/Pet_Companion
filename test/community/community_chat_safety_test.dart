import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/chat/chat_message_tile.dart';
import 'package:pet_companion/features/community/chat/chat_providers.dart';
import 'package:pet_companion/features/community/data/photo_picker.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/widgets/post_photo_view.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/community/data/safety_repository.dart';

import 'community_helpers.dart';

/// Opens a room from the Chat section.
Future<void> openRoom(WidgetTester tester, String name) async {
  await openSection(tester, 'Chat');
  await scrollTo(tester, find.text(name));
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

/// Long-presses the bubble that reads [text].
Future<void> longPressMessage(WidgetTester tester, String text) async {
  await tester.longPress(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

/// A widget a screen reader names [label] (inside a card the name merges
/// into the card's, so the semantics tree would not show it alone).
Finder labelled(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label, description: 'labelled "$label"');

/// Tall enough to show the whole General room of the sample data.
const tall = Size(390, 1400);

const vacuum = 'Anyone else have a dog who hides when the vacuum comes out?';
const luna = 'Luna barks at it from behind the sofa. Very brave.';
const lunaPhoto = 'Here she is, guarding the living room.';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('room list', () {
    testWidgets('shows the latest message and an unread badge that opening the room clears', (tester) async {
      final h = await pumpCommunity(tester);
      await openSection(tester, 'Chat');

      // General: five messages from others in the last three days.
      expect(find.text('Jonas: $lunaPhoto'), findsOneWidget);
      expect(labelled('5 unread messages'), findsOneWidget);
      // The liveliest room comes first.
      expect(
        tester.getTopLeft(find.text('General')).dy,
        lessThan(tester.getTopLeft(find.text('Puppies')).dy),
      );

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(h.chat.lastRead(demoUser.id, 'general'), testNow);
      await goBack(tester);

      expect(labelled('5 unread messages'), findsNothing);
      expect(find.text('Jonas: $lunaPhoto'), findsOneWidget);
    });

    testWidgets('my own latest message reads "You:"', (tester) async {
      await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');
      await send(tester, 'Thanks, Priya!');
      await goBack(tester);
      expect(find.text('You: Thanks, Priya!'), findsOneWidget);
    });
  });

  group('conversation', () {
    testWidgets('groups a person\'s messages and quotes the message a reply answers', (tester) async {
      await pumpCommunity(tester, size: tall);
      await openRoom(tester, 'General');

      // Jonas wrote twice in a row: his name shows once, the time once.
      expect(find.text('Jonas'), findsOneWidget);
      expect(find.text('09:20'), findsNothing); // 21 min ago, not the run's end
      expect(find.text('09:21'), findsOneWidget); // 20 min ago, the run's end
      // His first message answers Noa's: her words are quoted in it.
      final lunaTile = find.ancestor(of: find.text(luna), matching: find.byType(ChatMessageTile));
      expect(find.descendant(of: lunaTile, matching: find.text(vacuum)), findsOneWidget);
      expect(find.descendant(of: lunaTile, matching: find.text('Noa')), findsOneWidget);
      // The photo message carries a picture that opens full screen.
      expect(find.byType(PostPhotoView), findsOneWidget);
      await tester.tap(labelled('Open the photo'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('answering a message', (tester) async {
      final h = await pumpCommunity(tester, size: tall);
      await openRoom(tester, 'General');

      await longPressMessage(tester, luna);
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(find.text('Replying to Jonas'), findsOneWidget);

      await send(tester, 'Brave indeed!');
      expect(find.text('Replying to Jonas'), findsNothing);
      expect(find.text('Brave indeed!'), findsOneWidget);
      // Luna's line now shows twice: in its bubble and quoted in mine.
      final mineTile = find.ancestor(of: find.text('Brave indeed!'), matching: find.byType(ChatMessageTile));
      expect(find.descendant(of: mineTile, matching: find.text(luna)), findsOneWidget);
      final mine = h.chat.idOf('general', 'Brave indeed!');
      expect(mine, isNotEmpty);
    });

    testWidgets('reactions: add from the menu, see the count, tap to take back', (tester) async {
      final h = await pumpCommunity(tester, size: tall);
      await openRoom(tester, 'General');

      // Sample data: two members laughed at Sam's message.
      expect(find.text('😂 2'), findsOneWidget);

      await longPressMessage(tester, luna);
      await tester.tap(find.byTooltip('React with 🐾'));
      await tester.pumpAndSettle();
      expect(find.text('🐾 1'), findsOneWidget);

      h.chat.reactAs('u-maya', h.chat.idOf('general', luna), '🐾');
      await tester.pumpAndSettle();
      expect(find.text('🐾 2'), findsOneWidget);

      await tester.tap(find.text('🐾 2'));
      await tester.pumpAndSettle();
      expect(find.text('🐾 1'), findsOneWidget);
    });

    testWidgets('copying, and deleting my own message', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');
      await send(tester, 'Oops, wrong room');

      await longPressMessage(tester, 'Oops, wrong room');
      // Mine: no report, no block.
      expect(find.text('Report'), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(copied, 'Oops, wrong room');
      expect(find.text('Message copied'), findsOneWidget);

      await longPressMessage(tester, 'Oops, wrong room');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this message?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Oops, wrong room'), findsNothing);
      expect(find.text('Message deleted'), findsOneWidget);
    });

    testWidgets('a message that fails shows at once, says why, and can be sent again', (tester) async {
      final h = await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');

      h.chat.sendFailing = true;
      await send(tester, 'Is anyone here?');
      expect(find.text('Is anyone here?'), findsOneWidget);
      expect(find.text('Not sent. Tap to try again.'), findsOneWidget);
      expect(find.text('Cannot reach the chat right now. Please try again.'), findsOneWidget);

      h.chat.sendFailing = false;
      await tester.tap(find.text('Not sent. Tap to try again.'));
      await tester.pumpAndSettle();
      expect(find.text('This message was not sent'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Not sent. Tap to try again.'), findsNothing);
      expect(find.text('Is anyone here?'), findsOneWidget);
      expect(h.chat.idOf('puppies', 'Is anyone here?'), isNotEmpty);
    });

    testWidgets('a failed message can also be let go', (tester) async {
      final h = await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');
      h.chat.sendFailing = true;
      await send(tester, 'Never mind');

      await tester.tap(find.text('Not sent. Tap to try again.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Never mind'), findsNothing);
    });

    testWidgets('a photo message', (tester) async {
      final h = await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');

      await tester.tap(find.byTooltip('Add a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gallery'));
      await tester.pumpAndSettle();
      expect(labelled('The photo to send'), findsOneWidget);

      // A photo alone is enough to send.
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(labelled('The photo to send'), findsNothing);
      expect(find.byType(PostPhotoView), findsOneWidget);
      expect(h.picker.requests, [PhotoSource.gallery]);
    });

    testWidgets('scrolling up loads older messages down to the start', (tester) async {
      final chat = FakeChatRepository(latency: Duration.zero, now: testClock);
      final start = testNow.subtract(const Duration(hours: 30));
      for (var i = 1; i <= 230; i++) {
        chat.receive(
          channelId: 'seniors',
          authorId: i.isEven ? 'u-noa' : 'u-sam',
          authorName: i.isEven ? 'Noa' : 'Sam',
          text: 'Old message $i',
          sentAt: start.add(Duration(minutes: i)),
        );
      }
      await pumpCommunity(tester, harness: CommunityHarness(chat: chat));
      await openRoom(tester, 'Senior dogs');

      final list = find.byType(Scrollable).hitTestable().first;
      await tester.scrollUntilVisible(find.text('Old message 1'), 600, scrollable: list, maxScrolls: 200);
      await tester.scrollUntilVisible(find.text('This is the start of the conversation'), 300, scrollable: list);
      expect(find.text('This is the start of the conversation'), findsOneWidget);

      // Back to the latest, with the button.
      await tester.tap(find.byTooltip('Go to the latest message'));
      await tester.pumpAndSettle();
      expect(find.text('Old message 230'), findsOneWidget);
    });

    testWidgets('while reading older messages, the button counts what arrives', (tester) async {
      final chat = FakeChatRepository(latency: Duration.zero, now: testClock);
      for (var i = 1; i <= 40; i++) {
        chat.receive(channelId: 'training', authorId: 'u-sam', authorName: 'Sam', text: 'Tip number $i');
      }
      await pumpCommunity(tester, harness: CommunityHarness(chat: chat));
      await openRoom(tester, 'Training tips');

      await tester.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Go to the latest message'), findsOneWidget);

      chat.receive(channelId: 'training', authorId: 'u-noa', authorName: 'Noa', text: 'New one');
      chat.receive(channelId: 'training', authorId: 'u-noa', authorName: 'Noa', text: 'And another');
      await tester.pumpAndSettle();
      expect(find.text('2 new messages'), findsOneWidget);

      await tester.tap(find.text('2 new messages'));
      await tester.pumpAndSettle();
      expect(find.text('And another'), findsOneWidget);
      expect(find.byTooltip('Go to the latest message'), findsNothing);
    });

    testWidgets('the advice note can be put away in most rooms, not in Health questions', (tester) async {
      await pumpCommunity(tester);
      await openRoom(tester, 'Puppies');
      expect(find.byTooltip('Hide this note'), findsOneWidget);
      await tester.tap(find.byTooltip('Hide this note'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide this note'), findsNothing);

      // Still there in the room's info.
      await tester.tap(find.byTooltip('About this room'));
      await tester.pumpAndSettle();
      expect(find.text('First weeks, teething and sleep'), findsOneWidget);
      expect(find.text('Community rules'), findsOneWidget);
      await closeSheet(tester);
      await goBack(tester);

      await openRoom(tester, 'Health questions');
      expect(find.byTooltip('Hide this note'), findsNothing);
    });
  });

  group('safety', () {
    testWidgets('the rules come before the first message, once', (tester) async {
      final h = await pumpCommunity(tester, harness: CommunityHarness(rulesAccepted: false));
      await openRoom(tester, 'Puppies');

      await send(tester, 'Hello!');
      expect(find.text('Community rules'), findsOneWidget);
      expect(find.text('No selling animals, no ads and no spam.'), findsOneWidget);
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Hello!'), findsOneWidget);
      expect(h.settings.values['community.rules.demo'], '1');

      await send(tester, 'Second one');
      expect(find.text('Agree and continue'), findsNothing);
      expect(find.text('Second one'), findsOneWidget);
    });

    testWidgets('closing the rules sends nothing', (tester) async {
      final h = await pumpCommunity(tester, harness: CommunityHarness(rulesAccepted: false));
      await openRoom(tester, 'Puppies');
      await send(tester, 'Not yet');
      await closeSheet(tester);
      expect(find.text('Not yet'), findsOneWidget); // still in the field
      expect(() => h.chat.idOf('puppies', 'Not yet'), throwsStateError);
    });

    testWidgets('reporting a message hides it for me and records the reason', (tester) async {
      final h = await pumpCommunity(tester, size: tall);
      await openRoom(tester, 'General');

      // Noa's own message; Jonas's answer above it quotes the same words.
      await tester.longPress(find.text(vacuum).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report this message'), findsOneWidget);
      await tester.tap(find.text('Spam or advertising'));
      await tester.pumpAndSettle();

      expect(find.text('Thanks. We have hidden this message and will review it.'), findsOneWidget);
      // Gone, and Jonas's answer no longer quotes it.
      expect(find.text(vacuum), findsNothing);
      expect(find.text('The original message is not available'), findsOneWidget);
      expect(h.chat.reports.single.reason, ReportReason.spam);
    });

    testWidgets('blocking someone hides them everywhere; unblocking brings them back', (tester) async {
      final h = await pumpCommunity(tester, size: tall);
      await openRoom(tester, 'General');

      await longPressMessage(tester, luna);
      await tester.tap(find.text('Block Jonas'));
      await tester.pumpAndSettle();
      expect(find.text('Block Jonas?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(find.text('You blocked Jonas'), findsOneWidget);
      expect(find.text(luna), findsNothing);
      expect(find.text(lunaPhoto), findsNothing);
      expect((await tester.runAsync(() => h.safety.fetchBlocked(viewer: demoUser)))!.single.name, 'Jonas');

      // Community safety lists him, with a way back.
      await goBack(tester);
      await tester.tap(find.byTooltip('Community safety'));
      await tester.pumpAndSettle();
      expect(find.text('Blocked members'), findsOneWidget);
      expect(find.text('Jonas'), findsOneWidget);
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(find.text('Jonas is unblocked'), findsOneWidget);
      expect(find.text('You have not blocked anyone.'), findsOneWidget);

      await goBack(tester);
      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(find.text(lunaPhoto), findsOneWidget);
    });

    testWidgets('blocking from a post hides the author\'s posts in the feed', (tester) async {
      final h = await pumpCommunity(tester);
      final first = (await storedPosts(tester, h)).firstWhere((p) => p.authorId != demoUser.id);
      await scrollTo(tester, find.text(first.text));

      final options = find.descendant(
        of: find.widgetWithText(PostCard, first.text),
        matching: find.byTooltip('Post options'),
      );
      await tester.ensureVisible(options);
      await tester.pumpAndSettle();
      await tester.tap(options);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block ${first.authorName}'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(find.text(first.text), findsNothing);
    });

    testWidgets('a comment can be reported, and its author blocked', (tester) async {
      final h = await pumpCommunity(tester);
      final posts = await storedPosts(tester, h);
      final withComments = posts.firstWhere((p) => p.commentCount > 0);
      final comments = (await tester.runAsync(() => h.feed.fetchComments(postId: withComments.id)))!;
      final other = comments.firstWhere((c) => c.authorId != demoUser.id);

      await scrollTo(tester, find.text(withComments.text));
      await tester.tap(find.text(withComments.text));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(other.text));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Comment options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('Report this comment'), findsOneWidget);
      await tester.tap(find.text('Unkind or abusive'));
      await tester.pumpAndSettle();

      expect(find.text('Thanks. We have hidden this comment and will review it.'), findsOneWidget);
      expect(find.text(other.text), findsNothing);
      expect(h.safety.commentReports.single.commentId, other.id);
    });

    testWidgets('the community safety page holds the rules', (tester) async {
      await pumpCommunity(tester);
      await tester.tap(find.byTooltip('Community safety'));
      await tester.pumpAndSettle();
      expect(find.text('Blocking and reporting are private: nobody is told who did it.'), findsOneWidget);
      // Members are not moderators.
      expect(find.text('Review reports'), findsNothing);

      await tester.tap(find.text('Community rules'));
      await tester.pumpAndSettle();
      expect(find.text('Be kind. Disagree with ideas, not with people.'), findsOneWidget);
      expect(find.text('Agree and continue'), findsNothing);
    });
  });

  group('moderation', () {
    testWidgets('a moderator keeps or removes what was reported', (tester) async {
      final safety = FakeCommunitySafetyRepository(latency: Duration.zero, now: testClock);
      final h = await pumpCommunity(tester, harness: CommunityHarness(safety: safety, moderator: true));

      await tester.tap(find.byTooltip('Community safety'));
      await tester.pumpAndSettle();
      expect(find.text('2 waiting'), findsOneWidget);
      await tester.tap(find.text('Review reports'));
      await tester.pumpAndSettle();

      expect(find.text('Cheap puppies for sale, message me now!!!'), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
      expect(find.text('3 reports · Spam or advertising'), findsOneWidget);
      expect(find.textContaining('In General'), findsOneWidget);

      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      expect(find.text('Remove it for everyone?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove').last);
      await tester.pumpAndSettle();
      expect(find.text('Cheap puppies for sale, message me now!!!'), findsNothing);

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.text('All clear'), findsOneWidget);
      expect(h.safety.decisions, [('mod-1', ModerationDecision.remove), ('mod-2', ModerationDecision.keep)]);
    });
  });

  testWidgets('in Hebrew on a small phone: a room, its menu, safety and review fit', (tester) async {
    await pumpCommunity(
      tester,
      harness: CommunityHarness(appLanguage: AppLanguage.hebrew, moderator: true),
      size: const Size(320, 568),
    );
    await openSection(tester, he.sectionChat);
    await scrollTo(tester, find.text(he.roomPuppies));
    await tester.tap(find.text(he.roomPuppies));
    await tester.pumpAndSettle();
    expect(find.byTooltip(he.hideNotice), findsOneWidget);

    await tester.longPress(find.text('Until about six months for us. Frozen carrot sticks were a big help.'));
    await tester.pumpAndSettle();
    expect(find.text(he.chatReply), findsOneWidget);
    expect(reads(he.blockMember('Priya')), findsOneWidget);
    await tester.tap(find.text(he.chatReply));
    await tester.pumpAndSettle();
    expect(reads(he.replyingTo('Priya')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await goBack(tester);
    await tester.tap(find.byTooltip(he.safetyTitle));
    await tester.pumpAndSettle();
    expect(find.text(he.reviewWaiting(2)), findsOneWidget);
    await tester.tap(find.text(he.reviewReports));
    await tester.pumpAndSettle();
    expect(find.text(he.keepItem), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a run of messages: start and end', (tester) async {
    ChatEntry entry(String author, int minute) => ChatEntry(
      ChatMessage(
        id: '$author$minute',
        channelId: 'c',
        authorId: author,
        authorName: author,
        text: 'x',
        sentAt: testNow.add(Duration(minutes: minute)),
      ),
    );
    final entries = [entry('a', 0), entry('a', 2), entry('a', 20), entry('b', 21)];
    final runs = [for (var i = 0; i < entries.length; i++) ChatRunPosition.of(entries, i)];
    expect([for (final r in runs) (r.first, r.last)], [(true, false), (false, true), (true, true), (true, true)]);
  });
}
