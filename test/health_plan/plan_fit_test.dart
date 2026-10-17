import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/insights/insight_line.dart';
import 'package:pet_companion/features/health/plans/plan_invite.dart';
import 'package:pet_companion/features/health/plans/yearly_plan_sheet.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/theme/app_fonts.dart';

import '../health/health_test_helpers.dart';

/// Loads the app's real fonts (the widget-test font is square and much
/// wider), so this file checks what fits on a real 320 px phone.
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

const narrow = Size(320, 640);

/// A dog of 9 years with nothing on record, so every kind of row shows,
/// and three "ate less" entries for the insight line.
const dog = Pet(id: 'kelly', name: 'Kelly', ageYears: 9);
const cat = Pet(id: 'soya', name: 'Soya', species: PetSpecies.cat, ageYears: 5);

Future<HealthHarness> _harness(WidgetTester tester, AppLanguage language) async {
  final repo = fakeHealth(seeded: false);
  await real(tester, () async {
    for (final daysAgo in [12, 6, 1]) {
      await repo.saveObservation(
        Observation(
          id: '',
          petId: 'kelly',
          category: 'appetite',
          level: ObservationLevel.less,
          observedAt: addDays(fixedNow, -daysAgo),
        ),
      );
    }
  });
  return HealthHarness(repository: repo, pets: [dog, cat], language: language);
}

/// Every text under [root] whole and every box inside the screen.
Future<void> _fits(WidgetTester tester, Finder root, String what) async {
  expect(tester.takeException(), isNull, reason: what);
  for (final element in find.descendant(of: root, matching: find.byType(RichText)).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '"${paragraph.text.toPlainText()}" is cut short ($what)');
    final box = tester.getRect(find.byWidget(element.widget));
    expect(box.left, greaterThanOrEqualTo(-0.5), reason: what);
    expect(box.right, lessThanOrEqualTo(narrow.width + 0.5), reason: what);
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.english, AppLanguage.hebrew]) {
    testWidgets('the Overview lines and the plan sheet fit at 320 px (${language.name})', (tester) async {
      final h = await pumpHealth(tester, harness: await _harness(tester, language), size: narrow);
      for (final key in [HealthInsightLine.lineKey, PlanInviteCard.cardKey]) {
        final card = find.byKey(key);
        expect(card, findsOneWidget);
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await _fits(tester, card, '$key');
        expect(tester.getSize(find.byKey(key == PlanInviteCard.cardKey ? PlanInviteCard.actionKey : HealthInsightLine.linkKey)).height,
            greaterThanOrEqualTo(44));
      }

      await tapVisible(tester, find.byKey(PlanInviteCard.actionKey));
      final sheet = find.byKey(YearlyPlanSheet.sheetKey);
      for (final key in ['dog.rabies', 'dog.combined', 'dog.spirocerca', 'dog.deworm', 'dog.flea']) {
        final row = find.byKey(YearlyPlanSheet.itemKey(key));
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
        await _fits(tester, row, key);
      }
      await tester.ensureVisible(find.byKey(YearlyPlanSheet.addKey));
      await tester.pumpAndSettle();
      await _fits(tester, sheet, 'the picker');

      await tapVisible(tester, find.byKey(YearlyPlanSheet.addKey));
      expect(find.byKey(YearlyPlanSheet.addedKey), findsOneWidget);
      await _fits(tester, sheet, 'the added view');
      await tester.ensureVisible(find.byKey(YearlyPlanSheet.calendarKey));
      await tester.pumpAndSettle();
      await _fits(tester, sheet, 'the added view, scrolled');
      expect(h.isHebrew, language == AppLanguage.hebrew);
    });
  }
}
