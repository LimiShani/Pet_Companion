import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/health_format.dart';
import 'package:pet_companion/features/health/health_screen.dart';
import 'package:pet_companion/features/health/health_strings.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

// The Schedule in Hebrew and right to left (its sections, the routine and
// medicine forms, recording a dose), and the owner's week: the order of
// the day chips, and what "Weekdays" and "Weekends" mean.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);
final appEn = lookupAppL10n(englishLocale);

const kelly = 'kelly';

Future<HealthHarness> openSchedule(WidgetTester tester, {HealthHarness? harness, Size size = widePhone}) async {
  final h = await pumpHealth(tester, harness: harness ?? hebrewHealth(), size: size);
  await openSection(tester, h.l10n.sectionSchedule);
  return h;
}

/// Presses the confirm button of the date or time picker on screen, in
/// whichever language it is.
Future<void> confirmPicker(WidgetTester tester) async {
  final context = tester.element(find.byType(Dialog).last);
  await tester.tap(find.text(MaterialLocalizations.of(context).okButtonLabel));
  await tester.pumpAndSettle();
}

/// The weekday chips on screen, as ISO weekdays, in the order they are
/// read: row by row, from the left in English and from the right in
/// Hebrew ([rtl]). The chips wrap, so they are not all on one row.
List<int> chipsInReadingOrder(WidgetTester tester, {required bool rtl}) {
  Offset at(int day) => tester.getCenter(find.byKey(ValueKey('day-$day')));
  return [for (var day = 1; day <= 7; day++) day]..sort((a, b) {
    final rows = at(a).dy.compareTo(at(b).dy);
    if (rows != 0) return rows;
    return rtl ? at(b).dx.compareTo(at(a).dx) : at(a).dx.compareTo(at(b).dx);
  });
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [widePhone, smallPhone]) {
    final width = size.width.toInt();

    group('Schedule in Hebrew ($width px)', () {
      testWidgets('today, what is coming up, what waits for an answer, and the plan', (tester) async {
        final h = await openSchedule(tester, size: size);
        final format = HealthFormat.forLocale(hebrewLocale);

        // Today.
        expect(find.text('היום'), findsOneWidget);
        expect(find.text(he.sectionDetailDay(format.shortDay(fixedNow))), findsOneWidget);
        expect(hasHebrew(format.shortDay(fixedNow)), isTrue); // יום ג׳, 10 ביוני
        expect(find.text('הוספה'), findsOneWidget);
        expect(find.textContaining('בשעה \u206820:00\u2069'), findsOneWidget);
        expect(find.text(he.recordDose), findsOneWidget);
        expect(find.text(he.doneTodayCount(2)), findsOneWidget);
        expect(find.textContaining('ניתנה בשעה'), findsOneWidget);
        expect(find.bySemanticsLabel(he.markNamedAsDone('Evening walk')), findsOneWidget);
        expect(directionOf(tester, find.text('היום')), TextDirection.rtl);

        // Upcoming: the kind of record in Hebrew, the month of the badge too.
        expect(find.text('בקרוב'), findsOneWidget);
        expect(find.textContaining('ביקור וטרינר'), findsOneWidget);
        expect(find.textContaining('Park Vet Clinic'), findsOneWidget);
        expect(find.text(he.followUpDue('Rabies booster')), findsOneWidget);
        expect(find.textContaining(he.dateGivenByVet), findsWidgets);
        expect(find.text('יוני'), findsOneWidget);
        expect(find.text('מרץ 26'), findsOneWidget);

        // Needs review.
        expect(find.text('ממתינות לעדכון'), findsOneWidget);
        // Yesterday evening's reminder: the day, the time and what is known,
        // each in one piece.
        final yesterdayEvening = DateTime(2025, 6, 9, 20);
        expect(
          find.text(format.dots([format.weekdayDate(yesterdayEvening), '20:00', he.noAnswerRecorded])),
          findsOneWidget,
        );
        expect(format.weekdayDate(yesterdayEvening), he.weekdayAndDate('יום ב׳', '09.06.25'));
        expect(find.text('ניתנה'), findsOneWidget);
        expect(find.text('לא ניתנה'), findsOneWidget);
        expect(find.text('לא ידוע'), findsOneWidget);
        expect(find.text(he.needsReviewNote(7)), findsOneWidget);

        // The plan.
        expect(find.text(he.medicinesAndRoutines), findsOneWidget);
        expect(find.textContaining('כל יום'), findsWidgets);
        // Saturday is "ש׳", and a routine named in English still says its kind.
        expect(find.textContaining('טיפוח'), findsOneWidget);
        expect(find.textContaining('ש׳'), findsOneWidget);

        for (final english in [
          'Today',
          'Upcoming',
          'Needs review',
          'Record',
          'Given',
          'Not given',
          'Not sure',
          'Add',
        ]) {
          expect(find.text(english), findsNothing, reason: english);
        }
        expect(find.textContaining('Every day'), findsNothing);
        expect(find.textContaining('Vet visit'), findsNothing);

        // A routine is ticked and undone.
        await tapVisible(tester, find.byKey(const ValueKey('tick-p-walk')));
        expect(find.text(he.doneTodayCount(3)), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('done-today')));
        expect(find.text(he.undo), findsNWidgets(3));
        await tapVisible(tester, find.byKey(const ValueKey('undo-p-walk')));
        expect(find.byKey(const ValueKey('today-p-walk')), findsOneWidget);

        // An answer given from "Needs review".
        await tapVisible(tester, find.text('לא ידוע'));
        expect(find.text('ממתינות לעדכון'), findsNothing);
        final logs = await real(tester, () => h.repository.fetchLogs(kelly, from: DateTime(2025, 5, 1)));
        expect(logs.where((l) => l.status == CareLogStatus.unknown), hasLength(1));
      });

      testWidgets('the add sheet, a new routine and the day chips', (tester) async {
        final h = await openSchedule(tester, size: size);

        await tapVisible(tester, find.byKey(const Key('schedule-add')));
        expect(find.text('הוספה ללוח הזמנים'), findsOneWidget);
        expect(find.text('תור או תאריך יעד'), findsOneWidget);
        expect(find.text('תרופה'), findsOneWidget);
        expect(find.text('שגרה'), findsOneWidget);
        expect(find.text(he.addRoutineNote), findsOneWidget);

        await tapVisible(tester, find.byKey(const ValueKey('add-routine')));
        expect(find.text('שגרה חדשה'), findsOneWidget);
        expect(find.text(he.whatKindOfRoutine), findsOneWidget);
        for (final kind in ['האכלה', 'טיול', 'טיפוח', 'אחר']) {
          expect(find.widgetWithText(ChoiceChip, kind), findsOneWidget, reason: kind);
        }
        expect(find.text(he.fieldTime), findsOneWidget);
        expect(find.text(he.fieldDays), findsOneWidget);
        expect(find.text(he.showInSchedule), findsOneWidget);
        expect(find.text(he.routineOn), findsOneWidget);

        await tapVisible(tester, find.text(he.saveRoutine));
        expect(find.text(he.validRoutineTitle), findsOneWidget);

        // The title follows the kind, in Hebrew, until one is typed.
        await tapVisible(tester, find.byKey(const ValueKey('routine-kind-walk')));
        expect(find.widgetWithText(TextFormField, 'טיול'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('routine-title')), 'טיול בוקר');

        await tapVisible(tester, find.byKey(const Key('routine-time')));
        expect(find.text(he.timeOfRoutine), findsOneWidget);
        await confirmPicker(tester);

        // The chips: Hebrew day letters, Sunday first, from the right.
        for (final letter in ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳']) {
          expect(find.widgetWithText(FilterChip, letter), findsOneWidget, reason: letter);
        }
        expect(chipsInReadingOrder(tester, rtl: true), [7, 1, 2, 3, 4, 5, 6]);
        expect(
          tester.getCenter(find.byKey(const ValueKey('day-7'))).dx,
          greaterThan(tester.getCenter(find.byKey(const ValueKey('day-1'))).dx),
        );
        expect(find.text('כל יום'), findsOneWidget);

        // Sunday to Thursday are the weekdays of the Israeli week.
        await tapVisible(tester, find.byKey(const ValueKey('day-5')));
        await tapVisible(tester, find.byKey(const ValueKey('day-6')));
        expect(find.text('ימי חול'), findsOneWidget);

        await tapVisible(tester, find.byKey(const Key('routine-active')));
        expect(find.text(he.routinePausedNote), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('routine-active')));

        await tapVisible(tester, find.text(he.saveRoutine));
        expect(find.text('שגרה חדשה'), findsNothing);
        // Once in today's list (it is due on a Tuesday), once in the plan.
        expect(find.text('טיול בוקר'), findsNWidgets(2));
        expect(find.textContaining('ימי חול'), findsOneWidget);

        final items = await real(tester, () => h.repository.fetchPlanItems(kelly));
        final saved = items.firstWhere((i) => i.title == 'טיול בוקר');
        expect(saved.kind, CareKind.walk);
        expect(saved.days, {1, 2, 3, 4, 7});

        // Deleting it asks first, in Hebrew.
        await tapVisible(tester, find.byKey(ValueKey('routine-${saved.id}')));
        expect(find.text('עריכת שגרה'), findsOneWidget);
        await tester.tap(find.byTooltip(he.deleteRoutine));
        await tester.pumpAndSettle();
        expect(find.text(he.deleteRoutineTitle), findsOneWidget);
        expect(find.text(he.deleteRoutineMessage('טיול בוקר')), findsOneWidget);
        await tester.tap(find.text('מחיקה'));
        await tester.pumpAndSettle();
        expect(find.text('טיול בוקר'), findsNothing);
      });

      testWidgets('a new medicine, its instructions and its dose log', (tester) async {
        final h = await openSchedule(tester, size: size);
        await tapVisible(tester, find.byKey(const Key('schedule-add')));
        await tapVisible(tester, find.byKey(const ValueKey('add-medicine')));

        expect(find.text('תרופה חדשה'), findsOneWidget);
        expect(find.text(he.fromVetInstructions), findsOneWidget);
        expect(find.text(he.howItIsGiven), findsOneWidget);
        for (final route in ['דרך הפה', 'על העור', 'בעין', 'באוזן', 'זריקה', 'אחר']) {
          expect(find.widgetWithText(ChoiceChip, route), findsOneWidget, reason: route);
        }
        expect(find.text(he.fieldStart), findsOneWidget);
        expect(find.text(he.endOptional), findsOneWidget);
        expect(find.text(he.noEnd), findsOneWidget);
        expect(find.text(he.reminders), findsOneWidget);
        expect(find.text(he.medicineNoTimesNote), findsOneWidget);
        expect(find.text(he.medicineFinePrint), findsOneWidget);

        await tapVisible(tester, find.text(he.saveMedicine));
        expect(find.text(he.validMedicineName), findsOneWidget);

        await tester.enterText(find.byKey(const Key('medicine-name')), 'טיפות אוזניים');
        await tester.enterText(find.byKey(const Key('medicine-dose')), '3 טיפות');
        await tapVisible(tester, find.byKey(const ValueKey('route-In the ear')));
        await tester.enterText(find.byKey(const Key('medicine-frequency')), 'פעם ביום');

        await tapVisible(tester, find.byKey(const Key('medicine-add-time')));
        expect(find.text(he.reminderTime), findsOneWidget);
        await confirmPicker(tester);
        expect(find.byKey(const ValueKey('time-08:00')), findsOneWidget);
        expect(find.text('כל יום'), findsOneWidget);
        expect(find.text(he.medicineReminderNote), findsOneWidget);

        await tapVisible(tester, find.text(he.saveMedicine));
        expect(find.text('תרופה חדשה'), findsNothing);
        // The instructions as one whole line, the way of giving in Hebrew.
        expect(
          find.text(he.medicineHowAndOften(he.medicineDoseAndRoute('3 טיפות', 'באוזן'), 'פעם ביום')),
          findsOneWidget,
        );
        // What is stored is the key, not the word on screen.
        final medicine = (await real(
          tester,
          () => h.repository.fetchMedications(kelly),
        )).firstWhere((m) => m.name == 'טיפות אוזניים');
        expect(medicine.route, 'In the ear');

        // An existing medicine: the dose log and the delete question.
        await tapVisible(tester, find.byKey(const ValueKey('medicine-m-joint')));
        expect(find.text('עריכת תרופה'), findsOneWidget);
        expect(find.text('יומן מנות'), findsOneWidget);
        expect(find.text(he.givenAt('08:05')), findsWidgets);
        expect(find.textContaining(he.doseLoggedBy('Alex')), findsWidgets);
        expect(find.textContaining(he.doseLogReminder('08:00')), findsWidgets);
        expect(find.byTooltip(he.removeNamed('20:00')), findsOneWidget);

        await tester.tap(find.byTooltip(he.deleteMedicine));
        await tester.pumpAndSettle();
        expect(find.text(he.deleteMedicineTitle), findsOneWidget);
        expect(find.text(he.deleteMedicineMessage('Joint tablets')), findsOneWidget);
        await tester.tap(find.text('ביטול'));
        await tester.pumpAndSettle();
        expect(find.text('עריכת תרופה'), findsOneWidget);
      });

      testWidgets('recording a dose', (tester) async {
        final h = await openSchedule(tester, size: size);

        await tapVisible(tester, find.byKey(const ValueKey('record-p-joint-pm')));
        expect(find.text('Joint tablets 50 mg'), findsWidgets);
        expect(find.text(he.reminderForToday('20:00')), findsOneWidget);
        expect(find.textContaining('הוראות הווטרינר: '), findsOneWidget);
        expect(find.text(he.givenNowAt('17:40')), findsOneWidget);
        expect(find.text(he.givenAtAnotherTime), findsOneWidget);
        expect(find.text('לא ניתנה'), findsWidgets);
        expect(find.text(he.noteOptional), findsOneWidget);
        expect(find.text(he.doseFinePrintNamed('Alex')), findsOneWidget);

        // A time that is still ahead is refused, in Hebrew.
        await tapVisible(tester, find.byKey(const Key('dose-given-other')));
        expect(find.text(he.whenWasItGiven), findsOneWidget);
        await confirmPicker(tester);
        expect(find.text(he.validTimeAhead), findsOneWidget);

        await tapVisible(tester, find.byKey(const Key('dose-given-now')));
        expect(find.text(he.doseRecordedGiven), findsOneWidget);
        final logs = await real(tester, () => h.repository.fetchLogs(kelly, from: DateTime(2025, 6, 10)));
        expect(logs.where((l) => l.planItemId == 'p-joint-pm').single.loggedByName, 'Alex');
      });

      testWidgets('an empty schedule offers to add something', (tester) async {
        await openSchedule(tester, size: size);
        await selectPet(tester, 'Soya');

        expect(find.text(he.scheduleEmpty), findsOneWidget);
        expect(find.text(he.scheduleEmptyNote('Soya')), findsOneWidget);
        await tapVisible(tester, find.text('הוספה ללוח הזמנים'));
        expect(find.text(he.addAppointment), findsOneWidget);
      });
    });
  }

  testWidgets('a reminder of yesterday says so in Hebrew', (tester) async {
    await openSchedule(tester);
    // The unanswered reminder of yesterday evening.
    await tapVisible(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('review-p-joint-pm-09.06.25')),
        matching: find.text('Joint tablets'),
      ),
    );
    expect(find.text(he.reminderForYesterday('20:00')), findsOneWidget);
  });

  group('the owner\'s week', () {
    final english = HealthFormat.forLocale(englishLocale);
    final hebrew = HealthFormat.forLocale(hebrewLocale);
    const israeli = WeekSettings.israeli;
    const monday = WeekSettings.mondayToFriday;

    test('"Weekdays" and "Weekends" mean what the week says', () {
      const sunToThu = {1, 2, 3, 4, 7};
      const monToFri = {1, 2, 3, 4, 5};

      expect(english.days({1, 2, 3, 4, 5, 6, 7}, israeli), 'Every day');
      expect(english.days(sunToThu, israeli), 'Weekdays');
      expect(english.days({5, 6}, israeli), 'Weekends');
      // In the Israeli week Monday to Friday is a plain list, Sunday first.
      expect(english.days(monToFri, israeli), 'Mon, Tue, Wed, Thu, Fri');
      expect(english.days({1, 7}, israeli), 'Sun, Mon');

      expect(english.days(monToFri, monday), 'Weekdays');
      expect(english.days({6, 7}, monday), 'Weekends');
      expect(english.days(sunToThu, monday), 'Mon, Tue, Wed, Thu, Sun');
      expect(english.days({1, 7}, monday), 'Mon, Sun');

      expect(hebrew.days({1, 2, 3, 4, 5, 6, 7}, israeli), 'כל יום');
      expect(hebrew.days(sunToThu, israeli), 'ימי חול');
      expect(hebrew.days({5, 6}, israeli), 'סוף שבוע');
      expect(hebrew.days({1, 4}, israeli), 'ב׳, ה׳');
      expect(hebrew.days({1, 7}, israeli), 'א׳, ב׳');
      expect(hebrew.days({1, 7}, monday), 'ב׳, א׳');
      // A week that starts on Saturday.
      expect(english.days({6, 7, 1}, israeli.copyWith(firstDay: DateTime.saturday)), 'Sat, Sun, Mon');
    });

    for (final (name, week) in [
      ('Sunday', israeli),
      ('Monday', monday),
      ('Saturday', WeekSettings(firstDay: DateTime.saturday, weekdays: israeli.weekdays)),
    ]) {
      testWidgetsInBothLanguages('the day chips start on $name when the week does', (tester, language) async {
        final h = HealthHarness(language: language, week: week);
        await openSchedule(tester, harness: h);
        await tapVisible(tester, find.byKey(const Key('schedule-add')));
        await tapVisible(tester, find.byKey(const ValueKey('add-routine')));

        // The first day leads: on the left in English, on the right in Hebrew.
        expect(chipsInReadingOrder(tester, rtl: h.isHebrew), week.orderedDays);
        expect(find.widgetWithText(FilterChip, h.l10n.dayChip(week.firstDay)), findsOneWidget);

        // The line under the chips uses the same week.
        for (final day in week.weekend) {
          await tapVisible(tester, find.byKey(ValueKey('day-$day')));
        }
        expect(find.text(h.l10n.daysWeekdays), findsOneWidget);
      });
    }

    testWidgets('changing the week in Settings changes an open Schedule at once', (tester) async {
      final h = HealthHarness();
      await real(
        tester,
        () => h.repository.savePlanItem(
          const CarePlanItem(
            id: '',
            petId: kelly,
            kind: CareKind.walk,
            title: 'Morning walk',
            time: TimeOfDay(hour: 6, minute: 30),
            days: {1, 2, 3, 4, 5},
          ),
        ),
      );
      await openSchedule(tester, harness: h);

      // The Israeli week: Monday to Friday is just a list of days.
      expect(find.text('Walk · 06:30 · Mon, Tue, Wed, Thu, Fri'), findsOneWidget);

      final container = ProviderScope.containerOf(tester.element(find.byType(HealthScreen)), listen: false);
      await tester.runAsync(() => container.read(weekSettingsProvider.notifier).use(WeekSettings.mondayToFriday));
      await tester.pumpAndSettle();
      expect(find.text('Walk · 06:30 · Weekdays'), findsOneWidget);
      expect(h.settings.values[weekFirstDaySettingKey], '1');

      // And back: Sunday to Thursday are the weekdays again.
      await tester.runAsync(() => container.read(weekSettingsProvider.notifier).use(WeekSettings.israeli));
      await tester.pumpAndSettle();
      expect(find.text('Walk · 06:30 · Mon, Tue, Wed, Thu, Fri'), findsOneWidget);
    });

    test('the Settings note no longer says "soon"', () {
      expect(appEn.settingsWeekNote, contains('The Health schedule follows this choice'));
      expect(appEn.settingsWeekNote, isNot(contains('soon')));
      expect(appHe.settingsWeekNote, contains('לוח הזמנים בבריאות מתאים את עצמו לבחירה הזו'));
      expect(appHe.settingsWeekNote, isNot(contains('בקרוב')));
    });
  });

  group('words of the Schedule', () {
    test('a dose in the log: given, not given, not sure', () {
      expect(he.doseStatus(CareLogStatus.done, givenAtTime: '08:05'), 'ניתנה בשעה \u206808:05\u2069');
      expect(he.doseStatus(CareLogStatus.done), 'ניתנה');
      expect(he.doseStatus(CareLogStatus.skipped), 'לא ניתנה');
      expect(he.doseStatus(CareLogStatus.unknown), 'לא ידוע');
      expect(en.doseStatus(CareLogStatus.done, givenAtTime: '08:05'), 'Given 08:05');
    });

    test('a way of giving a medicine is stored in English and said in Hebrew; a typed one stays as typed', () {
      expect(
        [for (final route in medicineRoutes) he.medicineRoute(route)],
        ['דרך הפה', 'על העור', 'בעין', 'באוזן', 'זריקה', 'אחר'],
      );
      expect([for (final route in medicineRoutes) en.medicineRoute(route)], medicineRoutes);
      expect(he.medicineRoute('Under the tongue'), 'Under the tongue');
    });

    test('the instructions of a medicine are one line in both languages', () {
      const medication = Medication(
        id: 'm',
        petId: kelly,
        name: 'Joint tablets',
        dose: '1 tablet',
        route: 'By mouth',
        frequency: 'Twice a day with food',
      );
      final english = HealthFormat.forLocale(englishLocale);
      final hebrew = HealthFormat.forLocale(hebrewLocale);
      expect(english.instructions(medication), '1 tablet by mouth, twice a day with food');
      expect(english.instructions(medication), medication.instructionLine);
      expect(
        hebrew.instructions(medication),
        '\u2068\u20681 tablet\u2069 \u2068דרך הפה\u2069\u2069, \u2068twice a day with food\u2069',
      );
      expect(english.instructions(const Medication(id: 'm', petId: kelly, name: 'Drops')), '');
      expect(hebrew.instructions(const Medication(id: 'm', petId: kelly, name: 'Drops', route: 'In the eye')), 'בעין');
    });
  });
}
