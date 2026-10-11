import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pet_companion/access/access_admin_screen.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/auth/widgets/delete_account_dialog.dart';
import 'package:pet_companion/features/community/safety/community_safety_screen.dart';
import 'package:pet_companion/features/pets/my_pets_screen.dart';
import 'package:pet_companion/features/settings/about_screen.dart';
import 'package:pet_companion/features/settings/admin_tools_screen.dart';
import 'package:pet_companion/features/settings/widgets/legal_links.dart';
import 'package:pet_companion/features/settings/you_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:pet_companion/widgets/petloop_icon.dart';

import '../helpers.dart';
import 'settings_test_helpers.dart';

// The You page behind the avatar of every header (Home's top bar, the
// tabs' coral headers), in English and in Hebrew.

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgetsInBothLanguages('the avatar on Home opens it: the account, the rows, and Sign out at the bottom', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    final hebrew = language == AppLanguage.hebrew;
    await pumpHome(tester, language: language);
    expect(youPage, findsNothing);

    // The avatar is at the end of the top bar.
    final button = tester.getCenter(avatar(l10n)).dx;
    expect(button, hebrew ? lessThan(phone.width / 2) : greaterThan(phone.width / 2));

    await openYou(tester, l10n);
    expect(find.text(l10n.youTitle), findsOneWidget);
    expect(Directionality.of(tester.element(youPage)), hebrew ? TextDirection.rtl : TextDirection.ltr);
    // A full page: no bottom bar, and a back arrow at the start.
    expect(find.byType(AppBottomNav), findsNothing);
    final back = tester.getCenter(find.byTooltip(l10n.commonBack)).dx;
    expect(back, hebrew ? greaterThan(phone.width / 2) : lessThan(phone.width / 2));

    // Who is signed in.
    expect(find.text('Alex'), findsOneWidget);
    final email = find.text(FakeAuthRepository.demoEmail);
    expect(email, findsOneWidget);
    expect(tester.widget<Text>(email).textDirection, TextDirection.ltr);

    // The rows, from the top: My pets and Budget; Settings, Community
    // safety and About; Admin tools (the demo user is an administrator);
    // then Sign out and Delete account.
    expect(find.text(l10n.menuMyPets), findsOneWidget);
    expect(find.text(l10n.homePetCount(2)), findsOneWidget);
    expect(find.byKey(YouScreen.budgetKey), findsOneWidget);
    expect(find.text(l10n.settingsTitle), findsOneWidget);
    expect(find.text(l10n.settingsSummary), findsOneWidget);
    expect(find.text(l10n.youCommunitySafetySummary), findsOneWidget);
    expect(find.text(l10n.aboutTitle), findsOneWidget);
    expect(find.text(l10n.youAdminTools), findsOneWidget);
    expect(find.text(l10n.accountSignOut), findsOneWidget);
    expect(find.text(l10n.accountDelete), findsOneWidget);
    double y(Key key) => tester.getCenter(find.byKey(key)).dy;
    expect(tester.getCenter(email).dy, lessThan(y(YouScreen.myPetsKey)));
    expect(y(YouScreen.myPetsKey), lessThan(y(YouScreen.budgetKey)));
    expect(y(YouScreen.budgetKey), lessThan(y(YouScreen.settingsKey)));
    expect(y(YouScreen.settingsKey), lessThan(y(YouScreen.safetyKey)));
    expect(y(YouScreen.safetyKey), lessThan(y(YouScreen.aboutKey)));
    expect(y(YouScreen.aboutKey), lessThan(y(YouScreen.adminKey)));
    expect(y(YouScreen.adminKey), lessThan(y(YouScreen.signOutKey)));
    expect(y(YouScreen.signOutKey), lessThan(y(YouScreen.deleteKey)));

    // The sign-out arrow is mirrored in Hebrew only.
    final arrow = find.byWidgetPredicate((w) => w is PetLoopIcon && w.glyph == PetLoopGlyph.logout);
    expect(find.descendant(of: arrow, matching: find.byType(Transform)), hebrew ? findsOneWidget : findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgetsInBothLanguages('the avatar on the Community header opens it too, and back returns there; Health has none', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    final health = lookupHealthL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);
    final community = lookupCommunityL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);
    await pumpHome(tester, language: language, size: const Size(390, 844));
    // Health keeps its header row for the pet switcher and the Emergency pill.
    await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(l10n.navHealth)));
    await settle(tester);
    expect(find.descendant(of: find.byType(CoralHeader), matching: find.text(health.tabTitle)), findsOneWidget);
    expect(find.byType(HeaderAvatar), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(l10n.navCommunity)));
    await settle(tester);
    // The title in the coral header (the bottom bar says "Community" too).
    final healthTitle = find.descendant(of: find.byType(CoralHeader), matching: find.text(community.tabTitle));
    expect(healthTitle, findsOneWidget);

    await openYou(tester, l10n);
    expect(healthTitle, findsNothing);

    await tester.tap(find.byTooltip(l10n.commonBack));
    await settle(tester);
    expect(youPage, findsNothing);
    expect(healthTitle, findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgetsInBothLanguages('"My pets" opens the My pets page', (tester, language) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openYou(tester, l10n);

    await tester.tap(find.byKey(YouScreen.myPetsKey));
    await settle(tester);
    expect(find.byType(MyPetsScreen), findsOneWidget);

    // Back is the You page, then Home.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(MyPetsScreen), findsNothing);
    expect(youPage, findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(youPage, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);
  });

  testWidgetsInBothLanguages('"Settings" opens the Settings page, and back returns through You to Home', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openSettingsFromYou(tester, l10n);

    expect(find.text(l10n.settingsTitle), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);

    await tester.tap(find.byTooltip(l10n.commonBack));
    await settle(tester);
    expect(settingsPage, findsNothing);
    expect(youPage, findsOneWidget);
    await tester.tap(find.byTooltip(l10n.commonBack));
    await settle(tester);
    expect(youPage, findsNothing);
    expect(find.text(l10n.homeFeeding), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('"Community safety" goes to the Community tab\'s safety page', (tester) async {
    final l10n = stringsOf(AppLanguage.english);
    await pumpHome(tester);
    await openYou(tester, l10n);

    await tester.tap(find.byKey(YouScreen.safetyKey));
    await settle(tester);
    expect(find.byType(CommunitySafetyScreen), findsOneWidget);
    expect(youPage, findsNothing);
  });

  testWidgetsInBothLanguages('"About PetLoop" opens the legal links, the credits and the version', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    PackageInfo.setMockInitialValues(
      appName: 'PetLoop',
      packageName: 'app.petloop',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    await pumpHome(tester, language: language);
    await openYou(tester, l10n);

    await tester.tap(find.byKey(YouScreen.aboutKey));
    await settle(tester);
    expect(find.byKey(AboutScreen.screenKey), findsOneWidget);
    expect(find.text(l10n.aboutTitle), findsOneWidget);
    expect(find.byKey(LegalLinks.termsKey), findsOneWidget);
    expect(find.byKey(LegalLinks.privacyKey), findsOneWidget);
    expect(find.text(l10n.legalOpensInBrowser), findsOneWidget);
    expect(find.text(l10n.aboutVersion('1.2.3 (45)')), findsOneWidget);
    // About is no longer on the Settings page.
    await tester.tap(find.byTooltip(l10n.commonBack));
    await settle(tester);
    await tester.tap(find.byKey(YouScreen.settingsKey));
    await settle(tester);
    expect(find.byKey(LegalLinks.termsKey), findsNothing);
    expect(find.text(l10n.aboutTitle), findsNothing);
  });

  testWidgets('"Admin tools" lists what the account may do: Feature access and Directory review for the demo user', (
    tester,
  ) async {
    final l10n = stringsOf(AppLanguage.english);
    await pumpHome(tester);
    await openAdminTools(tester, l10n);

    expect(find.text(l10n.youAdminTools), findsOneWidget);
    expect(find.byKey(AdminToolsScreen.featureAccessKey), findsOneWidget);
    // The demo user is an administrator and a directory reviewer on the
    // fake backends (test/findvet/ covers an account that is not), and
    // not a park reviewer.
    expect(find.byKey(AdminToolsScreen.directoryReviewKey), findsOneWidget);
    expect(find.byKey(AdminToolsScreen.parkSuggestionsKey), findsNothing);

    await tester.tap(find.byKey(AdminToolsScreen.featureAccessKey));
    await settle(tester);
    expect(find.byType(AccessAdministrationScreen), findsOneWidget);
  });

  testWidgetsInBothLanguages('"Sign out" returns to the sign-in screen', (tester, language) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openYou(tester, l10n);

    await tester.tap(find.byKey(YouScreen.signOutKey));
    await settle(tester);
    expect(find.text(l10n.authWelcomeBack), findsOneWidget);
    expect(youPage, findsNothing);
  });

  testWidgetsInBothLanguages('"Delete account" asks for the word; cancelling keeps the page and the account', (
    tester,
    language,
  ) async {
    final l10n = stringsOf(language);
    await pumpHome(tester, language: language);
    await openYou(tester, l10n);

    await tester.ensureVisible(find.byKey(YouScreen.deleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(YouScreen.deleteKey));
    await settle(tester);
    expect(find.text(l10n.accountDeleteTitle), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(DeleteAccountDialog.confirmKey)).enabled, isFalse);

    await tester.tap(find.byKey(DeleteAccountDialog.cancelKey));
    await settle(tester);
    expect(find.byKey(DeleteAccountDialog.fieldKey), findsNothing);
    expect(youPage, findsOneWidget);
    expect(find.text(FakeAuthRepository.demoEmail), findsOneWidget);
  });

  for (final textScale in const [1.0, 1.3]) {
    testWidgetsInBothLanguages('fits a small phone, text x$textScale', (tester, language) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language, size: smallPhone, textScale: textScale);
      await openYou(tester, l10n);
      expect(tester.takeException(), isNull);

      // Everything can be reached: the page scrolls.
      for (final key in [
        YouScreen.myPetsKey,
        YouScreen.settingsKey,
        YouScreen.aboutKey,
        YouScreen.signOutKey,
        YouScreen.deleteKey,
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        final entry = tester.getRect(find.byKey(key));
        expect(entry.top, greaterThanOrEqualTo(0));
        expect(entry.bottom, lessThanOrEqualTo(smallPhone.height), reason: '$key is on screen');
      }
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(YouScreen.settingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(YouScreen.settingsKey));
      await settle(tester);
      expect(settingsPage, findsOneWidget);
    });
  }
}
