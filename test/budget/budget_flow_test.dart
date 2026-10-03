import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/budget/basket/basket_item_form_screen.dart';
import 'package:pet_companion/features/budget/basket/bought_again_dialog.dart';
import 'package:pet_companion/features/budget/budget.dart';
import 'package:pet_companion/features/budget/budget_screen.dart' show BudgetEntryTile;
import 'package:pet_companion/features/budget/expense_form_screen.dart';
import 'package:pet_companion/features/budget/widgets/budget_widgets.dart';
import 'package:pet_companion/l10n/l10n.dart';

import 'budget_test_helpers.dart';

// The sample budget on 10 June 2025 (see FakeBudgetRepository):
//   June: the dog walker ₪200 (every month since April), a rope toy ₪45,
//         a lint roller for the home ₪35 = ₪280.
//   May:  food ₪240, dental chews ₪59, poop bags ₪29, the yearly insurance
//         ₪600, the walker ₪200, Soya's grooming ₪150, and from Health the
//         flea tablet ₪85 and the vet visit ₪320 = ₪1,683.

Finder _total() => find.byKey(BudgetScreen.totalKey);

String _text(WidgetTester tester, Finder finder) => stripBidiMarks(tester.widget<Text>(finder).data!);

/// A text on screen as it reads, without the invisible direction marks
/// that keep amounts and names whole (rich text included).
Finder plain(String text) => find.byWidgetPredicate(
  (widget) => widget is Text && stripBidiMarks(widget.data ?? widget.textSpan?.toPlainText() ?? '') == text,
  description: 'text "$text"',
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Home cards', () {
    testWidgets("show this month's spending and what runs low, and open their pages", (tester) async {
      await pumpBudgetApp(tester);

      final spending = find.byKey(SpendingCard.cardKey);
      await tester.ensureVisible(spending);
      expect(find.descendant(of: spending, matching: plain("This month's spending")), findsOneWidget);
      expect(find.descendant(of: spending, matching: plain('All the home')), findsOneWidget);
      expect(find.descendant(of: spending, matching: plain('₪280')), findsOneWidget);
      expect(find.descendant(of: spending, matching: plain('↓ 83% from May')), findsOneWidget);
      expect(find.descendant(of: spending, matching: plain('Services ₪200 · Equipment ₪45')), findsOneWidget);

      final low = find.byKey(RunningLowCard.cardKey);
      await tester.ensureVisible(low);
      expect(find.descendant(of: low, matching: plain('runs out in 3 days')), findsOneWidget);
      expect(find.descendant(of: low, matching: find.textContaining('Adult dry food')), findsOneWidget);

      await tapVisible(tester, spending);
      expect(find.byKey(BudgetScreen.screenKey), findsOneWidget);
      expect(_text(tester, _total()), '₪280');
      await tester.pageBack();
      await settle(tester);

      // The title, not the middle of the card, where "Bought again" may be.
      await tapVisible(tester, find.descendant(of: low, matching: plain('Running low')));
      expect(find.byKey(BasketView.viewKey), findsOneWidget);
    });

    testWidgets('"Bought again" on the card records the expense and the card goes away', (tester) async {
      await pumpBudgetApp(tester);

      await tapVisible(tester, find.byKey(const ValueKey('home-bought-b-kelly-food')));
      expect(plain('Bought again: Adult dry food'), findsOneWidget);
      // Last time's price, ready to change.
      expect(find.widgetWithText(TextFormField, '240'), findsOneWidget);
      await tapVisible(tester, find.byKey(BoughtAgainDialog.saveKey));

      expect(plain('₪240 added to the budget'), findsOneWidget);
      expect(find.byKey(RunningLowCard.cardKey), findsNothing);
      final spending = find.byKey(SpendingCard.cardKey);
      expect(find.descendant(of: spending, matching: plain('₪520')), findsOneWidget);
    });

    testWidgets('neither card shows without expenses or products', (tester) async {
      await pumpBudgetApp(tester, budget: FakeBudgetRepository(latency: Duration.zero, seeded: false));
      expect(find.byKey(SpendingCard.cardKey), findsNothing);
      expect(find.byKey(RunningLowCard.cardKey), findsNothing);
      // The rest of Home is there as usual.
      expect(plain('Feeding'), findsOneWidget);
    });
  });

  group('Budget page', () {
    testWidgets('switches month, compares with the month before and lists the lines with their sources', (
      tester,
    ) async {
      await pumpBudgetApp(tester);
      await openBudgetFromMenu(tester);

      expect(plain('June 2025'), findsOneWidget);
      expect(_text(tester, _total()), '₪280');
      expect(plain('May: ₪1,683'), findsOneWidget);
      expect(plain('↓ 83% from May'), findsOneWidget);
      expect(find.textContaining('Monthly average: '), findsOneWidget);
      expect(plain('Rope toy'), findsOneWidget);
      expect(plain('Dog walker'), findsOneWidget);
      expect(plain('every month'), findsOneWidget);
      expect(find.textContaining('Whole home'), findsOneWidget);
      // The future has no expenses yet.
      final next = tester.widget<IconButton>(find.byKey(MonthSwitcher.nextKey));
      expect(next.onPressed, isNull);

      await tapVisible(tester, find.byKey(MonthSwitcher.previousKey));
      expect(plain('May 2025'), findsOneWidget);
      expect(_text(tester, _total()), '₪1,683');
      expect(plain('April: ₪200'), findsOneWidget);
      // Health's costs are read, not copied: in "Vet and medicines" and
      // tagged as coming from Health.
      expect(plain('Vet and medicines'), findsOneWidget);
      Finder tile(String title) => find.ancestor(of: plain(title), matching: find.byType(BudgetEntryTile));
      await scrollTo(tester, plain('Flea and tick tablet'));
      expect(find.descendant(of: tile('Flea and tick tablet'), matching: plain('from Health')), findsOneWidget);
      expect(find.descendant(of: tile('Poop bags'), matching: plain('from the basket')), findsOneWidget);
      await scrollTo(tester, plain('Limping after a long walk'));
      expect(find.descendant(of: tile('Limping after a long walk'), matching: plain('from Health')), findsOneWidget);
      expect(find.descendant(of: tile('Pet insurance'), matching: plain('every year')), findsOneWidget);
      expect(find.descendant(of: tile('Pet insurance'), matching: plain('manual')), findsOneWidget);

      await scrollTo(tester, find.byKey(MonthSwitcher.nextKey), up: true);
      await tapVisible(tester, find.byKey(MonthSwitcher.nextKey));
      expect(plain('June 2025'), findsOneWidget);
    });

    testWidgets('a pet pill narrows the budget to that pet; "All the home" shows everything again', (tester) async {
      await pumpBudgetApp(tester);
      await openBudgetFromMenu(tester);

      await tapVisible(tester, plain('Soya'));
      expect(_text(tester, _total()), '₪0');
      expect(plain('Nothing spent in this month.'), findsOneWidget);
      await tapVisible(tester, find.byKey(MonthSwitcher.previousKey));
      // Grooming ₪150 and poop bags ₪29.
      expect(_text(tester, _total()), '₪179');

      await tapVisible(tester, plain('Kelly'));
      // May for Kelly: 240 + 59 + 600 + 200 + 85 + 320.
      expect(_text(tester, _total()), '₪1,504');

      await tapVisible(tester, plain('All the home'));
      expect(_text(tester, _total()), '₪1,683');
    });

    testWidgets('adds, edits and deletes an expense', (tester) async {
      await pumpBudgetApp(tester);
      await openBudgetFromMenu(tester);

      await tapVisible(tester, plain('Add expense'));
      expect(plain('New expense'), findsOneWidget);
      // An amount is needed.
      await tapVisible(tester, find.byKey(ExpenseFormScreen.saveKey));
      expect(plain('Enter an amount, like 120'), findsOneWidget);
      await tester.enterText(find.byKey(ExpenseFormScreen.amountKey), '60');
      await tester.enterText(find.byKey(ExpenseFormScreen.noteKey), 'Treats');
      await tapVisible(tester, find.byKey(ExpenseFormScreen.saveKey));

      expect(find.byKey(ExpenseFormScreen.saveKey), findsNothing);
      expect(_text(tester, _total()), '₪340');
      expect(plain('Treats'), findsOneWidget);

      await tapVisible(tester, plain('Treats'));
      expect(plain('Edit expense'), findsOneWidget);
      await tester.enterText(find.byKey(ExpenseFormScreen.amountKey), '80');
      await tapVisible(tester, plain('Every year'));
      expect(find.textContaining('1/12 a month'), findsOneWidget);
      await tapVisible(tester, find.byKey(ExpenseFormScreen.saveKey));
      expect(_text(tester, _total()), '₪360');
      expect(plain('every year'), findsOneWidget);

      await tapVisible(tester, plain('Treats'));
      await tapVisible(tester, find.byKey(ExpenseFormScreen.deleteKey));
      expect(plain('Delete this expense?'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Delete'));
      expect(plain('Expense deleted'), findsOneWidget);
      expect(_text(tester, _total()), '₪280');
      expect(plain('Treats'), findsNothing);
    });

    testWidgets('a recurring expense can be stopped', (tester) async {
      await pumpBudgetApp(tester);
      await openBudgetFromMenu(tester);

      await tapVisible(tester, plain('Dog walker'));
      await tapVisible(tester, find.byKey(ExpenseFormScreen.stopKey));
      expect(plain('Stopped on 10.06.25'), findsOneWidget);
      await tapVisible(tester, find.byKey(ExpenseFormScreen.saveKey));
      // June's payment (the 1st) was before it stopped, so it still counts.
      expect(_text(tester, _total()), '₪280');
    });

    testWidgets('leaving the expense form with changes asks first', (tester) async {
      await pumpBudgetApp(tester);
      await openBudgetFromMenu(tester);

      await tapVisible(tester, plain('Add expense'));
      await tester.enterText(find.byKey(ExpenseFormScreen.amountKey), '12');
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(plain('Discard changes?'), findsOneWidget);
      await tester.tap(plain('Discard'));
      await settle(tester);
      expect(plain('New expense'), findsNothing);
      expect(_text(tester, _total()), '₪280');
    });

    testWidgets('a load failure offers to try again', (tester) async {
      final repo = FakeBudgetRepository(latency: Duration.zero, now: () => sampleAfternoon)
        ..failWith = BudgetFailure.offline;
      await pumpBudgetApp(tester, budget: repo);
      await openBudgetFromMenu(tester);
      expect(plain('Could not load the budget'), findsOneWidget);

      repo.failWith = null;
      await tapVisible(tester, plain('Try again'));
      expect(_text(tester, _total()), '₪280');
    });
  });

  group('My basket', () {
    testWidgets('the Store switches between the deals and the basket', (tester) async {
      await pumpBudgetApp(tester);
      await openBasket(tester);

      expect(plain('Share a deal'), findsNothing);
      expect(plain('Adult dry food · Kelly'), findsOneWidget);
      expect(plain('Dental chews · Kelly'), findsOneWidget);
      expect(plain('Poop bags · Soya'), findsOneWidget);
      // Food works out from the feeding; the others from the owner's number.
      expect(plain('bought 02.05 · ₪240 · runs out 13.06'), findsOneWidget);
      expect(plain('by 280 g a day from feeding'), findsOneWidget);
      expect(plain('bought 29.05 · ₪59 · runs out 26.06'), findsOneWidget);

      await tester.tap(plain('Deals'));
      await settle(tester);
      expect(find.byKey(BasketView.viewKey), findsNothing);
      expect(plain('Share a deal'), findsOneWidget);
    });

    testWidgets('"Bought again" updates the product and the expense appears in the budget', (tester) async {
      await pumpBudgetApp(tester);
      await openBasket(tester);

      await tapVisible(tester, find.byKey(const ValueKey('basket-bought-b-kelly-food')));
      await tester.enterText(find.byKey(BoughtAgainDialog.priceKey), '250');
      await tapVisible(tester, find.byKey(BoughtAgainDialog.saveKey));
      expect(plain('₪250 added to the budget'), findsOneWidget);
      // 10 June + 42 days.
      expect(plain('bought 10.06 · ₪250 · runs out 22.07'), findsOneWidget);

      await tester.tap(plain('Home').last);
      await settle(tester);
      await openBudgetFromMenu(tester);
      expect(_text(tester, _total()), '₪530');
      final line = find.ancestor(of: plain('Adult dry food'), matching: find.byType(BudgetEntryTile));
      expect(find.descendant(of: line, matching: plain('from the basket')), findsOneWidget);
      expect(find.descendant(of: line, matching: plain('₪250')), findsOneWidget);
    });

    testWidgets('adds a regular product with its own duration', (tester) async {
      await pumpBudgetApp(tester);
      await openBasket(tester);

      await tapVisible(tester, plain('Regular product'));
      expect(plain('New regular product'), findsOneWidget);
      await tester.enterText(find.byKey(BasketItemFormScreen.nameKey), 'Pee pads');
      await tapVisible(tester, plain('Consumable'));
      await tester.enterText(find.byKey(BasketItemFormScreen.sizeKey), '30');
      await tapVisible(tester, plain('units'));
      await tester.enterText(find.byKey(BasketItemFormScreen.priceKey), '45');
      await tester.enterText(find.byKey(BasketItemFormScreen.lastsKey), '4');
      await tapVisible(tester, plain('weeks'));
      await tapVisible(tester, find.byKey(BasketItemFormScreen.saveKey));

      expect(plain('Pee pads · Kelly'), findsOneWidget);
      expect(plain('bought 10.06 · ₪45 · runs out 08.07'), findsOneWidget);
    });

    testWidgets('food bought by the feeding shows what the feeding says in the form', (tester) async {
      await pumpBudgetApp(tester);
      await openBasket(tester);

      await tapVisible(tester, plain('Adult dry food · Kelly'));
      expect(plain('Edit product'), findsOneWidget);
      expect(plain('About 42 days, by 280 g a day from feeding.'), findsOneWidget);
      await tester.enterText(find.byKey(BasketItemFormScreen.sizeKey), '6');
      await tester.pump();
      expect(plain('About 21 days, by 280 g a day from feeding.'), findsOneWidget);
    });

    testWidgets('the deals link opens the Store on that category for the pet', (tester) async {
      await pumpBudgetApp(tester);
      await openBasket(tester);

      final link = find.byKey(const ValueKey('basket-deals-b-kelly-food'));
      expect(link, findsOneWidget);
      final label = tester.widget<Text>(find.descendant(of: link, matching: find.byType(Text))).data!;
      final count = int.parse(RegExp(r'^(\d+) deals? on food for dogs$').firstMatch(label)!.group(1)!);

      await tapVisible(tester, link);
      expect(find.byKey(BasketView.viewKey), findsNothing);
      final shown = tester.widget<Text>(find.byKey(const Key('store-deal-count'))).data!;
      expect(shown, startsWith('$count deal'));
      final food = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Food'));
      expect(food.selected, isTrue);
    });

    testWidgets('"Bought again" plans the run-out reminder on the real clock', (tester) async {
      final sink = RecordingSink();
      final now = DateTime.now();
      await pumpBudgetApp(tester, now: now, sink: sink);
      await openBasket(tester);

      await tapVisible(tester, find.byKey(const ValueKey('basket-bought-b-kelly-food')));
      await tapVisible(tester, find.byKey(BoughtAgainDialog.saveKey));

      final reminders = sink.groups['basket:kelly']!;
      final today = DateTime(now.year, now.month, now.day);
      final food = reminders.singleWhere((r) => r.key.startsWith('b-kelly-food@'));
      // 42 days of food; the reminder is 5 days before, at 10:00.
      expect(food.at, DateTime(today.year, today.month, today.day + 37, 10));
      expect(food.title, 'Adult dry food is running low');
      expect(food.body, startsWith('Adult dry food for Kelly runs out in 5 days'));
      expect(food.payload, 'basket:kelly');
    });
  });

  group('Hebrew', () {
    testWidgets('the budget page, the basket and the Home cards read in Hebrew', (tester) async {
      await pumpBudgetApp(tester, language: AppLanguage.hebrew);

      expect(plain('ההוצאות החודש'), findsOneWidget);
      expect(plain('מלאי נמוך'), findsOneWidget);
      expect(plain('נשארו 3 ימים'), findsOneWidget);

      await tapVisible(tester, find.byKey(SpendingCard.cardKey));
      expect(plain('תקציב'), findsOneWidget);
      expect(plain('יוני 2025'), findsOneWidget);
      expect(plain('כל הבית'), findsWidgets);
      expect(plain('הוספת הוצאה'), findsOneWidget);
      expect(plain('לפי קטגוריה'), findsOneWidget);
      await tester.tap(find.byTooltip('חזרה'));
      await settle(tester);

      await openBasket(tester, store: 'חנות', basket: 'הסל שלי');
      expect(plain('קניתי שוב'), findsWidgets);
      await scrollTo(tester, plain('מוצר קבוע'));
      expect(plain('מוצר קבוע'), findsOneWidget);
    });
  });
}
