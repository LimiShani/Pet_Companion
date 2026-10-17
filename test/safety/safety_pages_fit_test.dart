import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/safety/food_check_screen.dart';
import 'package:pet_companion/features/safety/lost_mode_screens.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/services/safety/data/food_safety.dart';
import 'package:pet_companion/services/safety/state/safety_providers.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import '../health/health_test_helpers.dart';

// The safety pages on the smallest phone in the app's real fonts (the
// widget-test font is square and much wider), in English and Hebrew:
// Is it urgent?, the foods list and a food's sheet, Lost mode's two steps
// and the open alert. Any overflow fails the test.

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
  expect(finder, findsWidgets, reason: label);
  for (final element in finder.evaluate()) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byElementPredicate((e) => e == element), matching: find.byType(RichText)).first,
    );
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" is cut short');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  const phone = Size(320, 640);

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the safety pages fit at 320 px (${language.name})', (tester) async {
      final h = HealthHarness(language: language);
      final safety = lookupSafetyL10n(h.locale);
      final health = h.l10n;
      await pumpHealthHost(
        tester,
        const Row(children: [EmergencyButton(petId: 'kelly', onCoral: false)]),
        harness: h,
        size: phone,
      );
      Future<void> openSheet() async {
        await tester.tap(find.byType(EmergencyButton));
        await tester.pumpAndSettle();
      }

      // The phone's back: the top page goes (or Lost mode's step 2 goes
      // back to step 1).
      Future<void> back() async {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }

      // Is it urgent?
      await openSheet();
      await tapVisible(tester, find.byKey(const Key('emergency-urgent')));
      expectWhole(tester, health.emergencyCallNow);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await back();

      // Can Kelly eat this?, and a dangerous food's sheet.
      await tapVisible(tester, find.byKey(const Key('emergency-food')));
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), language == AppLanguage.hebrew ? 'ענב' : 'grape');
      await tester.pumpAndSettle();
      expectWhole(tester, safety.levelDangerous);
      await tester.tap(find.byKey(FoodCheckScreen.rowKey('grapes')));
      await tester.pumpAndSettle();
      expectWhole(tester, safety.foodCallVet);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(FoodSheet))).pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(FoodCheckScreen.searchKey), '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodCheckScreen.kindKey(FoodKind.household)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await back();

      // Lost mode: step 1, step 2.
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));
      expectWhole(tester, safety.lostStep(1, 2));
      await tapVisible(tester, find.byKey(LostStartScreen.townKey));
      await tester.enterText(find.byKey(const Key('lost-town-field')), language == AppLanguage.hebrew ? 'רעננ' : 'raan');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lost-town-raanana')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(LostStartScreen.placeKey), 'Ahuza park gate, by the big ficus tree');
      await tapVisible(tester, find.byKey(LostStartScreen.nextKey));
      expectWhole(tester, safety.lostStart);
      expect(tester.takeException(), isNull);
      await back(); // to step 1
      await back(); // to the sheet
      expect(find.byType(LostStartScreen), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The open alert.
      await real(
        tester,
        () => h.lostAlerts.start(
          LostStart(petId: 'kelly', localityCode: 'raanana', seenAt: fixedNow, place: 'Ahuza park gate, by the big ficus tree'),
        ),
      );
      await real(tester, () => hostContainer(tester).read(lostAlertsProvider.notifier).refresh());
      await openSheet();
      expect(find.text(safety.lostRowActive('Kelly', 0)), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('emergency-lost')));
      expectWhole(tester, safety.lostHome('Kelly'));
      expectWhole(tester, safety.lostShareCard);
      expect(tester.takeException(), isNull);
    });
  }
}
