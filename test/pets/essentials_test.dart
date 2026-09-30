import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/state/pet_completeness.dart' show kReminderSnooze;
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'pets_test_helpers.dart';

/// The reminder card of [petId] (and the dot), the way another tab would
/// place them.
Widget reminder(String petId, {bool compact = false}) => Padding(
  padding: const EdgeInsets.all(20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PetReminderCard(petId: petId, compact: compact, margin: const EdgeInsets.only(bottom: 12)),
      Align(
        alignment: Alignment.centerLeft,
        child: PetAttentionDot(petId: petId),
      ),
      Builder(
        builder: (context) =>
            TextButton(onPressed: () => showPetChecklist(context, petId), child: const Text('Open checklist')),
      ),
    ],
  ),
);

final dot = find.bySemanticsLabel('Essentials missing');

/// Kelly with one essential missing: her weight.
Future<PetsHarness> kellyWithoutWeight() async {
  final harness = PetsHarness();
  await harness.pets.savePet('demo', const Pet(id: kelly, name: 'Kelly', breed: 'Mix', ageYears: 13.6));
  return harness;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the reminder card', () {
    testWidgets('says what is missing and offers the next item', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      expect(find.text("Finish Soya's profile"), findsOneWidget);
      expect(find.text('5 of 5 essentials still to add'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, "Add the vet's phone"), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.bySemanticsLabel("Soya's profile: 5 of 5 essentials still to add"), findsOneWidget);
      expect(dot, findsOneWidget);
    });

    testWidgets('a complete pet costs no space at all, margin included', (tester) async {
      await pumpPetsHost(tester, reminder(kelly));
      expect(find.text("Finish Kelly's profile"), findsNothing);
      expect(tester.getSize(find.byType(PetReminderCard)).height, 0);
      expect(dot, findsNothing);
    });

    testWidgets('the compact size is one line with the same action', (tester) async {
      await pumpPetsHost(tester, reminder(soya, compact: true));
      expect(find.text("Add the vet's phone"), findsOneWidget);
      expect(find.text('5 of 5 essentials still to add'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text("Finish Soya's profile"), findsNothing);
      // One line: about 60 px of card plus the margin it was given.
      expect(tester.getSize(find.byType(PetReminderCard)).height, lessThanOrEqualTo(64 + 12));

      await tester.tap(find.text("Add the vet's phone"));
      await tester.pumpAndSettle();
      expect(find.text('Choose the regular vet'), findsOneWidget);
    });

    testWidgets('one tap opens the next missing item; then the one after it is offered', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text("Add the vet's phone"));
      await tester.pumpAndSettle();
      expect(find.text('Choose the regular vet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));

      expect(find.text('4 of 5 essentials still to add'), findsOneWidget);
      expect(find.text('Answer about allergies'), findsOneWidget);

      await tester.tap(find.text('Answer about allergies'));
      await tester.pumpAndSettle();
      expect(find.text("Soya's health profile"), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.byKey(const Key('profile-no-conditions')));
      await tapVisible(tester, find.text('Save profile'));

      expect(find.text('2 of 5 essentials still to add'), findsOneWidget);
      expect(find.text("Add Soya's age"), findsOneWidget);
    });

    testWidgets('the rest of the card opens the checklist', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text("Finish Soya's profile"));
      await tester.pumpAndSettle();
      expect(find.text("Soya's essentials"), findsOneWidget);
      expect(find.text('0 of 5 answered. "None known" counts.'), findsOneWidget);
    });

    testWidgets('"Not now" hides it for 7 days; the dot stays', (tester) async {
      final h = await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text("Finish Soya's profile"), findsNothing);
      expect(tester.getSize(find.byType(PetReminderCard)).height, 0);
      expect(find.text("We'll remind you again in a week"), findsOneWidget);
      expect(dot, findsOneWidget);

      final stored = h.pets.cachedPets('demo')!.firstWhere((p) => p.id == soya);
      expect(stored.reminderSnoozedUntil, petsNow.add(kReminderSnooze));
      expect(kReminderSnooze, const Duration(days: 7));

      // Six days on it is still hidden; after the seventh it is back.
      h.now = petsNow.add(const Duration(days: 6));
      appContainer(tester).invalidate(petCompletenessProvider(soya));
      await tester.pumpAndSettle();
      expect(find.text("Finish Soya's profile"), findsNothing);

      h.now = petsNow.add(const Duration(days: 7, minutes: 1));
      appContainer(tester).invalidate(petCompletenessProvider(soya));
      await tester.pumpAndSettle();
      expect(find.text("Finish Soya's profile"), findsOneWidget);
    });

    testWidgets('a "Not now" that cannot be saved says so and keeps the card', (tester) async {
      final h = await pumpPetsHost(tester, reminder(soya));
      h.pets.failure = 'Cannot reach the server. Check your connection and try again.';
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.text("Finish Soya's profile"), findsOneWidget);
    });

    testWidgets('after the last item it disappears, with one message', (tester) async {
      final harness = await kellyWithoutWeight();
      await pumpPetsHost(
        tester,
        Column(
          children: [
            reminder(kelly),
            PetReminderCard(petId: kelly, compact: true),
          ],
        ),
        harness: harness,
      );
      expect(find.text('1 of 5 essentials still to add'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(FilledButton, "Add Kelly's weight"));
      await tester.pumpAndSettle();
      expect(find.text("Kelly's weight"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '23');
      await tapVisible(tester, find.text('Save'));

      expect(find.text('1 of 5 essentials still to add'), findsNothing);
      expect(dot, findsNothing);
      // Two reminders were on screen; the message is said once.
      expect(find.text("Kelly's essentials are complete"), findsOneWidget);
    });

    testWidgets('while Health cannot be read there is no reminder and no dot', (tester) async {
      final harness = PetsHarness()..health.failing = true;
      await pumpPetsHost(tester, reminder(soya), harness: harness);
      expect(find.text("Finish Soya's profile"), findsNothing);
      expect(dot, findsNothing);
    });
  });

  group('the dot on the pet pills', () {
    testWidgets('marks Soya and not Kelly, with each pet\'s picture in its pill', (tester) async {
      await pumpPetsApp(tester);
      expect(dot, findsOneWidget);
      final soyaPill = tester.getRect(find.text('Soya'));
      final dotRect = tester.getRect(dot);
      expect(dotRect.left, greaterThan(soyaPill.left));
      // One picture in each pill, and the selected pet's in the hero.
      expect(find.byType(PetAvatar), findsNWidgets(3));
      // The dashboard still names each pet once in the pills.
      expect(find.text('Kelly'), findsNWidgets(2));
    });

    testWidgets('stays when the reminder is postponed, and goes when the pet is complete', (tester) async {
      final harness = await kellyWithoutWeight();
      await pumpPetsApp(tester, harness: harness);
      expect(dot, findsNWidgets(2));

      final container = appContainer(tester);
      final kellyPet = container.read(petsProvider).first;
      container.read(petsProvider.notifier).update(kellyPet.copyWith(weightKg: 23));
      await tester.pumpAndSettle();
      expect(dot, findsOneWidget);
    });

    testWidgets('stays up to date while the tabs are covered by another page', (tester) async {
      // A vet is added on Kelly's profile, which covers the tabs. Nothing on
      // that page is about Soya, yet Soya's dot depends on the owner's vets
      // too: when the tabs come back, a moment later, they must simply be
      // there (paused providers catching up mid-build used to fail here).
      await pumpPetsApp(tester);
      openPetProfile(tester.element(find.text('Feeding')), kelly);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Dr. Levi, Park Vet Clinic'));
      await tapVisible(tester, find.text('Add a new vet'));
      await typeInto(tester, find.byKey(const Key('vet-name')), 'Dr. Noa');
      await typeInto(tester, find.byKey(const Key('vet-phone')), '+972 3 555 0100');
      await tapVisible(tester, find.text('Save vet'));
      expect(find.text('Dr. Noa'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Feeding'), findsOneWidget);
      expect(dot, findsOneWidget);
    });
  });

  group('the checklist', () {
    testWidgets('lists the five essentials, each open one with "Add"', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();

      expect(find.text("Soya's essentials"), findsOneWidget);
      for (final label in ["A vet's phone number", 'Allergies', 'Medical conditions', 'Age', 'Weight']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('So Emergency can call'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsNWidgets(5));
      expect(find.text('Good to have'), findsOneWidget);
      for (final label in ['A real photo', 'Microchip', 'Emergency vet (24 h)', 'Breed', 'Sex and neutering']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Remind me in a week'), findsOneWidget);
    });

    testWidgets('an open row goes to its editor and comes back ticked', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('add-weight')));
      expect(find.text("Soya's weight"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Save'));

      expect(find.text('1 of 5 answered. "None known" counts.'), findsOneWidget);
      expect(find.text('18 kg'), findsOneWidget);
      expect(find.byKey(const Key('answered-weight')), findsOneWidget);

      // An answered row opens the same editor, to change the answer.
      await tapVisible(tester, find.byKey(const Key('answered-weight')));
      expect(find.text("Soya's weight"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '19.5');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('19.5 kg'), findsOneWidget);
    });

    testWidgets('a complete pet has everything ticked and nothing to postpone', (tester) async {
      await pumpPetsHost(tester, reminder(kelly));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
      expect(find.text('All 5 answered. Thank you!'), findsOneWidget);
      expect(find.text('Remind me in a week'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);
      expect(find.text('Dr. Levi, Park Vet Clinic · +972 3 555 0142'), findsOneWidget);
      expect(find.text('Chicken (skin reaction)'), findsOneWidget);
      expect(find.text('13.6 years'), findsOneWidget);
      expect(find.text('23 kg'), findsOneWidget);
      expect(find.byTooltip('Breed: answered'), findsOneWidget);
      expect(find.byTooltip('Microchip: answered'), findsOneWidget);
      expect(find.byTooltip('Emergency vet (24 h): answered'), findsOneWidget);
    });

    testWidgets('"good to have" items are one tap away too, and never produce a reminder', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Breed: not added yet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('good-breed')));
      expect(find.text("Soya's breed"), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilterChip, 'Mixed or not sure'));
      await tapVisible(tester, find.text('Save'));
      expect(find.byTooltip('Breed: answered'), findsOneWidget);
      expect(petNamed(tester, 'Soya').breed, 'Mixed');

      await tapVisible(tester, find.byKey(const Key('good-sexAndNeutering')));
      expect(find.text('Sex and neutering'), findsNWidgets(2));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Female'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Yes'));
      await tapVisible(tester, find.text('Save'));
      expect(petNamed(tester, 'Soya').sex, PetSex.female);
      expect(petNamed(tester, 'Soya').neutered, Neutered.yes);
      expect(find.byTooltip('Sex and neutering: answered'), findsOneWidget);
    });

    testWidgets('"A real photo" opens the picture sheet and saves the photo', (tester) async {
      final h = await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('good-photo')));
      expect(find.text("Soya's picture"), findsOneWidget);
      await tapVisible(tester, find.text('Choose from your photos'));

      final pet = petNamed(tester, 'Soya');
      expect(pet.photoPath, startsWith('demo/soya/'));
      expect(h.pets.photos.keys, [pet.photoPath]);
      expect(find.byTooltip('A real photo: answered'), findsOneWidget);
    });

    testWidgets('"Remind me in a week" closes the sheet and postpones the reminder', (tester) async {
      await pumpPetsHost(tester, reminder(soya));
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Remind me in a week'));

      expect(find.text("Soya's essentials"), findsNothing);
      expect(find.text("Finish Soya's profile"), findsNothing);
      expect(dot, findsOneWidget);

      // Opened again, it says until when instead of offering to postpone.
      await tester.tap(find.text('Open checklist'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me in a week'), findsNothing);
      expect(find.text("The reminder is hidden until 17.06.25. The dot on Soya's name stays."), findsOneWidget);
    });
  });
}
