import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/data/audience.dart';
import 'package:pet_companion/features/community/data/community_language.dart';
import 'package:pet_companion/features/community/widgets/advice_notice.dart';
import 'package:pet_companion/features/community/widgets/scope_menu_chip.dart';
import 'package:pet_companion/widgets/app_tag.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'community_helpers.dart';
import 'guide_fixtures.dart';

Finder headerTitle(String title) => find.descendant(of: find.byType(CoralHeader), matching: find.text(title));

/// A small tag with [label] (not the chip of the same name).
Finder tag(String label) => find.widgetWithText(AppTag, label);

/// The advice line (its words are one rich text).
final adviceLine = find.byType(AdviceNotice);

/// The animal menu chip of the section on screen, reading [label] ("Dogs",
/// "Cats", "Everything").
Finder scopeChip(String label) =>
    find.descendant(of: find.byKey(ScopeMenuChip.chipKey), matching: find.text(label)).hitTestable();

const attribution = 'By PetLoop team · Updated 30.09.26';
const authorRole = 'App content team, writing with an AI assistant. Not veterinarians or trainers.';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('cats as first-class', () {
    testWidgets('a cat owner starts on the cat rooms and the shared ones', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Chat');

      expect(scopeChip('Cats'), findsOneWidget);
      for (final name in ['General', 'Kittens', 'Litter and cleaning', 'Cat behaviour and play', 'Senior cats']) {
        expect(find.text(name), findsOneWidget);
      }
      await scrollTo(tester, find.text('Health questions'));
      for (final name in ['Puppies', 'Training tips', 'Senior dogs']) {
        expect(find.text(name), findsNothing);
      }
      // Nothing is tagged while only one animal is shown.
      expect(find.byType(AppTag), findsNothing);
    });

    testWidgets('a cat room opens and takes a message', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Chat');

      await tester.tap(find.text('Litter and cleaning'));
      await tester.pumpAndSettle();
      expect(headerTitle('Litter and cleaning'), findsOneWidget);
      expect(find.text('A second box in another room made the biggest difference for us.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'We scoop morning and evening now.');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(find.text('We scoop morning and evening now.'), findsOneWidget);
    });

    testWidgets('Everything shows every room, each tagged with its animal', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Chat');
      expect(scopeChip('Dogs'), findsOneWidget);

      await chooseScope(tester, 'everything');
      expect(scopeChip('Everything'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Puppies'), findsOneWidget);
      expect(tag('Dogs'), findsWidgets);

      await scrollTo(tester, find.text('Senior cats'));
      expect(tag('Cats'), findsWidgets);
      await scrollTo(tester, find.text('Health questions'));
    });

    testWidgets('the choice is shared by Chat and Guides and goes back to the pet when another is selected', (
      tester,
    ) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Chat');
      await chooseScope(tester, 'cats');
      expect(scopeChip('Cats'), findsOneWidget);
      expect(find.text('Kittens'), findsOneWidget);
      expect(find.text('Puppies'), findsNothing);

      await openSection(tester, 'Guides');
      expect(scopeChip('Cats'), findsOneWidget);
      expect(find.text("Your cat's first week at home"), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsNothing);

      // Selecting the other pet (as the pet switcher on Home does).
      hostContainer(tester).read(selectedPetIdProvider.notifier).select('soya');
      await tester.pumpAndSettle();
      expect(scopeChip('Dogs'), findsOneWidget);
      expect(find.text("Your puppy's first week at home"), findsOneWidget);
      expect(find.text("Your cat's first week at home"), findsNothing);
    });

    testWidgets('cat guides: categories that fit, and who wrote each guide', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Guides');

      expect(scopeChip('Cats'), findsOneWidget);
      expect(find.text("Your cat's first week at home"), findsOneWidget);
      expect(find.text(attribution), findsWidgets);
      expect(find.text("Your puppy's first week at home"), findsNothing);

      // Only the categories that have cat guides.
      for (final id in ['all', 'start', 'home', 'behaviour', 'health']) {
        expect(find.byKey(ValueKey('category-$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('category-nutrition')), findsNothing);
      expect(find.byKey(const ValueKey('category-senior')), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('category-home')));
      expect(find.text('Setting up the litter box'), findsOneWidget);
      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(find.text('Keeping litter smell and mess under control'), findsOneWidget);
      expect(find.text("Your cat's first week at home"), findsNothing);
      expect(find.textContaining('min read · Home and cleaning'), findsNWidgets(3));
    });

    testWidgets('a search with no match for this animal offers to search everything', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Guides');

      await searchFor(tester, 'xylitol');
      expect(find.text('No guides for cats match'), findsOneWidget);
      expect(find.text('There is 1 match among the guides for every animal.'), findsOneWidget);

      await tapVisible(tester, find.text('Search everything'));
      expect(scopeChip('Everything'), findsOneWidget);
      expect(find.text('Foods your dog should never eat'), findsOneWidget);
      expect(tag('Dogs'), findsOneWidget);

      // Nothing anywhere: the plain message, without the offer.
      await searchFor(tester, 'zzzz');
      expect(find.text('No guides match'), findsOneWidget);
      expect(find.text('Search everything'), findsNothing);
    });

    testWidgets('an owner of another kind of animal starts on Everything', (tester) async {
      const bunny = Pet(id: 'bunny', name: 'Bunny', species: PetSpecies.rabbit);
      await pumpCommunity(tester, harness: CommunityHarness(pets: const [bunny]));
      await openSection(tester, 'Chat');

      expect(scopeChip('Everything'), findsOneWidget);
      expect(find.text('Puppies'), findsOneWidget);
      expect(hostContainer(tester).read(communityScopeProvider), CommunityScope.everything);
    });
  });

  group('honest attribution', () {
    Future<void> openLitterGuide(WidgetTester tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst));
      await openSection(tester, 'Guides');
      await scrollTo(tester, find.text('How many litter boxes do you need?'));
      await tester.tap(find.text('How many litter boxes do you need?'));
      await tester.pumpAndSettle();
    }

    testWidgets('the reader says who wrote a guide and that no vet reviewed it: a byline before the text, the full account after it', (tester) async {
      await openLitterGuide(tester);

      expect(headerTitle('Guide'), findsOneWidget);
      expect(find.text('Home and cleaning'), findsOneWidget);
      expect(find.textContaining('min read · For cats'), findsOneWidget);
      // One line under the title, before the guide's first words.
      final byline = find.byKey(const Key('guide-byline'));
      expect(reads('$attribution · Not reviewed by a veterinarian'), findsOneWidget);
      final intro = find.textContaining('The usual guideline is simple');
      expect(tester.getBottomLeft(byline).dy, lessThan(tester.getTopLeft(intro).dy));

      final about = find.byKey(const Key('about-guide'));
      await scrollOnTop(tester, about);
      Finder inAbout(String text) => find.descendant(of: about, matching: find.text(text));
      expect(inAbout('About this guide'), findsOneWidget);
      expect(inAbout('Written by'), findsOneWidget);
      expect(inAbout('PetLoop team'), findsOneWidget);
      expect(inAbout(authorRole), findsOneWidget);
      expect(inAbout('Professional review'), findsOneWidget);
      expect(inAbout('Not reviewed by a veterinarian'), findsOneWidget);
      expect(inAbout('Last updated'), findsOneWidget);
      expect(inAbout('30.09.26'), findsOneWidget);
      expect(inAbout('Sources'), findsOneWidget);
      expect(inAbout('None cited'), findsOneWidget);
      expect(inAbout('General, widely accepted pet-care guidance.'), findsOneWidget);

      // Nothing suggests a review.
      expect(find.byKey(const Key('guide-review')), findsNothing);
      expect(find.text('Reviewed by'), findsNothing);
      expect(tag('Reviewed'), findsNothing);
      expect(tag('English only'), findsNothing);

      // The box comes after the guide's text (its last part is just above
      // as the box comes into view), above the closing note.
      final lastSection = find.text('When a cat stops using the box');
      expect(lastSection, findsOneWidget);
      expect(tester.getTopLeft(about).dy, greaterThan(tester.getBottomLeft(lastSection).dy));
      await scrollOnTop(tester, find.text(guideDisclaimer));
      expect(tester.getBottomLeft(about).dy, lessThan(tester.getTopLeft(find.text(guideDisclaimer)).dy));
    });

    testWidgets('the closing note stays, with the way to a professional', (tester) async {
      await openLitterGuide(tester);

      await tester.scrollUntilVisible(find.text(guideDisclaimer), 300);
      final contact = find.text(contactProfessionalLabel);
      await tester.scrollUntilVisible(contact, 200);
      await tester.tap(contact);
      await settleHealth(tester);
      expect(find.text('Emergency · Mitzi'), findsOneWidget);
    });

    testWidgets('no guide in the library is shown as reviewed', (tester) async {
      await pumpCommunity(tester);
      await openSection(tester, 'Guides');
      await chooseScope(tester, 'everything');

      // All 18 cards, from the first to the last.
      expect(find.text("Your puppy's first week at home"), findsOneWidget);
      final last = find.text('Keeping an older dog comfortable');
      for (var i = 0; i < 40 && last.evaluate().isEmpty; i++) {
        expect(tag('Reviewed'), findsNothing);
        expect(find.text(attribution), findsWidgets);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(last, findsOneWidget);
      expect(tag('Reviewed'), findsNothing);
      expect(find.text('Reviewed by'), findsNothing);
    });

    testWidgets('a recorded review shows name, role and date; a later text change removes it (fixtures)', (
      tester,
    ) async {
      final h = await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst, guides: reviewedGuides));
      await openSection(tester, 'Guides');

      // One card carries the tag: the guide whose text is older than its review.
      expect(find.text('Fixture: reviewed guide'), findsOneWidget);
      expect(find.text('Fixture: changed after review'), findsOneWidget);
      expect(tag('Reviewed'), findsOneWidget);

      await tapVisible(tester, find.text('Fixture: reviewed guide'));
      final review = find.byKey(const Key('guide-review'));
      expect(find.descendant(of: review, matching: find.text('Reviewed by')), findsOneWidget);
      expect(find.descendant(of: review, matching: find.text('Test Reviewer (fixture)')), findsOneWidget);
      expect(find.descendant(of: review, matching: find.text('Veterinarian · reviewed 05.10.26')), findsOneWidget);
      expect(find.text('Not reviewed by a veterinarian'), findsNothing);
      expect(find.text('01.10.26'), findsOneWidget); // last updated

      // Sources: listed by name; the linked one opens in the browser.
      expect(find.text('None cited'), findsNothing);
      expect(find.text('Fixture source without a link'), findsOneWidget);
      await tapVisible(tester, find.text('Fixture source with a link, Fixture Press'));
      expect(h.openedSources, [Uri.parse('https://example.com/fixture')]);
      await goBack(tester);

      // Same review on record, but the text changed four days later.
      await tapVisible(tester, find.text('Fixture: changed after review'));
      expect(find.byKey(const Key('guide-review')), findsNothing);
      expect(find.text('Test Reviewer (fixture)'), findsNothing);
      expect(find.text('Not reviewed by a veterinarian'), findsOneWidget);
      expect(find.text('09.10.26'), findsOneWidget);
    });
  });

  group('two languages', () {
    testWidgets('in Hebrew, a translated guide reads right to left and the others say "English only"', (
      tester,
    ) async {
      await pumpCommunity(
        tester,
        harness: CommunityHarness(pets: catFirst, guides: bilingualGuides, language: ContentLanguage.he),
      );
      await openSection(tester, 'Guides');
      await tapVisible(tester, find.byKey(const ValueKey('category-home')));

      // Three guides in this category: one has Hebrew text.
      expect(find.text(hebrewFixture.title), findsOneWidget);
      expect(find.text('How many litter boxes do you need?'), findsNothing);
      expect(find.text('Setting up the litter box'), findsOneWidget);
      expect(tag('English only'), findsNWidgets(2));
      expect(Directionality.of(tester.element(find.text(hebrewFixture.title))), TextDirection.rtl);
      expect(Directionality.of(tester.element(find.text('Setting up the litter box'))), TextDirection.ltr);
      // The Hebrew name is kept as one unit inside the English line.
      expect(reads('By מחבר לבדיקה · Updated 01.10.26'), findsOneWidget);

      await tapVisible(tester, find.text(hebrewFixture.title));
      expect(tag('English only'), findsNothing);
      expect(Directionality.of(tester.element(find.text(hebrewFixture.intro))), TextDirection.rtl);
      await scrollOnTop(tester, find.text('טקסט לבדיקה בלבד'));
      expect(find.text('טקסט לבדיקה בלבד'), findsOneWidget); // this text's own author line
      expect(find.text('01.10.26'), findsOneWidget); // and its own date
      await goBack(tester);

      await tapVisible(tester, find.text('Setting up the litter box'));
      expect(tag('English only'), findsOneWidget);
      expect(Directionality.of(tester.element(find.textContaining('Most cats take to a litter box'))), TextDirection.ltr);
    });

    testWidgets('in English nothing is tagged "English only"', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(pets: catFirst, guides: bilingualGuides));
      await openSection(tester, 'Guides');
      await tapVisible(tester, find.byKey(const ValueKey('category-home')));

      expect(find.text('How many litter boxes do you need?'), findsOneWidget);
      expect(find.text(hebrewFixture.title), findsNothing);
      expect(tag('English only'), findsNothing);
    });
  });
}
