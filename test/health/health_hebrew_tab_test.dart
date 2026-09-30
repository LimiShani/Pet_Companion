import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/emergency/emergency.dart';
import 'package:pet_companion/features/health/widgets/weight_trend.dart';
import 'package:pet_companion/l10n/l10n.dart';

import '../helpers.dart';
import 'health_test_helpers.dart';

// The Health tab itself in Hebrew and right to left, through the whole
// app: the header, the four sections and what they open. An overflow
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

        // The header: the tab's name, the emergency pill, the four sections.
        expect(find.text('בריאות'), findsNWidgets(2)); // the header and the bottom bar
        for (final label in ['סקירה', 'לוח זמנים', 'היסטוריה', 'תובנות']) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        expect(find.text('חירום'), findsOneWidget);
        expect(directionOf(tester, find.byType(EmergencyButton)), TextDirection.rtl);
        // The emergency pill ends the header: on the left in Hebrew.
        expect(tester.getCenter(find.byType(EmergencyButton)).dx, lessThan(size.width / 2));

        // The pet, in the Pets feature's Hebrew words; its name as typed.
        expect(find.text('Kelly'), findsWidgets);
        expect(find.textContaining('כלב · '), findsOneWidget);
        expect(find.text(he.overviewLastRecord('08.06.25')), findsOneWidget);
        expect(find.text(he.healthProfile), findsOneWidget);

        // Coming up.
        expect(find.text('בקרוב'), findsOneWidget);
        expect(find.text('Evening walk'), findsOneWidget); // sample data stays English
        expect(find.text(he.dayAndTime('היום', '18:30')), findsOneWidget);
        expect(find.textContaining('12.06.25'), findsOneWidget);
        expect(find.text('תזכורת אחת ממתינה לעדכון'), findsOneWidget);

        // The quick actions.
        expect(find.text('רישום מהיר'), findsOneWidget);
        expect(find.text('הוספת רשומה'), findsOneWidget);
        expect(find.text('שיתוף'), findsOneWidget);

        // The vet.
        expect(find.text(he.vet), findsOneWidget);
        expect(find.text(he.details), findsOneWidget);
        expect(find.text('חיוג'), findsOneWidget);
        expect(find.textContaining(ltr('+972 3 555 0142')), findsOneWidget);

        // The latest facts.
        await tester.dragUntilVisible(
          find.byKey(const Key('overview-records')),
          find.byKey(const Key('overview-pet')),
          const Offset(0, -200),
        );
        expect(find.text('תרופות'), findsOneWidget);
        expect(find.text('אחת פעילה'), findsOneWidget);
        expect(find.text(he.lastDoseToday('08:05')), findsOneWidget);
        expect(find.text('משקל'), findsOneWidget);
        expect(find.text('23 ק״ג', findRichText: true), findsOneWidget);
        expect(find.textContaining('מאז'), findsOneWidget);
        expect(find.byType(WeightTrendChart), findsOneWidget);
        expect(find.text('תיק רפואי'), findsOneWidget);
        expect(find.bySemanticsLabel(he.countAndLabel(3, 'חיסונים')), findsOneWidget);
        expect(find.bySemanticsLabel(he.countAndLabel(4, 'ביקורי וטרינר')), findsOneWidget);
        expect(find.bySemanticsLabel(he.countAndLabel(3, 'מסמכים')), findsOneWidget);

        for (final english in [
          'Health',
          'Overview',
          'Schedule',
          'History',
          'Insights',
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
        await tester.tap(find.text('Soya').first);
        await tester.pumpAndSettle();

        expect(find.text(he.overviewNoCareDue), findsOneWidget);
        expect(find.text(he.startWithOneThing), findsOneWidget);
        expect(find.text(he.startNote('Soya')), findsOneWidget);
        expect(find.text(he.startDocument), findsOneWidget);
        expect(find.text(he.startDocumentNote), findsOneWidget);
        expect(find.text(he.startAppointment), findsOneWidget);
        expect(find.text(he.startAppointmentNote), findsOneWidget);
        expect(find.text(he.startMedicine), findsOneWidget);
        expect(find.text(he.startMedicineNote), findsOneWidget);
        expect(find.text('הוספת וטרינר עבור \u2068Soya\u2069'), findsOneWidget);
        expect(find.text('כלב'), findsOneWidget); // all that is known about Soya
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
    await openSection(tester, 'היסטוריה');
    expect(find.text('12 רשומות'), findsOneWidget);
    await openSection(tester, 'תובנות');
    expect(find.text(he.observations), findsOneWidget);
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

    test('active medicines: one, two, many', () {
      expect(he.medicinesActive(1), 'אחת פעילה');
      expect(he.medicinesActive(2), 'שתיים פעילות');
      expect(he.medicinesActive(4), '4 פעילות');
      expect(en.medicinesActive(1), '1 active');
      expect(en.medicinesActive(2), '2 active');
    });
  });
}
