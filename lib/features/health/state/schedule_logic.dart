import '../data/health_models.dart';

/// A pet's medicines, recurring reminders and the recent log of what was
/// actually done.
class CarePlan {
  const CarePlan({this.medications = const [], this.items = const [], this.logs = const []});

  final List<Medication> medications;
  final List<CarePlanItem> items;
  final List<CareLog> logs;

  bool get isEmpty => medications.isEmpty && items.isEmpty;

  Medication? medication(String? id) {
    if (id == null) return null;
    for (final m in medications) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Medicines being given on [day].
  List<Medication> activeMedications(DateTime day) => [
        for (final m in medications)
          if (m.isActiveOn(day)) m,
      ];

  /// Reminders of one medicine, earliest first.
  List<CarePlanItem> itemsOf(String medicationId) => [
        for (final i in items)
          if (i.medicationId == medicationId) i,
      ]..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));

  /// The most recent dose recorded as given for a medicine, or `null`.
  CareLog? lastDose(String medicationId) {
    CareLog? last;
    for (final log in logs) {
      if (log.medicationId != medicationId || log.status != CareLogStatus.done) continue;
      final at = log.doneAt;
      if (at == null) continue;
      if (last == null || at.isAfter(last.doneAt!)) last = log;
    }
    return last;
  }

  CarePlan copyWith({List<Medication>? medications, List<CarePlanItem>? items, List<CareLog>? logs}) => CarePlan(
        medications: medications ?? this.medications,
        items: items ?? this.items,
        logs: logs ?? this.logs,
      );
}

/// One occurrence of a reminder on a given day, with the owner's answer
/// if there is one.
class ScheduleEntry {
  const ScheduleEntry({required this.item, required this.due, this.log, this.medication});

  final CarePlanItem item;

  /// The day and time it is due.
  final DateTime due;
  final CareLog? log;
  final Medication? medication;

  bool get isAnswered => log != null;
  bool get isDone => log?.status == CareLogStatus.done;
}

/// The reminders due on [day], earliest first.
List<ScheduleEntry> entriesOn(CarePlan plan, DateTime day) {
  final entries = <ScheduleEntry>[];
  for (final item in plan.items) {
    if (!item.occursOn(day)) continue;
    final medication = plan.medication(item.medicationId);
    if (item.isMedication && medication != null && !medication.isActiveOn(day)) continue;
    CareLog? log;
    for (final l in plan.logs) {
      if (l.planItemId == item.id && isSameDay(l.dueOn, day)) log = l;
    }
    entries.add(ScheduleEntry(item: item, due: atTime(day, item.time), log: log, medication: medication));
  }
  entries.sort((a, b) => a.due.compareTo(b.due));
  return entries;
}

/// How long an unanswered medicine reminder waits for an answer.
const needsReviewDays = 7;

/// Medicine reminders of the past [needsReviewDays] days that nobody
/// answered, newest first. They are not "missed doses": the app only knows
/// that no answer was recorded. Routines never need review.
List<ScheduleEntry> entriesNeedingReview(CarePlan plan, DateTime now) {
  final today = dateOnly(now);
  final entries = <ScheduleEntry>[];
  for (var back = 1; back <= needsReviewDays; back++) {
    final day = today.subtract(Duration(days: back));
    final ofDay = entriesOn(plan, day).where((e) => e.item.isMedication && !e.isAnswered).toList()
      ..sort((a, b) => b.due.compareTo(a.due));
    entries.addAll(ofDay);
  }
  return entries;
}

/// Planned records (appointments and due dates), soonest first.
List<HealthRecord> plannedRecords(List<HealthRecord> records) => [
      for (final r in records)
        if (!r.isDone) r,
    ]..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

/// Done records, newest first.
List<HealthRecord> historyRecords(List<HealthRecord> records) => [
      for (final r in records)
        if (r.isDone) r,
    ]..sort((a, b) => b.when.compareTo(a.when));

/// Weight measurements, oldest first.
List<Observation> weightEntries(List<Observation> observations) => [
      for (final o in observations)
        if (o.isWeight) o,
    ]..sort((a, b) => a.observedAt.compareTo(b.observedAt));
