import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/home/home_screen.dart';
import 'package:pet_companion/features/home/widgets/activity_card.dart';
import 'package:pet_companion/features/home/widgets/feeding_card.dart';
import 'package:pet_companion/features/today/today_card.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The sample day, in the afternoon (see test/home_screen_test.dart).
  final afternoon = DateTime(2025, 6, 10, 15);

  Future<void> pumpHome(WidgetTester tester, {AppLanguage? language}) async {
    await pumpApp(tester, now: afternoon, language: language);
    await signInAsDemo(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // Centred: at the top of a long Home it would sit under the pinned bar.
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // Home's Today rows of Kelly's dinner and evening walk: tapping one (not
  // its tick) opens the sheet on that meal or walk.
  final dinnerRow = find.byKey(TodayCard.rowKey('kelly:p-dinner'));
  final walkRow = find.byKey(TodayCard.rowKey('kelly:p-walk'));

  testWidgets('the dinner row logs dinner with the usual portion and the card counts it', (tester) async {
    await pumpHome(tester);
    expect(find.text('504'), findsOneWidget);

    await tapVisible(tester, dinnerRow);
    expect(find.text('Log a meal'), findsOneWidget);
    // The sheet is on dinner; the usual portion is 140 g.
    expect(find.text('140 g'), findsOneWidget);
    expect(find.text('= 504 cal · Adult dry food'), findsOneWidget);

    // A little more than usual.
    await tapVisible(tester, find.byKey(LogMealSheet.moreKey));
    expect(find.text('150 g'), findsOneWidget);
    expect(find.text('= 540 cal · Adult dry food'), findsOneWidget);
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));

    expect(find.text('Log a meal'), findsNothing);
    expect(find.text('1,044'), findsOneWidget);
    // Both meals of today are answered: the next one is tomorrow's breakfast.
    expect(find.text('Next feeding · tomorrow 07:30'), findsOneWidget);
  });

  testWidgets('a snack is an extra meal and "Did not eat" counts nothing', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, dinnerRow);
    await tapVisible(tester, find.byKey(LogMealSheet.extraKey));
    expect(find.text('Did not eat'), findsNothing); // only for a planned meal
    await tapVisible(tester, find.text('Half'));
    expect(find.text('70 g'), findsOneWidget);
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));
    expect(find.text('756'), findsOneWidget);

    await tapVisible(tester, dinnerRow);
    await tapVisible(tester, find.text('Did not eat'));
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));
    expect(find.text('756'), findsOneWidget);
  });

  testWidgets('the feeding page lists the day, the week, the food and the times', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, find.text('Feeding'));
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
    expect(find.text('Feeding · Kelly'), findsOneWidget);
    expect(find.text('504 / 1,030 cal'), findsOneWidget);
    expect(find.text('140 g · 504 cal'), findsOneWidget);
    expect(find.byKey(WeekBars.chartKey), findsOneWidget);
    expect(find.text('Adult dry food'), findsOneWidget);
    expect(find.text('360 cal per 100 g · 140 g a meal'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);

    // A logged meal can be removed; its time opens again.
    await tapVisible(tester, find.text('140 g · 504 cal'));
    await tapVisible(tester, find.text('Remove'));
    expect(find.text('0 / 1,030 cal'), findsOneWidget);
    expect(find.text('Fed'), findsNWidgets(2));
  });

  testWidgets("the owner's own goal replaces the estimate", (tester) async {
    await pumpHome(tester);
    await tapVisible(tester, find.text('Feeding'));
    await tapVisible(tester, find.text('Adult dry food'));

    expect(find.textContaining('Worked out from the weight (23 kg)'), findsOneWidget);
    expect(find.text('1,030'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('food-own-goal')));
    await tester.enterText(find.byKey(const Key('food-goal')), '900');
    await tapVisible(tester, find.text('Save'));

    expect(find.text('504 / 900 cal'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Goal 900 cal/day'), findsOneWidget);
  });

  testWidgets('Soya: the food is added from the invitation, then calories count', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Soya'));
    await tester.pumpAndSettle();
    expect(find.text("Add Soya's food and meal times to count calories."), findsOneWidget);

    await tapVisible(tester, find.text('Feeding'));
    await tapVisible(tester, find.text('Food and portion').last);
    // No weight: no estimate, the owner sets a goal.
    expect(find.textContaining('Add the weight in the profile'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('food-kcal')), '400');
    await tester.enterText(find.byKey(const Key('food-portion')), '50');
    await tester.enterText(find.byKey(const Key('food-goal')), '0');
    await tapVisible(tester, find.text('Save'));
    expect(find.text('Enter a number from 1 to 100,000'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('food-goal')), '400');
    await tapVisible(tester, find.text('Save'));

    expect(find.text('0 / 400 cal'), findsOneWidget);
    await tapVisible(tester, find.text('Snack or extra meal'));
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));
    expect(find.text('200 / 400 cal'), findsOneWidget);

    // With food but no meal times, the card is the usual one: calories
    // and "Next feeding · not set" (no pill: meals are ticked in Today).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.text('200')), findsOneWidget);
    expect(find.text('Next feeding · not set'), findsOneWidget);
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.byType(CarePillButton)), findsNothing);
  });

  /// The pills on [card] (a Home card's widget type).
  Finder pillsOf(Type card) => find.descendant(of: find.byType(card), matching: find.byType(CarePillButton));

  testWidgets('Soya, nothing set up: one line on Feeding and Activity, no pill, each card opening its page', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text('Soya'));
    await tester.pumpAndSettle();

    expect(find.text("Add Soya's food and meal times to count calories."), findsOneWidget);
    expect(find.text('Add walk times to follow the activity.'), findsOneWidget);
    expect(find.text('Set up'), findsNothing);
    expect(pillsOf(FeedingCard), findsNothing);
    expect(pillsOf(ActivityCard), findsNothing);
    // Nothing to log against yet: no "not set" lines, no "No goal set"
    // label.
    expect(find.text('Next feeding · not set'), findsNothing);
    expect(find.text('Next walk · not set'), findsNothing);
    expect(find.text('No goal set'), findsNothing);

    await tapVisible(tester, find.byType(FeedingCard));
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
    expect(find.text('Feeding · Soya'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byType(ActivityCard));
    expect(find.byKey(ActivityScreen.screenKey), findsOneWidget);
  });

  testWidgets('Kelly: the cards are status only, the next meal and walk on their last line', (tester) async {
    await pumpHome(tester);

    expect(pillsOf(FeedingCard), findsNothing);
    expect(pillsOf(ActivityCard), findsNothing);
    expect(find.text('Next feeding · 19:30'), findsOneWidget);
    expect(find.text('Next walk · 18:30'), findsOneWidget);
    expect(find.text('Set up'), findsNothing);
  });

  testWidgets('a past walk is logged with its minutes', (tester) async {
    await pumpHome(tester);
    expect(find.text(isolate('1/2')), findsOneWidget);

    await tapVisible(tester, walkRow);
    expect(find.text('Going out now'), findsOneWidget);
    await tapVisible(tester, find.text('45'));
    await tapVisible(tester, find.byKey(WalkSheet.saveKey));

    // The evening walk was the open one: 25 + 45 minutes, both walks done.
    expect(find.text(isolate('2/2')), findsOneWidget);
    expect(find.text(isolate('70')), findsOneWidget);
  });

  testWidgets('a walk started now runs on the card until Finish', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, walkRow);
    await tapVisible(tester, find.byKey(WalkSheet.startKey));
    expect(find.textContaining('Walking ·'), findsOneWidget);

    await tapVisible(tester, find.byKey(RunningWalkBox.finishKey));
    // The test clock stands still: the shortest walk is one minute.
    expect(find.text('Saved 1 min'), findsOneWidget);
    expect(find.textContaining('Walking ·'), findsNothing);
    expect(find.text(isolate('2/2')), findsOneWidget);
    expect(find.text(isolate('26')), findsOneWidget);
  });

  testWidgets('the activity page shows the day, the week and the goal', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, find.text('Activity'));
    expect(find.byKey(ActivityScreen.screenKey), findsOneWidget);
    expect(find.text('25 / 60 min'), findsOneWidget);
    expect(find.textContaining('Morning walk', findRichText: true), findsOneWidget);
    expect(find.text('Evening walk'), findsOneWidget); // the walk time below

    await tapVisible(tester, find.text('Minutes of activity a day'));
    await tapVisible(tester, find.text('45 min'));
    expect(find.text('25 / 45 min'), findsOneWidget);
  });

  testWidgets('the health card opens the Health schedule', (tester) async {
    await pumpHome(tester);
    await tapVisible(tester, find.text('General check'));
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Schedule'), findsWidgets);
  });

  testWidgets('the cards and sheets read in Hebrew', (tester) async {
    await pumpHome(tester, language: AppLanguage.hebrew);
    final he = lookupCareL10n(hebrewLocale);

    await tapVisible(tester, dinnerRow);
    expect(find.text(he.logMealTitle), findsOneWidget);
    expect(find.text(he.wholePortion), findsOneWidget);
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));

    await tapVisible(tester, walkRow);
    expect(find.text(he.startNow), findsOneWidget);
    expect(find.text(he.logPast), findsOneWidget);
  });
}
