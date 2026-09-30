import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
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
    Widget option(int value, String key, IconData icon, String title, String detail) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
        const SheetTitle('Add to the schedule'),
        const SizedBox(height: 12),
        option(
          0,
          'appointment',
          Icons.event_rounded,
          'Appointment or due date',
          'A vet visit, a vaccination, a treatment',
        ),
        option(1, 'medicine', Icons.medication_rounded, 'Medicine', "The vet's instructions and the reminder times"),
        option(2, 'routine', Icons.restaurant_rounded, 'Routine', 'Feeding, walks, grooming, cleaning'),
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

    if (plan.isEmpty && planned.isEmpty && reviewRecords.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_rounded,
        title: 'Nothing scheduled yet',
        message: "Appointments, medicine reminders and daily routines for ${pet.name} will show here.",
        actionLabel: 'Add to the schedule',
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
          'Today',
          detail: '· ${formatShortDay(now)}',
          trailing: HealthLink(
            'Add',
            key: const Key('schedule-add'),
            icon: Icons.add_rounded,
            onPressed: () => showScheduleAddSheet(context, pet),
          ),
        ),
        if (today.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              answered.isEmpty ? 'Nothing is due today.' : 'Everything for today is answered.',
              style: AppText.body.copyWith(color: AppColors.brown),
            ),
          ),
        for (final (_, row) in today) ...[row, const SizedBox(height: 8)],
        if (answered.isNotEmpty) _DoneToday(pet: pet, entries: answered),
        const SizedBox(height: 8),
        HealthSectionTitle('Upcoming', count: upcoming.isEmpty ? null : upcoming.length),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('No appointments or due dates ahead.', style: AppText.body.copyWith(color: AppColors.brown)),
          ),
        for (final record in upcoming) ...[
          _PlannedRow(record: record, now: now, onTap: () => openRecordDetail(context, pet, record)),
          const SizedBox(height: 8),
        ],
        if (reviewEntries.isNotEmpty || reviewRecords.isNotEmpty) ...[
          const SizedBox(height: 8),
          HealthSectionTitle('Needs review', count: reviewEntries.length + reviewRecords.length),
          for (final entry in reviewEntries) ...[_ReviewEntryRow(pet: pet, entry: entry), const SizedBox(height: 8)],
          for (final record in reviewRecords) ...[
            _ReviewRecordRow(pet: pet, record: record),
            const SizedBox(height: 8),
          ],
          const FinePrint(
            'No answer was recorded for these. Nothing is counted as missed; a medicine reminder leaves this list '
            'after $needsReviewDays days.',
            center: false,
          ),
        ],
        if (!plan.isEmpty) ...[
          const SizedBox(height: 16),
          const HealthSectionTitle('Medicines and routines'),
          for (final medication in plan.medications) ...[
            _MedicineCard(pet: pet, medication: medication, plan: plan, now: now),
            const SizedBox(height: 8),
          ],
          for (final item in _routines(plan)) ...[
            _RoutineCard(
              item: item,
              kindLabel: SpeciesSettings.of(pet.species).routineLabel(item.kind),
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
      if (context.mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }
}

/// A routine due today: ticked with one tap.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.pet, required this.entry, required this.onTick});

  final Pet pet;
  final ScheduleEntry entry;
  final VoidCallback onTick;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final kindLabel = SpeciesSettings.of(pet.species).routineLabel(item.kind);
    return HealthCard(
      key: ValueKey('today-${item.id}'),
      onTap: () => openRoutineForm(context, pet, item: item),
      padding: const EdgeInsetsDirectional.only(start: 4, end: 14, top: 6, bottom: 6),
      child: Row(
        children: [
          Semantics(
            label: 'Mark ${item.title} as done',
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
                Text(item.title, style: AppText.cardTitle),
                // A routine named after its kind does not say it twice.
                if (item.title.trim() != kindLabel)
                  Text(kindLabel, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(formatTimeOfDay(item.time), style: AppText.cardTitle),
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
                Text(item.title, style: AppText.cardTitle),
                Text(
                  [if (dose.isNotEmpty) dose, 'due ${formatTimeOfDay(item.time)}'].join(' · '),
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
            child: const Text('Record'),
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

  static String _line(ScheduleEntry entry) {
    final log = entry.log!;
    if (entry.item.isMedication) return '${entry.item.title} ${doseStatusLabel(log).toLowerCase()}';
    return log.status == CareLogStatus.done
        ? '${entry.item.title} ${formatTimeOfDay(entry.item.time)}'
        : '${entry.item.title} skipped';
  }

  Future<void> _undo(ScheduleEntry entry) async {
    try {
      await ref.read(carePlanProvider(widget.pet.id).notifier).removeLog(entry.log!);
    } catch (error) {
      if (mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
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
                    Text('Done today · ${entries.length}', style: AppText.cardTitle),
                    if (!_open)
                      Text(
                        entries.map(_line).join(' · '),
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
                  Expanded(child: Text(_line(entry), style: AppText.secondary)),
                  HealthLink(
                    'Undo',
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
    final detail = followUp
        ? '${record.kind.label} · date given by the vet'
        : [
            record.kind.label,
            '${dayName(at.weekday)} ${formatTime(at)}',
            if (record.clinic.isNotEmpty) record.clinic,
          ].join(' · ');

    return HealthCard(
      key: ValueKey('planned-${record.id}'),
      onTap: onTap,
      padding: const EdgeInsetsDirectional.only(start: 10, end: 8, top: 10, bottom: 10),
      child: Row(
        children: [
          Semantics(
            label: formatDate(at),
            excludeSemantics: true,
            child: Container(
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(16)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${at.day}', style: AppText.pillValue),
                  Text(formatBadgeMonth(at, now), style: AppText.label),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(followUp ? '${record.title} due' : record.title, style: AppText.cardTitle),
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
      if (context.mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = '${entry.item.id}-${formatDate(entry.due)}';
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
                    Text(entry.item.title, style: AppText.cardTitle),
                    Text(
                      '${formatWeekdayDate(entry.due)} · ${formatTime(entry.due)} · no answer recorded',
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
                child: const Text('Given'),
              ),
              OutlinedButton(
                key: ValueKey('review-not-given-$tag'),
                style: _smallOutlined(),
                onPressed: () => _answer(context, ref, CareLogStatus.skipped),
                child: const Text('Not given'),
              ),
              OutlinedButton(
                key: ValueKey('review-not-sure-$tag'),
                style: _smallOutlined(),
                onPressed: () => _answer(context, ref, CareLogStatus.unknown),
                child: const Text('Not sure'),
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
      if (context.mounted) showHealthSnack(context, 'Moved to the History.');
    } catch (error) {
      if (context.mounted) showHealthSnack(context, healthErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = record.scheduledAt;
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
                    Text(record.title, style: AppText.cardTitle),
                    Text(
                      '${formatWeekdayDate(at)} · ${formatTime(at)} · not marked as done',
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
                child: const Text('It happened'),
              ),
              OutlinedButton(
                key: ValueKey('review-change-${record.id}'),
                style: _smallOutlined(),
                onPressed: () => openRecordForm(context, pet, record: record),
                child: const Text('Change or delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A medicine in the care plan: its instructions and reminder times.
class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.pet, required this.medication, required this.plan, required this.now});

  final Pet pet;
  final Medication medication;
  final CarePlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final items = plan.itemsOf(medication.id);
    final asNeeded = items.isEmpty;
    final active = medication.isActiveOn(now);
    final reminders = asNeeded
        ? 'Only when needed'
        : '${items.map((i) => formatTimeOfDay(i.time)).join(', ')} · ${formatDays(items.first.days)}';
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
                Text(medication.displayName, style: AppText.cardTitle),
                if (medication.instructionLine.isNotEmpty)
                  Text(medication.instructionLine, style: AppText.secondary.copyWith(color: AppColors.brown)),
                Text(reminders, style: AppText.secondary.copyWith(color: AppColors.brown)),
                if (!active)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: HealthTag(
                      ends != null && dateOnly(now).isAfter(ends)
                          ? 'Ended ${formatDate(ends)}'
                          : starts != null
                          ? 'Starts ${formatDate(starts)}'
                          : 'Not active',
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
              child: const Text('Record'),
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}

/// A routine in the care plan.
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.item, required this.kindLabel, required this.onTap});

  final CarePlanItem item;

  /// What the routine's kind is called for this pet's species.
  final String kindLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Text(item.title, style: AppText.cardTitle),
                Text(
                  [
                    // A routine named after its kind does not say it twice.
                    if (item.title.trim() != kindLabel) kindLabel,
                    formatTimeOfDay(item.time),
                    formatDays(item.days),
                  ].join(' · '),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                if (!item.active) const Padding(padding: EdgeInsets.only(top: 4), child: HealthTag('Paused')),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
        ],
      ),
    );
  }
}
