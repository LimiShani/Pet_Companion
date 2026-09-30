import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/costs.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/health_format.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';

  Future<HealthHarness> openHistory(WidgetTester tester, {HealthHarness? harness}) async {
    final h = await pumpHealth(tester, harness: harness);
    await openSection(tester, 'History');
    return h;
  }

  String tag(WidgetTester tester, String recordId) => tester
      .widget<Text>(find.descendant(of: find.byKey(ValueKey('cost-$recordId')), matching: find.byType(Text)))
      .data!;

  group('money', () {
    test('an amount shows decimals only when it has them', () {
      final english = HealthFormat.forLocale(englishLocale);
      expect(english.money(320, 'ILS'), '₪320');
      expect(english.money(649.9, 'ILS'), '₪649.90');
      expect(english.money(12, 'EUR'), '€12');
    });

    test('a typed amount accepts a comma and refuses anything else', () {
      expect(parseMoney('120'), 120);
      expect(parseMoney(' 89,90 '), 89.9);
      expect(parseMoney('12.345'), 12.35);
      expect(parseMoney('0'), 0);
      expect(parseMoney('1.2.3'), isNull);
      expect(parseMoney(''), isNull);
      expect(parseMoney('999999999'), isNull);
    });
  });

  group('Cost on a record', () {
    testWidgets('shows as a tag on the History card and a row on the record', (tester) async {
      await openHistory(tester);

      expect(tag(tester, 'r-limp'), '₪320');
      expect(tag(tester, 'r-dental'), '₪649.90');
      expect(find.bySemanticsLabel(RegExp('Cost ₪320')), findsOneWidget);
      // A record without a cost looks as before.
      expect(find.byKey(const ValueKey('cost-r-worm')), findsNothing);

      await tapVisible(tester, find.text('Limping after a long walk'));
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('₪320'), findsOneWidget);
    });

    testWidgets('is entered in the record form, optional, and validated', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Add record'));
      expect(find.text('Cost (optional)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('record-title')), 'Nail trim');
      await tester.enterText(find.byKey(const Key('record-cost')), '4.5.0');
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('Enter an amount, like 120 or 89.90.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('record-cost')), '45,5');
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('New record'), findsNothing);

      final saved = (await real(
        tester,
        () => h.repository.fetchRecords(kelly),
      )).firstWhere((r) => r.title == 'Nail trim');
      expect(saved.costAmount, 45.5);
      expect(saved.costCurrency, 'ILS');
      expect(tag(tester, saved.id), '₪45.50');
    });

    testWidgets('can be changed and removed again', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Limping after a long walk'));
      await tester.tap(find.byTooltip('Edit record'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, '320'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('record-cost')), '');
      await tapVisible(tester, find.text('Save record'));

      expect(find.byKey(const Key('record-cost-row')), findsNothing);
      final saved = (await real(tester, () => h.repository.fetchRecords(kelly))).firstWhere((r) => r.id == 'r-limp');
      expect(saved.costAmount, isNull);
      // Everything else on the record is untouched.
      expect(saved.notes, 'Arthritis in the hips. Started joint tablets.');
    });

    testWidgets('on a planned record it is an expected cost, and stays when it is marked as done', (tester) async {
      final h = await pumpHealth(tester);
      await openSection(tester, 'Schedule');
      await tapVisible(tester, find.byKey(const ValueKey('planned-r-check')));
      await tester.tap(find.byTooltip('Edit record'));
      await tester.pumpAndSettle();
      expect(find.text('Expected cost (optional)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('record-cost')), '250');
      await tapVisible(tester, find.text('Save record'));
      expect(find.text('Expected cost'), findsOneWidget);

      // Not spent yet: a Budget reader does not see it.
      var costs = (await settled(tester, healthCostsProvider(kelly))).value!;
      expect(costs.map((c) => c.recordId), isNot(contains('r-check')));

      await tapVisible(tester, find.byKey(const Key('record-mark-done')));
      expect(find.text('Cost'), findsOneWidget);
      final saved = (await real(tester, () => h.repository.fetchRecords(kelly))).firstWhere((r) => r.id == 'r-check');
      expect(saved.costAmount, 250);
      costs = (await settled(tester, healthCostsProvider(kelly))).value!;
      expect(costs.map((c) => c.recordId), contains('r-check'));
    });

    testWidgets('is never part of the PDF that is shared', (tester) async {
      final h = await openHistory(tester);
      await tapVisible(tester, find.text('Limping after a long walk'));
      await tapVisible(tester, find.byKey(const Key('record-share')));

      final text = h.pdf.last.allText.join(' | ');
      expect(text, contains('Limping after a long walk'));
      expect(text, isNot(contains('320')));
      expect(text, isNot(contains('Cost')));
    });
  });

  group('costs for the Budget module', () {
    testWidgets('lists every amount of a done record, newest first', (tester) async {
      await pumpHealthHost(tester, const SizedBox(height: 10));
      final costs = (await settled(tester, healthCostsProvider(kelly))).value!;

      expect(costs.map((c) => c.recordId), ['r-flea', 'r-limp', 'r-rabies', 'r-dental']);
      final limp = costs[1];
      expect(limp.amount, 320);
      expect(limp.currency, 'ILS');
      expect(limp.category, HealthCostCategory.vetVisit);
      expect(limp.title, 'Limping after a long walk');
      expect(limp.date, DateTime(2025, 5, 2, 8, 15));
      expect(limp.petId, kelly);
      expect(costs.first.category, HealthCostCategory.preventive);

      // A pet with nothing entered is an empty list, not an error.
      expect((await settled(tester, healthCostsProvider('soya'))).value, isEmpty);
    });

    testWidgets('adds them up by month and category', (tester) async {
      await pumpHealthHost(tester, const SizedBox(height: 10));
      final months = (await settled(tester, healthCostsByMonthProvider(kelly))).value!;

      expect(months.map((m) => m.month), [DateTime(2025, 5), DateTime(2025, 3), DateTime(2025, 1)]);
      final may = months.first;
      expect(may.total, 405);
      expect(may.currency, 'ILS');
      expect(may.count, 2);
      expect(may.byCategory, {HealthCostCategory.preventive: 85, HealthCostCategory.vetVisit: 320});
      expect(months.last.total, 649.9);
      expect(months.last.byCategory.keys, [HealthCostCategory.procedure]);
    });

    testWidgets('follows the records and reports a load error', (tester) async {
      final h = await pumpHealthHost(tester, const SizedBox(height: 10));
      final container = hostContainer(tester);
      expect((await settled(tester, healthCostsProvider(kelly))).value, hasLength(4));

      final records = (await settled(tester, healthRecordsProvider(kelly))).value!;
      final worm = records.firstWhere((r) => r.id == 'r-worm');
      container
          .read(healthRecordsProvider(kelly).notifier)
          .save(
            HealthRecord(
              id: worm.id,
              petId: worm.petId,
              kind: worm.kind,
              title: worm.title,
              scheduledAt: worm.scheduledAt,
              doneAt: worm.doneAt,
              costAmount: 60,
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      final after = (await settled(tester, healthCostsProvider(kelly))).value!;
      expect(after.map((c) => c.recordId), contains('r-worm'));

      h.repository.failing = true;
      final failed = await settled(tester, healthCostsProvider('soya'));
      expect(failed.hasError, isTrue);
      expect(healthErrorMessage(failed.error!), contains('Could not reach the server'));
    });

    test('amounts in cents add up exactly, and currencies are kept apart', () {
      HealthRecord record(String id, double amount, {String currency = 'ILS', RecordKind kind = RecordKind.medicine}) =>
          HealthRecord(
            id: id,
            petId: kelly,
            kind: kind,
            title: id,
            scheduledAt: DateTime(2025, 6, 3),
            doneAt: DateTime(2025, 6, 3),
            costAmount: amount,
            costCurrency: currency,
          );
      final months = healthCostsByMonth(
        healthCostsOf([
          record('a', 0.1),
          record('b', 0.2),
          record('c', 10, currency: 'EUR'),
          record('d', 5, kind: RecordKind.document),
        ]),
      );
      expect(months, hasLength(2));
      final ils = months.firstWhere((m) => m.currency == 'ILS');
      expect(ils.total, 5.3);
      expect(ils.byCategory[HealthCostCategory.medicine], 0.3);
      expect(ils.byCategory[HealthCostCategory.other], 5);
      expect(months.firstWhere((m) => m.currency == 'EUR').total, 10);
    });
  });
}
