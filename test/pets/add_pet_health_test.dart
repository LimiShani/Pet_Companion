import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/models/pet.dart';

import 'pets_test_helpers.dart';

/// Steps 1 and 2 done (2 skipped): the vet step is on screen.
Future<PetsHarness> openVetStep(WidgetTester tester, {PetsHarness? harness}) async {
  final h = await openFlowFromWelcome(tester, harness: harness);
  await createPet(tester);
  await tapVisible(tester, find.text('Skip for now'));
  return h;
}

/// Everything skipped: the "All set" page of a pet with nothing answered.
Future<PetsHarness> skipToAllSet(WidgetTester tester, {PetsHarness? harness}) async {
  final h = await openVetStep(tester, harness: harness);
  await tapVisible(tester, find.text("I don't have a vet yet"));
  await tapVisible(tester, find.text('Skip for now'));
  return h;
}

/// What is missing for a pet right now (Health may not have answered yet).
PetCompleteness completenessOf(WidgetTester tester, String petId) {
  final sub = appContainer(tester).listen(petCompletenessProvider(petId), (_, _) {});
  addTearDown(sub.close);
  return sub.read();
}

/// What is missing for a pet once Health has answered.
Future<PetCompleteness> settledCompleteness(WidgetTester tester, String petId) async {
  completenessOf(tester, petId);
  await tester.pumpAndSettle();
  return completenessOf(tester, petId);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('step 3: the vet', () {
    testWidgets("shows Health's two vet tiles and explains why", (tester) async {
      await openVetStep(tester);
      expect(find.text("Milo's vet"), findsOneWidget);
      expect(find.text('Who looks after Milo?'), findsOneWidget);
      expect(find.text('Regular vet'), findsOneWidget);
      expect(find.text('Emergency vet (24 h)'), findsOneWidget);
      expect(find.text('Essential'), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.byType(PetVetTile), findsNWidgets(2));
      expect(find.text('Add a vet'), findsOneWidget);
      expect(find.text('Add an emergency vet'), findsOneWidget);
      expect(find.text('Finish later'), findsOneWidget);
    });

    testWidgets('a vet saved before is one tap away', (tester) async {
      await openVetStep(tester);
      await tapVisible(tester, find.text('Add a vet'));
      expect(find.text('Choose the regular vet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));

      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text('+972 3 555 0142'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      final pet = petNamed(tester, 'Milo');
      final info = await settledCompleteness(tester, pet.id);
      expect(info.isKnown, isTrue);
      expect(info.missing, isNot(contains(PetInfoItem.vetPhone)));
    });

    testWidgets("with no saved vets the tile opens Health's vet form", (tester) async {
      final harness = PetsHarness(
        health: FakeHealthRepository(latency: Duration.zero, now: () => petsNow, seeded: false),
      );
      await openVetStep(tester, harness: harness);
      await tapVisible(tester, find.text('Add a vet'));
      expect(find.text('Save vet'), findsOneWidget);

      await typeInto(tester, find.byKey(const Key('vet-name')), 'Dr. Noa');
      await typeInto(tester, find.byKey(const Key('vet-phone')), '+972 3 555 0100');
      await tapVisible(tester, find.text('Save vet'));

      expect(find.text('Who looks after Milo?'), findsOneWidget);
      expect(find.text('Dr. Noa'), findsOneWidget);
      expect(find.text('+972 3 555 0100'), findsOneWidget);
    });

    testWidgets('"Continue" and "I don\'t have a vet yet" both move on', (tester) async {
      await openVetStep(tester);
      await tapVisible(tester, find.text('Continue'));
      expect(find.text('What a vet asks first'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text("I don't have a vet yet"));
      expect(find.text('What a vet asks first'), findsOneWidget);
    });

    testWidgets('back walks the steps one at a time', (tester) async {
      await openVetStep(tester);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('About Milo'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Who is joining the family?'), findsOneWidget);
    });
  });

  group('step 4: health basics', () {
    testWidgets('"None known" and a list are both answers, saved through Health', (tester) async {
      final h = await openVetStep(tester);
      await tapVisible(tester, find.text("I don't have a vet yet"));

      expect(find.text('Health basics'), findsOneWidget);
      expect(find.byType(HealthBasicsSection), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await typeInto(tester, find.byKey(const Key('profile-conditions')), 'Sensitive stomach');
      await tapVisible(tester, find.text('Finish'));

      expect(find.text('Milo is ready'), findsOneWidget);
      expect(find.text('2 of 5 essentials filled'), findsOneWidget);
      expect(find.text('None known'), findsOneWidget);
      expect(find.text('Sensitive stomach'), findsOneWidget);

      final pet = petNamed(tester, 'Milo');
      final profile = await tester.runAsync(() => h.health.fetchProfile(pet.id));
      expect(profile!.allergiesNoneKnown, isTrue);
      expect(profile.conditions, ['Sensitive stomach']);
    });

    testWidgets('"Skip for now" goes to the last page with everything still open', (tester) async {
      await skipToAllSet(tester);
      expect(find.text('Milo is ready'), findsOneWidget);
      expect(find.text('0 of 5 essentials filled'), findsOneWidget);
      expect(find.text('Add now'), findsNWidgets(5));
      expect(
        find.text("We'll keep a small reminder on Milo's dashboard until the rest is added."),
        findsOneWidget,
      );
    });
  });

  group('all set', () {
    testWidgets('"Add now" opens the missing item, and the row is ticked afterwards', (tester) async {
      await skipToAllSet(tester);
      await tapVisible(tester, find.byKey(const Key('add-weight')));
      expect(find.text("Milo's weight"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-weight')), '4.2');
      await tapVisible(tester, find.text('Save'));

      expect(find.text('1 of 5 essentials filled'), findsOneWidget);
      expect(find.text('4.2 kg'), findsOneWidget);
      expect(find.text('Add now'), findsNWidgets(4));
      expect(petNamed(tester, 'Milo').weightKg, 4.2);

      await tapVisible(tester, find.byKey(const Key('add-age')));
      expect(find.text("Milo's age"), findsOneWidget);
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '2');
      await tapVisible(tester, find.text('Save'));
      expect(find.text('2 of 5 essentials filled'), findsOneWidget);
      expect(find.text('About 2 years'), findsOneWidget);
    });

    testWidgets("the vet's phone is added through Health's picker", (tester) async {
      await skipToAllSet(tester);
      await tapVisible(tester, find.byKey(const Key('add-vetPhone')));
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
      expect(find.text('Dr. Levi, Park Vet Clinic · +972 3 555 0142'), findsOneWidget);
      expect(find.text('1 of 5 essentials filled'), findsOneWidget);
    });

    testWidgets("allergies are answered on Health's profile page", (tester) async {
      await skipToAllSet(tester);
      await tapVisible(tester, find.byKey(const Key('add-allergies')));
      expect(find.text("Milo's health profile"), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.byKey(const Key('profile-no-conditions')));
      await tapVisible(tester, find.text('Save profile'));

      expect(find.text('Milo is ready'), findsOneWidget);
      expect(find.text('2 of 5 essentials filled'), findsOneWidget);
      expect(find.text('None known'), findsNWidgets(2));
    });

    testWidgets('a pet with everything answered says so', (tester) async {
      await openFlowFromWelcome(tester);
      await createPet(tester);
      await typeInto(tester, find.byKey(const Key('pet-age-amount')), '3');
      await typeInto(tester, find.byKey(const Key('pet-weight')), '18');
      await tapVisible(tester, find.text('Continue'));
      await tapVisible(tester, find.text('Add a vet'));
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
      await tapVisible(tester, find.text('Continue'));
      await tapVisible(tester, find.byKey(const Key('profile-no-allergies')));
      await tapVisible(tester, find.byKey(const Key('profile-no-conditions')));
      await tapVisible(tester, find.text('Finish'));

      expect(find.text('All 5 essentials filled'), findsOneWidget);
      expect(find.text('Add now'), findsNothing);
      expect(
        find.text("Milo's essentials are complete. You can change anything from the profile."),
        findsOneWidget,
      );
      final info = await settledCompleteness(tester, petNamed(tester, 'Milo').id);
      expect(info.isComplete, isTrue);
      expect(info.shouldRemind, isFalse);
    });

    testWidgets('"Go to the dashboard" opens the new pet\'s Home', (tester) async {
      await skipToAllSet(tester);
      await tapVisible(tester, find.text("Go to Milo's dashboard"));
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Milo'), findsNWidgets(2));
      expect(find.text('Milo is ready'), findsNothing);
    });

    testWidgets('"Add another pet" starts the flow again, empty', (tester) async {
      await skipToAllSet(tester);
      await tapVisible(tester, find.text('Add another pet'));
      expect(find.text('Who is joining the family?'), findsOneWidget);
      expect(find.text('Your pet is saved when you continue. You can change anything later.'), findsOneWidget);

      await createPet(tester, name: 'Pip', kind: PetSpecies.bird);
      expect(find.text('About Pip'), findsOneWidget);
      expect([for (final p in currentPets(tester)) p.name], ['Milo', 'Pip']);
      expect(currentPets(tester).first.id, isNot(currentPets(tester).last.id));
    });

    testWidgets('leaving after "Add another pet" still returns the pet that was made', (tester) async {
      await pumpPetsApp(tester);
      Pet? added;
      openAddPet(tester.element(find.text('Feeding'))).then((pet) => added = pet);
      await tester.pumpAndSettle();
      await createPet(tester, name: 'Pip');
      await tapVisible(tester, find.text('Skip for now'));
      await tapVisible(tester, find.text("I don't have a vet yet"));
      await tapVisible(tester, find.text('Skip for now'));
      await tapVisible(tester, find.text('Add another pet'));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(added!.name, 'Pip');
      expect(find.text('Feeding'), findsOneWidget);
    });
  });

  group('what is missing for a pet', () {
    testWidgets('Kelly is complete and Soya has nothing answered', (tester) async {
      await pumpPetsApp(tester);
      final kellyInfo = await settledCompleteness(tester, kelly);
      expect(kellyInfo.isComplete, isTrue);
      expect(kellyInfo.shouldRemind, isFalse);
      expect(kellyInfo.missing, isEmpty);

      final info = await settledCompleteness(tester, soya);
      expect(info.isKnown, isTrue);
      expect(info.missing, PetInfoItem.essentials);
      expect(info.next, PetInfoItem.vetPhone);
      expect(info.answered, 0);
      expect(info.total, 5);
      expect(info.shouldRemind, isTrue);
      expect(info.goodToHave, [
        PetInfoItem.photo,
        PetInfoItem.breed,
        PetInfoItem.sexAndNeutering,
        PetInfoItem.microchip,
        PetInfoItem.emergencyVet,
      ]);
    });

    testWidgets('until Health has answered its items are unknown, never missing', (tester) async {
      final harness = PetsHarness(
        health: FakeHealthRepository(latency: const Duration(seconds: 5), now: () => petsNow),
      );
      await pumpPetsApp(tester, harness: harness);

      final early = completenessOf(tester, soya);
      expect(early.isKnown, isFalse);
      expect(early.missing, [PetInfoItem.age, PetInfoItem.weight]);
      expect(early.shouldRemind, isFalse);
      expect(completenessOf(tester, kelly).isComplete, isFalse);

      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      await tester.pumpAndSettle();
      expect(completenessOf(tester, soya).missing, PetInfoItem.essentials);
      expect(completenessOf(tester, kelly).isComplete, isTrue);
    });

    testWidgets("while Health cannot be read its items are unknown, never missing", (tester) async {
      final harness = PetsHarness()..health.failing = true;
      await pumpPetsApp(tester, harness: harness);
      completenessOf(tester, soya);
      await tester.pumpAndSettle();

      final info = completenessOf(tester, soya);
      expect(info.isKnown, isFalse);
      expect(info.missing, [PetInfoItem.age, PetInfoItem.weight]);
      expect(info.shouldRemind, isFalse);
      expect(info.isComplete, isFalse);
    });

    testWidgets('an unknown pet id is simply not known', (tester) async {
      await pumpPetsApp(tester);
      final info = completenessOf(tester, 'nobody');
      expect(info.isKnown, isFalse);
      expect(info.shouldRemind, isFalse);
    });

    test('the essentials are five, in reminder order, and named for people', () {
      expect(PetInfoItem.essentials, [
        PetInfoItem.vetPhone,
        PetInfoItem.allergies,
        PetInfoItem.conditions,
        PetInfoItem.age,
        PetInfoItem.weight,
      ]);
      expect([for (final item in PetInfoItem.values) if (item.isEssential) item], PetInfoItem.essentials);
      expect(PetInfoItem.vetPhone.labelIn(en), "A vet's phone number");
      expect(PetInfoItem.vetPhone.actionIn(en, 'Soya'), "Add the vet's phone");
      expect(PetInfoItem.weight.actionIn(en, 'Soya'), "Add Soya's weight");
      expect(PetInfoItem.allergies.hintIn(en), PetInfoItem.conditions.hintIn(en));
      expect(PetInfoItem.microchip.isEssential, isFalse);
    });
  });
}
