import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/widgets/post_photo_view.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'community_helpers.dart';

const mayaPost =
    'First full night without a toilet trip! Four months old and we both finally slept. '
    'Taking him out right before bed made all the difference.';
const priyaQuestion =
    'Does anyone have tips for a dog who pulls towards every other dog on the lead? '
    'We have started turning around each time, but progress is slow.';
const jonasTip =
    'Rainy day plan: a towel rolled up with treats inside. Luna spent twenty happy minutes '
    'working it out and then slept the whole afternoon.';
const pepperPost = 'Pepper met the sea for the first time today. She barked at every single wave.';

/// A widget a screen reader names [label].
/// Direction marks around a name are ignored.
Finder labelled(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label != null && plain(w.properties.label!) == plain(label),
      description: 'labelled "$label"',
    );

/// The card of the post whose author line reads [author].
Finder cardOf(String author) => find.widgetWithText(PostCard, author);

Finder inCard(String author, Finder matching) => find.descendant(of: cardOf(author), matching: matching);

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

const maya = AppUser(id: 'u-maya', email: 'maya@example.test', displayName: 'Maya');

Future<void> chooseKind(WidgetTester tester, String name) async {
  // The row of kinds scrolls sideways on a phone.
  await tester.ensureVisible(find.byKey(ValueKey('kind-$name')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('kind-$name')));
  await tester.pumpAndSettle();
}

/// Writes a post from the composer, choosing [kind] when given.
Future<void> writePost(WidgetTester tester, String text, {String? kind}) async {
  await tester.tap(find.text('New post'));
  await tester.pumpAndSettle();
  if (kind != null) {
    await tester.tap(find.byKey(ValueKey('compose-kind-$kind')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Post'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('feed filters', () {
    testWidgets('kinds of post: questions, tips, back to all', (tester) async {
      await pumpCommunity(tester, size: const Size(390, 1400));
      expect(find.text(mayaPost), findsOneWidget);
      // Tags on the cards.
      await scrollTo(tester, inCard('Jonas', find.text('Tip')));
      await scrollTo(tester, inCard('Priya', find.text('Question')));
      await scrollTo(tester, find.byKey(const ValueKey('kind-question')));

      await chooseKind(tester, 'question');
      expect(find.text(priyaQuestion), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);
      expect(find.text(jonasTip), findsNothing);

      await chooseKind(tester, 'tip');
      expect(find.text(jonasTip), findsOneWidget);
      expect(find.text(priyaQuestion), findsNothing);

      await chooseKind(tester, 'lostFound');
      expect(find.text('No posts found'), findsOneWidget);

      await chooseKind(tester, 'all');
      expect(find.text(mayaPost), findsOneWidget);
    });

    testWidgets('searching the posts', (tester) async {
      await pumpCommunity(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Search posts'), 'sea');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text(pepperPost), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text(mayaPost), findsOneWidget);
    });

    testWidgets('a post about a dog shows under Dogs and Everything, not under Cats', (tester) async {
      await pumpCommunity(tester);
      // Kelly, the selected pet, is tagged: the post is about a dog.
      await writePost(tester, 'Kelly found a new favourite bench.');
      expect(find.text('Kelly found a new favourite bench.'), findsOneWidget);
      expect(find.text('Matched to Kelly. Tap Everything to see all posts.'), findsOneWidget);

      await chooseScope(tester, 'cats');
      expect(find.text('Kelly found a new favourite bench.'), findsNothing);
      // Posts for everyone still show.
      expect(find.text(mayaPost), findsOneWidget);

      await chooseScope(tester, 'everything');
      expect(find.text('Kelly found a new favourite bench.'), findsOneWidget);
    });

    testWidgets('more posts load at the end of the list', (tester) async {
      var clock = testNow.subtract(const Duration(days: 30));
      final feed = FakeFeedRepository(latency: Duration.zero, seeded: false, now: () => clock);
      await tester.runAsync(() async {
        for (var i = 1; i <= 45; i++) {
          clock = clock.add(const Duration(minutes: 10));
          await feed.createPost(author: maya, text: 'Walk number $i');
        }
      });
      await pumpCommunity(tester, harness: CommunityHarness(feed: feed));
      expect(find.text('Walk number 45'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Walk number 1'), 400, scrollable: find.byType(Scrollable).first);
      expect(find.text('Walk number 1'), findsOneWidget);
    });
  });

  group('posts', () {
    testWidgets('a question from the composer carries its tag', (tester) async {
      await pumpCommunity(tester);
      await tester.tap(find.text('New post'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compose-kind-question')));
      await tester.pumpAndSettle();
      expect(find.text('What would you like to ask other owners?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Best brush for a long coat?');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Post'));
      await tester.pumpAndSettle();

      expect(find.text('Best brush for a long coat?'), findsOneWidget);
      expect(inCard('Alex', find.text('Question')), findsWidgets);
    });

    testWidgets('editing my post changes its text and says Edited', (tester) async {
      await pumpCommunity(tester);
      await writePost(tester, 'Teh park was lovely.');

      await tester.tap(find.descendant(
        of: find.widgetWithText(PostCard, 'Teh park was lovely.'),
        matching: find.byTooltip('Post options'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(headerTitle('Edit post'), findsOneWidget);
      expect(find.text('Teh park was lovely.'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'The park was lovely.');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Your post was updated'), findsOneWidget);
      expect(find.text('The park was lovely.'), findsOneWidget);
      expect(find.textContaining('Edited'), findsOneWidget);
    });

    testWidgets('the author of a question marks the helpful answer', (tester) async {
      final h = await pumpCommunity(tester);
      await writePost(tester, 'Which harness for a puller?', kind: 'question');
      final question = (await storedPosts(tester, h)).firstWhere((p) => p.text == 'Which harness for a puller?');
      await tester.runAsync(() => h.feed.addComment(author: maya, postId: question.id, text: 'A front-clip harness helped us.'));

      await tester.tap(find.text('Which harness for a puller?'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Comment options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as the helpful answer'));
      await tester.pumpAndSettle();

      expect(find.text('Marked as the helpful answer'), findsOneWidget);
      expect(find.text('Helpful answer'), findsOneWidget);
      expect(find.text('Answered'), findsOneWidget);

      await goBack(tester);
      expect(inCard('Alex', find.text('Answered')), findsOneWidget);
    });

    testWidgets('only the author of a question may mark an answer', (tester) async {
      await pumpCommunity(tester);
      await scrollTo(tester, find.text(priyaQuestion));
      await tapVisible(tester, find.text(priyaQuestion));
      await tester.tap(find.byTooltip('Comment options').first);
      await tester.pumpAndSettle();
      expect(find.text('Mark as the helpful answer'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
    });

    testWidgets('sharing a post and liking a photo with a double tap', (tester) async {
      final h = await pumpCommunity(tester);
      await tester.tap(inCard('Maya', find.byTooltip('Post options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(h.shared.single, 'Maya on PetLoop: $mayaPost');

      final photo = find.descendant(of: find.widgetWithText(PostCard, jonasTip), matching: find.byType(PostPhotoView));
      await scrollTo(tester, photo);
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(inCard('Jonas', find.text('10')), findsOneWidget);
    });
  });

  group('members', () {
    testWidgets('a member page: who, where, their posts, and blocking', (tester) async {
      await pumpCommunity(tester);
      await tester.tap(labelled('Open Maya\'s profile'));
      await tester.pumpAndSettle();

      expect(headerTitle('Maya'), findsOneWidget);
      expect(find.text('Haifa · 1 post'), findsOneWidget);
      expect(find.text('Biscuit, four months of chaos.'), findsOneWidget);
      expect(find.text(mayaPost), findsOneWidget);
      expect(find.text('Block Maya'), findsOneWidget);

      await tester.tap(find.text('Block Maya'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();
      expect(find.text('You blocked this member.'), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);
    });

    testWidgets('my own page edits my line and city', (tester) async {
      final h = await pumpCommunity(tester);
      await scrollTo(tester, labelled('Open Alex\'s profile'));
      await tester.tap(labelled('Open Alex\'s profile'));
      await tester.pumpAndSettle();
      expect(find.text('Kelly and Soya keep me busy.'), findsOneWidget);
      expect(find.textContaining('Block'), findsNothing);

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'About me'), 'Two dogs, many walks.');
      await tester.enterText(find.widgetWithText(TextField, 'City'), 'Eilat');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Your profile was updated'), findsOneWidget);
      expect(find.text('Two dogs, many walks.'), findsOneWidget);
      expect(find.textContaining('Eilat'), findsOneWidget);
      expect((await tester.runAsync(() => h.members.fetchMember('demo')))!.city, 'Eilat');
    });

    testWidgets('a name in a chat room opens the member page', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Chat');
      await tester.tap(find.text('Puppies'));
      await tester.pumpAndSettle();
      await tester.tap(labelled('Open Priya\'s profile'));
      await tester.pumpAndSettle();
      expect(headerTitle('Priya'), findsOneWidget);
      expect(find.text('Ramat Gan · 1 post'), findsOneWidget);
    });
  });

  group('activity', () {
    testWidgets('comments on my posts and answers to my messages, with a dot until seen', (tester) async {
      final h = await pumpCommunity(tester);
      // An answer to one of my chat messages.
      await openSection(tester, 'Chat');
      await tester.tap(find.text('Puppies'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Any tips for chewing?');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      h.chat.receive(
        channelId: 'puppies',
        authorId: 'u-priya',
        authorName: 'Priya',
        text: 'Frozen carrots!',
        replyToId: h.chat.idOf('puppies', 'Any tips for chewing?'),
      );
      await tester.pumpAndSettle();
      await goBack(tester);
      await openSection(tester, 'Feed');

      expect(find.byTooltip('New activity'), findsOneWidget);
      await tester.tap(find.byTooltip('New activity'));
      await tester.pumpAndSettle();

      expect(headerTitle('Activity'), findsOneWidget);
      expect(find.text('Priya answered your message'), findsOneWidget);
      expect(find.text('Frozen carrots!'), findsOneWidget);
      expect(find.text('Sam commented on your post'), findsOneWidget);

      await tester.tap(find.text('Sam commented on your post'));
      await tester.pumpAndSettle();
      expect(headerTitle('Post'), findsOneWidget);
      await scrollOnTop(tester, find.text('What a lovely face. Thirteen and thriving!'));
      expect(find.text('What a lovely face. Thirteen and thriving!'), findsOneWidget);

      await goBack(tester);
      await goBack(tester);
      expect(find.byTooltip('Activity'), findsOneWidget);
      expect(find.byTooltip('New activity'), findsNothing);
    });
  });

  testWidgets('in Hebrew on a small phone: the feed header, a member, activity and the composer fit', (tester) async {
    await pumpCommunity(
      tester,
      harness: CommunityHarness(appLanguage: AppLanguage.hebrew),
      size: const Size(320, 568),
    );
    expect(find.text(he.kindsAll), findsOneWidget);
    expect(find.widgetWithText(TextField, he.searchPostsHint), findsOneWidget);

    await scrollTo(tester, labelled(he.openProfile('Maya')));
    await tester.tap(labelled(he.openProfile('Maya')).first);
    await tester.pumpAndSettle();
    expect(find.text('Biscuit, four months of chaos.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await goBack(tester);

    await tester.tap(find.byTooltip(he.activityNew));
    await tester.pumpAndSettle();
    expect(headerTitle(he.activityTitle), findsOneWidget);
    expect(reads(he.activityComment('Sam')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await goBack(tester);

    await tester.tap(find.text(he.newPost));
    await tester.pumpAndSettle();
    expect(find.text(he.kindLostFound), findsOneWidget);
    await tester.tap(find.text(he.kindLostFound));
    await tester.pumpAndSettle();
    expect(find.text(he.composerHintLostFound), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a muted room shows no unread count', (tester) async {
    await pumpCommunity(tester);
    await openSection(tester, 'Chat');
    expect(find.text('5'), findsOneWidget); // General's badge
    await tester.tap(find.text('Puppies'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('About this room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mute this room'));
    await tester.pumpAndSettle();
    expect(find.text('Muted: no unread count for this room'), findsOneWidget);
    await closeSheet(tester);
    await goBack(tester);

    expect(find.byTooltip('Muted'), findsOneWidget);
  });
}
