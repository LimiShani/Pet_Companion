import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/meetups/meetups.dart';
import 'package:pet_companion/features/outdoors/outdoors.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'meetups_test_helpers.dart';

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

/// Every text under [finder] is whole and inside the screen.
void expectWhole(WidgetTester tester, Finder finder, String what) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final texts = find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true);
  expect(texts, findsWidgets, reason: what);
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$what: "${paragraph.text.toPlainText()}" is cut short');
  }
  final box = tester.getRect(finder);
  expect(box.left, greaterThanOrEqualTo(0), reason: what);
  expect(box.right, lessThanOrEqualTo(width), reason: what);
}

void main() {
  setUpMeetupsTests();
  setUpAll(_loadAppFonts);

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('320 px (${language.name}): the going-out card, the hazard line, a going-now ad and the sheet', (
      tester,
    ) async {
      final kit = MeetupsKit(
        repo: FakeMeetupsRepository(latency: Duration.zero, now: clock, viewerId: () => 'demo', goingNowSample: true),
        hazards: FakeHazardsRepository(latency: Duration.zero, now: clock),
        favorites: {'demo-raanana-park', 'demo-raanana-ahuza'},
        profileCity: "Ra'anana",
      );
      await openPartners(tester, kit: kit, language: language, size: const Size(320, 1800));
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(GoingOutCard.cardKey), 'the going-out card');
      expectWhole(tester, find.byKey(HazardLine.lineKey), 'the hazard line');
      expectWhole(tester, find.byKey(MeetupCard.goingTagKey('demo-meetup-now')), 'the "in 25 min" tag');
      expectWhole(tester, find.byKey(MeetupCard.joinKey('demo-meetup-now')), 'I want to join');

      await tapOn(tester, find.byKey(GoingOutCard.buttonKey));
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(GoingNowSheet.postKey), 'the post button');
      for (final minutes in MeetupLimits.nowLeaveOptions) {
        expectWhole(tester, find.byKey(GoingNowSheet.leaveKey(minutes)), '$minutes min');
      }
      expectWhole(tester, find.byKey(GoingNowSheet.otherParkKey), 'another park');
    });
  }
}
