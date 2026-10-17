import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/features/meetups/meetups.dart' show PartnersView;
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/findvet/regions/regions.dart';
import 'package:pet_companion/services/outdoors/data/supabase_hazards_repository.dart';

import '../meetups/meetups_test_helpers.dart';

FakeHazardsRepository hazardsRepo({String viewer = 'demo', bool seed = true, DateTime Function()? now}) =>
    FakeHazardsRepository(latency: Duration.zero, now: now ?? clock, viewerId: () => viewer, seed: seed);

Matcher failsWith(HazardFailure failure) =>
    throwsA(isA<HazardException>().having((e) => e.failure, 'failure', failure));

void main() {
  setUpMeetupsTests();

  group('the rules', () {
    test('a report takes its park\'s city; five a day; "other" says what it is', () async {
      final repo = hazardsRepo(seed: false);
      await repo.report(const HazardDraft(kind: HazardKind.bait, parkId: 'demo-raanana-park', note: ' By the gate '));
      final mine = (await repo.current(['raanana'])).single;
      expect(mine.localityCode, 'raanana');
      expect(mine.note, 'By the gate');
      expect(mine.mine, isTrue);
      expect(mine.expiresAt, monday.add(const Duration(days: HazardLimits.days)));
      await expectLater(repo.report(const HazardDraft(kind: HazardKind.other, localityCode: 'raanana')), failsWith(HazardFailure.invalid));
      await expectLater(repo.report(const HazardDraft(kind: HazardKind.glass)), failsWith(HazardFailure.invalid));
      for (var i = 0; i < 4; i++) {
        await repo.report(const HazardDraft(kind: HazardKind.glass, localityCode: 'petah-tikva'));
      }
      await expectLater(
        repo.report(const HazardDraft(kind: HazardKind.glass, localityCode: 'petah-tikva')),
        failsWith(HazardFailure.rateLimited),
      );
    });

    test('two "not there any more" from others hide it; its author still sees it and deletes it', () async {
      var viewer = 'author';
      final repo = FakeHazardsRepository(latency: Duration.zero, now: clock, viewerId: () => viewer, seed: false);
      final id = await repo.report(const HazardDraft(kind: HazardKind.caterpillars, localityCode: 'raanana'));
      await expectLater(repo.vote(id, gone: true), failsWith(HazardFailure.invalid));
      viewer = 'one';
      expect(await repo.vote(id, gone: false), isTrue);
      expect(await repo.vote(id, gone: true), isTrue, reason: 'a changed vote is one vote');
      final seen = (await repo.current(['raanana'])).single;
      expect((seen.stillCount, seen.goneCount, seen.myVote), (0, 1, true));
      viewer = 'two';
      expect(await repo.vote(id, gone: true), isFalse, reason: 'hidden');
      expect(await repo.current(['raanana']), isEmpty);
      await expectLater(repo.vote(id, gone: false), failsWith(HazardFailure.notOpen));
      await expectLater(repo.delete(id), failsWith(HazardFailure.invalid));
      viewer = 'author';
      expect((await repo.current(['raanana'])).single.hidden, isTrue);
      await repo.delete(id);
      expect(await repo.current(['raanana']), isEmpty);
    });

    test('a week later a report is gone', () async {
      var now = monday;
      final repo = hazardsRepo(seed: false, now: () => now);
      await repo.report(const HazardDraft(kind: HazardKind.inspector, localityCode: 'raanana'));
      now = monday.add(const Duration(days: 7, minutes: 1));
      expect(await repo.current(['raanana']), isEmpty);
    });

    test('the server gets the park or the city, and its rows and refusals read back', () {
      expect(hazardDraftJson(const HazardDraft(kind: HazardKind.bait, parkId: 'p1', localityCode: 'raanana')),
          {'kind': 'bait', 'park_id': 'p1', 'note': ''});
      expect(hazardDraftJson(const HazardDraft(kind: HazardKind.glass, localityCode: 'raanana', note: ' x ')),
          {'kind': 'glass', 'park_id': null, 'locality_code': 'raanana', 'note': 'x'});
      final report = hazardFromRow({
        'id': 'h1',
        'locality_code': 'tel-aviv-yafo',
        'park_id': 'p1',
        'kind': 'caterpillars',
        'note': 'By the gate',
        'created_at': '2026-10-12T06:00:00Z',
        'expires_at': '2026-10-19T06:00:00Z',
        'mine': false,
        'hidden': false,
        'still_count': 2,
        'gone_count': 1,
        'my_vote': false,
        'park_name_en': 'Yarkon park',
        'park_lat': 32.1,
        'park_lng': 34.8,
      });
      expect(report.kind, HazardKind.caterpillars);
      expect(report.park?.nameEn, 'Yarkon park');
      expect((report.stillCount, report.goneCount, report.myVote), (2, 1, false));
      expect(hazardFromRow({'id': 'h2', 'locality_code': 'raanana', 'kind': 'wolves'}).kind, HazardKind.other);
      expect(SupabaseHazardsRepository.failureOf('rate_limited', 'P0001'), HazardFailure.rateLimited);
      expect(SupabaseHazardsRepository.failureOf('not_open', 'P0001'), HazardFailure.notOpen);
      expect(SupabaseHazardsRepository.failureOf('invalid_hazard', '22023'), HazardFailure.invalid);
      expect(SupabaseHazardsRepository.failureOf('Hazard reports access required', '42501'), HazardFailure.other);
    });

    test('the area asks for its city, or the localities in range', () {
      final raanana = israelRegion.localityByCode('raanana')!;
      expect(areaLocalityCodes(CityArea(raanana)), ['raanana']);
      final around = areaLocalityCodes(CityArea(raanana, radius: ParkRadius.km10));
      expect(around, containsAll(['raanana', 'kfar-saba']));
      expect(around, isNot(contains('jerusalem')));
      final nearMe = areaLocalityCodes(NearMeArea(point: raanana.point, nearest: raanana));
      expect(nearMe, contains('raanana'));
    });
  });

  group('the line above the lists', () {
    testWidgets('Partners and Parks: how many this week and the newest in a few words', (tester) async {
      final kit = MeetupsKit(hazards: hazardsRepo(), profileCity: "Ra'anana");
      await openPartners(tester, kit: kit, size: const Size(390, 1600));
      final line = find.byKey(HazardLine.lineKey);
      expect(line, findsOneWidget);
      expect(
        find.descendant(of: line, matching: find.textContaining(outdoorsEn.hazardLineCount(2))),
        findsOneWidget,
        reason: "Ra'anana and Kfar Saba, not Tel Aviv-Yafo",
      );
      expect(find.descendant(of: line, matching: find.textContaining("Caterpillars at Ra'anana Park dog run")), findsOneWidget);
      // Below the going-out card, above the board's controls.
      expect(tester.getTopLeft(line).dy, lessThan(tester.getTopLeft(find.byKey(PartnersView.controlRowKey)).dy));

      await tester.tap(find.byKey(OutsideSection.parksKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HazardLine.lineKey), findsOneWidget, reason: 'the same line on Parks');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no report around, or no access: no line', (tester) async {
      await openPartners(tester, kit: MeetupsKit(hazards: hazardsRepo(seed: false)));
      expect(find.byKey(HazardLine.lineKey), findsNothing);
    });

    testWidgets('switched off for the account: no line', (tester) async {
      final access = FakeAccessRepository()..users['demo'] = {HazardCapabilities.view: AccessRule.deny};
      await openPartners(tester, kit: MeetupsKit(hazards: hazardsRepo(), profileCity: "Ra'anana", access: access));
      expect(find.byKey(HazardLine.lineKey), findsNothing);
    });

    testWidgets('Hebrew', (tester) async {
      final kit = MeetupsKit(hazards: hazardsRepo(), profileCity: "Ra'anana");
      await openPartners(tester, kit: kit, language: AppLanguage.hebrew, size: const Size(390, 1600));
      expect(
        find.descendant(of: find.byKey(HazardLine.lineKey), matching: find.textContaining(outdoorsHe.hazardLineCount(2))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
