import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/widgets/add_sheet.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'meetups_test_helpers.dart';

/// A tall phone, so a whole form or list is built without scrolling.
const tall = Size(390, 3200);

/// The tab's "+", then "Plan a walk or play date" in its Add sheet.
Future<void> openForm(WidgetTester tester) async {
  await tapOn(tester, find.byKey(AddFab.fabKey));
  await tapOn(tester, find.byKey(AddSheet.rowKey('plan-walk')));
  expect(find.byKey(MeetupFormScreen.screenKey), findsOneWidget);
}

Future<void> submit(WidgetTester tester) => tapOn(tester, find.byKey(MeetupFormScreen.submitKey));

/// Picks a park in the park picker: Ra'anana, then [parkId]. The picker
/// starts on Outside's area (the profile's Tel Aviv-Yafo); its "Change"
/// opens the same sheet as the header's chip.
Future<void> pickRaananaPark(WidgetTester tester, String parkId) async {
  await tapOn(tester, find.byKey(MeetupFormScreen.chooseParkKey));
  expect(find.byKey(ParkPickerScreen.screenKey), findsOneWidget);
  await tapOn(tester, find.byKey(ParkAreaBar.changeKey));
  expect(find.byKey(OutsideAreaSheet.sheetKey), findsOneWidget);
  await tester.enterText(find.byKey(ParkAreaPicker.cityFieldKey), 'raan');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ParkAreaPicker.cityKey('raanana')));
  await tester.pumpAndSettle();
  expect(find.byKey(OutsideAreaSheet.sheetKey), findsNothing);
  await tapOn(tester, find.byKey(ParkCard.keyOf(parkId)));
}

Future<void> openMyAds(WidgetTester tester) async {
  await tapOn(tester, find.byKey(PartnersView.myAdsKey));
  expect(find.byKey(MyMeetupsScreen.screenKey), findsOneWidget);
}

void main() {
  setUpMeetupsTests();

  group('a new ad', () {
    testWidgets('at a park from the picker: the pet, the kind, every week; it shows on the board', (tester) async {
      final kit = await openPartners(tester, size: tall);
      await openForm(tester);
      expect(find.text(en.formNewTitle), findsWidgets);
      // Kelly (the selected pet) is chosen; a park is asked for.
      await submit(tester);
      expect(find.text(en.parkRequired), findsOneWidget);
      expect(kit.repo.saved, isEmpty);

      await pickRaananaPark(tester, 'demo-raanana-ahuza');
      expect(find.text("Dog park · Ahuza, Ra'anana"), findsOneWidget);
      await tester.tap(find.byKey(MeetupFormScreen.kindKey(MeetupKind.play)));
      await tester.tap(find.byKey(MeetupFormScreen.dayKey(DateTime.saturday)));
      await tester.tap(find.byKey(MeetupFormScreen.partKey(DayPart.evening)));
      await tester.tap(find.byKey(MeetupFormScreen.sizeKey(PetSize.small)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MeetupFormScreen.noteKey), '  Ball games for small dogs  ');
      await submit(tester);

      expect(find.text(en.posted), findsOneWidget);
      expect(find.byKey(MeetupFormScreen.screenKey), findsNothing);
      final draft = kit.repo.saved.single;
      expect(draft.kind, MeetupKind.play);
      expect(draft.pet?.name, 'Kelly');
      expect(draft.pet?.size, PetSize.medium, reason: 'Kelly weighs 23 kg');
      expect(draft.parkId, 'demo-raanana-ahuza');
      expect((draft.time as RecurringTime).weekdays, {DateTime.monday, DateTime.saturday});
      expect((draft.time as RecurringTime).part, DayPart.evening);
      expect(draft.suits, {PetSize.small});
      expect(draft.note, 'Ball games for small dogs');
      final ad = kit.repo.ads.last;
      expect(ad.localityCode, 'raanana');
      expect(ad.expiresAt, monday.add(const Duration(days: 30)));
    });

    testWidgets('another place: a city and a public place; once, with its hours', (tester) async {
      final kit = await openPartners(tester, size: tall);
      await openForm(tester);
      await tester.tap(find.byKey(MeetupFormScreen.otherModeKey));
      await tester.pumpAndSettle();
      // The board's city is the default.
      expect(find.text('Tel Aviv-Yafo'), findsWidgets);
      await tester.tap(find.byKey(MeetupFormScreen.noPetKey));
      await tester.tap(find.byKey(MeetupFormScreen.onceKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('12.10.26'), findsOneWidget);
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.textContaining('11:00'), findsOneWidget);
      await submit(tester);
      expect(find.text(en.placeRequired), findsOneWidget);
      await tester.enterText(find.byKey(MeetupFormScreen.placeKey), 'The bridge in Yarkon Park');
      await submit(tester);

      final draft = kit.repo.saved.single;
      expect(draft.pet, isNull);
      expect(draft.parkId, isNull);
      expect(draft.localityCode, 'tel-aviv-yafo');
      expect(draft.placeText, 'The bridge in Yarkon Park');
      final time = draft.time as OneOffTime;
      expect(time.start, DateTime(2026, 10, 12, 10));
      expect(time.end, DateTime(2026, 10, 12, 11));
      expect(kit.repo.ads.last.expiresAt, time.end);
    });

    testWidgets('the daily limit is said in words', (tester) async {
      final repo = FakeMeetupsRepository(latency: Duration.zero, now: clock, viewerId: () => 'demo');
      for (var i = 0; i < 3; i++) {
        await repo.save(
          const MeetupDraft(
            kind: MeetupKind.walk,
            parkId: 'demo-tlv-meir',
            time: RecurringTime({1}, DayPart.noon),
          ),
        );
      }
      await openPartners(tester, size: tall, kit: MeetupsKit(repo: repo));
      await openForm(tester);
      await tester.tap(find.byKey(MeetupFormScreen.otherModeKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MeetupFormScreen.placeKey), 'The beach promenade');
      await submit(tester);
      expect(find.text(en.errRateLimited), findsOneWidget);
      expect(find.byKey(MeetupFormScreen.screenKey), findsOneWidget, reason: 'nothing is lost');
    });
  });

  group('My ads', () {
    testWidgets('open, ended: renew; close; the group for everyone who answered', (tester) async {
      final kit = await openPartners(tester, size: tall);
      await openMyAds(tester);
      expect(find.text(en.sectionOpen), findsOneWidget);
      expect(find.text(en.sectionEnded), findsWidgets, reason: 'the section, and the tag of the ad');
      expect(find.descendant(of: card('demo-meetup-mine-ended'), matching: find.text(en.endedTag)), findsOneWidget);
      expect(find.byKey(MeetupCard.editKey('demo-meetup-mine-ended')), findsNothing, reason: 'ended ads are renewed');

      await tapOn(tester, find.byKey(MeetupCard.renewKey('demo-meetup-mine-ended')));
      expect(find.text(en.renewed), findsOneWidget);
      expect(find.text(en.sectionEnded), findsNothing);
      expect(kit.repo.ads.firstWhere((a) => a.id == 'demo-meetup-mine-ended').expiresAt, monday.add(const Duration(days: 30)));

      await tapOn(tester, find.byKey(MeetupCard.closeKey('demo-meetup-mine-ended')));
      expect(find.text(en.closeConfirmTitle), findsOneWidget);
      await tester.tap(find.text(en.closeConfirm));
      await tester.pumpAndSettle();
      expect(find.text(en.closedDone), findsOneWidget);
      expect(find.text(en.sectionClosed), findsWidgets, reason: 'the section, and the tag of the ad');
      expect(find.descendant(of: card('demo-meetup-mine-ended'), matching: find.text(en.closedTag)), findsOneWidget);

      // Two answered Kelly's walk: one group for them.
      await tapOn(tester, find.byKey(MeetupCard.groupKey('demo-meetup-mine')));
      expect(find.text(en.groupButton(2)), findsNothing, reason: 'the chat is open');
      expect(
        find.descendant(of: find.byType(CoralHeader), matching: find.text('Walk · Yarkon Park dog run')),
        findsOneWidget,
      );
    });

    testWidgets('edit an open ad', (tester) async {
      final kit = await openPartners(tester, size: tall);
      await openMyAds(tester);
      await tapOn(tester, find.byKey(MeetupCard.editKey('demo-meetup-mine')));
      expect(find.text(en.formEditTitle), findsWidgets);
      expect(find.text('An evening walk around the lawns, all sizes welcome.'), findsOneWidget);
      await tester.enterText(find.byKey(MeetupFormScreen.noteKey), 'Now with a ball');
      await submit(tester);
      expect(find.text(en.saved), findsOneWidget);
      final ad = kit.repo.ads.firstWhere((a) => a.id == 'demo-meetup-mine');
      expect(ad.note, 'Now with a ball');
      expect(ad.parkId, 'demo-tlv-yarkon');
      expect(find.text('Now with a ball'), findsOneWidget, reason: 'My ads shows the new text');
    });

    testWidgets('a one-off ad that ended is posted again', (tester) async {
      final repo = FakeMeetupsRepository(latency: Duration.zero, now: clock, viewerId: () => 'demo');
      repo.ads.add(
        Meetup(
          id: 'old-play',
          authorId: 'demo',
          authorName: 'Alex',
          kind: MeetupKind.play,
          localityCode: 'tel-aviv-yafo',
          placeText: 'Gordon beach',
          time: OneOffTime(DateTime(2026, 10, 10, 17), DateTime(2026, 10, 10, 18)),
          createdAt: DateTime(2026, 10, 8),
          expiresAt: DateTime(2026, 10, 10, 18),
        ),
      );
      await openPartners(tester, size: tall, kit: MeetupsKit(repo: repo));
      await openMyAds(tester);
      expect(find.byKey(MeetupCard.renewKey('old-play')), findsNothing, reason: 'one-off ads are posted again');
      await tapOn(tester, find.byKey(MeetupCard.againKey('old-play')));
      expect(find.text(en.formNewTitle), findsWidgets);
      expect(find.text('Gordon beach'), findsOneWidget);
      expect(find.textContaining('17:00'), findsOneWidget);
    });
  });

  group('the park page and the parks list', () {
    Future<void> openRaananaParks(WidgetTester tester) async {
      await tester.tap(find.byKey(OutsideSection.parksKey));
      await tester.pumpAndSettle();
      // Outside's area (Tel Aviv-Yafo from the profile), changed from the
      // header; up to 10 km as before: Kfar Saba's parks too.
      await changeArea(tester, 'raan', 'raanana');
      expect(containerOf(tester).read(outsideAreaProvider).area?.radius, ParkRadius.km10);
    }

    testWidgets('park cards say "Meetup today" or how many this week', (tester) async {
      await openPartners(tester, size: tall);
      await openRaananaParks(tester);
      expect(
        find.descendant(of: find.byKey(ParkCard.keyOf('demo-raanana-park')), matching: find.text(en.cardMeetupToday)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ParkCard.keyOf('demo-kfarsaba-weizmann')),
          matching: find.text(en.cardMeetupsWeek(1)),
        ),
        findsOneWidget,
      );
      expect(find.byKey(ParkCardMeetups.keyOf('demo-raanana-ahuza')), findsNothing);
    });

    testWidgets('meetups at this park, posting one there, and the switch for saved parks', (tester) async {
      final kit = await openPartners(tester, size: tall);
      await openRaananaParks(tester);
      await tapOn(tester, find.byKey(ParkCard.keyOf('demo-raanana-park')));
      expect(find.byKey(ParkScreen.screenKey), findsOneWidget);
      expect(find.text(en.atThisPark), findsOneWidget);
      expect(find.byKey(ParkMeetupsSection.rowKey('demo-meetup-sam')), findsOneWidget);
      expect(find.byKey(ParkMeetupsSection.saveFirstKey), findsOneWidget);
      expect(find.byKey(ParkMeetupsSection.notifyKey), findsNothing);

      // Saved: the switch appears and is kept.
      await tester.tap(find.byKey(ParkScreen.saveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ParkMeetupsSection.notifyKey), findsOneWidget);
      await tapOn(tester, find.byKey(ParkMeetupsSection.notifyKey));
      expect(kit.repo.notify, {'demo-raanana-park'});

      // "Post a meetup here": the park is already chosen.
      await tapOn(tester, find.byKey(PostMeetupHereButton.buttonKey));
      expect(find.byKey(MeetupFormScreen.screenKey), findsOneWidget);
      expect(find.text("Ra'anana Park dog run, Ra'anana"), findsOneWidget);
      await submit(tester);
      expect(kit.repo.saved.single.parkId, 'demo-raanana-park');
      expect(find.byKey(ParkMeetupsSection.rowKey(kit.repo.ads.last.id)), findsOneWidget, reason: 'the new ad is listed');

      // A row opens the ad.
      await tapOn(tester, find.byKey(ParkMeetupsSection.rowKey('demo-meetup-sam')));
      expect(find.byKey(MeetupScreen.screenKey), findsOneWidget);
      expect(find.text('Pepper'), findsOneWidget);
    });
  });

  group('Hebrew at 320 px', () {
    testWidgets('the board, a card, the join sheet, the form and My ads fit', (tester) async {
      await openPartners(tester, language: AppLanguage.hebrew, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(find.text(he.safetyStrip), findsNothing, reason: 'the form keeps it, not the board');
      expect(find.byTooltip(lookupOutdoorsL10n(hebrewLocale).addToOutside), findsOneWidget);
      expect(find.text(he.myAdsCount(2)), findsOneWidget);
      await scrollTo(tester, find.byKey(MeetupCard.joinKey('demo-meetup-noa')));
      expect(tester.takeException(), isNull);
      expect(find.text('ב׳, ד׳ · ערב'), findsOneWidget, reason: 'Hebrew day letters');

      await tester.tap(find.byKey(MeetupCard.joinKey('demo-meetup-noa')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.joinTitle('Noa')), findsOneWidget);
      expect(find.text(he.draftWalkPet('Noa', 'Yarkon Park, by the Seven Mills', 'Kelly')), findsOneWidget);
      Navigator.of(tester.element(find.byType(JoinMeetupSheet))).pop();
      await tester.pumpAndSettle();

      // The tab's "+", wherever the list is.
      await tester.tap(find.byKey(AddFab.fabKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(AddSheet.rowKey('plan-walk')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.withWhom), findsOneWidget);
      final form = find.byKey(MeetupFormScreen.screenKey);
      await scrollTo(tester, find.byKey(MeetupFormScreen.otherModeKey), within: form);
      await tester.tap(find.byKey(MeetupFormScreen.otherModeKey));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(MeetupFormScreen.onceKey), within: form);
      await tester.tap(find.byKey(MeetupFormScreen.onceKey));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(MeetupFormScreen.submitKey), within: form);
      expect(tester.takeException(), isNull);
      expect(find.textContaining(he.safetyStrip), findsOneWidget, reason: 'the footer of the form');
      Navigator.of(tester.element(form)).pop();
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(PartnersView.myAdsKey), delta: -200);
      await tester.tap(find.byKey(PartnersView.myAdsKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text(he.sectionEnded), within: find.byKey(MyMeetupsScreen.screenKey));
      expect(tester.takeException(), isNull);
      expect(find.text(he.renew), findsOneWidget);
    });

    testWidgets('the row of controls, the distance menu and the filters sheet fit', (tester) async {
      await openPartners(tester, language: AppLanguage.hebrew, size: const Size(320, 640));
      expect(find.text(he.filters), findsOneWidget);
      expect(find.text(outdoorsHe.radiusKm(10)), findsOneWidget);
      await chooseRadius(tester, ParkRadius.km25);
      expect(tester.takeException(), isNull);
      expect(find.text(outdoorsHe.radiusKm(25)), findsOneWidget);
      await openFilters(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(he.filtersTitle), findsOneWidget);
      for (final heading in [he.filterKind, he.filterAnimal, he.filterWhen, he.filterWhere]) {
        expect(find.text(heading), findsOneWidget);
      }
      await tapOn(tester, find.byKey(PartnersView.kindKey(MeetupKind.walk)));
      await tapOn(tester, find.byKey(PartnersView.myParksKey));
      expect(tester.takeException(), isNull);
      expect(find.text(he.filtersShow(0)), findsOneWidget, reason: 'no saved parks');
      await tapOn(tester, find.byKey(PartnersView.myParksKey));
      await closeFilters(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(he.filtersCount(1)), findsOneWidget);
      await openFilters(tester);
      await tapOn(tester, find.byKey(PartnersFiltersSheet.clearAllKey));
      await closeFilters(tester);
      expect(find.text(he.filters), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a park page with its meetups fits', (tester) async {
      await openPartners(tester, language: AppLanguage.hebrew, size: const Size(320, 640));
      await tester.tap(find.byKey(OutsideSection.parksKey));
      await tester.pumpAndSettle();
      await changeArea(tester, 'רענ', 'raanana');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(ParkCard.keyOf('demo-raanana-park')),
        200,
        scrollable: find.descendant(of: find.byKey(ParksView.listKey), matching: find.byType(Scrollable)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ParkCard.keyOf('demo-raanana-park')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(he.postHere), findsOneWidget);
    });
  });

  test('a pet\'s public facts for an ad', () {
    const kelly = Pet(id: 'kelly', name: 'Kelly', breed: 'Mix', weightKg: 23);
    final pet = MeetupPet.of(kelly);
    expect(pet.petId, 'kelly');
    expect(pet.size, PetSize.medium);
    expect(pet.asPet.name, 'Kelly');
  });
}
