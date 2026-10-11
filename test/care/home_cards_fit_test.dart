import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/budget/budget.dart';
import 'package:pet_companion/features/care/widgets/activity_card.dart';
import 'package:pet_companion/features/care/widgets/feeding_card.dart';
import 'package:pet_companion/features/firstdays/firstdays.dart';
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

  // The sample day, in the afternoon (see test/home_screen_test.dart).
  final afternoon = DateTime(2025, 6, 10, 15);

  /// Scrolls [card] into view and checks that it laid out without an
  /// overflow and that none of its texts is cut short.
  Future<void> expectFits(WidgetTester tester, Finder card, String name) async {
    expect(card, findsOneWidget, reason: '$name is on Home');
    await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$name overflows');
    final texts = find.descendant(of: card, matching: find.byType(RichText));
    expect(texts, findsWidgets);
    for (final element in texts.evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '"${paragraph.text.toPlainText()}" is cut short on $name',
      );
    }
  }

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the Home cards fit at 320 px, Kelly and Soya (${language.name})', (tester) async {
      await pumpApp(tester, now: afternoon, language: language);
      await signInAsDemo(tester);

      // On a regular phone the spending card's total and change are one
      // line (a metric line is 32 px tall; two would be over 45).
      final spending = find.byKey(SpendingCard.cardKey);
      await Scrollable.ensureVisible(tester.element(spending), alignment: 0.5);
      await tester.pumpAndSettle();
      final money = find.descendant(of: spending, matching: find.textContaining('280', findRichText: true));
      expect(money, findsOneWidget);
      expect(tester.getSize(money).height, lessThan(45));

      // Then the smallest phone.
      tester.view.physicalSize = const Size(320, 640) * 3;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Kelly: data on every card.
      await expectFits(tester, find.byType(FeedingCard), 'Kelly feeding');
      await expectFits(tester, find.byType(ActivityCard), 'Kelly activity');
      await expectFits(tester, find.byKey(SpendingCard.cardKey), 'spending');
      await expectFits(tester, find.byKey(RunningLowCard.cardKey), 'running low');

      // Soya: nothing set up, and her first 30 days. Back to the top of
      // Home, where the pet pills are.
      tester
          .state<ScrollableState>(find.ancestor(of: find.byType(FeedingCard), matching: find.byType(Scrollable)).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soya').first);
      await tester.pumpAndSettle();
      expect(find.byKey(FeedingCard.setUpKey), findsOneWidget);
      expect(find.byKey(ActivityCard.setUpKey), findsOneWidget);
      await expectFits(tester, find.byType(FeedingCard), 'Soya feeding');
      await expectFits(tester, find.byType(ActivityCard), 'Soya activity');
      await expectFits(tester, find.byKey(FirstDaysHomeCard.cardKey), 'first 30 days');
    });
  }
}
