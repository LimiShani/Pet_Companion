import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/household/household.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'household_test_helpers.dart';

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
  setUpHouseholdTests();
  setUpAll(_loadAppFonts);

  const small = Size(320, 640);

  /// Every text under [finder] is whole and within the screen.
  void expectWhole(WidgetTester tester, Finder finder, String what) {
    final texts = find.descendant(
      of: finder,
      matching: find.byType(RichText),
      matchRoot: true,
    );
    expect(texts, findsWidgets, reason: what);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final element in texts.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$what: "${paragraph.text.toPlainText()}" is cut short',
      );
      final box = paragraph.localToGlobal(Offset.zero) & paragraph.size;
      expect(
        box.left,
        greaterThanOrEqualTo(-0.5),
        reason: '$what: "${paragraph.text.toPlainText()}"',
      );
      expect(
        box.right,
        lessThanOrEqualTo(width + 0.5),
        reason: '$what: "${paragraph.text.toPlainText()}"',
      );
    }
  }

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets(
      'the Household page, the invite sheet and the join card fit at 320 px (${language.name})',
      (tester) async {
        await pumpHouseholdHome(tester, language: language, size: small);
        await openHouseholdPage(tester, language);
        expect(tester.takeException(), isNull);
        expectWhole(
          tester,
          find.byKey(HouseholdScreen.screenKey),
          'Household page',
        );

        await tester.tap(find.byKey(HouseholdScreen.inviteKey));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expectWhole(tester, find.byType(InviteSheet), 'Invite sheet');
        await tester.tapAt(const Offset(10, 10));
        await settle(tester);

        await tester.ensureVisible(find.byKey(HouseholdScreen.haveCodeKey));
        await tester.tap(find.byKey(HouseholdScreen.haveCodeKey));
        await settle(tester);
        await tester.enterText(
          find.byKey(JoinHouseholdScreen.codeFieldKey),
          FakeHouseholdRepository.demoJoinCode,
        );
        await tester.tap(find.byKey(JoinHouseholdScreen.continueKey));
        await settle(tester);
        expect(tester.takeException(), isNull);
        expectWhole(
          tester,
          find.byKey(JoinHouseholdScreen.screenKey),
          'Join card',
        );
      },
    );
  }
}
