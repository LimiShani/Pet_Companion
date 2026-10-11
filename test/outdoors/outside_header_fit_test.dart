import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'outdoors_test_helpers.dart';

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
  setUpOutdoorsTests();
  setUpAll(_loadAppFonts);

  // Both languages on the smallest phones.
  for (final (language, width) in [(AppLanguage.hebrew, 320.0), (AppLanguage.english, 320.0)]) {
    testWidgets('the five tabs and the Outside switch fit at ${width.toInt()} px (${language.name})', (
      tester,
    ) async {
      await openOutside(tester, language: language, size: Size(width, 640));
      expect(tester.takeException(), isNull);
      final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
      final app = lookupAppL10n(locale);
      final outdoors = lookupOutdoorsL10n(locale);
      for (final label in [
        app.navHome,
        app.navHealth,
        app.navCommunity,
        outdoors.sectionOutside,
        app.navStore,
        outdoors.outsidePartners,
        outdoors.outsideParks,
      ]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label).first);
        expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut short');
      }
    });
  }
}
