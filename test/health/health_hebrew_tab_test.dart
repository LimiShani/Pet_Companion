import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/health_format.dart';
import 'package:pet_companion/features/health/widgets/weight_trend.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/widgets/pet_switcher.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

// The Health tab itself in Hebrew and right to left, through the whole
// app: the header, the three sections and what they open. An overflow
// anywhere fails the test by itself, and the test font makes Hebrew
// letters as wide as Latin ones.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);
final appHe = lookupAppL10n(hebrewLocale);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [widePhone, smallPhone]) {
    final width = size.width.toInt();

    group('Overview in Hebrew ($width px)', () {
      testWidgets('the header and what needs attention for Kelly', (tester) async {
        await pumpHealth(tester, harness: hebrewHealth(), size: size);

        // The header: the tab's name, the emergency pill, the three sections.
        expect(find.text('בריאות'), findsNWidgets(2)); // the header and the bottom bar
        for (final label in ['סקירה', 'לוח זמנים', 'רשומות']) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        expect(find.text('היסטוריה'), findsNothing);
        expect(find.text('תובנות'), findsNothing);
        expect(find.text('חירום'), findsOneWidget);
        expect(directionOf(tester, find.byType(EmergencyButton)), TextDirection.rtl);
        // The emergency pill ends the header: on the left in Hebrew.
        expect(tester.getCenter(find.byType(EmergencyButton)).dx, lessThan(size.width / 2));

        // The pet is named by the header's chip; no pet card.
        expect(find.byKey(PetSwitcher.chipKey), findsOneWidget);
        expect(find.textContaining('כלב · '), findsNothing);

        // Coming up.
        expect(find.text('בקרוב'), findsOneWidget);
        expect(find.text('Evening walk'), findsOneWidget); // sample data stays English
        expect(find.text(he.dayAndTime('היום', '18:30')), findsOneWidget);
        expect(find.textContaining('12.06.25'), findsOneWidget);
        expect(find.text('תזכורת אחת ממתינה לעדכון'), findsOneWidget);

        // The two actions; Share is on Records.
        expect(find.text('רישום מהיר'), findsOneWidget);
        expect(find.text('הוספת רשומה'), findsOneWidget);
        expect(find.text('שיתוף'), findsNothing);

        // The vet: its hours as typed, Call and Message; the map is on the
        // details page.
        expect(find.text(he.vet), findsOneWidget);
        expect(find.text(he.details), findsOneWidget);
        expect(find.text('Sun to Thu 08:00-19:00, Fri 08:00-13:00'), findsOneWidget);
        expect(find.text('חיוג'), findsOneWidget);
        expect(find.text('הודעה'), findsOneWidget);
        expect(find.text('מפה'), findsNothing);

        // The rows: the health profile, the weight, the records.
        await tester.dragUntilVisible(
          find.byKey(const Key('overview-records')),
          find.byKey(const Key('overview-coming-up')),
          const Offset(0, -200),
        );
        final format = HealthFormat.forLocale(hebrewLocale);
        expect(find.text(he.healthProfile), findsOneWidget);
        expect(
          find.text(
            format.dots([
              he.overviewProfileAllergies(format.commas(['Chicken (skin reaction)'])),
              format.commas(['Arthritis in the hips']),
              'יש שבב',
            ]),
          ),
          findsOneWidget,
        );
        expect(find.text(he.overviewWeightRow(format.weight(23))), findsOneWidget);
        expect(find.textContaining('מאז'), findsOneWidget);
        expect(find.byType(WeightTrendChart), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('overview-records')), matching: find.text('רשומות')), findsOneWidget);
        expect(find.text(format.dots(['3 חיסונים', '4 ביקורי וטרינר', '3 מסמכים'])), findsOneWidget);
        // The medicines are in the Schedule.
        expect(find.text('תרופות'), findsNothing);
        expect(find.text(he.lastDoseToday('08:05')), findsNothing);

        for (final english in [
          'Health',
          'Overview',
          'Schedule',
          'History',
          'Insights',
          'Records',
          'Emergency',
          'Coming up',
          'Quick log',
          'Add record',
          'Share',
          'Vet',
          'Medicines',
          'Weight',
          'Medical records',
          'Health profile',
        ]) {
          expect(find.text(english), findsNothing, reason: english);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('an empty pet gets its first steps', (tester) async {
        await pumpHealth(tester, harness: hebrewHealth(), size: size);
        await switchPet(tester, 'Soya');

        expect(find.text(he.startWithOneThing), findsOneWidget);
        expect(find.text(he.startNote('Soya')), findsOneWidget);
        expect(find.text(he.startDocument), findsOneWidget);
        expect(find.text(he.startDocumentNote), findsOneWidget);
        expect(find.text(he.startAppointment), findsOneWidget);
        expect(find.text(he.startAppointmentNote), findsOneWidget);
        expect(find.text(he.startMedicine), findsOneWidget);
        expect(find.text(he.startMedicineNote), findsOneWidget);
        expect(find.text('הוספת וטרינר עבור \u2068Soya\u2069'), findsOneWidget);
        expect(find.text(he.overviewProfileEmpty), findsOneWidget);
        expect(find.text(he.noWeightYet), findsOneWidget);
        expect(find.text(he.historyEmpty), findsOneWidget);
        expect(find.text('בקרוב'), findsNothing);
      });
    });
  }

  testWidgets('a load failure is explained in Hebrew and offers to try again', (tester) async {
    final h = hebrewHealth();
    h.repository.failing = true;
    await pumpHealth(tester, harness: h);

    expect(find.text(he.loadFailedHealth('Kelly')), findsOneWidget);
    expect(find.text('אין חיבור לשרת. כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.'), findsOneWidget);
    expect(find.byType(EmergencyButton), findsOneWidget);

    h.repository.failing = false;
    await tester.tap(find.text('לנסות שוב'));
    await tester.pumpAndSettle();
    expect(find.text('בקרוב'), findsOneWidget);
  });

  testWidgetsInBothLanguages('the tab follows the language of the app', (tester, language) async {
    final h = await pumpHealth(tester, harness: HealthHarness(language: language));
    expect(find.text(h.l10n.comingUp), findsOneWidget);
    expect(find.text(h.l10n.quickLog), findsOneWidget);
    expect(directionOf(tester, find.text(h.l10n.comingUp)), h.isHebrew ? TextDirection.rtl : TextDirection.ltr);
  });

  testWidgets('the tab works in the app as shipped, in Hebrew, on the sample data', (tester) async {
    // No Health overrides at all: the default repository (with its delay)
    // and the sample-data clock, which treats 10.06.25 as today.
    await pumpApp(tester, language: AppLanguage.hebrew);
    await signInAsDemo(tester);
    await openHealthTab(tester, label: appHe.navHealth);

    expect(find.text('בקרוב'), findsOneWidget);
    expect(find.text('General check'), findsOneWidget);
    expect(find.text('Dr. Levi, Park Vet Clinic'), findsOneWidget);

    await openSection(tester, 'לוח זמנים');
    expect(find.text('היום'), findsOneWidget);
    await openSection(tester, 'רשומות');
    expect(find.text('12 רשומות'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('filter-journal')));
    expect(find.text(he.recordsEntries(9)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching the language turns an open Health tab around at once', (tester) async {
    final h = await pumpHealth(tester);
    expect(find.text('Coming up'), findsOneWidget);
    expect(directionOf(tester, find.text('Coming up')), TextDirection.ltr);

    final container = ProviderScope.containerOf(tester.element(find.byType(EmergencyButton)), listen: false);
    await tester.runAsync(() => container.read(appLanguageProvider.notifier).choose(AppLanguage.hebrew));
    await tester.pumpAndSettle();
    expect(find.text('בקרוב'), findsOneWidget);
    expect(directionOf(tester, find.text('בקרוב')), TextDirection.rtl);
    expect(find.text('Coming up'), findsNothing);
    expect(h.settings.values[languageSettingKey], 'he');
  });

  group('plural forms on the Overview', () {
    test('reminders that need review: one, two, many', () {
      expect(he.remindersNeedReview(1), 'תזכורת אחת ממתינה לעדכון');
      expect(he.remindersNeedReview(2), 'שתי תזכורות ממתינות לעדכון');
      expect(he.remindersNeedReview(5), '5 תזכורות ממתינות לעדכון');
      expect(en.remindersNeedReview(1), '1 reminder needs review');
      expect(en.remindersNeedReview(3), '3 reminders need review');
    });

    test('the counts of the Records row and the journal: one, two, many', () {
      expect(he.overviewVaccinations(1), 'חיסון אחד');
      expect(he.overviewVaccinations(2), 'שני חיסונים');
      expect(he.overviewVaccinations(3), '3 חיסונים');
      expect(he.overviewVetVisits(1), 'ביקור וטרינר אחד');
      expect(he.overviewVetVisits(4), '4 ביקורי וטרינר');
      expect(he.overviewDocuments(2), 'שני מסמכים');
      expect(he.overviewMedicines(1), 'תרופה אחת');
      expect(he.overviewMedicines(2), 'שתי תרופות');
      expect(he.recordsEntries(1), 'רישום אחד');
      expect(he.recordsEntries(9), '9 רישומים');
      expect(en.overviewVaccinations(1), '1 vaccination');
      expect(en.overviewVetVisits(4), '4 vet visits');
      expect(en.overviewMedicines(1), '1 medicine');
      expect(en.recordsEntries(1), '1 entry');
      expect(en.recordsEntries(9), '9 entries');
    });

    test('active medicines: one, two, many', () {
      expect(he.medicinesActive(1), 'אחת פעילה');
      expect(he.medicinesActive(2), 'שתיים פעילות');
      expect(he.medicinesActive(4), '4 פעילות');
      expect(en.medicinesActive(1), '1 active');
      expect(en.medicinesActive(2), '2 active');
    });
  });
}
