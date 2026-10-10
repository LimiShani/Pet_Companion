import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/composition/modules.g.dart';
import 'package:pet_companion/features/meetups/meetups.dart' show PartnersView;
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/platform/feature_module.dart';
import 'package:pet_companion/services/findvet/data/location_service.dart';

import 'outdoors_test_helpers.dart';

/// A tall phone, so a whole list is built without scrolling.
const tall = Size(390, 2400);

void main() {
  setUpOutdoorsTests();

  testWidgets('Outside sits between Chat and Guides; Parks is one tap from Partners', (
    tester,
  ) async {
    await openOutside(tester, parks: false);
    expect(find.byKey(PartnersView.listKey), findsOneWidget, reason: 'Partners shows first');
    await tester.tap(find.byKey(OutsideSection.parksKey));
    await tester.pumpAndSettle();
    final feed = tester.getCenter(find.text(communityEn.sectionFeed));
    final chat = tester.getCenter(find.text(communityEn.sectionChat));
    final outside = tester.getCenter(find.text(en.sectionOutside));
    final guides = tester.getCenter(find.text(communityEn.sectionGuides));
    expect(feed.dx < chat.dx && chat.dx < outside.dx && outside.dx < guides.dx, isTrue);
    expect(find.byKey(ParksView.listKey), findsOneWidget);
    expect(find.text(en.areaQuestion), findsOneWidget);
    expect(find.byKey(ParksView.sampleKey), findsOneWidget);
    expect(find.byKey(OsmCredit.creditKey), findsOneWidget);

  });

  testWidgets('without the meetups module Outside opens on Parks, Partners says it is coming', (
    tester,
  ) async {
    await openOutside(
      tester,
      parks: false,
      overrides: [
        featureModulesProvider.overrideWithValue([
          for (final module in builtInFeatureModules)
            if (module.id != 'meetups') module,
        ]),
      ],
    );
    expect(find.byKey(ParksView.listKey), findsOneWidget);
    await tester.tap(find.byKey(OutsideSection.partnersKey));
    await tester.pumpAndSettle();
    expect(find.byKey(OutsideSection.partnersSoonKey), findsOneWidget);
    expect(find.text(en.partnersSoonTitle), findsOneWidget);
    await tester.tap(find.text(en.partnersShowParks));
    await tester.pumpAndSettle();
    expect(find.byKey(ParksView.listKey), findsOneWidget);
  });

  testWidgets('Near me asks for the location only on the tap, sorts by distance and sends only a coarse box', (
    tester,
  ) async {
    final kit = await openOutside(tester, size: tall);
    expect(kit.location.asked, 0, reason: 'nothing is asked before the tap');
    expect(kit.repo.queries, isEmpty);

    await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    expect(kit.location.asked, 1);
    expect(find.text(en.areaNearMeIn("Ra'anana")), findsOneWidget);

    final query = kit.repo.queries.single;
    expect(query.localityCode, isNull);
    final box = query.box!;
    for (final edge in [box.south, box.west, box.north, box.east]) {
      expect(edge * 20, closeTo((edge * 20).roundToDouble(), 1e-9), reason: 'on the 0.05° grid');
    }
    expect(box.contains(raananaSpot), isTrue);

    // Nearest first, with distances; Jerusalem is not "near".
    final ids = cardIds(tester);
    expect(ids.first, 'demo-raanana-ahuza');
    expect(ids, containsAll(['demo-raanana-park', 'demo-kfarsaba-weizmann']));
    expect(ids, isNot(contains('demo-jlm-refaim')));
    expect(find.descendant(of: card('demo-raanana-ahuza'), matching: find.textContaining(' m')), findsOneWidget);
    // Tags show only what is known to be there.
    expect(find.descendant(of: card('demo-raanana-ahuza'), matching: find.text(en.detailFenced)), findsOneWidget);
    expect(find.descendant(of: card('demo-raanana-ahuza'), matching: find.text(en.detailSmallDogs)), findsNothing);
    // The closed park says so.
    expect(find.descendant(of: card('demo-kfarsaba-garden'), matching: find.text(en.closedLabel)), findsOneWidget);
    // An unnamed park is named after its street.
    expect(find.descendant(of: card('demo-raanana-ahuza'), matching: find.text('Dog park · Ahuza')), findsOneWidget);

    // Wider: 25 km reaches Tel Aviv.
    await tester.tap(find.byKey(ParkAreaBar.radiusKey(ParkRadius.km25)));
    await tester.pumpAndSettle();
    expect(cardIds(tester), contains('demo-tlv-meir'));
    expect(find.byKey(ParkAreaBar.radiusKey(ParkRadius.cityOnly)), findsNothing, reason: 'no "City only" near me');
  });

  testWidgets('a refused location says why and a city works instead', (tester) async {
    final kit = await openOutside(
      tester,
      size: tall,
      kit: ParksKit(location: const LocationResult(LocationOutcome.deniedForever)),
    );
    await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    expect(find.text(en.problemDeniedForever), findsOneWidget);
    await tester.tap(find.byKey(ParkAreaPicker.openSettingsKey));
    await tester.pumpAndSettle();
    expect(kit.location.settingsOpened, [LocationOutcome.deniedForever]);

    await chooseCity(tester, 'Kfar Sa', 'kfar-saba');
    expect(kit.repo.queries.single.localityCode, 'kfar-saba', reason: 'City only asks by locality');
    expect(cardIds(tester), unorderedEquals(['demo-kfarsaba-weizmann', 'demo-kfarsaba-garden']));
    // No distance from a city's centre.
    expect(find.descendant(of: card('demo-kfarsaba-weizmann'), matching: find.textContaining(' km')), findsNothing);

    await tester.tap(find.byKey(ParkAreaBar.radiusKey(ParkRadius.km10)));
    await tester.pumpAndSettle();
    expect(cardIds(tester), contains('demo-raanana-park'));
    expect(kit.repo.queries.last.box, isNotNull);

    await tester.tap(find.byKey(ParkAreaBar.changeKey));
    await tester.pumpAndSettle();
    expect(find.text(en.areaQuestion), findsOneWidget);
  });

  testWidgets('filters keep parks known to have every chosen detail', (tester) async {
    await openOutside(tester, size: tall);
    await chooseCity(tester, 'raan', 'raanana');
    await tester.tap(find.byKey(ParkAreaBar.radiusKey(ParkRadius.km10)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParksView.filterKey(ParkDetail.fenced)));
    await tester.tap(find.byKey(ParksView.filterKey(ParkDetail.smallDogs)));
    await tester.pumpAndSettle();
    expect(cardIds(tester), ['demo-raanana-park', 'demo-kfarsaba-garden']);

    await tester.tap(find.byKey(ParksView.filterKey(ParkDetail.lighting)));
    await tester.pumpAndSettle();
    expect(cardIds(tester), isEmpty);
    expect(find.text(en.noFilterMatch), findsOneWidget);
    await tester.tap(find.byKey(ParksView.clearFiltersKey));
    await tester.pumpAndSettle();
    expect(cardIds(tester).length, greaterThan(3));
  });

  testWidgets('My parks come first, wherever they are', (tester) async {
    await openOutside(tester, size: tall, kit: ParksKit(favorites: {'demo-jlm-refaim'}));
    // Before an area is chosen, the saved parks are already there.
    expect(find.text(en.myParks), findsOneWidget);
    expect(cardIds(tester), ['demo-jlm-refaim']);
    await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    final ids = cardIds(tester);
    expect(ids.first, 'demo-jlm-refaim');
    expect(ids.where((id) => id == 'demo-jlm-refaim'), hasLength(1));
    expect(ids[1], 'demo-raanana-ahuza');
  });

  testWidgets('a park page: details, navigation and saving', (tester) async {
    final kit = await openOutside(tester, size: tall);
    await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    await tester.tap(card('demo-raanana-ahuza'));
    await tester.pumpAndSettle();

    expect(find.byKey(ParkScreen.screenKey), findsOneWidget);
    expect(find.text('Dog park · Ahuza'), findsOneWidget);
    Finder answer(ParkDetail d, String text) =>
        find.descendant(of: find.byKey(ParkScreen.detailKey(d)), matching: find.text(text));
    expect(answer(ParkDetail.fenced, en.answerYes), findsOneWidget);
    expect(answer(ParkDetail.smallDogs, en.answerNo), findsOneWidget);
    expect(answer(ParkDetail.shade, en.answerUnknown), findsOneWidget);
    expect(find.text(en.unknownNote), findsOneWidget);
    expect(find.byKey(OsmCredit.creditKey), findsOneWidget);
    // The meetups slots are empty and take no room.
    expect(find.text(en.parkDefaultName), findsNothing);

    await tester.tap(find.byKey(ParkScreen.navigateKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.wazeKey));
    await tester.pumpAndSettle();
    expect(kit.launcher.opened.single.host, 'waze.com');
    expect(kit.launcher.opened.single.queryParameters['ll'], '32.1866,34.8722');

    kit.launcher.succeeds = false;
    await tester.tap(find.byKey(ParkScreen.navigateKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.googleMapsKey));
    await tester.pumpAndSettle();
    expect(kit.launcher.opened.last.host, 'www.google.com');
    expect(find.text(en.navigateFailed), findsOneWidget);

    await tester.tap(find.byKey(ParkScreen.saveKey));
    await tester.pumpAndSettle();
    expect(kit.repo.favoriteSet, {'demo-raanana-ahuza'});
    expect(find.text(en.savedToMyParks), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(en.myParks), findsOneWidget);
    expect(cardIds(tester).first, 'demo-raanana-ahuza');
    expect(cardIds(tester).where((id) => id == 'demo-raanana-ahuza'), hasLength(1));

    // Removing it again.
    await tester.tap(card('demo-raanana-ahuza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.saveKey));
    await tester.pumpAndSettle();
    expect(kit.repo.favoriteSet, isEmpty);
    expect(find.text(en.removedFromMyParks), findsOneWidget);
  });

  testWidgets('saving that fails is taken back', (tester) async {
    final kit = await openOutside(tester, size: tall);
    await chooseCity(tester, 'raan', 'raanana');
    await tester.tap(card('demo-raanana-park'));
    await tester.pumpAndSettle();
    kit.repo.failure = const ParkException(ParkFailure.unavailable);
    await tester.tap(find.byKey(ParkScreen.saveKey));
    await tester.pumpAndSettle();
    expect(find.text(en.saveFailed), findsOneWidget);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
  });

  testWidgets('Update details sends only what changed, for review', (tester) async {
    final kit = await openOutside(tester, size: tall);
    await chooseCity(tester, 'raan', 'raanana');
    await tester.tap(card('demo-raanana-ahuza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.updateKey));
    await tester.pumpAndSettle();

    // Nothing changed yet.
    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.tap(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(en.nothingChanged), findsOneWidget);
    expect(kit.repo.sentSuggestions, isEmpty);

    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.shade, ParkAnswer.yes)));
    await tester.tap(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.shade, ParkAnswer.yes)));
    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.closedKey));
    await tester.tap(find.byKey(UpdateDetailsSheet.closedKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.tap(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.pumpAndSettle();

    expect(kit.repo.sentSuggestions.single, {
      'kind': 'details',
      'park_id': 'demo-raanana-ahuza',
      'changes': {'shade': 'yes', 'closed': true},
    });
    expect(find.text(en.sentThanks), findsOneWidget);
    // Nothing is published before a reviewer approves it.
    final park = kit.repo.parkList.firstWhere((p) => p.id == 'demo-raanana-ahuza');
    expect(park.answer(ParkDetail.shade), ParkAnswer.unknown);
    expect(park.isClosed, isFalse);
  });

  testWidgets('the daily limit on suggestions is explained', (tester) async {
    final kit = await openOutside(tester, size: tall);
    kit.repo.suggestFailure = ParkFailure.rateLimited;
    await chooseCity(tester, 'raan', 'raanana');
    await tester.tap(card('demo-raanana-ahuza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.updateKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.benches, ParkAnswer.no)));
    await tester.tap(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.benches, ParkAnswer.no)));
    await tester.ensureVisible(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.tap(find.byKey(UpdateDetailsSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(en.rateLimited), findsOneWidget);
  });

  testWidgets('Suggest a park: from the phone at the park, or a city and a place', (tester) async {
    final kit = await openOutside(tester, size: tall);
    await tester.tap(find.byKey(ParksView.suggestKey));
    await tester.pumpAndSettle();
    expect(find.byKey(SuggestParkScreen.screenKey), findsOneWidget);

    // No location yet.
    await tester.ensureVisible(find.byKey(SuggestParkScreen.sendKey));
    await tester.tap(find.byKey(SuggestParkScreen.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(en.needLocation), findsOneWidget);

    // A city alone is not enough: where in it?
    await tester.enterText(find.byKey(SuggestParkScreen.cityFieldKey), 'Herzl');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SuggestParkScreen.cityKey('herzliya')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SuggestParkScreen.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(en.needLocation), findsOneWidget);
    await tester.enterText(find.byKey(SuggestParkScreen.placeKey), 'Behind the sports centre');
    await tester.tap(find.byKey(SuggestParkScreen.answerKey(ParkDetail.fenced, ParkAnswer.yes)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SuggestParkScreen.sendKey));
    await tester.pumpAndSettle();

    final sent = kit.repo.sentSuggestions.single;
    expect(sent['kind'], 'new_park');
    expect(sent['location_kind'], 'locality');
    expect(sent['locality_code'], 'herzliya');
    expect(sent['place_note'], 'Behind the sports centre');
    expect(sent['name'], isNull);
    expect(sent['changes'], {'fenced': 'yes'});
    expect(find.text(en.sentThanks), findsOneWidget);
    expect(kit.location.asked, 0, reason: 'the phone was never asked');

    // Again, standing at the park.
    await tester.tap(find.byKey(ParksView.suggestKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(SuggestParkScreen.nameKey), 'Dog run by the lake');
    await tester.tap(find.byKey(SuggestParkScreen.hereKey));
    await tester.pumpAndSettle();
    expect(find.text(en.hereSet), findsOneWidget);
    await tester.ensureVisible(find.byKey(SuggestParkScreen.sendKey));
    await tester.tap(find.byKey(SuggestParkScreen.sendKey));
    await tester.pumpAndSettle();
    final second = kit.repo.sentSuggestions.last;
    expect(second['location_kind'], 'device');
    expect(second['lat'], raananaSpot.lat);
    expect(second['locality_code'], 'raanana');
    expect(second['name'], 'Dog run by the lake');
  });

  testWidgets('a load that fails can be tried again', (tester) async {
    final kit = await openOutside(tester, size: tall);
    kit.repo.failure = const ParkException(ParkFailure.unavailable);
    await chooseCity(tester, 'raan', 'raanana');
    expect(find.text(en.loadFailed), findsOneWidget);
    kit.repo.failure = null;
    await tester.tap(find.byKey(ParksView.retryKey));
    await tester.pumpAndSettle();
    expect(cardIds(tester), isNotEmpty);
  });

  testWidgets('an area with no park says so and offers to look further', (tester) async {
    await openOutside(tester, size: tall);
    await chooseCity(tester, 'Mitzpe', 'mitzpe-ramon');
    expect(find.text(en.noParksTitle), findsOneWidget);
    await tester.tap(find.byKey(ParksView.widerKey));
    await tester.pumpAndSettle();
    expect(find.text(en.noParksTitle), findsOneWidget);
    expect(find.byKey(ParksView.widerKey), findsNothing, reason: '25 km is the widest');
  });

  testWidgets('members do not see the review entry', (tester) async {
    await openOutside(tester);
    expect(find.byKey(ParksView.reviewKey), findsNothing);
  });
}
