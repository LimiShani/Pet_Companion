import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/community/community_routes.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/platform/feature_ui.dart';
import 'package:pet_companion/services/community/data/audience.dart';
import 'package:pet_companion/widgets/add_sheet.dart';
import 'package:pet_companion/services/findvet/data/location_service.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import 'meetups_test_helpers.dart';

/// A tall phone, so the whole board is built without scrolling.
const tall = Size(390, 3200);

void main() {
  setUpMeetupsTests();

  testWidgets('Outside opens on Partners: the profile city in the header, one row of controls, the soonest ads first', (
    tester,
  ) async {
    final kit = await openPartners(tester, size: tall);
    expect(board, findsOneWidget);
    // No safety strip on the board (the form and the join sheet keep it).
    expect(find.text(en.safetyStrip), findsNothing);
    expect(find.byKey(PartnersView.sampleKey), findsOneWidget);
    // The demo profile says "Tel Aviv": Tel Aviv-Yafo, up to 10 km, as the
    // header's chip; no area bar in the board.
    final chip = find.byKey(OutsideScreen.areaChipKey);
    expect(find.descendant(of: chip, matching: find.text('Tel Aviv-Yafo')), findsOneWidget);
    expect(find.byType(ParkAreaBar), findsNothing);
    final area = containerOf(tester).read(meetupsAreaProvider).area!;
    expect(area.radius, ParkRadius.km10);
    expect(
      kit.settings.values.keys.where((k) => k.startsWith('meetups.') || k.startsWith('outdoors.')),
      isEmpty,
      reason: 'nothing stored yet',
    );

    // One row: "Filters", "Up to 10 km", "My ads (2)", side by side. The
    // animal starts on the selected pet's kind (Kelly: dogs), as in the
    // Community, so no filter counts as on. Today first (nearest first),
    // then Tuesday.
    final row = find.byKey(PartnersView.controlRowKey);
    final controls = [
      find.byKey(PartnersView.filtersKey),
      find.byKey(PartnersView.radiusChipKey),
      find.byKey(PartnersView.myAdsKey),
    ];
    for (final control in controls) {
      expect(find.descendant(of: row, matching: control), findsOneWidget);
      expect(tester.getCenter(control).dy, moreOrLessEquals(tester.getCenter(row).dy, epsilon: 1));
    }
    expect(tester.getCenter(controls[0]).dx, lessThan(tester.getCenter(controls[1]).dx));
    expect(tester.getCenter(controls[1]).dx, lessThan(tester.getCenter(controls[2]).dx));
    expect(find.descendant(of: row, matching: find.text(en.filters)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text(outdoorsEn.radiusKm(10))), findsOneWidget);
    expect(find.byKey(PartnersView.scopeKey(CommunityScope.dogs)), findsNothing);
    // A new ad is a row of the tab's "+" (its Add sheet).
    expect(tester.widget(find.byKey(AddFab.fabKey)), isA<AddFab>());
    expect(find.text(en.newAd), findsNothing);
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-priya', 'demo-meetup-mine']);
    await openFilters(tester);
    expect(find.text(en.filterAnimal), findsOneWidget);
    expect(chipOn(tester, PartnersView.scopeKey(CommunityScope.dogs)), isTrue);
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.everything)));
    await closeFilters(tester);
    // Everything: Luna the cat too, on Saturday.
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-priya', 'demo-meetup-mine', 'demo-meetup-jonas']);
    expect(find.text(en.filtersCount(1)), findsOneWidget);
    // The card: the pet, the place, when, the note, the author.
    final priya = card('demo-meetup-priya');
    expect(find.descendant(of: priya, matching: find.text('Chico')), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.text('Meir Garden dog run, Tel Aviv-Yafo')), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.textContaining('18:00–19:00')), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.text('Small dogs welcome, we bring a ball.')), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.textContaining('Priya')), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.text(en.detailWaterOf(outdoorsEn))), findsOneWidget);
    expect(find.descendant(of: priya, matching: find.byKey(MeetupCard.joinKey('demo-meetup-priya'))), findsOneWidget);
    // The demo's own ad: no join button, a way to manage it.
    expect(find.byKey(MeetupCard.joinKey('demo-meetup-mine')), findsNothing);
    expect(find.byKey(MeetupCard.manageKey('demo-meetup-mine')), findsOneWidget);
    expect(find.byKey(PartnersView.myAdsKey), findsOneWidget);
    expect(find.text(en.myAdsCount(2)), findsOneWidget);
    // The recurring one says its days.
    expect(find.descendant(of: card('demo-meetup-noa'), matching: find.textContaining('Mon, Wed · Evening')), findsOneWidget);
  });

  testWidgets('a wider radius asks for the cities in range; City only for the city alone', (tester) async {
    await openPartners(tester, size: tall);
    // The distance is a chip of its own, not in the filters sheet.
    await openFilters(tester);
    expect(find.byKey(PartnersView.radiusKey(ParkRadius.km10)), findsNothing);
    await closeFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.radiusChipKey));
    for (final option in ParkRadius.values) {
      expect(find.byKey(PartnersView.radiusKey(option)), findsOneWidget);
    }
    await tester.tap(find.byKey(PartnersView.radiusKey(ParkRadius.km25)));
    await tester.pumpAndSettle();
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-maya', 'demo-meetup-dana']));
    expect(find.text(outdoorsEn.radiusKm(25)), findsOneWidget);
    expect(find.text(en.filters), findsOneWidget, reason: 'the distance is no filter of the sheet');
    // Distances between city centres (or the park), about.
    expect(find.descendant(of: card('demo-meetup-dana'), matching: find.textContaining('about')), findsOneWidget);
    await chooseRadius(tester, ParkRadius.cityOnly);
    expect(listedIds(tester), isNot(contains('demo-meetup-sam')));
    // Outside's one area keeps the choice, for the parks too.
    expect(containerOf(tester).read(settingsStoreProvider).read(outsideAreaKey('demo')), 'tel-aviv-yafo|cityOnly');
    expect(containerOf(tester).read(outsideAreaProvider).area?.radius, ParkRadius.cityOnly);
  });

  testWidgets('filters: kind, the animal chips, when, my parks; empty says so and clears', (tester) async {
    await openPartners(tester, size: tall, kit: MeetupsKit(favorites: {'demo-tlv-meir'}));
    // The sheet's choices apply at once: the ads behind it follow.
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.play)));
    expect(listedIds(tester), ['demo-meetup-priya']);
    expect(find.text(en.filtersShow(1)), findsOneWidget);
    await tapOn(tester, find.byKey(PartnersView.kindKey(null)));

    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.cats)));
    expect(listedIds(tester), ['demo-meetup-jonas'], reason: 'Luna is a cat');
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.everything)));

    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.today)));
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-priya']);
    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.recurring)));
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-mine', 'demo-meetup-jonas']);
    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.recurring)));

    await tapOn(tester, find.byKey(PartnersView.myParksKey));
    expect(listedIds(tester), ['demo-meetup-priya']);
    await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.walk)));
    expect(listedIds(tester), isEmpty);
    expect(find.text(en.filtersShow(0)), findsOneWidget);
    await closeFilters(tester);
    expect(find.text(en.emptyFiltered), findsOneWidget);
    await tester.tap(find.byKey(PartnersView.clearFiltersKey));
    await tester.pumpAndSettle();
    expect(listedIds(tester), hasLength(4));
    // The empty state widens to every animal, which the button counts.
    expect(find.text(en.filtersCount(1)), findsOneWidget);
  });

  testWidgets('the Filters chip counts what differs from the start; Clear all goes back', (tester) async {
    await openPartners(tester, size: tall, kit: MeetupsKit(favorites: {'demo-tlv-meir'}));
    await openFilters(tester);
    expect(tester.widget<TextButton>(find.byKey(PartnersFiltersSheet.clearAllKey)).onPressed, isNull);
    await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.walk)));
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.everything)));
    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.thisWeek)));
    expect(containerOf(tester).read(partnersFilterCountProvider), 3);
    await tapOn(tester, find.byKey(PartnersView.myParksKey));
    expect(containerOf(tester).read(partnersFilterCountProvider), 4);
    await closeFilters(tester);
    expect(find.text(en.filtersCount(4)), findsOneWidget);
    expect(find.bySemanticsLabel(en.filtersLabel(4)), findsOneWidget);

    // The distance has its own chip: it is not counted.
    await chooseRadius(tester, ParkRadius.km25);
    expect(containerOf(tester).read(partnersFilterCountProvider), 4);

    // "Clear all": every filter back, the animal to Kelly's kind; the
    // distance stays (it is Outside's, shared with the parks).
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersFiltersSheet.clearAllKey));
    final container = containerOf(tester);
    expect(container.read(partnersFilterCountProvider), 0);
    expect(chipOn(tester, PartnersView.kindKey(null)), isTrue);
    expect(container.read(meetupFiltersProvider).isEmpty, isTrue);
    expect(container.read(meetupAnimalProvider), CommunityScope.dogs);
    expect(container.read(meetupsAreaProvider).area!.radius, ParkRadius.km25);
    await closeFilters(tester);
    expect(find.text(en.filters), findsOneWidget);
    expect(find.bySemanticsLabel(en.filtersLabel(0)), findsOneWidget);
  });

  testWidgets('the board\'s animal is its own: it leaves the Community\'s choice alone, and the other way round', (
    tester,
  ) async {
    await openPartners(tester, size: tall);
    final container = containerOf(tester);
    expect(container.read(communityScopeProvider), CommunityScope.dogs);
    expect(container.read(meetupAnimalProvider), CommunityScope.dogs);

    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.cats)));
    await closeFilters(tester);
    expect(container.read(meetupAnimalProvider), CommunityScope.cats);
    expect(container.read(communityScopeProvider), CommunityScope.dogs, reason: 'the Community is unchanged');
    expect(listedIds(tester), ['demo-meetup-jonas']);

    // "Clear filters" on an empty board widens the board alone, too.
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.today)));
    await closeFilters(tester);
    expect(listedIds(tester), isEmpty, reason: 'Luna walks on Saturdays');
    await tester.tap(find.byKey(PartnersView.clearFiltersKey));
    await tester.pumpAndSettle();
    expect(container.read(meetupAnimalProvider), CommunityScope.everything);
    expect(container.read(communityScopeProvider), CommunityScope.dogs, reason: 'the Community is unchanged');

    // And the Community's choice leaves the board's.
    container.read(communityScopeProvider.notifier).select(CommunityScope.cats);
    await tester.pumpAndSettle();
    expect(container.read(meetupAnimalProvider), CommunityScope.everything);
    expect(listedIds(tester), hasLength(4));
  });

  testWidgets('on an ordinary phone the first ad shows without scrolling', (tester) async {
    await openPartners(tester);
    final first = card('demo-meetup-noa');
    expect(first, findsOneWidget);
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getTopLeft(first).dy, lessThan(view.height * 0.75));
  });

  testWidgets('an area without ads offers to look further', (tester) async {
    await openPartners(tester, size: tall);
    await changeArea(tester, 'Herzl', 'herzliya');
    expect(find.descendant(of: find.byKey(OutsideScreen.areaChipKey), matching: find.text('Herzliya')), findsOneWidget);
    await chooseRadius(tester, ParkRadius.cityOnly);
    expect(find.text(en.emptyFiltered), findsOneWidget, reason: 'the dogs chip is on');
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.everything)));
    await closeFilters(tester);
    expect(find.text(en.emptyTitle), findsOneWidget);
    await tester.tap(find.byKey(PartnersView.widerKey));
    await tester.pumpAndSettle();
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-noa']));
  });

  testWidgets('without a profile city the board asks once; the choice is kept on the phone', (tester) async {
    final kit = MeetupsKit(profileCity: '');
    await openPartners(tester, kit: kit, size: tall);
    expect(find.text(en.areaQuestion), findsOneWidget);
    // The one location sentence of Outside, as on the parks' picker.
    expect(find.text(outdoorsEn.locationWhy), findsOneWidget);
    expect(find.byKey(OutsideScreen.areaChipKey), findsNothing, reason: 'no area yet');
    expect(kit.location.asked, 0, reason: 'nothing is asked before the tap');
    await tester.enterText(find.byKey(MeetupsAreaPicker.cityFieldKey), 'raan');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MeetupsAreaPicker.cityKey('raanana')));
    await tester.pumpAndSettle();
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-dana']));
    expect(kit.settings.values[outsideAreaKey('demo')], 'raanana|km10');

    // The next start remembers it.
    await openPartners(tester, kit: kit, size: tall);
    expect(find.text(en.areaQuestion), findsNothing);
    expect(find.descendant(of: find.byKey(OutsideScreen.areaChipKey), matching: find.text("Ra'anana")), findsOneWidget);
  });

  testWidgets('a city the board kept before Outside had one area is carried over', (tester) async {
    final kit = MeetupsKit();
    await kit.settings.write(meetupsAreaKey('demo'), 'kfar-saba|km25');
    await openPartners(tester, kit: kit, size: tall);
    expect(find.descendant(of: find.byKey(OutsideScreen.areaChipKey), matching: find.text('Kfar Saba')), findsOneWidget);
    expect(containerOf(tester).read(meetupsAreaProvider).area?.radius, ParkRadius.km25);
    expect(kit.settings.read(outsideAreaKey('demo')), 'kfar-saba|km25');
    expect(kit.settings.read(meetupsAreaKey('demo')), isNull);
  });

  testWidgets('Near me looks around the nearest city: the position is neither kept nor sent', (tester) async {
    final kit = MeetupsKit(profileCity: '');
    await openPartners(tester, kit: kit, size: tall);
    await tester.tap(find.byKey(MeetupsAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    expect(kit.location.asked, 1);
    expect(find.descendant(of: find.byKey(OutsideScreen.areaChipKey), matching: find.text("Ra'anana")), findsOneWidget);
    expect(containerOf(tester).read(meetupsAreaProvider).area?.city.code, 'raanana');
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-dana']));
    expect(kit.settings.values.keys.where((k) => k.startsWith('outdoors.') || k.startsWith('meetups.')), isEmpty);
    expect(kit.settings.values.values.any((v) => v.contains('32.18')), isFalse);
  });

  testWidgets('a refused location says why and a city still works', (tester) async {
    final kit = MeetupsKit(
      profileCity: '',
      location: const LocationResult(LocationOutcome.denied),
    );
    await openPartners(tester, kit: kit, size: tall);
    await tester.tap(find.byKey(MeetupsAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    expect(find.text(outdoorsEn.problemDenied), findsOneWidget);
    await tester.enterText(find.byKey(MeetupsAreaPicker.cityFieldKey), 'kfar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MeetupsAreaPicker.cityKey('kfar-saba')));
    await tester.pumpAndSettle();
    expect(listedIds(tester), contains('demo-meetup-maya'));
  });

  testWidgets('I want to join: the message sheet, then the chat of two with the message ready; the answer counts', (
    tester,
  ) async {
    final kit = await openPartners(tester, size: tall);
    await tapOn(tester, find.byKey(MeetupCard.joinKey('demo-meetup-noa')));
    expect(find.text(en.joinTitle('Noa')), findsOneWidget);
    expect(find.text(en.joinBody('Noa')), findsOneWidget);
    // The selected pet comes along; "Just me" changes the message.
    final draft = en.draftWalkPet('Noa', 'Yarkon Park, by the Seven Mills', 'Kelly');
    expect(find.text(draft), findsOneWidget);
    await tester.tap(find.byKey(JoinMeetupSheet.justMeKey));
    await tester.pumpAndSettle();
    expect(find.text(en.draftWalk('Noa', 'Yarkon Park, by the Seven Mills')), findsOneWidget);
    await tester.tap(find.byKey(JoinMeetupSheet.petKey('kelly')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(JoinMeetupSheet.sendKey));
    await tester.pumpAndSettle();

    // The chat with Noa is open, the message waiting in the field.
    final location = GoRouter.of(tester.element(find.byType(AppBottomNav))).state.uri.toString();
    expect(location, startsWith('${CommunityRoutes.root}/chat/'));
    expect(find.text(draft), findsOneWidget);
    expect(kit.repo.answers['demo-meetup-noa']?.keys, ['demo']);

    // Back on the board: answered, and the chat one tap away.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: card('demo-meetup-noa'), matching: find.text(en.answeredTag)), findsOneWidget);
    expect(find.byKey(MeetupCard.chatKey('demo-meetup-noa')), findsOneWidget);
    expect(find.descendant(of: card('demo-meetup-noa'), matching: find.textContaining(en.answers(1))), findsOneWidget);
  });

  testWidgets('a report takes the ad off the reporter\'s board; blocking hides the member\'s ads', (tester) async {
    final kit = await openPartners(tester, size: tall);
    await tapOn(tester, find.byKey(MeetupCard.menuKey('demo-meetup-priya')));
    await tester.tap(find.byKey(MeetupCard.reportItemKey));
    await tester.pumpAndSettle();
    expect(find.text(en.reportTitle), findsOneWidget);
    await tester.tap(find.text(communityEn.reportSpam));
    await tester.pumpAndSettle();
    expect(find.text(en.reportThanks), findsOneWidget);
    expect(kit.repo.reports['demo-meetup-priya'], isNotNull);
    expect(card('demo-meetup-priya'), findsNothing);

    await tapOn(tester, find.byKey(MeetupCard.menuKey('demo-meetup-noa')));
    await tester.tap(find.byKey(MeetupCard.blockItemKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(communityEn.blockConfirm));
    await tester.pumpAndSettle();
    expect(card('demo-meetup-noa'), findsNothing);
  });

  testWidgets('a member page lists their open ads; a tap opens the ad', (tester) async {
    await openPartners(tester);
    GoRouter.of(tester.element(find.byType(AppBottomNav))).go(CommunityRoutes.member('u-sam'));
    await tester.pumpAndSettle();
    expect(find.byKey(MemberMeetupsSection.sectionKey), findsOneWidget);
    expect(find.text(en.memberAds), findsOneWidget);
    await tapOn(tester, find.text('Pepper'));
    expect(find.byKey(MeetupScreen.screenKey), findsOneWidget);
    expect(find.byKey(MeetupCard.joinKey('demo-meetup-sam')), findsOneWidget);
  });

  testWidgets('a push opens the ad; an ad no longer shown says so', (tester) async {
    await openPartners(tester);
    final context = tester.element(find.byType(AppBottomNav));
    expect(canOpenFeature(context, 'meetup'), isTrue);
    openFeature<Object>(context, 'meetup', '', {'id': 'demo-meetup-maya'});
    await tester.pumpAndSettle();
    expect(find.byKey(MeetupScreen.screenKey), findsOneWidget);
    expect(find.text('Biscuit'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    openFeature<Object>(context, 'meetup', '', {'id': 'gone'});
    await tester.pumpAndSettle();
    expect(find.text(en.adGone), findsOneWidget);
  });

  testWidgets('without the meetups capability Outside opens on Parks and Partners is still to come', (tester) async {
    await openPartners(
      tester,
      kit: MeetupsKit(
        access: FakeAccessRepository()..users['demo'] = {'community.meetups.view': AccessRule.deny},
      ),
    );
    expect(find.byKey(ParksView.listKey), findsOneWidget);
    await tester.tap(find.byKey(OutsideSection.partnersKey));
    await tester.pumpAndSettle();
    expect(find.byKey(OutsideSection.partnersSoonKey), findsOneWidget);
    expect(board, findsNothing);
  });

  testWidgets('with meetups but no parks, Outside is the board alone', (tester) async {
    await openPartners(
      tester,
      kit: MeetupsKit(
        access: FakeAccessRepository()..users['demo'] = {'community.parks.view': AccessRule.deny},
      ),
    );
    expect(board, findsOneWidget);
    expect(find.byKey(OutsideSection.parksKey), findsNothing);
  });
}

extension on MeetupsL10n {
  /// The tag of a park's water tap, as the parks feature words it.
  String detailWaterOf(OutdoorsL10n outdoors) => outdoors.detailWater;
}
