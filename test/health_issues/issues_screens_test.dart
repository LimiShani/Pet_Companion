import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/data/issue_models.dart';
import 'package:pet_companion/services/pet_records/state/health_issues.dart';
import 'package:pet_companion/widgets/add_sheet.dart';

import '../health/health_test_helpers.dart';

// Following a problem through the app: the "+" row, the sheet, the
// problem's page, the Quick log's "Part of a problem" and photos, the
// Overview's row and the Records chip.

const kelly = 'kelly';

FakeHealthRepository withIssue() =>
    FakeHealthRepository(latency: Duration.zero, now: () => fixedNow, seedIssue: true);

Future<HealthHarness> pumpIssues(WidgetTester tester, {FakeHealthRepository? repository}) =>
    pumpHealth(tester, harness: HealthHarness(repository: repository ?? withIssue()));

Future<void> openLimp(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('overview-issue-i-limp')));
  expect(find.byKey(const Key('issue-summary')), findsOneWidget);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('the Overview has a row for the open problem, which opens its page', (tester) async {
    await pumpIssues(tester);
    final row = find.byKey(const ValueKey('overview-issue-i-limp'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Limping, right front leg')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('Ongoing since June 3 · 4 entries, 2 photos')),
      findsOneWidget,
    );

    await openLimp(tester);
    expect(find.text('Since June 3 · 7 days'), findsOneWidget);
    expect(find.text('Right front leg · Kelly · 4 entries, 2 photos'), findsOneWidget);
    expect(find.text('Ongoing'), findsOneWidget);
    // Newest first, each with its photos.
    final newest = tester.getTopLeft(find.byKey(const ValueKey('issue-entry-o-limp-4'))).dy;
    final oldest = tester.getTopLeft(find.byKey(const ValueKey('issue-entry-o-limp-1'))).dy;
    expect(newest, lessThan(oldest));
    expect(find.text('Walked 20 minutes without limping'), findsOneWidget);
    expect(find.text('Mobility · Less than usual'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pet without a problem has no row', (tester) async {
    await pumpIssues(tester, repository: fakeHealth());
    expect(find.byKey(const ValueKey('overview-issue-i-limp')), findsNothing);
    expect(find.byKey(const Key('overview-issues-more')), findsNothing);
  });

  testWidgets('"Follow a problem" from the "+": the sheet, then the page with the Quick log on it', (tester) async {
    final h = await pumpIssues(tester, repository: fakeHealth());
    await openAddRow(tester, 'follow-problem');
    expect(find.text('Follow a problem'), findsWidgets);
    // Nothing to save without a title.
    final save = find.byKey(const Key('issue-save'));
    expect(tester.widget<FilledButton>(find.descendant(of: save, matching: find.byType(FilledButton))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('issue-title')), 'Itchy left ear');
    await tester.enterText(find.byKey(const Key('issue-area')), 'Left ear');
    await tester.pump();
    await tapVisible(tester, save);

    // The page of the new problem, with the Quick log open on it.
    expect(find.byKey(const Key('issue-summary')), findsOneWidget);
    expect(find.text('For: Itchy left ear'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('quick-skin_coat')));
    await tapVisible(tester, find.byKey(const ValueKey('level-different')));
    await tapVisible(tester, find.text('Save to journal'));
    expect(find.text('Skin or coat · Different from usual'), findsOneWidget);
    expect(find.text('No entries yet'), findsNothing);

    final stored = (await tester.runAsync(() => h.repository.fetchIssues(kelly)))!;
    expect(stored.single.title, 'Itchy left ear');
    expect(stored.single.bodyArea, 'Left ear');
    expect(stored.single.startedOn, DateTime(2025, 6, 10));
    final entries = (await tester.runAsync(() => h.repository.fetchIssueEntries(kelly, stored.single.id)))!;
    expect(entries, hasLength(1));
  });

  testWidgets('a problem without entries invites the first one', (tester) async {
    final repo = fakeHealth();
    await tester.runAsync(
      () => repo.saveIssue(HealthIssue(id: '', petId: kelly, title: 'Coughing', startedOn: DateTime(2025, 6, 10))),
    );
    await pumpIssues(tester, repository: repo);
    await tapVisible(tester, find.textContaining('Coughing'));
    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('Since June 10'), findsOneWidget);
  });

  testWidgets('the Quick log from the page puts the entry, with its photos, into the problem', (tester) async {
    final h = await pumpIssues(tester);
    h.picker.photo = PickedFile(name: 'paw.png', mimeType: 'image/png', bytes: FakeHealthRepository.samplePeachPng);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const Key('issue-add-entry')));
    expect(find.text('For: Limping, right front leg'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('quick-mobility')));
    await tapVisible(tester, find.byKey(const ValueKey('level-less')));
    expect(find.byKey(const Key('quick-photos-label')), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('quick-add-photo')));
    await tapVisible(tester, find.byKey(const ValueKey('entry-photo-gallery')));
    await tester.enterText(find.byKey(const Key('quick-note')), 'Swelling above the paw');
    await tapVisible(tester, find.text('Save to journal'));

    expect(find.text('Swelling above the paw'), findsOneWidget);
    expect(find.text('Right front leg · Kelly · 5 entries, 3 photos'), findsOneWidget);
    expect(h.picker.asked, ['gallery']);
  });

  testWidgets('the Quick log from the "+" offers the open problem; photos only for an entry of a problem', (tester) async {
    final h = await pumpIssues(tester);
    await openAddRow(tester, 'quick-log');
    await tapVisible(tester, find.byKey(const ValueKey('quick-energy')));
    await tapVisible(tester, find.byKey(const ValueKey('level-less')));
    expect(find.text('Part of a problem'), findsOneWidget);
    final none = tester.widget<ChoiceChip>(find.byKey(const Key('quick-issue-none')));
    expect(none.selected, isTrue);
    expect(find.byKey(const Key('quick-photos-label')), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('quick-issue-i-limp')));
    expect(find.byKey(const Key('quick-photos-label')), findsOneWidget);
    await tapVisible(tester, find.text('Save to journal'));
    final entries = (await tester.runAsync(() => h.repository.fetchIssueEntries(kelly, 'i-limp')))!;
    expect(entries.map((e) => e.category), contains('energy'));
  });

  testWidgets('editing an entry takes it out of its problem, and removes a photo', (tester) async {
    final h = await pumpIssues(tester);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const ValueKey('issue-entry-o-limp-2')));
    expect(find.byKey(const ValueKey('quick-photo-d-limp-paw')), findsOneWidget);
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('quick-photo-d-limp-paw')), matching: find.byType(IconButton)));
    expect(find.byKey(const ValueKey('quick-photo-d-limp-paw')), findsNothing);
    await tapVisible(tester, find.text('Save changes'));
    var photos = (await tester.runAsync(() => h.repository.fetchEntryPhotos(kelly)))!;
    expect(photos.map((p) => p.id), ['d-limp-walk']);

    await tapVisible(tester, find.byKey(const ValueKey('issue-entry-o-limp-3')));
    await tapVisible(tester, find.byKey(const Key('quick-issue-none')));
    await tapVisible(tester, find.text('Save changes'));
    expect(find.byKey(const ValueKey('issue-entry-o-limp-3')), findsNothing);
    final journal = (await tester.runAsync(() => h.repository.fetchObservations(kelly)))!;
    expect(journal.firstWhere((o) => o.id == 'o-limp-3').issueId, isNull);
    // The photo stays with the entry.
    photos = (await tester.runAsync(() => h.repository.fetchEntryPhotos(kelly)))!;
    expect(photos.map((p) => p.id), ['d-limp-walk']);
  });

  testWidgets('a fifth photo is not offered', (tester) async {
    final repo = withIssue();
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await repo.addEntryPhoto(
          petId: kelly,
          observationId: 'o-limp-2',
          file: PickedFile(name: 'p$i.png', mimeType: 'image/png', bytes: FakeHealthRepository.samplePng),
        );
      }
    });
    await pumpIssues(tester, repository: repo);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const ValueKey('issue-entry-o-limp-2')));
    expect(find.byKey(const Key('quick-add-photo')), findsNothing);
  });

  testWidgets('resolve, open again, rename', (tester) async {
    final h = await pumpIssues(tester);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const Key('issue-resolve')));
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('June 3 to June 10 · 7 days'), findsOneWidget);
    expect((await tester.runAsync(() => h.repository.fetchIssues(kelly)))!.single.resolvedOn, DateTime(2025, 6, 10));

    await tapVisible(tester, find.byKey(const Key('issue-reopen')));
    expect(find.text('Ongoing'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('issue-more')));
    await tapVisible(tester, find.byKey(const Key('issue-rename')));
    expect(find.text('Rename the problem'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('issue-title')), 'Limping, both front legs');
    await tapVisible(tester, find.byKey(const Key('issue-save')));
    expect(find.text('Limping, both front legs'), findsWidgets);
    expect((await tester.runAsync(() => h.repository.fetchIssues(kelly)))!.single.title, 'Limping, both front legs');
  });

  testWidgets('a resolved problem leaves the Overview but keeps its Records chip', (tester) async {
    await pumpIssues(tester);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const Key('issue-resolve')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overview-issue-i-limp')), findsNothing);
    await openSection(tester, 'Records');
    expect(find.byKey(const ValueKey('filter-issue-i-limp')), findsOneWidget);
  });

  testWidgets('stop following: the entries stay in the journal', (tester) async {
    final h = await pumpIssues(tester);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const Key('issue-more')));
    await tapVisible(tester, find.byKey(const Key('issue-stop')));
    expect(find.text('Stop following this problem?'), findsOneWidget);
    expect(find.text('Its 4 entries and their photos stay in the journal.'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Stop following'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('issue-summary')), findsNothing);
    expect(find.text('No longer followed. Its entries stay in the journal.'), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-issue-i-limp')), findsNothing);
    expect((await tester.runAsync(() => h.repository.fetchIssues(kelly)))!, isEmpty);
    final journal = (await tester.runAsync(() => h.repository.fetchObservations(kelly)))!;
    expect(journal.where((o) => o.id.startsWith('o-limp')), hasLength(4));
  });

  testWidgets('Records: the problem\'s chip lists its entries and leads to its page', (tester) async {
    await pumpIssues(tester);
    await openSection(tester, 'Records');
    await tapVisible(tester, find.byKey(const ValueKey('filter-issue-i-limp')));
    expect(find.text('4 entries'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue-entry-o-limp-1')), findsOneWidget);
    // Another chip goes back to its own view.
    await tapVisible(tester, find.byKey(const Key('filter-journal')));
    expect(find.text('13 entries'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue-entry-o-limp-1')), findsNothing);

    await tapVisible(tester, find.byKey(const ValueKey('filter-issue-i-limp')));
    await tapVisible(tester, find.byKey(const Key('records-issue-open')));
    expect(find.byKey(const Key('issue-summary')), findsOneWidget);
  });

  testWidgets('more than three open problems fold into one row that opens Records', (tester) async {
    final repo = withIssue();
    await tester.runAsync(() async {
      for (final (title, day) in [('Coughing', 7), ('Itchy ear', 8), ('Sneezing', 9)]) {
        await repo.saveIssue(HealthIssue(id: '', petId: kelly, title: title, startedOn: DateTime(2025, 6, day)));
      }
    });
    await pumpIssues(tester, repository: repo);
    expect(find.textContaining('Ongoing since'), findsNWidgets(3));
    expect(find.text('Limping, right front leg'), findsNothing);
    expect(find.text('1 more problem'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('overview-issues-more')));
    final chip = tester.widget<ChoiceChip>(find.byKey(const ValueKey('filter-issue-i-limp')));
    expect(chip.selected, isTrue);
    expect(find.byKey(const ValueKey('issue-entry-o-limp-1')), findsOneWidget);
  });

  testWidgets('the report is shared as a PDF from the page', (tester) async {
    final h = await pumpIssues(tester);
    await openLimp(tester);
    await tapVisible(tester, find.byKey(const Key('issue-share')));
    final report = h.pdf.reports.last;
    expect(report.title, 'Kelly: Limping, right front leg');
    expect(report.records, hasLength(4));
    expect(report.records.where((r) => r.photos.isNotEmpty), hasLength(2));
    expect(h.sharer.shared.single.name, 'kelly-limping-right-front-leg.pdf');
  });

  testWidgets('a failure to load says so, with a way to try again', (tester) async {
    final h = await pumpIssues(tester);
    await openLimp(tester);
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('issue-summary'))), listen: false);
    h.repository.failing = true;
    container.invalidate(healthIssuesProvider(kelly));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the problem'), findsOneWidget);

    h.repository.failing = false;
    await tapVisible(tester, find.text('Try again'));
    expect(find.byKey(const Key('issue-summary')), findsOneWidget);
  });

  testWidgets('the "+" sheet offers "Follow a problem" after the Quick log', (tester) async {
    await pumpIssues(tester);
    await tester.tap(find.byKey(AddFab.fabKey));
    await tester.pumpAndSettle();
    final quick = tester.getTopLeft(find.byKey(AddSheet.rowKey('quick-log'))).dy;
    final follow = tester.getTopLeft(find.byKey(AddSheet.rowKey('follow-problem'))).dy;
    final record = tester.getTopLeft(find.byKey(AddSheet.rowKey('record'))).dy;
    expect(quick, lessThan(follow));
    expect(follow, lessThan(record));
    expect(find.text('A limp, a rash, a cough: over a few days'), findsOneWidget);
  });

  testWidgets('in Hebrew: the row, the page and the Quick log addition', (tester) async {
    final he = lookupHealthL10n(hebrewLocale);
    await pumpHealth(tester, harness: hebrewHealth(repository: withIssue()));
    final row = find.byKey(const ValueKey('overview-issue-i-limp'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.textContaining('עדיין נמשכת מאז')),
      findsOneWidget,
    );
    await openLimp(tester);
    expect(find.text(he.issueOngoing), findsOneWidget);
    expect(find.text(he.issueResolve), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('issue-add-entry')));
    expect(find.text(he.issueFor('Limping, right front leg')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('quick-mobility')));
    expect(find.text(he.issuePartOf), findsOneWidget);
    expect(find.text(he.issuePhotos(4)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
