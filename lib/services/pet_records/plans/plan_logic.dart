/// The yearly plan's arithmetic: what a pet's plan looks like today (the
/// next date of each item, from its age and its records), the planned
/// record an item becomes, and the next one once it is done.
///
/// Plain functions on plain data, so they are tested without a backend;
/// `plan_providers.dart` wires them to the records.
library;

import '../../../models/pet.dart';
import '../data/health_models.dart';
import 'plan_templates.dart';

/// How a planned record says which plan item it is: the item's key, the
/// dose of a puppy or kitten series, and the interval in months the owner
/// chose for an item that has a choice. Written as `dog.combined#2` or
/// `dog.flea@3m` in `health_events.plan_item`.
class PlanRef {
  const PlanRef(this.key, {this.dose, this.months});

  /// `dog.rabies`.
  final String key;

  /// 1, 2 or 3 for a dose of the series; `null` for the item itself.
  final int? dose;

  /// The interval the owner chose, in months.
  final int? months;

  static final _shape = RegExp(r'^([a-z]+\.[a-z_]+)(?:#([1-9]))?(?:@([1-9][0-9]?)m)?$');

  /// The reference written as [value], or `null` when it is not one.
  static PlanRef? parse(String? value) {
    if (value == null) return null;
    final m = _shape.firstMatch(value);
    if (m == null) return null;
    return PlanRef(
      m[1]!,
      dose: m[2] == null ? null : int.parse(m[2]!),
      months: m[3] == null ? null : int.parse(m[3]!),
    );
  }

  PlanTemplateItem? get item => planTemplateByKey(key);

  @override
  String toString() =>
      '$key${dose == null ? '' : '#$dose'}${months == null ? '' : '@${months}m'}';

  @override
  bool operator ==(Object other) =>
      other is PlanRef &&
      other.key == key &&
      other.dose == dose &&
      other.months == months;

  @override
  int get hashCode => Object.hash(key, dose, months);
}

/// Why an item's first date is what it is; the plan sheet says it in words.
enum PlanBasis {
  /// From the last time it was done (its interval after that).
  lastDone,

  /// The last time it was done is longer ago than its interval: as soon as
  /// possible (today).
  overdue,

  /// Nothing on record: in [noHistoryLeadDays] days, so there is time to
  /// check the vaccination booklet first.
  noHistory,

  /// The pet is too young: on the day it reaches the item's starting age.
  tooYoung,

  /// The next dose of the puppy or kitten series.
  series,

  /// Already planned (a record that is not done yet): nothing new is made.
  alreadyPlanned,
}

/// Days until an item with nothing on record is planned.
const noHistoryLeadDays = 14;

/// The hour a planned record of the plan is set at (like a follow-up).
const planRecordHour = 9;

/// One item of a pet's plan as it stands today.
class PlanProposal {
  const PlanProposal({
    required this.item,
    required this.ref,
    required this.due,
    required this.basis,
    this.lastDone,
    this.planned,
  });

  final PlanTemplateItem item;
  final PlanRef ref;

  /// The day of the next occurrence.
  final DateTime due;
  final PlanBasis basis;

  /// The most recent done record of the item.
  final HealthRecord? lastDone;

  /// The planned record of the item that already exists.
  final HealthRecord? planned;

  String title({required bool hebrew}) =>
      planned?.title ?? item.titleOf(hebrew: hebrew, dose: ref.dose);

  /// The same item with the interval in [months] (for an item with a
  /// choice): the date moves when it was counted from the last time.
  PlanProposal withMonths(int months, {required DateTime today}) {
    if (item.monthChoices.isEmpty || planned != null) return this;
    final ref = PlanRef(item.key, months: months);
    final last = lastDone;
    if (last == null) {
      return PlanProposal(item: item, ref: ref, due: due, basis: basis);
    }
    final next = PlanInterval.months(months).after(dateOnly(last.when));
    final overdue = next.isBefore(dateOnly(today));
    return PlanProposal(
      item: item,
      ref: ref,
      due: overdue ? dateOnly(today) : next,
      basis: overdue ? PlanBasis.overdue : PlanBasis.lastDone,
      lastDone: last,
    );
  }
}

/// The pet's birthday: the one given, or worked out from the age given
/// directly (the sample pets); `null` when the age is not known.
DateTime? birthOf(Pet pet, DateTime today) {
  final born = pet.birthDate;
  if (born != null) return dateOnly(born);
  final years = pet.ageYearsAt(today);
  if (years == null) return null;
  return addDays(dateOnly(today), -(years * 365.25).round());
}

/// Whole weeks from [birth] to [day], or `null` without a birthday.
int? ageWeeksAt(DateTime? birth, DateTime day) =>
    birth == null ? null : daysBetween(birth, day) ~/ 7;

DateTime _latest(Iterable<DateTime> days) =>
    days.reduce((a, b) => a.isAfter(b) ? a : b);

/// The pet's plan today: one proposal per item of its species, in the
/// plan's order. [months] holds the owner's interval choices by item key.
///
/// For each item: a planned record of it already there is kept as it is;
/// a puppy or kitten in its first series gets the next dose (at its age
/// in the series, at least the series' gap after the last dose, never
/// before today); otherwise the item's interval after the last time it
/// was done (today when that has passed), the day the pet reaches the
/// starting age, or, with nothing on record, [noHistoryLeadDays] from
/// today.
List<PlanProposal> proposePlan({
  required Pet pet,
  required List<HealthRecord> records,
  required DateTime today,
  Map<String, int> months = const {},
}) {
  final day = dateOnly(today);
  final birth = birthOf(pet, day);
  final age = ageWeeksAt(birth, day);
  return [
    for (final item in planTemplatesFor(pet.species))
      _propose(
        item,
        records: records,
        today: day,
        birth: birth,
        age: age,
        months: months[item.key],
      ),
  ];
}

PlanProposal _propose(
  PlanTemplateItem item, {
  required List<HealthRecord> records,
  required DateTime today,
  required DateTime? birth,
  required int? age,
  required int? months,
}) {
  final mine = records.where(item.matches).toList();
  final done = [
    for (final r in mine)
      if (r.isDone) r,
  ]..sort((a, b) => b.when.compareTo(a.when));
  final planned = [
    for (final r in mine)
      if (!r.isDone) r,
  ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  final last = done.isEmpty ? null : done.first;
  final chosen = item.monthChoices.contains(months) ? months : null;
  final ref = PlanRef(item.key, months: chosen);

  if (planned.isNotEmpty) {
    final p = planned.first;
    return PlanProposal(
      item: item,
      ref: PlanRef.parse(p.planItem) ?? ref,
      due: dateOnly(p.scheduledAt),
      basis: PlanBasis.alreadyPlanned,
      lastDone: last,
      planned: p,
    );
  }

  final series = item.series;
  if (series != null && birth != null && age! < series.endsAtWeeks) {
    // Doses given since the series could start count as its doses.
    final start = addDays(birth, (item.startAgeWeeks - 1) * 7);
    final given = done.where((r) => !r.when.isBefore(start)).length;
    if (given < series.count) {
      final dose = given + 1;
      final due = _latest([
        addDays(birth, series.ageWeeks[given] * 7),
        if (last != null) addDays(dateOnly(last.when), series.minGapWeeks * 7),
        today,
      ]);
      return PlanProposal(
        item: item,
        ref: PlanRef(item.key, dose: dose),
        due: due,
        basis: PlanBasis.series,
        lastDone: last,
      );
    }
  }

  if (last != null) {
    final lastDay = dateOnly(last.when);
    final next = item
        .intervalAt(ageWeeksAt(birth, lastDay), months: chosen)
        .after(lastDay);
    final overdue = next.isBefore(today);
    return PlanProposal(
      item: item,
      ref: ref,
      due: overdue ? today : next,
      basis: overdue ? PlanBasis.overdue : PlanBasis.lastDone,
      lastDone: last,
    );
  }

  if (birth != null) {
    final starts = addDays(birth, item.startAgeWeeks * 7);
    if (starts.isAfter(today)) {
      return PlanProposal(
        item: item,
        ref: ref,
        due: starts,
        basis: PlanBasis.tooYoung,
      );
    }
  }
  return PlanProposal(
    item: item,
    ref: ref,
    due: addDays(today, noHistoryLeadDays),
    basis: PlanBasis.noHistory,
  );
}

/// The planned record [proposal] becomes, in the app's language
/// ([hebrew]), at [planRecordHour] on its day.
HealthRecord plannedRecordOf(
  PlanProposal proposal, {
  required String petId,
  required bool hebrew,
}) {
  final d = proposal.due;
  return HealthRecord(
    id: '',
    petId: petId,
    kind: proposal.item.kind,
    title: proposal.title(hebrew: hebrew),
    scheduledAt: DateTime(d.year, d.month, d.day, planRecordHour),
    planItem: proposal.ref.toString(),
  );
}

/// What comes after a plan item done on [doneOn]: the next dose of the
/// series (or the yearly booster after the last one), or the item again
/// after its interval.
class PlanStep {
  const PlanStep(this.item, this.ref, this.due);

  final PlanTemplateItem item;
  final PlanRef ref;
  final DateTime due;

  String title({required bool hebrew}) =>
      item.titleOf(hebrew: hebrew, dose: ref.dose);
}

/// The step after [record], a done record of a plan, or `null` when it is
/// not one (or its item is no longer in the plans). [birth] is the pet's
/// birthday, for the series and the intervals of the young.
PlanStep? nextPlanStep(HealthRecord record, {DateTime? birth}) {
  final ref = PlanRef.parse(record.planItem);
  final item = ref?.item;
  final at = record.doneAt;
  if (ref == null || item == null || at == null) return null;
  final day = dateOnly(at);
  final series = item.series;
  final dose = ref.dose;
  if (series != null && dose != null) {
    if (dose < series.count) {
      final gap = addDays(day, series.minGapWeeks * 7);
      final due = birth == null
          ? addDays(day, 4 * 7)
          : _latest([gap, addDays(birth, series.ageWeeks[dose] * 7)]);
      return PlanStep(item, PlanRef(item.key, dose: dose + 1), due);
    }
    return PlanStep(item, PlanRef(item.key), item.interval.after(day));
  }
  final interval = item.intervalAt(ageWeeksAt(birth, day), months: ref.months);
  return PlanStep(
    item,
    PlanRef(item.key, months: ref.months),
    interval.after(day),
  );
}

/// [record] about to be saved, with the "next due" date of its plan item
/// when it has just been marked done: a planned record of a plan that was
/// not done before ([before]) and has no next due date of its own. The
/// existing follow-up logic then plans that date. Any other record is
/// returned as it is: the next due date of a record added by hand is the
/// vet's, never the app's.
HealthRecord withPlanNextDue(
  HealthRecord record, {
  HealthRecord? before,
  DateTime? birth,
}) {
  if (!record.isFromPlan ||
      !record.isDone ||
      !record.kind.hasNextDue ||
      record.nextDueOn != null ||
      (before != null && before.isDone)) {
    return record;
  }
  final step = nextPlanStep(record, birth: birth);
  return step == null ? record : record.withNextDue(step.due);
}

/// The planned follow-up of [saved], a done record of a plan with a next
/// due date: the next step's title (a series moves on to its next dose)
/// and plan item. `null` when [saved] is not from a plan.
({String title, String planItem})? planFollowUpOf(
  HealthRecord saved, {
  DateTime? birth,
  required bool hebrew,
}) {
  final step = nextPlanStep(saved, birth: birth);
  if (step == null) return null;
  return (title: step.title(hebrew: hebrew), planItem: step.ref.toString());
}
