import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/profile/name_and_kind_sheet.dart';
import 'package:pet_companion/features/pets/profile/pet_profile_screen.dart';
import 'package:pet_companion/features/pets/profile/remove_pet.dart';
import 'package:pet_companion/presentation/pets_widgets.dart' show PetsTag;
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

/// Opens the profile's "More" menu and picks [entry] (archive or delete).
Future<void> openMenuEntry(WidgetTester tester, Key entry) async {
  await tester.tap(find.byKey(PetProfileScreen.moreKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(entry));
  await tester.pumpAndSettle();
}

/// Opens the "Remove …?" dialog through "Archive …" in the "More" menu.
Future<void> openRemoveDialog(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(PetProfileScreen.moreKey));
  await tester.pumpAndSettle();
  expect(find.text('Archive $name'), findsOneWidget);
  await tester.tap(find.byKey(PetProfileScreen.archiveKey));
  await tester.pumpAndSettle();
}

/// The text [text] in the profile row called [name].
Finder rowText(String name, String text) =>
    find.descendant(of: find.byKey(PetProfileScreen.rowKey(name)), matching: find.text(text));

/// Opens the profile row called [name].
Future<void> openRow(WidgetTester tester, String name) =>
    tapVisible(tester, find.byKey(PetProfileScreen.rowKey(name)));

/// The phone's back button.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the pet profile', () {
    testWidgets('a long press on a pet pill opens an overview: rows, no form, nothing to save', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      expect(find.text('Home'), findsNothing); // full screen: no bottom bar
      expect(find.byKey(PetProfileScreen.pictureKey), findsOneWidget);
      expect(find.byKey(PetProfileScreen.moreKey), findsOneWidget);
      expect(find.byTooltip('More'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget); // the summary line
      for (final label in ['BASICS', 'VET AND HEALTH', 'MORE']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final row in ['name', 'age', 'weight', 'breed', 'sex', 'vets', 'health', 'documents']) {
        expect(find.byKey(PetProfileScreen.rowKey(row)), findsOneWidget, reason: row);
      }
      expect(rowText('name', 'Soya · Dog'), findsOneWidget);
      // A missing answer reads "Add": four basics and the health profile.
      for (final row in ['age', 'weight', 'breed', 'sex', 'health']) {
        expect(rowText(row, 'Add'), findsOneWidget, reason: row);
      }
      expect(rowText('vets', 'Add the vet'), findsOneWidget);
      // One nag only, on Home: no essentials card here, no form, no Save.
      expect(find.textContaining('essentials still to add'), findsNothing);
      expect(find.byKey(const Key('profile-essentials-add')), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Save changes'), findsNothing);
      expect(find.text('Change picture'), findsNothing);
      expect(find.text('My pets'), findsNothing);
      expect(find.text('Archive Soya'), findsNothing);
      expect(find.text('Delete Soya'), findsNothing);
    });

    testWidgets('a complete pet shows its answers on the rows', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');

      expect(find.text('Dog · Mix · female, spayed'), findsOneWidget);
      expect(rowText('name', 'Kelly · Dog'), findsOneWidget);
      expect(rowText('age', '13.6 years'), findsOneWidget);
      expect(rowText('weight', '23 kg'), findsOneWidget);
      expect(rowText('breed', 'Mix'), findsOneWidget);
      expect(rowText('sex', 'Female · spayed'), findsOneWidget);
      expect(rowText('vets', 'Dr. Levi, Park Vet Clinic · emergency: City Animal Hospital'), findsOneWidget);
      expect(rowText('health', 'Allergy: Chicken (skin reaction) · Arthritis in the hips · Chipped'), findsOneWidget);
      expect(rowText('documents', '4'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
    });

    testWidgets('each basics row opens its own sheet, which saves on its own', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      await openRow(tester, 'age');
      expect(find.text("Soya's age"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '3');
      await tapVisible(tester, find.text('Save'));
      expect(find.text("Soya's age"), findsNothing);
      expect(rowText('age', 'about 3 years'), findsOneWidget);

      await openRow(tester, 'weight');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Save'));
      expect(rowText('weight', '18 kg'), findsOneWidget);

      await openRow(tester, 'breed');
      await typeInto(tester, find.byKey(const Key('pet-breed')), 'Labrador');
      await tapVisible(tester, find.text('Save'));
      expect(rowText('breed', 'Labrador'), findsOneWidget);

      await openRow(tester, 'sex');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Female'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'No'));
      await tapVisible(tester, find.text('Save'));
      expect(rowText('sex', 'Female · not spayed'), findsOneWidget);
      expect(find.text('Dog · Labrador · female, not spayed'), findsOneWidget);

      final pet = petNamed(tester, 'Soya');
      expect(pet.weightKg, 18);
      expect(pet.ageLabelAt(petsNow), 'About 3 years');
      expect(pet.sex, PetSex.female);
      expect(pet.neutered, Neutered.no);
      expect(pet.breed, 'Labrador');
      expect(h.pets.cachedPets('demo')!.last.breed, 'Labrador');
      expect(find.text('Changes saved'), findsNothing);
    });

    testWidgets('saving one row leaves an untouched age exactly as it was', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await openRow(tester, 'breed');
      await typeInto(tester, find.byKey(const Key('pet-breed')), 'Canaan mix');
      await tapVisible(tester, find.text('Save'));

      final pet = petNamed(tester, 'Kelly');
      expect(pet.breed, 'Canaan mix');
      expect(pet.ageYears, 13.6);
      expect(pet.weightKg, 23);
      expect(pet.photoAsset, 'assets/images/kelly.png');
    });

    testWidgets('"Name and kind" saves a new name and kind, and a bird is then weighed in grams', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      await openRow(tester, 'name');
      expect(find.byKey(PetNameAndKindSheet.sheetKey), findsOneWidget);
      expect(find.text('Name and kind'), findsNWidgets(2)); // the row and the sheet's title
      final field = tester.widget<TextFormField>(find.byKey(const Key('pet-name')));
      expect(field.controller!.text, 'Soya');
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Soya Bean');
      await tapVisible(tester, find.byKey(const Key('kind-bird')));
      await tapVisible(tester, find.text('Save'));

      expect(find.byKey(PetNameAndKindSheet.sheetKey), findsNothing);
      final pet = petNamed(tester, 'Soya Bean');
      expect(pet.id, soya);
      expect(pet.species, PetSpecies.bird);
      expect(rowText('name', 'Soya Bean · Bird'), findsOneWidget);

      await openRow(tester, 'weight');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '35');
      await tapVisible(tester, find.text('Save'));
      expect(petNamed(tester, 'Soya Bean').weightKg, closeTo(0.035, 1e-9));
      expect(rowText('weight', '35 g'), findsOneWidget);
    });

    testWidgets('"Name and kind" asks before dropping a change, and a pet cannot lose its name', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      final sheet = find.byKey(PetNameAndKindSheet.sheetKey);
      final dialog = find.text('Discard changes?');

      // Nothing changed: back closes the sheet at once.
      await openRow(tester, 'name');
      await pressBack(tester);
      expect(dialog, findsNothing);
      expect(sheet, findsNothing);
      expect(find.byKey(PetProfileScreen.moreKey), findsOneWidget);

      // A new kind: back asks; "Keep editing" stays with the change.
      await openRow(tester, 'name');
      await tapVisible(tester, find.byKey(const Key('kind-cat')));
      await pressBack(tester);
      expect(dialog, findsOneWidget);
      await tapVisible(tester, find.text('Keep editing'));
      expect(sheet, findsOneWidget);

      // A typed name: a tap outside the sheet asks too; "Discard" closes it.
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Soya Bean');
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(dialog, findsOneWidget);
      await tapVisible(tester, find.text('Discard'));
      expect(sheet, findsNothing);
      expect(petNamed(tester, 'Soya').species, PetSpecies.dog);

      // An empty name is not saved.
      await openRow(tester, 'name');
      await typeInto(tester, find.byKey(const Key('pet-name')), '  ');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('A pet needs a name.'), findsOneWidget);
      expect(petNamed(tester, 'Soya').name, 'Soya');
    });

    testWidgets('a save that fails says why and keeps the sheet', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      h.pets.failure = 'Could not save your pet. Please try again.';
      await openRow(tester, 'weight');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('Could not save your pet. Please try again.'), findsOneWidget);
      expect(find.text("Soya's weight"), findsOneWidget);
      expect(petNamed(tester, 'Soya').weightKg, isNull);
    });

    testWidgets('the picture is the one button of the header block and saves at once', (tester) async {
      final h = await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      final picture = find.byKey(PetProfileScreen.pictureKey);
      expect(find.bySemanticsLabel('Change picture'), findsOneWidget);
      expect(tester.getSize(picture), const Size(88, 88));

      await tapVisible(tester, picture);
      await tapVisible(tester, find.text('Pick an icon'));
      await tapVisible(tester, find.byKey(const Key('icon-dog_pointy')));
      await tapVisible(tester, find.byKey(const Key('icon-bg-sage')));
      await tapVisible(tester, find.text('Use this icon'));
      expect(petNamed(tester, 'Soya').iconKey, 'dog_pointy:sage');

      // A photo replaces the icon; removing it goes back to the default.
      await tapVisible(tester, picture);
      await tapVisible(tester, find.text('Take a photo'));
      final withPhoto = petNamed(tester, 'Soya');
      expect(withPhoto.photoPath, startsWith('demo/soya/'));
      expect(withPhoto.iconKey, isNull);

      await tapVisible(tester, picture);
      await tapVisible(tester, find.text('Remove picture'));
      expect(petNamed(tester, 'Soya').hasPhoto, isFalse);
      // The replaced photo does not stay behind in storage.
      expect(h.pets.photos, isEmpty);
    });

    testWidgets("Kelly's bundled photo can be swapped for an icon", (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await tapVisible(tester, find.byKey(PetProfileScreen.pictureKey));
      expect(find.text('Remove picture'), findsOneWidget);
      await tapVisible(tester, find.text('Remove picture'));
      final pet = petNamed(tester, 'Kelly');
      expect(pet.photoAsset, isNull);
      expect(pet.hasPhoto, isFalse);
    });

    testWidgets("the vets and the health profile rows open Health's own pages", (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');

      // No vet yet: the row picks one.
      await openRow(tester, 'vets');
      expect(find.text('Choose the regular vet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
      expect(rowText('vets', 'Dr. Levi, Park Vet Clinic'), findsOneWidget);

      // With a vet, it opens the pet's vets.
      await openRow(tester, 'vets');
      expect(find.text("Soya's vets"), findsOneWidget);
      await tester.tap(find.byTooltip('Back').last);
      await tester.pumpAndSettle();

      await openRow(tester, 'health');
      expect(find.text("Soya's health profile"), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.text('Save profile'));
      expect(rowText('health', 'No known allergies'), findsOneWidget);
      // Health's three answers have one row now, not three "Edit" links.
      expect(find.byKey(const Key('health-allergies')), findsNothing);
    });

    testWidgets("the Documents row opens the pet's documents", (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Kelly');
      await openRow(tester, 'documents');
      expect(find.text("Kelly's documents"), findsOneWidget);
      expect(find.text('blood-test.pdf'), findsOneWidget);
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
      expect(find.byKey(PetProfileScreen.pictureKey), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('My pets', () {
    testWidgets('shows every pet without tags, and leads to the profile and back', (tester) async {
      await pumpPetsApp(tester);
      openMyPets(tester.element(find.text('Feeding')));
      await tester.pumpAndSettle();

      expect(find.text('Dog · Mix · 13.6 years'), findsOneWidget);
      expect(find.text('Dog'), findsOneWidget); // Soya
      // The essentials are nagged about on Home only.
      expect(find.text('Complete'), findsNothing);
      expect(find.textContaining('essential'), findsNothing);
      expect(find.byType(PetsTag), findsNothing);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('my-pet-soya')));
      expect(find.byKey(PetProfileScreen.moreKey), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.byKey(PetProfileScreen.moreKey), findsNothing);
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
  });

  group('archive and delete', () {
    testWidgets('both entries of the "More" menu open the same clear choice, and "Cancel" changes nothing', (tester) async {
      await pumpPetsApp(tester);
      await openProfile(tester, 'Soya');
      await tester.tap(find.byKey(PetProfileScreen.moreKey));
      await tester.pumpAndSettle();
      expect(find.text('Archive Soya'), findsOneWidget);
      expect(find.text('Delete Soya'), findsOneWidget);
      await tester.tap(find.byKey(PetProfileScreen.deleteKey));
      await tester.pumpAndSettle();

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
        extra: [petHealthCleanupProvider.overrideWithValue((petId) async => () async => cleaned.add(petId))],
      );
      await harness.pets.uploadPhoto('demo', soya, testPhoto);
      await pumpPetsApp(tester, harness: harness);
      await openProfile(tester, 'Soya');
      await openMenuEntry(tester, PetProfileScreen.deleteKey);
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Soya was deleted'), findsOneWidget);
      expect(cleaned, [soya]);
      expect([for (final p in harness.pets.cachedPets('demo')!) p.id], [kelly]);
      expect(harness.pets.photos, isEmpty);
      expect(appContainer(tester).read(archivedPetsProvider), isEmpty);
    });

    testWidgets('a delete that fails keeps the pet, its Health files, and says why', (tester) async {
      final prepared = <String>[];
      final cleaned = <String>[];
      final harness = PetsHarness(
        extra: [
          petHealthCleanupProvider.overrideWithValue((petId) async {
            prepared.add(petId);
            return () async => cleaned.add(petId);
          }),
        ],
      );
      final h = await pumpPetsApp(tester, harness: harness);
      await openProfile(tester, 'Soya');
      h.pets.failure = 'Cannot reach the server. Check your connection and try again.';
      await openMenuEntry(tester, PetProfileScreen.deleteKey);
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.byKey(PetProfileScreen.moreKey), findsOneWidget);
      expect(currentPets(tester).length, 2);
      // Health got ready, but its files stay: the pet is still there.
      expect(prepared, [soya]);
      expect(cleaned, isEmpty);
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
      await openMenuEntry(tester, PetProfileScreen.deleteKey);
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
      await openMenuEntry(tester, PetProfileScreen.deleteKey);
      await tapVisible(tester, find.byKey(const Key('remove-delete')));

      expect(find.text('Welcome, Alex'), findsOneWidget);
      expect(find.text('Archived pets'), findsOneWidget);
      await tapVisible(tester, find.text('Restore'));
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Soya'), findsNWidgets(2));
    });
  });
}
