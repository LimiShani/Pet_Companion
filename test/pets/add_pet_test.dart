import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:pet_companion/features/pets/data/photo_services.dart';
import 'package:pet_companion/features/pets/icons/pet_icon_bank.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/picture/crop_photo_screen.dart';
import 'package:pet_companion/features/pets/widgets/pet_basics_fields.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'pets_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('step 1: name and kind', () {
    testWidgets('the welcome leads into the flow', (tester) async {
      await openFlowFromWelcome(tester);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Who is joining the family?'), findsOneWidget);
      expect(find.text('Finish later'), findsNothing);
      for (final kind in ['Dog', 'Cat', 'Bird', 'Rabbit', 'Reptile', 'Other']) {
        expect(find.text(kind), findsOneWidget);
      }
      expect(find.text('Your pet is saved when you continue. You can change anything later.'), findsOneWidget);
    });

    testWidgets('a pet needs a name', (tester) async {
      await openFlowFromWelcome(tester);
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('What is your pet called?'), findsOneWidget);
      expect(currentPets(tester), isEmpty);
    });

    testWidgets('"Continue" creates the pet, selects it and moves on', (tester) async {
      final h = await openFlowFromWelcome(tester);
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      expect(find.text('Milo is saved when you continue. You can change anything later.'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('kind-cat')));
      await tapVisible(tester, find.text('Continue'));

      expect(find.text('About Milo'), findsOneWidget);
      expect(find.text('Milo is saved'), findsOneWidget);
      expect(find.text('Finish later'), findsOneWidget);

      final pet = currentPets(tester).single;
      expect(pet.name, 'Milo');
      expect(pet.species, PetSpecies.cat);
      expect(pet.createdAt, petsNow);
      expect(appContainer(tester).read(selectedPetProvider).id, pet.id);
      // A database-style id made on the phone, and stored for this owner.
      expect(pet.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect([for (final p in h.pets.cachedPets('u2')!) p.name], ['Milo']);
    });

    testWidgets('a save that fails keeps the step open with the reason', (tester) async {
      final h = await openFlowFromWelcome(tester);
      h.pets.failure = 'Cannot reach the server. Check your connection and try again.';
      await createPet(tester);
      expect(find.text('Cannot reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.text('Who is joining the family?'), findsOneWidget);

      h.pets.failure = null;
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('About Milo'), findsOneWidget);
    });

    testWidgets('leaving before step 1 is saved creates nothing', (tester) async {
      await openFlowFromWelcome(tester);
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Add my first pet'), findsOneWidget);
      expect(currentPets(tester), isEmpty);
    });

    testWidgets('back from step 2 edits the same pet instead of making another', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Who is joining the family?'), findsOneWidget);

      await createPet(tester, name: 'Miloš', kind: PetSpecies.rabbit);
      expect(find.text('About Miloš'), findsOneWidget);
      final pet = currentPets(tester).single;
      expect(pet.name, 'Miloš');
      expect(pet.species, PetSpecies.rabbit);
    });
  });

  group('the picture', () {
    testWidgets('the sheet offers a photo or an icon, and "Remove" only when there is a picture', (tester) async {
      await openFlowFromWelcome(tester);
      await typeInto(tester, find.byKey(const Key('pet-name')), 'Milo');
      await tapVisible(tester, find.byKey(const Key('pet-picture')));

      expect(find.text("Milo's picture"), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from your photos'), findsOneWidget);
      expect(find.text('Pick an icon'), findsOneWidget);
      expect(find.text("13 animals in the app's colours"), findsOneWidget);
      expect(find.text('Remove picture'), findsNothing);
    });

    testWidgets('an icon from the bank, on a chosen background, is stored with the pet', (tester) async {
      await openFlowFromWelcome(tester);
      await tapVisible(tester, find.byKey(const Key('kind-cat')));
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Pick an icon'));

      expect(find.text('For a cat'), findsOneWidget);
      expect(find.text('All animals'), findsOneWidget);
      for (final icon in PetIcon.values) {
        expect(find.byKey(Key('icon-${icon.key}')), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const Key('icon-cat_tabby')));
      await tapVisible(tester, find.byKey(const Key('icon-bg-peach')));
      await tapVisible(tester, find.text('Use this icon'));

      expect(find.text('Who is joining the family?'), findsOneWidget);
      await createPet(tester);
      expect(currentPets(tester).single.iconKey, 'cat_tabby:peach');
      expect(currentPets(tester).single.photoPath, isNull);
    });

    testWidgets('a photo is picked, cropped, uploaded and linked to the pet', (tester) async {
      final h = await openFlowFromWelcome(tester);
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Choose from your photos'));
      expect(h.picker.asked, [PetPhotoSource.gallery]);
      expect(h.cropper.calls, 1);
      // Nothing is stored before the pet exists.
      expect(h.pets.photos, isEmpty);

      await createPet(tester);
      final pet = currentPets(tester).single;
      expect(pet.photoPath, startsWith('u2/${pet.id}/'));
      expect(pet.hasPhoto, isTrue);
      expect(h.pets.photos.keys, [pet.photoPath]);
    });

    testWidgets('the camera is one tap away too', (tester) async {
      final h = await openFlowFromWelcome(tester);
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Take a photo'));
      expect(h.picker.asked, [PetPhotoSource.camera]);
    });

    testWidgets('"Choose another" on the crop step opens the photos again', (tester) async {
      final h = await openFlowFromWelcome(tester);
      h.cropper.outcomes.addAll([const CropOutcome.another(), CropOutcome.cropped(testPhoto)]);
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Choose from your photos'));
      expect(h.picker.asked, [PetPhotoSource.gallery, PetPhotoSource.gallery]);
      expect(h.cropper.calls, 2);

      // There is a picture now, so it can be removed again.
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      expect(find.text('Remove picture'), findsOneWidget);
      await tapVisible(tester, find.text('Remove picture'));
      await createPet(tester);
      expect(currentPets(tester).single.hasPhoto, isFalse);
      expect(h.pets.photos, isEmpty);
    });

    testWidgets('backing out of the camera or the crop step changes nothing', (tester) async {
      final h = await openFlowFromWelcome(tester);
      h.picker.photo = null;
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Take a photo'));
      expect(h.cropper.calls, 0);

      h.picker.photo = testPhoto;
      h.cropper.outcomes.add(const CropOutcome.cancelled());
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Take a photo'));
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      expect(find.text('Remove picture'), findsNothing);
    });

    testWidgets('a camera that cannot open says why', (tester) async {
      final h = await openFlowFromWelcome(tester);
      h.picker.failure = 'Cannot open the camera. Check that Pet Companion is allowed to use it.';
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Take a photo'));
      expect(find.text('Cannot open the camera. Check that Pet Companion is allowed to use it.'), findsOneWidget);
      expect(find.text('Who is joining the family?'), findsOneWidget);
    });

    testWidgets('a photo that cannot be stored does not stop the pet from being created', (tester) async {
      final h = await openFlowFromWelcome(tester, harness: PetsHarness(pets: _NoPhotoStorage()));
      await tapVisible(tester, find.byKey(const Key('pet-picture')));
      await tapVisible(tester, find.text('Choose from your photos'));
      await createPet(tester);

      expect(find.text('About Milo'), findsOneWidget);
      expect(
        find.text("The picture could not be saved. You can add it later from Milo's profile."),
        findsOneWidget,
      );
      expect(currentPets(tester).single.photoPath, isNull);
      expect(h.pets.photos, isEmpty);
    });
  });

  group('step 2: about the pet', () {
    testWidgets('an approximate age, a rough weight and "Not sure" are all answers', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);

      expect(find.text('Birthday or age'), findsOneWidget);
      expect(find.text('Essential'), findsNWidgets(2));
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '3');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Female'));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Not sure').last);
      await tapVisible(tester, find.widgetWithText(FilterChip, 'Mixed or not sure'));
      await tapVisible(tester, find.text('Continue'));

      final pet = petNamed(tester, 'Milo');
      expect(pet.birthDate, DateTime(2022, 6, 10));
      expect(pet.birthDateApprox, isTrue);
      expect(pet.ageLabelAt(petsNow), 'About 3 years');
      expect(pet.weightKg, 18);
      expect(pet.sex, PetSex.female);
      expect(pet.neutered, Neutered.unknown);
      expect(pet.breed, 'Mixed');
    });

    testWidgets('months work for the very young', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '4');
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'months'));
      await tapVisible(tester, find.text('Continue'));

      final pet = petNamed(tester, 'Milo');
      expect(pet.birthDate, DateTime(2025, 2, 10));
      expect(pet.ageLabelAt(petsNow), 'About 4 months');
    });

    testWidgets('a known birthday is picked from the calendar', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await tapVisible(tester, find.text('I know the date'));
      expect(find.text('Choose the date'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('pet-age-date')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('10.06.2025'), findsOneWidget);
      await tapVisible(tester, find.text('Continue'));

      final pet = petNamed(tester, 'Milo');
      expect(pet.birthDate, DateTime(2025, 6, 10));
      expect(pet.birthDateApprox, isFalse);
    });

    testWidgets('a bird is weighed in grams and stored in kilograms', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester, name: 'Kiwi', kind: PetSpecies.bird);
      expect(find.text('g'), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '35');
      await tapVisible(tester, find.text('Continue'));
      expect(petNamed(tester, 'Kiwi').weightKg, closeTo(0.035, 1e-9));
    });

    testWidgets('a weight that is not a number is caught', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '1.2.3');
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('Enter a number, for example 18.'), findsOneWidget);
      expect(petNamed(tester, 'Milo').weightKg, isNull);
    });

    testWidgets('"Skip for now" saves nothing', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Skip for now'));
      expect(petNamed(tester, 'Milo').weightKg, isNull);
    });

    testWidgets('"Finish later" closes the flow and the pet stays, on its dashboard', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();

      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Milo'), findsNWidgets(2)); // the pill and the hero
    });
  });

  group('openAddPet', () {
    testWidgets('from inside the app it returns the new pet, already selected', (tester) async {
      await pumpPetsApp(tester);
      Pet? added;
      var done = false;
      openAddPet(tester.element(find.text('Feeding'))).then((pet) {
        added = pet;
        done = true;
      });
      await tester.pumpAndSettle();
      expect(find.text('Who is joining the family?'), findsOneWidget);
      expect(find.text('Home'), findsNothing); // full screen: no bottom bar

      await createPet(tester, name: 'Pip');
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(added!.name, 'Pip');
      expect([for (final p in currentPets(tester)) p.name], ['Kelly', 'Soya', 'Pip']);
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Pip'), findsNWidgets(2));
    });

    testWidgets('leaving at step 1 returns null', (tester) async {
      await pumpPetsApp(tester);
      Pet? added;
      var done = false;
      openAddPet(tester.element(find.text('Feeding'))).then((pet) {
        added = pet;
        done = true;
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(done, isTrue);
      expect(added, isNull);
      expect(currentPets(tester).length, 2);
    });

    testWidgets('it also works from a page shown on its own', (tester) async {
      Pet? added;
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => added = await openAddPet(context),
            child: const Text('Add'),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await createPet(tester, name: 'Pip');
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();

      expect(added!.name, 'Pip');
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('the about form', () {
    PetBasicsController controllerFor(Pet pet) {
      final controller = PetBasicsController(pet: pet, now: petsNow);
      addTearDown(controller.dispose);
      return controller;
    }

    test('an age nobody touched is kept exactly (the sample pets)', () {
      const pet = Pet(id: 'kelly', name: 'Kelly', ageYears: 13.6, weightKg: 23, breed: 'Mix');
      final controller = controllerFor(pet);
      expect(controller.ageAmount.text, '13.6');
      expect(controller.weight.text, '23');
      expect(controller.breed.text, 'Mix');

      final saved = controller.applyTo(pet, now: petsNow);
      expect(saved.ageYears, 13.6);
      expect(saved.birthDate, isNull);
    });

    test('an approximate age reads back as the number that was typed', () {
      final years = controllerFor(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2022, 6, 10), birthDateApprox: true));
      expect(years.ageApprox, isTrue);
      expect(years.ageAmount.text, '3');
      expect(years.ageUnit, AgeUnit.years);

      final months = controllerFor(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2025, 2, 10), birthDateApprox: true));
      expect(months.ageAmount.text, '4');
      expect(months.ageUnit, AgeUnit.months);
    });

    test('an exact birthday opens on "I know the date"', () {
      final controller = controllerFor(Pet(id: 'p', name: 'Pip', birthDate: DateTime(2021, 3, 4)));
      expect(controller.ageApprox, isFalse);
      expect(controller.birthDate, DateTime(2021, 3, 4));
      expect(controller.ageAnswer(petsNow), (date: DateTime(2021, 3, 4), approx: false));
    });

    test('switching the way of answering does not wipe a known age', () {
      final pet = Pet(id: 'p', name: 'Pip', birthDate: DateTime(2021, 3, 4));
      final controller = controllerFor(pet)..ageApprox = true;
      expect(controller.applyTo(pet, now: petsNow).birthDate, DateTime(2021, 3, 4));
    });

    test('emptying the age removes the answer', () {
      final pet = Pet(id: 'p', name: 'Pip', birthDate: DateTime(2022, 6, 10), birthDateApprox: true);
      final controller = controllerFor(pet);
      controller.ageAmount.clear();
      controller.touch(BasicsSection.age);
      expect(controller.applyTo(pet, now: petsNow).hasAge, isFalse);
    });

    test('an age typed one way is not thrown away by looking at the other way', () {
      const pet = Pet(id: 'p', name: 'Pip');
      final typed = controllerFor(pet);
      typed.ageAmount.text = '3';
      typed.touch(BasicsSection.age);
      typed.ageApprox = false; // "I know the date", but no date is picked
      final saved = typed.applyTo(pet, now: petsNow);
      expect(saved.birthDate, DateTime(2022, 6, 10));
      expect(saved.birthDateApprox, isTrue);

      // The other way round: a picked date, then a look at "About…".
      final picked = controllerFor(pet)
        ..birthDate = DateTime(2021, 3, 4)
        ..ageApprox = true;
      expect(picked.applyTo(pet, now: petsNow).birthDate, DateTime(2021, 3, 4));
      expect(picked.applyTo(pet, now: petsNow).birthDateApprox, isFalse);

      // What is on screen wins when both ways hold an answer.
      picked.ageAmount.text = '2';
      expect(picked.applyTo(pet, now: petsNow).birthDate, DateTime(2023, 6, 10));
      picked.ageApprox = false;
      expect(picked.applyTo(pet, now: petsNow).birthDate, DateTime(2021, 3, 4));
    });

    test('a comma works as a decimal point', () {
      const pet = Pet(id: 'p', name: 'Pip');
      final controller = controllerFor(pet);
      controller.weight.text = '4,25';
      controller.touch(BasicsSection.weight);
      expect(controller.applyTo(pet, now: petsNow).weightKg, 4.25);
      expect(controller.validateWeight('4,25'), isNull);
      expect(controller.validateWeight('0'), isNotNull);
      expect(controller.validateWeight('5000'), isNotNull);
      expect(controller.validateAgeAmount('400'), isNotNull);
    });

    test('changing the kind converts the typed weight to the new unit, to the gram', () {
      const pet = Pet(id: 'p', name: 'Pip', weightKg: 0.035, species: PetSpecies.bird);
      final controller = controllerFor(pet);
      expect(controller.weight.text, '35');
      controller.species = PetSpecies.dog;
      expect(controller.weight.text, '0.035');
      controller.species = PetSpecies.bird;
      expect(controller.weight.text, '35');
      // Nothing was typed, so nothing is written back.
      expect(controller.applyTo(pet, now: petsNow).weightKg, 0.035);
    });

    test('only what was changed is written back; the rest follows the stored pet', () {
      const pet = Pet(id: 'p', name: 'Pip', breed: 'Labrador');
      final controller = controllerFor(pet);
      controller.sex = PetSex.female;

      // Meanwhile the weight is added somewhere else (the checklist).
      const newer = Pet(id: 'p', name: 'Pip', breed: 'Labrador', weightKg: 18, neutered: Neutered.yes);
      controller.refresh(newer, petsNow);
      expect(controller.weight.text, '18');
      expect(controller.neutered, Neutered.yes);
      expect(controller.sex, PetSex.female, reason: 'what the owner chose here stays');

      final saved = controller.applyTo(newer, now: petsNow);
      expect(saved.weightKg, 18);
      expect(saved.neutered, Neutered.yes);
      expect(saved.sex, PetSex.female);
      expect(saved.breed, 'Labrador');

      // Even a form that was not refreshed does not write its old, empty
      // weight over the newer one.
      final stale = controllerFor(pet)..sex = PetSex.male;
      expect(stale.applyTo(newer, now: petsNow).weightKg, 18);
    });

    test('"Mixed or not sure" is stored as a breed and read back as the tick', () {
      const pet = Pet(id: 'p', name: 'Pip', breed: 'Labrador');
      final controller = controllerFor(pet)..mixedBreed = true;
      final saved = controller.applyTo(pet, now: petsNow);
      expect(saved.breed, 'Mixed');
      expect(controllerFor(saved).mixedBreed, isTrue);
      expect(controllerFor(saved).breed.text, isEmpty);
    });

    test('a one-field save leaves the other answers alone', () {
      const pet = Pet(id: 'p', name: 'Pip', breed: 'Labrador', sex: PetSex.male, ageYears: 2);
      final controller = controllerFor(pet);
      controller.weight.text = '30';
      controller.touch(BasicsSection.weight);
      controller.breed.clear();
      controller.touch(BasicsSection.breed);
      final saved = controller.applyTo(pet, now: petsNow, only: {BasicsSection.weight});
      expect(saved.weightKg, 30);
      expect(saved.breed, 'Labrador');
      expect(saved.sex, PetSex.male);
      expect(saved.ageYears, 2);
    });

    test('weights and the summary line are written the way people say them', () {
      expect(formatPetWeight(18, PetSpecies.dog), '18 kg');
      expect(formatPetWeight(4.25, PetSpecies.cat), '4.25 kg');
      expect(formatPetWeight(100, PetSpecies.other), '100 kg');
      expect(formatPetWeight(0.035, PetSpecies.bird), '35 g');
      expect(formatPetWeight(0.035, PetSpecies.other), '0.035 kg'); // a hamster: never "0 kg"
      expect(petSummaryLine(const Pet(id: 'soya', name: 'Soya')), 'Dog');
      expect(petSummaryLine(const Pet(id: 'kelly', name: 'Kelly', breed: 'Mix', ageYears: 13.6)), 'Dog · Mix · 13.6 years');
    });
  });

  group('the profile photo', () {
    test('is shrunk to a 512 px square JPEG', () {
      final big = img.encodePng(img.Image(width: 900, height: 900));
      final jpeg = squarePetPhoto(big);
      final decoded = img.decodeJpg(jpeg)!;
      expect(decoded.width, 512);
      expect(decoded.height, 512);
      expect(jpeg.length, lessThan(100 * 1024));
    });

    testWidgets('a file the crop screen could not read is refused before it opens', (tester) async {
      Object? error;
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              try {
                await const ScreenPetPhotoCropper().crop(context, Uint8List.fromList([1, 2, 3, 4]));
              } catch (e) {
                error = e;
              }
            },
            child: const Text('Crop'),
          ),
        ),
      );
      await tester.tap(find.text('Crop'));
      await tester.pumpAndSettle();

      expect(find.byType(CropPhotoScreen), findsNothing);
      expect(
        error,
        isA<PetsException>().having(
          (e) => e.message,
          'message',
          'That kind of picture is not supported. Please choose another one.',
        ),
      );
      expect(isReadablePhoto(testPhoto), isTrue);
    });

    test('something that is not a picture is refused in words', () {
      expect(
        () => squarePetPhoto(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<PetsException>().having((e) => e.message, 'message', 'That kind of picture is not supported.')),
      );
    });

    testWidgets('the crop screen explains itself and can be left', (tester) async {
      CropOutcome? outcome;
      await pumpPetsHost(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => outcome = await const ScreenPetPhotoCropper().crop(context, testPhoto),
            child: const Text('Crop'),
          ),
        ),
      );
      await tester.tap(find.text('Crop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CropPhotoScreen), findsOneWidget);
      expect(find.text('Move and zoom'), findsOneWidget);
      expect(find.text('Drag to move · pinch to zoom'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Use photo'), findsOneWidget);

      await tester.tap(find.text('Choose another'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(outcome!.another, isTrue);
      expect(outcome!.jpeg, isNull);
    });

    testWidgets('the real crop screen turns a photo into the square profile picture', (tester) async {
      // A real landscape photo through the real cropper: the package parses
      // and crops off the main thread, so real time has to pass.
      Future<void> waitUntil(bool Function() done) async {
        for (var i = 0; i < 200 && !done(); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Let the page transition finish.
        await tester.pump(const Duration(milliseconds: 400));
      }

      final photo = img.encodeJpg(img.Image(width: 640, height: 360));
      CropOutcome? outcome;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      // A plain app: the app's theme would try to fetch its font once real
      // time passes.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => outcome = await const ScreenPetPhotoCropper().crop(context, photo),
              child: const Text('Crop'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Crop'));
      await tester.pump();
      final use = find.widgetWithText(FilledButton, 'Use photo');
      await waitUntil(() => tester.any(use) && tester.widget<FilledButton>(use).onPressed != null);

      expect(tester.widget<FilledButton>(use).onPressed, isNotNull, reason: 'the photo was parsed');
      await tester.tap(use);
      await tester.pump();
      await waitUntil(() => outcome != null);

      expect(find.byType(CropPhotoScreen), findsNothing);
      final jpeg = outcome!.jpeg!;
      final picture = img.decodeJpg(jpeg)!;
      expect(picture.width, kPetPhotoSide);
      expect(picture.height, kPetPhotoSide);
    });
  });

  group('the icon bank', () {
    test('has 13 animals, and every kind has a default', () {
      expect(PetIcon.values.length, 13);
      for (final species in PetSpecies.values) {
        expect(PetIcon.forSpecies(species), isNotEmpty);
        expect(PetIcon.forSpecies(species).first, PetIcon.defaultFor(species));
      }
      expect(PetIcon.defaultFor(PetSpecies.dog), PetIcon.dogFloppy);
      expect(PetIcon.defaultFor(PetSpecies.other), PetIcon.paw);
    });

    test('a stored key names the icon and its background', () {
      expect(const PetIconChoice(PetIcon.dogFloppy, PetIconBackground.sage).key, 'dog_floppy:sage');
      expect(PetIconChoice.parse('cat_tabby:peach'), const PetIconChoice(PetIcon.catTabby, PetIconBackground.peach));
      // Unknown values fall back instead of failing.
      expect(
        PetIconChoice.parse('unicorn:gold', species: PetSpecies.rabbit),
        const PetIconChoice(PetIcon.rabbitUpright),
      );
      expect(PetIconChoice.parse(null, species: PetSpecies.bird), const PetIconChoice(PetIcon.parrot));
    });

    test('the drawing notation is read correctly', () {
      final bounds = parseSvgPath('M10 10h20v20h-20z').getBounds();
      expect(bounds, const Rect.fromLTRB(10, 10, 30, 30));
      // Relative curves, implicit repeats and numbers written without a gap.
      final curve = parseSvgPath('M32 42.5c-1.5 2-4 2-5 .5M8 42c0-13 9-22 21-22s21 9 21 22z').getBounds();
      expect(curve.left, closeTo(8, 0.01));
      expect(curve.right, closeTo(50, 0.01));
      expect(curve.top, closeTo(20, 0.01));
      expect(() => parseSvgPath('M0 0A5 5 0 0 1 10 10'), throwsFormatException);
      // Malformed input is refused rather than looped over.
      expect(() => parseSvgPath('M0 0h5z 3 4'), throwsFormatException);
      expect(() => parseSvgPath('3 4 M0 0'), throwsFormatException);
    });

    testWidgets('every animal draws at every size used', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            children: [
              for (final icon in PetIcon.values)
                for (final size in [19.0, 44.0, 103.0]) PetIconImage(icon, size: size),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PetIconImage), findsNWidgets(39));
    });
  });
}

/// Pets are stored, photos are not: what a full or unreachable bucket does.
class _NoPhotoStorage extends FakePetsRepository {
  _NoPhotoStorage() : super(latency: Duration.zero);

  @override
  Future<String> uploadPhoto(String ownerId, String petId, Uint8List jpeg) async =>
      throw const PetsException('Could not save the photo. Please try again.');
}
