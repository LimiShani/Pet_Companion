import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/home/widgets/home_header.dart';
import 'package:pet_companion/theme/app_colors.dart';
import 'package:pet_companion/widgets/pet_selector.dart';

import 'home_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Closes the open bottom sheet by tapping the dimmed page above it.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
  }

  group('the Emergency pill on Home', () {
    testWidgets('is shown for the selected pet, in the top bar', (tester) async {
      await pumpHome(tester);

      // One pill, Health's own widget, in its labelled on-coral form.
      expect(emergencyPill, findsOneWidget);
      expect(find.descendant(of: topBar, matching: emergencyPill), findsOneWidget);
      final pill = tester.widget<EmergencyButton>(emergencyPill);
      expect(pill.petId, kellyId);
      expect(pill.compact, isFalse);
      expect(pill.onCoral, isTrue);
      expect(pill.showStatusDot, isTrue);

      // The word, in dark coral, and a label that names the pet.
      expect(find.text('Emergency'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Emergency')).style?.color, AppColors.coralDark);
      expect(find.bySemanticsLabel('Emergency contacts for Kelly'), findsOneWidget);

      // A full-size target, fully on screen.
      final rect = tester.getRect(emergencyPill);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));
      expect(tester.getRect(topBar).contains(rect.topLeft), isTrue);
      expect(tester.getRect(topBar).contains(rect.bottomRight), isTrue);
      expect(emergencyPill.hitTestable(), findsOneWidget);
    });

    testWidgets('one tap opens the emergency actions, a second tap calls the vet', (tester) async {
      final launcher = await pumpHome(tester);

      await tapAndSettle(tester, emergencyPill);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      // The first tap only opens the sheet: nothing is dialled yet.
      expect(launcher.calls, isEmpty);

      await tapAndSettle(tester, find.byKey(const ValueKey('call-regular')));
      expect(launcher.calls, hasLength(1));
      expect(launcher.calls.single.action, ContactAction.call);
      expect(launcher.calls.single.target, kellyVetPhone);
    });

    testWidgets('acts for whichever pet is selected', (tester) async {
      final launcher = await pumpHome(tester);

      await tapAndSettle(tester, find.text('Soya'));
      expect(pillPetId(tester), soyaId);
      expect(find.bySemanticsLabel(RegExp('^Emergency contacts for Soya')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Emergency contacts for Kelly')), findsNothing);

      await tapAndSettle(tester, emergencyPill);
      expect(find.text('Emergency · Soya'), findsOneWidget);
      expect(find.text('No vet saved for Soya yet'), findsOneWidget);
      expect(find.text('Emergency · Kelly'), findsNothing);
      expect(find.byKey(const ValueKey('call-regular')), findsNothing);
      await closeSheet(tester);
      expect(find.text('Emergency · Soya'), findsNothing);

      // And back again: Kelly is the selector pill only, Soya fills the hero.
      await tapAndSettle(tester, find.text('Kelly'));
      expect(pillPetId(tester), kellyId);
      await tapAndSettle(tester, emergencyPill);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      expect(find.text('Emergency · Soya'), findsNothing);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(launcher.calls, isEmpty);
    });

    testWidgets('carries the dot only for a pet with no number to call', (tester) async {
      await pumpHome(tester);

      // Kelly has vets.
      expect(emergencyDot, findsNothing);

      // Soya has none: a dot on the pill. The pill adds no card of its own;
      // the one-line essentials reminder under the hero (the Pets feature)
      // is what asks for the vet's phone.
      await tapAndSettle(tester, find.text('Soya'));
      expect(find.descendant(of: emergencyPill, matching: emergencyDot), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Emergency contacts for Soya. No phone number saved yet')), findsOneWidget);
      expect(find.byType(PetReminderCard), findsOneWidget);
      // The pill looks and works the same with the dot.
      expect(find.text('Emergency'), findsOneWidget);
      expect(emergencyPill.hitTestable(), findsOneWidget);

      await tapAndSettle(tester, find.text('Kelly'));
      expect(emergencyDot, findsNothing);
    });

    testWidgets('loses the dot once a vet is saved for the pet', (tester) async {
      await pumpHome(tester);
      await tapAndSettle(tester, find.text('Soya'));
      expect(emergencyDot, findsOneWidget);

      // Reuse Kelly's vet from Health's add-a-vet prompt.
      await tapAndSettle(tester, emergencyPill);
      final useVet = find.byKey(const ValueKey('use-vet-v-park'));
      await tester.ensureVisible(useVet);
      await tapAndSettle(tester, useVet);
      await closeSheet(tester);

      expect(find.text('Emergency · Soya'), findsNothing);
      expect(emergencyDot, findsNothing);
      expect(find.bySemanticsLabel('Emergency contacts for Soya'), findsOneWidget);
    });

    testWidgets('stays in place and works after scrolling to the bottom of a short phone', (tester) async {
      final launcher = await pumpHome(tester, size: const Size(390, 640));

      final barBefore = tester.getRect(topBar);
      final pillBefore = tester.getRect(emergencyPill);
      final feedingBefore = tester.getTopLeft(find.text('Feeding')).dy;
      expect(tester.widget<HomeTopBar>(topBar).raised, isFalse);

      final scrolled = await scrollHomeToBottom(tester);
      // The page really is longer than this phone.
      expect(scrolled, greaterThan(100));
      expect(tester.getTopLeft(find.text('Feeding')).dy, moreOrLessEquals(feedingBefore - scrolled));

      // The bar and the pill have not moved; the bar now floats over the page.
      expect(tester.getRect(topBar), barBefore);
      expect(tester.getRect(emergencyPill), pillBefore);
      expect(tester.widget<HomeTopBar>(topBar).raised, isTrue);
      expect(emergencyPill.hitTestable(), findsOneWidget);
      // The pet pills have slid away under it.
      expect(find.descendant(of: find.byType(PetSelector), matching: find.text('Kelly')).hitTestable(), findsNothing);

      await tapAndSettle(tester, emergencyPill);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      await tapAndSettle(tester, find.byKey(const ValueKey('call-regular')));
      expect(launcher.calls.single.target, kellyVetPhone);
    });

    testWidgets('sits below the status bar, and hides nothing at the top of the page', (tester) async {
      await pumpHome(tester, statusBar: 47);

      final bar = tester.getRect(topBar);
      expect(bar.top, 0);
      expect(bar.height, 47 + HomeTopBar.height);
      expect(tester.getRect(emergencyPill).top, greaterThanOrEqualTo(47));
      // The pet pills start under the bar, not behind it.
      expect(tester.getRect(find.text('Soya')).top, greaterThanOrEqualTo(bar.bottom));
      expect(find.text('Soya').hitTestable(), findsOneWidget);
    });
  });
}
