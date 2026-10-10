import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/features/settings/settings_routes.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/platform/feature_ui.dart';
import 'package:pet_companion/services/findvet/regions/regions.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import '../helpers.dart';
import 'outdoors_test_helpers.dart';

const tall = Size(390, 2400);

void main() {
  setUpOutdoorsTests();

  group('review', () {
    testWidgets('a reviewer approves a detail change and it shows on the park', (tester) async {
      final kit = await openOutside(tester, size: tall, kit: ParksKit(reviewer: true));
      expect(find.text(en.reviewEntry(1)), findsOneWidget);
      await tester.tap(find.byKey(ParksView.reviewKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ParksReviewScreen.screenKey), findsOneWidget);
      expect(find.text(en.reviewDetails), findsOneWidget);
      expect(
        find.text(en.reviewChange(en.detailShade, en.answerUnknown, en.answerYes)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ParksReviewScreen.mapKey('demo-suggestion-shade')));
      await tester.pumpAndSettle();
      expect(kit.launcher.opened.single.path, '/maps/search/');

      await tester.tap(find.byKey(ParksReviewScreen.approveKey('demo-suggestion-shade')));
      await tester.pumpAndSettle();
      expect(kit.repo.reviewActions, ['approve:demo-suggestion-shade']);
      expect(find.text(en.reviewEmpty), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(en.reviewEntryEmpty), findsOneWidget);
      await chooseCity(tester, 'raan', 'raanana');
      expect(
        find.descendant(of: card('demo-raanana-ahuza'), matching: find.text(en.detailShade)),
        findsOneWidget,
        reason: 'the approved shade is a tag now',
      );
    });

    testWidgets('a suggested park is approved into the list; another is rejected', (tester) async {
      final repo = FakeParksRepository(
        latency: Duration.zero,
        pending: [
          ParkSuggestion(
            id: 'new-1',
            kind: SuggestionKind.newPark,
            createdAt: DateTime(2026, 10, 9),
            name: 'Lakeside dog run',
            point: const GeoPoint(32.1880, 34.8690),
            location: SuggestedLocation.device,
            localityCode: 'raanana',
            changes: const {ParkDetail.fenced: ParkAnswer.yes},
          ),
          ParkSuggestion(
            id: 'new-2',
            kind: SuggestionKind.newPark,
            createdAt: DateTime(2026, 10, 9),
            point: israelRegion.localityByCode('herzliya')!.point,
            location: SuggestedLocation.locality,
            localityCode: 'herzliya',
            placeNote: 'Near the marina',
          ),
        ],
      );
      final kit = await openOutside(tester, size: tall, kit: ParksKit(reviewer: true, repository: repo));
      await tester.tap(find.byKey(ParksView.reviewKey));
      await tester.pumpAndSettle();
      expect(find.text('Lakeside dog run'), findsOneWidget);
      expect(find.text(en.reviewFromPhone), findsOneWidget);
      expect(find.text(en.reviewFromCity('Herzliya')), findsOneWidget);
      expect(find.text(en.reviewPlace('Near the marina')), findsOneWidget);

      await tester.tap(find.byKey(ParksReviewScreen.approveKey('new-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ParksReviewScreen.rejectKey('new-2')));
      await tester.pumpAndSettle();
      expect(kit.repo.reviewActions, ['approve:new-1', 'reject:new-2']);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await chooseCity(tester, 'raan', 'raanana');
      expect(find.text('Lakeside dog run'), findsOneWidget);
    });

    testWidgets('a park gone from OpenStreetMap is kept, closed or removed', (tester) async {
      final gone = FakeParksRepository.demoParks().first.copyWith(status: ParkStatus.pendingReview);
      final repo = FakeParksRepository(
        latency: Duration.zero,
        pending: const [],
        vanished: [DogPark(id: 'osm-gone', point: gone.point, streetEn: 'Gone St', localityCode: 'raanana')],
      );
      final kit = await openOutside(tester, size: tall, kit: ParksKit(reviewer: true, repository: repo));
      await tester.tap(find.byKey(ParksView.reviewKey));
      await tester.pumpAndSettle();
      expect(find.text(en.reviewVanished), findsOneWidget);
      expect(find.text("Dog park · Gone St, Ra'anana"), findsOneWidget);
      await tester.tap(find.byKey(ParksReviewScreen.statusKey('osm-gone', ParkStatus.closed)));
      await tester.pumpAndSettle();
      expect(kit.repo.reviewActions, ['status:osm-gone:closed']);
      expect(find.text(en.reviewEmpty), findsOneWidget);
    });

    testWidgets('a reviewer closes or removes a park from its page', (tester) async {
      final kit = await openOutside(tester, size: tall, kit: ParksKit(reviewer: true));
      await chooseCity(tester, 'raan', 'raanana');
      await tester.tap(card('demo-raanana-nesiim'));
      await tester.pumpAndSettle();
      expect(find.text(en.reviewerTools), findsOneWidget);
      await tester.tap(find.byKey(ParkScreen.reviewerKey(ParkStatus.closed)));
      await tester.pumpAndSettle();
      expect(kit.repo.reviewActions, ['status:demo-raanana-nesiim:closed']);
      expect(find.text(en.closedLabel), findsOneWidget);
      expect(find.byKey(ParkScreen.reviewerKey(ParkStatus.active)), findsOneWidget, reason: 'now it can reopen');

      await tester.tap(find.byKey(ParkScreen.reviewerKey(ParkStatus.removed)));
      await tester.pumpAndSettle();
      expect(find.text(en.removeConfirm), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, en.removePark));
      await tester.pumpAndSettle();
      expect(kit.repo.reviewActions.last, 'status:demo-raanana-nesiim:removed');
      expect(find.byKey(ParkScreen.screenKey), findsNothing, reason: 'back to the list');
      expect(card('demo-raanana-nesiim'), findsNothing);
    });

    testWidgets('members get no reviewer tools on a park page', (tester) async {
      await openOutside(tester, size: tall);
      await chooseCity(tester, 'raan', 'raanana');
      await tester.tap(card('demo-raanana-nesiim'));
      await tester.pumpAndSettle();
      expect(find.text(en.reviewerTools), findsNothing);
    });

    testWidgets('the review page is closed to members', (tester) async {
      await openOutside(tester);
      final context = tester.element(find.byKey(OutsideSection.sectionKey));
      expect(canOpenFeature(context, 'parks-review'), isFalse);
      expect(canOpenFeature(context, 'pick-park'), isTrue);
      openParksReview(context);
      await tester.pumpAndSettle();
      expect(find.byKey(ParksReviewScreen.screenKey), findsNothing);
    });
  });

  group('seams for meetups', () {
    testWidgets('the park picker answers the chosen park, saved first', (tester) async {
      await openOutside(tester, size: tall, kit: ParksKit(favorites: {'demo-tlv-meir'}));
      final context = tester.element(find.byKey(OutsideSection.sectionKey));
      PickedPark? picked;
      openFeature<PickedPark>(context, 'pick-park', '').then((p) => picked = p);
      await tester.pumpAndSettle();
      expect(find.byKey(ParkPickerScreen.screenKey), findsOneWidget);
      await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
      await tester.pumpAndSettle();
      expect(cardIds(tester).first, 'demo-tlv-meir');
      await tester.tap(card('demo-raanana-ahuza'));
      await tester.pumpAndSettle();
      expect(picked?.id, 'demo-raanana-ahuza');
      expect(picked?.displayName, "Dog park · Ahuza, Ra'anana");
      expect(picked?.tags, [ParkDetail.fenced, ParkDetail.water, ParkDetail.lighting]);
    });

    testWidgets('the park action opens a park by id', (tester) async {
      await openOutside(tester);
      final context = tester.element(find.byKey(OutsideSection.sectionKey));
      openFeature<Object>(context, 'park', '', {'parkId': 'demo-jlm-refaim'});
      await tester.pumpAndSettle();
      expect(find.byKey(ParkScreen.screenKey), findsOneWidget);
      expect(find.text('Emek Refaim dog park'), findsOneWidget);
    });
  });

  testWidgets('Settings credits OpenStreetMap', (tester) async {
    await pumpApp(tester, size: tall);
    await signInAsDemo(tester);
    final context = tester.element(find.byType(AppBottomNav));
    openSettings(context);
    await tester.pumpAndSettle();
    expect(find.byKey(OsmAboutCredit.creditKey), findsOneWidget);
  });

  group('Hebrew at 320 px', () {
    testWidgets('the four Community sections fit and the parks read right to left', (tester) async {
      await openOutside(
        tester,
        language: AppLanguage.hebrew,
        size: const Size(320, 640),
        kit: ParksKit(favorites: {'demo-raanana-park'}),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(he.sectionOutside), findsOneWidget);
      expect(find.text(he.outsideParks), findsOneWidget);
      expect(find.text(he.outsidePartners), findsOneWidget);
      expect(Directionality.of(tester.element(find.byKey(ParksView.listKey))), TextDirection.rtl);

      await tester.tap(find.byKey(ParkAreaPicker.nearMeKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Filters wrap instead of overflowing.
      await scrollTo(tester, find.byKey(ParksView.filterKey(ParkDetail.smallDogs)));
      await tester.tap(find.byKey(ParksView.filterKey(ParkDetail.smallDogs)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text(he.myParks));
      await scrollTo(tester, card('demo-raanana-park'));
      expect(tester.takeException(), isNull);

      await tester.tap(card('demo-raanana-park'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('גינת הכלבים בפארק רעננה'), findsWidgets);
      expect(find.text(he.whatsThere), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(he.osmCredit),
        200,
        scrollable: find
            .descendant(of: find.byKey(ParkScreen.screenKey), matching: find.byType(Scrollable))
            .first,
      );
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(ParkScreen.updateKey),
        -200,
        scrollable: find
            .descendant(of: find.byKey(ParkScreen.screenKey), matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ParkScreen.updateKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.updateTitle), findsWidgets);
    });

    testWidgets('the suggestion form and the partners card fit', (tester) async {
      await openOutside(tester, language: AppLanguage.hebrew, size: const Size(320, 640));
      await tester.tap(find.byKey(OutsideSection.partnersKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.partnersSoonTitle), findsOneWidget);
      await tester.tap(find.byKey(OutsideSection.parksKey));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(ParksView.suggestKey));
      await tester.tap(find.byKey(ParksView.suggestKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.suggestIntro), findsOneWidget);
    });
  });
}
