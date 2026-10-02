import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/home/widgets/home_header.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/theme/app_colors.dart';
import 'package:pet_companion/widgets/brand.dart';

import 'home_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const title = 'PetLoop';
  // The logo's two pieces: the paw-and-loop mark and the lettering.
  final titleText = find.byKey(HomeTopBar.brandWordmarkKey);
  final paw = find.byKey(HomeTopBar.brandMarkKey);
  final menu = find.byTooltip('Menu');
  // Semantics finders need the test binding, so they are built on demand.
  Finder brandFinder() => find.bySemanticsLabel(title);
  Finder avatarFinder() => find.bySemanticsLabel(RegExp('^Account'));

  /// True when [inner] lies inside [outer] (with a hair of rounding slack).
  bool within(Rect inner, Rect outer) => outer.inflate(0.01).contains(inner.topLeft) && outer.inflate(0.01).contains(inner.bottomRight);

  group('the Home top bar', () {
    testWidgets('has a 48 px row, with the pill as a full-height target', (tester) async {
      await pumpTopBar(tester, width: 390);

      expect(HomeTopBar.rowHeight, 48);
      final bar = tester.getRect(topBar);
      expect(bar.width, 390);
      expect(bar.height, HomeTopBar.height);
      final pill = tester.getRect(emergencyPill);
      expect(pill.height, 48);
      // Menu, pill and avatar share the row's centre line.
      expect(tester.getCenter(menu).dy, moreOrLessEquals(pill.center.dy));
      expect(tester.getCenter(avatarFinder()).dy, moreOrLessEquals(pill.center.dy));
    });

    testWidgets('keeps menu, title, pill and avatar in that order', (tester) async {
      await pumpTopBar(tester, width: 390);

      final pill = tester.getRect(emergencyPill);
      expect(tester.getRect(menu).right, lessThanOrEqualTo(tester.getRect(brandFinder()).left));
      expect(tester.getRect(brandFinder()).right, lessThanOrEqualTo(pill.left));
      expect(pill.right, lessThanOrEqualTo(tester.getRect(avatarFinder()).left));
    });

    testWidgets('mirrors in a right-to-left language', (tester) async {
      await pumpTopBar(tester, width: 390, direction: TextDirection.rtl, petId: soyaId);

      final pill = tester.getRect(emergencyPill);
      expect(tester.getRect(avatarFinder()).right, lessThanOrEqualTo(pill.left));
      expect(pill.right, lessThanOrEqualTo(tester.getRect(brandFinder()).left));
      expect(tester.getRect(brandFinder()).right, lessThanOrEqualTo(tester.getRect(menu).left));
      // The dot moves to the pill's other top corner.
      expect(tester.getCenter(emergencyDot).dx, lessThan(pill.center.dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrinks the title step by step and never the pill', (tester) async {
      // What is drawn of the brand: 0 paw only, 1 title only, 2 paw and title.
      final steps = <double, int>{};
      Size? pillSize;

      for (final width in <double>[320, 360, 390, 430, 480, 540, 600, 700, 840]) {
        await pumpTopBar(tester, width: width);
        expect(tester.takeException(), isNull, reason: 'overflow at $width px');

        // The pill keeps its natural size at every width.
        final pill = tester.getRect(emergencyPill);
        pillSize ??= pill.size;
        expect(pill.size, pillSize, reason: 'pill size at $width px');
        expect(within(pill, tester.getRect(topBar)), isTrue, reason: 'pill inside the bar at $width px');
        expect(within(tester.getRect(find.text('Emergency')), pill), isTrue);

        // The brand is always announced, whatever is drawn of it.
        expect(brandFinder(), findsOneWidget);
        final room = tester.getRect(brandFinder());
        final showsTitle = titleText.evaluate().isNotEmpty;
        final showsPaw = paw.evaluate().isNotEmpty;
        expect(showsTitle || showsPaw, isTrue, reason: 'something of the brand at $width px');
        if (showsPaw) expect(within(tester.getRect(paw), room), isTrue, reason: 'paw fits at $width px');
        if (showsTitle) {
          final drawn = tester.getRect(titleText);
          expect(within(drawn, room), isTrue, reason: 'title fits at $width px');
          // Never drawn smaller than it can be read: below that the title
          // gives way to the paw.
          final scale = drawn.width / tester.widget<PetLoopWordmark>(titleText).width;
          expect(scale, greaterThanOrEqualTo(0.449), reason: 'title scale at $width px');
        }
        steps[width] = showsTitle ? (showsPaw ? 2 : 1) : 0;
      }

      // Wider never shows less; the ends are the paw alone and the full brand.
      final order = steps.values.toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThanOrEqualTo(order[i - 1]), reason: 'steps by width: $steps');
      }
      expect(order.first, 0, reason: 'steps by width: $steps');
      expect(order.last, 2, reason: 'steps by width: $steps');
      expect(order, contains(1), reason: 'steps by width: $steps');
    });

    testWidgets('gives way to large text without clipping the pill', (tester) async {
      await pumpTopBar(tester, width: 390, textScale: 1.3);
      expect(tester.takeException(), isNull);
      final natural = tester.getRect(emergencyPill);
      expect(natural.height, 48);
      expect(natural.right, lessThanOrEqualTo(tester.getRect(avatarFinder()).left));

      // Huge text on a small phone: the whole pill is scaled to the room
      // there is, still between the menu and the avatar, still tappable.
      await pumpTopBar(tester, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
      final pill = tester.getRect(emergencyPill);
      expect(within(pill, tester.getRect(topBar)), isTrue);
      expect(within(tester.getRect(find.text('Emergency')), pill), isTrue);
      expect(tester.getRect(menu).right, lessThanOrEqualTo(pill.left));
      expect(pill.right, lessThanOrEqualTo(tester.getRect(avatarFinder()).left));
      expect(emergencyPill.hitTestable(), findsOneWidget);
      expect(tester.getSize(topBar).height, HomeTopBar.height);
    });
  });

  testWidgets(
    'stays one coral header when the page is pulled down past its top',
    (tester) async {
      await pumpHome(tester);
      final petRow = find.byType(HomePetRow);
      expect(tester.getTopLeft(petRow).dy, 0);

      // Pull down and hold: the page bounces away from the pinned bar.
      final gesture = await tester.startGesture(tester.getCenter(find.text('Feeding')));
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      final pulled = tester.getTopLeft(petRow).dy;
      expect(pulled, greaterThan(HomeTopBar.height));

      // The bar has not moved, and coral fills the gap the pull opened.
      expect(tester.getRect(topBar).top, 0);
      expect(tester.widget<HomeTopBar>(topBar).raised, isFalse);
      final coverBox = find.descendant(of: petRow, matching: find.byType(ColoredBox)).first;
      expect(tester.widget<ColoredBox>(coverBox).color, AppColors.coral);
      final cover = tester.getRect(coverBox);
      expect(cover.top, lessThanOrEqualTo(0));
      expect(cover.bottom, moreOrLessEquals(pulled));
      expect(cover.width, tester.getSize(petRow).width);

      await gesture.up();
      await settle(tester);
      expect(tester.getTopLeft(petRow).dy, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  group('the pet counter', () {
    testWidgets('counts pets, not dogs', (tester) async {
      await pumpHome(tester);
      expect(find.text('2 pets'), findsOneWidget);
      expect(find.textContaining('dog'), findsNothing);
    });

    testWidgets('says "1 pet" for a single pet', (tester) async {
      await pumpHome(tester, pets: const [Pet(id: soyaId, name: 'Soya', species: PetSpecies.cat)]);

      expect(find.text('1 pet'), findsOneWidget);
      expect(find.textContaining('pets'), findsNothing);
      expect(pillPetId(tester), soyaId);
    });
  });
}
