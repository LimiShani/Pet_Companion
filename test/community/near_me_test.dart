import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/feed/feed_controller.dart';
import 'package:pet_companion/features/community/feed/near_me.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/services/community/data/fake_feed_repository.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import 'community_helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppBottomNav)));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('posts near me', () {
    test('a query near some localities keeps only their posts', () {
      final here = Post(
        id: 'a',
        authorId: 'u',
        authorName: 'Dana',
        text: 'x',
        createdAt: testNow,
        localityCode: 'petah-tikva',
      );
      final everywhere = Post(id: 'b', authorId: 'u', authorName: 'Dana', text: 'y', createdAt: testNow);
      const near = FeedQuery(localities: {'petah-tikva', 'bnei-brak'});
      expect(near.matches(here), isTrue);
      expect(near.matches(everywhere), isFalse, reason: 'posts for everywhere are not "near"');
      expect(const FeedQuery().matches(everywhere), isTrue);
      expect(near.narrowed, isTrue);
      expect(near, const FeedQuery(localities: {'bnei-brak', 'petah-tikva'}));
      expect(near == const FeedQuery(), isFalse);
    });

    test('a post keeps its city, and a recommendation its place', () async {
      final feed = FakeFeedRepository(latency: Duration.zero, now: testClock, seeded: false);
      final tip = await feed.createPost(
        author: demoUser,
        text: 'Gentle with seniors',
        kind: PostKind.recommendation,
        localityCode: 'petah-tikva',
        placeName: "  Dr. Levi's clinic ",
      );
      expect(tip.localityCode, 'petah-tikva');
      expect(tip.placeName, "Dr. Levi's clinic");
      final moment = await feed.createPost(author: demoUser, text: 'Hi', placeName: 'A shop');
      expect(moment.placeName, isNull, reason: 'only recommendations carry a place');
      expect(moment.localityCode, isNull);
      await expectLater(
        feed.createPost(author: demoUser, text: 'x', kind: PostKind.recommendation, placeName: 'x' * 81),
        throwsA(isA<CommunityException>()),
      );
      final edited = await feed.updatePost(viewer: demoUser, post: tip, text: 'Now a tip', kind: PostKind.tip);
      expect(edited.placeName, isNull, reason: 'no longer a recommendation, no place');
      expect(edited.localityCode, 'petah-tikva');
    });
  });

  group('the Near me chip', () {
    testWidgets('after All in the filter row; it narrows the feed to the city around me', (tester) async {
      await pumpCommunity(tester);
      final chip = find.byKey(const ValueKey('feed-near-me'));
      expect(chip, findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text(en.feedNearMe)), findsOneWidget);
      final all = tester.getRect(find.byKey(const ValueKey('kind-all')));
      final moment = tester.getRect(find.byKey(const ValueKey('kind-moment')));
      final near = tester.getRect(chip);
      expect(near.left, greaterThan(all.right));
      expect(near.right, lessThan(moment.left));

      final container = containerOf(tester);
      final codes = container.read(nearMeCodesProvider)!;
      expect(codes, contains('tel-aviv-yafo'), reason: 'the profile says Tel Aviv');
      final everything = container.read(feedControllerProvider).value!.length;
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(container.read(feedFilterProvider).nearMe, isTrue);
      final posts = container.read(feedControllerProvider).value!;
      expect(posts, isNotEmpty);
      expect(posts.length, lessThan(everything));
      expect(posts.every((p) => codes.contains(p.localityCode)), isTrue);

      // A kind on top of it, then off again.
      await tester.tap(find.byKey(const ValueKey('kind-tip')));
      await tester.pumpAndSettle();
      expect(container.read(feedFilterProvider).nearMe, isTrue, reason: 'a kind keeps Near me');
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(container.read(feedQueryProvider).localities, isNull);
    });

    testWidgets('no city and no Outside area: no chip', (tester) async {
      final harness = CommunityHarness();
      await tester.runAsync(() => harness.members.updateMyProfile(viewer: demoUser, bio: '', city: ''));
      await pumpCommunity(tester, harness: harness);
      expect(find.byKey(const ValueKey('feed-near-me')), findsNothing);
    });

    testWidgets('Hebrew: "בסביבה שלי"', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: AppLanguage.hebrew));
      expect(find.text(he.feedNearMe), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
