import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/health/emergency/emergency_button.dart';
import 'package:pet_companion/features/health/emergency/health_profile_form.dart';
import 'package:pet_companion/features/health/emergency/lost_pet_card_screen.dart';
import 'package:pet_companion/features/health/emergency/vet_form_screen.dart';
import 'package:pet_companion/features/health/records/record_form_screen.dart';
import 'package:pet_companion/features/health/schedule/medicine_form_screen.dart';
import 'package:pet_companion/features/health/schedule/routine_form_screen.dart';
import 'package:pet_companion/features/pets/profile/pet_profile_screen.dart';
import 'package:pet_companion/features/store/share_deal_screen.dart';

import '../health/health_test_helpers.dart';
import '../helpers.dart';
import '../store/store_test_helpers.dart' show pumpStore;

/// Every edit page asks before it drops typed changes: going back with
/// nothing changed leaves at once, going back with a change asks "Discard
/// changes?", and saving never asks.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final dialog = find.text('Discard changes?');

  /// The phone's back button.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, String button) async {
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
  }

  /// Checks the whole rule on one page. [open] shows the page (found by
  /// [page]) with its fields as stored; [edit] changes something; [save]
  /// changes something and saves.
  Future<void> checkPage(
    WidgetTester tester, {
    required Future<void> Function() open,
    required Finder page,
    required Future<void> Function() edit,
    required Finder edited,
    required Future<void> Function() save,
  }) async {
    // Nothing changed: back leaves without a question.
    await open();
    expect(page, findsOneWidget);
    await pressBack(tester);
    expect(dialog, findsNothing);
    expect(page, findsNothing);

    // A change: back asks. "Keep editing" stays, with the change intact.
    await open();
    await edit();
    await tester.pump();
    await pressBack(tester);
    expect(dialog, findsOneWidget);
    expect(find.text('Your changes will not be saved.'), findsOneWidget);
    await answer(tester, 'Keep editing');
    expect(dialog, findsNothing);
    expect(page, findsOneWidget);
    expect(edited, findsOneWidget);

    // Asked again, "Discard" leaves.
    await pressBack(tester);
    expect(dialog, findsOneWidget);
    await answer(tester, 'Discard');
    expect(page, findsNothing);

    // Saving never asks.
    await open();
    await save();
    expect(dialog, findsNothing);
  }

  Future<void> tapText(WidgetTester tester, String text) => tapVisible(tester, find.text(text));

  testWidgets('food and portion', (tester) async {
    await pumpApp(tester, now: DateTime(2025, 6, 10, 15));
    await signInAsDemo(tester);
    await tapText(tester, 'Feeding');
    final page = find.byType(FoodSettingsScreen);

    await checkPage(
      tester,
      open: () => tapText(tester, 'Adult dry food'),
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('food-kcal')), '410'),
      edited: find.text('410'),
      save: () async {
        await tester.enterText(find.byKey(const Key('food-kcal')), '420');
        await tapVisible(tester, find.byKey(const Key('food-save')));
        expect(page, findsNothing);
      },
    );
    expect(find.text('420 cal per 100 g · 140 g a meal'), findsOneWidget);
  });

  testWidgets('a new medicine, and the header arrow asks too', (tester) async {
    await pumpHealth(tester);
    await openSection(tester, 'Schedule');
    final page = find.byType(MedicineFormScreen);
    Future<void> open() async {
      await tapVisible(tester, find.byKey(const Key('schedule-add')));
      await tapVisible(tester, find.byKey(const ValueKey('add-medicine')));
    }

    await checkPage(
      tester,
      open: open,
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('medicine-name')), 'Ear drops'),
      edited: find.text('Ear drops'),
      save: () async {
        await tester.enterText(find.byKey(const Key('medicine-name')), 'Calming drops');
        await tapText(tester, 'Save medicine');
        expect(page, findsNothing);
      },
    );
    expect(find.text('Calming drops'), findsOneWidget);

    // The arrow in the header, and a choice (not typed text) as the change.
    await open();
    await tapVisible(tester, find.byKey(const ValueKey('route-In the ear')));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(dialog, findsOneWidget);
    await answer(tester, 'Keep editing');
    expect(page, findsOneWidget);

    // Undoing the change undoes the question.
    await tapVisible(tester, find.byKey(const ValueKey('route-In the ear')));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(page, findsNothing);
  });

  testWidgets('a record', (tester) async {
    await pumpHealth(tester);
    await openSection(tester, 'History');
    final page = find.byType(RecordFormScreen);

    await checkPage(
      tester,
      open: () => tapText(tester, 'Add record'),
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('record-title')), 'Nail trim'),
      edited: find.text('Nail trim'),
      save: () async {
        await tester.enterText(find.byKey(const Key('record-title')), 'Ear check');
        await tapText(tester, 'Save record');
        expect(page, findsNothing);
      },
    );
    expect(find.text('Ear check'), findsOneWidget);
  });

  testWidgets('editing a vet', (tester) async {
    await pumpHealth(tester);
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    await tapText(tester, "Open Kelly's Emergency card");
    await tapText(tester, "Kelly's vets");
    final page = find.byType(VetFormScreen);

    await checkPage(
      tester,
      open: () => tapVisible(tester, find.byKey(const ValueKey('edit-vet-regular'))),
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('vet-name')), 'Green Street Vets'),
      edited: find.text('Green Street Vets'),
      save: () async {
        await tester.enterText(find.byKey(const Key('vet-name')), 'Riverside Vets');
        await tapText(tester, 'Save vet');
        expect(page, findsNothing);
      },
    );
    expect(find.text('Riverside Vets'), findsOneWidget);
  });

  testWidgets('a new routine', (tester) async {
    await pumpHealth(tester);
    await openSection(tester, 'Schedule');
    final page = find.byType(RoutineFormScreen);

    await checkPage(
      tester,
      open: () async {
        await tapVisible(tester, find.byKey(const Key('schedule-add')));
        await tapVisible(tester, find.byKey(const ValueKey('add-routine')));
      },
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('routine-title')), 'Brush teeth'),
      edited: find.text('Brush teeth'),
      save: () async {
        await tester.enterText(find.byKey(const Key('routine-title')), 'Ear cleaning');
        await tapText(tester, 'Save routine');
        expect(page, findsNothing);
      },
    );
  });

  testWidgets("Health's profile page, from the emergency kit", (tester) async {
    await pumpHealth(tester);
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
    final page = find.byType(HealthProfileScreen);

    await checkPage(
      tester,
      open: () => tapVisible(tester, find.byKey(const Key('kit-open-profile'))),
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('profile-microchip')), '900 111 222'),
      edited: find.text('900 111 222'),
      save: () async {
        await tester.enterText(find.byKey(const Key('profile-microchip')), '900 333 444');
        await tapText(tester, 'Save profile');
        expect(page, findsNothing);
      },
    );
  });

  testWidgets('the lost card: sharing keeps the card, so back leaves', (tester) async {
    await pumpHealth(tester);
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    final page = find.byType(LostPetCardScreen);

    await checkPage(
      tester,
      open: () => tapVisible(tester, find.byKey(const Key('open-lost-card'))),
      page: page,
      edit: () => tester.enterText(find.byKey(const Key('lost-description')), 'Red collar'),
      // In the field (the card's preview shows it too).
      edited: find.descendant(of: find.byKey(const Key('lost-description')), matching: find.text('Red collar')),
      save: () async {
        await tester.enterText(find.byKey(const Key('lost-description')), 'Blue collar');
        await tester.enterText(find.byKey(const Key('lost-phone')), '+972 54 555 0100');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
        await tapText(tester, 'Share as image');
        // Sharing keeps the card as written: nothing is left to lose.
        expect(page, findsOneWidget);
        await pressBack(tester);
        expect(page, findsNothing);
      },
    );
  });

  testWidgets("the pet's profile", (tester) async {
    await pumpApp(tester, now: DateTime(2025, 6, 10, 15));
    await signInAsDemo(tester);
    final page = find.byType(PetProfileScreen);
    final name = find.byKey(const Key('pet-name'));

    await checkPage(
      tester,
      open: () async {
        // A long press on the pet's pill on Home.
        await tester.longPress(find.text('Kelly').first);
        await tester.pumpAndSettle();
      },
      page: page,
      edit: () => tester.enterText(name, 'Kelly Bean'),
      edited: find.text('Kelly Bean'),
      save: () async {
        // The profile saves in place: once saved, back leaves at once.
        await tester.enterText(name, 'Kells');
        await tapText(tester, 'Save changes');
        expect(page, findsOneWidget);
        await pressBack(tester);
        expect(dialog, findsNothing);
        expect(page, findsNothing);
      },
    );
    expect(find.text('Kells'), findsWidgets);
  });

  testWidgets('sharing a deal', (tester) async {
    final store = await pumpStore(tester);
    final page = find.byType(ShareDealScreen);
    final before = (await store.fetchDeals()).length;
    Future<void> fill(String field, String text) => tester.enterText(find.byKey(Key('share-$field')), text);

    await checkPage(
      tester,
      open: () => tapText(tester, 'Share a deal'),
      page: page,
      edit: () => fill('title', 'Chicken jerky strips'),
      edited: find.text('Chicken jerky strips'),
      save: () async {
        await fill('title', 'Chicken jerky strips, 300 g');
        await tapVisible(tester, find.byKey(const Key('share-category')));
        await tester.tap(find.text('Treats').last);
        await tester.pumpAndSettle();
        await fill('price', '22');
        await fill('original-price', '36');
        await fill('seller', 'The Treat Jar');
        await fill('link', 'https://example.com/jerky');
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Share deal'));
        expect(page, findsNothing);
      },
    );
    expect((await store.fetchDeals()).length, before + 1);
  });
}
