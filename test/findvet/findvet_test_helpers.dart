import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/auth/login_screen.dart';
import 'package:pet_companion/features/findvet/findvet.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';

/// The clock of every Find a vet test: live reports expire against it.
final testNow = DateTime(2026, 10, 3, 14);

final en = lookupFindVetL10n(englishLocale);
final he = lookupFindVetL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);

const rehovot = GeoPoint(31.8928, 34.8113);

/// Find a vet's fakes, ready to hand to [pumpApp].
class FindVetKit {
  FindVetKit({LocationResult location = const LocationResult(LocationOutcome.denied), bool admin = false})
    : location = FakeLocationService(location),
      admin = FakeVetAdminRepository(admin: admin);

  final repo = FakeVetFinderRepository(latency: Duration.zero, now: () => testNow);
  final FakeLocationService location;
  final launcher = RecordingVetLauncher();
  final FakeVetAdminRepository admin;

  List<Override> get overrides => [
    findVetRepositoryProvider.overrideWithValue(repo),
    locationServiceProvider.overrideWithValue(location),
    vetLauncherProvider.overrideWithValue(launcher),
    findVetClockProvider.overrideWithValue(() => testNow),
    vetAdminRepositoryProvider.overrideWithValue(admin),
  ];
}

/// A tall phone, so every result card is built without scrolling.
const tallPhone = Size(390, 3200);

/// Starts the app on the sign-in screen and opens the emergency path from
/// there, without an account.
Future<void> openEmergencySignedOut(
  WidgetTester tester,
  FindVetKit kit, {
  AppLanguage? language,
  Size size = tallPhone,
  double textScale = 1,
}) async {
  await pumpApp(tester, overrides: kit.overrides, language: language, size: size, textScale: textScale);
  await tester.ensureVisible(find.byKey(LoginScreen.findVetKey));
  await tester.tap(find.byKey(LoginScreen.findVetKey));
  await tester.pumpAndSettle();
  expect(find.byKey(FindVetScreen.screenKey), findsOneWidget);
}

/// Types [query] into the place field and picks the suggestion [label].
Future<void> pickPlace(WidgetTester tester, String query, String label) async {
  await tester.enterText(find.byKey(AreaPicker.fieldKey), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AreaPicker.matchKey(label)));
  await tester.pumpAndSettle();
}

/// The card of the result with [key].
Finder cardOf(String key) => find.byKey(VetResultCard.cardKey(key));

/// [text] inside the card of [key].
Finder inCard(String key, String text) => find.descendant(of: cardOf(key), matching: find.text(text));

/// The keys of the demo facilities (see FakeVetFinderRepository).
const demoCentre = 'demo-emergency-centre';
const demoHospital = 'demo-vet-hospital';
const demoListing = 'g:demo-place-3';
const demoNightClinic = 'demo-night-clinic';
const demoFamilyVet = 'g:demo-place-5';
