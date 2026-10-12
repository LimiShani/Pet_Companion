import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/community/data/community_providers.dart';
import 'package:pet_companion/services/community/data/fake_chat_repository.dart';
import 'package:pet_companion/services/community/data/fake_feed_repository.dart';
import 'package:pet_companion/services/community/data/members_repository.dart';
import 'package:pet_companion/services/findvet/data/location_service.dart';
import 'package:pet_companion/services/findvet/regions/regions.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';

final en = lookupMeetupsL10n(englishLocale);
final he = lookupMeetupsL10n(hebrewLocale);
final outdoorsEn = lookupOutdoorsL10n(englishLocale);
final outdoorsHe = lookupOutdoorsL10n(hebrewLocale);
final communityEn = lookupCommunityL10n(englishLocale);
final communityHe = lookupCommunityL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);

/// Monday 12 October 2026, 09:00: the clock of these tests.
final monday = DateTime(2026, 10, 12, 9);
DateTime clock() => monday;

/// A spot in central Ra'anana (made up).
const raananaSpot = GeoPoint(32.1850, 34.8715);

void setUpMeetupsTests() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
}

/// The fakes behind the partners board, answering at once.
class MeetupsKit {
  MeetupsKit({
    FakeMeetupsRepository? repo,
    Set<String>? favorites,
    LocationResult location = const LocationResult(
      LocationOutcome.found,
      point: raananaSpot,
      accuracyM: 30,
    ),
    this.profileCity,
    this.access,
  }) : repo =
           repo ??
           FakeMeetupsRepository(
             latency: Duration.zero,
             now: clock,
             viewerId: () => 'demo',
           ),
       parks = FakeParksRepository(
         latency: Duration.zero,
         favorites: favorites,
       ),
       location = FakeLocationService(location);

  final FakeMeetupsRepository repo;
  final FakeParksRepository parks;
  final FakeLocationService location;
  final feed = FakeFeedRepository(latency: Duration.zero, now: clock);
  final chat = FakeChatRepository(latency: Duration.zero, now: clock);
  final FakeAccessRepository? access;

  /// The demo account's profile city ("Tel Aviv" in the sample data).
  final String? profileCity;

  late final members = FakeCommunityMembersRepository(
    latency: Duration.zero,
    now: clock,
    feed: feed,
    chat: chat,
  );

  late final settings = MemorySettingsStore({'community.rules.demo': '1'});

  List<Override> get overrides => [
    meetupsRepositoryProvider.overrideWithValue(repo),
    meetupsClockProvider.overrideWithValue(clock),
    parksRepositoryProvider.overrideWithValue(parks),
    locationServiceProvider.overrideWithValue(location),
    parkLauncherProvider.overrideWithValue(RecordingParkLauncher()),
    communityClockProvider.overrideWithValue(clock),
    feedRepositoryProvider.overrideWithValue(feed),
    chatRepositoryProvider.overrideWithValue(chat),
    communityMembersRepositoryProvider.overrideWithValue(members),
    if (access != null) accessRepositoryProvider.overrideWithValue(access!),
  ];
}

/// Pumps the app, signs in as the demo account, opens the Outside tab
/// (Partners shows first).
Future<MeetupsKit> openPartners(
  WidgetTester tester, {
  MeetupsKit? kit,
  AppLanguage? language,
  Size size = const Size(390, 844),
}) async {
  final k = kit ?? MeetupsKit();
  if (language != null) {
    await k.settings.write(languageSettingKey, language.code);
  }
  if (k.profileCity != null) {
    // The fake waits on a timer, which only real time runs out here.
    await tester.runAsync(
      () => k.members.updateMyProfile(
        viewer: demoViewer,
        bio: '',
        city: k.profileCity!,
      ),
    );
  }
  await pumpApp(
    tester,
    language: language,
    settings: k.settings,
    overrides: k.overrides,
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
      matching: find.text(
        hebrew ? outdoorsHe.sectionOutside : outdoorsEn.sectionOutside,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return k;
}

/// The demo account as the fakes know it.
const demoViewer = AppUser(
  id: 'demo',
  email: FakeAuthRepository.demoEmail,
  displayName: 'Alex',
);

/// The board's list.
Finder get board => find.byKey(PartnersView.listKey);

/// The card of [id].
Finder card(String id) => find.byKey(MeetupCard.keyOf(id));

/// The ids of the ads the board lists, top to bottom (built or not).
List<String> listedIds(WidgetTester tester) => [
  for (final item
      in containerOf(tester).read(partnersListingProvider).value ?? const [])
    item.meetup.id,
];

/// The ids of the cards built, top to bottom.
List<String> cardIds(WidgetTester tester) => [
  for (final m in tester.widgetList<Material>(
    find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('meetup-card-'),
    ),
  ))
    (m.key! as ValueKey<String>).value.substring('meetup-card-'.length),
];

/// Scrolls the first scrollable under [within] until [finder] is built,
/// then shows it.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  Finder? within,
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: within ?? board,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// Taps [finder] once it is on screen.
Future<void> tapOn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens the board's filters sheet.
Future<void> openFilters(WidgetTester tester) async {
  await tapOn(tester, find.byKey(PartnersView.filtersKey));
  expect(find.byKey(PartnersFiltersSheet.sheetKey), findsOneWidget);
}

/// Picks [radius] from the board's distance chip.
Future<void> chooseRadius(WidgetTester tester, ParkRadius radius) async {
  await tapOn(tester, find.byKey(PartnersView.radiusChipKey));
  await tester.tap(find.byKey(PartnersView.radiusKey(radius)));
  await tester.pumpAndSettle();
}

/// Changes Outside's one area from the chip in the tab's header: [query]
/// in the sheet's city field, then [cityCode].
Future<void> changeArea(
  WidgetTester tester,
  String query,
  String cityCode,
) async {
  await tester.tap(find.byKey(OutsideScreen.areaChipKey));
  await tester.pumpAndSettle();
  expect(find.byKey(OutsideAreaSheet.sheetKey), findsOneWidget);
  await tester.enterText(find.byKey(ParkAreaPicker.cityFieldKey), query);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ParkAreaPicker.cityKey(cityCode)));
  await tester.pumpAndSettle();
  expect(find.byKey(OutsideAreaSheet.sheetKey), findsNothing);
}

/// Closes the filters sheet with its "Show N ads" button.
Future<void> closeFilters(WidgetTester tester) async {
  await tapOn(tester, find.byKey(PartnersFiltersSheet.showKey));
  expect(find.byKey(PartnersFiltersSheet.sheetKey), findsNothing);
}

/// Whether the chip under [key] is chosen.
bool chipOn(WidgetTester tester, Key key) {
  final chip = tester.widget(find.byKey(key));
  return switch (chip) {
    ChoiceChip(:final selected) || FilterChip(:final selected) => selected,
    _ => throw StateError('not a chip: $key'),
  };
}

/// The provider container of the app.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AppBottomNav)));
