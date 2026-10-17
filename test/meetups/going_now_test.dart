import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/community/data/audience.dart';
import 'package:pet_companion/services/meetups/data/supabase_meetups_repository.dart';
import 'package:pet_companion/widgets/add_sheet.dart';

import 'meetups_test_helpers.dart';

/// A tall phone, so the whole board is built without scrolling.
const tall = Size(390, 2400);

FakeMeetupsRepository fakeRepo({bool sample = false, String viewer = 'demo'}) =>
    FakeMeetupsRepository(
      latency: Duration.zero,
      now: clock,
      viewerId: () => viewer,
      goingNowSample: sample,
    );

MeetupDraft goingNow({int minutes = 25, String parkId = 'demo-tlv-yarkon'}) =>
    MeetupDraft(
      kind: MeetupKind.walk,
      time: NowTime.leavingIn(minutes, monday),
      pet: const MeetupPet(petId: 'kelly', name: 'Kelly', species: PetSpecies.dog),
      parkId: parkId,
    );

void main() {
  setUpMeetupsTests();

  group('the rules', () {
    test('leaving in 15 to 60 minutes; the ad is up for 90 from posting', () {
      final in25 = NowTime.leavingIn(25, monday);
      expect(in25.start, monday.add(const Duration(minutes: 25)));
      expect(in25.end, monday.add(const Duration(minutes: 90)));
      expect(in25.minutesUntil(monday), 25);
      expect(in25.minutesUntil(monday.add(const Duration(minutes: 30))), 0);
      expect(in25, isA<OneOffTime>(), reason: 'a one-off time to every other rule');
      expect(draftProblems(goingNow(), monday), isEmpty);
      final tooFar = MeetupDraft(
        kind: MeetupKind.walk,
        parkId: 'demo-tlv-yarkon',
        time: NowTime(monday.add(const Duration(hours: 2)), monday.add(const Duration(hours: 3))),
      );
      expect(draftProblems(tooFar, monday), contains(MeetupDraftProblem.tooFar));
      final left = MeetupDraft(
        kind: MeetupKind.walk,
        parkId: 'demo-tlv-yarkon',
        time: NowTime(monday.subtract(const Duration(hours: 1)), monday.add(const Duration(minutes: 20))),
      );
      expect(draftProblems(left, monday), contains(MeetupDraftProblem.past));
    });

    test('three a day of their own, one at a time, never edited', () async {
      final repo = fakeRepo()..ads.clear();
      final first = await repo.save(goingNow());
      expect(repo.ads.single.isGoingNow, isTrue);
      expect(repo.ads.single.expiresAt, monday.add(const Duration(minutes: 90)));
      final second = await repo.save(goingNow(minutes: 45));
      expect(repo.ads.firstWhere((a) => a.id == first).status, MeetupStatus.closed, reason: 'the earlier one is closed');
      expect(repo.ads.firstWhere((a) => a.id == second).status, MeetupStatus.open);
      final third = await repo.save(goingNow());
      await expectLater(
        repo.save(goingNow()),
        throwsA(isA<MeetupException>().having((e) => e.failure, 'failure', MeetupFailure.rateLimited)),
      );
      // Planned ads keep their own three a day.
      await repo.save(
        const MeetupDraft(
          kind: MeetupKind.play,
          parkId: 'demo-tlv-yarkon',
          time: RecurringTime({6}, DayPart.morning),
        ),
      );
      await expectLater(
        repo.save(goingNow(), id: third),
        throwsA(isA<MeetupException>().having((e) => e.failure, 'failure', MeetupFailure.invalid)),
      );
      await expectLater(
        repo.renew(third),
        throwsA(isA<MeetupException>().having((e) => e.failure, 'failure', MeetupFailure.invalid)),
      );
    });

    test('the server is sent "now" and reads back the now kinds', () {
      expect(draftJson(goingNow())['now'], isTrue);
      expect(draftJson(goingNow())['kind'], 'walk');
      expect(draftJson(goingNow()).containsKey('weekdays'), isFalse);
      final row = {
        'id': 'm1',
        'author_id': 'u1',
        'author_name': 'Dana',
        'kind': 'play_now',
        'locality_code': 'tel-aviv-yafo',
        'place_text': 'The lawn',
        'starts_at': '2026-10-12T06:25:00Z',
        'ends_at': '2026-10-12T07:30:00Z',
        'status': 'open',
        'expires_at': '2026-10-12T07:30:00Z',
        'created_at': '2026-10-12T06:00:00Z',
      };
      final ad = meetupFromRow(row);
      expect(ad.kind, MeetupKind.play);
      expect(ad.isGoingNow, isTrue);
      expect(meetupFromRow({...row, 'kind': 'walk'}).isGoingNow, isFalse);
      expect(meetupFromRow({...row, 'kind': 'walk_now'}).kind, MeetupKind.walk);
    });

    test('going-now ads lead the board, the soonest to leave first', () {
      final repo = fakeRepo(sample: true);
      final listing = buildMeetupListing(
        ads: repo.ads,
        area: null,
        filters: const MeetupFilters(),
        scope: CommunityScope.everything,
        blocked: const {},
        myParks: const {},
        now: monday,
      );
      expect(listing.first.meetup.id, 'demo-meetup-now');
    });
  });

  group('the Partners card and sheet', () {
    testWidgets('"Going out soon?" sits above the board; the sheet posts a going-now ad', (tester) async {
      final kit = MeetupsKit(repo: fakeRepo(), favorites: {'demo-tlv-yarkon'});
      await openPartners(tester, kit: kit, size: tall);
      final cardTop = tester.getTopLeft(find.byKey(GoingOutCard.cardKey)).dy;
      expect(cardTop, lessThan(tester.getTopLeft(find.byKey(PartnersView.controlRowKey)).dy));
      expect(find.text(en.goingSoonTitle), findsOneWidget);
      expect(find.text(en.goingSoonBody), findsOneWidget);

      await tapOn(tester, find.byKey(GoingOutCard.buttonKey));
      expect(find.byType(GoingNowSheet), findsOneWidget);
      // The saved park is chosen; 30 minutes and Walk to start with.
      expect(chipOn(tester, GoingNowSheet.parkKey('demo-tlv-yarkon')), isTrue);
      expect(chipOn(tester, GoingNowSheet.leaveKey(30)), isTrue);
      expect(chipOn(tester, GoingNowSheet.kindKey(MeetupKind.walk)), isTrue);
      expect(find.text(en.goingWith('Kelly')), findsOneWidget);

      await tester.tap(find.byKey(GoingNowSheet.leaveKey(45)));
      await tester.tap(find.byKey(GoingNowSheet.kindKey(MeetupKind.play)));
      await tester.enterText(find.byKey(GoingNowSheet.noteKey), 'Ball games');
      await tester.pumpAndSettle();
      await tapOn(tester, find.byKey(GoingNowSheet.postKey));
      // The community rules come first for a member who has not agreed.
      final agree = find.text(communityEn.rulesAgree);
      if (agree.evaluate().isNotEmpty) await tapOn(tester, agree);

      final sent = kit.repo.saved.single;
      expect(sent.time, isA<NowTime>());
      expect((sent.time as NowTime).start, monday.add(const Duration(minutes: 45)));
      expect(sent.kind, MeetupKind.play);
      expect(sent.parkId, 'demo-tlv-yarkon');
      expect(sent.note, 'Ball games');
      expect(sent.pet?.name, 'Kelly');
      expect(find.byType(GoingNowSheet), findsNothing);
      expect(find.text(en.goingPosted), findsOneWidget);
      // On the board, first, with its tag.
      final id = kit.repo.ads.firstWhere((a) => a.isGoingNow).id;
      expect(listedIds(tester).first, id);
      expect(find.descendant(of: card(id), matching: find.text(en.goingInTag(45))), findsOneWidget);
      expect(find.byKey(MeetupCard.editKey(id)), findsNothing, reason: 'a going-now ad is never edited');
    });

    testWidgets('without a saved park the sheet asks for one', (tester) async {
      final kit = MeetupsKit(repo: fakeRepo());
      await openPartners(tester, kit: kit, size: tall);
      await tapOn(tester, find.byKey(GoingOutCard.buttonKey));
      await tapOn(tester, find.byKey(GoingNowSheet.postKey));
      expect(find.text(en.goingPickPark), findsOneWidget);
      expect(kit.repo.saved, isEmpty);
      expect(find.byKey(GoingNowSheet.otherParkKey), findsOneWidget);
    });

    testWidgets('the Outside "+" has "Going out now"', (tester) async {
      await openPartners(tester, kit: MeetupsKit(repo: fakeRepo(), favorites: {'demo-tlv-yarkon'}), size: tall);
      await tapOn(tester, find.byKey(AddFab.fabKey));
      expect(find.text(en.addGoingNow), findsOneWidget);
      await tapOn(tester, find.byKey(AddSheet.rowKey('going-now')));
      expect(find.byType(GoingNowSheet), findsOneWidget);
    });

    testWidgets('someone going out soon: a yellow "in 25 min" and I want to join', (tester) async {
      final kit = MeetupsKit(repo: fakeRepo(sample: true), profileCity: "Ra'anana");
      await openPartners(tester, kit: kit, size: tall);
      expect(listedIds(tester).first, 'demo-meetup-now');
      final tag = find.byKey(MeetupCard.goingTagKey('demo-meetup-now'));
      expect(find.descendant(of: tag, matching: find.text(en.goingInTag(25))), findsOneWidget);
      expect(find.descendant(of: card('demo-meetup-now'), matching: find.textContaining('Leaving')), findsOneWidget);
      expect(find.byKey(MeetupCard.joinKey('demo-meetup-now')), findsOneWidget);
    });

    testWidgets('without the right to post there is no card and no row', (tester) async {
      final access = FakeAccessRepository()..users['demo'] = {MeetupCapabilities.post: AccessRule.deny};
      await openPartners(tester, kit: MeetupsKit(repo: fakeRepo(), access: access), size: tall);
      expect(find.byKey(GoingOutCard.cardKey), findsNothing);
      expect(find.byKey(PartnersView.controlRowKey), findsOneWidget);
    });

    testWidgets('Hebrew: the card, the tag and the sheet', (tester) async {
      final kit = MeetupsKit(repo: fakeRepo(sample: true), favorites: {'demo-raanana-park'}, profileCity: "Ra'anana");
      await openPartners(tester, kit: kit, language: AppLanguage.hebrew, size: tall);
      expect(find.text(he.goingSoonTitle), findsOneWidget);
      expect(find.text(he.goingInTag(25)), findsOneWidget);
      await tapOn(tester, find.byKey(GoingOutCard.buttonKey));
      expect(find.text(he.goingPost), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
