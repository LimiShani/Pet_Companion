import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/household/household.dart';
import 'package:pet_companion/features/settings/you_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';

/// The day the household tests live on.
final householdNow = DateTime(2026, 10, 14, 12);

/// The demo backend at zero latency, as the demo account (Alex) sees it.
/// With [shared] false nobody else is in Alex's household yet.
FakeHouseholdRepository demoHouseholds({bool shared = true}) =>
    FakeHouseholdRepository(
      viewerId: () => 'demo',
      viewerName: () => 'Alex',
      now: () => householdNow,
      latency: Duration.zero,
      shared: shared,
    );

void setUpHouseholdTests() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });
}

HouseholdL10n householdStrings(AppLanguage language) => lookupHouseholdL10n(
  language == AppLanguage.hebrew ? hebrewLocale : englishLocale,
);

AppL10n appStrings(AppLanguage language) => lookupAppL10n(
  language == AppLanguage.hebrew ? hebrewLocale : englishLocale,
);

/// Lets the fakes answer and every animation finish.
Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Signs in as the demo account on [repository] and lands on Home. What is
/// shared through the phone's share sheet goes into [shared].
Future<void> pumpHouseholdHome(
  WidgetTester tester, {
  AppLanguage? language,
  FakeHouseholdRepository? repository,
  List<String>? shared,
  Size size = const Size(390, 844),
}) async {
  final repo = repository ?? demoHouseholds();
  await pumpApp(
    tester,
    language: language,
    overrides: [
      householdRepositoryProvider.overrideWithValue(repo),
      householdClockProvider.overrideWithValue(() => householdNow),
      householdShareProvider.overrideWithValue(
        (text) async => shared?.add(text),
      ),
    ],
  );
  await signInAsDemo(tester);
  tester.view.physicalSize = size * 3;
  await settle(tester);
}

/// Opens the You page with the header's avatar, then the Household page.
Future<void> openHouseholdPage(
  WidgetTester tester,
  AppLanguage language,
) async {
  await tester.tap(find.byTooltip(appStrings(language).youTitle));
  await settle(tester);
  expect(find.byKey(YouScreen.screenKey), findsOneWidget);
  await tester.tap(find.byKey(HouseholdMenuEntry.entryKey));
  await settle(tester);
  expect(find.byKey(HouseholdScreen.screenKey), findsOneWidget);
}
