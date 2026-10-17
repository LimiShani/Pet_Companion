import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/pet_records/data/fake_health_repository.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import '../health/health_test_helpers.dart';

// The problem's screens on a real 320 px phone, with the app's own fonts
// (the widget-test font is square and much wider), in English and Hebrew:
// nothing overflows, nothing that must be read whole is cut short, and
// every row stays inside the screen.

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

/// Every text under [of] is whole, and [of] is inside the screen.
void expectFits(WidgetTester tester, Finder of, String where) {
  expect(tester.takeException(), isNull, reason: where);
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final element in of.evaluate()) {
    final box = tester.getRect(find.byWidget(element.widget));
    expect(box.left, greaterThanOrEqualTo(-0.5), reason: where);
    expect(box.right, lessThanOrEqualTo(width + 0.5), reason: where);
  }
  for (final text in find.descendant(of: of, matching: find.byType(RichText)).evaluate()) {
    final paragraph = text.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$where: "${paragraph.text.toPlainText()}" is cut short');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('the problem\'s screens fit at 320 px (${language.name})', (tester) async {
      final h = HealthHarness(
        repository: FakeHealthRepository(latency: Duration.zero, now: () => fixedNow, seedIssue: true),
        language: language,
      );
      await pumpHealth(tester, harness: h, size: smallPhone);

      // The Overview row.
      final row = find.byKey(const ValueKey('overview-issue-i-limp'));
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pumpAndSettle();
      expectFits(tester, row, 'Overview row');
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));

      // The page.
      await tapVisible(tester, row);
      expectFits(tester, find.byKey(const Key('issue-summary')), 'summary');
      for (final id in ['o-limp-4', 'o-limp-3', 'o-limp-2', 'o-limp-1']) {
        final entry = find.byKey(ValueKey('issue-entry-$id'));
        await Scrollable.ensureVisible(tester.element(entry), alignment: 0.5);
        await tester.pumpAndSettle();
        expectFits(tester, entry, 'entry $id');
      }
      final resolve = find.byKey(const Key('issue-resolve'));
      await Scrollable.ensureVisible(tester.element(resolve), alignment: 0.5);
      await tester.pumpAndSettle();
      expectFits(tester, resolve, 'resolve');

      // The Quick log on the problem, with its photos row.
      await tapVisible(tester, find.byKey(const Key('issue-add-entry')));
      await tapVisible(tester, find.byKey(const ValueKey('quick-mobility')));
      final part = find.byKey(const ValueKey('quick-issue-i-limp'));
      await Scrollable.ensureVisible(tester.element(part), alignment: 0.5);
      await tester.pumpAndSettle();
      expectFits(tester, part, 'Part of a problem');
      expectFits(tester, find.byKey(const Key('quick-add-photo')), 'add photo');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The sheet, from the page's "More".
      await tapVisible(tester, find.byKey(const Key('issue-more')));
      await tapVisible(tester, find.byKey(const Key('issue-rename')));
      for (final key in ['issue-title', 'issue-started', 'issue-area', 'issue-save']) {
        final piece = find.byKey(Key(key));
        await Scrollable.ensureVisible(tester.element(piece), alignment: 0.5);
        await tester.pumpAndSettle();
        expectFits(tester, piece, key);
      }
    });
  }
}
