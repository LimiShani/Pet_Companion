import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/basket/basket_view.dart';
import 'package:pet_companion/features/care/care.dart';
import 'package:pet_companion/features/firstdays/first_days_screen.dart';
import 'package:pet_companion/features/home/widgets/activity_card.dart';
import 'package:pet_companion/features/home/widgets/feeding_card.dart';
import 'package:pet_companion/features/pets/pets.dart' show PetReminderCard;
import 'package:pet_companion/features/today/today_card.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/presentation/dashboard_card.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/state/schedule_logic.dart';
import 'package:pet_companion/services/today/today_providers.dart';

import '../helpers.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The sample day, in the afternoon: Kelly's breakfast and morning dose
  // are logged, the evening walk, dinner and evening dose are still to do.
  final afternoon = DateTime(2025, 6, 10, 15);
  final en = lookupTodayL10n(englishLocale);

  Future<void> pumpHome(WidgetTester tester, {AppLanguage? language, List<Override> overrides = const []}) async {
    await pumpApp(tester, now: afternoon, language: language, overrides: overrides);
    await signInAsDemo(tester);
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // Centred: at the top of a long Home it would sit under the pinned bar.
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder row(String id) => find.byKey(TodayCard.rowKey(id));
  Finder tick(String id) => find.byKey(TodayCard.tickKey(id));
  Finder inRow(String id, String text) => find.descendant(of: row(id), matching: find.text(text));
  Finder inCard(String text) => find.descendant(of: find.byKey(TodayCard.cardKey), matching: find.text(text));

  testWidgets('Today lists the day of both pets, with their names, in order', (tester) async {
    await pumpHome(tester);

    expect(inCard(en.title), findsOneWidget);
    expect(inCard(en.headerDone('Tue 10 June', 2, 5)), findsOneWidget);
    expect(inRow('kelly:p-walk', en.withPet('Evening walk', 'Kelly')), findsOneWidget);
    expect(inRow('kelly:p-walk', '18:30'), findsOneWidget);
    expect(inRow('kelly:p-dinner', en.withPet('Dinner', 'Kelly')), findsOneWidget);
    expect(inRow('kelly:p-joint-pm', en.withPet('Joint tablets', 'Kelly')), findsOneWidget);
    expect(inRow('basket:b-kelly-food', en.withPet(en.runsOutIn(3, 'Adult dry food'), 'Kelly')), findsOneWidget);
    expect(inRow('firstdays:soya', en.firstDaysLine('10')), findsOneWidget);
    expect(inRow('essentials:soya', "Finish Soya's profile"), findsOneWidget);
    expect(inRow('kelly:p-breakfast', en.doneBy('07:35', en.you)), findsOneWidget);
    expect(inRow('kelly:p-joint-am', en.doneBy('08:05', en.you)), findsOneWidget);

    // To do by time, then the undated rows, then what is done.
    final order = [
      'kelly:p-walk',
      'kelly:p-dinner',
      'kelly:p-joint-pm',
      'basket:b-kelly-food',
      'firstdays:soya',
      'essentials:soya',
      'kelly:p-breakfast',
      'kelly:p-joint-am',
    ];
    for (var i = 1; i < order.length; i++) {
      expect(tester.getTopLeft(row(order[i - 1])).dy, lessThan(tester.getTopLeft(row(order[i])).dy), reason: order[i]);
    }
    // A done row is faded; every row is a comfortable tap target.
    expect(find.ancestor(of: row('kelly:p-breakfast'), matching: find.byType(Opacity)), findsNothing);
    expect(find.descendant(of: row('kelly:p-breakfast'), matching: find.byType(Opacity)), findsOneWidget);
    for (final id in order) {
      expect(tester.getSize(row(id)).height, greaterThanOrEqualTo(48), reason: id);
    }

    // The compact essentials reminder and the Running low card left Home.
    expect(find.byType(PetReminderCard), findsNothing);
    expect(find.text('Running low'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a meal tick logs the planned dinner as "you" with the usual portion; ticking again within the hour undoes it', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.text('504')), findsOneWidget);

    await tapVisible(tester, tick('kelly:p-dinner'));
    expect(inRow('kelly:p-dinner', en.doneBy('15:00', en.you)), findsOneWidget);
    expect(inCard(en.headerDone('Tue 10 June', 3, 5)), findsOneWidget);
    // 140 g of Kelly's food: 504 cal again.
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.text('1,008')), findsOneWidget);
    // Done rows sink: dinner now comes after the undated rows.
    expect(tester.getTopLeft(row('kelly:p-dinner')).dy, greaterThan(tester.getTopLeft(row('essentials:soya')).dy));

    await tapVisible(tester, tick('kelly:p-dinner'));
    expect(inRow('kelly:p-dinner', '19:30'), findsOneWidget);
    expect(inCard(en.headerDone('Tue 10 June', 2, 5)), findsOneWidget);
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.text('504')), findsOneWidget);
  });

  testWidgets('a row done more than an hour ago opens its sheet instead of being undone', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, tick('kelly:p-breakfast'));
    expect(find.text('Log a meal'), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(inRow('kelly:p-breakfast', en.doneBy('07:35', en.you)), findsOneWidget);
  });

  testWidgets('a walk tick records the planned walk with its minutes', (tester) async {
    await pumpHome(tester);
    expect(find.descendant(of: find.byType(ActivityCard), matching: find.text(isolate('1/2'))), findsOneWidget);

    await tapVisible(tester, tick('kelly:p-walk'));
    expect(inRow('kelly:p-walk', en.doneBy('15:00', en.you)), findsOneWidget);
    // The morning walk's 25 minutes and this one's 30.
    expect(find.descendant(of: find.byType(ActivityCard), matching: find.text(isolate('2/2'))), findsOneWidget);
    expect(find.descendant(of: find.byType(ActivityCard), matching: find.text(isolate('55'))), findsOneWidget);
  });

  testWidgets('a dose tick records it as given now; the row body opens "Record dose"', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, find.text(en.withPet('Joint tablets', 'Kelly')).first);
    expect(find.byKey(const Key('dose-given-now')), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tapVisible(tester, tick('kelly:p-joint-pm'));
    expect(inRow('kelly:p-joint-pm', en.doneBy('15:00', en.you)), findsOneWidget);
    expect(inCard(en.headerDone('Tue 10 June', 3, 5)), findsOneWidget);
  });

  testWidgets('the meal row opens "Log a meal" on that meal', (tester) async {
    await pumpHome(tester);

    await tapVisible(tester, find.text(en.withPet('Dinner', 'Kelly')));
    expect(find.text('Log a meal'), findsOneWidget);
    final dinner = find.widgetWithText(ChoiceChip, '${isolate('Dinner')} · ${isolate('19:30')}');
    expect(tester.widget<ChoiceChip>(dinner).selected, isTrue);
    await tapVisible(tester, find.byKey(LogMealSheet.saveKey));
    expect(find.descendant(of: find.byType(FeedingCard), matching: find.text('1,008')), findsOneWidget);
    expect(inRow('kelly:p-dinner', en.doneBy('15:00', en.you)), findsOneWidget);
  });

  testWidgets('the runs-out row opens the basket, the first days row its page, the essentials row the checklist', (
    tester,
  ) async {
    await pumpHome(tester);

    await tapVisible(tester, row('basket:b-kelly-food'));
    expect(find.byKey(BasketView.viewKey), findsOneWidget);
    Navigator.of(tester.element(find.byKey(BasketView.viewKey)), rootNavigator: true).pop();
    await tester.pumpAndSettle();

    await tapVisible(tester, row('firstdays:soya'));
    expect(find.byKey(FirstDaysScreen.screenKey), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, row('essentials:soya'));
    expect(find.text(lookupPetsL10n(englishLocale).checklistTitle('Soya')), findsOneWidget);
  });

  testWidgets('an empty day says so, and offers to set up feeding for a pet without meal times', (tester) async {
    await pumpHome(
      tester,
      overrides: [
        todayProvider.overrideWithValue(AsyncData(TodayDay(now: afternoon, items: const [], petCount: 2))),
      ],
    );
    expect(inCard(en.empty), findsOneWidget);
    expect(inCard('Tue 10 June'), findsOneWidget);
    // Kelly has meal times.
    expect(find.byKey(TodayCard.setUpKey), findsNothing);

    await tester.tap(find.text('Soya'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(TodayCard.setUpKey));
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
    expect(find.text('Feeding · Soya'), findsOneWidget);
  });

  testWidgets('more than five done rows fold into one "N done" row that opens', (tester) async {
    final items = [
      for (var hour = 6; hour < 12; hour++)
        () {
          final item = CarePlanItem(
            id: 'r$hour',
            petId: 'kelly',
            kind: CareKind.grooming,
            title: 'Routine $hour',
            time: TimeOfDay(hour: hour, minute: 0),
          );
          final due = DateTime(2025, 6, 10, hour);
          return TodayItem(
            id: 'kelly:r$hour',
            kind: TodayKind.routine,
            petId: 'kelly',
            title: item.title,
            time: due,
            entry: ScheduleEntry(
              item: item,
              due: due,
              log: CareLog(
                id: 'l$hour',
                petId: 'kelly',
                planItemId: item.id,
                title: item.title,
                dueOn: DateTime(2025, 6, 10),
                status: CareLogStatus.done,
                doneAt: due,
                loggedAt: due,
              ),
            ),
          );
        }(),
    ];
    await pumpHome(
      tester,
      overrides: [
        todayProvider.overrideWithValue(AsyncData(TodayDay(now: afternoon, items: items, petCount: 2))),
      ],
    );
    expect(inCard(en.headerDone('Tue 10 June', 6, 6)), findsOneWidget);
    expect(inCard(en.foldDone(6)), findsOneWidget);
    expect(row('kelly:r6'), findsNothing);

    await tapVisible(tester, find.byKey(TodayCard.foldKey));
    for (var hour = 6; hour < 12; hour++) {
      expect(row('kelly:r$hour'), findsOneWidget);
    }
  });

  testWidgets('the Home cards keep their status but lose their pills; each opens its page', (tester) async {
    await pumpHome(tester);

    for (final card in [FeedingCard, ActivityCard]) {
      expect(find.descendant(of: find.byType(card), matching: find.byType(CarePillButton)), findsNothing);
      expect(find.descendant(of: find.byType(card), matching: find.byKey(DashboardCard.chevronKey)), findsOneWidget);
    }
    expect(find.text('Fed'), findsNothing);
    expect(find.text('Walk'), findsNothing);
    expect(find.text('Next feeding · 19:30'), findsOneWidget);

    await tapVisible(tester, find.byType(FeedingCard));
    expect(find.byKey(FeedingScreen.screenKey), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byType(ActivityCard));
    expect(find.byKey(ActivityScreen.screenKey), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('General check'));
    expect(find.text('Schedule'), findsWidgets);
  });

  testWidgets('Today reads in Hebrew', (tester) async {
    await pumpHome(tester, language: AppLanguage.hebrew);
    final he = lookupTodayL10n(hebrewLocale);

    expect(inCard(he.title), findsOneWidget);
    expect(inRow('kelly:p-breakfast', he.doneBy('07:35', he.you)), findsOneWidget);
    expect(inRow('kelly:p-dinner', he.withPet('Dinner', 'Kelly')), findsOneWidget);
    expect(inRow('basket:b-kelly-food', he.withPet(he.runsOutIn(3, 'Adult dry food'), 'Kelly')), findsOneWidget);

    await tapVisible(tester, tick('kelly:p-dinner'));
    expect(inRow('kelly:p-dinner', he.doneBy('15:00', he.you)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
