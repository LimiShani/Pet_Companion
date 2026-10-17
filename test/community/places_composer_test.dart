import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/feed/feed_controller.dart';
import 'package:pet_companion/features/community/feed/places_group.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/header_search.dart';

import 'community_helpers.dart';

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppBottomNav)));

Post _rec(String id, String place, {String? city = 'petah-tikva', int hours = 1}) => Post(
  id: id,
  authorId: 'u',
  authorName: 'Dana',
  text: 'Lovely',
  createdAt: testNow.subtract(Duration(hours: hours)),
  kind: PostKind.recommendation,
  localityCode: city,
  placeName: place,
);

/// Three recommendations of two vets, written before the app starts.
Future<CommunityHarness> withRecommendations(WidgetTester tester, {AppLanguage? language}) async {
  final harness = CommunityHarness(appLanguage: language);
  await tester.runAsync(() async {
    for (final (text, place) in [
      ('Gentle vet, explains everything', "Dr. Levi's clinic"),
      ('Our vet for years', "dr. levi's clinic"),
      ('Quick and kind vet', 'Vet on Herzl'),
    ]) {
      await harness.feed.createPost(
        author: const AppUser(id: 'u-sam', email: 'sam@example.test', displayName: 'Sam'),
        text: text,
        kind: PostKind.recommendation,
        localityCode: 'petah-tikva',
        placeName: place,
      );
    }
  });
  return harness;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('places people recommend', () {
    test('grouped by place and city, the most recommended first', () {
      final places = recommendedPlaces([
        _rec('a', "Dr. Levi's clinic", hours: 3),
        _rec('b', "dr. levi's clinic ", hours: 1),
        _rec('c', 'Vet on Herzl', city: 'ramat-gan'),
        _rec('d', "Dr. Levi's clinic", city: 'haifa'),
        Post(id: 'e', authorId: 'u', authorName: 'x', text: 'y', createdAt: testNow, placeName: 'Ignored'),
      ]);
      expect([for (final p in places) (p.name, p.localityCode, p.posts.length)], [
        ("dr. levi's clinic", 'petah-tikva', 2),
        ('Vet on Herzl', 'ramat-gan', 1),
        ("Dr. Levi's clinic", 'haifa', 1),
      ]);
      expect(places.first.posts.first.id, 'b', reason: 'newest first');
    });

    testWidgets('searching: "Places" above the posts; one with several posts searches for it', (tester) async {
      final harness = await withRecommendations(tester);
      await pumpCommunity(tester, harness: harness, size: const Size(390, 1600));
      expect(find.byKey(PlacesGroup.groupKey), findsNothing, reason: 'only while searching');
      await searchFor(tester, 'vet');
      expect(find.text(en.searchPlaces), findsOneWidget);
      expect(find.text(en.searchPostsHeading), findsOneWidget);
      final first = find.byKey(PlacesGroup.placeKey(0));
      expect(find.descendant(of: first, matching: find.textContaining(en.placeRecommendations(2))), findsOneWidget);
      expect(find.descendant(of: first, matching: find.textContaining('Petah Tikva')), findsOneWidget);
      await tester.tap(first);
      await tester.pumpAndSettle();
      final words = containerOf(tester).read(feedFilterProvider).search.toLowerCase();
      expect(words, "dr. levi's clinic");
      final field = tester.widget<TextField>(find.descendant(of: find.byKey(HeaderSearchField.fieldKey), matching: find.byType(TextField), matchRoot: true));
      expect(field.controller?.text.toLowerCase(), "dr. levi's clinic", reason: 'the field shows the new words');
      expect(containerOf(tester).read(feedControllerProvider).value!.length, 2);
    });

    testWidgets('a place with one recommendation opens it', (tester) async {
      final harness = await withRecommendations(tester);
      await pumpCommunity(tester, harness: harness, size: const Size(390, 1600));
      await searchFor(tester, 'Herzl');
      await tester.tap(find.byKey(PlacesGroup.placeKey(0)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Quick and kind vet'), findsWidgets);
      expect(find.byKey(PlacesGroup.groupKey), findsNothing);
    });
  });

  group('the composer', () {
    testWidgets('a new post starts near the member\'s city; a recommendation has a place', (tester) async {
      final harness = await pumpCommunity(tester, size: const Size(390, 1400));
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-post-recommendation')));
      await tester.pumpAndSettle();
      expect(find.text('${en.composerNear('Tel Aviv-Yafo')} ▾'), findsOneWidget);
      expect(find.text(en.composerPlace), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'The kindest groomer');
      await tester.enterText(find.byKey(const ValueKey('compose-place')), 'Fluffy Salon');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, en.postButton));
      await tester.pumpAndSettle();
      final post = (await tester.runAsync(
        () => harness.feed.fetchPosts(viewer: demoUser, query: const FeedQuery(search: 'groomer')),
      ))!.single;
      expect((post.localityCode, post.placeName), ('tel-aviv-yafo', 'Fluffy Salon'));
      expect(find.byKey(ValueKey('post-place-${post.id}')), findsOneWidget, reason: 'the card shows the place');
    });

    testWidgets('another city, or everywhere; a moment has no place field', (tester) async {
      final harness = await pumpCommunity(tester, size: const Size(390, 1400));
      await writeWith(tester, (tester) async {
        expect(find.byKey(const ValueKey('compose-place')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('compose-locality')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('compose-locality-other')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('compose-city-field')), 'petah');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('compose-city-petah-tikva')));
        await tester.pumpAndSettle();
        expect(find.text('${en.composerNear('Petah Tikva')} ▾'), findsOneWidget);
      }, 'Morning in the park');
      await writeWith(tester, (tester) async {
        await tester.tap(find.byKey(const ValueKey('compose-locality')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('compose-locality-everywhere')));
        await tester.pumpAndSettle();
        expect(find.text('${en.composerEverywhere} ▾'), findsOneWidget);
      }, 'Evening everywhere');
      final posts = (await tester.runAsync(() => harness.feed.fetchPosts(viewer: demoUser)))!;
      expect(posts.firstWhere((p) => p.text == 'Morning in the park').localityCode, 'petah-tikva');
      expect(posts.firstWhere((p) => p.text == 'Evening everywhere').localityCode, isNull);
    });

    testWidgets('Hebrew: the chip and the place field', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: AppLanguage.hebrew), size: const Size(390, 1400));
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-post-recommendation')));
      await tester.pumpAndSettle();
      expect(find.text(he.composerPlace), findsOneWidget);
      expect(find.textContaining('ליד'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Opens the composer on a moment, runs [choose], writes [text] and posts.
Future<void> writeWith(WidgetTester tester, Future<void> Function(WidgetTester) choose, String text) async {
  await tester.tap(find.byKey(const Key('add-fab')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('add-post-moment')));
  await tester.pumpAndSettle();
  await choose(tester);
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, en.postButton));
  await tester.pumpAndSettle();
}
