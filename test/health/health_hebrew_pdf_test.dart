import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/emergency/lost_card_view.dart';
import 'package:pet_companion/features/health/share/health_pdf.dart';
import 'package:pet_companion/features/health/share/health_report.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

// The shared PDFs in Hebrew: the summary and the record, laid out right to
// left in the app's own fonts (embedded), with every Latin name and number
// in its place and no missing letter; and the lost-pet card, which keeps
// its own language whatever the app shows.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);

/// The bundled fonts, read from the project.
Future<ByteData> fromDisk(String path) async => ByteData.sublistView(File(path).readAsBytesSync());

/// A builder whose PDF can be read back: nothing is compressed.
final readable = PdfHealthPdfBuilder(compress: false, loadFont: fromDisk);

/// One word the PDF draws: where, and its letters in the order they are
/// drawn (left to right).
class PdfWord {
  const PdfWord(this.y, this.x, this.drawn, {required this.missing});

  final double y;
  final double x;
  final String drawn;

  /// A glyph the font does not have was drawn instead of a letter.
  final bool missing;

  /// The word as it is read: a Hebrew word is drawn from its last letter.
  String get read => RegExp('[֐-׿]').hasMatch(drawn) ? String.fromCharCodes(drawn.runes.toList().reversed) : drawn;

  @override
  String toString() => '($x, $y) $read';
}

/// Every word of an uncompressed PDF made by the builder, from the fonts'
/// own maps of glyphs to letters.
List<PdfWord> wordsOf(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final unicode = <String, Map<int, int>>{};
  final fonts = RegExp(r'/Name/(F\d+)/Encoding/Identity-H/.*?/ToUnicode (\d+) 0 R', dotAll: true);
  for (final font in fonts.allMatches(text)) {
    final object = text.indexOf('\n${font.group(2)} 0 obj');
    final map = text.substring(text.indexOf('beginbfchar', object), text.indexOf('endbfchar', object));
    unicode[font.group(1)!] = {
      for (final pair in RegExp('<([0-9A-Fa-f]{4})> <([0-9A-Fa-f]{4})>').allMatches(map))
        int.parse(pair.group(1)!, radix: 16): int.parse(pair.group(2)!, radix: 16),
    };
  }
  // The page contents: the streams that show text. Each word is placed by
  // the transformations in force (q, cm, Q) and its own offset (Td).
  final words = <PdfWord>[];
  final streams = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true);
  final op = RegExp(
    r'(?<=\s|^)(q|Q)(?=\s)'
    r'|(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) cm'
    r'|BT /(F\d+) [\d.]+ Tf -?[\d.]+ Tc (-?[\d.]+) (-?[\d.]+) Td \[<([0-9A-Fa-f]*)>\]TJ ET',
  );
  var page = 0;
  for (final stream in streams.allMatches(text)) {
    final content = stream.group(1)!;
    if (!content.contains('BT /F')) continue;
    page++;
    var m = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];
    final saved = <List<double>>[];
    for (final token in op.allMatches(content)) {
      if (token.group(1) == 'q') {
        saved.add(m);
      } else if (token.group(1) == 'Q') {
        m = saved.removeLast();
      } else if (token.group(2) != null) {
        final n = [for (var i = 2; i <= 7; i++) double.parse(token.group(i)!)];
        // The new matrix is n x m.
        m = [
          n[0] * m[0] + n[1] * m[2],
          n[0] * m[1] + n[1] * m[3],
          n[2] * m[0] + n[3] * m[2],
          n[2] * m[1] + n[3] * m[3],
          n[4] * m[0] + n[5] * m[2] + m[4],
          n[4] * m[1] + n[5] * m[3] + m[5],
        ];
      } else {
        final map = unicode[token.group(8)]!;
        final tx = double.parse(token.group(9)!);
        final ty = double.parse(token.group(10)!);
        final hex = token.group(11)!;
        final glyphs = [for (var i = 0; i < hex.length; i += 4) int.parse(hex.substring(i, i + 4), radix: 16)];
        words.add(
          PdfWord(
            page * 10000 + m[1] * tx + m[3] * ty + m[5],
            m[0] * tx + m[2] * ty + m[4],
            String.fromCharCodes([for (final g in glyphs) map[g] ?? 0]),
            missing: glyphs.any((g) => g == 0 || !map.containsKey(g)),
          ),
        );
      }
    }
  }
  return words;
}

/// Checks that the words [reading] (in the order they are read) are drawn
/// on one line, each further left than the one before in a right-to-left
/// reading ([rtl]), or further right in a left-to-right one.
void expectDrawnInOrder(List<PdfWord> words, List<String> reading, {bool rtl = true}) {
  List<PdfWord> lineOf(PdfWord first) => [
    for (final w in words)
      if ((w.y - first.y).abs() < 0.5) w,
  ];
  // The line where the first word is drawn with all the others.
  final candidates = [
    for (final w in words)
      if (w.read == reading.first) lineOf(w),
  ];
  expect(candidates, isNotEmpty, reason: 'no word "${reading.first}" in $words');
  final line = candidates.firstWhere(
    (line) => reading.every((word) => line.any((w) => w.read == word)),
    orElse: () => candidates.first,
  );
  final xs = <double>[];
  for (final word in reading) {
    final found = line.where((w) => w.read == word).toList();
    expect(found, isNotEmpty, reason: '"$word" is not on the line of "${reading.first}": $line');
    xs.add(found.first.x);
  }
  for (var i = 1; i < xs.length; i++) {
    expect(
      rtl ? xs[i] < xs[i - 1] : xs[i] > xs[i - 1],
      isTrue,
      reason: '"${reading[i]}" should come after "${reading[i - 1]}" (${rtl ? 'to its left' : 'to its right'}): $line',
    );
  }
}

/// Runs [body], and returns what the pdf package printed meanwhile (it
/// prints a warning for every letter no font can draw).
Future<(T, List<String>)> printed<T>(Future<T> Function() body) async {
  final lines = <String>[];
  final result = await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));
  return (result, lines);
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('the summary PDF in Hebrew', () {
    testWidgets('is made from the Hebrew screen, in Hebrew', (tester) async {
      final h = await pumpHealth(tester, harness: hebrewHealth());
      await tapVisible(tester, find.byKey(const Key('overview-share')));

      final report = h.pdf.last;
      expect(report.rightToLeft, isTrue);
      expect(report.title, he.reportSummaryTitle('Kelly'));
      expect(stripBidiMarks(report.subtitle), 'כלב · Mix · 13.6 שנים · 23 ק״ג');
      expect(report.prepared, he.reportPreparedBy('10.06.25', 'Alex'));
      final facts = {for (final f in report.facts) f.$1: stripBidiMarks(f.$2)};
      expect(facts['שבב'], '985 112 004 567 321');
      expect(facts['אלרגיות'], 'Chicken (skin reaction)');
      expect(facts['מחלות רקע'], 'Arthritis in the hips');
      expect(facts['תרופות פעילות'], 'Joint tablets 50 mg: 1 tablet דרך הפה, twice a day with food');
      expect(facts['וטרינר קבוע'], 'Dr. Levi, Park Vet Clinic · +972 3 555 0142 · 12 Park Street, Tel Aviv');
      expect(facts['וטרינר חירום'], contains('City Animal Hospital'));
      expect(facts['איש קשר לחירום'], 'Dana (sister) · +972 50 555 0117');
      expect(report.recordsTitle, 'רשומות אחרונות');
      expect(report.columns, ['תאריך', 'סוג', 'רשומה', 'פרטים']);
      expect(report.records.first.kind, 'טיפול מונע');
      expect(stripBidiMarks(report.records.first.details), 'המועד הבא: 27.07.25');
      expect(report.footer, he.reportFooter);
      // What the owner typed, and the sample data, stays as written.
      expect(stripBidiMarks(report.records.first.title), 'Flea and tick tablet');
      // The file itself keeps a plain name and a subject without marks.
      expect(h.sharer.shared.single.name, 'kelly-health-summary.pdf');
      expect(h.sharer.shared.single.subject, 'Kelly: סיכום בריאות');
    });

    testWidgets('builds as text in the embedded fonts, right to left, with nothing missing', (tester) async {
      final h = await pumpHealth(tester, harness: hebrewHealth());
      await tapVisible(tester, find.byKey(const Key('overview-share')));
      final report = h.pdf.last;

      final (bytes, warnings) = (await tester.runAsync(() => printed(() => readable.build(report))))!;
      final pdf = latin1.decode(bytes);
      expect(pdf, startsWith('%PDF-'));
      // Text in the app's own font with the Hebrew letters, not pictures.
      expect(pdf, contains('/BaseFont/Fredoka'));
      expect(pdf, contains('/FontFile2'));
      expect(pdf, isNot(contains('/Subtype/Image')));
      // No letter fell back to a missing glyph.
      expect(warnings.where((w) => w.contains('Unable to find a font')), isEmpty);
      final words = wordsOf(bytes);
      expect(words, isNotEmpty);
      expect(words.where((w) => w.missing), isEmpty);

      // Every line reads right to left, the Latin names and the numbers in
      // their places.
      expectDrawnInOrder(words, ['Kelly', 'סיכום', 'בריאות']);
      expectDrawnInOrder(words, ['כלב', 'Mix', '13.6', 'שנים', '23', 'ק״ג']);
      expectDrawnInOrder(words, ['הוכן', 'בתאריך', '10.06.25', 'Alex', 'באפליקציית', 'Companion']);
      // A name in Latin letters reads left to right inside the line.
      expectDrawnInOrder(words, ['Pet', 'Companion'], rtl: false);
      expectDrawnInOrder(words, ['Park', 'Vet', 'Clinic'], rtl: false);
      // A phone number and a microchip number keep their groups in order.
      expectDrawnInOrder(words, ['+972', '50', '555', '0117'], rtl: false);
      expectDrawnInOrder(words, ['985', '112', '004', '567', '321'], rtl: false);
      // A label is on the right of its value, in the same row of the table
      // (a smaller size of letters, so a baseline a little higher).
      for (final (label, value) in [('שבב', '985'), ('איש', 'Dana')]) {
        final l = words.firstWhere((w) => w.read == label);
        final v = words.firstWhere((w) => w.read == value);
        expect((l.y - v.y).abs(), lessThan(6), reason: '$label and $value share a row');
        expect(l.x, greaterThan(v.x), reason: '$label is on the right of $value');
      }
    });
  });

  group('the record PDF in Hebrew', () {
    testWidgets('is made from the Hebrew record page, and builds right to left', (tester) async {
      final h = await pumpHealth(tester, harness: hebrewHealth());
      await openSection(tester, he.sectionHistory);
      await tapVisible(tester, find.text('Rabies booster'));
      await tapVisible(tester, find.byKey(const Key('record-share')));

      final report = h.pdf.last;
      expect(report.rightToLeft, isTrue);
      expect(report.title, he.reportRecordTitle('Kelly', 'Rabies booster'));
      expect(report.recordsTitle, 'רשומה');
      expect(report.records.single.kind, 'חיסון');
      expect(stripBidiMarks(report.records.single.details), contains('המועד הבא: 14.03.26'));
      expect(h.sharer.shared.single.name, 'kelly-rabies-booster.pdf');

      final (bytes, warnings) = (await tester.runAsync(() => printed(() => readable.build(report))))!;
      expect(warnings.where((w) => w.contains('Unable to find a font')), isEmpty);
      final words = wordsOf(bytes);
      expect(words.where((w) => w.missing), isEmpty);
      expectDrawnInOrder(words, ['Kelly', 'booster']);
      expectDrawnInOrder(words, ['Rabies', 'booster'], rtl: false);
      // The table starts on the right: the date first, then the kind.
      final date = words.firstWhere((w) => w.read == '14.03.25');
      final kind = words.firstWhere((w) => w.read == 'חיסון');
      final title = words.firstWhere((w) => w.read == 'Rabies' && (w.y - date.y).abs() < 0.5);
      expect(date.x, greaterThan(kind.x));
      expect(kind.x, greaterThan(title.x));
      // Its headings, in the same order.
      final headDate = words.firstWhere((w) => w.read == 'תאריך');
      final headKind = words.firstWhere((w) => w.read == 'סוג');
      expect(headDate.x, greaterThan(headKind.x));
    });
  });

  test('a record whose owner typed Hebrew into an English report falls back to pictures', () async {
    // The English report has only Nunito, which has no Hebrew letters.
    const report = HealthReport(
      title: 'Kelly: חיסון כלבת',
      subtitle: 'Dog',
      prepared: 'Prepared on 10.06.25 with Pet Companion',
      fileName: 'kelly.pdf',
    );
    final fonts = await HealthPdfFonts.load(fromDisk);
    expect(fonts.nunitoCovers(report.allText.join('\n')), isFalse);
    expect(fonts.fredokaCovers(report.allText.join('\n')), isTrue);
  });

  test('the pieces of a line are cut at the direction marks, which are left out', () {
    expect(pdfPieces('ירידה של \u2068\u20680.2\u2069 ק״ג\u2069 מאז \u206802.05.25\u2069'), [
      'ירידה של ',
      '0.2',
      ' ק״ג',
      ' מאז ',
      '02.05.25',
    ]);
    expect(pdfPieces('\u2066+972 3 555 0142\u2069'), ['+972 3 555 0142']);
    expect(pdfPieces('\u2068\u200F320 \u200F₪\u2069'), ['320 ₪']);
    expect(pdfPieces('Plain English'), ['Plain English']);
  });

  group('the lost-pet card keeps its own language', () {
    test('its words come from the strings of the chosen language', () {
      final hebrew = LostCardWords.of(LostCardLanguage.hebrew);
      final english = LostCardWords.of(LostCardLanguage.english);
      expect(hebrew.rightToLeft, isTrue);
      expect(hebrew.heading('Kelly'), he.lostCardHeading('Kelly'));
      expect(stripBidiMarks(hebrew.heading('Kelly')), 'מחפשים את Kelly');
      expect(stripBidiMarks(hebrew.call('Kelly')), 'ראיתם את Kelly? התקשרו');
      expect(hebrew.footer, 'הוכן באפליקציית Pet Companion');
      expect(english.rightToLeft, isFalse);
      expect(english.heading('Kelly'), 'Looking for Kelly');
      expect(english.call('Kelly'), 'Seen Kelly? Please call');
      expect(english.around('10.06.25', '16:30'), '10.06.25, around 16:30');
      expect(lostCardLanguageName(LostCardLanguage.hebrew), 'עברית');
      expect(lostCardLanguageName(LostCardLanguage.english), 'English');
    });

    for (final size in [widePhone, smallPhone]) {
      final width = size.width.toInt();

      testWidgets(
        'the page in Hebrew, a Hebrew card by default, and an English card on an English choice ($width px)',
        (tester) async {
          final h = await pumpHealth(tester, harness: hebrewHealth(), size: size);
          await tester.tap(find.text('חירום'));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.byKey(const Key('open-lost-card')));

          // The page speaks the app's language.
          expect(find.text(he.petIsLost('Kelly')), findsWidgets);
          expect(find.text(he.lostCardSection), findsOneWidget);
          expect(find.text(he.lostDescription), findsOneWidget);
          expect(find.text(he.lostArea), findsOneWidget);
          expect(find.text(he.lostAreaHint), findsOneWidget);
          expect(find.text(he.lostWhen), findsOneWidget);
          expect(find.text(he.lostYourPhone), findsOneWidget);
          expect(find.text(he.lostLanguage), findsOneWidget);
          expect(find.text('עברית'), findsOneWidget);
          expect(find.text('English'), findsOneWidget);
          expect(find.text(he.lostAddPhoneFirst), findsOneWidget);
          expect(find.text(he.shareAsImage), findsOneWidget);
          expect(find.text(he.lostFinePrint), findsOneWidget);

          // The card: Hebrew by default, right to left.
          final card = find.byKey(const Key('lost-card-preview'));
          Finder onCard(String text) => find.descendant(of: card, matching: find.text(text));
          expect(onCard(he.lostCardHeading('Kelly')), findsOneWidget);
          expect(directionOf(tester, onCard(he.lostCardHeading('Kelly'))), TextDirection.rtl);
          expect(onCard('הוכן באפליקציית Pet Companion'), findsOneWidget);

          await tester.enterText(find.byKey(const Key('lost-area')), 'פארק הירקון');
          await tester.enterText(find.byKey(const Key('lost-phone')), '050 123 4567');
          await tester.pumpAndSettle();
          expect(find.text(he.lostShowPhone(ltr('050 123 4567'))), findsOneWidget);
          await tapVisible(tester, find.byKey(const Key('lost-confirm-phone')));
          expect(onCard(he.lostCardCall('Kelly')), findsOneWidget);
          expect(onCard('050 123 4567'), findsOneWidget);
          expect(onCard('אזור'), findsOneWidget);
          expect(onCard('פארק הירקון'), findsOneWidget);

          // An English card on a Hebrew screen: the card follows its own choice.
          await tapVisible(tester, find.byKey(const ValueKey('lost-language-en')));
          expect(onCard('Looking for Kelly'), findsOneWidget);
          expect(onCard('Seen Kelly? Please call'), findsOneWidget);
          expect(onCard('Area'), findsOneWidget);
          expect(directionOf(tester, onCard('Looking for Kelly')), TextDirection.ltr);
          // The page itself is still in Hebrew.
          expect(find.text(he.lostLanguage), findsOneWidget);

          // Sharing: the file's title has no invisible marks.
          await tapVisible(tester, find.byKey(const Key('lost-share-pdf')));
          expect(h.cardRenderer.pdfTitles.single, 'Looking for Kelly');
        },
      );
    }

    testWidgetsInBothLanguages('the card is Hebrew by default in either language of the app', (tester, language) async {
      final h = HealthHarness(language: language);
      await pumpHealth(tester, harness: h);
      await tester.tap(find.text(h.l10n.emergencyButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('open-lost-card')));
      final card = find.byKey(const Key('lost-card-preview'));
      expect(find.descendant(of: card, matching: find.text(he.lostCardHeading('Kelly'))), findsOneWidget);
      expect(find.text(h.l10n.lostCardSection), findsOneWidget);
    });
  });
}
