import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/auth/widgets/account_sheet.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/features/settings/side_menu.dart';
import 'package:pet_companion/features/settings/widgets/week_choice.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';

const phone = Size(390, 844);
const smallPhone = Size(320, 568);

final menu = find.byKey(AppSideMenu.menuKey);
final settingsPage = find.byKey(SettingsScreen.screenKey);

/// The strings of [language], for expectations that must hold in both.
AppL10n stringsOf(AppLanguage language) =>
    lookupAppL10n(language == AppLanguage.hebrew ? hebrewLocale : englishLocale);

/// Lets Health's sample data (behind the Emergency pill) finish loading and
/// every animation finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Starts the app on its fakes, signs in as the demo user (Alex, with Kelly
/// and Soya) and lands on Home. Signing in happens on a regular phone; the
/// screen under test is then [size] with [textScale].
Future<void> pumpHome(
  WidgetTester tester, {
  AppLanguage? language,
  SettingsStore? settings,
  Size size = phone,
  double textScale = 1,
}) async {
  await pumpApp(tester, language: language, settings: settings);
  await signInAsDemo(tester);
  tester.view.physicalSize = size * 3;
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await settle(tester);
}

/// Opens the side menu with its button on Home.
Future<void> openMenu(WidgetTester tester, AppL10n l10n) async {
  await tester.tap(find.byTooltip(l10n.homeMenu));
  await settle(tester);
  expect(menu, findsOneWidget);
}

/// Opens Settings through the side menu.
Future<void> openSettingsFromMenu(WidgetTester tester, AppL10n l10n) async {
  await openMenu(tester, l10n);
  await tester.tap(find.byKey(AppSideMenu.settingsKey));
  await settle(tester);
  expect(settingsPage, findsOneWidget);
}

/// Opens Settings through the account sheet (the avatar of the demo user).
Future<void> openSettingsFromAccountSheet(WidgetTester tester) async {
  await tester.tap(find.text('A'));
  await settle(tester);
  await tester.tap(find.byKey(AccountSheet.settingsKey));
  await settle(tester);
  expect(settingsPage, findsOneWidget);
}

/// Whether a row of a pick-one list (found by its key) is the marked one.
bool isChosen(WidgetTester tester, Key rowKey) {
  final row = find.descendant(of: find.byKey(rowKey), matching: find.byType(Semantics));
  return tester.widget<Semantics>(row.first).properties.selected ?? false;
}

/// Scrolls [finder] into view on the Settings page, then taps it.
Future<void> tapOnSettings(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settle(tester);
}

/// The day letters of the week preview as they appear from left to right.
List<String> previewLetters(WidgetTester tester) {
  final letters = find.descendant(of: find.byKey(WeekChoice.previewKey), matching: find.byType(Text));
  final placed = [
    for (final element in letters.evaluate())
      ((element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx, (element.widget as Text).data!),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, letter) in placed) letter];
}

/// The week layout the app is using.
WeekSettings weekOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(settingsPage)).read(weekSettingsProvider);
