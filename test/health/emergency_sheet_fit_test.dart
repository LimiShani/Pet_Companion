import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import 'health_test_helpers.dart';

// The emergency sheet and the Emergency card on the smallest phone, in the
// app's real fonts (the widget-test font is square and much wider), so the
// one big "Call now", the buttons under it and the round row buttons are
// checked as they will really look.

/// Loads the app's real fonts, as test/outdoors/outside_header_fit_test.dart
/// does.
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

/// Fails when the text [label] is cut short.
void expectWhole(WidgetTester tester, String label) {
  final finder = find.text(label);
  expect(finder, findsOneWidget, reason: label);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  );
  expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut short');
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  const phone = Size(320, 640);

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the emergency sheet and the Emergency card fit at 320 px (${language.name})', (tester) async {
      final h = HealthHarness(language: language);
      final l10n = h.l10n;
      await pumpHealthHost(
        tester,
        const Row(children: [EmergencyButton(petId: 'kelly', onCoral: false)]),
        harness: h,
        size: phone,
      );
      await tester.tap(find.byType(EmergencyButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The one big button and the two under it, each on one line.
      expectWhole(tester, l10n.emergencyCallNow);
      expectWhole(tester, l10n.actionMessage);
      expectWhole(tester, l10n.emergencyDirections);
      final callNow = tester.getRect(find.byKey(const ValueKey('call-emergency')));
      expect(callNow.height, greaterThanOrEqualTo(52));
      final message = tester.getRect(find.byKey(const ValueKey('message-emergency')));
      final directions = tester.getRect(find.byKey(const ValueKey('map-emergency')));
      // Side by side, each about half of Call now.
      expect(message.top, moreOrLessEquals(directions.top));
      expect(message.width, lessThan(callNow.width / 2 + 1));
      expect(directions.width, lessThan(callNow.width / 2 + 1));

      // The rows keep both round buttons inside the screen, 48 px to tap.
      for (final tag in ['regular', 'contact']) {
        for (final action in ['message', 'call']) {
          final rect = tester.getRect(find.byKey(ValueKey('$action-$tag')));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '$action-$tag');
          expect(rect.right, lessThanOrEqualTo(phone.width), reason: '$action-$tag');
          expect(rect.height, greaterThanOrEqualTo(48), reason: '$action-$tag');
        }
      }
      expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);

      // The plain rows and the fine print.
      await tester.ensureVisible(find.text(l10n.emergencySheetFinePrint));
      await tester.pumpAndSettle();
      expect(find.text(l10n.emergencyCardAndKit), findsOneWidget);
      expect(find.text(l10n.emergencyCardAndKitNoteKit(3, 6)), findsOneWidget);
      expect(find.text(l10n.petIsLost('Kelly')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The Emergency card.
      await tapVisible(tester, find.byKey(const Key('open-emergency-card')));
      expect(find.text(l10n.emergencyCardTitle), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.emergencyCardFinePrint));
      await tester.pumpAndSettle();
      expect(find.byTooltip(l10n.shareSummary), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
