import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';

  Future<HealthHarness> openHistory(WidgetTester tester, {HealthHarness? harness}) async {
    final h = await pumpHealth(tester, harness: harness);
    await openSection(tester, 'History');
    return h;
  }

  String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('history-count'))).data!;

  group('History timeline', () {
    testWidgets('lists every done record by month, newest first', (tester) async {
      await openHistory(tester);

      expect(count(tester), '12 records');
      expect(find.text('May 2025'), findsOneWidget);
      expect(find.text('March 2025'), findsOneWidget);
      expect(find.text('Flea and tick tablet'), findsOneWidget);
      expect(find.text('Preventive · 27.05.25'), findsOneWidget);
      expect(find.text('Next due 27.07.25'), findsOneWidget);
      expect(find.text('Vet visit · 02.05.25 · Park Vet Clinic'), findsOneWidget);
      expect(find.text('Arthritis in the hips. Started joint tablets.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('2 attachments')), findsOneWidget);

      // Newest first: May above March above January.
      final may = tester.getTopLeft(find.text('May 2025')).dy;
      final march = tester.getTopLeft(find.text('March 2025')).dy;
      final january = tester.getTopLeft(find.text('January 2025')).dy;
      expect(may, lessThan(march));
      expect(march, lessThan(january));

      // Planned records are in the Schedule, not here.
      expect(find.text('General check'), findsNothing);
    });

    testWidgets('filter chips and the search narrow the timeline', (tester) async {
      await openHistory(tester);

      await tapVisible(tester, find.byKey(const ValueKey('filter-vaccination')));
      expect(count(tester), '3 of 12 records');
      expect(find.text('Rabies booster'), findsOneWidget);
      expect(find.text('Flea and tick tablet'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('filter-documents')));
      expect(count(tester), '3 of 12 records');
      expect(find.text('Blood test results'), findsOneWidget);
      expect(find.text('Limping after a long walk'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('filter-all')));
      await tester.enterText(find.byKey(const Key('history-search')), 'ear drops');
      await tester.pumpAndSettle();
      expect(count(tester), '1 of 12 records');
      expect(find.text('Ear infection'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('history-search')), 'giraffe');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches'), findsOneWidget);
      await tapVisible(tester, find.text('Show all records'));
      expect(count(tester), '12 records');
    });

    testWidgets('the Overview counts open the matching filter', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.bySemanticsLabel('3 Vaccinations'));

      expect(count(tester), '3 of 12 records');
      expect(find.text('DHPP booster'), findsOneWidget);

      await openSection(tester, 'Overview');
      await tapVisible(tester, find.bySemanticsLabel('3 Documents'));
      expect(count(tester), '3 of 12 records');
      expect(find.text('Blood test results'), findsOneWidget);
    });

    testWidgets('a pet without records gets a friendly empty state', (tester) async {
      await openHistory(tester);
      await selectPet(tester, 'Soya');

      expect(find.text('No records yet'), findsOneWidget);
      await tapVisible(tester, find.text('Add a record'));
      expect(find.text('New record'), findsOneWidget);
    });
  });

  group('Record detail', () {
    testWidgets('shows the dates apart, the product, the vet and the files', (tester) async {
      await openHistory(tester);
      await tapVisible(tester, find.text('Rabies booster'));

      expect(find.text('Record'), findsOneWidget);
      expect(find.text('Vaccination · Kelly'), findsOneWidget);
      expect(find.text('Date given'), findsOneWidget);
      expect(find.text('14.03.25 · 10:00'), findsOneWidget);
      expect(find.text('Next due (from the vet)'), findsOneWidget);
      expect(find.text('14.03.26'), findsOneWidget);
      expect(find.text('In the Schedule'), findsOneWidget);
      expect(find.text('Rabies vaccine, 1 year, batch A1234'), findsOneWidget);
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);
      expect(find.text('A little sleepy that evening, fine the next morning.'), findsOneWidget);
      expect(find.text('vaccination-booklet.png'), findsOneWidget);
    });

    testWidgets('a photo opens full screen and a PDF goes to the phone', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Blood test results'));

      await tapVisible(tester, find.text('blood-test-page-2.png'));
      expect(find.byTooltip('Share this photo'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // The sample data has no link, so the file itself is handed over.
      await tapVisible(tester, find.text('blood-test.pdf'));
      expect(h.sharer.shared.single.name, 'blood-test.pdf');
      expect(h.sharer.shared.single.mimeType, 'application/pdf');
    });

    testWidgets('a photo or a PDF can be added, and an oversized file is refused', (tester) async {
      final h = HealthHarness();
      h.picker.pdf = testPdf();
      h.picker.photo = testPhoto('letter.png');
      await openHistory(tester, harness: h);
      await tapVisible(tester, find.text('Dental cleaning'));
      expect(find.textContaining('No photos or PDFs yet'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('detail-attach')));
      expect(find.text('Take a photo'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('attach-pdf')));
      expect(find.text('lab-results.pdf'), findsOneWidget);
      expect(h.picker.asked, ['pdf']);

      await tapVisible(tester, find.byKey(const Key('detail-attach')));
      await tapVisible(tester, find.byKey(const ValueKey('attach-camera')));
      expect(find.text('letter.png'), findsOneWidget);

      h.picker.pdf = hugePdf();
      await tapVisible(tester, find.byKey(const Key('detail-attach')));
      await tapVisible(tester, find.byKey(const ValueKey('attach-pdf')));
      expect(find.text('That file is larger than 5 MB. Please choose a smaller one.'), findsOneWidget);
      expect(find.text('huge.pdf'), findsNothing);

      final stored = await real(tester, () => h.repository.fetchDocuments(kelly));
      expect(stored.where((d) => d.recordId == 'r-dental').map((d) => d.fileName), ['lab-results.pdf', 'letter.png']);
    });

    testWidgets('sharing a record hands a PDF to the share sheet', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Rabies booster'));
      await tapVisible(tester, find.byKey(const Key('record-share')));

      final report = h.pdf.last;
      expect(report.title, 'Kelly: Rabies booster');
      expect(report.subtitle, 'Dog · Mix · 13.6 years · 23 kg');
      expect(report.records.single.title, 'Rabies booster');
      expect(report.records.single.details, contains('Next due 14.03.26'));
      expect(report.facts.map((f) => f.$1), containsAll(['Microchip', 'Allergies', 'Conditions', 'Regular vet']));
      expect(h.sharer.shared.single.name, 'kelly-rabies-booster.pdf');
      expect(h.sharer.shared.single.mimeType, 'application/pdf');
    });
  });

  group('Record form', () {
    testWidgets('a vaccination is saved with a separate next due date', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Add record'));
      expect(find.text('New record'), findsOneWidget);

      // Only the title is required.
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('Give the record a title.'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('kind-vaccination')));
      await tester.enterText(find.byKey(const Key('record-title')), 'Leptospirosis vaccine');
      await tester.enterText(find.byKey(const Key('record-product')), 'Lepto 4, batch L77');
      await tester.enterText(find.byKey(const Key('record-clinic')), 'Park Vet Clinic');

      // The next due date comes from the owner, never from the app.
      expect(find.text('Not set'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('record-next-due')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('11.06.25'), findsOneWidget);

      await tapVisible(tester, find.text('Save record'));
      expect(find.text('New record'), findsNothing);
      expect(count(tester), '13 records');
      expect(find.text('Leptospirosis vaccine'), findsOneWidget);
      expect(find.text('Next due 11.06.25'), findsOneWidget);

      final records = await real(tester, () => h.repository.fetchRecords(kelly));
      final saved = records.firstWhere((r) => r.title == 'Leptospirosis vaccine' && r.isDone);
      expect(saved.kind, RecordKind.vaccination);
      expect(saved.productName, 'Lepto 4, batch L77');
      expect(saved.nextDueOn, DateTime(2025, 6, 11));
      // The next due date became an upcoming item.
      final followUp = records.firstWhere((r) => r.followUpOf == saved.id);
      expect(followUp.isDone, isFalse);
      expect(followUp.scheduledAt, DateTime(2025, 6, 11, 9));
      // And the reminder hook heard about it.
      expect(h.scheduler.last.upcoming.map((r) => r.id), contains(followUp.id));
    });

    testWidgets('files chosen in the form are stored with the new record', (tester) async {
      final h = HealthHarness();
      h.picker.pdf = testPdf('discharge-letter.pdf');
      await openHistory(tester, harness: h);
      await tapVisible(tester, find.text('Add record'));

      await tapVisible(tester, find.byKey(const ValueKey('kind-document')));
      await tester.enterText(find.byKey(const Key('record-title')), 'Discharge letter');
      await tapVisible(tester, find.byKey(const Key('record-attach')));
      await tapVisible(tester, find.byKey(const ValueKey('attach-pdf')));
      expect(find.text('discharge-letter.pdf'), findsOneWidget);
      await tapVisible(tester, find.text('Save record'));

      expect(find.text('Discharge letter'), findsOneWidget);
      final records = await real(tester, () => h.repository.fetchRecords(kelly));
      final saved = records.firstWhere((r) => r.title == 'Discharge letter');
      final stored = await real(tester, () => h.repository.fetchDocuments(kelly));
      expect(stored.where((d) => d.recordId == saved.id).single.fileName, 'discharge-letter.pdf');
    });

    testWidgets('a record is edited from its detail page', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Worming tablet'));
      await tester.tap(find.byTooltip('Edit record'));
      await tester.pumpAndSettle();
      expect(find.text('Edit record'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('record-title')), 'Worming tablet (spring)');
      await tester.enterText(find.byKey(const Key('record-notes')), 'Given with breakfast.');
      await tapVisible(tester, find.text('Save record'));

      // Back on the detail page, already up to date.
      expect(find.text('Worming tablet (spring)'), findsOneWidget);
      expect(find.text('Given with breakfast.'), findsOneWidget);
      final records = await real(tester, () => h.repository.fetchRecords(kelly));
      expect(records.firstWhere((r) => r.id == 'r-worm').notes, 'Given with breakfast.');
    });

    testWidgets('a record is deleted only after a confirmation', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Rabies booster'));
      await tester.tap(find.byTooltip('Edit record'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete record'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this record?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit record'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Both pages closed: back on the timeline without the record.
      expect(find.text('Edit record'), findsNothing);
      expect(find.text('Record'), findsNothing);
      expect(count(tester), '11 records');
      expect(find.text('Rabies booster'), findsNothing);

      final records = await real(tester, () => h.repository.fetchRecords(kelly));
      // The record, and the upcoming item its next due date had created.
      expect(records.map((r) => r.id), isNot(contains('r-rabies')));
      expect(records.map((r) => r.id), isNot(contains('r-rabies-due')));
      final stored = await real(tester, () => h.repository.fetchDocuments(kelly));
      expect(stored.map((d) => d.id), isNot(contains('d-rabies')));
    });

    testWidgets('a date that is still ahead becomes an upcoming item', (tester) async {
      final h = await pumpHealth(tester);
      await selectPet(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('start-appointment')));
      expect(find.text('New appointment'), findsOneWidget);
      expect(find.text('Planned for'), findsOneWidget);
      expect(find.text('11.06.25'), findsOneWidget);
      expect(find.textContaining('saved as an upcoming item in the Schedule'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('record-title')), 'First check-up');
      await tapVisible(tester, find.text('Save record'));

      // The Overview now leads with it instead of the first steps.
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.text('First check-up'), findsOneWidget);
      expect(find.byKey(const Key('getting-started')), findsNothing);
      final records = await real(tester, () => h.repository.fetchRecords('soya'));
      expect(records.single.isDone, isFalse);
      expect(records.single.scheduledAt, DateTime(2025, 6, 11, 9));
    });

    testWidgets('a failed save keeps the form open with the reason', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Add record'));
      await tester.enterText(find.byKey(const Key('record-title')), 'Nail trim');

      h.repository.failing = true;
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('New record'), findsOneWidget);
      expect(find.text('Could not reach the server. Check your connection and try again.'), findsOneWidget);

      h.repository.failing = false;
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('New record'), findsNothing);
      expect(find.text('Nail trim'), findsOneWidget);
    });
  });
}
