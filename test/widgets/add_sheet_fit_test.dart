import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/theme/app_theme.dart';
import 'package:pet_companion/widgets/add_sheet.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';

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

/// Every text under [finder] is whole.
void _expectWhole(WidgetTester tester, Finder finder, String what) {
  final texts = find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true);
  expect(texts, findsWidgets, reason: what);
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$what: "${paragraph.text.toPlainText()}" is cut short');
  }
}

/// [finder] lies within the screen.
void _expectOnScreen(WidgetTester tester, Finder finder, String what) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final box = tester.getRect(finder);
  expect(box.left, greaterThanOrEqualTo(0), reason: what);
  expect(box.right, lessThanOrEqualTo(width), reason: what);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the bottom bar and every Add sheet fit at 320 px (${language.name})', (tester) async {
      await pumpApp(tester, language: language, size: const Size(320, 640));
      await signInAsDemo(tester);
      expect(tester.takeException(), isNull);
      final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
      final app = lookupAppL10n(locale);
      final outdoors = lookupOutdoorsL10n(locale);

      // The five tabs, each label whole, the selected pill inside its slot.
      final nav = find.byType(AppBottomNav);
      _expectWhole(tester, nav, 'the bottom bar');
      _expectOnScreen(tester, find.byKey(AppBottomNav.selectedPillKey), 'the selected pill');

      for (final (tab, title) in [
        (app.navHealth, lookupHealthL10n(locale).addToHealth),
        (app.navCommunity, lookupCommunityL10n(locale).addToCommunity),
        (outdoors.sectionOutside, outdoors.addToOutside),
        (app.navStore, lookupStoreL10n(locale).addToStore),
      ]) {
        await tester.tap(find.descendant(of: nav, matching: find.text(tab)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        _expectWhole(tester, nav, 'the bottom bar on $tab');
        _expectOnScreen(tester, find.byKey(AddFab.fabKey), 'the "+" on $tab');

        await tester.tap(find.byKey(AddFab.fabKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        final sheet = find.byKey(AddSheet.sheetKey);
        expect(find.descendant(of: sheet, matching: find.text(title)), findsOneWidget, reason: tab);
        // Every label and line whole; the title and the quieter lines on
        // one line each (a long label may take two at 320 px).
        _expectWhole(tester, sheet, 'the $tab sheet');
        for (final element in find
            .descendant(of: sheet, matching: find.byType(RichText))
            .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          if (paragraph.text.style?.fontSize == AppText.rowTitle.fontSize) continue;
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width + 0.5);
          expect(
            painter.computeLineMetrics().length,
            1,
            reason: '"${paragraph.text.toPlainText()}" wraps on $tab',
          );
          painter.dispose();
        }
        Navigator.of(tester.element(sheet)).pop();
        await tester.pumpAndSettle();
      }
    });
  }
}
