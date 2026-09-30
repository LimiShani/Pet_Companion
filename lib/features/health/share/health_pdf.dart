import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/health_models.dart';
import 'health_report.dart';

/// Turns a [HealthReport] into the bytes of a PDF file. Behind an interface
/// so tests can look at the report instead of parsing a PDF.
///
/// Throws a [HealthException] when the file cannot be produced.
abstract class HealthPdfBuilder {
  Future<Uint8List> build(HealthReport report);
}

final healthPdfBuilderProvider = Provider<HealthPdfBuilder>((ref) => const PdfHealthPdfBuilder());

/// Punctuation that phones type by themselves, as plain characters the
/// PDF's built-in font has.
String plainPunctuation(String text) => text
    .replaceAll(RegExp('[‘’‚′]'), "'")
    .replaceAll(RegExp('[“”„″]'), '"')
    .replaceAll(RegExp('[‐-―]'), '-')
    .replaceAll('…', '...')
    .replaceAll('•', '·')
    .replaceAll(RegExp('[ -  ]'), ' ');

/// Whether the PDF's built-in font can draw every character of [text].
bool fitsBuiltInFont(String text) => text.runes.every((rune) => rune == 0x0A || (rune >= 0x20 && rune <= 0xFF));

/// [HealthPdfBuilder] on the `pdf` package.
///
/// The package's built-in fonts only cover western European letters. A
/// report written with those is a normal text PDF. Anything else (Hebrew,
/// Arabic, Cyrillic, emoji...) is drawn with the phone's own fonts onto
/// pages that are placed in the PDF as pictures, so every name still reads
/// correctly.
class PdfHealthPdfBuilder implements HealthPdfBuilder {
  const PdfHealthPdfBuilder();

  static const _ink = PdfColor.fromInt(0xFF3B2A1A);
  static const _muted = PdfColor.fromInt(0xFF7A5B3A);
  static const _line = PdfColor.fromInt(0xFFE7D9B5);
  static const _accent = PdfColor.fromInt(0xFFFFE9A8);

  @override
  Future<Uint8List> build(HealthReport report) async {
    try {
      final text = _plain(report);
      return fitsBuiltInFont(text.allText.join('\n')) ? await _textPdf(text) : await _picturePdf(text);
    } on HealthException {
      rethrow;
    } catch (_) {
      throw const HealthException('Could not prepare the PDF. Please try again.');
    }
  }

  HealthReport _plain(HealthReport r) => HealthReport(
    title: plainPunctuation(r.title),
    subtitle: plainPunctuation(r.subtitle),
    prepared: plainPunctuation(r.prepared),
    fileName: r.fileName,
    facts: [for (final f in r.facts) (plainPunctuation(f.$1), plainPunctuation(f.$2))],
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
  );

  // ------------------------------------------------------------- text PDF

  Future<Uint8List> _textPdf(HealthReport report) {
    final doc = pw.Document(title: report.title, creator: 'Pet Companion');
    final small = pw.TextStyle(fontSize: 9, color: _muted);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Text(report.footer, style: small)),
              pw.SizedBox(width: 12),
              pw.Text('${context.pageNumber} / ${context.pagesCount}', style: small),
            ],
          ),
        ),
        build: (context) => [
          pw.Text(
            report.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 4),
          pw.Text(report.subtitle, style: pw.TextStyle(fontSize: 12, color: _ink)),
          pw.SizedBox(height: 2),
          pw.Text(report.prepared, style: small),
          pw.SizedBox(height: 14),
          if (report.facts.isNotEmpty)
            pw.Table(
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              columnWidths: const {0: pw.FixedColumnWidth(120), 1: pw.FlexColumnWidth()},
              children: [
                for (final fact in report.facts)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        child: pw.Text(fact.$1, style: pw.TextStyle(fontSize: 10, color: _muted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 5),
                        child: pw.Text(fact.$2, style: pw.TextStyle(fontSize: 11, color: _ink)),
                      ),
                    ],
                  ),
              ],
            ),
          if (report.records.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              report.recordsTitle,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: const ['Date', 'Kind', 'Record', 'Details'],
              data: [
                for (final row in report.records) [row.date, row.kind, row.title, row.details],
              ],
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.topLeft,
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink),
              headerDecoration: const pw.BoxDecoration(color: _accent),
              cellStyle: pw.TextStyle(fontSize: 10, color: _ink),
              columnWidths: const {
                0: pw.FixedColumnWidth(58),
                1: pw.FixedColumnWidth(72),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(3),
              },
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

  static const _inkColor = ui.Color(0xFF3B2A1A);
  static const _mutedColor = ui.Color(0xFF7A5B3A);

  static bool _startsRightToLeft(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return true;
      }
      if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A) || rune >= 0xC0) return false;
    }
    return false;
  }

  Future<Uint8List> _picturePdf(HealthReport report) async {
    const width = _pageWidth - _margin * 2;
    TextPainter block(String text, {double size = 11, bool bold = false, ui.Color color = _inkColor}) {
      final rtl = _startsRightToLeft(text);
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
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

    // Every block with the gap above it.
    final blocks = <(double, TextPainter)>[
      (0, block(report.title, size: 22, bold: true)),
      (4, block(report.subtitle, size: 12)),
      (2, block(report.prepared, size: 9, color: _mutedColor)),
      for (var i = 0; i < report.facts.length; i++) ...[
        (i == 0 ? 16.0 : 8.0, block(report.facts[i].$1, size: 10, color: _mutedColor)),
        (1, block(report.facts[i].$2)),
      ],
      if (report.records.isNotEmpty) (20, block(report.recordsTitle, size: 14, bold: true)),
      for (final row in report.records) ...[
        (10, block('${row.date} · ${row.kind}', size: 10, color: _mutedColor)),
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
      if (pages.last.isNotEmpty && top + painter.height > _pageHeight - _margin) {
        pages.add([]);
        top = _margin;
      }
      pages.last.add((top, painter));
      y = top + painter.height;
    }

    final doc = pw.Document(title: report.fileName, creator: 'Pet Companion');
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
      final image = await picture.toImage((_pageWidth * _scale).round(), (_pageHeight * _scale).round());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      image.dispose();
      if (png == null) throw const HealthException('Could not prepare the PDF. Please try again.');
      final bytes = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        ),
      );
    }
    for (final (_, painter) in blocks) {
      painter.dispose();
    }
    return doc.save();
  }
}
