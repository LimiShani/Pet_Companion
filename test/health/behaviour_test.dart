import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/health_rows.dart';
import 'package:pet_companion/features/health/data/species_settings.dart';
import 'package:pet_companion/models/pet.dart';

import 'health_test_helpers.dart';

/// A cat, a parrot and a gecko to stand beside the sample dogs.
const mitzi = Pet(id: 'mitzi', name: 'Mitzi', species: PetSpecies.cat, breed: 'Domestic shorthair');
const rio = Pet(id: 'rio', name: 'Rio', species: PetSpecies.bird);
const gil = Pet(id: 'gil', name: 'Gil', species: PetSpecies.reptile);

HealthHarness harnessFor(Pet pet) => HealthHarness(repository: fakeHealth(seeded: false), pets: [pet]);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  List<String> labels(PetSpecies species, QuickLogGroup group) =>
      SpeciesSettings.of(species).quickLogIn(group).map((c) => c.label).toList();

  group('species lists', () {
    test('a cat is a first-class animal in every list', () {
      final cat = SpeciesSettings.of(PetSpecies.cat);
      expect(labels(PetSpecies.cat, QuickLogGroup.body), ['Weight', 'Appetite', 'Drinking', 'Dental', 'Other']);
      expect(labels(PetSpecies.cat, QuickLogGroup.behaviour), [
        'Sleep',
        'Meowing',
        'Biting or scratching',
        'When left alone',
        'Litter box use',
        'Other behaviour',
      ]);
      expect(cat.recordKinds.take(4), [
        RecordKind.checkup,
        RecordKind.vaccination,
        RecordKind.preventive,
        RecordKind.medicine,
      ]);
      expect(cat.routineKinds, [
        CareKind.feeding,
        CareKind.litterCleaning,
        CareKind.litterChange,
        CareKind.grooming,
        CareKind.other,
      ]);
      expect(cat.weightInGrams, isFalse);
    });

    test('behaviour follows the animal, and never uses the word anxiety', () {
      expect(labels(PetSpecies.dog, QuickLogGroup.behaviour), [
        'Sleep',
        'Barking',
        'Biting',
        'When left alone',
        'Other behaviour',
      ]);
      expect(labels(PetSpecies.bird, QuickLogGroup.behaviour), ['Sleep', 'Vocalisation', 'Biting']);
      expect(labels(PetSpecies.reptile, QuickLogGroup.behaviour), isEmpty);
      // Only cats are asked about the litter box.
      for (final species in PetSpecies.values.where((s) => s != PetSpecies.cat)) {
        expect(
          SpeciesSettings.of(species).quickLog.map((c) => c.key),
          isNot(contains('litter_box')),
          reason: '$species',
        );
      }
      for (final species in PetSpecies.values) {
        for (final c in SpeciesSettings.of(species).quickLog) {
          expect(c.label.toLowerCase(), isNot(contains('anxiety')));
        }
        // A key is offered once per species.
        final keys = SpeciesSettings.of(species).quickLog.map((c) => c.key).toList();
        expect(keys.toSet().length, keys.length, reason: '$species');
      }
    });

    test('the same simple answers are used for behaviour', () {
      final cat = SpeciesSettings.of(PetSpecies.cat);
      const amount = [ObservationLevel.usual, ObservationLevel.less, ObservationLevel.more, ObservationLevel.unsure];
      for (final key in ['sleep', 'vocalisation', 'biting', 'litter_box']) {
        expect(cat.category(key).levels, amount, reason: key);
      }
      // "More than usual" says nothing about being left alone.
      expect(cat.category('left_alone').levels, [
        ObservationLevel.usual,
        ObservationLevel.different,
        ObservationLevel.unsure,
      ]);
      // One stored key, named after the animal.
      expect(cat.category('vocalisation').label, 'Meowing');
      expect(SpeciesSettings.of(PetSpecies.dog).category('vocalisation').label, 'Barking');
      // A dog's journal can still name an entry logged for a cat.
      expect(SpeciesSettings.of(PetSpecies.dog).category('litter_box').label, 'Litter box use');
    });

    test('cleaning routines are offered to the animals that need them', () {
      expect(SpeciesSettings.of(PetSpecies.dog).routineKinds, isNot(contains(CareKind.cageCleaning)));
      for (final species in [PetSpecies.bird, PetSpecies.rabbit, PetSpecies.reptile, PetSpecies.other]) {
        expect(SpeciesSettings.of(species).routineKinds, contains(CareKind.cageCleaning), reason: '$species');
        expect(SpeciesSettings.of(species).routineKinds, isNot(contains(CareKind.litterChange)), reason: '$species');
      }
      expect(SpeciesSettings.of(PetSpecies.bird).routineLabel(CareKind.cageCleaning), 'Cage cleaning');
      expect(SpeciesSettings.of(PetSpecies.reptile).routineLabel(CareKind.cageCleaning), 'Enclosure cleaning');
      // Stored under its own kind.
      const item = CarePlanItem(
        id: '',
        petId: 'p',
        kind: CareKind.litterChange,
        title: 'Litter change',
        time: TimeOfDay(hour: 10, minute: 0),
        days: {6},
      );
      final row = planItemToRow(item);
      expect(row['kind'], 'litter_change');
      expect(planItemFromRow({...row, 'id': 'i'}).kind, CareKind.litterChange);
      expect(CareKind.fromDb('cage_cleaning'), CareKind.cageCleaning);
      expect(CareKind.fromDb('litter_cleaning'), CareKind.litterCleaning);
    });
  });

  group('Behaviour journal', () {
    testWidgets('a cat gets a Behaviour group with the four simple answers', (tester) async {
      final h = harnessFor(mitzi);
      await pumpHealth(tester, harness: h);
      await tapVisible(tester, find.byKey(const Key('overview-quick-log')));

      expect(find.text('Quick log for Mitzi'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-group-body')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-group-behaviour')), findsOneWidget);
      for (final label in ['Sleep', 'Meowing', 'Biting or scratching', 'When left alone', 'Litter box use']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
      expect(find.widgetWithText(ChoiceChip, 'Barking'), findsNothing);
      expect(find.textContaining('anxiety'), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('quick-vocalisation')));
      for (final level in ['usual', 'less', 'more', 'unsure']) {
        expect(find.byKey(ValueKey('level-$level')), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const ValueKey('level-more')));
      await tester.enterText(find.byKey(const Key('quick-note')), 'Cries at the door around five');
      await tapVisible(tester, find.text('Save to journal'));

      final stored = await real(tester, () => h.repository.fetchObservations('mitzi'));
      expect(stored.single.category, 'vocalisation');
      expect(stored.single.level, ObservationLevel.more);

      // It sits in the Insights journal with every other observation.
      await openSection(tester, 'Insights');
      expect(find.text('Meowing · More than usual'), findsOneWidget);
      expect(find.text('10.06.25 · Cries at the door around five'), findsOneWidget);
      expect(find.textContaining('The app does not interpret it'), findsOneWidget);
    });

    testWidgets('"When left alone" is answered usual, different or not sure', (tester) async {
      await pumpHealth(tester);
      await tapVisible(tester, find.byKey(const Key('overview-quick-log')));

      // Kelly is a dog: barking, not meowing; no litter box.
      expect(find.widgetWithText(ChoiceChip, 'Barking'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-litter_box')), findsNothing);

      await tapVisible(tester, find.byKey(const ValueKey('quick-left_alone')));
      expect(find.byKey(const ValueKey('level-usual')), findsOneWidget);
      expect(find.byKey(const ValueKey('level-different')), findsOneWidget);
      expect(find.byKey(const ValueKey('level-unsure')), findsOneWidget);
      expect(find.byKey(const ValueKey('level-more')), findsNothing);
    });

    testWidgets('one chip shows the whole Behaviour group in the journal', (tester) async {
      final h = harnessFor(mitzi);
      Observation noticed(String category, ObservationLevel level, int day, [String note = '']) => Observation(
        id: '',
        petId: 'mitzi',
        category: category,
        level: level,
        note: note,
        observedAt: DateTime(2025, 6, day, 9),
      );
      for (final observation in [
        noticed('appetite', ObservationLevel.usual, 9),
        noticed('sleep', ObservationLevel.less, 8),
        noticed('biting', ObservationLevel.more, 7, 'Scratched the sofa'),
        // Logged before the answers changed: it keeps what was said.
        noticed('litter_box', ObservationLevel.different, 6),
      ]) {
        await real(tester, () => h.repository.saveObservation(observation));
      }
      await pumpHealth(tester, harness: h);
      await openSection(tester, 'Insights');

      expect(find.text('Appetite · Usual'), findsOneWidget);
      expect(find.text('Litter box use · Different from usual'), findsOneWidget);

      await tapVisible(tester, find.byKey(const Key('journal-behaviour-group')));
      expect(find.text('Appetite · Usual'), findsNothing);
      expect(find.text('Sleep · Less than usual'), findsOneWidget);
      expect(find.text('Biting or scratching · More than usual'), findsOneWidget);
      expect(find.text('07.06.25 · Scratched the sofa'), findsOneWidget);
      expect(find.text('Litter box use · Different from usual'), findsOneWidget);

      // A single category still narrows it further.
      await tapVisible(tester, find.byKey(const ValueKey('journal-sleep')));
      expect(find.text('Sleep · Less than usual'), findsOneWidget);
      expect(find.text('Biting or scratching · More than usual'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('journal-all')));
      expect(find.text('Appetite · Usual'), findsOneWidget);
    });

    testWidgets('without behaviour entries, or for a reptile, nothing extra shows', (tester) async {
      // Kelly's sample journal has no behaviour entry: no group chip.
      await pumpHealth(tester);
      await openSection(tester, 'Insights');
      expect(find.byKey(const Key('journal-behaviour-group')), findsNothing);
    });

    testWidgets('a reptile keeps its single list of categories', (tester) async {
      await pumpHealth(tester, harness: harnessFor(gil));
      await tapVisible(tester, find.byKey(const Key('overview-quick-log')));

      expect(find.byKey(const ValueKey('quick-shedding')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-group-behaviour')), findsNothing);
      expect(find.byKey(const ValueKey('quick-group-body')), findsNothing);
      expect(find.byKey(const ValueKey('quick-sleep')), findsNothing);
    });
  });

  group('Cleaning routines', () {
    Future<void> openRoutineForm(WidgetTester tester) async {
      await openSection(tester, 'Schedule');
      await tapVisible(tester, find.text('Add to the schedule'));
      await tapVisible(tester, find.byKey(const ValueKey('add-routine')));
    }

    testWidgets('a cat gets litter box cleaning and litter change', (tester) async {
      final h = harnessFor(mitzi);
      await pumpHealth(tester, harness: h);
      await openRoutineForm(tester);

      expect(find.byKey(const ValueKey('routine-kind-litterCleaning')), findsOneWidget);
      expect(find.byKey(const ValueKey('routine-kind-litterChange')), findsOneWidget);
      expect(find.byKey(const ValueKey('routine-kind-walk')), findsNothing);
      expect(find.byKey(const ValueKey('routine-kind-cageCleaning')), findsNothing);

      // Choosing a kind fills the title and a usual time and day.
      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-litterChange')));
      expect(find.widgetWithText(TextFormField, 'Litter change'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Sat'), findsNWidgets(2));
      await tapVisible(tester, find.text('Save routine'));

      // Named after its kind, so the kind is not said twice.
      expect(find.text('Litter change'), findsOneWidget);
      expect(find.text('10:00 · Sat'), findsOneWidget);
      final items = await real(tester, () => h.repository.fetchPlanItems('mitzi'));
      expect(items.single.kind, CareKind.litterChange);
      expect(items.single.days, {6});
      expect(items.single.time, const TimeOfDay(hour: 10, minute: 0));
    });

    testWidgets('the daily scoop is ticked like any routine and never needs review', (tester) async {
      final h = harnessFor(mitzi);
      await pumpHealth(tester, harness: h);
      await openRoutineForm(tester);

      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-litterCleaning')));
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('Every day'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('routine-title')), 'Scoop the litter box');
      // A time or days the owner chose are kept when the kind changes.
      await tapVisible(tester, find.byKey(const ValueKey('day-7')));
      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-litterChange')));
      expect(find.text('Mon, Tue, Wed, Thu, Fri, Sat'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-litterCleaning')));
      await tapVisible(tester, find.text('Save routine'));

      final item = (await real(tester, () => h.repository.fetchPlanItems('mitzi'))).single;
      expect(item.kind, CareKind.litterCleaning);
      // Due this evening (the test clock is a Tuesday, 17:40).
      expect(find.byKey(ValueKey('today-${item.id}')), findsOneWidget);
      expect(find.text('Litter box cleaning'), findsOneWidget);

      await tapVisible(tester, find.byKey(ValueKey('tick-${item.id}')));
      expect(find.byKey(ValueKey('today-${item.id}')), findsNothing);
      expect(find.text('Done today · 1'), findsOneWidget);

      // Days later and never ticked again: still not under Needs review.
      h.now = DateTime(2025, 6, 13, 9);
      await openSection(tester, 'Overview');
      await openSection(tester, 'Schedule');
      expect(find.text('Needs review'), findsNothing);
    });

    testWidgets('cage animals get cage cleaning, worded for a reptile', (tester) async {
      await pumpHealth(tester, harness: harnessFor(rio));
      await openRoutineForm(tester);
      expect(find.widgetWithText(ChoiceChip, 'Cage cleaning'), findsOneWidget);
      expect(find.byKey(const ValueKey('routine-kind-litterCleaning')), findsNothing);
    });

    testWidgets('a reptile reads "Enclosure cleaning" in the form and the Schedule', (tester) async {
      await pumpHealth(tester, harness: harnessFor(gil));
      await openRoutineForm(tester);

      await tapVisible(tester, find.byKey(const ValueKey('routine-kind-cageCleaning')));
      expect(find.widgetWithText(ChoiceChip, 'Enclosure cleaning'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Enclosure cleaning'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('routine-title')), 'Clean the tank');
      await tapVisible(tester, find.text('Save routine'));

      expect(find.text('Clean the tank'), findsOneWidget);
      expect(find.text('Enclosure cleaning · 10:00 · Sat'), findsOneWidget);
    });

    testWidgets('a dog keeps its own routine kinds', (tester) async {
      await pumpHealth(tester);
      await openSection(tester, 'Schedule');
      await tapVisible(tester, find.byKey(const Key('schedule-add')));
      await tapVisible(tester, find.byKey(const ValueKey('add-routine')));

      expect(find.byKey(const ValueKey('routine-kind-walk')), findsOneWidget);
      expect(find.byKey(const ValueKey('routine-kind-litterCleaning')), findsNothing);
      expect(find.byKey(const ValueKey('routine-kind-cageCleaning')), findsNothing);
    });
  });
}
