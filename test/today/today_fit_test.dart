import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/today/today_card.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import '../helpers.dart';

/// Loads the app's real fonts (the widget-test font is square and much
/// wider), so this file can check what fits on a real 320 px phone.
Future<void> _loadAppFonts() async {
  Future<ByteData> read(String file) async =>
      ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());
  final nunito = FontLoader(AppFonts.latin);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    nunito.addFont(read('Nunito-$weight.ttf'));
  }
  final fredoka = FontLoader(AppFonts.hebrew);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    fredoka.addFont(read('Fredoka-$weight.ttf'));
  }
  await nunito.load();
  await fredoka.load();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  // The sample day, in the afternoon: rows of both pets, to do and done,
  // undated rows (runs out, first 30 days, essentials).
  final afternoon = DateTime(2025, 6, 10, 15);

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the Today card fits at 320 px (${language.name})', (tester) async {
      await pumpApp(tester, language: language, now: afternoon, size: const Size(320, 640));
      await signInAsDemo(tester);
      expect(tester.takeException(), isNull);
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

      final card = find.byKey(TodayCard.cardKey);
      expect(card, findsOneWidget);
      // Every text whole, every row inside the screen and at least 48 px.
      final rows = find.descendant(of: card, matching: find.byType(TodayRow));
      expect(rows.evaluate().length, greaterThanOrEqualTo(8));
      for (final element in rows.evaluate()) {
        final row = find.byWidget(element.widget);
        await Scrollable.ensureVisible(element, alignment: 0.5);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final box = tester.getRect(row);
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(width));
        expect(box.height, greaterThanOrEqualTo(48));
        for (final text in find.descendant(of: row, matching: find.byType(RichText)).evaluate()) {
          final paragraph = text.renderObject! as RenderParagraph;
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '"${paragraph.text.toPlainText()}" is cut short (${language.name})',
          );
        }
      }
      // The title and the date line: whole, beside or under each other.
      final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
      final l10n = lookupTodayL10n(locale);
      final title = find.descendant(of: card, matching: find.text(l10n.title));
      await Scrollable.ensureVisible(tester.element(title), alignment: 0.5);
      await tester.pumpAndSettle();
      for (final text in find.descendant(of: card, matching: find.byType(RichText)).evaluate()) {
        final paragraph = text.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse, reason: paragraph.text.toPlainText());
      }
    });
  }
}
