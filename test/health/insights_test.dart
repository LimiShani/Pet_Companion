import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/share/health_pdf.dart';
import 'package:pet_companion/features/health/share/health_report.dart';
import 'package:pet_companion/features/health/widgets/weight_trend.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';

  Future<HealthHarness> openInsights(WidgetTester tester, {HealthHarness? harness}) async {
    final h = await pumpHealth(tester, harness: harness);
    await openSection(tester, 'Insights');
    return h;
  }

  bool saveEnabled(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed != null;

  group('Insights', () {
    testWidgets('shows the weight trend with vet visits and the journal', (tester) async {
      await openInsights(tester);

      expect(find.text('23 kg', findRichText: true), findsOneWidget);
      expect(find.text('01.06.25 · 6 weigh-ins'), findsOneWidget);
      expect(find.text('0.2 kg down since 02.05.25 · highest 24.1 · lowest 23'), findsOneWidget);
      expect(find.text('18.09.24'), findsOneWidget);
      expect(find.text('vet visit'), findsOneWidget);

      // The line is drawn by hand; vet visits inside its period are marked.
      final chart = tester.widget<WeightTrendChart>(find.byType(WeightTrendChart));
      expect(chart.points, hasLength(6));
      expect(chart.points.last.value, 23);
      expect(chart.events, hasLength(3));
      expect(
        find.bySemanticsLabel(RegExp('Weight trend from 24.1 kg on 18.09.24 to 23 kg on 01.06.25')),
        findsOneWidget,
      );

      // The journal, newest first.
      expect(find.text('Observations'), findsOneWidget);
      expect(find.text('Mobility · Less than usual'), findsOneWidget);
      expect(find.text('08.06.25 · Stiff getting up in the morning'), findsOneWidget);
      expect(find.text('Appetite · Usual'), findsOneWidget);
      expect(find.text('Weight · 23 kg'), findsOneWidget);
      final mobility = tester.getTopLeft(find.byKey(const ValueKey('observation-o-mobility'))).dy;
      final energy = tester.getTopLeft(find.byKey(const ValueKey('observation-o-energy'))).dy;
      expect(mobility, lessThan(energy));

      // A record of observations, never a verdict.
      expect(find.textContaining('The app does not interpret it'), findsOneWidget);
      expect(find.textContaining('diagnos'), findsNothing);
    });

    testWidgets('the journal is filtered by category', (tester) async {
      await openInsights(tester);

      await tapVisible(tester, find.byKey(const ValueKey('journal-mobility')));
      expect(find.text('Mobility · Less than usual'), findsOneWidget);
      expect(find.text('Appetite · Usual'), findsNothing);
      expect(find.text('Weight · 23 kg'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('journal-all')));
      expect(find.text('Appetite · Usual'), findsOneWidget);
    });

    testWidgets('a pet with nothing logged is invited to the Quick log', (tester) async {
      await openInsights(tester);
      await selectPet(tester, 'Soya');

      expect(find.text('Nothing logged yet'), findsOneWidget);
      await tapVisible(tester, find.text('Open the Quick log'));
      expect(find.text('Quick log for Soya'), findsOneWidget);
    });

    testWidgets('an entry can be changed and deleted', (tester) async {
      final h = await openInsights(tester);

      await tapVisible(tester, find.byKey(const ValueKey('observation-o-energy')));
      expect(find.text('Edit entry'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('level-usual')));
      await tapVisible(tester, find.text('Save changes'));
      expect(find.text('Energy · Usual'), findsOneWidget);
      // The note and the date are kept.
      expect(find.text('30.05.25 · Short walk only'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('observation-o-energy')));
      await tapVisible(tester, find.byKey(const Key('quick-delete')));
      expect(find.text('Delete this entry?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('observation-o-energy')), findsNothing);
      final stored = await real(tester, () => h.repository.fetchObservations(kelly));
      expect(stored.map((o) => o.id), isNot(contains('o-energy')));
    });
  });

  group('Quick log', () {
    testWidgets('two taps save an observation for a dog', (tester) async {
      final h = await openInsights(tester);

      await tester.tap(find.byKey(const Key('quick-log-button')));
      await tester.pumpAndSettle();
      expect(find.text('Quick log for Kelly'), findsOneWidget);
      for (final key in ['weight', 'appetite', 'energy', 'mobility', 'digestion', 'skin_coat', 'dental', 'other']) {
        expect(find.byKey(ValueKey('quick-$key')), findsOneWidget);
      }
      // Nothing to save until something is chosen.
      expect(saveEnabled(tester, 'Save to journal'), isFalse);

      await tapVisible(tester, find.byKey(const ValueKey('quick-appetite')));
      for (final level in ['usual', 'less', 'more', 'unsure']) {
        expect(find.byKey(ValueKey('level-$level')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('level-different')), findsNothing);
      expect(find.text('Today · 17:40'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('level-less')));
      expect(saveEnabled(tester, 'Save to journal'), isTrue);
      await tester.enterText(find.byKey(const Key('quick-note')), 'Left half of her dinner');
      await tapVisible(tester, find.text('Save to journal'));

      expect(find.text('Quick log for Kelly'), findsNothing);
      expect(find.text('Appetite · Less than usual'), findsOneWidget);
      expect(find.text('10.06.25 · Left half of her dinner'), findsOneWidget);
      final stored = await real(tester, () => h.repository.fetchObservations(kelly));
      final saved = stored.firstWhere((o) => o.note == 'Left half of her dinner');
      expect(saved.category, 'appetite');
      expect(saved.level, ObservationLevel.less);
      expect(saved.value, isNull);
      expect(saved.observedAt, fixedNow);
    });

    testWidgets('logging a weight updates the trend and the pet profile', (tester) async {
      await openInsights(tester);

      await tapVisible(tester, find.byKey(const Key('log-weight')));
      expect(find.text('Weight in kilograms'), findsOneWidget);
      expect(find.text('Last time: 23 kg on 01.06.25'), findsOneWidget);
      expect(saveEnabled(tester, 'Save to journal'), isFalse);

      await tester.enterText(find.byKey(const Key('quick-weight-field')), '0');
      await tester.pump();
      expect(saveEnabled(tester, 'Save to journal'), isFalse);

      await tester.enterText(find.byKey(const Key('quick-weight-field')), '22,8');
      await tester.pump();
      await tapVisible(tester, find.text('Save to journal'));

      expect(find.text('22.8 kg', findRichText: true), findsOneWidget);
      expect(find.text('10.06.25 · 7 weigh-ins'), findsOneWidget);
      expect(find.text('0.2 kg down since 01.06.25 · highest 24.1 · lowest 22.8'), findsOneWidget);
      // The Home dashboard's weight pill reads the pet profile.
      expect(hostContainer(tester).read(petsProvider).first.weightKg, 22.8);
    });

    testWidgets('another species gets its own categories and is weighed in grams', (tester) async {
      final h = HealthHarness(
        repository: fakeHealth(seeded: false),
        pets: const [Pet(id: 'rio', name: 'Rio', species: PetSpecies.bird, breed: 'Cockatiel', ageYears: 4)],
      );
      await pumpHealth(tester, harness: h);

      await tapVisible(tester, find.byKey(const Key('overview-quick-log')));
      expect(find.text('Quick log for Rio'), findsOneWidget);
      for (final key in ['weight', 'diet', 'droppings', 'feathers', 'activity', 'vocalisation', 'environment']) {
        expect(find.byKey(ValueKey('quick-$key')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('quick-mobility')), findsNothing);

      // How something looks is answered differently from how much.
      await tapVisible(tester, find.byKey(const ValueKey('quick-feathers')));
      expect(find.byKey(const ValueKey('level-different')), findsOneWidget);
      expect(find.byKey(const ValueKey('level-less')), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('quick-weight')));
      expect(find.text('Weight in grams'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('quick-weight-field')), '412');
      await tester.pump();
      await tapVisible(tester, find.text('Save to journal'));

      final stored = await real(tester, () => h.repository.fetchObservations('rio'));
      expect(stored.single.value, closeTo(0.412, 1e-9));
      await openSection(tester, 'Insights');
      expect(find.text('412 g', findRichText: true), findsOneWidget);
      expect(find.text('Weight · 412 g'), findsOneWidget);
    });

    testWidgets('a worry that looks urgent leads to the vet, not to a form', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.byKey(const Key('overview-quick-log')));

      await tapVisible(tester, find.byKey(const Key('quick-urgent')));
      expect(find.text('Quick log for Kelly'), findsNothing);
      expect(find.text('Emergency · Kelly'), findsOneWidget);
      expect(find.byKey(const ValueKey('call-regular')), findsOneWidget);
    });

    testWidgets('a failed save keeps the sheet open with the reason', (tester) async {
      final h = await openInsights(tester);
      await tester.tap(find.byKey(const Key('quick-log-button')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('quick-energy')));
      await tapVisible(tester, find.byKey(const ValueKey('level-more')));

      h.repository.failing = true;
      await tapVisible(tester, find.text('Save to journal'));
      expect(find.text('Quick log for Kelly'), findsOneWidget);
      expect(find.text('Could not reach the server. Check your connection and try again.'), findsOneWidget);
    });
  });

  group('Sharing', () {
    testWidgets('Share on the Overview hands a PDF summary to the share sheet', (tester) async {
      final h = await pumpHealth(tester);
      await tapVisible(tester, find.byKey(const Key('overview-share')));

      final report = h.pdf.last;
      expect(report.title, 'Kelly: health summary');
      expect(report.subtitle, 'Dog · Mix · 13.6 years · 23 kg');
      expect(report.prepared, 'Prepared on 10.06.25 by Alex with Pet Companion');
      final facts = {for (final f in report.facts) f.$1: f.$2};
      expect(facts['Microchip'], '985 112 004 567 321');
      expect(facts['Allergies'], 'Chicken (skin reaction)');
      expect(facts['Conditions'], 'Arthritis in the hips');
      expect(facts['Active medicines'], 'Joint tablets 50 mg: 1 tablet by mouth, twice a day with food');
      expect(facts['Regular vet'], 'Dr. Levi, Park Vet Clinic · +972 3 555 0142 · 12 Park Street, Tel Aviv');
      expect(facts['Emergency vet'], contains('City Animal Hospital'));
      expect(facts['Emergency contact'], 'Dana (sister) · +972 50 555 0117');
      // The recent history, newest first; planned records are left out.
      expect(report.recordsTitle, 'Recent records');
      expect(report.records, hasLength(12));
      expect(report.records.first.title, 'Flea and tick tablet');
      expect(report.records.first.details, 'Next due 27.07.25');
      expect(report.footer, contains('not veterinary advice'));

      final file = h.sharer.shared.single;
      expect(file.name, 'kelly-health-summary.pdf');
      expect(file.mimeType, 'application/pdf');
      expect(file.subject, 'Kelly: health summary');
    });

    testWidgets('the Emergency card shares the same summary', (tester) async {
      final h = await pumpHealth(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('Emergency contacts for Kelly')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text("Open Kelly's Emergency card"));

      await tapVisible(tester, find.byKey(const Key('share-summary')));
      expect(h.pdf.last.title, 'Kelly: health summary');
      expect(h.sharer.shared.single.name, 'kelly-health-summary.pdf');
    });

    testWidgets('says so when the PDF or the share sheet is not available', (tester) async {
      final h = await pumpHealth(tester);

      h.sharer.succeeds = false;
      await tapVisible(tester, find.byKey(const Key('overview-share')));
      expect(find.text('Could not open the share sheet on this device.'), findsOneWidget);

      h.pdf.failing = true;
      await tapVisible(tester, find.byKey(const Key('overview-share')));
      expect(find.text('Could not prepare the PDF. Please try again.'), findsOneWidget);
    });

    testWidgets('a pet with almost nothing still gets an honest summary', (tester) async {
      final h = await pumpHealth(tester);
      await selectPet(tester, 'Soya');
      await tapVisible(tester, find.byKey(const Key('overview-share')));

      final report = h.pdf.last;
      expect(report.title, 'Soya: health summary');
      expect(report.subtitle, 'Dog');
      // Nothing entered, nothing invented.
      expect(report.facts, isEmpty);
      expect(report.records, isEmpty);
      expect(h.sharer.shared.single.name, 'soya-health-summary.pdf');
    });
  });

  group('PDF file', () {
    // The bundled fonts, read from the project (a plain test has no asset
    // bundle).
    Future<ByteData> fromDisk(String path) async => ByteData.sublistView(File(path).readAsBytesSync());
    final builder = PdfHealthPdfBuilder(loadFont: fromDisk);

    const report = HealthReport(
      title: 'Kelly: health summary',
      subtitle: 'Dog · Mix · 13.6 years · 23 kg',
      prepared: 'Prepared on 10.06.25 by Alex with Pet Companion',
      fileName: 'kelly-health-summary.pdf',
      facts: [('Allergies', 'Chicken (skin reaction)'), ('Regular vet', 'Dr. Levi · +972 3 555 0142')],
      recordsTitle: 'Recent records',
      records: [
        HealthReportRow(date: '14.03.25', kind: 'Vaccination', title: 'Rabies booster', details: 'Next due 14.03.26'),
        HealthReportRow(date: '02.05.25', kind: 'Vet visit', title: 'Limping after a long walk'),
      ],
    );

    test('a report in western letters becomes a text PDF, in the app font', () async {
      final bytes = await builder.build(report);
      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(800));
      expect(latin1.decode(bytes), contains('Nunito'));
    });

    test('a long history runs over several pages', () async {
      final long = HealthReport(
        title: report.title,
        subtitle: report.subtitle,
        prepared: report.prepared,
        fileName: report.fileName,
        facts: report.facts,
        recordsTitle: 'Recent records',
        records: [
          for (var i = 0; i < 80; i++)
            HealthReportRow(
              date: '14.03.25',
              kind: 'Vet visit',
              title: 'Visit number $i',
              details: 'Park Vet Clinic · A long note about what was found and what to watch for next time.',
            ),
        ],
      );
      final bytes = await builder.build(long);
      final text = latin1.decode(bytes);
      expect(RegExp('/Type ?/Page[^s]').allMatches(text).length, greaterThan(1));
    });

    test('typographic punctuation is replaced, and what each font draws is known', () async {
      expect(plainPunctuation('Kelly’s “big” walk – done…'), 'Kelly\'s "big" walk - done...');
      final fonts = await HealthPdfFonts.load(fromDisk);
      expect(fonts.nunitoCovers('Dr. Lévi · café'), isTrue);
      expect(fonts.nunitoCovers('ד"ר לוי'), isFalse);
      expect(fonts.fredokaCovers('ד״ר לוי · Dr. Levi · 23 ק״ג · ₪320'), isTrue);
      expect(fonts.fredokaCovers('🐶'), isFalse);
    });

    testWidgets('a left-to-right report with another script is drawn onto the pages instead', (tester) async {
      const hebrew = HealthReport(
        title: 'קלי: סיכום בריאות',
        subtitle: 'כלבה · מעורבת',
        prepared: 'Prepared on 10.06.25 with Pet Companion',
        fileName: 'kelly-health-summary.pdf',
        facts: [('Regular vet', 'ד"ר לוי, מרפאת הפארק')],
        recordsTitle: 'Recent records',
        records: [HealthReportRow(date: '14.03.25', kind: 'Vaccination', title: 'חיסון כלבת', details: 'מרפאת הפארק')],
      );
      final bytes = await tester.runAsync(() => builder.build(hebrew));
      expect(latin1.decode(bytes!.sublist(0, 5)), '%PDF-');
      // A page picture makes the file much larger than a text PDF.
      expect(bytes.length, greaterThan(3000));
    });
  });

  group('WeightTrendPainter', () {
    final points = [
      TrendPoint(DateTime(2025, 1, 1), 24),
      TrendPoint(DateTime(2025, 2, 1), 23),
      TrendPoint(DateTime(2025, 3, 1), 23.5),
    ];
    const size = Size(200, 100);

    test('runs oldest to latest, left to right, heavier higher', () {
      final spots = WeightTrendPainter(points: points).layout(size);
      expect(spots, hasLength(3));
      expect(spots[0].dx, lessThan(spots[1].dx));
      expect(spots[1].dx, lessThan(spots[2].dx));
      // 24 kg sits above 23 kg.
      expect(spots[0].dy, lessThan(spots[1].dy));
    });

    testWidgets('runs left to right in a right-to-left layout too', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(width: 200, child: WeightTrendChart(points: points)),
          ),
        ),
      );
      final painter = tester.widget<CustomPaint>(find.byType(CustomPaint)).painter! as WeightTrendPainter;
      final spots = painter.layout(size);
      expect(spots.first.dx, lessThan(spots.last.dx));
    });

    test('one weigh-in is a single marker, a flat series a level line', () {
      final one = WeightTrendPainter(points: [points.first]).layout(size);
      expect(one.single.dx, greaterThan(size.width / 2));
      final flat = WeightTrendPainter(
        points: [TrendPoint(DateTime(2025, 1, 1), 5), TrendPoint(DateTime(2025, 2, 1), 5)],
      ).layout(size);
      expect(flat.first.dy, flat.last.dy);
    });
  });
}
