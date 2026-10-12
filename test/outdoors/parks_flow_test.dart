import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/composition/modules.g.dart';
import 'package:pet_companion/features/meetups/meetups.dart' show MeetupsAreaPicker, PartnersView;
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/platform/feature_module.dart';
import 'package:pet_companion/services/findvet/data/location_service.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import 'outdoors_test_helpers.dart';

/// A tall phone, so a whole list is built without scrolling.
const tall = Size(390, 2400);

void main() {
  setUpOutdoorsTests();

  testWidgets('Outside is its own tab between Community and Store; Parks is one tap from Partners', (
    tester,
  ) async {
    await openOutside(tester, parks: false);
    expect(find.byKey(PartnersView.listKey), findsOneWidget, reason: 'Partners shows first');
    await tester.tap(find.byKey(OutsideSection.parksKey));
    await tester.pumpAndSettle();
    Offset tab(String label) => tester.getCenter(
      find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)),
    );
    final community = tab(appEn.navCommunity);
    final outside = tab(en.sectionOutside);
    final store = tab(appEn.navStore);
    expect(community.dx < outside.dx && outside.dx < store.dx, isTrue);
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
    // The area is the header's chip now: the nearest city, no area bar.
    expect(find.descendant(of: find.byKey(OutsideScreen.areaChipKey), matching: find.text("Ra'anana")), findsOneWidget);
    expect(find.byType(ParkAreaBar), findsNothing);

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
    await chooseRadius(tester, ParkRadius.km25);
    expect(cardIds(tester), contains('demo-tlv-meir'));
    expect(find.descendant(of: find.byKey(ParksView.radiusChipKey), matching: find.text(en.radiusKm(25))), findsOneWidget);
    await tester.tap(find.byKey(ParksView.radiusChipKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ParkAreaBar.radiusKey(ParkRadius.km10)), findsOneWidget);
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
    // A city starts on up to 10 km, as Partners does.
    expect(kit.repo.queries.single.box, isNotNull);
    expect(cardIds(tester), contains('demo-raanana-park'));

    await chooseRadius(tester, ParkRadius.cityOnly);
    expect(kit.repo.queries.last.localityCode, 'kfar-saba', reason: 'City only asks by locality');
    expect(cardIds(tester), unorderedEquals(['demo-kfarsaba-weizmann', 'demo-kfarsaba-garden']));
    // No distance from a city's centre.
    expect(find.descendant(of: card('demo-kfarsaba-weizmann'), matching: find.textContaining(' km')), findsNothing);

    // The header's chip asks again, in a sheet.
    await tester.tap(find.byKey(OutsideScreen.areaChipKey));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(OutsideAreaSheet.sheetKey), matching: find.text(en.areaQuestion)), findsOneWidget);
  });

  testWidgets('filters keep parks known to have every chosen detail', (tester) async {
    await openOutside(tester, size: tall);
    await chooseCity(tester, 'raan', 'raanana');
    await tapFilter(tester, ParkDetail.fenced);
    await tapFilter(tester, ParkDetail.smallDogs);
    expect(cardIds(tester), ['demo-raanana-park', 'demo-kfarsaba-garden']);

    await tapFilter(tester, ParkDetail.lighting);
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

  testWidgets('one area for Outside: a chip in the header opens the picker; no area bar in the bodies', (tester) async {
    await openOutside(tester, size: tall);
    // Before an area is chosen: the picker in the body, no chip.
    expect(find.byKey(OutsideScreen.areaChipKey), findsNothing);
    expect(find.byType(ParkAreaPicker), findsOneWidget);
    await chooseCity(tester, 'raan', 'raanana');
    expect(find.byType(ParkAreaPicker), findsNothing);
    expect(find.byType(ParkAreaBar), findsNothing);
    final chip = find.byKey(OutsideScreen.areaChipKey);
    expect(find.descendant(of: chip, matching: find.text("Ra'anana")), findsOneWidget);
    expect(find.bySemanticsLabel(en.areaChipLabel("Ra'anana")), findsOneWidget);

    // The chip opens the same picker, in a sheet; a city closes it.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    final sheet = find.byKey(OutsideAreaSheet.sheetKey);
    expect(find.descendant(of: sheet, matching: find.byType(ParkAreaPicker)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(en.locationWhy)), findsOneWidget);
    await chooseCity(tester, 'Kfar Sa', 'kfar-saba');
    expect(sheet, findsNothing);
    expect(find.descendant(of: chip, matching: find.text('Kfar Saba')), findsOneWidget);
    expect(cardIds(tester), contains('demo-kfarsaba-weizmann'));

    // Partners looks at the same place, with no bar of its own.
    await tester.tap(find.byKey(OutsideSection.partnersKey));
    await tester.pumpAndSettle();
    expect(find.byKey(PartnersView.listKey), findsOneWidget);
    expect(find.byType(ParkAreaBar), findsNothing);
    expect(find.byType(MeetupsAreaPicker), findsNothing);
    expect(find.byKey(PartnersView.controlRowKey), findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('Kfar Saba')), findsOneWidget);
  });

  testWidgets('Parks has one filter row: the radius menu first, a divider, then the details', (tester) async {
    final kit = await openOutside(tester, size: tall);
    await chooseCity(tester, 'raan', 'raanana');
    final row = find.byKey(ParksView.filterRowKey);
    expect(tester.widget<SingleChildScrollView>(row).scrollDirection, Axis.horizontal);
    final radius = find.byKey(ParksView.radiusChipKey);
    expect(find.descendant(of: row, matching: radius), findsOneWidget);
    expect(find.descendant(of: radius, matching: find.text(en.radiusKm(10))), findsOneWidget);
    final y = tester.getCenter(radius).dy;
    for (final detail in ParkDetail.filters) {
      final chip = find.byKey(ParksView.filterKey(detail));
      expect(find.descendant(of: row, matching: chip), findsOneWidget);
      expect(tester.getCenter(chip).dy, moreOrLessEquals(y, epsilon: 1), reason: '${detail.name} is on the same row');
      expect(tester.getCenter(chip).dx, greaterThan(tester.getCenter(radius).dx), reason: 'the radius comes first');
    }

    // The menu: City only around a city, 10 and 25 km.
    await tester.tap(radius);
    await tester.pumpAndSettle();
    for (final option in ParkRadius.values) {
      expect(find.byKey(ParkAreaBar.radiusKey(option)), findsOneWidget);
    }
    await tester.tap(find.byKey(ParkAreaBar.radiusKey(ParkRadius.cityOnly)));
    await tester.pumpAndSettle();
    expect(kit.repo.queries.last.localityCode, 'raanana');
    expect(find.descendant(of: radius, matching: find.text(en.radiusCityOnly)), findsOneWidget);

    // "Missing a park?" stays at the end of the list.
    final suggest = find.byKey(ParksView.suggestKey);
    expect(tester.getTopLeft(suggest).dy, greaterThan(tester.getBottomLeft(card(cardIds(tester).last)).dy));
  });

  testWidgets('Suggest a park and Update details: one row per detail with Yes · No · ?', (tester) async {
    await openOutside(tester, size: tall);
    await tester.tap(find.byKey(ParksView.suggestKey));
    await tester.pumpAndSettle();
    final suggest = find.byKey(SuggestParkScreen.screenKey);
    expect(find.descendant(of: suggest, matching: find.byType(ChoiceChip)), findsNothing);
    expect(find.descendant(of: suggest, matching: find.byType(ParkDetailRow)), findsNWidgets(ParkDetail.values.length));
    for (final detail in ParkDetail.values) {
      final label = find.descendant(of: suggest, matching: find.text(en.detail(detail)));
      final y = tester.getCenter(label).dy;
      for (final answer in ParkAnswer.values) {
        final key = find.byKey(SuggestParkScreen.answerKey(detail, answer));
        expect(tester.getCenter(key).dy, moreOrLessEquals(y, epsilon: 1), reason: '${detail.name}: one row');
      }
    }
    // "Not known" is the default, and screen readers hear the words.
    expect(find.bySemanticsLabel(en.detailAnswer(en.detailShade, en.answerUnknown)), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(SuggestParkScreen.answerKey(ParkDetail.shade, ParkAnswer.unknown))),
      containsSemantics(isSelected: true, isButton: true, hasTapAction: true, label: en.detailAnswer(en.detailShade, en.answerUnknown)),
    );
    expect(find.descendant(of: suggest, matching: find.text(en.imHereWhy)), findsOneWidget, reason: 'its position is sent');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await chooseCity(tester, 'raan', 'raanana');
    await tester.tap(card('demo-raanana-ahuza'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ParkScreen.updateKey));
    await tester.pumpAndSettle();
    final sheet = find.byType(UpdateDetailsSheet);
    expect(find.descendant(of: sheet, matching: find.byType(ChoiceChip)), findsNothing);
    expect(find.descendant(of: sheet, matching: find.byType(ParkDetailRow)), findsNWidgets(ParkDetail.values.length));
    final fenced = find.descendant(of: sheet, matching: find.text(en.detailFenced));
    expect(
      tester.getCenter(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.fenced, ParkAnswer.no))).dy,
      moreOrLessEquals(tester.getCenter(fenced).dy, epsilon: 1),
    );
    // The park's own answers are chosen: Ahuza is fenced.
    expect(
      tester.getSemantics(find.byKey(UpdateDetailsSheet.answerKey(ParkDetail.fenced, ParkAnswer.yes))),
      containsSemantics(isSelected: true, isButton: true, hasTapAction: true, label: en.detailAnswer(en.detailFenced, en.answerYes)),
    );
  });
}
