import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'health_test_helpers.dart';

/// Loads the app's real fonts (the widget-test font is square and much
/// wider), so this file can check what fits on a real 320 px phone.
Future<void> _loadAppFonts() async {
  Future<ByteData> read(String file) async => ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());
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

/// Every text found by [finder] is drawn whole: not cut short, and not
/// wrapped onto a second line.
void expectWhole(WidgetTester tester, Finder finder, String reason) {
  expect(finder, findsWidgets, reason: reason);
  for (final element in finder.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$reason is cut short');
    final length = paragraph.text.toPlainText().length;
    final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: length));
    final tops = [for (final box in boxes) box.top];
    final spread = tops.reduce((a, b) => a > b ? a : b) - tops.reduce((a, b) => a < b ? a : b);
    expect(spread, lessThan(6), reason: '$reason wraps');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
    final l10n = lookupHealthL10n(locale);
    final app = lookupAppL10n(locale);
    Finder text(String value) => find.text(value);

    testWidgets('the Overview and Records fit a 320 px phone (${language.name})', (tester) async {
      await pumpHealth(tester, harness: HealthHarness(language: language), size: const Size(320, 640));
      expect(tester.takeException(), isNull);

      // The switcher; adding is the tab's "+".
      for (final label in [l10n.sectionOverview, l10n.sectionSchedule, l10n.recordsSection]) {
        expectWhole(tester, text(label).first, label);
      }
      expect(find.byKey(const Key('add-fab')), findsOneWidget);

      // The rows: their titles on one line.
      await tester.ensureVisible(find.byKey(const Key('overview-records')));
      await tester.pumpAndSettle();
      expectWhole(tester, text(l10n.healthProfile), l10n.healthProfile);
      expectWhole(
        tester,
        find.descendant(of: find.byKey(const Key('overview-weight')), matching: find.byType(Text)).first,
        'the weight row',
      );

      // Records: the count line with Share.
      await openSection(tester, l10n.recordsSection);
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(const Key('history-count')), 'the count');
      expectWhole(tester, text(app.commonShare), app.commonShare);

      // The weight, and the journal with its Category chip.
      await tapVisible(tester, find.byKey(const Key('filter-weight')));
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(const Key('history-count')), 'the weigh-ins');
      await tapVisible(tester, find.byKey(const Key('filter-journal')));
      expect(tester.takeException(), isNull);
      expectWhole(tester, text(l10n.recordsCategory), l10n.recordsCategory);
      expectWhole(tester, find.byKey(const Key('history-count')), 'the entries');
      expectWhole(tester, text(app.commonShare), app.commonShare);
    });
  }
}
