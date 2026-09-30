import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/fake_chat_repository.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/data/guides_repository.dart';
import 'package:pet_companion/features/community/data/photo_picker.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/widgets/post_photo_view.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'community_helpers.dart';

const mayaPost = 'First full night without a toilet trip! Four months old and we both finally slept. '
    'Taking him out right before bed made all the difference.';
const alexPost = 'Kelly is thirteen and still insists on carrying the biggest stick in the park. '
    'Slower walks these days, same big ambitions.';

/// The card of the post whose author line reads [author].
Finder cardOf(String author) => find.widgetWithText(PostCard, author);

Finder inCard(String author, Finder matching) => find.descendant(of: cardOf(author), matching: matching);

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

void main() {
  setUpAll(() {
    // No network in tests: fall back to the platform font quietly.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('tab shell', () {
    testWidgets('the three sections switch and keep their state', (tester) async {
      await pumpCommunity(tester);

      expect(headerTitle('Community'), findsOneWidget);
      expect(find.text(mayaPost), findsOneWidget);
      expect(find.text('New post'), findsOneWidget);

      await openSection(tester, 'Chat');
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Health questions'), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);
      expect(find.text('New post'), findsNothing);

      await openSection(tester, 'Guides');
      expect(find.text("Your puppy's first week at home"), findsOneWidget);
      expect(find.text('General'), findsNothing);

      // Type a search, leave the section and come back: it is still there.
      await tester.enterText(find.byType(TextField), 'xylitol');
      await tester.pumpAndSettle();
      await openSection(tester, 'Feed');
      expect(find.text(mayaPost), findsOneWidget);
      await openSection(tester, 'Guides');
      expect(find.text('xylitol'), findsOneWidget);
      expect(find.text('Foods your dog should never eat'), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsNothing);
    });
  });

  group('feed', () {
    testWidgets('renders post cards with author, pet, time, photo and counts', (tester) async {
      await pumpCommunity(tester);

      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('with Biscuit · 12 min ago'), findsOneWidget);
      expect(find.text(mayaPost), findsOneWidget);
      expect(inCard('Maya', find.text('M')), findsOneWidget); // avatar initial
      expect(inCard('Maya', find.text('14')), findsOneWidget); // likes
      expect(inCard('Maya', find.text('2')), findsOneWidget); // comments

      await tester.scrollUntilVisible(find.text('with Kelly · 2 h ago'), 200);
      expect(find.text(alexPost), findsOneWidget);
      expect(inCard('Alex', find.byType(PostPhotoView)), findsOneWidget);

      await tester.scrollUntilVisible(find.text('22 h ago'), 200); // no pet tagged
      await tester.scrollUntilVisible(find.text('with Milo · 6 days ago'), 200);
    });

    testWidgets('like and unlike', (tester) async {
      final h = await pumpCommunity(tester);

      await tester.tap(inCard('Maya', find.byTooltip('Like')));
      await tester.pumpAndSettle();
      expect(inCard('Maya', find.text('15')), findsOneWidget);
      expect(inCard('Maya', find.byIcon(Icons.favorite_rounded)), findsOneWidget);

      await tester.tap(inCard('Maya', find.byTooltip('Unlike')));
      await tester.pumpAndSettle();
      expect(inCard('Maya', find.text('14')), findsOneWidget);
      expect(inCard('Maya', find.byIcon(Icons.favorite_border_rounded)), findsOneWidget);

      // A like the backend refuses is put back, with a message.
      h.feed.failing = true;
      await tester.tap(inCard('Maya', find.byTooltip('Like')));
      await tester.pumpAndSettle();
      expect(inCard('Maya', find.text('14')), findsOneWidget);
      expect(find.text('Cannot reach the community right now. Please try again.'), findsOneWidget);
    });

    testWidgets('open a post and add a comment', (tester) async {
      await pumpCommunity(tester);

      await tester.tap(find.text(mayaPost));
      await tester.pumpAndSettle();

      expect(headerTitle('Post'), findsOneWidget);
      expect(find.text(mayaPost), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Well done Biscuit! The early weeks are the hardest part.'), findsOneWidget);
      expect(find.textContaining('Jonas · '), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sleep well, Biscuit!');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();

      expect(find.text('Sleep well, Biscuit!'), findsOneWidget);
      expect(find.text('Alex · just now'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(inCard('Maya', find.text('3')), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(headerTitle('Community'), findsOneWidget);
      expect(inCard('Maya', find.text('3')), findsOneWidget);
    });

    testWidgets('compose a post with a photo from the picker', (tester) async {
      final h = await pumpCommunity(tester);

      await tester.tap(find.text('New post'));
      await tester.pumpAndSettle();
      expect(headerTitle('New post'), findsOneWidget);

      // Nothing to post yet.
      final postButton = find.widgetWithText(FilledButton, 'Post');
      expect(tester.widget<FilledButton>(postButton).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Kelly found the sunny spot again.');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Gallery'));
      expect(h.picker.requests, [PhotoSource.gallery]);
      expect(find.byTooltip('Remove photo'), findsOneWidget);

      await tester.tap(postButton);
      await tester.pumpAndSettle();

      expect(headerTitle('Community'), findsOneWidget);
      expect(find.text('Kelly found the sunny spot again.'), findsOneWidget);
      expect(find.text('with Kelly · just now'), findsOneWidget);
      final newest = (await storedPosts(tester, h)).first;
      expect(newest.text, 'Kelly found the sunny spot again.');
      expect(newest.petName, 'Kelly');
      expect(newest.photo, isA<MemoryPostPhoto>());
    });

    testWidgets('a post can go out without a pet tag or a photo', (tester) async {
      final h = await pumpCommunity(tester);

      await tester.tap(find.text('New post'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Good morning everyone.');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Kelly')); // untag
      await tester.tap(find.widgetWithText(FilledButton, 'Post'));
      await tester.pumpAndSettle();

      expect(find.text('Good morning everyone.'), findsOneWidget);
      expect(find.text('just now'), findsOneWidget);
      final newest = (await storedPosts(tester, h)).first;
      expect(newest.petName, isNull);
      expect(newest.photo, isNull);
      expect(h.picker.requests, isEmpty);
    });

    testWidgets('leaving a half-written post asks first', (tester) async {
      await pumpCommunity(tester);

      await tester.tap(find.text('New post'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Half a thought');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this post?'), findsOneWidget);
      await tester.tap(find.text('Keep writing'));
      await tester.pumpAndSettle();
      expect(find.text('Half a thought'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(headerTitle('Community'), findsOneWidget);
      expect(find.text('Half a thought'), findsNothing);
    });

    testWidgets('delete own post', (tester) async {
      final h = await pumpCommunity(tester);
      await tester.scrollUntilVisible(find.text('with Kelly · 2 h ago'), 200);

      await tapVisible(tester, inCard('Alex', find.byTooltip('Post options')));
      expect(find.text('Report'), findsNothing); // you cannot report yourself
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this post?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text(alexPost), findsNothing);
      expect(find.text('Your post was deleted.'), findsOneWidget);
      expect((await storedPosts(tester, h)).any((p) => p.authorId == 'demo'), isFalse);
    });

    testWidgets('report hides a post and records the report', (tester) async {
      final h = await pumpCommunity(tester);

      await tester.tap(inCard('Maya', find.byTooltip('Post options')));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsNothing); // not yours to delete
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();

      expect(find.text('Report this post'), findsOneWidget);
      await tester.tap(find.text('Spam or advertising'));
      await tester.pumpAndSettle();

      expect(find.text(mayaPost), findsNothing);
      expect(find.text('Thanks. We have hidden this post and will review it.'), findsOneWidget);
      expect(h.feed.reports, hasLength(1));
      expect(h.feed.reports.single.reporterId, 'demo');
      expect(h.feed.reports.single.reason, ReportReason.spam);
    });

    testWidgets('empty state offers to write the first post', (tester) async {
      final feed = FakeFeedRepository(latency: Duration.zero, now: testClock, seeded: false);
      await pumpCommunity(tester, harness: CommunityHarness(feed: feed));

      expect(find.text('No posts yet'), findsOneWidget);
      await tester.tap(find.text('Write a post'));
      await tester.pumpAndSettle();
      expect(headerTitle('New post'), findsOneWidget);
    });

    testWidgets('error state can be retried', (tester) async {
      final feed = FakeFeedRepository(latency: Duration.zero, now: testClock)..failing = true;
      await pumpCommunity(tester, harness: CommunityHarness(feed: feed));

      expect(find.text('Cannot load the feed'), findsOneWidget);
      expect(find.text('Cannot reach the community right now. Please try again.'), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);

      feed.failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot load the feed'), findsNothing);
      expect(find.text(mayaPost), findsOneWidget);
    });
  });

  group('chat', () {
    testWidgets('lists the rooms; a sent message and a live one appear in the conversation', (tester) async {
      final h = await pumpCommunity(tester);
      await openSection(tester, 'Chat');

      // Kelly, the selected pet, is a dog: the dog rooms and the shared ones.
      for (final name in ['General', 'Puppies', 'Training tips', 'Senior dogs', 'Health questions']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Kittens'), findsNothing);
      expect(find.text('First weeks, teething and sleep'), findsOneWidget);

      await tester.tap(find.text('Puppies'));
      await tester.pumpAndSettle();

      expect(headerTitle('Puppies'), findsOneWidget);
      const others = 'Until about six months for us. Frozen carrot sticks were a big help.';
      expect(find.text(others), findsOneWidget);
      expect(find.text('Priya'), findsOneWidget);
      expect(find.text('04:11'), findsOneWidget); // 5 h 30 min before 09:41
      expect(find.text('Today'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Hello puppies');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(find.text('Hello puppies'), findsOneWidget);
      expect(find.text('09:41'), findsOneWidget);
      expect(find.text('Alex'), findsNothing); // own messages carry no name
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      // Mine sit on the right, other people's on the left.
      expect(tester.getTopRight(find.text('Hello puppies')).dx, greaterThan(300));
      expect(tester.getTopLeft(find.text(others)).dx, lessThan(60));

      // Someone else writes: it arrives through the stream, no refresh.
      h.chat.receive(channelId: 'puppies', authorId: 'u-maya', authorName: 'Maya', text: 'Welcome, Alex!');
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Alex!'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Welcome, Alex!')).dx, lessThan(60));

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Senior dogs'), findsOneWidget);
    });

    testWidgets('a conversation that cannot load can be retried', (tester) async {
      final h = await pumpCommunity(tester);
      await openSection(tester, 'Chat');

      h.chat.failing = true;
      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot load this conversation'), findsOneWidget);

      h.chat.failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Morning everyone! Biscuit says hi.'), findsOneWidget);
    });

    testWidgets('no rooms yet', (tester) async {
      final chat = FakeChatRepository(latency: Duration.zero, now: testClock, seeded: false);
      await pumpCommunity(tester, harness: CommunityHarness(chat: chat));
      await openSection(tester, 'Chat');

      expect(find.text('No chat rooms yet'), findsOneWidget);
    });
  });

  group('guides', () {
    testWidgets('list, category filter, search and reader', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Guides');

      expect(find.text("Your puppy's first week at home"), findsOneWidget);
      expect(find.text('A calm start: sleep, routine and first introductions.'), findsOneWidget);
      expect(find.textContaining('min read · Getting started'), findsWidgets);
      expect(find.text("Your cat's first week at home"), findsNothing); // Kelly is a dog

      // Category filter.
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Senior care'));
      expect(find.text('Keeping an older dog comfortable'), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsNothing);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'All'));

      // Search, including a miss.
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No guides match'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'loose lead');
      await tester.pumpAndSettle();
      expect(find.text('Walking nicely on a loose lead'), findsOneWidget);
      expect(find.text('Foods your dog should never eat'), findsNothing);

      // Reader.
      await tester.tap(find.text('Walking nicely on a loose lead'));
      await tester.pumpAndSettle();

      expect(headerTitle('Guide'), findsOneWidget);
      expect(find.text('Walking nicely on a loose lead'), findsOneWidget);
      expect(find.text('Training and behaviour'), findsOneWidget);
      expect(find.textContaining('min read · For dogs'), findsOneWidget);
      expect(find.text('Before you start'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(guideDisclaimer), 300);
      expect(find.text('Be realistic'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('loose lead'), findsOneWidget); // the search is kept
    });
  });
}
