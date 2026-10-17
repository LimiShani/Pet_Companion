import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/meetups/meetups.dart' show PartnersView;
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/add_sheet.dart';

import '../meetups/meetups_test_helpers.dart';

FakeHazardsRepository hazardsRepo({bool seed = true}) =>
    FakeHazardsRepository(latency: Duration.zero, now: clock, seed: seed);

const tall = Size(390, 1800);

Future<MeetupsKit> openWithHazards(
  WidgetTester tester, {
  FakeHazardsRepository? hazards,
  AppLanguage? language,
  Set<String>? favorites,
}) => openPartners(
  tester,
  kit: MeetupsKit(hazards: hazards ?? hazardsRepo(), profileCity: "Ra'anana", favorites: favorites),
  language: language,
  size: tall,
);

Future<void> openReportRow(WidgetTester tester) async {
  await tapOn(tester, find.byKey(AddFab.fabKey));
  await tapOn(tester, find.byKey(AddSheet.rowKey('report-hazard')));
  expect(find.byType(ReportHazardSheet), findsOneWidget);
}

void main() {
  setUpMeetupsTests();

  group('the list', () {
    testWidgets('the line opens it: what, where, how long ago, the note, the votes', (tester) async {
      final kit = await openWithHazards(tester);
      await tapOn(tester, find.byKey(HazardLine.lineKey));
      expect(find.byKey(HazardsScreen.screenKey), findsOneWidget);
      expect(find.text(outdoorsEn.hazardsTitle), findsOneWidget);
      expect(find.text(outdoorsEn.hazardsLead), findsOneWidget);
      final caterpillars = find.byKey(HazardsScreen.cardKey('demo-hazard-caterpillars'));
      expect(find.descendant(of: caterpillars, matching: find.text(outdoorsEn.hazardKindCaterpillars)), findsOneWidget);
      expect(find.descendant(of: caterpillars, matching: find.text("Ra'anana Park dog run · 5 h ago")), findsOneWidget);
      expect(find.descendant(of: caterpillars, matching: find.text(outdoorsEn.hazardStillCount(1))), findsOneWidget);
      final bait = find.byKey(HazardsScreen.cardKey('demo-hazard-bait'));
      expect(find.descendant(of: bait, matching: find.text('Somewhere in Kfar Saba · yesterday')), findsOneWidget);
      expect(find.byKey(HazardsScreen.cardKey('demo-hazard-glass')), findsNothing, reason: 'Tel Aviv-Yafo is out of range');

      await tapOn(tester, find.byKey(HazardsScreen.stillKey('demo-hazard-caterpillars')));
      expect(kit.hazards.votes['demo-hazard-caterpillars']?['demo'], isFalse);
      expect(find.text(outdoorsEn.hazardStillCount(2)), findsOneWidget);
      await tapOn(tester, find.byKey(HazardsScreen.goneKey('demo-hazard-bait')));
      expect(kit.hazards.votes['demo-hazard-bait']?['demo'], isTrue);
      // Back on the board, the line counts what is still shown.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(HazardLine.lineKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two "not there any more" hide a report', (tester) async {
      final hazards = hazardsRepo()..votes['demo-hazard-bait'] = {'u-sam': true};
      await openWithHazards(tester, hazards: hazards);
      await tapOn(tester, find.byKey(HazardLine.lineKey));
      await tapOn(tester, find.byKey(HazardsScreen.goneKey('demo-hazard-bait')));
      expect(find.text(outdoorsEn.hazardHidden), findsOneWidget);
      expect(find.byKey(HazardsScreen.cardKey('demo-hazard-bait')), findsNothing);
    });

    testWidgets('one\'s own report: its tag and Delete, after asking', (tester) async {
      final hazards = hazardsRepo(seed: false);
      await tester.runAsync(
        () => hazards.report(const HazardDraft(kind: HazardKind.glass, localityCode: 'raanana', note: 'By the gate')),
      );
      await openWithHazards(tester, hazards: hazards);
      await tapOn(tester, find.byKey(HazardLine.lineKey));
      final id = hazards.reports.single.$1.id;
      expect(find.text(outdoorsEn.hazardYours), findsOneWidget);
      expect(find.byKey(HazardsScreen.stillKey(id)), findsNothing, reason: 'no vote on one\'s own');
      await tapOn(tester, find.byKey(HazardsScreen.deleteKey(id)));
      expect(find.text(outdoorsEn.hazardDeleteTitle), findsOneWidget);
      await tapOn(tester, find.widgetWithText(FilledButton, appEn.commonDelete));
      expect(hazards.reports, isEmpty);
      expect(find.byKey(HazardsScreen.emptyKey), findsOneWidget);
    });

    testWidgets('empty: one sentence and "Report a hazard"', (tester) async {
      await openWithHazards(tester, hazards: hazardsRepo(seed: false));
      expect(find.byKey(HazardLine.lineKey), findsNothing);
      openHazards(tester.element(find.byType(PartnersView)));
      await tester.pumpAndSettle();
      expect(find.text(outdoorsEn.hazardsEmpty), findsOneWidget);
      await tapOn(tester, find.text(outdoorsEn.addReportHazard));
      expect(find.byType(ReportHazardSheet), findsOneWidget);
    });

    testWidgets('Hebrew', (tester) async {
      await openWithHazards(tester, language: AppLanguage.hebrew);
      await tapOn(tester, find.byKey(HazardLine.lineKey));
      expect(find.text(outdoorsHe.hazardsTitle), findsOneWidget);
      expect(find.text(outdoorsHe.hazardStillThere), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('the report form', () {
    testWidgets('from the "+": what, the saved park, a note; it shows on the list', (tester) async {
      final kit = await openWithHazards(tester, hazards: hazardsRepo(seed: false), favorites: {'demo-raanana-park'});
      await openReportRow(tester);
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      expect(find.text(outdoorsEn.hazardNeedKind), findsOneWidget);
      expect(kit.hazards.sent, isEmpty);

      await tester.tap(find.byKey(ReportHazardSheet.kindKey(HazardKind.bait)));
      await tester.pumpAndSettle();
      expect(chipOn(tester, ReportHazardSheet.parkKey('demo-raanana-park')), isTrue, reason: 'the first saved park');
      await tester.enterText(find.byKey(ReportHazardSheet.noteKey), 'By the gate');
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      final sent = kit.hazards.sent.single;
      expect((sent.kind, sent.parkId, sent.note), (HazardKind.bait, 'demo-raanana-park', 'By the gate'));
      expect(find.byType(ReportHazardSheet), findsNothing);
      expect(find.text(outdoorsEn.hazardReported), findsOneWidget);
      expect(find.byKey(HazardLine.lineKey), findsOneWidget);
    });

    testWidgets('somewhere else in the city; "Something else" says what it is', (tester) async {
      final kit = await openWithHazards(tester, hazards: hazardsRepo(seed: false));
      await openReportRow(tester);
      await tester.tap(find.byKey(ReportHazardSheet.kindKey(HazardKind.other)));
      await tester.pumpAndSettle();
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      expect(find.text(outdoorsEn.hazardNeedPlace), findsOneWidget);
      expect(find.text(outdoorsEn.hazardElsewhereIn("Ra'anana")), findsOneWidget);
      await tapOn(tester, find.byKey(ReportHazardSheet.elsewhereKey));
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      expect(find.text(outdoorsEn.hazardNeedNote), findsOneWidget);
      await tester.enterText(find.byKey(ReportHazardSheet.noteKey), 'A loose dog');
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      final sent = kit.hazards.sent.single;
      expect((sent.parkId, sent.localityCode), (null, 'raanana'));
    });

    testWidgets('five a day', (tester) async {
      final hazards = hazardsRepo(seed: false);
      await tester.runAsync(() async {
        for (var i = 0; i < HazardLimits.perDay; i++) {
          await hazards.report(const HazardDraft(kind: HazardKind.glass, localityCode: 'raanana'));
        }
      });
      await openWithHazards(tester, hazards: hazards);
      await openReportRow(tester);
      await tester.tap(find.byKey(ReportHazardSheet.kindKey(HazardKind.glass)));
      await tapOn(tester, find.byKey(ReportHazardSheet.elsewhereKey));
      await tapOn(tester, find.byKey(ReportHazardSheet.reportKey));
      expect(find.text(outdoorsEn.hazardRateLimited), findsOneWidget);
      expect(find.byType(ReportHazardSheet), findsOneWidget);
    });
  });
}
