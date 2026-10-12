import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/community/widgets/advice_notice.dart';
import 'package:pet_companion/features/community/widgets/scope_menu_chip.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/widgets/coral_header.dart';
import 'package:pet_companion/widgets/header_search.dart';

import 'community_helpers.dart';

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

/// Fails when a one-line text found by [finder] is cut short.
void expectWhole(WidgetTester tester, Finder finder, String what) {
  expect(finder, findsWidgets, reason: what);
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true),
  )) {
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$what" is cut short');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    final words = language == AppLanguage.hebrew ? he : en;

    testWidgets('the streamlined Community fits at 320 px (${language.name})', (tester) async {
      await pumpCommunity(tester, harness: CommunityHarness(appLanguage: language), size: const Size(320, 640));
      expect(tester.takeException(), isNull);

      // The header: title, magnifier, bell and avatar on one line.
      expectWhole(tester, find.descendant(of: find.byType(CoralHeader), matching: find.text(words.tabTitle)), 'title');
      expect(find.byKey(HeaderSearchButton.buttonKey), findsOneWidget);
      for (final label in [words.sectionFeed, words.sectionChat, words.sectionGuides]) {
        expectWhole(tester, find.text(label), label);
      }

      // The feed's one row and its advice line with "Hide".
      expectWhole(tester, find.descendant(of: scopeMenu, matching: find.text(words.scopeDogs)), 'scope chip');
      expectWhole(tester, find.text(words.kindsAll), 'all posts');
      final hide = find.descendant(of: find.byType(FeedAdviceLine), matching: find.text(words.adviceHide));
      expectWhole(tester, hide, 'Hide');
      expect(tester.getSize(find.ancestor(of: hide, matching: find.byType(TextButton))).height, greaterThanOrEqualTo(40));

      // The search open in the header.
      await openSearch(tester);
      expect(find.byKey(HeaderSearchField.fieldKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await closeSearch(tester);

      // Chat: the menu chip at the end of the "Topic rooms" line.
      await openSection(tester, words.sectionChat);
      final heading = find.byKey(const Key('rooms-heading'));
      expectWhole(tester, find.descendant(of: heading, matching: find.text(words.topicRooms)), 'topic rooms');
      await chooseScope(tester, 'everything');
      expectWhole(
        tester,
        find.descendant(of: heading, matching: find.text(words.scopeEverything)),
        'scope chip (Everything)',
      );
      expect(find.descendant(of: heading, matching: find.byKey(ScopeMenuChip.chipKey)), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Guides: the row, then a reader's byline.
      await openSection(tester, words.sectionGuides);
      expectWhole(tester, find.descendant(of: scopeMenu, matching: find.text(words.scopeEverything)), 'guides chip');
      await tapVisible(tester, find.byKey(const ValueKey('guide-first-week')));
      expect(find.byKey(const Key('guide-byline')), findsOneWidget);
      await tester.scrollUntilVisible(find.text(words.guideDisclaimer), 300);
      expect(tester.takeException(), isNull);
    });
  }
}
