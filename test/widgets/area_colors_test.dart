import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/theme/app_area.dart';
import 'package:pet_companion/theme/app_colors.dart';
import 'package:pet_companion/widgets/app_bottom_nav.dart';
import 'package:pet_companion/widgets/app_tag.dart';
import 'package:pet_companion/widgets/area_disc.dart';
import 'package:pet_companion/widgets/petloop_icon.dart';

import '../helpers.dart';

/// WCAG 2 relative luminance.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('area colours', () {
    test('every deep variant passes 3:1 on white (an icon in the bottom bar)', () {
      for (final area in AppArea.values) {
        expect(
          _contrast(area.deep, AppColors.white),
          greaterThanOrEqualTo(3),
          reason: '${area.name} deep',
        );
      }
    });

    test('ink on every area fill passes 4.5:1 (an icon or a tag label)', () {
      for (final area in AppArea.values) {
        expect(
          _contrast(AppColors.ink, area.disc),
          greaterThanOrEqualTo(4.5),
          reason: '${area.name} disc',
        );
      }
    });

    test('the brief\'s colours: care tint, neutral, and the brand fills', () {
      expect(AppArea.care.disc, AppColors.coralTint);
      expect(AppColors.coralTint, const Color(0xFFFBD0C3));
      expect(AppArea.health.disc, AppColors.peach);
      expect(AppArea.community.disc, AppColors.sage);
      expect(AppArea.store.disc, AppColors.yellow);
      expect(AppArea.you.disc, AppColors.neutral);
      expect(AppColors.neutral, const Color(0xFFEADFCB));
      expect(AppArea.care.deep, AppColors.coralDeep);
    });
  });

  testWidgets('AreaDisc and AppTag.area take the area colour, in ink', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AreaDisc(Icons.medication_rounded, area: AppArea.health),
              AppTag.area('Store', area: AppArea.store),
              AppTag('Plain'),
            ],
          ),
        ),
      ),
    );
    final disc = tester.widget<Container>(
      find.descendant(of: find.byType(AreaDisc), matching: find.byType(Container)).first,
    );
    expect((disc.decoration! as BoxDecoration).color, AppColors.peach);
    expect(tester.getSize(find.byType(AreaDisc)), const Size.square(AreaDisc.defaultSize));

    Color tagColour(String label) {
      final container = tester.widget<Container>(
        find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
      );
      return (container.decoration! as ShapeDecoration).color!;
    }

    expect(tagColour('Store'), AppColors.yellow);
    expect(tagColour('Plain'), const Color(0xFFFFF3D6));
    final storeText = tester.widget<Text>(find.text('Store'));
    expect(storeText.style!.color, AppColors.ink);
  });

  testWidgets('the bottom bar: the selected tab on its area pill, the others in deep colours', (tester) async {
    await pumpApp(tester);
    await signInAsDemo(tester);

    Color? pillColour() {
      final pill = tester.widget<AnimatedContainer>(find.byKey(AppBottomNav.selectedPillKey));
      return (pill.decoration! as ShapeDecoration).color;
    }

    Color? iconColour(PetLoopGlyph glyph) => tester
        .widget<PetLoopIcon>(
          find.descendant(
            of: find.byType(AppBottomNav),
            matching: find.byWidgetPredicate((w) => w is PetLoopIcon && w.glyph == glyph),
          ),
        )
        .color;

    // Home: care's tint, the rest stroked in their deep colours.
    expect(pillColour(), AppColors.coralTint);
    expect(iconColour(PetLoopGlyph.home), AppColors.ink);
    expect(iconColour(PetLoopGlyph.health), AppColors.peachDeep);
    expect(iconColour(PetLoopGlyph.community), AppColors.sageDeep);
    expect(iconColour(PetLoopGlyph.walk), AppColors.sageDeep);
    expect(iconColour(PetLoopGlyph.shop), AppColors.yellowDeep);

    // The selected label is ink and bold; the others brown.
    final home = tester.widget<Text>(
      find.descendant(of: find.byType(AppBottomNav), matching: find.text('Home')),
    );
    expect(home.style!.color, AppColors.ink);
    expect(home.style!.fontWeight, FontWeight.w800);
    final store = tester.widget<Text>(
      find.descendant(of: find.byType(AppBottomNav), matching: find.text('Store')),
    );
    expect(store.style!.color, AppColors.brown);

    for (final (label, glyph, fill) in [
      ('Health', PetLoopGlyph.health, AppColors.peach),
      ('Community', PetLoopGlyph.community, AppColors.sage),
      ('Outside', PetLoopGlyph.walk, AppColors.sage),
      ('Store', PetLoopGlyph.shop, AppColors.yellow),
    ]) {
      await tester.tap(find.descendant(of: find.byType(AppBottomNav), matching: find.text(label)));
      await tester.pumpAndSettle();
      expect(pillColour(), fill, reason: label);
      expect(iconColour(glyph), AppColors.ink, reason: label);
      expect(iconColour(PetLoopGlyph.home), AppColors.coralDeep, reason: label);
    }
  });
}
