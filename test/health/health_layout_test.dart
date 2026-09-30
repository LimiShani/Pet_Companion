import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/health/health_screen.dart';
import 'package:pet_companion/features/health/sections/overview_section.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

/// Closes the bottom sheet on top.
Future<void> closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Every screen of the tab on a small phone, in both directions. The test
  // font is wide, so anything that would overflow fails here.
  for (final direction in TextDirection.values) {
    group('small phone, ${direction.name}', () {
      Future<HealthHarness> pump(WidgetTester tester) => pumpHealthHost(
        tester,
        const HealthScreen(),
        page: true,
        size: const Size(320, 640),
        textDirection: direction,
      );

      testWidgets('Overview pages: vets, Emergency card, health profile, message', (tester) async {
        await pump(tester);

        await tapVisible(tester, find.text('Details'));
        expect(find.text("Kelly's vets"), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('edit-vet-regular')));
        expect(find.text('Edit vet'), findsOneWidget);
        await back(tester);
        await tapVisible(tester, find.byKey(const ValueKey('message-regular')));
        expect(find.textContaining('Message to'), findsOneWidget);
        await closeSheet(tester);
        await back(tester);

        await tester.tap(find.bySemanticsLabel(RegExp('Emergency contacts for Kelly')));
        await tester.pumpAndSettle();
        expect(find.text('Emergency · Kelly'), findsOneWidget);
        await tapVisible(tester, find.text("Open Kelly's Emergency card"));
        expect(find.text('Emergency card'), findsOneWidget);
        await back(tester);

        await tapVisible(tester, find.byKey(const Key('overview-pet')));
        expect(find.text("Kelly's health profile"), findsOneWidget);
        await back(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the emergency kit, the documents page and the lost card', (tester) async {
        final h = HealthHarness();
        h.cardPhotos.photo = MemoryImage(FakeHealthRepository.samplePng);
        await pumpHealthHost(
          tester,
          const HealthScreen(),
          harness: h,
          page: true,
          size: const Size(320, 640),
          textDirection: direction,
        );

        await tester.tap(find.bySemanticsLabel(RegExp('Emergency contacts for Kelly')));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
        expect(find.text("Kelly's emergency kit"), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('kit-foodWater')));
        expect(find.text('4 of 6 ready'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('kit-open-documents')));
        expect(find.text("Kelly's documents"), findsOneWidget);
        await back(tester);
        await back(tester);

        await tapVisible(tester, find.byKey(const Key('open-lost-card')));
        await tester.enterText(
          find.byKey(const Key('lost-description')),
          'Mixed-breed dog, medium, light brown coat, red collar. Shy: please do not chase her.',
        );
        await tester.enterText(find.byKey(const Key('lost-area')), 'Herzl 12, Florentin, Tel Aviv');
        await tester.enterText(find.byKey(const Key('lost-phone')), '+972 50 555 0117');
        await tester.enterText(find.byKey(const Key('lost-extra')), 'Needs a daily medicine');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
        expect(find.text('Show this phone number on the card: +972 50 555 0117'), findsOneWidget);
        // Both languages of the card, in either app direction.
        await tapVisible(tester, find.byKey(const ValueKey('lost-language-en')));
        expect(find.text('Seen Kelly? Please call'), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('lost-language-he')));
        await tapVisible(tester, find.text('Share as image'));
        expect(h.sharer.shared, hasLength(1));
        await back(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets("a cat's Quick log, routine form and a record with a cost", (tester) async {
        final h = HealthHarness(
          repository: fakeHealth(seeded: false),
          pets: const [Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat, breed: 'Domestic shorthair')],
        );
        await pumpHealthHost(
          tester,
          const HealthScreen(),
          harness: h,
          page: true,
          size: const Size(320, 640),
          textDirection: direction,
        );

        await tapVisible(tester, find.byKey(const Key('overview-quick-log')));
        expect(find.byKey(const ValueKey('quick-group-behaviour')), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('quick-biting')));
        await tapVisible(tester, find.byKey(const ValueKey('level-more')));
        await tapVisible(tester, find.text('Save to journal'));
        // Let the "Saved to the journal." message go before tapping under it.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        await tapVisible(tester, find.byKey(const Key('overview-add-record')));
        await tester.enterText(find.byKey(const Key('record-title')), 'Yearly check and vaccinations at the clinic');
        await tester.enterText(find.byKey(const Key('record-cost')), '12345.50');
        await tapVisible(tester, find.text('Save record'));

        await openSection(tester, 'Schedule');
        await tapVisible(tester, find.text('Add to the schedule'));
        await tapVisible(tester, find.byKey(const ValueKey('add-routine')));
        await tapVisible(tester, find.byKey(const ValueKey('routine-kind-litterCleaning')));
        await tapVisible(tester, find.text('Save routine'));
        expect(find.text('Litter box cleaning'), findsWidgets);

        await openSection(tester, 'History');
        expect(find.bySemanticsLabel(RegExp('Cost')), findsOneWidget);
        await tapVisible(tester, find.text('Yearly check and vaccinations at the clinic'));
        expect(find.byKey(const Key('record-cost-row')), findsOneWidget);
        await back(tester);

        await openSection(tester, 'Insights');
        expect(find.byKey(const Key('journal-behaviour-group')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Schedule, the dose sheet and the medicine and routine forms', (tester) async {
        await pump(tester);
        await openSection(tester, 'Schedule');
        expect(find.text('Needs review'), findsOneWidget);

        await tapVisible(tester, find.byKey(const ValueKey('record-p-joint-pm')));
        expect(find.byKey(const Key('dose-given-now')), findsOneWidget);
        await closeSheet(tester);

        await tapVisible(tester, find.byKey(const Key('done-today')));
        expect(find.byKey(const ValueKey('undo-p-breakfast')), findsOneWidget);

        await tapVisible(tester, find.byKey(const Key('schedule-add')));
        expect(find.text('Add to the schedule'), findsOneWidget);
        await closeSheet(tester);

        await tapVisible(tester, find.byKey(const ValueKey('medicine-m-joint')));
        expect(find.text('Edit medicine'), findsOneWidget);
        expect(find.text('Dose log'), findsOneWidget);
        await back(tester);

        await tapVisible(tester, find.byKey(const ValueKey('routine-p-brush')));
        expect(find.text('Edit routine'), findsOneWidget);
        await back(tester);

        await tapVisible(tester, find.byKey(const ValueKey('planned-r-rabies-due')));
        expect(find.text('Planned for'), findsOneWidget);
        await back(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('History, a record, its form and the attachment sheet', (tester) async {
        await pump(tester);
        await openSection(tester, 'History');
        expect(find.byKey(const Key('history-count')), findsOneWidget);

        await tapVisible(tester, find.text('Blood test results'));
        expect(find.text('blood-test.pdf'), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('detail-attach')));
        expect(find.text('Choose a PDF file'), findsOneWidget);
        await closeSheet(tester);

        await tester.tap(find.byTooltip('Edit record'));
        await tester.pumpAndSettle();
        expect(find.text('Edit record'), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('kind-vaccination')));
        expect(find.byKey(const Key('record-next-due')), findsOneWidget);
        await back(tester);
        await back(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Insights and the Quick log', (tester) async {
        await pump(tester);
        await openSection(tester, 'Insights');
        expect(find.byKey(const Key('weight-summary')), findsOneWidget);

        await tester.tap(find.byKey(const Key('quick-log-button')));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('quick-skin_coat')));
        expect(find.byKey(const ValueKey('level-different')), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('quick-weight')));
        expect(find.byKey(const Key('quick-weight-field')), findsOneWidget);
        await closeSheet(tester);

        await tapVisible(tester, find.byKey(const ValueKey('observation-o-mobility')));
        expect(find.text('Edit entry'), findsOneWidget);
        await closeSheet(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the empty states of a pet with nothing', (tester) async {
        await pump(tester);
        await selectPet(tester, 'Soya');
        expect(find.text('Start with one thing'), findsOneWidget);
        for (final (section, title) in [
          ('Schedule', 'Nothing scheduled yet'),
          ('History', 'No records yet'),
          ('Insights', 'Nothing logged yet'),
        ]) {
          await openSection(tester, section);
          expect(find.text(title), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('the chart and the back arrow follow a right-to-left layout', (tester) async {
    await pumpHealthHost(tester, const HealthScreen(), page: true, textDirection: TextDirection.rtl);

    // The summary's avatar sits at the start: the right-hand side.
    final card = tester.getRect(find.byKey(const Key('overview-pet')));
    final name = tester.getRect(
      find.descendant(of: find.byKey(const Key('overview-pet')), matching: find.text('Kelly')),
    );
    expect(name.right, lessThan(card.right - 56));

    await tapVisible(tester, find.text('Details'));
    final arrow = tester.getCenter(find.byTooltip('Back'));
    expect(arrow.dx, greaterThan(390 / 2));
  });

  testWidgets('the Overview keeps a slot for the Pets reminder under the pet summary', (tester) async {
    // The slot holds the Pets feature's reminder card, which draws nothing
    // for a pet whose essentials are all answered.
    expect(petReminderSlot(const Pet(id: 'kelly', name: 'Kelly')), isA<PetReminderCard>());

    await pumpHealthHost(
      tester,
      Consumer(
        builder: (context, ref, _) {
          final pet = ref.watch(selectedPetProvider);
          final data = ref.watch(petHealthDataProvider(pet.id)).value;
          if (data == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.all(20),
            child: OverviewSection(pet: pet, data: data, reminder: const Text('Reminder card goes here')),
          );
        },
      ),
    );

    final summary = tester.getRect(find.byKey(const Key('overview-pet')));
    final reminder = tester.getRect(find.text('Reminder card goes here'));
    final comingUp = tester.getRect(find.byKey(const Key('overview-coming-up')));
    expect(reminder.top, greaterThanOrEqualTo(summary.bottom));
    expect(reminder.bottom, lessThanOrEqualTo(comingUp.top));
  });

  testWidgets('the tab works in the app as shipped, on the sample data', (tester) async {
    // No Health overrides at all: the default repository (with its delay)
    // and the sample-data clock, which treats 10.06.25 as today.
    await pumpApp(tester);
    await signInAsDemo(tester);
    await openHealthTab(tester);

    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('General check'), findsOneWidget);
    expect(find.text('Thu 12.06.25 · 18:20 · Park Vet Clinic'), findsOneWidget);
    expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);

    await openSection(tester, 'Schedule');
    expect(find.textContaining('Tue 10 June'), findsOneWidget);
    await openSection(tester, 'History');
    expect(find.text('12 records'), findsOneWidget);
    await openSection(tester, 'Insights');
    expect(find.text('01.06.25 · 6 weigh-ins'), findsOneWidget);
  });
}
