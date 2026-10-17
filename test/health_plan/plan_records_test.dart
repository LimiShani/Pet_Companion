import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pet_companion/access/access_provider.dart';
import 'package:pet_companion/models/pet.dart';
import 'package:pet_companion/services/pet_records/data/health_models.dart';
import 'package:pet_companion/services/pet_records/data/health_rows.dart';
import 'package:pet_companion/services/pet_records/plans/plan_logic.dart';
import 'package:pet_companion/services/pet_records/plans/plan_providers.dart';
import 'package:pet_companion/services/pet_records/state/health_providers.dart';

import '../health/health_test_helpers.dart';

/// A puppy of 9 weeks on [fixedNow] (10 June 2025), and an adult cat.
final puppy = Pet(id: 'kelly', name: 'Kelly', birthDate: DateTime(2025, 4, 8));
const adultCat = Pet(id: 'soya', name: 'Soya', species: PetSpecies.cat, ageYears: 5);

Future<List<HealthRecord>> recordsOf(ProviderContainer c, String petId) =>
    c.read(healthRecordsProvider(petId).future);

void main() {
  // The app's language follows the phone's, which needs the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('the plan_item column travels only when it is set', () {
    final byHand = HealthRecord(
      id: '',
      petId: 'kelly',
      kind: RecordKind.checkup,
      title: 'General check',
      scheduledAt: DateTime(2026, 10, 20, 9),
    );
    expect(recordToRow(byHand).containsKey('plan_item'), isFalse);
    final fromPlan = byHand.copyWith(kind: RecordKind.vaccination, planItem: 'dog.rabies');
    expect(recordToRow(fromPlan)['plan_item'], 'dog.rabies');
    final row = {
      ...recordToRow(fromPlan),
      'id': 'r1',
      'plan_item': 'dog.combined#2',
    };
    expect(recordFromRow(row).planItem, 'dog.combined#2');
    expect(recordFromRow({...row, 'plan_item': null}).isFromPlan, isFalse);
    // Kept through the record's other changes.
    expect(fromPlan.withDone(DateTime(2026, 10, 20)).planItem, 'dog.rabies');
    expect(fromPlan.withNextDue(DateTime(2027, 10, 20)).planItem, 'dog.rabies');
  });

  test('choosing items creates planned records; marking one done plans the '
      'next step of the plan', () async {
    final h = HealthHarness(repository: fakeHealth(seeded: false), pets: [puppy, adultCat]);
    final c = h.container();
    c.listen(healthRecordsProvider('kelly'), (_, _) {});
    c.listen(yearlyPlanProvider('kelly'), (_, _) {});

    final plan = await c.read(yearlyPlanProvider('kelly').future);
    expect(plan.map((p) => p.item.key), ['dog.rabies', 'dog.combined', 'dog.spirocerca', 'dog.deworm', 'dog.flea']);
    final combined = plan.firstWhere((p) => p.item.key == 'dog.combined');
    final rabies = plan.firstWhere((p) => p.item.key == 'dog.rabies');
    expect(combined.ref.toString(), 'dog.combined#1');

    final saved = await c.read(yearlyPlanServiceProvider).apply('kelly', [combined, rabies]);
    expect(saved, hasLength(2));
    var records = await recordsOf(c, 'kelly');
    expect(records.map((r) => r.planItem), unorderedEquals(['dog.combined#1', 'dog.rabies']));
    expect(records.every((r) => !r.isDone && r.scheduledAt.hour == planRecordHour), isTrue);

    // The plan now shows them as planned; choosing again makes nothing new.
    final again = await c.read(yearlyPlanProvider('kelly').future);
    expect(again.firstWhere((p) => p.item.key == 'dog.combined').basis, PlanBasis.alreadyPlanned);
    final chosenAgain = [
      for (final p in again)
        if (p.item.key == 'dog.combined' || p.item.key == 'dog.rabies') p,
    ];
    expect(await c.read(yearlyPlanServiceProvider).apply('kelly', chosenAgain), isEmpty);
    expect(await recordsOf(c, 'kelly'), hasLength(2));

    // The first puppy dose is given: the second one is planned at 12 weeks.
    final dose1 = records.firstWhere((r) => r.planItem == 'dog.combined#1');
    final given = await c
        .read(healthRecordsProvider('kelly').notifier)
        .setDone(dose1, DateTime(2025, 6, 10, 10));
    expect(given.nextDueOn, DateTime(2025, 7, 1), reason: '12 weeks old');
    records = await recordsOf(c, 'kelly');
    final dose2 = records.singleWhere((r) => r.followUpOf == given.id);
    expect(dose2.planItem, 'dog.combined#2');
    expect(dose2.title, 'Combined vaccine, puppy dose 2 of 3');
    expect(dose2.scheduledAt, DateTime(2025, 7, 1, 9));
    expect(dose2.isDone, isFalse);
  });

  test('a record planned by hand joins the plan instead of a second one', () async {
    final h = HealthHarness(repository: fakeHealth(seeded: false), pets: [puppy, adultCat]);
    final c = h.container();
    c.listen(healthRecordsProvider('soya'), (_, _) {});
    final byHand = await c
        .read(healthRecordsProvider('soya').notifier)
        .save(
          HealthRecord(
            id: '',
            petId: 'soya',
            kind: RecordKind.vaccination,
            title: 'Rabies booster',
            scheduledAt: DateTime(2025, 9, 1, 17),
          ),
        );
    final plan = await c.read(yearlyPlanProvider('soya').future);
    final rabies = plan.firstWhere((p) => p.item.key == 'cat.rabies');
    expect(rabies.planned?.id, byHand.id);
    await c.read(yearlyPlanServiceProvider).apply('soya', [rabies]);
    final records = await recordsOf(c, 'soya');
    expect(records, hasLength(1));
    expect(records.single.planItem, 'cat.rabies');
    expect(records.single.title, 'Rabies booster');

    // Done: once a year from the day it was given.
    final done = await c
        .read(healthRecordsProvider('soya').notifier)
        .setDone(records.single, DateTime(2025, 9, 2, 17));
    expect(done.nextDueOn, DateTime(2026, 9, 2));
    final next = (await recordsOf(c, 'soya')).singleWhere((r) => r.followUpOf == done.id);
    expect(next.planItem, 'cat.rabies');
    expect(next.title, 'Rabies vaccine');
  });

  test('without the capability there is no plan, and nothing is created', () async {
    final h = HealthHarness(repository: fakeHealth(seeded: false), pets: [puppy, adultCat]);
    final c = h.container();
    final access = c.read(accessRepositoryProvider) as FakeAccessRepository;
    access.groups['standard']!.remove(plansCapability);
    c.invalidate(accessProvider);
    expect(await c.read(yearlyPlanProvider('kelly').future), isEmpty);
    await expectLater(
      c.read(yearlyPlanServiceProvider).apply('kelly', []),
      throwsA(isA<FeatureDenied>()),
    );
  });

  test('the invitation: dogs and cats only, while no vaccination is on record', () {
    expect(hasYearlyPlan(puppy), isTrue);
    expect(hasYearlyPlan(const Pet(id: 'b', name: 'Bun', species: PetSpecies.rabbit)), isFalse);
    expect(hasNoVaccinations(const []), isTrue);
    expect(
      hasNoVaccinations([
        HealthRecord(
          id: 'r',
          petId: 'kelly',
          kind: RecordKind.vaccination,
          title: 'Rabies',
          scheduledAt: DateTime(2025, 1, 1),
        ),
      ]),
      isFalse,
    );
  });
}
