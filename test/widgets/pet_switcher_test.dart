import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/pets/add_pet/add_pet_screen.dart';
import 'package:pet_companion/features/pets/profile/pet_profile_screen.dart';
import 'package:pet_companion/features/pets/widgets/pet_reminder_card.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/presentation/pet_avatar.dart';
import 'package:pet_companion/state/pets_provider.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/app_icon.dart';
import 'package:pet_companion/widgets/pet_switcher.dart';

import '../helpers.dart';

// The pet chip of a coral header, on the Health tab (the one tab that
// carries it). The demo account owns two dogs: Kelly, selected and
// complete, and Soya, with her essentials still missing.
//
// The Health header holds the title, the chip, the Emergency pill and the
// account avatar, so the chip sizes itself to the screen: the name from
// 400 px, the picture and the chevron from 360 px, the picture alone
// below. The tiers are checked at 540, 360 and 320 px.

/// The day of the sample data, so every fake backend answers at once.
final _now = DateTime(2025, 6, 10, 15);

final _chip = find.byKey(PetSwitcher.chipKey);
final _sheet = find.byKey(PetSwitcher.sheetKey);

Finder _onChip(String text) => find.descendant(of: _chip, matching: find.text(text));

Finder _inSheet(Finder what) => find.descendant(of: _sheet, matching: what);

Finder _checkMark() => find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.check_rounded);

/// Signs in and opens the Health tab, in English unless [language] says
/// otherwise, on a wide phone (the chip shows the name) unless [size]
/// says otherwise.
Future<void> _pumpHealth(
  WidgetTester tester, {
  AppLanguage? language,
  Size size = const Size(540, 844),
}) async {
  await pumpApp(tester, language: language, size: size, now: _now);
  await signInAsDemo(tester);
  final locale = language == AppLanguage.hebrew ? hebrewLocale : englishLocale;
  await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(lookupAppL10n(locale).navHealth)));
  await tester.pumpAndSettle();
}

Finder _chevron() => find.descendant(
      of: _chip,
      matching: find.byWidgetPredicate((w) => w is AppIcon && w.icon == Icons.expand_more_rounded),
    );

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(_chip);
  await tester.pumpAndSettle();
  expect(_sheet, findsOneWidget);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('the chip shows the selected pet; the sheet lists the pets, the selected one checked', (tester) async {
    await _pumpHealth(tester);

    expect(_chip, findsOneWidget);
    expect(_onChip('Kelly'), findsOneWidget);
    expect(_sheet, findsNothing);

    await _openSheet(tester);

    expect(_inSheet(find.text('Which pet?')), findsOneWidget);
    final kelly = find.byKey(PetSwitcher.rowKey('kelly'));
    final soya = find.byKey(PetSwitcher.rowKey('soya'));
    expect(kelly, findsOneWidget);
    expect(soya, findsOneWidget);
    expect(find.descendant(of: kelly, matching: find.text('Kelly')), findsOneWidget);
    // The kind leads the one-line summary.
    expect(find.descendant(of: kelly, matching: find.textContaining('Dog')), findsOneWidget);
    expect(find.descendant(of: kelly, matching: _checkMark()), findsOneWidget);
    expect(find.descendant(of: soya, matching: _checkMark()), findsNothing);
    expect(find.byKey(PetSwitcher.profileKey), findsOneWidget);
    expect(_inSheet(find.text("Open Kelly's profile")), findsOneWidget);
    expect(find.byKey(PetSwitcher.addKey), findsOneWidget);
    expect(_inSheet(find.text('Add a pet')), findsOneWidget);
  });

  testWidgets('tapping a pet selects it for the whole app, closes the sheet and moves the dot', (tester) async {
    await _pumpHealth(tester);
    final container = ProviderScope.containerOf(tester.element(_chip));
    expect(container.read(selectedPetProvider).id, 'kelly');
    // Kelly's essentials are all answered: no dot on the chip.
    expect(find.descendant(of: find.byType(PetSwitcher), matching: find.bySemanticsLabel('Essentials missing')),
        findsNothing);

    await _openSheet(tester);
    await tester.tap(find.byKey(PetSwitcher.rowKey('soya')));
    await tester.pumpAndSettle();

    expect(_sheet, findsNothing);
    expect(container.read(selectedPetProvider).id, 'soya');
    expect(_onChip('Soya'), findsOneWidget);
    expect(_onChip('Kelly'), findsNothing);
    // Soya still misses her essentials: the Pets feature's dot sits on the chip.
    expect(find.descendant(of: find.byType(PetSwitcher), matching: find.byType(PetAttentionDot)), findsOneWidget);
    expect(find.descendant(of: find.byType(PetSwitcher), matching: find.bySemanticsLabel('Essentials missing')),
        findsOneWidget);

    // The sheet now checks Soya and offers her profile.
    await _openSheet(tester);
    expect(find.descendant(of: find.byKey(PetSwitcher.rowKey('soya')), matching: _checkMark()), findsOneWidget);
    expect(_inSheet(find.text("Open Soya's profile")), findsOneWidget);
  });

  testWidgets('on a small phone the chip keeps the picture and the chevron, and still switches', (tester) async {
    await _pumpHealth(tester, size: const Size(360, 780));

    expect(_chip, findsOneWidget);
    expect(_onChip('Kelly'), findsNothing);
    expect(_chevron(), findsOneWidget);
    expect(tester.getSize(_chip).height, 36);
    // The name is still announced.
    expect(find.bySemanticsLabel('Switch pet: Kelly'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _openSheet(tester);
    await tester.tap(find.byKey(PetSwitcher.rowKey('soya')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Switch pet: Soya'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Open profile" opens the selected pet\'s profile', (tester) async {
    await _pumpHealth(tester);
    await _openSheet(tester);

    await tester.tap(find.byKey(PetSwitcher.profileKey));
    await tester.pumpAndSettle();

    expect(_sheet, findsNothing);
    expect(find.byType(PetProfileScreen), findsOneWidget);
    expect(find.text('Kelly'), findsWidgets);
  });

  testWidgets('"Add a pet" opens the add-a-pet flow', (tester) async {
    await _pumpHealth(tester);
    await _openSheet(tester);

    await tester.tap(find.byKey(PetSwitcher.addKey));
    await tester.pumpAndSettle();

    expect(_sheet, findsNothing);
    expect(find.byType(AddPetScreen), findsOneWidget);
  });

  testWidgets('in Hebrew on a 320 px phone the chip and the sheet fit', (tester) async {
    await _pumpHealth(tester, language: AppLanguage.hebrew, size: const Size(320, 844));

    // The tightest case: the chip is down to the picture, and nothing
    // overflows.
    expect(_chip, findsOneWidget);
    expect(_onChip('Kelly'), findsNothing);
    expect(tester.getSize(_chip).height, 36);
    expect(find.bySemanticsLabel(RegExp('החלפת חיה')), findsOneWidget);
    // It comes first in the header's actions, which run right to left, so
    // it sits at the right of the Emergency pill and left of the title.
    expect(tester.getTopRight(_chip).dx, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);

    await _openSheet(tester);
    expect(_inSheet(find.text('איזו חיה?')), findsOneWidget);
    expect(_inSheet(find.textContaining('פתיחת הפרופיל של')), findsOneWidget);
    expect(_inSheet(find.text('הוספת חיה')), findsOneWidget);
    expect(find.byKey(PetSwitcher.rowKey('soya')), findsOneWidget);
    // Rows read from the right: the picture is right of the name.
    final soya = find.byKey(PetSwitcher.rowKey('soya'));
    final name = find.descendant(of: soya, matching: find.text('Soya'));
    final picture = find.descendant(of: soya, matching: find.byType(PetAvatar));
    expect(tester.getCenter(name).dx, lessThan(tester.getCenter(picture).dx));
    expect(tester.takeException(), isNull);
  });
}
