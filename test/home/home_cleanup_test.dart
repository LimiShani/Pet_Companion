import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/home/widgets/pet_hero.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../pets/pets_test_helpers.dart';

// Home after the clean-up, on the demo account: Kelly has everything, Soya
// is new (no breed, age or weight, no vet, nothing planned). Each check runs
// in English and in Hebrew (right to left), on a regular and a small phone.
// An overflow anywhere fails the test by itself.

const wide = Size(390, 844);
const small = Size(320, 568);

/// The demo account, minus [denied] capabilities.
PetsHarness harnessFor(AppLanguage language, {List<String> denied = const []}) {
  final access = FakeAccessRepository();
  for (final capability in denied) {
    access.groups['standard']!.remove(capability);
  }
  return PetsHarness(language: language, extra: [accessRepositoryProvider.overrideWithValue(access)]);
}

/// Scrolls [finder] to the middle of the screen (clear of the pinned top
/// bar) and taps it.
Future<void> tapInMiddle(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Closes the sheet or page that shows [finder].
Future<void> closeOver(WidgetTester tester, Finder finder) async {
  Navigator.of(tester.element(finder)).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final language in AppLanguage.values) {
    final hebrew = language == AppLanguage.hebrew;
    final locale = hebrew ? hebrewLocale : englishLocale;
    final app = lookupAppL10n(locale);
    final pets = lookupPetsL10n(locale);
    final health = lookupHealthL10n(locale);
    final lang = hebrew ? 'Hebrew' : 'English';

    for (final size in [wide, small]) {
      final width = size.width.toInt();

      testWidgets('hero: Soya\'s missing details are "Add" pills that open their sheets ($lang, $width px)', (
        tester,
      ) async {
        await pumpPetsApp(tester, harness: harnessFor(language), size: size);

        // Kelly has everything: values, no "Add".
        for (final item in [PetInfoItem.breed, PetInfoItem.age, PetInfoItem.weight]) {
          expect(find.byKey(PetHero.addKey(item)), findsNothing);
        }
        expect(find.text('Mix'), findsOneWidget);
        final filled = tester.getSize(find.ancestor(of: find.text('Mix'), matching: find.byType(Container)).first);

        await tester.tap(find.text('Soya'));
        await tester.pumpAndSettle();
        expect(find.text('—'), findsNothing);

        final sheets = {
          PetInfoItem.breed: (pets.actionBreed('Soya'), pets.petBreedTitle('Soya')),
          PetInfoItem.age: (pets.actionAge('Soya'), pets.petAgeTitle('Soya')),
          PetInfoItem.weight: (pets.actionWeight('Soya'), pets.petWeightTitle('Soya')),
        };
        for (final MapEntry(key: item, value: (semantics, title)) in sheets.entries) {
          final pill = find.byKey(PetHero.addKey(item));
          expect(pill, findsOneWidget);
          expect(find.descendant(of: pill, matching: find.text(app.commonAdd)), findsOneWidget);
          expect(find.bySemanticsLabel(semantics), findsOneWidget);
          // The same size as a filled pill, with a 44 px tap area.
          final drawn = tester.getSize(find.descendant(of: pill, matching: find.byType(Ink)));
          expect(drawn.height, filled.height);
          expect(tester.getSize(pill).height, greaterThanOrEqualTo(44));

          await tester.tap(pill);
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget, reason: '$item opens its sheet');
          await closeOver(tester, find.text(title));
        }
      });
    }

    testWidgets('hero: without "pets.edit" a missing detail stays "—" ($lang)', (tester) async {
      await pumpPetsApp(tester, harness: harnessFor(language, denied: ['pets.edit']), size: small);
      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      expect(find.text('—'), findsNWidgets(3));
      for (final item in [PetInfoItem.breed, PetInfoItem.age, PetInfoItem.weight]) {
        expect(find.byKey(PetHero.addKey(item)), findsNothing);
      }
      expect(find.descendant(of: find.byType(PetHero), matching: find.text(app.commonAdd)), findsNothing);
    });

    testWidgets('profile reminder on Home: one "Add" pill, no "Not now"; the row opens the checklist ($lang, 320 px)', (
      tester,
    ) async {
      await pumpPetsApp(tester, harness: harnessFor(language), size: small);
      expect(find.byKey(PetReminderCard.addKey), findsNothing); // Kelly is complete

      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      expect(find.text(pets.finishProfile('Soya')), findsOneWidget);
      expect(find.text(pets.essentialsStillToAdd(5, 5)), findsOneWidget);
      expect(find.text(pets.notNow), findsNothing);
      final add = find.byKey(PetReminderCard.addKey);
      expect(find.descendant(of: add, matching: find.text(app.commonAdd)), findsOneWidget);
      expect(find.bySemanticsLabel(pets.actionVetPhone), findsOneWidget);
      // The pill ends the row: on the left in Hebrew.
      final center = tester.getCenter(add).dx;
      expect(hebrew ? center < small.width / 2 : center > small.width / 2, isTrue);

      // The pill opens the next missing item: the vet.
      await tapInMiddle(tester, add);
      expect(find.text(health.chooseRegularVet), findsOneWidget);
      await closeOver(tester, find.text(health.chooseRegularVet));

      // The row opens the checklist, where "Remind me in a week" is.
      await tapInMiddle(tester, find.text(pets.finishProfile('Soya')));
      expect(find.text(pets.checklistTitle('Soya')), findsOneWidget);
      expect(find.text(pets.remindInAWeek), findsOneWidget);
    });

    testWidgets('Health card: no vet saved asks for one and opens the vet picker ($lang, 320 px)', (tester) async {
      await pumpPetsApp(tester, harness: harnessFor(language), size: small);
      // Kelly has a vet and things coming up.
      expect(find.text(health.homeNoVet), findsNothing);

      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      expect(find.text(health.homeNoVet), findsOneWidget);
      expect(find.text(app.homeNoHealthEvents), findsNothing);

      await tapInMiddle(tester, find.text(health.homeNoVet));
      expect(find.text(health.chooseRegularVet), findsOneWidget);
    });

    testWidgets('Health card: an account that may not add a vet keeps "No health events yet" ($lang)', (tester) async {
      await pumpPetsApp(tester, harness: harnessFor(language, denied: ['health.emergency.edit']), size: small);
      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      expect(find.text(app.homeNoHealthEvents), findsOneWidget);
      expect(find.text(health.homeNoVet), findsNothing);
    });
  }
}
