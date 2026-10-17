import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/features/community/feed/places_group.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'community_helpers.dart';

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
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUpAll(_loadAppFonts);

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('320 px (${language.name}): the places in search and the composer\'s chip and place', (tester) async {
      final harness = CommunityHarness(appLanguage: language);
      await tester.runAsync(
        () => harness.feed.createPost(
          author: const AppUser(id: 'u-sam', email: 'sam@example.test', displayName: 'Sam'),
          text: 'Gentle vet',
          kind: PostKind.recommendation,
          localityCode: 'petah-tikva',
          placeName: "Dr. Levi's clinic for older dogs",
        ),
      );
      await pumpCommunity(tester, harness: harness, size: const Size(320, 1400));
      await searchFor(tester, 'vet');
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(PlacesGroup.placeKey(0)), 'the place row');

      await closeSearch(tester);
      await tester.tap(find.byKey(const Key('add-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-post-recommendation')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectWhole(tester, find.byKey(const ValueKey('compose-locality')), 'the locality chip');
      expectWhole(tester, find.byKey(const ValueKey('compose-place')), 'the place field');
    });
  }
}
