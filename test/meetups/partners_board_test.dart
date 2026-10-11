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
import 'package:pet_companion/services/findvet/data/location_service.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

import 'meetups_test_helpers.dart';

/// A tall phone, so the whole board is built without scrolling.
const tall = Size(390, 3200);

void main() {
  setUpMeetupsTests();

  testWidgets('Outside opens on Partners: the profile city, the safety line, the soonest ads first', (
    tester,
  ) async {
    final kit = await openPartners(tester, size: tall);
    expect(board, findsOneWidget);
    expect(find.text(en.safetyStrip), findsOneWidget);
    expect(find.byKey(PartnersView.sampleKey), findsOneWidget);
    // The demo profile says "Tel Aviv": Tel Aviv-Yafo, up to 10 km.
    expect(find.text('Tel Aviv-Yafo'), findsOneWidget);
    final area = containerOf(tester).read(meetupsAreaProvider).area!;
    expect(area.radius, ParkRadius.km10);
    expect(kit.settings.values.keys.where((k) => k.startsWith('meetups.')), isEmpty, reason: 'nothing stored yet');

    // One "Filters" button, no chips on the board. The animal starts on the
    // selected pet's kind (Kelly: dogs), as in the rest of the Community,
    // so no filter counts as on. Today first (nearest first), then Tuesday.
    expect(find.text(en.filters), findsOneWidget);
    expect(find.byKey(PartnersView.filtersClearKey), findsNothing);
    expect(find.byKey(PartnersView.scopeKey(CommunityScope.dogs)), findsNothing);
    expect(find.byKey(ParkAreaBar.radiusKey(ParkRadius.km10)), findsNothing);
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-priya', 'demo-meetup-mine']);
    await openFilters(tester);
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
    await openFilters(tester);
    expect(chipOn(tester, PartnersView.radiusKey(ParkRadius.km10)), isTrue);
    await tapOn(tester, find.byKey(PartnersView.radiusKey(ParkRadius.km25)));
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-maya', 'demo-meetup-dana']));
    await closeFilters(tester);
    // Distances between city centres (or the park), about.
    expect(find.descendant(of: card('demo-meetup-dana'), matching: find.textContaining('about')), findsOneWidget);
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.radiusKey(ParkRadius.cityOnly)));
    expect(listedIds(tester), isNot(contains('demo-meetup-sam')));
    expect(containerOf(tester).read(settingsStoreProvider).read(meetupsAreaKey('demo')), 'tel-aviv-yafo|cityOnly');
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

  testWidgets('the Filters button counts what differs from the start; Clear and Clear all go back', (tester) async {
    final kit = await openPartners(tester, size: tall, kit: MeetupsKit(favorites: {'demo-tlv-meir'}));
    await openFilters(tester);
    expect(tester.widget<TextButton>(find.byKey(PartnersFiltersSheet.clearAllKey)).onPressed, isNull);
    await tapOn(tester, find.byKey(PartnersView.radiusKey(ParkRadius.km25)));
    await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.walk)));
    await tapOn(tester, find.byKey(PartnersView.scopeKey(CommunityScope.everything)));
    await tapOn(tester, find.byKey(PartnersView.whenKey(MeetupWhen.thisWeek)));
    expect(containerOf(tester).read(partnersFilterCountProvider), 4);
    await tapOn(tester, find.byKey(PartnersView.myParksKey));
    expect(containerOf(tester).read(partnersFilterCountProvider), 5);
    await closeFilters(tester);
    expect(find.text(en.filtersCount(5)), findsOneWidget);
    expect(find.bySemanticsLabel(en.filtersLabel(5)), findsOneWidget);
    expect(kit.settings.values[meetupsAreaKey('demo')], 'tel-aviv-yafo|km25');

    // "Clear": every filter back, the animal to Kelly's kind, 10 km again.
    await tapOn(tester, find.byKey(PartnersView.filtersClearKey));
    expect(find.text(en.filters), findsOneWidget);
    expect(find.byKey(PartnersView.filtersClearKey), findsNothing);
    final container = containerOf(tester);
    expect(container.read(meetupFiltersProvider).isEmpty, isTrue);
    expect(container.read(communityScopeProvider), CommunityScope.dogs);
    expect(container.read(meetupsAreaProvider).area!.radius, ParkRadius.km10);
    expect(kit.settings.values[meetupsAreaKey('demo')], 'tel-aviv-yafo|km10');
    expect(listedIds(tester), ['demo-meetup-noa', 'demo-meetup-priya', 'demo-meetup-mine']);

    // "Clear all" in the sheet does the same.
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.play)));
    await tapOn(tester, find.byKey(PartnersView.radiusKey(ParkRadius.cityOnly)));
    expect(containerOf(tester).read(partnersFilterCountProvider), 2);
    await tapOn(tester, find.byKey(PartnersFiltersSheet.clearAllKey));
    expect(containerOf(tester).read(partnersFilterCountProvider), 0);
    expect(chipOn(tester, PartnersView.kindKey(null)), isTrue);
    expect(chipOn(tester, PartnersView.radiusKey(ParkRadius.km10)), isTrue);
    expect(find.text(en.filtersShow(3)), findsOneWidget);
    await closeFilters(tester);
    expect(find.text(en.filters), findsOneWidget);
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
    await tester.tap(find.byKey(ParkAreaBar.changeKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(MeetupsAreaPicker.cityFieldKey), 'Herzl');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MeetupsAreaPicker.cityKey('herzliya')));
    await tester.pumpAndSettle();
    await openFilters(tester);
    await tapOn(tester, find.byKey(PartnersView.radiusKey(ParkRadius.cityOnly)));
    await closeFilters(tester);
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
    expect(find.text(en.areaWhy), findsOneWidget);
    expect(kit.location.asked, 0, reason: 'nothing is asked before the tap');
    await tester.enterText(find.byKey(MeetupsAreaPicker.cityFieldKey), 'raan');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MeetupsAreaPicker.cityKey('raanana')));
    await tester.pumpAndSettle();
    expect(listedIds(tester), containsAll(['demo-meetup-sam', 'demo-meetup-dana']));
    expect(kit.settings.values[meetupsAreaKey('demo')], 'raanana|km10');

    // The next start remembers it.
    await openPartners(tester, kit: kit, size: tall);
    expect(find.text(en.areaQuestion), findsNothing);
    expect(find.text("Ra'anana"), findsOneWidget);
  });

  testWidgets('Near me only picks the nearest city: the position is neither kept nor sent', (tester) async {
    final kit = MeetupsKit(profileCity: '');
    await openPartners(tester, kit: kit, size: tall);
    await tester.tap(find.byKey(MeetupsAreaPicker.nearMeKey));
    await tester.pumpAndSettle();
    expect(kit.location.asked, 1);
    expect(find.text("Ra'anana"), findsOneWidget);
    expect(kit.settings.values[meetupsAreaKey('demo')], 'raanana|km10');
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
