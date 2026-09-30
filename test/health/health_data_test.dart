import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/data/species_settings.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/health/state/schedule_logic.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/state/pets_provider.dart';

import 'health_test_helpers.dart';

void main() {
  const kelly = 'kelly';

  test('the sample data agrees with the home dashboard', () async {
    final repo = fakeHealth();

    final planned = plannedRecords(await repo.fetchRecords(kelly));
    expect(planned.map((r) => r.title), containsAll(['General check', 'Medicine']));
    expect(planned.firstWhere((r) => r.title == 'General check').scheduledAt, DateTime(2025, 6, 12, 18, 20));
    expect(planned.firstWhere((r) => r.title == 'Medicine').scheduledAt, DateTime(2025, 7, 27, 19, 30));

    final weights = weightEntries(await repo.fetchObservations(kelly));
    expect(weights.last.value, 23);

    final items = await repo.fetchPlanItems(kelly);
    expect(items.firstWhere((i) => i.title == 'Dinner').time, const TimeOfDay(hour: 19, minute: 30));
    expect(items.firstWhere((i) => i.title == 'Evening walk').time, const TimeOfDay(hour: 18, minute: 30));

    expect(await repo.fetchRecords('soya'), isEmpty);
    expect(await repo.fetchPlanItems('soya'), isEmpty);
    expect((await repo.fetchProfile('soya')).regularVetId, isNull);
  });

  test('today lists every reminder once, with the answers already given', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(carePlanProvider(kelly), (_, _) {});
    final plan = await container.read(carePlanProvider(kelly).future);

    final today = entriesOn(plan, fixedNow);
    expect(today.map((e) => e.item.title), ['Breakfast', 'Joint tablets', 'Evening walk', 'Dinner', 'Joint tablets']);
    expect(today.where((e) => e.isAnswered).map((e) => e.item.title), ['Breakfast', 'Joint tablets']);
    // Saturdays only.
    expect(entriesOn(plan, DateTime(2025, 6, 14)).map((e) => e.item.title), contains('Brush coat'));
  });

  test('only unanswered medicine reminders of the last week need review', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(carePlanProvider(kelly), (_, _) {});
    final plan = await container.read(carePlanProvider(kelly).future);

    final review = entriesNeedingReview(plan, fixedNow);
    expect(review, hasLength(1));
    expect(review.single.item.title, 'Joint tablets');
    expect(review.single.due, DateTime(2025, 6, 9, 20));

    // Eight days later it has left the list, without being counted as anything.
    expect(entriesNeedingReview(plan, DateTime(2025, 6, 9).add(const Duration(days: 8))).where(
      (e) => e.due == DateTime(2025, 6, 9, 20),
    ), isEmpty);
  });

  test('recording a dose stores the status, the time and who logged it', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(carePlanProvider(kelly), (_, _) {});
    final plan = await container.read(carePlanProvider(kelly).future);
    final evening = entriesOn(plan, fixedNow).last;

    final log = await container.read(carePlanProvider(kelly).notifier).record(
          item: evening.item,
          dueOn: fixedNow,
          status: CareLogStatus.done,
          doneAt: DateTime(2025, 6, 10, 20, 10),
          note: 'Hidden in cheese',
        );

    expect(log.status, CareLogStatus.done);
    expect(log.doneAt, DateTime(2025, 6, 10, 20, 10));
    expect(log.loggedAt, fixedNow);
    expect(log.loggedByName, 'You'); // nobody is signed in here
    expect(log.medicationId, 'm-joint');
    final after = container.read(carePlanProvider(kelly)).value!;
    expect(entriesOn(after, fixedNow).last.isDone, isTrue);

    // "Not sure" is an answer too, and claims nothing about the dose.
    final review = entriesNeedingReview(after, fixedNow).single;
    final unsure = await container.read(carePlanProvider(kelly).notifier).record(
          item: review.item,
          dueOn: review.due,
          status: CareLogStatus.unknown,
        );
    expect(unsure.doneAt, isNull);
    expect(entriesNeedingReview(container.read(carePlanProvider(kelly)).value!, fixedNow), isEmpty);
  });

  test('saving a medicine keeps its reminders in step with the chosen times', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(carePlanProvider('soya'), (_, _) {});
    await container.read(carePlanProvider('soya').future);
    final controller = container.read(carePlanProvider('soya').notifier);

    final saved = await controller.saveMedication(
      const Medication(id: '', petId: 'soya', name: 'Ear drops', dose: '3 drops', route: 'In the ear'),
      times: const [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 21, minute: 0)],
    );
    var plan = container.read(carePlanProvider('soya')).value!;
    expect(plan.itemsOf(saved.id).map((i) => i.time.hour), [9, 21]);
    expect(plan.itemsOf(saved.id).every((i) => i.kind == CareKind.medication && i.title == 'Ear drops'), isTrue);
    // Reminders count from today: nothing of the past needs review.
    expect(entriesNeedingReview(plan, fixedNow.add(const Duration(days: 1))).length, lessThanOrEqualTo(2));
    expect(entriesNeedingReview(plan, fixedNow), isEmpty);

    await controller.saveMedication(saved, times: const [TimeOfDay(hour: 21, minute: 0)], days: {1, 4});
    plan = container.read(carePlanProvider('soya')).value!;
    expect(plan.itemsOf(saved.id).map((i) => i.time.hour), [21]);
    expect(plan.itemsOf(saved.id).single.days, {1, 4});

    await controller.deleteMedication(saved.id);
    plan = container.read(carePlanProvider('soya')).value!;
    expect(plan.isEmpty, isTrue);
  });

  test('a next due date plans one follow-up record and keeps it in step', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(healthRecordsProvider('soya'), (_, _) {});
    await container.read(healthRecordsProvider('soya').future);
    final controller = container.read(healthRecordsProvider('soya').notifier);

    final given = DateTime(2025, 6, 1, 10);
    final record = await controller.save(HealthRecord(
      id: '',
      petId: 'soya',
      kind: RecordKind.vaccination,
      title: 'Rabies vaccine',
      scheduledAt: given,
      doneAt: given,
      nextDueOn: DateTime(2026, 6, 1),
    ));
    List<HealthRecord> planned() => plannedRecords(container.read(healthRecordsProvider('soya')).value!);
    expect(planned(), hasLength(1));
    expect(planned().single.title, 'Rabies vaccine');
    expect(planned().single.followUpOf, record.id);
    expect(dateOnly(planned().single.scheduledAt), DateTime(2026, 6, 1));

    await controller.save(record.withNextDue(DateTime(2026, 7, 15)));
    expect(planned(), hasLength(1));
    expect(dateOnly(planned().single.scheduledAt), DateTime(2026, 7, 15));

    await controller.save(record.withNextDue(null));
    expect(planned(), isEmpty);
  });

  test('the reminder scheduler receives the plan on load and on every change', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(carePlanProvider(kelly), (_, _) {});
    container.listen(healthRecordsProvider(kelly), (_, _) {});
    await container.read(carePlanProvider(kelly).future);
    await container.read(healthRecordsProvider(kelly).future);
    await Future<void>.delayed(Duration.zero);

    expect(h.scheduler.plans, isNotEmpty);
    expect(h.scheduler.last.petId, kelly);
    expect(h.scheduler.last.petName, 'Kelly');
    expect(h.scheduler.last.items, hasLength(6));
    expect(h.scheduler.last.upcoming.map((r) => r.title), containsAll(['General check', 'Medicine']));

    final before = h.scheduler.plans.length;
    await container.read(carePlanProvider(kelly).notifier).saveRoutine(const CarePlanItem(
          id: '',
          petId: kelly,
          kind: CareKind.feeding,
          title: 'Lunch',
          time: TimeOfDay(hour: 13, minute: 0),
        ));
    expect(h.scheduler.plans.length, greaterThan(before));
    expect(h.scheduler.last.items.map((i) => i.title), contains('Lunch'));
  });

  test('logging a weight updates the weight on the pet profile', () async {
    final h = HealthHarness();
    final container = h.container();
    container.listen(observationsProvider(kelly), (_, _) {});
    await container.read(observationsProvider(kelly).future);

    await container.read(observationsProvider(kelly).notifier).save(Observation(
          id: '',
          petId: kelly,
          category: Observation.weightCategory,
          value: 22.6,
          observedAt: fixedNow,
        ));

    expect(weightEntries(container.read(observationsProvider(kelly)).value!).last.value, 22.6);
    expect(container.read(petsProvider).firstWhere((p) => p.id == kelly).weightKg, 22.6);
  });

  test('a failing backend surfaces as an error with a friendly message', () async {
    final h = HealthHarness();
    h.repository.failing = true;
    final container = h.container();
    container.listen(healthRecordsProvider(kelly), (_, _) {});
    await expectLater(container.read(healthRecordsProvider(kelly).future), throwsA(isA<HealthException>()));
    final state = container.read(healthRecordsProvider(kelly));
    expect(state.hasError, isTrue);
    expect(healthErrorMessage(state.error!), contains('Could not reach the server'));
  });

  test('only photos and PDFs up to 5 MB can be attached', () {
    expect(testPhoto().problem, isNull);
    expect(testPdf().problem, isNull);
    expect(hugePdf().problem, contains('5 MB'));
    expect(PickedFile(name: 'a.gif', mimeType: 'image/gif', bytes: testPhoto().bytes).problem, isNotNull);
    expect(PickedFile.mimeTypeFor('Scan.PDF'), 'application/pdf');
    expect(PickedFile.mimeTypeFor('movie.mp4'), isNull);
  });

  test('each species gets its own Quick log categories and weight unit', () {
    final dog = SpeciesSettings.of(PetSpecies.dog);
    final bird = SpeciesSettings.of(PetSpecies.bird);
    expect(dog.quickLog.map((c) => c.label), containsAll(['Weight', 'Appetite', 'Mobility', 'Skin or coat']));
    expect(bird.quickLog.map((c) => c.label), containsAll(['Weight', 'Droppings', 'Feathers', 'Vocalisation']));
    expect(bird.quickLog.map((c) => c.label), isNot(contains('Mobility')));
    expect(dog.weightInGrams, isFalse);
    expect(bird.weightInGrams, isTrue);
    expect(dog.routineKinds, contains(CareKind.walk));
    expect(bird.routineKinds, isNot(contains(CareKind.walk)));
    // Every kind stays available; the species only changes the order.
    expect(bird.recordKinds.toSet(), RecordKind.values.toSet());
    expect(bird.recordKinds.first, RecordKind.checkup);
    // A category logged under another species still has a name.
    expect(dog.category('feathers').label, 'Feathers');
    expect(dog.category('made_up').label, 'Made up');
  });

  test('a medicine shows the vet\'s instructions exactly as typed', () {
    const m = Medication(
      id: 'm',
      petId: kelly,
      name: 'Joint tablets',
      strength: '50 mg',
      dose: '1 tablet',
      route: 'By mouth',
      frequency: 'Twice a day with food',
    );
    expect(m.displayName, 'Joint tablets 50 mg');
    expect(m.instructionLine, '1 tablet by mouth, twice a day with food');
    expect(const Medication(id: 'm', petId: kelly, name: 'Drops').instructionLine, '');
  });
}
