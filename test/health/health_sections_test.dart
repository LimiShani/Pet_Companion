import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/widgets/coral_segmented_control.dart';

import 'health_test_helpers.dart';

// The tab's three sections (Overview, Schedule, Records), what moved where
// when History and Insights became Records, and the Overview's rows.

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// The labels of the chips in Records' one chip row, in order.
  List<String> chipKeys(WidgetTester tester) {
    final row = find.byKey(const Key('records-chips'));
    final chips = tester.widgetList<ChoiceChip>(find.descendant(of: row, matching: find.byType(ChoiceChip))).toList();
    return [for (final c in chips) (c.key! as ValueKey<String>).value];
  }

  ChoiceChip chip(WidgetTester tester, String key) => tester.widget<ChoiceChip>(find.byKey(Key(key)));

  testWidgets('the switcher has three sections: Overview, Schedule, Records', (tester) async {
    await pumpHealth(tester);

    expect(HealthSection.values.map((s) => s.name), ['overview', 'schedule', 'records']);
    final switcher = find.byType(CoralSegmentedControl);
    for (final label in ['Overview', 'Schedule', 'Records']) {
      expect(find.descendant(of: switcher, matching: find.text(label)), findsOneWidget, reason: label);
    }
    for (final gone in ['History', 'Insights']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(tester.widget<CoralSegmentedControl>(switcher).labels, hasLength(3));
  });

  group('Records', () {
    testWidgets('one chip row: All, the kinds on record, Documents, Weight, Journal', (tester) async {
      await pumpHealth(tester);
      await openSection(tester, 'Records');

      expect(chipKeys(tester), [
        'filter-all',
        'filter-checkup',
        'filter-vaccination',
        'filter-preventive',
        'filter-procedure',
        'filter-other',
        'filter-documents',
        'filter-weight',
        'filter-journal',
      ]);
      expect(chip(tester, 'filter-all').selected, isTrue);
      // The search, the count and Share; adding is the tab's "+".
      expect(find.byKey(const Key('history-search')), findsOneWidget);
      expect(find.text('12 records'), findsOneWidget);
      expect(find.byKey(const Key('records-share')), findsOneWidget);
      expect(find.text('Add record'), findsNothing);
      expect(find.byKey(const Key('journal-category')), findsNothing);
    });

    testWidgets('Weight shows the weight card and "Log weight"', (tester) async {
      await pumpHealth(tester);
      await openRecords(tester, chip: 'filter-weight');

      expect(chip(tester, 'filter-weight').selected, isTrue);
      expect(chip(tester, 'filter-all').selected, isFalse);
      expect(find.byKey(const Key('insights-weight')), findsOneWidget);
      expect(find.byKey(const Key('log-weight')), findsOneWidget);
      expect(find.text('6 weigh-ins'), findsOneWidget);
      expect(find.byKey(const Key('records-share')), findsOneWidget);
      // No timeline, and no search to type into on a chart.
      expect(find.text('Flea and tick tablet'), findsNothing);
      expect(find.byKey(const Key('history-search')), findsNothing);
      expect(find.byKey(const Key('journal-category')), findsNothing);
    });

    testWidgets('Journal has one Category menu chip instead of a second chip row', (tester) async {
      await pumpHealth(tester);
      await openRecords(tester, chip: 'filter-journal');

      expect(find.text('Mobility · Less than usual'), findsOneWidget);
      expect(find.text('9 entries'), findsOneWidget);
      expect(find.byKey(const Key('journal-category')), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Category'), findsOneWidget);
      // One row of chips: every other chip on the page is the Category chip.
      final chips = find.byType(ChoiceChip);
      final inRow = find.descendant(of: find.byKey(const Key('records-chips')), matching: find.byType(ChoiceChip));
      expect(tester.widgetList(chips).length - tester.widgetList(inRow).length, 1);
      expect(find.byType(SingleChildScrollView).evaluate().where((e) {
        final scroll = e.widget as SingleChildScrollView;
        return scroll.scrollDirection == Axis.horizontal;
      }), hasLength(1));
      // The categories wait in the menu.
      expect(find.byKey(const ValueKey('journal-mobility')), findsNothing);

      await pickJournalCategory(tester, 'journal-mobility');
      expect(find.widgetWithText(ChoiceChip, 'Mobility'), findsOneWidget);
      expect(find.text('1 of 9 entries'), findsOneWidget);
      expect(find.text('Appetite · Usual'), findsNothing);

      // The search finds an entry by its note.
      await pickJournalCategory(tester, 'journal-all');
      await tester.enterText(find.byKey(const Key('history-search')), 'walk');
      await tester.pumpAndSettle();
      expect(find.text('Energy · Less than usual'), findsOneWidget);
      expect(find.text('Mobility · Less than usual'), findsNothing);
    });

    testWidgets('Share is on Records, on every chip, and not on the Overview', (tester) async {
      final h = await pumpHealth(tester);
      expect(find.byKey(const Key('records-share')), findsNothing);
      expect(find.byKey(const Key('overview-share')), findsNothing);
      expect(find.text('Share'), findsNothing);

      for (final key in ['filter-all', 'filter-weight', 'filter-journal']) {
        await openRecords(tester, chip: key);
        expect(find.byKey(const Key('records-share')), findsOneWidget, reason: key);
        expect(find.text('Share'), findsOneWidget, reason: key);
      }
      await tapVisible(tester, find.byKey(const Key('records-share')));
      expect(h.sharer.shared.single.name, 'kelly-health-summary.pdf');
    });

    testWidgets('the "+" is on every section', (tester) async {
      await pumpHealth(tester);
      expect(find.byKey(const Key('add-fab')), findsOneWidget);
      await openSection(tester, 'Schedule');
      expect(find.byKey(const Key('add-fab')), findsOneWidget);
      for (final key in ['filter-all', 'filter-weight', 'filter-journal']) {
        await openRecords(tester, chip: key);
        expect(find.byKey(const Key('add-fab')), findsOneWidget, reason: key);
      }
    });

    testWidgets('another pet keeps the chip but starts unfiltered', (tester) async {
      await pumpHealth(tester);
      await openRecords(tester, chip: 'filter-vaccination');
      await switchPet(tester, 'Soya');
      expect(chip(tester, 'filter-all').selected, isTrue);

      await openRecords(tester, chip: 'filter-weight');
      await switchPet(tester, 'Kelly');
      expect(chip(tester, 'filter-weight').selected, isTrue);
    });
  });

  group('Overview', () {
    testWidgets('no pet card, no Medicines card, no Weight card and no record tiles', (tester) async {
      await pumpHealth(tester);

      // Adding is the tab's "+": no Quick log or "Add record" buttons here.
      for (final key in [
        'overview-pet',
        'overview-medicines',
        'overview-share',
        'insights-weight',
        'overview-quick-log',
        'overview-add-record',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(find.text('Medical records'), findsNothing);
      expect(find.text('Medicines'), findsNothing);
      expect(find.bySemanticsLabel('3 Vaccinations'), findsNothing);
      // What is there, top to bottom.
      final order = [
        'overview-coming-up',
        'overview-vet',
        'overview-profile',
        'overview-weight',
        'overview-records',
      ];
      for (var i = 1; i < order.length; i++) {
        final above = tester.getRect(find.byKey(Key(order[i - 1])));
        final below = tester.getRect(find.byKey(Key(order[i])));
        expect(above.top, lessThan(below.top), reason: '${order[i - 1]} above ${order[i]}');
      }
    });

    testWidgets('the Health profile row opens the health profile', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.byKey(const Key('overview-profile')));
      expect(find.text("Kelly's health profile"), findsOneWidget);
    });

    testWidgets('the Weight row opens Records on Weight', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.byKey(const Key('overview-weight')));

      final switcher = tester.widget<CoralSegmentedControl>(find.byType(CoralSegmentedControl));
      expect(switcher.labels[switcher.selectedIndex], 'Records');
      expect(chip(tester, 'filter-weight').selected, isTrue);
      expect(find.byKey(const Key('insights-weight')), findsOneWidget);
    });

    testWidgets('the Records row opens Records on All', (tester) async {
      await pumpHealth(tester);
      await openRecords(tester, chip: 'filter-journal');
      await openSection(tester, 'Overview');

      await tapVisible(tester, find.byKey(const Key('overview-records')));
      expect(chip(tester, 'filter-all').selected, isTrue);
      expect(find.text('12 records'), findsOneWidget);
    });

    testWidgets('the vet card: hours, Call and Message, Details and Find a vet', (tester) async {
      final h = await pumpHealth(tester);

      expect(find.text('Sun to Thu 08:00-19:00, Fri 08:00-13:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-overview')), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('call-overview')));
      expect(h.launcher.calls.single.target, '+972 3 555 0142');

      await tapVisible(tester, find.byKey(const Key('overview-vet-row')));
      expect(find.text("Kelly's vets"), findsOneWidget);
      // The map is on the details page.
      expect(find.byKey(const ValueKey('map-regular')), findsOneWidget);
    });
  });
}
