import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/features/health/data/fake_health_repository.dart';
import 'package:pet_companion/features/health/data/health_models.dart';
import 'package:pet_companion/features/health/state/health_providers.dart';
import 'package:pet_companion/features/health/state/schedule_logic.dart';

import 'health_test_helpers.dart';

const _soya = 'soya';
const _morning = TimeOfDay(hour: 8, minute: 0);
const _evening = TimeOfDay(hour: 20, minute: 0);

/// The sample data, where the second reminder of a new medicine fails to
/// save once, as if the connection dropped half way.
class _SecondReminderFailsOnce extends FakeHealthRepository {
  _SecondReminderFailsOnce() : super(latency: Duration.zero, now: () => fixedNow);

  int _newReminders = 0;

  @override
  Future<CarePlanItem> savePlanItem(CarePlanItem item) {
    if (item.isNew && ++_newReminders == 2) return Future.error(HealthException.of(HealthFailure.offline));
    return super.savePlanItem(item);
  }
}

void main() {
  test('a medicine whose reminders failed half way is not stored twice when saved again', () async {
    final repository = _SecondReminderFailsOnce();
    final container = HealthHarness(repository: repository).container();
    // Kept alive as the Schedule screen keeps it.
    container.listen(carePlanProvider(_soya), (_, _) {});
    final plan = container.read(carePlanProvider(_soya).notifier);
    await container.read(carePlanProvider(_soya).future);

    const draft = Medication(id: '', petId: _soya, name: 'Ear drops');
    final failure = await plan
        .saveMedication(draft, times: [_morning, _evening])
        .then<RemindersNotSaved?>((_) => null, onError: (Object e) => e as RemindersNotSaved);
    expect(failure, isNotNull);
    // What did work is in the plan already.
    expect(container.read(carePlanProvider(_soya)).value!.itemsOf(failure!.saved.id), hasLength(1));

    // Saving again, as the form does: the stored medicine, not the draft.
    await plan.saveMedication(Medication(id: failure.saved.id, petId: _soya, name: 'Ear drops'), times: [
      _morning,
      _evening,
    ]);

    final medicines = await repository.fetchMedications(_soya);
    expect([for (final m in medicines) m.name], ['Ear drops']);
    final reminders = await repository.fetchPlanItems(_soya);
    expect([for (final r in reminders) minutesOf(r.time)]..sort(), [8 * 60, 20 * 60]);
  });

  test('a weekday added to a reminder never makes last week need review', () async {
    final repository = fakeHealth(seeded: false);
    final container = HealthHarness(repository: repository).container();
    container.listen(carePlanProvider(_soya), (_, _) {});
    await container.read(carePlanProvider(_soya).future);

    // Mondays only, set up long ago, every dose answered.
    final medicine = await repository.saveMedication(const Medication(id: '', petId: _soya, name: 'Ear drops'));
    await repository.savePlanItem(
      CarePlanItem(
        id: '',
        petId: _soya,
        kind: CareKind.medication,
        title: 'Ear drops',
        time: _morning,
        days: const {DateTime.monday},
        medicationId: medicine.id,
        startsOn: DateTime(2025, 1, 1),
      ),
    );
    container.invalidate(carePlanProvider(_soya));
    await container.read(carePlanProvider(_soya).future);
    final plan = container.read(carePlanProvider(_soya).notifier);
    final mondays = entriesNeedingReview(container.read(carePlanProvider(_soya)).value!, fixedNow);
    expect(mondays, hasLength(1));
    for (final entry in mondays) {
      await plan.record(item: entry.item, dueOn: entry.due, status: CareLogStatus.done);
    }
    expect(entriesNeedingReview(container.read(carePlanProvider(_soya)).value!, fixedNow), isEmpty);

    // Now every day.
    await plan.saveMedication(medicine, times: [_morning]);

    expect(entriesNeedingReview(container.read(carePlanProvider(_soya)).value!, fixedNow), isEmpty);
  });
}
