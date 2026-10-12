import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/community_routes.dart';
import 'package:pet_companion/features/community/community_screen.dart';
import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/feed/feed_controller.dart';
import 'package:pet_companion/features/community/feed/post_card.dart';
import 'package:pet_companion/features/community/guides/guides_providers.dart';
import 'package:pet_companion/features/community/widgets/advice_notice.dart';
import 'package:pet_companion/features/community/widgets/post_photo_view.dart';
import 'package:pet_companion/features/community/widgets/scope_menu_chip.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:pet_companion/widgets/coral_segmented_control.dart';
import 'package:pet_companion/widgets/header_search.dart';

import 'community_helpers.dart';

// The streamlined Community (phase 4): one filter row per section with the
// animal as a menu chip, the search in the header, the advice line said
// once at the top of the feed, photos in their whole rounded frame, and a
// guide's byline on top with its "About" box after the text.

const mayaPost = 'First full night without a toilet trip! Four months old and we both finally slept. '
    'Taking him out right before bed made all the difference.';
const pepperPost = 'Pepper met the sea for the first time today. She barked at every single wave.';

final feedRow = find.byKey(const Key('feed-filter-row'));
final guidesRow = find.byKey(const Key('guides-filter-row'));
final feedAdvice = find.byKey(FeedAdviceLine.lineKey);

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

/// The animal menu chip of the section on screen, reading [label].
Finder scopeChipReads(String label) => find.descendant(of: scopeMenu, matching: find.text(label));

/// The words of the section on screen are searched for.
String feedSearch(WidgetTester tester) => hostContainer(tester).read(feedFilterProvider).search;
String guidesSearch(WidgetTester tester) => hostContainer(tester).read(guidesQueryProvider);

Future<void> goTo(WidgetTester tester, String location) async {
  GoRouter.of(tester.element(find.byType(CommunityScreen))).go(location);
  await tester.pumpAndSettle();
}

/// Every clip around a post photo: a rounded rectangle of 18 px, never an
/// oval, in the whole 4:3 frame.
void expectRoundedFrame(WidgetTester tester, Finder photo) {
  expect(photo, findsWidgets);
  for (final element in photo.evaluate()) {
    final one = find.byElementPredicate((e) => e == element);
    expect(find.descendant(of: one, matching: find.byType(ClipOval)), findsNothing);
    expect(find.descendant(of: one, matching: find.byType(ClipPath)), findsNothing);
    final clip = tester.widget<ClipRRect>(find.descendant(of: one, matching: find.byType(ClipRRect)).first);
    expect(clip.borderRadius, BorderRadius.circular(18));
    expect(tester.widget<AspectRatio>(find.descendant(of: one, matching: find.byType(AspectRatio))).aspectRatio, 4 / 3);
    // The frame is filled behind the picture, so it always shows whole.
    final frame = tester.getSize(find.descendant(of: one, matching: find.byType(AspectRatio)));
    final fill = tester.getSize(find.descendant(of: one, matching: find.byType(ColoredBox)).first);
    expect(fill, frame);
  }
  // Nowhere on the cards is anything cut to an oval.
  expect(find.descendant(of: find.byType(PostCard), matching: find.byType(ClipOval)), findsNothing);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('one filter row', () {
    testWidgets('the feed: the animal menu, a divider, the kinds; no caption, no search field', (tester) async {
      await pumpCommunity(tester);

      expect(feedRow, findsOneWidget);
      final chip = find.descendant(of: feedRow, matching: find.byKey(ScopeMenuChip.chipKey));
      final divider = find.descendant(of: feedRow, matching: find.byKey(ScopeFilterRow.dividerKey));
      final all = find.descendant(of: feedRow, matching: find.byKey(const ValueKey('kind-all')));
      expect(chip, findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text('Dogs')), findsOneWidget);
      expect(tester.getSize(divider).width, 1);
      // In one line, in this order.
      expect(tester.getCenter(chip).dy, moreOrLessEquals(tester.getCenter(all).dy, epsilon: 1));
      expect(tester.getCenter(chip).dx, lessThan(tester.getCenter(divider).dx));
      expect(tester.getCenter(divider).dx, lessThan(tester.getCenter(all).dx));
      for (final kind in ['question', 'tip', 'recommendation', 'lostFound', 'moment']) {
        expect(find.descendant(of: feedRow, matching: find.byKey(ValueKey('kind-$kind'))), findsOneWidget);
      }

      // Nothing else stacked above the posts.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Matched to'), findsNothing);
      expect(find.textContaining('Tap Everything'), findsNothing);
      expect(find.textContaining('Showing'), findsNothing);
      expect(find.byType(ChoiceChip).hitTestable(), findsWidgets);
      expect(find.widgetWithText(ChoiceChip, 'Dogs'), findsNothing); // the animal is no longer a chip row
    });

    testWidgets('guides: the animal menu, a divider, the categories; chat: the menu on the "Topic rooms" line', (
      tester,
    ) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Guides');
      expect(guidesRow, findsOneWidget);
      expect(find.descendant(of: guidesRow, matching: find.byKey(ScopeMenuChip.chipKey)), findsOneWidget);
      expect(find.descendant(of: guidesRow, matching: find.byKey(ScopeFilterRow.dividerKey)), findsOneWidget);
      expect(find.descendant(of: guidesRow, matching: find.byKey(const ValueKey('category-all'))), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Matched to'), findsNothing);

      await openSection(tester, 'Chat');
      final heading = find.byKey(const Key('rooms-heading'));
      expect(heading, findsOneWidget);
      expect(find.descendant(of: heading, matching: find.text('Topic rooms')), findsOneWidget);
      expect(find.descendant(of: heading, matching: find.byKey(ScopeMenuChip.chipKey)), findsOneWidget);
      // At the end of the heading's line.
      expect(
        tester.getCenter(find.descendant(of: heading, matching: find.byKey(ScopeMenuChip.chipKey))).dx,
        greaterThan(tester.getCenter(find.text('Topic rooms')).dx),
      );
      expect(find.textContaining('Matched to'), findsNothing);
    });

    testWidgets('the animal menu lists the three views and changes Feed, Guides and Chat together', (tester) async {
      await pumpCommunity(tester);

      await tester.tap(scopeMenu);
      await tester.pumpAndSettle();
      for (final scope in CommunityScope.values) {
        expect(find.byKey(ScopeMenuChip.itemKey(scope)), findsOneWidget);
      }
      await tester.tap(find.byKey(ScopeMenuChip.itemKey(CommunityScope.cats)));
      await tester.pumpAndSettle();
      expect(scopeChipReads('Cats'), findsOneWidget);
      expect(hostContainer(tester).read(feedQueryProvider).audiences, {Audience.everyone, Audience.cats});
      // Posts for everyone still show.
      expect(find.text(mayaPost), findsOneWidget);

      await openSection(tester, 'Guides');
      expect(scopeChipReads('Cats'), findsOneWidget);
      expect(find.text("Your cat's first week at home"), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsNothing);

      await chooseScope(tester, 'everything');
      expect(find.text("Your puppy's first week at home"), findsOneWidget);
      await openSection(tester, 'Chat');
      expect(scopeChipReads('Everything'), findsOneWidget);
      await openSection(tester, 'Feed');
      expect(scopeChipReads('Everything'), findsOneWidget);
      expect(hostContainer(tester).read(feedQueryProvider).audiences, isNull);
    });
  });

  group('search in the header', () {
    testWidgets('the feed: opens in the header, closing restores the sections and clears the words', (tester) async {
      await pumpCommunity(tester);
      expect(find.byType(CoralSegmentedControl), findsOneWidget);
      expect(find.byTooltip('Search posts'), findsOneWidget);
      // The shield went to the You page.
      expect(find.byTooltip('Community safety'), findsNothing);

      await openSearch(tester);
      final field = find.byKey(HeaderSearchField.fieldKey);
      expect(find.descendant(of: find.byType(CoralHeader), matching: field), findsOneWidget);
      expect(find.byType(CoralSegmentedControl), findsNothing);
      expect(find.widgetWithText(TextField, 'Search posts'), findsOneWidget);

      await searchFor(tester, 'sea');
      expect(feedSearch(tester), 'sea');
      expect(find.text(pepperPost), findsOneWidget);
      expect(find.text(mayaPost), findsNothing);

      await closeSearch(tester);
      expect(find.byType(CoralSegmentedControl), findsOneWidget);
      expect(field, findsNothing);
      expect(feedSearch(tester), isEmpty);
      expect(find.text(mayaPost), findsOneWidget);

      // Opening it again starts empty.
      await openSearch(tester);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    });

    testWidgets('the guides filter as the words are typed; closing clears them', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Guides');
      expect(find.byTooltip('Search guides'), findsOneWidget);

      await openSearch(tester);
      expect(find.byType(CoralSegmentedControl), findsNothing);
      await tester.enterText(find.byKey(HeaderSearchField.fieldKey), 'xylitol');
      await tester.pumpAndSettle();
      expect(guidesSearch(tester), 'xylitol');
      expect(find.text('Foods your dog should never eat'), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsNothing);

      await closeSearch(tester);
      expect(find.byType(CoralSegmentedControl), findsOneWidget);
      expect(guidesSearch(tester), isEmpty);
      expect(find.text("Your puppy's first week at home"), findsOneWidget);
    });

    testWidgets('chat has no search: no magnifier there', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Chat');
      expect(find.byKey(HeaderSearchButton.buttonKey), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('the advice line, once', () {
    testWidgets('on the feed: below the filters, above the first post; Hide hides it for the session', (tester) async {
      await pumpCommunity(tester);
      expect(feedAdvice, findsOneWidget);
      expect(find.descendant(of: feedAdvice, matching: find.text(en.adviceNotice)), findsOneWidget);
      // Said once: no other advice line on the feed.
      expect(find.byType(AdviceNotice), findsNothing);
      expect(find.text(en.adviceNotice), findsOneWidget);

      final line = tester.getRect(feedAdvice);
      expect(line.top, greaterThanOrEqualTo(tester.getRect(feedRow).bottom));
      expect(line.bottom, lessThanOrEqualTo(tester.getRect(find.widgetWithText(PostCard, 'Maya')).top));

      await tester.tap(find.descendant(of: feedAdvice, matching: find.widgetWithText(TextButton, 'Hide')));
      await tester.pumpAndSettle();
      expect(feedAdvice, findsNothing);
      expect(find.text(en.adviceNotice), findsNothing);

      // Still hidden after visiting another section and a post.
      await openSection(tester, 'Chat');
      await openSection(tester, 'Feed');
      expect(feedAdvice, findsNothing);
      await tester.tap(find.text(mayaPost));
      await tester.pumpAndSettle();
      await goBack(tester);
      expect(feedAdvice, findsNothing);
    });

    testWidgets('not on the post page; still in the health room and the room info', (tester) async {
      await pumpCommunity(tester);
      await tester.tap(find.text(mayaPost));
      await tester.pumpAndSettle();
      expect(headerTitle('Post'), findsOneWidget);
      expect(find.byType(AdviceNotice), findsNothing);
      expect(find.text(contactProfessionalLabel, findRichText: true), findsNothing);
      await goBack(tester);

      await openSection(tester, 'Chat');
      await tester.tap(find.text('Health questions'));
      await tester.pumpAndSettle();
      expect(find.byType(AdviceNotice), findsOneWidget);
      await goBack(tester);

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(find.byType(AdviceNotice), findsNothing);
      await tester.tap(find.byTooltip('About this room'));
      await tester.pumpAndSettle();
      expect(find.byType(AdviceNotice), findsOneWidget);
      expect(find.textContaining(contactProfessionalLabel, findRichText: true), findsOneWidget);
    });
  });

  group('post photos', () {
    testWidgets('the whole 4:3 frame with 18 px corners, never an oval: feed, post page, member page', (
      tester,
    ) async {
      await pumpCommunity(tester);
      final alexPhoto = find.descendant(of: find.widgetWithText(PostCard, 'Alex'), matching: find.byType(PostPhotoView));
      await scrollTo(tester, alexPhoto);
      expectRoundedFrame(tester, alexPhoto);
      // As wide as the card's text, in its 4:3 shape.
      final size = tester.getSize(alexPhoto);
      expect(size.width / size.height, moreOrLessEquals(4 / 3, epsilon: 0.01));

      await tapVisible(
        tester,
        find.text('Kelly is thirteen and still insists on carrying the biggest stick in the park. '
            'Slower walks these days, same big ambitions.'),
      );
      expect(headerTitle('Post'), findsOneWidget);
      expectRoundedFrame(tester, find.byType(PostPhotoView));
      await goBack(tester);

      await goTo(tester, CommunityRoutes.member('demo'));
      await scrollOnTop(tester, find.byType(PostPhotoView));
      expectRoundedFrame(tester, find.byType(PostPhotoView));
    });
  });

  group('the guide reader', () {
    testWidgets('a byline under the title, and the About box after the text, above the closing note', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Guides');
      await tapVisible(tester, find.text("Your cat's first week at home"));

      final byline = find.byKey(const Key('guide-byline'));
      expect(reads('By PetLoop team · Updated 30.09.26 · Not reviewed by a veterinarian'), findsOneWidget);
      final title = find.descendant(of: find.byType(ListView), matching: find.text("Your cat's first week at home"));
      expect(tester.getTopLeft(byline).dy, greaterThan(tester.getBottomLeft(title).dy));

      await scrollOnTop(tester, find.text(guideDisclaimer));
      final about = find.byKey(const Key('about-guide'));
      expect(about, findsOneWidget);
      expect(tester.getBottomLeft(about).dy, lessThan(tester.getTopLeft(find.text(guideDisclaimer)).dy));
    });
  });
}
