import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';

/// Opens the "Record dose" sheet: for one reminder ([entry]), or for a
/// medicine given only when needed ([medication], no reminder).
///
/// It records what actually happened (given now, given at another time, not
/// given, not sure), who logged it and when. It shows the vet's
/// instructions as typed and never suggests a dose or a repeat.
Future<void> showRecordDoseSheet(BuildContext context, Pet pet, {ScheduleEntry? entry, Medication? medication}) {
  assert(entry != null || medication != null, 'A dose belongs to a reminder or to a medicine.');
  return showHealthSheet<void>(
    context,
    RecordDoseSheet(pet: pet, entry: entry, medication: entry?.medication ?? medication),
  );
}

class RecordDoseSheet extends ConsumerStatefulWidget {
  const RecordDoseSheet({super.key, required this.pet, this.entry, this.medication});

  final Pet pet;
  final ScheduleEntry? entry;
  final Medication? medication;

  @override
  ConsumerState<RecordDoseSheet> createState() => _RecordDoseSheetState();
}

class _RecordDoseSheetState extends ConsumerState<RecordDoseSheet> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _now => ref.read(healthClockProvider)();

  /// The day the dose belongs to: the reminder's day, or today.
  DateTime get _day => dateOnly(widget.entry?.due ?? _now);

  Future<void> _record(CareLogStatus status, {DateTime? doneAt}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(carePlanProvider(widget.pet.id).notifier)
          .record(
            item: widget.entry?.item,
            medication: widget.medication,
            dueOn: _day,
            status: status,
            doneAt: doneAt,
            note: _note.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showHealthSnack(context, switch (status) {
        CareLogStatus.done => 'Dose recorded as given.',
        CareLogStatus.skipped => 'Recorded as not given.',
        CareLogStatus.unknown => 'Recorded as not sure.',
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  Future<void> _givenAtAnotherTime() async {
    final now = _now;
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.entry?.item.time ?? TimeOfDay.fromDateTime(now),
      helpText: 'When was it given?',
    );
    if (picked == null || !mounted) return;
    final at = atTime(_day, picked);
    if (at.isAfter(now)) {
      setState(() => _error = 'That time is still ahead. Record the dose once it is given.');
      return;
    }
    await _record(CareLogStatus.done, doneAt: at);
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final medication = widget.medication;
    final now = ref.watch(healthClockProvider)();
    final name = ref.watch(authControllerProvider.select((auth) => auth.value?.displayName.trim() ?? ''));
    final instructions = medication?.instructionLine ?? '';
    final notes = medication?.instructions.trim() ?? '';
    final by = medication?.prescribedBy.trim() ?? '';
    final wide = FilledButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget));
    final wideOutlined = OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(kHealthTapTarget));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          medication?.displayName ?? entry?.item.title ?? 'Medicine',
          subtitle: entry == null
              ? 'Given when needed · ${widget.pet.name}'
              : 'Reminder for ${formatRelativeDay(entry.due, now).toLowerCase()} · ${formatTime(entry.due)}',
        ),
        if (instructions.isNotEmpty || notes.isNotEmpty || by.isNotEmpty) ...[
          const SizedBox(height: 12),
          HealthCard(
            key: const Key('dose-instructions'),
            color: AppColors.yellow,
            radius: AppSpacing.fieldRadius,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (instructions.isNotEmpty) Text("Vet's instructions: $instructions.", style: AppText.body),
                if (notes.isNotEmpty) Text(notes, style: AppText.body),
                if (by.isNotEmpty) Text(by, style: AppText.secondary.copyWith(color: AppColors.brown)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('dose-given-now'),
          onPressed: _busy ? null : () => _record(CareLogStatus.done),
          style: wide,
          icon: const Icon(Icons.check_rounded),
          label: Text('Given now · ${formatTime(now)}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('dose-given-other'),
          onPressed: _busy ? null : _givenAtAnotherTime,
          style: wideOutlined,
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('Given at another time'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('dose-not-given'),
          onPressed: _busy ? null : () => _record(CareLogStatus.skipped),
          style: wideOutlined,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Not given'),
        ),
        Center(
          child: HealthLink(
            'Not sure',
            key: const Key('dose-not-sure'),
            onPressed: _busy ? null : () => _record(CareLogStatus.unknown),
          ),
        ),
        TextField(
          key: const Key('dose-note'),
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'For example: hidden in cheese'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FinePrint(
          'Saved as logged by ${name.isEmpty ? 'you' : name}, with the time. '
          'If you are unsure about a dose, ask your vet.',
        ),
      ],
    );
  }
}
