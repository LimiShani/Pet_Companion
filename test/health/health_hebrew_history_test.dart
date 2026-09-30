import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/health_format.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'health_test_helpers.dart';

// The History in Hebrew and right to left: the timeline and its filters,
// a record, its files and its cost, and the record form.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);

const kelly = 'kelly';

Future<HealthHarness> openHistory(WidgetTester tester, {HealthHarness? harness, Size size = widePhone}) async {
  final h = await pumpHealth(tester, harness: harness ?? hebrewHealth(), size: size);
  await openSection(tester, h.l10n.sectionHistory);
  return h;
}

String count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('history-count'))).data!;

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [widePhone, smallPhone]) {
    final width = size.width.toInt();

    group('History in Hebrew ($width px)', () {
      testWidgets('the timeline, its filters and its search', (tester) async {
        await openHistory(tester, size: size);
        final format = HealthFormat.forLocale(hebrewLocale);

        expect(count(tester), '12 רשומות');
        expect(find.text(format.month(DateTime(2025, 5))), findsOneWidget);
        expect(format.month(DateTime(2025, 5)), contains('מאי'));
        expect(find.text('Flea and tick tablet'), findsOneWidget); // sample data stays English
        expect(find.text(format.dots(['טיפול מונע', '27.05.25'])), findsOneWidget);
        expect(find.text(he.nextDue('27.07.25')), findsOneWidget);
        expect(find.text(format.dots(['ביקור וטרינר', '02.05.25', 'Park Vet Clinic'])), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(he.costSemantics(format.money(320, 'ILS'))))),
          findsOneWidget,
        );
        expect(find.text(he.addRecord), findsOneWidget);
        expect(find.text(he.searchRecords('Kelly')), findsOneWidget);
        for (final chip in ['הכול', 'ביקורי וטרינר', 'חיסונים', 'טיפולים מונעים', 'טיפולים', 'מסמכים']) {
          expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
        }
        for (final english in ['All', 'Vaccinations', 'Documents', 'Add record', 'May 2025']) {
          expect(find.text(english), findsNothing, reason: english);
        }
        expect(directionOf(tester, find.byKey(const Key('history-count'))), TextDirection.rtl);

        // Newest first, month by month.
        final may = tester.getTopLeft(find.text(format.month(DateTime(2025, 5)))).dy;
        final march = tester.getTopLeft(find.text(format.month(DateTime(2025, 3)))).dy;
        expect(may, lessThan(march));

        // The record with two files: its card says so, merged with the rest.
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(he.attachmentsCount(2)))), findsOneWidget);

        await tapVisible(tester, find.byKey(const ValueKey('filter-vaccination')));
        expect(count(tester), '3 מתוך 12 רשומות');
        await tapVisible(tester, find.byKey(const Key('filter-documents')));
        expect(count(tester), '3 מתוך 12 רשומות');
        await tapVisible(tester, find.byKey(const Key('filter-all')));

        // The search finds a record by the Hebrew name of its kind too.
        await tester.enterText(find.byKey(const Key('history-search')), 'חיסון');
        await tester.pumpAndSettle();
        expect(count(tester), '3 מתוך 12 רשומות');
        expect(find.byTooltip(he.clearSearch), findsOneWidget);

        await tester.enterText(find.byKey(const Key('history-search')), 'ג׳ירפה');
        await tester.pumpAndSettle();
        expect(find.text(he.nothingMatches), findsOneWidget);
        expect(find.text(he.nothingMatchesNote), findsOneWidget);
        await tapVisible(tester, find.text(he.showAllRecords));
        expect(count(tester), '12 רשומות');
      });

      testWidgets('a record, its files and sharing it', (tester) async {
        final h = hebrewHealth();
        h.picker.photo = testPhoto('letter.png');
        h.picker.pdf = hugePdf();
        await openHistory(tester, harness: h, size: size);

        await tapVisible(tester, find.text('Rabies booster'));
        expect(find.text('רשומה'), findsOneWidget);
        expect(find.byTooltip(he.editRecord), findsOneWidget);
        expect(find.textContaining('חיסון'), findsOneWidget);
        expect(find.text(he.dateGiven), findsOneWidget);
        expect(find.text('14.03.25 · 10:00'), findsOneWidget);
        expect(find.text(he.nextDueFromVet), findsOneWidget);
        expect(find.text(he.inTheSchedule), findsOneWidget);
        expect(find.text(he.product), findsOneWidget);
        expect(find.text(he.vetOrClinic), findsOneWidget);
        expect(find.text('הערות'), findsOneWidget);
        expect(find.text('קבצים מצורפים'), findsOneWidget);
        expect(find.text(he.shareThisRecord), findsOneWidget);
        expect(find.text(he.deleteInsideEdit), findsOneWidget);
        // A file keeps its name, and says what it is in Hebrew.
        expect(find.text('vaccination-booklet.png'), findsOneWidget);
        expect(find.textContaining('תמונה'), findsWidgets);
        // What the owner typed keeps its own direction.
        final notes = tester.widget<Text>(find.text('A little sleepy that evening, fine the next morning.'));
        expect(notes.textDirection, TextDirection.ltr);

        // Adding a file: the sheet, and a file that is too large.
        await tapVisible(tester, find.byKey(const Key('detail-attach')));
        expect(find.text(he.attachSheetNote), findsOneWidget);
        expect(find.text(he.takeAPhoto), findsOneWidget);
        expect(find.text(he.chooseAPhoto), findsOneWidget);
        expect(find.text(he.chooseAPdf), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('attach-pdf')));
        expect(find.text(he.errFileTooLarge), findsOneWidget);

        await tapVisible(tester, find.byKey(const Key('detail-attach')));
        await tapVisible(tester, find.byKey(const ValueKey('attach-camera')));
        expect(find.text(he.fileAttached('letter.png')), findsOneWidget);
      });

      testWidgets('a new record and its checks', (tester) async {
        final h = await openHistory(tester, size: size);
        await tapVisible(tester, find.text(he.addRecord));

        expect(find.text('רשומה חדשה'), findsOneWidget);
        expect(find.text(he.whatKindOfRecord), findsOneWidget);
        for (final kind in ['ביקור וטרינר', 'חיסון', 'טיפול מונע', 'תרופה', 'טיפול', 'מסמך', 'הערה']) {
          expect(find.widgetWithText(ChoiceChip, kind), findsOneWidget, reason: kind);
        }
        expect(find.text(he.fieldTitle), findsOneWidget);
        expect(find.text(he.fieldDate), findsOneWidget);
        expect(find.text(he.fieldTime), findsOneWidget);
        expect(find.text(he.vetOrClinicOptional), findsOneWidget);
        expect(find.text(he.costOptional), findsOneWidget);
        expect(find.text(he.costNotePaid), findsOneWidget);
        expect(find.text(he.attachments), findsOneWidget);
        expect(find.text(he.addPhotoOrPdf), findsOneWidget);

        await tapVisible(tester, find.text(he.saveRecord));
        expect(find.text(he.validRecordTitle), findsOneWidget);

        await tester.enterText(find.byKey(const Key('record-title')), 'גזירת ציפורניים');
        await tester.enterText(find.byKey(const Key('record-cost')), '4.5.0');
        await tapVisible(tester, find.text(he.saveRecord));
        expect(find.text(he.validAmount), findsOneWidget);

        // An amount is typed left to right.
        final amount = find.descendant(of: find.byKey(const Key('record-cost')), matching: find.byType(EditableText));
        expect(tester.widget<EditableText>(amount).textDirection, TextDirection.ltr);

        await tester.enterText(find.byKey(const Key('record-cost')), '45,5');
        await tapVisible(tester, find.text(he.saveRecord));
        expect(find.text('רשומה חדשה'), findsNothing);
        expect(find.text('גזירת ציפורניים'), findsOneWidget);

        final saved = (await real(
          tester,
          () => h.repository.fetchRecords(kelly),
        )).firstWhere((r) => r.title == 'גזירת ציפורניים');
        expect(saved.costAmount, 45.5);
        // The amount in Hebrew: the sign after the number, kept in one piece.
        expect(
          tester
              .widget<Text>(find.descendant(of: find.byKey(ValueKey('cost-${saved.id}')), matching: find.byType(Text)))
              .data,
          HealthFormat.forLocale(hebrewLocale).money(45.5, 'ILS'),
        );

        // Delete asks first, in Hebrew.
        await tapVisible(tester, find.text('גזירת ציפורניים'));
        await tester.tap(find.byTooltip(he.editRecord));
        await tester.pumpAndSettle();
        expect(find.text(he.editRecord), findsOneWidget);
        await tester.tap(find.byTooltip(he.deleteRecord));
        await tester.pumpAndSettle();
        expect(find.text(he.deleteRecordTitle), findsOneWidget);
        expect(find.text(he.deleteRecordMessage('גזירת ציפורניים')), findsOneWidget);
        await tester.tap(find.text('מחיקה'));
        await tester.pumpAndSettle();
        expect(find.text('גזירת ציפורניים'), findsNothing);
      });

      testWidgets('an appointment ahead, a vaccination with its next due date', (tester) async {
        await openHistory(tester, size: size);
        await tapVisible(tester, find.text(he.addRecord));

        // A vaccination given today asks for the next due date.
        await tapVisible(tester, find.widgetWithText(ChoiceChip, 'חיסון'));
        expect(find.text(he.productOptional), findsOneWidget);
        expect(find.text(he.nextDueOptional), findsOneWidget);
        expect(find.text(he.notSet), findsOneWidget);
        expect(find.text(he.nextDueNote), findsOneWidget);
      });

      testWidgets('a pet without records, and the documents page of the emergency kit', (tester) async {
        await openHistory(tester, size: size);
        await selectPet(tester, 'Soya');
        expect(find.text('עדיין אין רשומות'), findsOneWidget);
        expect(find.text(he.historyEmptyNote('Soya')), findsOneWidget);
        await tapVisible(tester, find.text(he.addARecord));
        expect(find.text('רשומה חדשה'), findsOneWidget);
      });
    });
  }

  testWidgets('the documents of a pet, from its emergency kit, in Hebrew', (tester) async {
    await pumpHealth(tester, harness: hebrewHealth());
    await tester.tap(find.text('חירום'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('open-emergency-kit')));
    await tapVisible(tester, find.byKey(const Key('kit-open-documents')));

    expect(find.text(he.petsDocuments('Kelly')), findsOneWidget);
    expect(find.textContaining('Blood test results'), findsOneWidget);
    expect(find.text(he.documentsFinePrint), findsOneWidget);
  });

  testWidgets('a file that cannot be attached is refused in the language of the screen', (tester) async {
    final h = hebrewHealth();
    h.picker.pdf = PickedFile(name: 'x.gif', mimeType: 'image/gif', bytes: testPhoto().bytes);
    await openHistory(tester, harness: h);
    await tapVisible(tester, find.text('Dental cleaning'));
    await tapVisible(tester, find.byKey(const Key('detail-attach')));
    await tapVisible(tester, find.byKey(const ValueKey('attach-pdf')));
    expect(find.text(he.errFileType), findsOneWidget);
    expect(find.textContaining('Only photos'), findsNothing);
  });

  group('plural forms of the History', () {
    test('records: one, two, many', () {
      expect(he.recordsCount(1), 'רשומה אחת');
      expect(he.recordsCount(2), 'שתי רשומות');
      expect(he.recordsCount(12), '12 רשומות');
      expect(en.recordsCount(1), '1 record');
      expect(en.recordsCount(12), '12 records');
    });

    test('attachments: one, two, many', () {
      expect(he.attachmentsCount(1), 'קובץ מצורף אחד');
      expect(he.attachmentsCount(2), 'שני קבצים מצורפים');
      expect(he.attachmentsCount(3), '3 קבצים מצורפים');
      expect(en.attachmentsCount(1), '1 attachment');
      expect(en.attachmentsCount(2), '2 attachments');
    });
  });

  test('money, months and file sizes in both languages', () {
    final english = HealthFormat.forLocale(englishLocale);
    expect(english.money(320, 'ILS'), '₪320');
    expect(english.money(649.9, 'ILS'), '₪649.90');
    expect(english.fileSize(1536), '2 KB');
    expect(english.fileSize(3 * 1024 * 1024 ~/ 2), '1.5 MB');
    final hebrew = HealthFormat.forLocale(hebrewLocale);
    expect(stripBidiMarks(hebrew.money(320, 'ILS')), contains('320'));
    expect(hebrew.money(320, 'ILS'), startsWith('\u2068'));
    expect(hebrew.fileSize(3 * 1024 * 1024 ~/ 2), '\u20681.5\u2069 מ״ב');
  });
}
