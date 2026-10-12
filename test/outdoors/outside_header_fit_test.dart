import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/meetups/meetups.dart' show PartnersView;
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/widgets/coral_header.dart';

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

  /// Every text under [finder] is whole.
  void expectWhole(WidgetTester tester, Finder finder, String what) {
    final texts = find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true);
    expect(texts, findsWidgets, reason: what);
    for (final element in texts.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(paragraph.didExceedMaxLines, isFalse, reason: '$what: "${paragraph.text.toPlainText()}" is cut short');
    }
  }

  /// [finder] lies within the screen's side margins.
  void expectOnScreen(WidgetTester tester, Finder finder, String what) {
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final box = tester.getRect(finder);
    expect(box.left, greaterThanOrEqualTo(0), reason: what);
    expect(box.right, lessThanOrEqualTo(width), reason: what);
  }

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the area chip, the Partners row, the Parks row and the detail switches fit at 320 px (${language.name})', (
      tester,
    ) async {
      final hebrew = language == AppLanguage.hebrew;
      final locale = hebrew ? hebrewLocale : englishLocale;
      final outdoors = lookupOutdoorsL10n(locale);
      final meetups = lookupMeetupsL10n(locale);
      // Partners first, on the demo profile's city.
      await openOutside(
        tester,
        language: language,
        size: const Size(320, 640),
        parks: false,
        kit: ParksKit(profileArea: true),
      );
      expect(tester.takeException(), isNull);

      // The header: the title whole beside the area chip and the avatar.
      final chip = find.byKey(OutsideScreen.areaChipKey);
      expect(chip, findsOneWidget);
      expectWhole(
        tester,
        find.descendant(of: find.byType(CoralHeader), matching: find.text(outdoors.sectionOutside)),
        'the title',
      );
      expectOnScreen(tester, chip, 'the area chip');
      // Hebrew names the city whole; a long English name may be cut.
      if (hebrew) expectWhole(tester, chip, 'the area chip');

      // Partners: one row, every label whole, inside the screen.
      final row = find.byKey(PartnersView.controlRowKey);
      for (final key in [PartnersView.filtersKey, PartnersView.radiusChipKey, PartnersView.myAdsKey]) {
        expectWhole(tester, find.byKey(key), key.toString());
        expectOnScreen(tester, find.byKey(key), key.toString());
        expect(tester.getCenter(find.byKey(key)).dy, moreOrLessEquals(tester.getCenter(row).dy, epsilon: 1));
      }
      expect(find.descendant(of: row, matching: find.text(meetups.filters)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(outdoors.radiusKm(10))), findsOneWidget);
      expectWhole(tester, find.byKey(PartnersView.newAdKey), 'New ad');

      // Parks: the filters scroll sideways in one row.
      await tester.tap(find.byKey(OutsideSection.parksKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(ParksView.radiusChipKey), 'the radius chip');
      expect(find.byKey(PartnersView.newAdKey), findsNothing, reason: 'New ad floats over Partners only');

      // Suggest a park: one row per detail, the switch whole.
      await scrollTo(tester, find.byKey(ParksView.suggestKey));
      await tester.tap(find.byKey(ParksView.suggestKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final form = find.byKey(SuggestParkScreen.screenKey);
      for (final detail in ParkDetail.values) {
        final yes = find.byKey(SuggestParkScreen.answerKey(detail, ParkAnswer.yes));
        await tester.scrollUntilVisible(
          yes,
          150,
          scrollable: find.descendant(of: form, matching: find.byType(Scrollable)).first,
        );
        await tester.pumpAndSettle();
        final row = find.ancestor(of: yes, matching: find.byType(ParkDetailRow));
        expectWhole(tester, row, detail.name);
        for (final answer in ParkAnswer.values) {
          expectOnScreen(tester, find.byKey(SuggestParkScreen.answerKey(detail, answer)), '${detail.name} ${answer.name}');
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
