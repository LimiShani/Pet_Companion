import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/health_screen.dart';
import 'package:pet_companion/features/health/widgets/weight_trend.dart';
import 'package:pet_companion/models/pet.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Overview', () {
    testWidgets('shows what needs attention for Kelly', (tester) async {
      await pumpHealth(tester);

      expect(find.text('Health'), findsWidgets);
      for (final label in ['Overview', 'Schedule', 'History', 'Insights']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.byType(EmergencyButton), findsOneWidget);

      // The pet, and the date of the last record.
      expect(find.text('Dog · Mix · 13.6 years'), findsOneWidget);
      expect(find.text('Last record 08.06.25'), findsOneWidget);

      // The next action outranks everything else.
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('Evening walk'), findsOneWidget);
      expect(find.text('Today · 18:30'), findsOneWidget);
      expect(find.text('General check'), findsOneWidget);
      expect(find.text('Thu 12.06.25 · 18:20 · Park Vet Clinic'), findsOneWidget);
      expect(find.text('1 reminder needs review'), findsOneWidget);

      // The vet, one tap away.
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text('12 Park Street, Tel Aviv · +972 3 555 0142'), findsOneWidget);

      // The latest facts.
      expect(find.text('Joint tablets 50 mg'), findsOneWidget);
      expect(find.text('1 tablet by mouth, twice a day with food'), findsOneWidget);
      expect(find.text('Last recorded dose: today 08:05'), findsOneWidget);
      expect(find.text('23 kg', findRichText: true), findsOneWidget);
      expect(find.text('01.06.25 · 0.2 kg down since 02.05.25'), findsOneWidget);
      expect(find.byType(WeightTrendChart), findsOneWidget);
      expect(find.bySemanticsLabel('3 Vaccinations'), findsOneWidget);
      expect(find.bySemanticsLabel('4 Vet visits'), findsOneWidget);
      expect(find.bySemanticsLabel('4 Documents'), findsOneWidget);

      // No score, no verdict.
      expect(find.textContaining('score'), findsNothing);
      expect(find.textContaining('Perfect'), findsNothing);
      expect(find.byKey(const Key('getting-started')), findsNothing);
    });

    testWidgets('an empty pet gets first steps, not empty blocks', (tester) async {
      await pumpHealth(tester);
      await tester.tap(find.text('Soya').first);
      await tester.pumpAndSettle();

      expect(find.text('No scheduled care due'), findsOneWidget);
      expect(find.text('Start with one thing'), findsOneWidget);
      expect(find.text("No need to enter Soya's whole history. Add things as they come up."), findsOneWidget);
      expect(find.text("Add Soya's vet"), findsOneWidget);
      expect(find.byKey(const Key('emergency-dot')), findsOneWidget);

      // Blocks with nothing in them are not shown.
      expect(find.text('Coming up'), findsNothing);
      expect(find.text('Medicines'), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.text('Medical records'), findsNothing);
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final h = HealthHarness();
      h.repository.failing = true;
      await pumpHealth(tester, harness: h);

      expect(find.text("Could not load Kelly's health"), findsOneWidget);
      expect(find.text('Could not reach the server. Check your connection and try again.'), findsOneWidget);
      // The emergency button is still there.
      expect(find.byType(EmergencyButton), findsOneWidget);

      h.repository.failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Coming up'), findsOneWidget);
    });

    testWidgets('fits a small phone and a right-to-left layout', (tester) async {
      for (final direction in TextDirection.values) {
        await pumpHealthHost(
          tester,
          const HealthScreen(),
          page: true,
          size: const Size(320, 640),
          textDirection: direction,
        );
        expect(find.text('Coming up'), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const Key('overview-records')),
          find.byKey(const Key('overview-pet')),
          const Offset(0, -200),
        );
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Vet section', () {
    testWidgets('opens from the Overview and shows both vets', (tester) async {
      final h = await pumpHealth(tester);

      await tapVisible(tester, find.text('Details'));
      expect(find.text("Kelly's vets"), findsOneWidget);
      expect(find.text('Regular vet'), findsOneWidget);
      expect(find.text('Emergency vet (24 h)'), findsOneWidget);
      expect(find.text('12 Park Street, Tel Aviv'), findsOneWidget);
      expect(find.text('Sun to Thu 08:00-19:00, Fri 08:00-13:00'), findsOneWidget);
      expect(find.text('Parking behind the building. Kelly is nervous in the waiting room.'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Open 24 hours'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('map-regular')));
      expect(h.launcher.calls.single.action, ContactAction.map);
      expect(h.launcher.calls.single.target, '12 Park Street, Tel Aviv');
    });

    testWidgets('a vet can be edited, and the change shows everywhere', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.text('Details'));

      await tapVisible(tester, find.byKey(const ValueKey('edit-vet-regular')));
      expect(find.text('Edit vet'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('vet-name')), 'Dr. Levi, Riverside Vets');
      await tapVisible(tester, find.text('Save vet'));

      expect(find.text('Edit vet'), findsNothing);
      expect(find.text('Dr. Levi, Riverside Vets'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Dr. Levi, Riverside Vets'), findsOneWidget);
    });

    testWidgets('a vet can be deleted after a confirmation', (tester) async {
      final h = await pumpHealth(tester);
      await tapVisible(tester, find.text('Details'));
      await tapVisible(tester, find.byKey(const ValueKey('edit-vet-emergency')));

      await tester.tap(find.byTooltip('Delete vet'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this vet?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit vet'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete vet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text("Kelly's vets"), findsOneWidget);
      expect(find.text('City Animal Hospital'), findsNothing);
      expect(find.text('Add an emergency vet'), findsOneWidget);
      expect((await real(tester, h.repository.fetchVets)).map((v) => v.id), ['v-park']);
    });

    testWidgets('another saved vet can be chosen for a pet', (tester) async {
      final h = await pumpHealth(tester);
      await tester.tap(find.text('Soya').first);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text("Add Soya's vet"));
      expect(find.text('Choose the regular vet'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('use-vet-v-park')));

      // The Overview now carries the vet card with its actions.
      expect(find.text("Add Soya's vet"), findsNothing);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('call-overview')));
      expect(h.launcher.calls.single.target, '+972 3 555 0142');
    });
  });

  group('Emergency card and health profile', () {
    testWidgets('the header button opens the sheet and the Emergency card', (tester) async {
      await pumpHealth(tester);

      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      expect(find.text('Emergency · Kelly'), findsOneWidget);

      await tapVisible(tester, find.text("Open Kelly's Emergency card"));
      expect(find.text('Emergency card'), findsOneWidget);
      expect(find.text('985 112 004 567 321'), findsOneWidget);
      expect(find.text('Dog · Mix · 13.6 years · 23 kg'), findsOneWidget);
      expect(find.text('Chicken (skin reaction)'), findsOneWidget);
      expect(find.text('Arthritis in the hips'), findsOneWidget);
      expect(find.text('Joint tablets 50 mg · 1 tablet by mouth, twice a day with food'), findsOneWidget);
      expect(find.byKey(const ValueKey('call-regular')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-emergency')), findsOneWidget);
      expect(find.textContaining('does not replace veterinary advice'), findsOneWidget);
    });

    testWidgets('the health profile is edited from the Overview', (tester) async {
      final h = await pumpHealth(tester);

      await tester.tap(find.byKey(const Key('overview-pet')));
      await tester.pumpAndSettle();
      expect(find.text("Kelly's health profile"), findsOneWidget);

      await tester.enterText(find.byKey(const Key('profile-allergies')), 'Chicken\nGrass pollen');
      await tester.enterText(find.byKey(const Key('profile-contact-phone')), 'call me');
      await tapVisible(tester, find.text('Save profile'));
      expect(find.text('That does not look like a phone number.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('profile-contact-phone')), '+972 50 555 0117');
      await tapVisible(tester, find.text('Save profile'));
      expect(find.text("Kelly's health profile"), findsNothing);

      final saved = await real(tester, () => h.repository.fetchProfile('kelly'));
      expect(saved.allergies, ['Chicken', 'Grass pollen']);
      // The vets are untouched by the profile form.
      expect(saved.regularVetId, 'v-park');
    });
  });

  group('species', () {
    testWidgets('another species is named on the Overview', (tester) async {
      final h = HealthHarness(
        repository: fakeHealth(seeded: false),
        pets: const [Pet(id: 'rio', name: 'Rio', species: PetSpecies.bird, breed: 'Cockatiel', ageYears: 4)],
      );
      await pumpHealth(tester, harness: h);

      expect(find.text('Bird · Cockatiel · 4 years'), findsOneWidget);
      expect(find.text('Start with one thing'), findsOneWidget);
      expect(find.text("Add Rio's vet"), findsOneWidget);
    });
  });
}
