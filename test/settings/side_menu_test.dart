import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/pets/my_pets_screen.dart';
import 'package:pet_companion/features/settings/side_menu.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/directional_icon.dart';

import '../helpers.dart';
import 'settings_test_helpers.dart';

// The side menu behind the three-bars button on Home, in English (from the
// left) and in Hebrew (from the right).

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgetsInBothLanguages('the button opens the menu from its own side, over the bottom bar', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    final hebrew = language == AppLanguage.hebrew;
    await pumpHome(tester, language: language);
    expect(menu, findsNothing);

    // The button is at the start of the top bar.
    final button = tester.getCenter(find.byTooltip(l10n.homeMenu)).dx;
    expect(button, hebrew ? greaterThan(phone.width / 2) : lessThan(phone.width / 2));

    await openMenu(tester, l10n);
    final panel = tester.getRect(menu);
    expect(panel.width, 304);
    expect(panel.top, 0);
    expect(panel.bottom, phone.height, reason: 'it covers the bottom bar');
    if (hebrew) {
      expect(panel.right, phone.width);
    } else {
      expect(panel.left, 0);
    }
    expect(Directionality.of(tester.element(menu)), hebrew ? TextDirection.rtl : TextDirection.ltr);

    // Who is signed in.
    Finder inMenu(Finder finder) => find.descendant(of: menu, matching: finder);
    expect(inMenu(find.text('Alex')), findsOneWidget);
    final email = inMenu(find.text(FakeAuthRepository.demoEmail));
    expect(email, findsOneWidget);
    expect(tester.widget<Text>(email).textDirection, TextDirection.ltr);

    // The entries, in order from the top: My pets, Settings, and Sign out
    // alone at the bottom.
    expect(inMenu(find.text(l10n.menuMyPets)), findsOneWidget);
    expect(inMenu(find.text(l10n.homePetCount(2))), findsOneWidget);
    expect(inMenu(find.text(l10n.settingsTitle)), findsOneWidget);
    expect(inMenu(find.text(l10n.settingsSummary)), findsOneWidget);
    expect(inMenu(find.text(l10n.accountSignOut)), findsOneWidget);
    final myPets = tester.getCenter(find.byKey(AppSideMenu.myPetsKey)).dy;
    final settings = tester.getCenter(find.byKey(AppSideMenu.settingsKey)).dy;
    final signOut = tester.getCenter(find.byKey(AppSideMenu.signOutKey)).dy;
    expect(tester.getCenter(email).dy, lessThan(myPets));
    expect(myPets, lessThan(settings));
    expect(settings, lessThan(signOut));
    expect(signOut, greaterThan(phone.height - 120));

    // The sign-out arrow is mirrored in Hebrew only.
    final arrow = inMenu(find.byType(MirroredIcon));
    expect(find.descendant(of: arrow, matching: find.byType(Transform)), hebrew ? findsOneWidget : findsNothing);
  });

  testWidgetsInBothLanguages('closes on a tap outside, a swipe back to its edge, and the back button', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    final hebrew = language == AppLanguage.hebrew;
    await pumpHome(tester, language: language);

    // A tap on the dimmed part, beside the menu.
    await openMenu(tester, l10n);
    await tester.tapAt(Offset(hebrew ? 40 : phone.width - 40, 400));
    await settle(tester);
    expect(menu, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);

    // A swipe towards the edge it came from.
    await openMenu(tester, l10n);
    await tester.drag(menu, Offset(hebrew ? 280 : -280, 0));
    await settle(tester);
    expect(menu, findsNothing);

    // The phone's back button: the menu closes and the app stays on Home.
    await openMenu(tester, l10n);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(menu, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);
  });

  testWidgetsInBothLanguages('can be pulled in from the screen edge on Home, and only on Home', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    final hebrew = language == AppLanguage.hebrew;
    final edge = Offset(hebrew ? phone.width - 3 : 3, 400);
    final inwards = Offset(hebrew ? -250 : 250, 0);
    await pumpHome(tester, language: language);

    await tester.dragFrom(edge, inwards);
    await settle(tester);
    expect(menu, findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);

    // The other tabs have no menu button and no edge to pull.
    await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(l10n.navStore)));
    await settle(tester);
    expect(find.byTooltip(l10n.homeMenu), findsNothing);
    await tester.dragFrom(edge, inwards);
    await settle(tester);
    expect(menu, findsNothing);
  });

  testWidgetsInBothLanguages('"My pets" opens the My pets page', (tester, language) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openMenu(tester, l10n);

    await tester.tap(find.byKey(AppSideMenu.myPetsKey));
    await settle(tester);
    expect(find.byType(MyPetsScreen), findsOneWidget);

    // Back on Home the menu is closed.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(MyPetsScreen), findsNothing);
    expect(menu, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);
  });

  testWidgetsInBothLanguages('"Settings" opens the Settings page, and back returns to Home', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openSettingsFromMenu(tester, l10n);

    expect(find.text(l10n.settingsTitle), findsOneWidget);
    // A full page: no bottom bar.
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.byTooltip(l10n.commonBack));
    await settle(tester);
    expect(settingsPage, findsNothing);
    expect(menu, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgetsInBothLanguages('"Sign out" returns to the sign-in screen', (tester, language) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openMenu(tester, l10n);

    await tester.tap(find.byKey(AppSideMenu.signOutKey));
    await settle(tester);
    expect(find.text(l10n.authWelcomeBack), findsOneWidget);
    expect(menu, findsNothing);
  });

  for (final textScale in const [1.0, 1.3]) {
    testWidgetsInBothLanguages('fits a small phone, text x$textScale', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language, size: smallPhone, textScale: textScale);
      await openMenu(tester, l10n);

      final panel = tester.getRect(menu);
      expect(panel.width, 304);
      expect(panel.bottom, smallPhone.height);
      for (final key in [AppSideMenu.myPetsKey, AppSideMenu.settingsKey, AppSideMenu.signOutKey]) {
        final entry = tester.getRect(find.byKey(key));
        expect(entry.top, greaterThanOrEqualTo(0));
        expect(entry.bottom, lessThanOrEqualTo(smallPhone.height), reason: '$key is on screen');
      }

      await tester.tap(find.byKey(AppSideMenu.settingsKey));
      await settle(tester);
      expect(settingsPage, findsOneWidget);
    });
  }
}
