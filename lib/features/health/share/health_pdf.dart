import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../l10n/bidi.dart';
import '../../../services/pet_records/data/health_models.dart';
import 'health_report.dart';

/// Turns a [HealthReport] into the bytes of a PDF file. Behind an interface
/// so tests can look at the report instead of parsing a PDF.
///
/// Throws a [HealthException] when the file cannot be produced.
abstract class HealthPdfBuilder {
  Future<Uint8List> build(HealthReport report);
}

final healthPdfBuilderProvider = Provider<HealthPdfBuilder>(
  (ref) => PdfHealthPdfBuilder(),
);

/// Punctuation that phones type by themselves, as plain characters every
/// font has.
String plainPunctuation(String text) => text
    .replaceAll(RegExp('[‘’‚′]'), "'")
    .replaceAll(RegExp('[“”„″]'), '"')
    .replaceAll(RegExp('[‐-―]'), '-')
    .replaceAll('…', '...')
    .replaceAll('•', '·')
    .replaceAll(RegExp('[ -  ]'), ' ');

/// [text] cut into the pieces the PDF lays out one after the other: the
/// app's strings keep a name, a number or anything typed in one piece
/// between invisible direction marks (U+2066 to U+2069), and each piece is
/// laid out in its own direction. The marks themselves are left out, as
/// are the other invisible direction marks: the fonts do not draw them.
List<String> pdfPieces(String text) => [
  for (final piece in text.split(RegExp('[\u2066-\u2069]')))
    if (piece.replaceAll(RegExp('[\u200E\u200F\u202A-\u202E]'), '').isNotEmpty)
      piece.replaceAll(RegExp('[\u200E\u200F\u202A-\u202E]'), ''),
];

/// The app's bundled fonts, embedded in the PDF: Nunito for Latin letters
/// (an English report) and Fredoka, which also has the Hebrew letters (a
/// Hebrew report).
class HealthPdfFonts {
  HealthPdfFonts({
    required this.nunito,
    required this.nunitoBold,
    required this.fredoka,
    required this.fredokaBold,
  }) : _nunitoChars = TtfParser(nunito).charToGlyphIndexMap.keys.toSet(),
       _fredokaChars = TtfParser(fredoka).charToGlyphIndexMap.keys.toSet();

  final ByteData nunito;
  final ByteData nunitoBold;
  final ByteData fredoka;
  final ByteData fredokaBold;
  final Set<int> _nunitoChars;
  final Set<int> _fredokaChars;

  static const _files = (
    nunito: 'assets/fonts/Nunito-Regular.ttf',
    nunitoBold: 'assets/fonts/Nunito-Bold.ttf',
    fredoka: 'assets/fonts/Fredoka-Regular.ttf',
    fredokaBold: 'assets/fonts/Fredoka-Bold.ttf',
  );

  /// Loads the four font files with [load] (the app's asset bundle unless
  /// given).
  static Future<HealthPdfFonts> load([
    Future<ByteData> Function(String path)? load,
  ]) async {
    final read = load ?? rootBundle.load;
    final files = await Future.wait([
      read(_files.nunito),
      read(_files.nunitoBold),
      read(_files.fredoka),
      read(_files.fredokaBold),
    ]);
    return HealthPdfFonts(
      nunito: files[0],
      nunitoBold: files[1],
      fredoka: files[2],
      fredokaBold: files[3],
    );
  }

  static bool _covers(Set<int> chars, String text) => pdfPieces(text)
      .join()
      .runes
      .every((rune) => rune == 0x0A || rune == 0x20 || chars.contains(rune));

  /// Whether Fredoka, the font of a right-to-left report, draws all of [text].
  bool fredokaCovers(String text) => _covers(_fredokaChars, text);

  /// Whether Nunito, the font of a left-to-right report, draws all of [text].
  bool nunitoCovers(String text) => _covers(_nunitoChars, text);
}

/// [HealthPdfBuilder] on the `pdf` package.
///
/// The report is a text PDF with the app's own fonts embedded: Nunito for
/// an English report, Fredoka for a Hebrew one, laid out right to left
/// with every name and number in its place. Text that the embedded font
/// cannot draw (an emoji, another script typed by the owner) is instead
/// drawn with the phone's own fonts onto pages that are placed in the PDF
/// as pictures, so every name still reads correctly.
class PdfHealthPdfBuilder implements HealthPdfBuilder {
  PdfHealthPdfBuilder({
    this.compress = true,
    Future<ByteData> Function(String path)? loadFont,
  }) : _loadFont = loadFont;

  /// Whether the PDF's content is compressed; tests read it when not.
  final bool compress;
  final Future<ByteData> Function(String path)? _loadFont;

  static Future<HealthPdfFonts>? _bundled;

  Future<HealthPdfFonts> _fonts() {
    final load = _loadFont;
    if (load != null) return HealthPdfFonts.load(load);
    return _bundled ??= HealthPdfFonts.load()..ignore();
  }

  static const _ink = PdfColor.fromInt(0xFF4A3829);
  static const _muted = PdfColor.fromInt(0xFF5B4636);
  static const _line = PdfColor.fromInt(0xFFE7D9B5);
  static const _accent = PdfColor.fromInt(0xFFFFE6B0);

  @override
  Future<Uint8List> build(HealthReport report) async {
    try {
      final text = _plain(report);
      final fonts = await _fonts();
      final all = text.allText.join('\n');
      final fits = report.rightToLeft
          ? fonts.fredokaCovers(all)
          : fonts.nunitoCovers(all);
      return fits ? await _textPdf(text, fonts) : await _picturePdf(text);
    } on HealthException {
      rethrow;
    } catch (_) {
      _bundled = null;
      throw HealthException.of(HealthFailure.pdf);
    }
  }

  HealthReport _plain(HealthReport r) => HealthReport(
    title: plainPunctuation(r.title),
    subtitle: plainPunctuation(r.subtitle),
    prepared: plainPunctuation(r.prepared),
    fileName: r.fileName,
    facts: [
      for (final f in r.facts) (plainPunctuation(f.$1), plainPunctuation(f.$2)),
    ],
    recordsTitle: plainPunctuation(r.recordsTitle),
    records: [
      for (final row in r.records)
        HealthReportRow(
          date: plainPunctuation(row.date),
          kind: plainPunctuation(row.kind),
          title: plainPunctuation(row.title),
          details: plainPunctuation(row.details),
        ),
    ],
    footer: plainPunctuation(r.footer),
    columns: [for (final c in r.columns) plainPunctuation(c)],
    rightToLeft: r.rightToLeft,
  );

  // ------------------------------------------------------------- text PDF

  /// One block of text, in the pieces of [pdfPieces], starting where the
  /// report's lines start.
  static pw.Widget _text(String text, pw.TextStyle style) => pw.RichText(
    textAlign: pw.TextAlign.start,
    text: pw.TextSpan(
      style: style,
      children: [for (final piece in pdfPieces(text)) pw.TextSpan(text: piece)],
    ),
  );

  Future<Uint8List> _textPdf(HealthReport report, HealthPdfFonts fonts) {
    final rtl = report.rightToLeft;
    final doc = pw.Document(
      title: stripBidiMarks(report.title),
      creator: 'PetLoop',
      compress: compress,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(rtl ? fonts.fredoka : fonts.nunito),
        bold: pw.Font.ttf(rtl ? fonts.fredokaBold : fonts.nunitoBold),
      ),
    );
    final small = pw.TextStyle(fontSize: 9, color: _muted);
    final start = rtl ? pw.Alignment.topRight : pw.Alignment.topLeft;

    /// A table cell: its text from the start of the cell.
    pw.Widget cell(String text, pw.TextStyle style) => pw.Container(
      alignment: start,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
      child: _text(text, style),
    );

    /// [cells] from the start of the line: the first on the right in a
    /// right-to-left report.
    List<pw.Widget> row(List<pw.Widget> cells) =>
        rtl ? cells.reversed.toList() : cells;
    Map<int, pw.TableColumnWidth> widths(List<pw.TableColumnWidth> columns) {
      final ordered = rtl ? columns.reversed.toList() : columns;
      return {for (var i = 0; i < ordered.length; i++) i: ordered[i]};
    }

    final factStyle = pw.TextStyle(fontSize: 11, color: _ink);
    final labelStyle = pw.TextStyle(fontSize: 10, color: _muted);
    final cellStyle = pw.TextStyle(fontSize: 10, color: _ink);
    final headStyle = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    );
    const border = pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _line, width: 0.5),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _text(report.footer, small)),
              pw.SizedBox(width: 12),
              // Page numbers read left to right in every language.
              pw.Directionality(
                textDirection: pw.TextDirection.ltr,
                child: pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: small,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          _text(
            report.title,
            pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 4),
          _text(report.subtitle, pw.TextStyle(fontSize: 12, color: _ink)),
          pw.SizedBox(height: 2),
          _text(report.prepared, small),
          pw.SizedBox(height: 14),
          if (report.facts.isNotEmpty)
            pw.Table(
              border: border,
              columnWidths: widths(const [
                pw.FixedColumnWidth(120),
                pw.FlexColumnWidth(),
              ]),
              children: [
                for (final fact in report.facts)
                  pw.TableRow(
                    children: row([
                      cell(fact.$1, labelStyle),
                      cell(fact.$2, factStyle),
                    ]),
                  ),
              ],
            ),
          if (report.records.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _text(
              report.recordsTitle,
              pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: border,
              columnWidths: widths(const [
                pw.FixedColumnWidth(58),
                pw.FixedColumnWidth(72),
                pw.FlexColumnWidth(2),
                pw.FlexColumnWidth(3),
              ]),
              children: [
                if (report.columns.isNotEmpty)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _accent),
                    children: row([
                      for (final heading in report.columns)
                        cell(heading, headStyle),
                    ]),
                  ),
                for (final record in report.records)
                  pw.TableRow(
                    children: row([
                      cell(record.date, cellStyle),
                      cell(record.kind, cellStyle),
                      cell(record.title, cellStyle),
                      cell(record.details, cellStyle),
                    ]),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------- picture PDF

  static const _pageWidth = 595.0;
  static const _pageHeight = 842.0;
  static const _margin = 40.0;

  /// Pixels per PDF point: sharp enough to read and to print.
  static const _scale = 2.0;

  static const _inkColor = ui.Color(0xFF4A3829);
  static const _mutedColor = ui.Color(0xFF5B4636);

  static bool _startsRightToLeft(String text) {
    for (final rune in stripBidiMarks(text).runes) {
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return true;
      }
      if ((rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A) ||
          rune >= 0xC0) {
        return false;
      }
    }
    return false;
  }

  Future<Uint8List> _picturePdf(HealthReport report) async {
    const width = _pageWidth - _margin * 2;
    TextPainter block(
      String text, {
      double size = 11,
      bool bold = false,
      ui.Color color = _inkColor,
    }) {
      // The report's own direction; a block of another language keeps its
      // own. Flutter lays out the direction marks of the strings itself.
      final rtl = report.rightToLeft || _startsRightToLeft(text);
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontFamilyFallback: const ['Fredoka'],
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
            height: 1.3,
          ),
        ),
        textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        textAlign: TextAlign.start,
      )..layout(minWidth: width, maxWidth: width);
    }

    String line(List<String> parts) =>
        parts.where((p) => p.isNotEmpty).join(' · ');

    // Every block with the gap above it.
    final blocks = <(double, TextPainter)>[
      (0, block(report.title, size: 22, bold: true)),
      (4, block(report.subtitle, size: 12)),
      (2, block(report.prepared, size: 9, color: _mutedColor)),
      for (var i = 0; i < report.facts.length; i++) ...[
        (
          i == 0 ? 16.0 : 8.0,
          block(report.facts[i].$1, size: 10, color: _mutedColor),
        ),
        (1, block(report.facts[i].$2)),
      ],
      if (report.records.isNotEmpty)
        (20, block(report.recordsTitle, size: 14, bold: true)),
      for (final row in report.records) ...[
        (
          10,
          block(
            line([row.date, isolate(row.kind)]),
            size: 10,
            color: _mutedColor,
          ),
        ),
        (1, block(row.title, bold: true)),
        if (row.details.isNotEmpty) (1, block(row.details, size: 10)),
      ],
      (24, block(report.footer, size: 9, color: _mutedColor)),
    ];

    // Blocks are never split; a new page starts when one does not fit.
    final pages = <List<(double, TextPainter)>>[[]];
    var y = _margin;
    for (final (gap, painter) in blocks) {
      var top = pages.last.isEmpty ? y : y + gap;
      if (pages.last.isNotEmpty &&
          top + painter.height > _pageHeight - _margin) {
        pages.add([]);
        top = _margin;
      }
      pages.last.add((top, painter));
      y = top + painter.height;
    }

    final doc = pw.Document(
      title: report.fileName,
      creator: 'PetLoop',
      compress: compress,
    );
    for (final page in pages) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(_scale);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, _pageWidth, _pageHeight),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      for (final (top, painter) in page) {
        painter.paint(canvas, ui.Offset(_margin, top));
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        (_pageWidth * _scale).round(),
        (_pageHeight * _scale).round(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      if (png == null) throw HealthException.of(HealthFailure.pdf);
      final bytes = png.buffer.asUint8List(
        png.offsetInBytes,
        png.lengthInBytes,
      );
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) =>
              pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        ),
      );
    }
    for (final (_, painter) in blocks) {
      painter.dispose();
    }
    return doc.save();
  }
}
