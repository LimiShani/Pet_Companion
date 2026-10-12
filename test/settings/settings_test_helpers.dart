import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/settings/about_screen.dart';
import 'package:pet_companion/features/settings/admin_tools_screen.dart';
import 'package:pet_companion/features/settings/settings_pages.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/features/settings/widgets/week_choice.dart';
import 'package:pet_companion/features/settings/you_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';

const phone = Size(390, 844);
const smallPhone = Size(320, 568);

final youPage = find.byKey(YouScreen.screenKey);
final settingsPage = find.byKey(SettingsScreen.screenKey);
final languagePage = find.byKey(LanguageSettingsScreen.screenKey);
final weekPage = find.byKey(WeekSettingsScreen.screenKey);
final notificationsPage = find.byKey(NotificationSettingsScreen.screenKey);
final adminToolsPage = find.byKey(AdminToolsScreen.screenKey);

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

/// The avatar of the signed-in account in the header on screen (Home's top
/// bar or a tab's coral header), which opens the You page.
Finder avatar(AppL10n l10n) => find.byTooltip(l10n.youTitle);

/// Opens the You page with the avatar of the header on screen.
Future<void> openYou(WidgetTester tester, AppL10n l10n) async {
  await tester.tap(avatar(l10n));
  await settle(tester);
  expect(youPage, findsOneWidget);
}

/// Opens Settings through the You page.
Future<void> openSettingsFromYou(WidgetTester tester, AppL10n l10n) async {
  await openYou(tester, l10n);
  await tester.tap(find.byKey(YouScreen.settingsKey));
  await settle(tester);
  expect(settingsPage, findsOneWidget);
}

/// Opens a page of Settings with its row ([rowKey]) on the Settings page.
Future<void> openSettingsRow(WidgetTester tester, Key rowKey, Finder page) async {
  await tester.ensureVisible(find.byKey(rowKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(rowKey));
  await settle(tester);
  expect(page, findsOneWidget);
}

/// Opens Settings through the You page, then its Language page.
Future<void> openLanguageFromYou(WidgetTester tester, AppL10n l10n) async {
  await openSettingsFromYou(tester, l10n);
  await openSettingsRow(tester, SettingsScreen.languageKey, languagePage);
}

/// Opens Settings through the You page, then its Week page.
Future<void> openWeekFromYou(WidgetTester tester, AppL10n l10n) async {
  await openSettingsFromYou(tester, l10n);
  await openSettingsRow(tester, SettingsScreen.weekKey, weekPage);
}

/// The line under a row of the Settings page.
String subtitleOf(WidgetTester tester, Key rowKey) {
  final texts = find.descendant(of: find.byKey(rowKey), matching: find.byType(Text));
  return tester.widget<Text>(texts.at(1)).data!;
}

/// Opens About through the You page.
Future<void> openAboutFromYou(WidgetTester tester, AppL10n l10n) async {
  await openYou(tester, l10n);
  await tester.tap(find.byKey(YouScreen.aboutKey));
  await settle(tester);
  expect(find.byKey(AboutScreen.screenKey), findsOneWidget);
}

/// Opens Admin tools through the You page (the demo user is an
/// administrator).
Future<void> openAdminTools(WidgetTester tester, AppL10n l10n) async {
  await openYou(tester, l10n);
  await tester.tap(find.byKey(YouScreen.adminKey));
  await settle(tester);
  expect(adminToolsPage, findsOneWidget);
}

/// Whether a row of a pick-one list (found by its key) is the marked one.
bool isChosen(WidgetTester tester, Key rowKey) {
  final row = find.descendant(of: find.byKey(rowKey), matching: find.byType(Semantics));
  return tester.widget<Semantics>(row.first).properties.selected ?? false;
}

/// Scrolls [finder] into view on a Settings page, then taps it.
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
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first)).read(weekSettingsProvider);
