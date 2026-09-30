import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/species_settings.dart';
import 'package:pet_companion/features/health/health_format.dart';
import 'package:pet_companion/features/health/health_strings.dart';
import 'package:pet_companion/features/health/insights/quick_log_sheet.dart';
import 'package:pet_companion/features/health/widgets/weight_trend.dart';
import 'package:pet_companion/l10n/l10n.dart';
import 'package:pet_companion/models/pet.dart';

import 'health_test_helpers.dart';

// Insights and the Quick log in Hebrew and right to left: the weight card
// and its chart (which runs left to right in both languages), the journal,
// and the Quick log for a dog, a cat and a reptile.

final he = lookupHealthL10n(hebrewLocale);
final en = lookupHealthL10n(englishLocale);

const kelly = 'kelly';
const mitzi = Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat);
const gil = Pet(id: 'gil', name: 'Gil', species: PetSpecies.reptile);
const rio = Pet(id: 'rio', name: 'Rio', species: PetSpecies.bird);

/// [finder] inside the Quick log sheet only (the page under it stays on
/// screen, with chips of its own).
Finder inSheet(Finder finder) => find.descendant(of: find.byType(QuickLogSheet), matching: finder);

Future<HealthHarness> openInsights(WidgetTester tester, {HealthHarness? harness, Size size = widePhone}) async {
  final h = await pumpHealth(tester, harness: harness ?? hebrewHealth(), size: size);
  await openSection(tester, h.l10n.sectionInsights);
  return h;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final size in [widePhone, smallPhone]) {
    final width = size.width.toInt();

    group('Insights in Hebrew ($width px)', () {
      testWidgets('the weight card, its chart and the journal', (tester) async {
        await openInsights(tester, size: size);
        final format = HealthFormat.forLocale(hebrewLocale);

        expect(
          find.descendant(of: find.byKey(const Key('insights-weight')), matching: find.text('משקל')),
          findsOneWidget,
        );
        expect(find.text(he.logWeight), findsOneWidget);
        expect(find.text('23 ק״ג', findRichText: true), findsOneWidget);
        expect(find.text(format.dots(['01.06.25', he.weighIns(6)])), findsOneWidget);
        expect(
          find.text(
            format.dots([
              format.weightChangeSince(23.2, 23, DateTime(2025, 5, 2)),
              he.weightHighest('24.1'),
              he.weightLowest('23'),
            ]),
          ),
          findsOneWidget,
        );
        expect(find.text(he.vetVisitMarker), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(he.weightTrendSemantics(format.weight(24.1), '18.09.24', format.weight(23), '01.06.25')),
            ),
          ),
          findsOneWidget,
        );

        // The chart runs left to right, and so do the dates under it: the
        // first weigh-in on the left, the latest on the right.
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(of: find.byType(WeightTrendChart), matching: find.byType(CustomPaint)),
                    )
                    .painter!
                as WeightTrendPainter;
        final spots = painter.layout(tester.getSize(find.byType(WeightTrendChart)));
        expect(spots.first.dx, lessThan(spots.last.dx));
        expect(tester.getCenter(find.text('18.09.24')).dx, lessThan(tester.getCenter(find.text('01.06.25').last).dx));

        // The journal.
        expect(find.text(he.observations), findsOneWidget);
        expect(find.text(format.dots(['תנועה', 'פחות מהרגיל'])), findsOneWidget);
        expect(find.text(format.dots(['תיאבון', 'כרגיל'])), findsOneWidget);
        expect(find.text(format.dots(['משקל', format.weight(23)])), findsOneWidget);
        expect(find.text(format.dots(['08.06.25', 'Stiff getting up in the morning'])), findsOneWidget);
        expect(find.text(he.insightsFinePrint), findsOneWidget);
        for (final chip in ['הכול', 'משקל', 'תיאבון', 'אנרגיה', 'תנועה']) {
          expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget, reason: chip);
        }
        for (final english in ['Weight', 'Observations', 'Log weight', 'vet visit', 'All']) {
          expect(find.text(english), findsNothing, reason: english);
        }

        await tapVisible(tester, find.byKey(const ValueKey('journal-mobility')));
        expect(find.text(format.dots(['תיאבון', 'כרגיל'])), findsNothing);
        await tapVisible(tester, find.byKey(const Key('journal-all')));
        expect(find.text(format.dots(['תיאבון', 'כרגיל'])), findsOneWidget);
      });

      testWidgets('the Quick log for a dog: an answer, a weight and a change', (tester) async {
        final h = await openInsights(tester, size: size);

        await tester.tap(find.byKey(const Key('quick-log-button')));
        await tester.pumpAndSettle();
        expect(find.text(he.quickLogFor('Kelly')), findsOneWidget);
        expect(find.text(he.whatDidYouNotice), findsOneWidget);
        expect(inSheet(find.text('גוף')), findsOneWidget);
        expect(inSheet(find.text('התנהגות')), findsOneWidget);
        for (final chip in ['משקל', 'תיאבון', 'אנרגיה', 'תנועה', 'עיכול', 'עור או פרווה', 'שיניים', 'אחר']) {
          expect(inSheet(find.widgetWithText(ChoiceChip, chip)), findsOneWidget, reason: chip);
        }
        for (final chip in ['שינה', 'נביחות', 'נשיכות', 'כשנשארים לבד', 'התנהגות אחרת']) {
          expect(inSheet(find.widgetWithText(ChoiceChip, chip)), findsOneWidget, reason: chip);
        }
        expect(find.text(he.looksUrgent), findsOneWidget);
        expect(find.text(he.quickLogFinePrint), findsOneWidget);

        await tapVisible(tester, find.byKey(const ValueKey('quick-appetite')));
        for (final level in ['כרגיל', 'פחות מהרגיל', 'יותר מהרגיל', 'לא ידוע']) {
          expect(inSheet(find.widgetWithText(ChoiceChip, level)), findsOneWidget, reason: level);
        }
        expect(find.text(he.fieldWhen), findsOneWidget);
        expect(find.text(he.dayAndTime('היום', '17:40')), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('level-less')));
        await tester.enterText(find.byKey(const Key('quick-note')), 'השאירה חצי מנה');
        await tapVisible(tester, find.text(he.saveToJournal));
        expect(find.text(he.savedToJournal), findsOneWidget);
        final stored = await real(tester, () => h.repository.fetchObservations(kelly));
        expect(stored.where((o) => o.note == 'השאירה חצי מנה').single.level, ObservationLevel.less);

        // A weight: typed left to right, with the last one beside it.
        await tapVisible(tester, find.byKey(const Key('log-weight')));
        expect(find.text(he.weightInKilograms), findsOneWidget);
        expect(
          find.text(he.lastTimeWeight(HealthFormat.forLocale(hebrewLocale).weight(23), '01.06.25')),
          findsOneWidget,
        );
        final field = find.descendant(
          of: find.byKey(const Key('quick-weight-field')),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(field).textDirection, TextDirection.ltr);
        await tester.enterText(find.byKey(const Key('quick-weight-field')), '900');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(he.saveToJournal));
        expect(find.text(he.validWeight), findsOneWidget);
        await tester.enterText(find.byKey(const Key('quick-weight-field')), '22.8');
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text(he.saveToJournal));
        expect(find.text('22.8 ק״ג', findRichText: true), findsOneWidget);

        // Changing and deleting an entry.
        await tapVisible(tester, find.byKey(const ValueKey('observation-o-energy')));
        expect(find.text(he.editEntry), findsOneWidget);
        expect(find.text(he.saveChanges), findsOneWidget);
        await tapVisible(tester, find.byKey(const Key('quick-delete')));
        expect(find.text(he.deleteEntryTitle), findsOneWidget);
        expect(find.text(he.deleteEntryMessage), findsOneWidget);
        await tester.tap(find.text('מחיקה'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('observation-o-energy')), findsNothing);
      });

      testWidgets('a cat, a reptile and a bird get their own categories in Hebrew', (tester) async {
        for (final (pet, chips) in [
          (mitzi, ['שתייה', 'יללות', 'נשיכות או שריטות', 'שימוש בארגז החול']),
          (gil, ['האכלה', 'נשל', 'טמפרטורה', 'לחות', 'תאורה']),
          (rio, ['תזונה', 'צואה', 'נוצות', 'פעילות', 'סביבה', 'קולות']),
        ]) {
          await pumpHealth(
            tester,
            harness: HealthHarness(repository: fakeHealth(seeded: false), pets: [pet], language: AppLanguage.hebrew),
            size: size,
          );
          await tapVisible(tester, find.byKey(const Key('overview-quick-log')));
          expect(find.text(he.quickLogFor(pet.name)), findsOneWidget);
          for (final chip in chips) {
            expect(inSheet(find.widgetWithText(ChoiceChip, chip)), findsOneWidget, reason: '${pet.name}: $chip');
          }
          if (pet == rio || pet == gil) {
            // Weighed in grams.
            await tapVisible(tester, find.byKey(const ValueKey('quick-weight')));
            expect(find.text(he.weightInGrams), findsOneWidget);
          }
          // Only one app on screen at a time.
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('a pet with nothing logged is invited to the Quick log', (tester) async {
        await openInsights(tester, size: size);
        await selectPet(tester, 'Soya');
        expect(find.text(he.insightsEmpty), findsOneWidget);
        expect(find.text(he.insightsEmptyNote('Soya')), findsOneWidget);
        await tapVisible(tester, find.text(he.openQuickLog));
        expect(find.text(he.quickLogFor('Soya')), findsOneWidget);
      });
    });
  }

  test('every Quick log category and answer has Hebrew words of its own', () {
    for (final species in PetSpecies.values) {
      final settings = SpeciesSettings.of(species);
      for (final category in settings.quickLog) {
        final hebrew = he.quickLogCategory(category);
        expect(hasHebrew(hebrew), isTrue, reason: '${category.key} ($species)');
        expect(en.quickLogCategory(category), category.label);
      }
      for (final kind in settings.routineKinds) {
        expect(hasHebrew(he.routineKind(settings, kind)), isTrue, reason: '$kind ($species)');
        expect(en.routineKind(settings, kind), settings.routineLabel(kind));
      }
      for (final kind in settings.recordKinds) {
        expect(hasHebrew(he.recordKind(kind)), isTrue, reason: '$kind');
        expect(en.recordKind(kind), kind.label);
        expect(en.recordKinds(kind), kind.plural);
      }
    }
    for (final level in ObservationLevel.values) {
      expect(hasHebrew(he.level(level)), isTrue, reason: '$level');
      expect(en.level(level), level.label);
    }
    for (final group in QuickLogGroup.values) {
      expect(en.quickLogGroup(group), group.label);
    }
    for (final role in VetRole.values) {
      expect(en.vetRole(role), role.label);
    }
    // The same key is a different word for a dog and for a cat.
    expect(he.quickLogCategory(SpeciesSettings.of(PetSpecies.dog).category('vocalisation')), 'נביחות');
    expect(he.quickLogCategory(SpeciesSettings.of(PetSpecies.cat).category('vocalisation')), 'יללות');
    expect(he.routineKind(SpeciesSettings.of(PetSpecies.reptile), CareKind.cageCleaning), 'ניקוי הטרריום');
    // A category the app does not know keeps the name its key gives it.
    expect(he.quickLogCategory(SpeciesSettings.of(PetSpecies.dog).category('made_up')), 'Made up');
  });

  group('plural forms of Insights', () {
    test('weigh-ins: one, two, many', () {
      expect(he.weighIns(1), 'שקילה אחת');
      expect(he.weighIns(2), 'שתי שקילות');
      expect(he.weighIns(6), '6 שקילות');
      expect(en.weighIns(1), '1 weigh-in');
      expect(en.weighIns(6), '6 weigh-ins');
    });
  });

  test('a change of weight is one whole sentence in both languages', () {
    final english = HealthFormat.forLocale(englishLocale);
    final hebrew = HealthFormat.forLocale(hebrewLocale);
    expect(english.weightChangeSince(23.2, 23, DateTime(2025, 5, 2)), '0.2 kg down since 02.05.25');
    expect(english.weightChangeSince(23, 23.4, DateTime(2025, 5, 2)), '0.4 kg up since 02.05.25');
    expect(english.weightChangeSince(23, 23.01, DateTime(2025, 5, 2)), 'No change since 02.05.25');
    expect(english.weightChangeSince(0.4, 0.412, DateTime(2025, 5, 2), grams: true), '12 g up since 02.05.25');
    expect(
      hebrew.weightChangeSince(23.2, 23, DateTime(2025, 5, 2)),
      'ירידה של \u2068\u20680.2\u2069 ק״ג\u2069 מאז \u206802.05.25\u2069',
    );
    expect(hebrew.weightChangeSince(23, 23.01, DateTime(2025, 5, 2)), 'ללא שינוי מאז \u206802.05.25\u2069');
  });
}
