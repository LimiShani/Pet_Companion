import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../records/record_detail_screen.dart';
import '../records/record_form_screen.dart';
import '../schedule/medicine_form_screen.dart';
import '../schedule/record_dose_sheet.dart';
import '../schedule/routine_form_screen.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';

/// Opens the "what do you want to add?" sheet of the Schedule: an
/// appointment or due date, a medicine, or a routine.
Future<void> showScheduleAddSheet(BuildContext context, Pet pet) async {
  final choice = await showHealthSheet<int>(context, const _AddSheet());
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case 0:
      await openRecordForm(context, pet, kind: RecordKind.checkup, planned: true);
    case 1:
      await openMedicineForm(context, pet);
    case 2:
      await openRoutineForm(context, pet);
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.healthL10n;
    Widget option(int value, String key, IconData icon, String title, String detail) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 8),
      child: HealthCard(
        key: ValueKey('add-$key'),
        onTap: () => Navigator.of(context).pop(value),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconDisc(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  Text(detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(l10n.addToSchedule),
        const SizedBox(height: 12),
        option(0, 'appointment', Icons.event_rounded, l10n.addAppointment, l10n.addAppointmentNote),
        option(1, 'medicine', Icons.medication_rounded, l10n.medicine, l10n.addMedicineNote),
        option(2, 'routine', Icons.restaurant_rounded, l10n.routine, l10n.addRoutineNote),
      ],
    );
  }
}

/// Today, Upcoming and Needs review. Routines are ticked directly; a
/// medicine opens "Record dose". A reminder nobody answered is never
/// counted as missed: it waits under Needs review.
class ScheduleSection extends ConsumerWidget {
  const ScheduleSection({super.key, required this.pet, required this.data});

  final Pet pet;
  final PetHealthData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(healthClockProvider)();
    final plan = data.plan;
    final planned = upcomingRecords(data.records, now);
    final reviewRecords = recordsNeedingReview(data.records, now);
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final settings = SpeciesSettings.of(pet.species);

    if (plan.isEmpty && planned.isEmpty && reviewRecords.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_rounded,
        title: l10n.scheduleEmpty,
        message: l10n.scheduleEmptyNote(pet.name),
        actionLabel: l10n.addToSchedule,
        onAction: () => showScheduleAddSheet(context, pet),
      );
    }

    final entries = entriesOn(plan, now);
    final open = [
      for (final e in entries)
        if (!e.isAnswered) e,
    ];
    final answered = [
      for (final e in entries)
        if (e.isAnswered) e,
    ];
    final todayRecords = [
      for (final r in planned)
        if (isSameDay(r.scheduledAt, now)) r,
    ];
    final upcoming = [
      for (final r in planned)
        if (!isSameDay(r.scheduledAt, now)) r,
    ];
    final reviewEntries = entriesNeedingReview(plan, now);

    // Today's open items, reminders and appointments together, by time.
    final today = <(DateTime, Widget)>[
      for (final e in open)
        (
          e.due,
          e.item.isMedication
              ? _MedicineRow(pet: pet, entry: e)
              : _RoutineRow(pet: pet, entry: e, onTick: () => _tick(context, ref, e)),
        ),
      for (final r in todayRecords)
        (r.scheduledAt, _PlannedRow(record: r, now: now, onTap: () => openRecordDetail(context, pet, r))),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HealthSectionTitle(
          context.l10n.commonToday,
          detail: l10n.sectionDetailDay(format.shortDay(now)),
          trailing: HealthLink(
            context.l10n.commonAdd,
            key: const Key('schedule-add'),
            icon: Icons.add_rounded,
            onPressed: () => showScheduleAddSheet(context, pet),
          ),
        ),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Text(
              answered.isEmpty ? l10n.nothingDueToday : l10n.allAnsweredToday,
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
          ),
        for (final (_, row) in today) ...[row, const SizedBox(height: 8)],
        if (answered.isNotEmpty) _DoneToday(pet: pet, entries: answered),
        const SizedBox(height: 8),
        HealthSectionTitle(l10n.upcoming, count: upcoming.isEmpty ? null : upcoming.length),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Text(l10n.noUpcoming, style: AppText.body.copyWith(color: AppColors.brown)),
          ),
        for (final record in upcoming) ...[
          _PlannedRow(record: record, now: now, onTap: () => openRecordDetail(context, pet, record)),
          const SizedBox(height: 8),
        ],
        if (reviewEntries.isNotEmpty || reviewRecords.isNotEmpty) ...[
          const SizedBox(height: 8),
          HealthSectionTitle(l10n.needsReview, count: reviewEntries.length + reviewRecords.length),
          for (final entry in reviewEntries) ...[_ReviewEntryRow(pet: pet, entry: entry), const SizedBox(height: 8)],
          for (final record in reviewRecords) ...[
            _ReviewRecordRow(pet: pet, record: record),
            const SizedBox(height: 8),
          ],
          FinePrint(l10n.needsReviewNote(needsReviewDays), center: false),
        ],
        if (!plan.isEmpty) ...[
          const SizedBox(height: 16),
          HealthSectionTitle(l10n.medicinesAndRoutines),
          for (final medication in plan.medications) ...[
            _MedicineCard(pet: pet, medication: medication, plan: plan, now: now),
            const SizedBox(height: 8),
          ],
          for (final item in _routines(plan)) ...[
            _RoutineCard(
              item: item,
              kindLabel: l10n.routineKind(settings, item.kind),
              kindLabelInEnglish: settings.routineLabel(item.kind),
              onTap: () => openRoutineForm(context, pet, item: item),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  static List<CarePlanItem> _routines(CarePlan plan) => [
    for (final item in plan.items)
      if (!item.isMedication) item,
  ]..sort((a, b) => minutesOf(a.time).compareTo(minutesOf(b.time)));

  Future<void> _tick(BuildContext context, WidgetRef ref, ScheduleEntry entry) async {
    try {
      await ref
          .read(carePlanProvider(pet.id).notifier)
          .record(item: entry.item, dueOn: entry.due, status: CareLogStatus.done);
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }
}

/// Whether a routine's title already says its kind (in the language of the
/// screen, or in English for one that was created in English): the kind is
/// then not said twice.
bool _namedAfterKind(String title, String kindLabel, String kindLabelInEnglish) =>
    title.trim() == kindLabel || title.trim() == kindLabelInEnglish;

/// A routine due today: ticked with one tap.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.pet, required this.entry, required this.onTick});

  final Pet pet;
  final ScheduleEntry entry;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final l10n = context.healthL10n;
    final settings = SpeciesSettings.of(pet.species);
    final kindLabel = l10n.routineKind(settings, item.kind);
    return HealthCard(
      key: ValueKey('today-${item.id}'),
      onTap: () => openRoutineForm(context, pet, item: item),
      padding: const EdgeInsetsDirectional.only(start: 4, end: 14, top: 6, bottom: 6),
      child: Row(
        children: [
          Semantics(
            label: l10n.markNamedAsDone(item.title),
            child: Checkbox(
              key: ValueKey('tick-${item.id}'),
              value: false,
              onChanged: (_) => onTick(),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(item.title, style: AppText.cardTitle),
                // A routine named after its kind does not say it twice.
                if (!_namedAfterKind(item.title, kindLabel, settings.routineLabel(item.kind)))
                  Text(kindLabel, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(HealthFormat.of(context).timeOfDay(item.time), style: AppText.cardTitle),
        ],
      ),
    );
  }
}

/// A medicine reminder due today: opens "Record dose".
class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.pet, required this.entry});

  final Pet pet;
  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final medication = entry.medication;
    final dose = medication?.dose.trim() ?? '';
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    return HealthCard(
      key: ValueKey('today-${item.id}'),
      onTap: medication == null ? null : () => openMedicineForm(context, pet, medication: medication),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 10, bottom: 10),
      child: Row(
        children: [
          const IconDisc(Icons.medication_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(item.title, style: AppText.cardTitle),
                Text(
                  format.dots([dose, l10n.dueAt(format.timeOfDay(item.time))]),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ValueKey('record-${item.id}'),
            onPressed: () => showRecordDoseSheet(context, pet, entry: entry),
            style: FilledButton.styleFrom(
              minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: AppText.button(14),
            ),
            child: Text(l10n.recordDose),
          ),
        ],
      ),
    );
  }
}

/// What was answered today, folded into one row.
class _DoneToday extends ConsumerStatefulWidget {
  const _DoneToday({required this.pet, required this.entries});

  final Pet pet;
  final List<ScheduleEntry> entries;

  @override
  ConsumerState<_DoneToday> createState() => _DoneTodayState();
}

class _DoneTodayState extends ConsumerState<_DoneToday> {
  bool _open = false;

  /// "Joint tablets given 08:05", "Breakfast 07:30": one answered reminder.
  static String _line(HealthFormat format, ScheduleEntry entry) {
    final l10n = format.l10n;
    final log = entry.log!;
    final title = entry.item.title;
    if (entry.item.isMedication) {
      return switch (log.status) {
        CareLogStatus.done =>
          log.doneAt == null ? l10n.doneLineGiven(title) : l10n.doneLineGivenAt(title, format.time(log.doneAt!)),
        CareLogStatus.skipped => l10n.doneLineNotGiven(title),
        CareLogStatus.unknown => l10n.doneLineNotSure(title),
      };
    }
    return log.status == CareLogStatus.done
        ? l10n.doneLineAt(title, format.timeOfDay(entry.item.time))
        : l10n.doneLineSkipped(title);
  }

  Future<void> _undo(ScheduleEntry entry) async {
    try {
      await ref.read(carePlanProvider(widget.pet.id).notifier).removeLog(entry.log!);
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    return HealthCard(
      key: const Key('done-today'),
      color: AppColors.sage,
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.doneTodayCount(entries.length), style: AppText.cardTitle),
                    if (!_open)
                      Text(
                        format.dots([for (final entry in entries) _line(format, entry)]),
                        style: AppText.secondary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.ink),
            ],
          ),
          if (_open)
            for (final entry in entries)
              Row(
                children: [
                  Expanded(child: Text(_line(format, entry), style: AppText.secondary)),
                  HealthLink(
                    l10n.undo,
                    key: ValueKey('undo-${entry.item.id}'),
                    color: AppColors.ink,
                    onPressed: () => _undo(entry),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// A planned appointment or due date, with a date badge.
class _PlannedRow extends StatelessWidget {
  const _PlannedRow({required this.record, required this.now, required this.onTap});

  final HealthRecord record;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = record.scheduledAt;
    // The day of a follow-up comes from the vet; its time means nothing.
    final followUp = record.followUpOf != null;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final detail = followUp
        ? format.dots([l10n.recordKind(record.kind), l10n.dateGivenByVet])
        : format.dots([l10n.recordKind(record.kind), format.weekdayTime(at), record.clinic]);

    return HealthCard(
      key: ValueKey('planned-${record.id}'),
      onTap: onTap,
      padding: const EdgeInsetsDirectional.only(start: 10, end: 8, top: 10, bottom: 10),
      child: Row(
        children: [
          Semantics(
            label: format.date(at),
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${at.day}', style: AppText.pillValue),
                  Text(format.badgeMonth(at, now), style: AppText.label),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(followUp ? l10n.followUpDue(record.title) : record.title, style: AppText.cardTitle),
                Text(detail, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}

ButtonStyle _smallFilled() => FilledButton.styleFrom(
  minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  textStyle: AppText.button(14),
);

ButtonStyle _smallOutlined() => OutlinedButton.styleFrom(
  minimumSize: const Size(kHealthTapTarget, kHealthTapTarget),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  textStyle: AppText.button(14),
);

/// A medicine reminder of a past day that nobody answered.
class _ReviewEntryRow extends ConsumerWidget {
  const _ReviewEntryRow({required this.pet, required this.entry});

  final Pet pet;
  final ScheduleEntry entry;

  Future<void> _answer(BuildContext context, WidgetRef ref, CareLogStatus status) async {
    try {
      await ref
          .read(carePlanProvider(pet.id).notifier)
          .record(
            item: entry.item,
            dueOn: entry.due,
            status: status,
            // "Given" without more detail: at the time it was due.
            doneAt: status == CareLogStatus.done ? entry.due : null,
          );
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    // Part of the keys below: the same in every language.
    final tag = '${entry.item.id}-${format.date(entry.due)}';
    return HealthCard(
      key: ValueKey('review-$tag'),
      onTap: () => showRecordDoseSheet(context, pet, entry: entry),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconDisc(Icons.medication_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypedText(entry.item.title, style: AppText.cardTitle),
                    Text(
                      format.dots([format.weekdayDate(entry.due), format.time(entry.due), l10n.noAnswerRecorded]),
                      style: AppText.secondary.copyWith(color: AppColors.brown),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: ValueKey('review-given-$tag'),
                style: _smallFilled(),
                onPressed: () => _answer(context, ref, CareLogStatus.done),
                child: Text(l10n.given),
              ),
              OutlinedButton(
                key: ValueKey('review-not-given-$tag'),
                style: _smallOutlined(),
                onPressed: () => _answer(context, ref, CareLogStatus.skipped),
                child: Text(l10n.notGiven),
              ),
              OutlinedButton(
                key: ValueKey('review-not-sure-$tag'),
                style: _smallOutlined(),
                onPressed: () => _answer(context, ref, CareLogStatus.unknown),
                child: Text(l10n.notSure),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An appointment or due date whose day has passed without an answer.
class _ReviewRecordRow extends ConsumerWidget {
  const _ReviewRecordRow({required this.pet, required this.record});

  final Pet pet;
  final HealthRecord record;

  Future<void> _done(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(healthRecordsProvider(pet.id).notifier).setDone(record, record.scheduledAt);
      if (context.mounted) showHealthSnack(context, context.healthL10n.movedToHistory);
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorOf(context, error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = record.scheduledAt;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    return HealthCard(
      key: ValueKey('review-record-${record.id}'),
      onTap: () => openRecordDetail(context, pet, record),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconDisc(recordKindIcon(record.kind)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TypedText(record.title, style: AppText.cardTitle),
                    Text(
                      format.dots([format.weekdayDate(at), format.time(at), l10n.notMarkedAsDone]),
                      style: AppText.secondary.copyWith(color: AppColors.brown),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: ValueKey('review-done-${record.id}'),
                style: _smallFilled(),
                onPressed: () => _done(context, ref),
                child: Text(l10n.itHappened),
              ),
              OutlinedButton(
                key: ValueKey('review-change-${record.id}'),
                style: _smallOutlined(),
                onPressed: () => openRecordForm(context, pet, record: record),
                child: Text(l10n.changeOrDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A medicine in the care plan: its instructions and reminder times. The
/// days of its reminders are said in the owner's week.
class _MedicineCard extends ConsumerWidget {
  const _MedicineCard({required this.pet, required this.medication, required this.plan, required this.now});

  final Pet pet;
  final Medication medication;
  final CarePlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final week = ref.watch(weekSettingsProvider);
    final items = plan.itemsOf(medication.id);
    final asNeeded = items.isEmpty;
    final active = medication.isActiveOn(now);
    final instructions = format.instructions(medication);
    final reminders = asNeeded
        ? l10n.onlyWhenNeeded
        : format.dots([
            format.commas([for (final item in items) format.timeOfDay(item.time)]),
            format.days(items.first.days, week),
          ]);
    final ends = medication.endsOn;
    final starts = medication.startsOn;

    return HealthCard(
      key: ValueKey('medicine-${medication.id}'),
      onTap: () => openMedicineForm(context, pet, medication: medication),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 12, bottom: 12),
      child: Row(
        children: [
          const IconDisc(Icons.medication_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(medication.displayName, style: AppText.cardTitle),
                if (instructions.isNotEmpty)
                  Text(instructions, style: AppText.secondary.copyWith(color: AppColors.brown)),
                Text(reminders, style: AppText.secondary.copyWith(color: AppColors.brown)),
                if (!active)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: HealthTag(
                      ends != null && dateOnly(now).isAfter(ends)
                          ? l10n.medicineEnded(format.date(ends))
                          : starts != null
                          ? l10n.medicineStarts(format.date(starts))
                          : l10n.medicineNotActive,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (asNeeded && active)
            OutlinedButton(
              key: ValueKey('record-as-needed-${medication.id}'),
              style: _smallOutlined(),
              onPressed: () => showRecordDoseSheet(context, pet, medication: medication),
              child: Text(l10n.recordDose),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}

/// A routine in the care plan. Its days are said in the owner's week.
class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({
    required this.item,
    required this.kindLabel,
    required this.kindLabelInEnglish,
    required this.onTap,
  });

  final CarePlanItem item;

  /// What the routine's kind is called for this pet's species.
  final String kindLabel;
  final String kindLabelInEnglish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = HealthFormat.of(context);
    final week = ref.watch(weekSettingsProvider);
    return HealthCard(
      key: ValueKey('routine-${item.id}'),
      onTap: onTap,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 12, bottom: 12),
      child: Row(
        children: [
          IconDisc(careKindIcon(item.kind)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypedText(item.title, style: AppText.cardTitle),
                Text(
                  format.dots([
                    // A routine named after its kind does not say it twice.
                    if (!_namedAfterKind(item.title, kindLabel, kindLabelInEnglish)) kindLabel,
                    format.timeOfDay(item.time),
                    format.days(item.days, week),
                  ]),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                if (!item.active)
                  Padding(padding: const EdgeInsetsDirectional.only(top: 4), child: HealthTag(format.l10n.paused)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}
