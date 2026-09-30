import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/profile/remove_pet.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'pets_test_helpers.dart';

/// Opens the profile of the pet called [name] from its pill on Home.
Future<void> openProfile(WidgetTester tester, String name) async {
  await tester.longPress(find.text(name).first);
  await tester.pumpAndSettle();
}

/// Waits until the message at the bottom of the screen has gone.
Future<void> letSnackBarPass(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Opens the "Remove …?" dialog from the end of the profile.
Future<void> openRemoveDialog(WidgetTester tester, String name) async {
  await tapVisible(tester, find.text('Archive $name'));
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the pet profile', () {
    testWidgets('a long press on a pet pill opens it, with everything on one page', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      expect(find.text('Home'), findsNothing); // full screen: no bottom bar
      expect(find.text('Change picture'), findsOneWidget);
      expect(find.text('My pets'), findsOneWidget);
      expect(find.text('5 of 5 essentials still to add'), findsOneWidget);
      expect(
        find.text("A vet's phone number · Allergies · Medical conditions · Age · Weight"),
        findsOneWidget,
      );
      for (final label in ['Basics', 'Birthday or age', 'Weight', 'Sex', 'Neutered or spayed', 'Breed', 'Vet']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Health basics'), findsOneWidget);
      expect(find.text('Not answered yet'), findsNWidgets(2));
      expect(find.text('Not added'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Archive Soya'), findsOneWidget);
      expect(find.text('Delete Soya'), findsOneWidget);
    });

    testWidgets('a complete pet shows its answers and no essentials card', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');

      expect(find.text('Dog · Mix · 13.6 years'), findsOneWidget);
      expect(find.textContaining('essentials still to add'), findsNothing);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text('City Animal Hospital'), findsOneWidget);
      expect(find.text('Chicken (skin reaction)'), findsOneWidget);
      expect(find.text('Arthritis in the hips'), findsOneWidget);
      expect(find.text('985 112 004 567 321'), findsOneWidget);
    });

    testWidgets('"Save changes" stores the basics', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      await typeInto(tester, find.byKey(const Key('pet-name')), 'Soya Bean');
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '3');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Female'));
      await typeInto(tester, find.byKey(const Key('pet-breed')), 'Labrador');
      await tapVisible(tester, find.text('Save changes'));

      expect(find.text('Changes saved'), findsOneWidget);
      final pet = petNamed(tester, 'Soya Bean');
      expect(pet.id, soya);
      expect(pet.weightKg, 18);
      expect(pet.ageLabelAt(petsNow), 'About 3 years');
      expect(pet.sex, PetSex.female);
      expect(pet.breed, 'Labrador');
      expect(h.pets.cachedPets('demo')!.last.name, 'Soya Bean');
      // Three essentials are still Health's to answer.
      expect(find.text('3 of 5 essentials still to add'), findsOneWidget);
    });

    testWidgets('saving something else leaves an untouched age exactly as it was', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await typeInto(tester, find.byKey(const Key('pet-breed')), 'Canaan mix');
      await tapVisible(tester, find.text('Save changes'));

      final pet = petNamed(tester, 'Kelly');
      expect(pet.breed, 'Canaan mix');
      expect(pet.ageYears, 13.6);
      expect(pet.weightKg, 23);
      expect(pet.photoAsset, 'assets/images/kelly.png');
    });

    testWidgets('the kind can be changed, and a bird is then weighed in grams', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('pet-kind')));
      await tester.tap(find.text('Bird').last);
      await tester.pumpAndSettle();
      await typeInto(tester, find.byKey(const Key('pet-weight')), '35');
      await tapVisible(tester, find.text('Save changes'));

      final pet = petNamed(tester, 'Soya');
      expect(pet.species, PetSpecies.bird);
      expect(pet.weightKg, closeTo(0.035, 1e-9));
    });

    testWidgets('an answer given from the checklist is not lost when the profile is saved afterwards', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      // The weight is added through the checklist while the profile, whose
      // own weight field is still empty, stays open underneath.
      await tapVisible(tester, find.byKey(const Key('profile-essentials-add')));
      await tapVisible(tester, find.byKey(const Key('add-weight')));
      await typeInto(tester, find.byKey(const Key('pet-weight')).last, '18');
      await tapVisible(tester, find.text('Save'));
      Navigator.of(tester.element(find.text("Soya's essentials"))).pop();
      await tester.pumpAndSettle();

      // The profile follows: its field now shows the weight.
      final field = tester.widget<TextFormField>(find.byKey(const Key('pet-weight')));
      expect(field.controller!.text, '18');

      await typeInto(tester, find.byKey(const Key('pet-name')), 'Soya Bean');
      await tapVisible(tester, find.text('Save changes'));
      final pet = petNamed(tester, 'Soya Bean');
      expect(pet.weightKg, 18);
    });

    testWidgets('a pet cannot lose its name', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await typeInto(tester, find.byKey(const Key('pet-name')), '  ');
      await tapVisible(tester, find.text('Save changes'));
      expect(find.text('A pet needs a name.'), findsOneWidget);
      expect(petNamed(tester, 'Soya').name, 'Soya');
    });

    testWidgets('a save that fails says why', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      h.pets.failure = 'Could not save your pet. Please try again.';
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Save changes'));
      expect(find.text('Could not save your pet. Please try again.'), findsOneWidget);
      expect(petNamed(tester, 'Soya').weightKg, isNull);
    });

    testWidgets('"Change picture" saves the new picture at once', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.text('Change picture'));
      await tapVisible(tester, find.text('Pick an icon'));
      await tapVisible(tester, find.byKey(const Key('icon-dog_pointy')));
      await tapVisible(tester, find.byKey(const Key('icon-bg-sage')));
      await tapVisible(tester, find.text('Use this icon'));
      expect(petNamed(tester, 'Soya').iconKey, 'dog_pointy:sage');

      // A photo replaces the icon; removing it goes back to the default.
      await tapVisible(tester, find.text('Change picture'));
      await tapVisible(tester, find.text('Take a photo'));
      final withPhoto = petNamed(tester, 'Soya');
      expect(withPhoto.photoPath, startsWith('demo/soya/'));
      expect(withPhoto.iconKey, isNull);

      await tapVisible(tester, find.text('Change picture'));
      await tapVisible(tester, find.text('Remove picture'));
      expect(petNamed(tester, 'Soya').hasPhoto, isFalse);
      // The replaced photo does not stay behind in storage.
      expect(h.pets.photos, isEmpty);
    });

    testWidgets("Kelly's bundled photo can be swapped for an icon", (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await tapVisible(tester, find.text('Change picture'));
      expect(find.text('Remove picture'), findsOneWidget);
      await tapVisible(tester, find.text('Remove picture'));
      final pet = petNamed(tester, 'Kelly');
      expect(pet.photoAsset, isNull);
      expect(pet.hasPhoto, isFalse);
    });

    testWidgets('the essentials card opens the checklist', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('profile-essentials-add')));
      expect(find.text("Soya's essentials"), findsOneWidget);
    });

    testWidgets("the vet and the health basics are Health's own pieces", (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      await tapVisible(tester, find.text('Add a vet'));
      expect(find.text('Choose the regular vet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
      expect(find.text('4 of 5 essentials still to add'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('health-allergies')));
      expect(find.text("Soya's health profile"), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.text('Save profile'));
      expect(find.text('None known'), findsOneWidget);
      expect(find.text('3 of 5 essentials still to add'), findsOneWidget);
    });

    testWidgets('it opens from a page shown on its own too', (tester) async {
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openPetProfile(context, soya),
            child: const Text('Profile'),
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Change picture'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('My pets', () {
    testWidgets('shows every pet with what is missing, and leads to the profile and back', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await tester.tap(find.text('My pets'));
      await tester.pumpAndSettle();

      expect(find.text('Dog · Mix · 13.6 years'), findsOneWidget);
      expect(find.text('Complete'), findsOneWidget);
      expect(find.text('5 essentials to add'), findsOneWidget);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('my-pet-soya')));
      expect(find.text('Archive Soya'), findsOneWidget);
      // "My pets" on a profile opened from My pets goes back to it.
      await tester.tap(find.text('My pets'));
      await tester.pumpAndSettle();
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Archive Soya'), findsNothing);
    });

    testWidgets('"Add a pet" opens the flow', (tester) async {
      await pumpPetsApp(tester);
      openMyPets(tester.element(find.text('Feeding')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Add a pet'));
      expect(find.text('Who is joining the family?'), findsOneWidget);

      await createPet(tester, name: 'Pip', kind: PetSpecies.cat);
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();
      expect(find.text('My pets'), findsOneWidget);
      expect(find.text('Pip'), findsOneWidget);
      expect(find.text('Cat'), findsOneWidget);
    });

    testWidgets('one missing essential is written in the singular', (tester) async {
      final harness = PetsHarness();
      await harness.pets.savePet('demo', const Pet(id: kelly, name: 'Kelly', ageYears: 13.6));
      await pumpPetsApp(tester, harness: harness);
      openMyPets(tester.element(find.text('Feeding')));
      await tester.pumpAndSettle();
      expect(find.text('1 essential to add'), findsOneWidget);
    });
  });

  group('archive and delete', () {
    testWidgets('both buttons open the same clear choice, and "Cancel" changes nothing', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.text('Delete Soya'));

      expect(find.text('Remove Soya?'), findsOneWidget);
      expect(find.text('Suggested'), findsOneWidget);
      expect(
        find.text('Soya is hidden from the app. Everything is kept, and you can bring Soya back from My pets.'),
        findsOneWidget,
      );
      expect(find.text('Delete for good'), findsOneWidget);
      expect(
        find.text(
          "Erases Soya's profile, picture, health records, reminders and documents. This cannot be undone.",
        ),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Cancel'));
      expect(find.text('Remove Soya?'), findsNothing);
      expect(currentPets(tester).length, 2);
    });

    testWidgets('archiving hides the pet everywhere and keeps it for "Restore"', (tester) async {
      final h = await pumpPetsApp(tester);
      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      await openProfile(tester, 'Soya');
      await openRemoveDialog(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('remove-archive')));

      // Back on the dashboard, now Kelly's: Soya was the selected pet.
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Soya'), findsNothing);
      expect(find.text('Kelly'), findsNWidgets(2));
      expect(find.text('Soya is archived. You can bring Soya back from My pets.'), findsOneWidget);
      expect([for (final p in currentPets(tester)) p.id], [kelly]);
      final stored = h.pets.cachedPets('demo')!.last;
      expect(stored.id, soya);
      expect(stored.archivedAt, petsNow);

      openMyPets(tester.element(find.text('Feeding')));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Dog · archived 10.06.25'), findsOneWidget);
      expect(
        find.text('Archived pets keep all their records and are hidden from the rest of the app.'),
        findsOneWidget,
      );

      await tapVisible(tester, find.byKey(const Key('restore-soya')));
      expect(find.text('Soya is back'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);
      expect([for (final p in currentPets(tester)) p.id], [kelly, soya]);
    });

    testWidgets('deleting erases the pet, its picture and asks Health to clean up', (tester) async {
      final cleaned = <String>[];
      final harness = PetsHarness(
        extra: [petHealthCleanupProvider.overrideWithValue((petId) async => cleaned.add(petId))],
      );
      await harness.pets.uploadPhoto('demo', soya, testPhoto);
      await pumpPetsApp(tester, harness: harness);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.text('Delete Soya'));
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Soya was deleted'), findsOneWidget);
      expect(cleaned, [soya]);
      expect([for (final p in harness.pets.cachedPets('demo')!) p.id], [kelly]);
      expect(harness.pets.photos, isEmpty);
      expect(appContainer(tester).read(archivedPetsProvider), isEmpty);
    });

    testWidgets('a delete that fails keeps the pet and says why', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      h.pets.failure = 'Cannot reach the server. Check your connection and try again.';
      await tapVisible(tester, find.text('Delete Soya'));
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.text('Archive Soya'), findsOneWidget);
      expect(currentPets(tester).length, 2);
    });

    testWidgets('when Health cannot clean up, the pet is not deleted', (tester) async {
      final harness = PetsHarness(
        extra: [
          petHealthCleanupProvider.overrideWithValue(
            (petId) async => throw const PetsException("Could not remove Soya's documents. Please try again."),
          ),
        ],
      );
      await pumpPetsApp(tester, harness: harness);
      await openProfile(tester, 'Soya');
      await tapVisible(tester, find.text('Delete Soya'));
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text("Could not remove Soya's documents. Please try again."), findsOneWidget);
      expect(currentPets(tester).length, 2);
    });

    testWidgets('the last pet cannot be archived; deleting it leads back to the welcome', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();
      await openProfile(tester, 'Milo');
      await openRemoveDialog(tester, 'Milo');

      expect(find.text('Suggested'), findsNothing);
      expect(find.textContaining('Milo is your only pet'), findsOneWidget);
      final archive = find.descendant(
        of: find.byKey(const Key('remove-archive')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(archive).onPressed, isNull);

      await tapVisible(tester, find.byKey(const Key('remove-delete')));
      expect(find.text('Welcome, Limor'), findsOneWidget);
      expect(find.text('Add my first pet'), findsOneWidget);
      expect(currentPets(tester), isEmpty);
    });

    testWidgets('with only archived pets left, the welcome offers to bring one back', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await openRemoveDialog(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('remove-archive')));
      await letSnackBarPass(tester);
      await openProfile(tester, 'Kelly');
      await tapVisible(tester, find.text('Delete Kelly'));
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Welcome, Alex'), findsOneWidget);
      expect(find.text('Archived pets'), findsOneWidget);
      await tapVisible(tester, find.text('Restore'));
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Soya'), findsNWidgets(2));
    });
  });
}
