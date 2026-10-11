import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/findvet/data/location_service.dart';
import 'package:pet_companion/services/findvet/regions/regions.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';

final en = lookupOutdoorsL10n(englishLocale);
final he = lookupOutdoorsL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);
final communityEn = lookupCommunityL10n(englishLocale);

/// A spot in central Ra'anana (made up for the tests).
const raananaSpot = GeoPoint(32.1850, 34.8715);

void setUpOutdoorsTests() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
}

/// The parks feature's fakes, ready for [pumpApp].
class ParksKit {
  ParksKit({
    LocationResult location = const LocationResult(
      LocationOutcome.found,
      point: raananaSpot,
      accuracyM: 30,
    ),
    this.reviewer = false,
    FakeParksRepository? repository,
    Set<String>? favorites,
  }) : location = FakeLocationService(location),
       repo =
           repository ??
           FakeParksRepository(latency: Duration.zero, favorites: favorites);

  final FakeParksRepository repo;

  /// The partner ads (Outside opens on Partners, and park pages and cards
  /// show meetups), answering at once.
  final meetups = FakeMeetupsRepository(latency: Duration.zero);
  final FakeLocationService location;
  final launcher = RecordingParkLauncher();
  final bool reviewer;

  List<Override> get overrides => [
    parksRepositoryProvider.overrideWithValue(repo),
    meetupsRepositoryProvider.overrideWithValue(meetups),
    locationServiceProvider.overrideWithValue(location),
    parkLauncherProvider.overrideWithValue(launcher),
    if (reviewer)
      accessRepositoryProvider.overrideWithValue(
        FakeAccessRepository()
          ..users['demo'] = {'community.parks.review': AccessRule.allow},
      ),
  ];
}

/// Pumps the app, signs in with the demo account, opens Community and its
/// Outside section, then Parks (Partners shows first).
Future<ParksKit> openOutside(
  WidgetTester tester, {
  ParksKit? kit,
  AppLanguage? language,
  Size size = const Size(390, 844),
  bool parks = true,
  List<Override> overrides = const [],
}) async {
  final k = kit ?? ParksKit();
  // Signed in at the usual size; the screen under test then takes [size].
  await pumpApp(
    tester,
    language: language,
    settings: MemorySettingsStore({
      languageSettingKey: ?language?.code,
      'community.rules.demo': '1',
    }),
    overrides: [...k.overrides, ...overrides],
  );
  await signInAsDemo(tester);
  if (size != const Size(390, 844)) {
    tester.view.physicalSize = size * 3;
    await tester.pumpAndSettle();
  }
  final hebrew = language == AppLanguage.hebrew;
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text(hebrew ? he.sectionOutside : en.sectionOutside),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(OutsideSection.sectionKey), findsOneWidget);
  if (parks) {
    await tester.tap(find.byKey(OutsideSection.parksKey));
    await tester.pumpAndSettle();
  }
  return k;
}

/// Picks [cityCode] by typing [query] in the city field.
Future<void> chooseCity(
  WidgetTester tester,
  String query,
  String cityCode,
) async {
  await tester.enterText(find.byKey(ParkAreaPicker.cityFieldKey), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ParkAreaPicker.cityKey(cityCode)));
  await tester.pumpAndSettle();
}

/// Scrolls the parks list until [finder] is built, then shows it.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(ParksView.listKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// The card of [parkId].
Finder card(String parkId) => find.byKey(ParkCard.keyOf(parkId));

/// The ids of the cards on screen, top to bottom.
List<String> cardIds(WidgetTester tester) {
  final cards = tester.widgetList<Material>(
    find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('park-card-'),
    ),
  );
  return [
    for (final c in cards)
      (c.key! as ValueKey<String>).value.substring('park-card-'.length),
  ];
}
