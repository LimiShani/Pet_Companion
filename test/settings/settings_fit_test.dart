import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/settings/settings_screen.dart';
import 'package:pet_companion/features/settings/widgets/week_choice.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'settings_test_helpers.dart';

// The Settings page and its Week page on a real 320 px phone, with the
// app's own fonts (the widget-test font is square and much wider).

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

const _phone = Size(320, 640);

/// Every text under [finder] is whole.
void _expectWhole(WidgetTester tester, Finder finder, String what) {
  final texts = find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true);
  expect(texts, findsWidgets, reason: what);
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$what: "${paragraph.text.toPlainText()}" is cut short');
  }
}

/// [finder] lies within the screen's side margins.
void _expectOnScreen(WidgetTester tester, Finder finder, String what) {
  final box = tester.getRect(finder);
  expect(box.left, greaterThanOrEqualTo(0), reason: what);
  expect(box.right, lessThanOrEqualTo(_phone.width), reason: what);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    testWidgets('the Settings rows and the Week page fit at 320 px (${language.name})', (tester) async {
      final l10n = stringsOf(language);
      await pumpHome(tester, language: language, size: _phone);
      await openSettingsFromYou(tester, l10n);
      expect(tester.takeException(), isNull);

      // Settings: the title, each row's name and its current choice, whole.
      _expectWhole(
        tester,
        find.descendant(of: find.byType(CoralHeader), matching: find.text(l10n.settingsTitle)),
        'the title',
      );
      for (final row in [SettingsScreen.languageKey, SettingsScreen.weekKey, SettingsScreen.notificationsKey]) {
        _expectWhole(tester, find.byKey(row), row.toString());
        _expectOnScreen(tester, find.byKey(row), row.toString());
      }
      _expectWhole(tester, find.text(l10n.settingsSavedNote), 'the saved note');

      // Week: the chips, the weekday rows, the day letters and the note.
      await openSettingsRow(tester, SettingsScreen.weekKey, weekPage);
      expect(tester.takeException(), isNull);
      for (final day in [DateTime.saturday, DateTime.sunday, DateTime.monday]) {
        final chip = find.byKey(WeekChoice.firstDayKey(day));
        _expectWhole(tester, chip, 'the first-day chip $day');
        _expectOnScreen(tester, chip, 'the first-day chip $day');
      }
      final firstChip = tester.getCenter(find.byKey(WeekChoice.firstDayKey(DateTime.saturday))).dy;
      final lastChip = tester.getCenter(find.byKey(WeekChoice.firstDayKey(DateTime.monday))).dy;
      // In Hebrew the three share one line; the longer English names may wrap.
      if (language == AppLanguage.hebrew) {
        expect(lastChip, moreOrLessEquals(firstChip, epsilon: 1), reason: 'the three chips share one line');
      }
      for (final key in [WeekChoice.sundayToThursdayKey, WeekChoice.mondayToFridayKey]) {
        _expectWhole(tester, find.byKey(key), key.toString());
      }
      _expectWhole(tester, find.byKey(WeekChoice.previewKey), 'the day letters');
      _expectOnScreen(tester, find.byKey(WeekChoice.previewKey), 'the day letters');
      await tester.ensureVisible(find.text(l10n.settingsWeekNote));
      await tester.pumpAndSettle();
      _expectWhole(tester, find.text(l10n.settingsWeekNote), 'the week note');
      expect(tester.takeException(), isNull);
    });
  }
}
