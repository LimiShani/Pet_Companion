import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';

import 'health_test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const kelly = 'kelly';
  final today = DateTime(2025, 6, 10);
  final yesterday = DateTime(2025, 6, 9);

  Future<HealthHarness> openSchedule(WidgetTester tester, {HealthHarness? harness}) async {
    final h = await pumpHealth(tester, harness: harness);
    await openSection(tester, 'Schedule');
    return h;
  }

  Future<List<CareLog>> logs(WidgetTester tester, HealthHarness h, {String petId = kelly}) =>
      real(tester, () => h.repository.fetchLogs(petId, from: DateTime(2025, 5, 1)));

  group('Schedule', () {
    testWidgets('shows today, what is coming up and what needs review', (tester) async {
      await openSchedule(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('· Tue 10 June'), findsOneWidget);

      // Open items, in time order.
      expect(find.byKey(const ValueKey('today-p-walk')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-p-dinner')), findsOneWidget);
      expect(find.text('1 tablet · due 20:00'), findsOneWidget);
      final walk = tester.getTopLeft(find.byKey(const ValueKey('today-p-walk'))).dy;
      final dinner = tester.getTopLeft(find.byKey(const ValueKey('today-p-dinner'))).dy;
      final tablets = tester.getTopLeft(find.byKey(const ValueKey('today-p-joint-pm'))).dy;
      expect(walk, lessThan(dinner));
      expect(dinner, lessThan(tablets));
      // A routine of another weekday is not due.
      expect(find.byKey(const ValueKey('today-p-brush')), findsNothing);

      // What is answered folds into one row.
      expect(find.text('Done today · 2'), findsOneWidget);
      expect(find.text('Breakfast 07:30 · Joint tablets given 08:05'), findsOneWidget);

      // Appointments and due dates with a date badge.
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('General check'), findsOneWidget);
      expect(find.text('Vet visit · Thu 18:20 · Park Vet Clinic'), findsOneWidget);
      expect(find.text('Rabies booster due'), findsOneWidget);
      expect(find.text('Vaccination · date given by the vet'), findsOneWidget);
      expect(find.text('Mar 26'), findsOneWidget);

      // Nobody answered yesterday evening's reminder. It is not "missed".
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Mon 09.06.25 · 20:00 · no answer recorded'), findsOneWidget);
      expect(find.textContaining('missed dose'), findsNothing);
      expect(find.textContaining('Nothing is counted as missed'), findsOneWidget);

      // The whole plan, including what is not due today.
      expect(find.text('Medicines and routines'), findsOneWidget);
      expect(find.text('08:00, 20:00 · Every day'), findsOneWidget);
      expect(find.text('Grooming · 10:00 · Sat'), findsOneWidget);
    });

    testWidgets('a routine is ticked with one tap and can be undone', (tester) async {
      final h = await openSchedule(tester);

      await tapVisible(tester, find.byKey(const ValueKey('tick-p-walk')));
      expect(find.byKey(const ValueKey('today-p-walk')), findsNothing);
      expect(find.text('Done today · 3'), findsOneWidget);

      var saved = (await logs(tester, h)).where((l) => l.planItemId == 'p-walk').single;
      expect(saved.status, CareLogStatus.done);
      expect(saved.dueOn, today);
      expect(saved.loggedByName, 'Alex');
      expect(saved.loggedAt, fixedNow);

      await tapVisible(tester, find.byKey(const Key('done-today')));
      await tapVisible(tester, find.byKey(const ValueKey('undo-p-walk')));
      expect(find.byKey(const ValueKey('today-p-walk')), findsOneWidget);
      expect((await logs(tester, h)).where((l) => l.planItemId == 'p-walk'), isEmpty);
    });

    testWidgets('an empty schedule offers to add something', (tester) async {
      await openSchedule(tester);
      await selectPet(tester, 'Soya');

      expect(find.text('Nothing scheduled yet'), findsOneWidget);
      await tapVisible(tester, find.text('Add to the schedule'));
      expect(find.text('Appointment or due date'), findsOneWidget);
      expect(find.text('Medicine'), findsOneWidget);
      expect(find.text('Routine'), findsOneWidget);
    });

    testWidgets('an upcoming appointment opens, and is marked as done', (tester) async {
      final h = await openSchedule(tester);

      await tapVisible(tester, find.byKey(const ValueKey('planned-r-check')));
      expect(find.text('Planned for'), findsOneWidget);
      expect(find.text('12.06.25 · 18:20'), findsOneWidget);
      expect(find.text('Yearly check at the vet. Bring the vaccination booklet.'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('record-mark-done')));
      expect(find.text('Planned for'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('planned-r-check')), findsNothing);
      final record = (await real(tester, () => h.repository.fetchRecords(kelly))).firstWhere((r) => r.id == 'r-check');
      // Marked before its planned time: done now.
      expect(record.doneAt, fixedNow);
    });

    testWidgets('an appointment whose day passed waits for an answer', (tester) async {
      final h = HealthHarness()..now = DateTime(2025, 6, 13, 9);
      await openSchedule(tester, harness: h);

      expect(find.byKey(const ValueKey('planned-r-check')), findsNothing);
      expect(find.text('Thu 12.06.25 · 18:20 · not marked as done'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('review-done-r-check')));
      expect(find.byKey(const ValueKey('review-record-r-check')), findsNothing);
      final record = (await real(tester, () => h.repository.fetchRecords(kelly))).firstWhere((r) => r.id == 'r-check');
      expect(record.doneAt, DateTime(2025, 6, 12, 18, 20));

      await openSection(tester, 'History');
      expect(find.text('General check'), findsOneWidget);
    });
  });

  group('Record dose', () {
    testWidgets('records a dose given now, with a note and who logged it', (tester) async {
      final h = await openSchedule(tester);

      await tapVisible(tester, find.byKey(const ValueKey('record-p-joint-pm')));
      expect(find.text('Joint tablets 50 mg'), findsWidgets);
      expect(find.text('Reminder for today · 20:00'), findsOneWidget);
      // The vet's instructions, exactly as typed.
      expect(find.text("Vet's instructions: 1 tablet by mouth, twice a day with food."), findsOneWidget);
      expect(find.text('Given now · 17:40'), findsOneWidget);
      expect(find.textContaining('Saved as logged by Alex'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('dose-note')), 'Hidden in cheese');
      await tapVisible(tester, find.byKey(const Key('dose-given-now')));

      expect(find.byKey(const ValueKey('today-p-joint-pm')), findsNothing);
      expect(find.text('Done today · 3'), findsOneWidget);
      final saved = (await logs(tester, h)).where((l) => l.planItemId == 'p-joint-pm' && l.dueOn == today).single;
      expect(saved.status, CareLogStatus.done);
      expect(saved.doneAt, fixedNow);
      expect(saved.note, 'Hidden in cheese');
      expect(saved.loggedByName, 'Alex');
      expect(saved.medicationId, 'm-joint');
    });

    testWidgets('a time that is still ahead cannot be recorded as given', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const ValueKey('record-p-joint-pm')));

      await tapVisible(tester, find.byKey(const Key('dose-given-other')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('That time is still ahead. Record the dose once it is given.'), findsOneWidget);
      expect((await logs(tester, h)).where((l) => l.planItemId == 'p-joint-pm' && l.dueOn == today), isEmpty);

      await tapVisible(tester, find.byKey(const Key('dose-not-given')));
      final saved = (await logs(tester, h)).where((l) => l.planItemId == 'p-joint-pm' && l.dueOn == today).single;
      expect(saved.status, CareLogStatus.skipped);
      expect(saved.doneAt, isNull);
    });

    testWidgets('a reminder needing review takes Given, Not given or Not sure', (tester) async {
      final h = await openSchedule(tester);
      const tag = 'p-joint-pm-09.06.25';

      await tapVisible(tester, find.byKey(const ValueKey('review-not-sure-$tag')));
      expect(find.text('Needs review'), findsNothing);
      var saved = (await logs(tester, h)).where((l) => l.planItemId == 'p-joint-pm' && l.dueOn == yesterday).single;
      // "Not sure" stops the question without claiming anything about the dose.
      expect(saved.status, CareLogStatus.unknown);
      expect(saved.doneAt, isNull);
    });

    testWidgets('a past reminder can be answered with the time it was given', (tester) async {
      final h = await openSchedule(tester);

      // The row itself (not one of its three buttons) opens the full sheet.
      await tapVisible(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('review-p-joint-pm-09.06.25')),
          matching: find.text('Joint tablets'),
        ),
      );
      expect(find.text('Reminder for yesterday · 20:00'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('dose-given-other')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Needs review'), findsNothing);
      final saved = (await logs(tester, h)).where((l) => l.planItemId == 'p-joint-pm' && l.dueOn == yesterday).single;
      expect(saved.status, CareLogStatus.done);
      expect(saved.doneAt, DateTime(2025, 6, 9, 20));
      expect(saved.loggedAt, fixedNow);
    });

    testWidgets('the Overview leads with the next dose and records it', (tester) async {
      final h = HealthHarness()..now = DateTime(2025, 6, 10, 19, 45);
      await pumpHealth(tester, harness: h);

      expect(find.text('Today · 20:00'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('overview-record-dose')));
      await tapVisible(tester, find.byKey(const Key('dose-given-now')));

      expect(find.text('Last recorded dose: today 19:45'), findsOneWidget);
      expect(find.byKey(const Key('overview-record-dose')), findsNothing);
    });
  });

  group('Medicines', () {
    testWidgets('a medicine is added with its instructions and a reminder time', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const Key('schedule-add')));
      await tapVisible(tester, find.byKey(const ValueKey('add-medicine')));
      expect(find.text('New medicine'), findsOneWidget);

      // Only the name is required.
      await tapVisible(tester, find.text('Save medicine'));
      expect(find.text('Enter the name of the medicine.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('medicine-name')), 'Ear drops');
      await tester.enterText(find.byKey(const Key('medicine-dose')), '3 drops');
      await tapVisible(tester, find.byKey(const ValueKey('route-In the ear')));
      await tester.enterText(find.byKey(const Key('medicine-frequency')), 'Once a day for ten days');
      expect(find.text('No reminder times: a medicine given only when needed.'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('medicine-add-time')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('time-08:00')), findsOneWidget);
      expect(find.text('Every day'), findsOneWidget);

      await tapVisible(tester, find.text('Save medicine'));
      expect(find.text('New medicine'), findsNothing);
      expect(find.text('3 drops in the ear, once a day for ten days'), findsOneWidget);
      expect(find.text('08:00 · Every day'), findsOneWidget);
      // Its reminder of this morning is open, waiting for an answer.
      expect(find.text('3 drops · due 08:00'), findsOneWidget);

      final medications = await real(tester, () => h.repository.fetchMedications(kelly));
      final saved = medications.firstWhere((m) => m.name == 'Ear drops');
      expect(saved.route, 'In the ear');
      expect(saved.startsOn, today);
      final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
      final reminder = items.where((i) => i.medicationId == saved.id).single;
      expect(reminder.time, const TimeOfDay(hour: 8, minute: 0));
      // Reminders count from the day they are set up: nothing to review.
      expect(reminder.startsOn, today);
      // The reminder hook received the new plan.
      expect(h.scheduler.last.items.map((i) => i.id), contains(reminder.id));
    });

    testWidgets('a medicine without reminder times is recorded when needed', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const Key('schedule-add')));
      await tapVisible(tester, find.byKey(const ValueKey('add-medicine')));
      await tester.enterText(find.byKey(const Key('medicine-name')), 'Calming drops');
      await tapVisible(tester, find.text('Save medicine'));

      expect(find.text('Only when needed'), findsOneWidget);
      final saved = (await real(
        tester,
        () => h.repository.fetchMedications(kelly),
      )).firstWhere((m) => m.name == 'Calming drops');
      await tapVisible(tester, find.byKey(ValueKey('record-as-needed-${saved.id}')));
      expect(find.text('Given when needed · Kelly'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('dose-given-now')));

      final log = (await logs(tester, h)).where((l) => l.medicationId == saved.id).single;
      expect(log.planItemId, isNull);
      expect(log.status, CareLogStatus.done);
      expect(log.doneAt, fixedNow);
    });

    testWidgets('editing a medicine shows its dose log and changes its reminders', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const ValueKey('medicine-m-joint')));

      expect(find.text('Edit medicine'), findsOneWidget);
      expect(find.text('Dose log'), findsOneWidget);
      expect(find.text('Given 08:05'), findsWidgets);
      expect(find.text('10.06.25 · reminder 08:00 · logged by Alex'), findsOneWidget);
      expect(find.byKey(const ValueKey('time-08:00')), findsOneWidget);
      expect(find.byKey(const ValueKey('time-20:00')), findsOneWidget);

      // Remove the evening reminder.
      await tester.ensureVisible(find.byKey(const ValueKey('time-20:00')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove 20:00'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('medicine-frequency')), 'Once a day with food');
      await tapVisible(tester, find.text('Save medicine'));

      expect(find.text('Edit medicine'), findsNothing);
      expect(find.text('08:00 · Every day'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-p-joint-pm')), findsNothing);
      final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
      expect(items.where((i) => i.medicationId == 'm-joint').map((i) => i.id), ['p-joint-am']);
    });

    testWidgets('a medicine is deleted only after a confirmation', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const ValueKey('medicine-m-joint')));

      await tester.tap(find.byTooltip('Delete medicine'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this medicine?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit medicine'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete medicine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Edit medicine'), findsNothing);
      expect(find.byKey(const ValueKey('medicine-m-joint')), findsNothing);
      expect(find.text('Needs review'), findsNothing);
      expect(await real(tester, () => h.repository.fetchMedications(kelly)), isEmpty);
      final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
      expect(items.where((i) => i.isMedication), isEmpty);
    });
  });

  group('Routines', () {
    testWidgets('a routine is added with a kind, a time and days', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const Key('schedule-add')));
      await tapVisible(tester, find.byKey(const ValueKey('add-routine')));
      expect(find.text('New routine'), findsOneWidget);

      await tapVisible(tester, find.text('Save routine'));
      expect(find.text('Give the routine a title.'), findsOneWidget);

      // The title follows the kind until the owner types one.
      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-walk')));
      expect(find.widgetWithText(TextFormField, 'Walk'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('routine-title')), 'Morning walk');

      await tapVisible(tester, find.byKey(const Key('routine-time')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Weekdays only.
      await tapVisible(tester, find.byKey(const ValueKey('day-6')));
      await tapVisible(tester, find.byKey(const ValueKey('day-7')));
      expect(find.text('Weekdays'), findsOneWidget);

      await tapVisible(tester, find.text('Save routine'));
      expect(find.text('New routine'), findsNothing);
      expect(find.text('Walk · 08:00 · Weekdays'), findsOneWidget);

      final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
      final saved = items.firstWhere((i) => i.title == 'Morning walk');
      expect(saved.kind, CareKind.walk);
      expect(saved.days, {1, 2, 3, 4, 5});
      expect(saved.active, isTrue);
      // A routine nobody ticked never needs review.
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Morning walk.*no answer')), findsNothing);
    });

    testWidgets('a routine can be paused and deleted', (tester) async {
      final h = await openSchedule(tester);
      await tapVisible(tester, find.byKey(const ValueKey('routine-p-dinner')));
      expect(find.text('Edit routine'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('routine-active')));
      expect(find.text('Paused: kept here, but not due'), findsOneWidget);
      await tapVisible(tester, find.text('Save routine'));

      expect(find.byKey(const ValueKey('today-p-dinner')), findsNothing);
      expect(find.text('Paused'), findsOneWidget);
      // A paused routine is not handed to the reminder hook.
      expect(h.scheduler.last.items.map((i) => i.id), isNot(contains('p-dinner')));

      await tapVisible(tester, find.byKey(const ValueKey('routine-p-dinner')));
      await tester.tap(find.byTooltip('Delete routine'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this routine?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('routine-p-dinner')), findsNothing);
      final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
      expect(items.map((i) => i.id), isNot(contains('p-dinner')));
    });
  });
}
