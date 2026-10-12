import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/pets.dart';
import 'package:pet_companion/features/pets/profile/name_and_kind_sheet.dart';
import 'package:pet_companion/features/pets/profile/pet_profile_screen.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/theme/app_fonts.dart';
import 'package:pet_companion/widgets/coral_header.dart';

import 'pets_test_helpers.dart';

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

/// Every text under [finder] is whole.
void expectWhole(WidgetTester tester, Finder finder, String what) {
  final texts = find.descendant(of: finder, matching: find.byType(RichText), matchRoot: true);
  expect(texts, findsWidgets, reason: what);
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: '$what: "${paragraph.text.toPlainText()}" is cut short');
  }
}

/// [finder] lies within the screen.
void expectOnScreen(WidgetTester tester, Finder finder, String what) {
  final box = tester.getRect(finder);
  expect(box.left, greaterThanOrEqualTo(0), reason: what);
  expect(box.right, lessThanOrEqualTo(320), reason: what);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
  });

  for (final language in [AppLanguage.hebrew, AppLanguage.english]) {
    for (final (petId, name) in [(kelly, 'Kelly'), (soya, 'Soya')]) {
      testWidgets("$name's profile, its menu and the name sheet fit at 320 px (${language.name})", (tester) async {
        final hebrew = language == AppLanguage.hebrew;
        final l10n = hebrew ? he : en;
        await pumpPetsHost(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => openPetProfile(context, petId),
              child: const Text('profile'),
            ),
          ),
          harness: PetsHarness(language: language),
          size: const Size(320, 640),
        );
        await tester.tap(find.text('profile'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The header: the name whole beside the back arrow and the menu.
        expectWhole(tester, find.descendant(of: find.byType(CoralHeader), matching: find.text(name)), 'the title');
        expectOnScreen(tester, find.byKey(PetProfileScreen.moreKey), 'the menu');
        expectOnScreen(tester, find.byKey(PetProfileScreen.pictureKey), 'the picture');

        // Every row: whole, inside the screen.
        for (final row in ['name', 'age', 'weight', 'breed', 'sex', 'vets', 'health', 'documents']) {
          final finder = find.byKey(PetProfileScreen.rowKey(row));
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expectWhole(tester, finder, row);
          expectOnScreen(tester, finder, row);
        }
        expect(tester.takeException(), isNull);

        // The menu: both entries whole.
        await tester.tap(find.byKey(PetProfileScreen.moreKey));
        await tester.pumpAndSettle();
        expectWhole(tester, find.byKey(PetProfileScreen.archiveKey), 'archive');
        expectWhole(tester, find.byKey(PetProfileScreen.deleteKey), 'delete');
        expect(find.text(l10n.deletePet(name)), findsOneWidget);
        await tester.tapAt(const Offset(10, 600));
        await tester.pumpAndSettle();

        // The name sheet: the kind tiles and the button.
        await tester.ensureVisible(find.byKey(PetProfileScreen.rowKey('name')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(PetProfileScreen.rowKey('name')));
        await tester.pumpAndSettle();
        expect(find.byKey(PetNameAndKindSheet.sheetKey), findsOneWidget);
        expect(find.text(l10n.profileNameAndKind), findsNWidgets(2));
        for (final kind in ['dog', 'cat', 'bird', 'rabbit', 'reptile', 'other']) {
          expectOnScreen(tester, find.byKey(Key('kind-$kind')), kind);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
