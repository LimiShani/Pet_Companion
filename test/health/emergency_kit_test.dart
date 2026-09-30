import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart' show KitCheck;
import 'package:pet_companion/features/health/data/health_rows.dart' show kitCheckFromRow, kitCheckToRow;
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/models/pet.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';
  const soya = 'soya';

  /// The emergency sheet of [petId], opened the way another tab opens it.
  Future<HealthHarness> openSheet(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await pumpHealthHost(
      tester,
      Row(children: [EmergencyButton(petId: petId, onCoral: false)]),
      harness: harness,
    );
    await tester.tap(find.byType(EmergencyButton));
    await tester.pumpAndSettle();
    return h;
  }

  Future<HealthHarness> openKit(WidgetTester tester, String petId, {HealthHarness? harness}) async {
    final h = await openSheet(tester, petId, harness: harness);
    await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
    return h;
  }

  bool ticked(WidgetTester tester, String item) => tester.widget<Checkbox>(find.byKey(ValueKey('kit-$item'))).value!;

  Future<Map<KitItem, KitCheck>> stored(WidgetTester tester, HealthHarness h, String petId) async => {
    for (final check in await real(tester, () => h.repository.fetchKit(petId))) check.item: check,
  };

  group('Emergency kit', () {
    testWidgets('is one tap from the emergency sheet, with its count', (tester) async {
      await openSheet(tester, kelly);

      expect(find.text('Emergency kit'), findsOneWidget);
      expect(find.text('3 of 6 ready'), findsOneWidget);
      // The contacts still come first.
      final call = tester.getTopLeft(find.byKey(const ValueKey('call-regular'))).dy;
      final kit = tester.getTopLeft(find.byKey(const Key('open-emergency-kit'))).dy;
      expect(call, lessThan(kit));

      await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
      expect(find.text("Kelly's emergency kit"), findsOneWidget);
      expect(find.text('3 of 6 ready'), findsOneWidget);
      expect(find.text('For sirens, a quick move to the protected room, or leaving home in a hurry.'), findsOneWidget);

      // Six items for a dog on a medicine, in the order of the checklist.
      for (final title in [
        'Carrier or crate, lead and harness',
        'Food and water for three days',
        'Documents',
        'Microchip details up to date',
        'Medicines',
        'A plan for the protected room',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('Vaccination booklet and licence, on paper or as photos.'), findsOneWidget);
      expect(find.text('985 112 004 567 321 · your phone number in the chip registry is current.'), findsOneWidget);
      expect(find.text('Joint tablets 50 mg · a spare supply in the kit.'), findsOneWidget);
      expect(find.text('Who takes Kelly, and where the carrier is.'), findsOneWidget);

      // Ticks are remembered with their date.
      expect(ticked(tester, 'carrier'), isTrue);
      expect(ticked(tester, 'foodWater'), isFalse);
      expect(find.text('Ticked 02.06.25'), findsNWidgets(2));
      expect(find.text('Ticked 28.05.25'), findsOneWidget);

      // The owner's list, not instructions.
      expect(find.textContaining('Your own list, not official guidance'), findsOneWidget);
    });

    testWidgets('an item is ticked and unticked, and the count follows everywhere', (tester) async {
      final h = await openKit(tester, kelly);

      await tapVisible(tester, find.byKey(const ValueKey('kit-foodWater')));
      expect(ticked(tester, 'foodWater'), isTrue);
      expect(find.text('4 of 6 ready'), findsOneWidget);
      expect(find.text('Ticked 10.06.25'), findsOneWidget);
      expect((await stored(tester, h, kelly))[KitItem.foodWater]!.checkedAt, fixedNow);

      await tapVisible(tester, find.byKey(const ValueKey('kit-carrier')));
      expect(ticked(tester, 'carrier'), isFalse);
      expect(find.text('3 of 6 ready'), findsOneWidget);
      expect((await stored(tester, h, kelly))[KitItem.carrier]!.checkedAt, isNull);

      // Back on the sheet the row already shows the new count.
      await tapVisible(tester, find.byKey(const ValueKey('kit-carrier')));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      expect(find.text('4 of 6 ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the plan for the protected room keeps a short note', (tester) async {
      final h = await openKit(tester, kelly);

      await tester.ensureVisible(find.byKey(const Key('kit-plan-note')));
      await tester.enterText(find.byKey(const Key('kit-plan-note')), 'Dana takes Kelly, lead by the door');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      var plan = (await stored(tester, h, kelly))[KitItem.shelterPlan]!;
      expect(plan.note, 'Dana takes Kelly, lead by the door');
      expect(plan.isReady, isFalse);

      // Ticking the item keeps the note.
      await tapVisible(tester, find.byKey(const ValueKey('kit-shelterPlan')));
      plan = (await stored(tester, h, kelly))[KitItem.shelterPlan]!;
      expect(plan.isReady, isTrue);
      expect(plan.note, 'Dana takes Kelly, lead by the door');
      expect(find.text('4 of 6 ready'), findsOneWidget);
    });

    testWidgets('a pet without medicines has five items, and nothing is pre-ticked', (tester) async {
      await openKit(tester, soya);

      expect(find.text("Soya's emergency kit"), findsOneWidget);
      expect(find.text('0 of 5 ready'), findsOneWidget);
      expect(find.text('Medicines'), findsNothing);
      expect(find.text('No microchip number saved yet.'), findsOneWidget);
      expect(find.byKey(const Key('kit-open-documents')), findsNothing);
      expect(find.textContaining('Ticked'), findsNothing);

      for (final item in ['carrier', 'foodWater', 'documents', 'microchip', 'shelterPlan']) {
        await tapVisible(tester, find.byKey(ValueKey('kit-$item')));
      }
      expect(find.text('All 5 ready'), findsOneWidget);
    });

    testWidgets('the wording follows the animal', (tester) async {
      final h = HealthHarness(
        repository: fakeHealth(seeded: false),
        pets: const [Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat)],
      );
      await openKit(tester, 'mitzi', harness: h);

      expect(find.text('Carrier'), findsOneWidget);
      expect(find.text('Vaccination booklet and vet papers, on paper or as photos.'), findsOneWidget);
      expect(find.textContaining('licence'), findsNothing);
      expect(find.text('Who takes Mitzi, and where the carrier is.'), findsOneWidget);
    });

    testWidgets('two items lead to where the facts already live', (tester) async {
      await openKit(tester, kelly);

      await tapVisible(tester, find.byKey(const Key('kit-open-documents')));
      expect(find.text("Kelly's documents"), findsOneWidget);
      expect(find.text('Rabies booster · 14.03.25'), findsOneWidget);
      expect(find.text('vaccination-booklet.png'), findsOneWidget);
      expect(find.text('blood-test.pdf'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tapVisible(tester, find.byKey(const Key('kit-open-profile')));
      expect(find.text("Kelly's health profile"), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      // Opening a link is not a tick.
      expect(find.text('3 of 6 ready'), findsOneWidget);
    });

    testWidgets('a tick that cannot be stored is put back, with the reason', (tester) async {
      final h = await openKit(tester, kelly);

      h.repository.failing = true;
      await tapVisible(tester, find.byKey(const ValueKey('kit-foodWater')));
      expect(find.text('Could not reach the server. Check your connection and try again.'), findsOneWidget);
      expect(ticked(tester, 'foodWater'), isFalse);
      expect(find.text('3 of 6 ready'), findsOneWidget);
    });

    testWidgets('a load error offers to try again', (tester) async {
      final h = HealthHarness();
      h.repository.failing = true;
      await pumpHealthHost(tester, const SizedBox(height: 10), harness: h);
      openEmergencyKit(tester.element(find.byType(SizedBox).first), kelly).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Could not load the emergency kit'), findsOneWidget);

      h.repository.failing = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 6 ready'), findsOneWidget);
    });

    testWidgets('is also on the Emergency card, and readable by other tabs', (tester) async {
      await openSheet(tester, kelly);
      await tapVisible(tester, find.text("Open Kelly's Emergency card"));
      expect(find.text('Emergency card'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('open-emergency-kit')));
      expect(find.text('3 of 6 ready'), findsOneWidget);

      final kit = (await settled(tester, emergencyKitProvider(kelly))).value!;
      expect(kit.ready, 3);
      expect(kit.total, 6);
      expect(kit.isComplete, isFalse);
      expect(kit.entries.map((e) => e.item), KitItem.values);

      final empty = (await settled(tester, emergencyKitProvider(soya))).value!;
      expect(empty.ready, 0);
      expect(empty.total, 5);
    });

    testWidgets('a vet edited from the kit path never breaks the pages below', (tester) async {
      await openKit(tester, kelly);
      await tapVisible(tester, find.byKey(const Key('kit-open-profile')));
      await tester.enterText(find.byKey(const Key('profile-microchip')), '900 111 222');
      await tapVisible(tester, find.text('Save profile'));

      // Back on the kit, the item shows the new number.
      expect(find.text("Kelly's emergency kit"), findsOneWidget);
      expect(find.text('900 111 222 · your phone number in the chip registry is current.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('kit rows', () {
    test('an answer keeps its item, date and note', () {
      final check = KitCheck(
        petId: 'p',
        item: KitItem.shelterPlan,
        checkedAt: DateTime(2025, 6, 10, 17, 40),
        note: 'Dana takes Kelly',
      );
      final row = kitCheckToRow(check);
      expect(row['item'], 'shelter_plan');
      final back = kitCheckFromRow(row)!;
      expect(back.item, KitItem.shelterPlan);
      expect(back.checkedAt, check.checkedAt);
      expect(back.note, 'Dana takes Kelly');

      expect(kitCheckFromRow({...kitCheckToRow(const KitCheck(petId: 'p', item: KitItem.carrier))})!.isReady, isFalse);
      // A row of an item from a newer version is skipped, not an error.
      expect(kitCheckFromRow({'pet_id': 'p', 'item': 'raincoat', 'checked_at': null, 'note': ''}), isNull);
    });
  });
}
