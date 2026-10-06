import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/care/data/care_repository.dart';
import 'package:pet_companion/features/community/community_screen.dart';
import 'package:pet_companion/features/community/guides/guide_reader_screen.dart';
import 'package:pet_companion/features/community/guides/guides_section.dart';
import 'package:pet_companion/features/firstdays/firstdays.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/health_screen.dart';
import 'package:pet_companion/features/health/records/record_form_screen.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';
import 'package:pet_companion/features/store/store_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import '../helpers.dart';
import '../pets/pets_test_helpers.dart' as pets;

/// The sample day, in the afternoon: Soya is on day 10 of her first 30 days.
final afternoon = DateTime(2025, 6, 10, 15);

final card = find.byKey(FirstDaysHomeCard.cardKey);
final page = find.byKey(FirstDaysScreen.screenKey);

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)), listen: false);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Signs in on the demo account at [now] and selects Soya on Home.
Future<void> homeOnSoya(
  WidgetTester tester, {
  DateTime? now,
  AppLanguage? language,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await pumpApp(tester, now: now ?? afternoon, language: language);
  await signInAsDemo(tester);
  await tester.tap(find.text('Soya'));
  await tester.pumpAndSettle();
  // Signed in on a regular phone (the form needs its height), then the
  // screen under test.
  if (size != const Size(390, 844)) tester.view.physicalSize = size * 3;
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpAndSettle();
}

Future<void> openPageFromCard(WidgetTester tester) => tapVisible(tester, find.byKey(FirstDaysHomeCard.openKey));

/// What [repo] holds for [petId] (read outside the test's fake clock).
Future<FirstDaysPath?> stored(WidgetTester tester, FakeFirstDaysRepository repo, String petId) async =>
    tester.runAsync<FirstDaysPath?>(() => repo.fetch(petId));

Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Back').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Home card', () {
    testWidgets('shows for Soya on day 10 with her progress and next task, not for Kelly', (tester) async {
      await pumpApp(tester, now: afternoon);
      await signInAsDemo(tester);
      // Kelly has no first 30 days.
      expect(card, findsNothing);

      await tester.tap(find.text('Soya'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(card);
      expect(find.text('The first 30 days of Soya'), findsOneWidget);
      expect(find.text('Day 10'), findsOneWidget);
      expect(find.text('2/12'), findsOneWidget);
      expect(find.text('Next: Get the basics: a bed, bowls, a lead and food'), findsOneWidget);
    });

    testWidgets('still shows on day 30, and is gone from day 31', (tester) async {
      await homeOnSoya(tester, now: DateTime(2025, 6, 30, 9));
      await tester.ensureVisible(card);
      expect(find.text('Day 30'), findsOneWidget);

      await homeOnSoya(tester, now: DateTime(2025, 7, 1, 9));
      expect(card, findsNothing);
    });

    testWidgets('"Open" leads to the page', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);
      expect(page, findsOneWidget);
      expect(find.text('The first 30 days · Soya'), findsOneWidget);
      expect(find.text('Arrived home 01.06.25'), findsOneWidget);
      expect(find.text('Day 10 of 30'), findsOneWidget);
      expect(find.text('2/12 done'), findsOneWidget);
      expect(find.text('First week'), findsOneWidget);
      await tester.ensureVisible(find.text('Weeks 2–4'));
      expect(find.text('Weeks 2–4'), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('a tick toggles a task by hand, and Home follows', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);

      await tapVisible(tester, find.byKey(FirstDaysScreen.tickKey('dog-basics')));
      expect(find.text('3/12 done'), findsOneWidget);
      await goBack(tester);
      await tester.ensureVisible(card);
      expect(find.text('3/12'), findsOneWidget);
      expect(find.text('Next: Keep to the food they know for now, and add it here'), findsOneWidget);

      await openPageFromCard(tester);
      await tapVisible(tester, find.byKey(FirstDaysScreen.tickKey('dog-basics')));
      expect(find.text('2/12 done'), findsOneWidget);
    });

    testWidgets('a vet visit added in Health ticks the first check-up by itself', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);
      expect(find.text('Done in the app'), findsNothing);

      // Not awaited: the fake answers while the tester pumps.
      final saving = containerOf(tester)
          .read(healthRecordsProvider('soya').notifier)
          .save(
            HealthRecord(
              id: '',
              petId: 'soya',
              kind: RecordKind.checkup,
              title: 'First check',
              scheduledAt: DateTime(2025, 6, 9, 10),
              doneAt: DateTime(2025, 6, 9, 10),
            ),
          );
      await tester.pumpAndSettle();
      await saving;
      expect(find.text('3/12 done'), findsOneWidget);
      expect(find.text('Done in the app'), findsOneWidget);
      // The app's tick is not the owner's to take back.
      await tester.ensureVisible(find.byKey(FirstDaysScreen.tickKey('first-vet')));
      await tester.tap(find.byKey(FirstDaysScreen.tickKey('first-vet')));
      await tester.pumpAndSettle();
      expect(find.text('3/12 done'), findsOneWidget);
    });

    testWidgets('pills open the screen that does the task, and back returns to the page', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);

      Future<void> openAndReturn(String taskId, Finder screen) async {
        await tapVisible(tester, find.byKey(FirstDaysScreen.actionKey(taskId)));
        expect(screen, findsOneWidget, reason: taskId);
        await goBack(tester);
        expect(page, findsOneWidget, reason: taskId);
      }

      await openAndReturn('meal-times', find.byKey(FeedingScreen.screenKey));
      await openAndReturn('walk-times', find.byKey(ActivityScreen.screenKey));
      await openAndReturn('food', find.byType(FoodSettingsScreen));
      await openAndReturn('first-vet', find.byType(RecordFormScreen));
      await openAndReturn('microchip', find.byType(HealthProfileScreen));
      await openAndReturn('dog-guide', find.text("Your puppy's first week at home"));
      expect(find.byType(GuideReaderScreen), findsNothing);
    });

    testWidgets('"Deals" leaves for the Store on what suits the pet', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);
      await tapVisible(tester, find.byKey(FirstDaysScreen.actionKey('dog-basics')));

      expect(page, findsNothing);
      expect(find.byType(StoreScreen), findsOneWidget);
      final container = containerOf(tester);
      expect(container.read(selectedPetProvider).id, 'soya');
      expect(container.read(storeFilterProvider).allAnimals, isFalse);
      expect(container.read(storeFilterProvider).category, isNull);
    });

    testWidgets('"Schedule" leaves for the Health schedule of the pet', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);
      await tapVisible(tester, find.byKey(FirstDaysScreen.actionKey('vaccines')));

      expect(page, findsNothing);
      expect(find.byType(HealthScreen), findsOneWidget);
      expect(containerOf(tester).read(healthSectionProvider), HealthSection.schedule);
    });

    testWidgets('another kind of animal has the shorter list, and "Guides" opens the guides library', (tester) async {
      await homeOnSoya(tester);
      final container = containerOf(tester);
      final soya = container.read(selectedPetProvider);
      container.read(petsProvider.notifier).update(soya.copyWith(species: PetSpecies.rabbit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(card);
      // Soya's ticks were a dog's tasks: none is on a rabbit's list.
      expect(find.text('0/7'), findsOneWidget);
      await openPageFromCard(tester);
      expect(find.text('Set up their home: a cage, tank or corner, with food and water'), findsOneWidget);
      expect(find.byKey(FirstDaysScreen.tickKey('dog-basics')), findsNothing);

      await tapVisible(tester, find.byKey(FirstDaysScreen.actionKey('guides')));
      expect(page, findsNothing);
      expect(find.byType(GuidesSection), findsOneWidget);
      expect(container.read(communityGuidesRequestProvider), isFalse);
      // The Community tab also loads its activity and blocked members on
      // the demo backend's short delay: let them answer.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('"Close" asks first, then the page is a summary and the Home card is gone', (tester) async {
      await homeOnSoya(tester);
      await openPageFromCard(tester);

      await tapVisible(tester, find.byKey(FirstDaysScreen.closeKey));
      expect(find.text('Close the first 30 days?'), findsOneWidget);
      await tapVisible(tester, find.text('Cancel'));
      expect(find.text('Day 10 of 30'), findsOneWidget);

      await tapVisible(tester, find.byKey(FirstDaysScreen.closeKey));
      await tapVisible(tester, find.text('Close'));
      expect(find.text('Closed on 10.06.25'), findsOneWidget);
      expect(find.text('A look back at the first 30 days.'), findsOneWidget);
      expect(find.byKey(FirstDaysScreen.closeKey), findsNothing);
      expect(find.byKey(FirstDaysScreen.actionKey('food')), findsNothing);
      // Read only: the ticks do nothing.
      await tapVisible(tester, find.byKey(FirstDaysScreen.tickKey('dog-basics')));
      expect(find.text('2/12 done'), findsOneWidget);

      await goBack(tester);
      expect(card, findsNothing);
    });
  });

  group('starting', () {
    pets.PetsHarness harness(FakeFirstDaysRepository repo) => pets.PetsHarness(
      extra: [
        firstDaysRepositoryProvider.overrideWithValue(repo),
        careRepositoryProvider.overrideWithValue(FakeCareRepository(latency: Duration.zero)),
      ],
    );

    testWidgets('from add-a-pet: "Just arrived home?" with the day, and the card on Home', (tester) async {
      final repo = FakeFirstDaysRepository(latency: Duration.zero);
      await pets.openFlowFromWelcome(tester, harness: harness(repo));
      await pets.createPet(tester, name: 'Mitzi', kind: PetSpecies.cat);
      final id = pets.petNamed(tester, 'Mitzi').id;

      expect(find.text('Just arrived home?'), findsOneWidget);
      expect(find.byKey(ArrivalQuestion.dayKey), findsNothing);
      await tapVisible(tester, find.byKey(ArrivalQuestion.yesKey));
      expect(find.text('10.06.2025'), findsOneWidget);

      // Another day from the picker.
      await tapVisible(tester, find.byKey(ArrivalQuestion.dayKey));
      await tester.tap(find.text('8'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('08.06.2025'), findsOneWidget);

      await tapVisible(tester, find.text('Continue'));
      expect(find.text('About Mitzi'), findsNothing);
      expect((await stored(tester, repo, id))!.arrivedOn, DateTime(2025, 6, 8));

      // Back to step 2: "No" takes the path back.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(ArrivalQuestion.noKey));
      await tapVisible(tester, find.text('Continue'));
      expect(await stored(tester, repo, id), isNull);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(ArrivalQuestion.yesKey));
      await tapVisible(tester, find.text('Continue'));
      await tester.tap(find.text('Finish later'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(card);
      expect(find.text('The first 30 days of Mitzi'), findsOneWidget);
      // The day picked before is kept: 8 June, so 10 June is day 3.
      expect(find.text('Day 3'), findsOneWidget);
      expect(find.text('0/11'), findsOneWidget);
      expect(find.text('Next: Get the basics: a litter box, bowls and food'), findsOneWidget);
    });

    testWidgets('from add-a-pet: no answer starts nothing', (tester) async {
      final repo = FakeFirstDaysRepository(latency: Duration.zero);
      await pets.openFlowFromWelcome(tester, harness: harness(repo));
      await pets.createPet(tester, name: 'Mitzi', kind: PetSpecies.cat);
      await tapVisible(tester, find.text('Continue'));
      expect(await stored(tester, repo, pets.petNamed(tester, 'Mitzi').id), isNull);
    });

    testWidgets('from the profile of a pet that never had them, and the profile follows', (tester) async {
      final repo = FakeFirstDaysRepository(latency: Duration.zero);
      await pets.pumpPetsApp(tester, harness: harness(repo));
      await tester.longPress(find.text('Kelly').first);
      await tester.pumpAndSettle();

      expect(find.text('The first 30 days'), findsOneWidget);
      await tapVisible(tester, find.byKey(FirstDaysProfileEntry.startKey));
      expect(find.text('Arrival day'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(page, findsOneWidget);
      expect(find.text('The first 30 days · Kelly'), findsOneWidget);
      expect(find.text('Day 1 of 30'), findsOneWidget);
      // Kelly's food, meal times and walk times are already in the app.
      expect(find.text('Done in the app'), findsAtLeastNWidgets(3));
      expect((await stored(tester, repo, 'kelly'))!.arrivedOn, DateTime(2025, 6, 10));

      await goBack(tester);
      expect(find.byKey(FirstDaysProfileEntry.startKey), findsNothing);
      await tester.ensureVisible(find.byKey(FirstDaysProfileEntry.openKey));
      expect(find.text('Day 1 of 30'), findsOneWidget);
    });

    testWidgets('the profile of a pet on its way shows the day and leads to the page, then to the summary', (
      tester,
    ) async {
      final repo = FakeFirstDaysRepository(latency: Duration.zero);
      await pets.pumpPetsApp(tester, harness: harness(repo));
      await tester.longPress(find.text('Soya').first);
      await tester.pumpAndSettle();

      expect(find.byKey(FirstDaysProfileEntry.startKey), findsNothing);
      await tester.ensureVisible(find.byKey(FirstDaysProfileEntry.openKey));
      expect(find.text('Day 10 of 30'), findsOneWidget);
      expect(find.text('2/12 done'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      await tapVisible(tester, find.byKey(FirstDaysProfileEntry.openKey));
      await tapVisible(tester, find.byKey(FirstDaysScreen.closeKey));
      await tapVisible(tester, find.text('Close'));
      await goBack(tester);

      await tester.ensureVisible(find.byKey(FirstDaysProfileEntry.openKey));
      expect(find.text('Closed on 10.06.25'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      await tapVisible(tester, find.byKey(FirstDaysProfileEntry.openKey));
      expect(find.text('A look back at the first 30 days.'), findsOneWidget);
    });
  });

  group('Hebrew and small screens', () {
    testWidgets('the card and the page read in Hebrew, right to left', (tester) async {
      await homeOnSoya(tester, language: AppLanguage.hebrew);
      await tester.ensureVisible(card);
      expect(find.text('30 הימים הראשונים של \u2068Soya\u2069'), findsOneWidget);
      expect(find.text('יום \u206810\u2069'), findsOneWidget);
      expect(find.text('הבא בתור: \u2068לדאוג לבסיס: מיטה, קערות, רצועה ומזון\u2069'), findsOneWidget);
      expect(find.text('פתיחה'), findsOneWidget);
      expect(Directionality.of(tester.element(card)), TextDirection.rtl);

      await openPageFromCard(tester);
      expect(find.text('30 הימים הראשונים · \u2068Soya\u2069'), findsOneWidget);
      expect(find.text('יום \u206810\u2069 מתוך \u206830\u2069'), findsOneWidget);
      expect(find.text('\u20682/12\u2069 בוצעו'), findsOneWidget);
      expect(find.text('השבוע הראשון'), findsOneWidget);
      expect(find.text('מבצעים'), findsOneWidget);
      expect(find.text('לקבוע שעות קבועות לארוחות'), findsOneWidget);
      await tester.ensureVisible(find.text('סגירת 30 הימים הראשונים'));
      expect(find.text('שבועות 2–4'), findsOneWidget);
    });

    for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
      testWidgets('fits a small phone with large text (${language.name})', (tester) async {
        await homeOnSoya(tester, language: language, size: const Size(320, 568), textScale: 1.3);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await openPageFromCard(tester);
        await tester.ensureVisible(find.byKey(FirstDaysScreen.closeKey));
        // An overflow anywhere on the way fails the test by itself.
        await tester.pumpAndSettle();
      });
    }
  });
}
