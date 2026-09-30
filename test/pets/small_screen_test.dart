import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';

import 'pets_test_helpers.dart';

/// A small phone. The test font is wide, so a layout that survives here has
/// room to spare on a real one. Any overflow fails the test.
const small = Size(320, 568);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the whole add-a-pet flow fits a small phone', (tester) async {
    await pumpPetsApp(tester, as: SignedIn.newAccount, size: small);
    expect(find.text('Welcome, Limor'), findsOneWidget);

    await tapVisible(tester, find.text('Add my first pet'));
    await tapVisible(tester, find.byKey(const Key('pet-picture')));
    expect(find.text('Pick an icon'), findsOneWidget);
    await tapVisible(tester, find.text('Pick an icon'));
    await tapVisible(tester, find.byKey(const Key('icon-hamster')));
    await tapVisible(tester, find.text('Use this icon'));

    await createPet(tester, name: 'Bartholomew the Third');
    expect(find.text('Bartholomew the Third is saved'), findsOneWidget);
    await tapVisible(tester, find.text('I know the date'));
    await tapVisible(tester, find.text('About…'));
    await typeInto(tester, find.byKey(const Key('pet-age-amount')), '2');
    await typeInto(tester, find.byKey(const Key('pet-weight')), '1.2.3');
    await tapVisible(tester, find.text('Continue'));
    expect(find.text('Enter a number, for example 18.'), findsOneWidget);
    await typeInto(tester, find.byKey(const Key('pet-weight')), '7.5');
    await tapVisible(tester, find.text('Continue'));

    expect(find.text('Who looks after Bartholomew the Third?'), findsOneWidget);
    await tapVisible(tester, find.text('Add a vet'));
    await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));
    await tapVisible(tester, find.text('Continue'));

    expect(find.text('What a vet asks first'), findsOneWidget);
    await tapVisible(tester, find.text('Skip for now'));

    expect(find.text('Bartholomew the Third is ready'), findsOneWidget);
    expect(find.text('3 of 5 essentials filled'), findsOneWidget);
    // The dashboard itself belongs to Home; the flow's last page ends here.
    expect(find.text("Go to Bartholomew the Third's dashboard"), findsOneWidget);
    expect(find.text('Add another pet'), findsOneWidget);
  });

  testWidgets('the profile, the checklist, the dialog and My pets fit a small phone', (tester) async {
    await pumpPetsHost(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openPetProfile(context, soya),
          child: const Text('Profile'),
        ),
      ),
      size: small,
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('profile-essentials-add')));
    expect(find.text("Soya's essentials"), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('add-age')));
    expect(find.text("Soya's age"), findsOneWidget);
    // Close the two sheets (they fill a screen this small).
    Navigator.of(tester.element(find.text("Soya's age"))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text("Soya's essentials"))).pop();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Delete Soya'));
    expect(find.text('Remove Soya?'), findsOneWidget);
    await tapVisible(tester, find.text('Cancel'));

    await tester.tap(find.text('My pets'));
    await tester.pumpAndSettle();
    expect(find.text('5 essentials to add'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('both reminder sizes fit a small phone', (tester) async {
    await pumpPetsHost(
      tester,
      const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            PetReminderCard(petId: soya, compact: true, margin: EdgeInsets.only(bottom: 12)),
            PetReminderCard(petId: soya),
          ],
        ),
      ),
      size: small,
    );
    expect(find.text("Finish Soya's profile"), findsOneWidget);
    expect(find.text("Add the vet's phone"), findsNWidgets(2));
    expect(find.text('Not now'), findsNWidgets(2));
  });
}
