import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/pet_records/data/health_models.dart';
import '../../../presentation/health_format.dart';
import '../../../services/pet_records/state/health_providers.dart';
import '../../../services/pet_records/state/schedule_logic.dart';
import '../../../presentation/health_widgets.dart';

/// Opens the "Record dose" sheet: for one reminder ([entry]), or for a
/// medicine given only when needed ([medication], no reminder).
///
/// It records what actually happened (given now, given at another time, not
/// given, not sure), who logged it and when. It shows the vet's
/// instructions as typed and never suggests a dose or a repeat.
Future<void> showRecordDoseSheet(
  BuildContext context,
  Pet pet, {
  ScheduleEntry? entry,
  Medication? medication,
}) {
  assert(
    entry != null || medication != null,
    'A dose belongs to a reminder or to a medicine.',
  );
  return showHealthSheet<void>(
    context,
    RecordDoseSheet(
      pet: pet,
      entry: entry,
      medication: entry?.medication ?? medication,
    ),
  );
}

class RecordDoseSheet extends ConsumerStatefulWidget {
  const RecordDoseSheet({
    super.key,
    required this.pet,
    this.entry,
    this.medication,
  });

  final Pet pet;
  final ScheduleEntry? entry;
  final Medication? medication;

  @override
  ConsumerState<RecordDoseSheet> createState() => _RecordDoseSheetState();
}

class _RecordDoseSheetState extends ConsumerState<RecordDoseSheet> {
  final _note = TextEditingController();
  bool _busy = false;

  /// What is wrong: a message of the sheet, or what saving threw (worded
  /// when it is shown).
  Object? _error;

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
      final l10n = context.healthL10n;
      showHealthSnack(context, switch (status) {
        CareLogStatus.done => l10n.doseRecordedGiven,
        CareLogStatus.skipped => l10n.doseRecordedNotGiven,
        CareLogStatus.unknown => l10n.doseRecordedNotSure,
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _givenAtAnotherTime() async {
    final now = _now;
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.entry?.item.time ?? TimeOfDay.fromDateTime(now),
      helpText: context.healthL10n.whenWasItGiven,
    );
    if (picked == null || !mounted) return;
    final at = atTime(_day, picked);
    if (at.isAfter(now)) {
      setState(() => _error = context.healthL10n.validTimeAhead);
      return;
    }
    await _record(CareLogStatus.done, doneAt: at);
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'health.schedule.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final entry = widget.entry;
    final medication = widget.medication;
    final now = ref.watch(healthClockProvider)();
    final name = ref.watch(
      authControllerProvider.select(
        (auth) => auth.value?.displayName.trim() ?? '',
      ),
    );
    final notes = medication?.instructions.trim() ?? '';
    final by = medication?.prescribedBy.trim() ?? '';
    final wide = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(kHealthTapTarget),
    );
    final wideOutlined = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(kHealthTapTarget),
    );
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final error = _error;
    final String subtitle;
    if (entry == null) {
      subtitle = l10n.doseGivenWhenNeeded(widget.pet.name);
    } else {
      final time = format.time(entry.due);
      subtitle = switch (daysBetween(now, entry.due)) {
        0 => l10n.reminderForToday(time),
        -1 => l10n.reminderForYesterday(time),
        _ => l10n.reminderForDay(format.weekdayDate(entry.due), time),
      };
    }
    final instructions = medication == null
        ? ''
        : format.instructions(medication);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          medication?.displayName ?? entry?.item.title ?? l10n.medicine,
          subtitle: subtitle,
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
                if (instructions.isNotEmpty)
                  Text(
                    l10n.vetsInstructions(instructions),
                    style: AppText.body,
                  ),
                if (notes.isNotEmpty) TypedText(notes, style: AppText.body),
                if (by.isNotEmpty)
                  TypedText(
                    by,
                    style: AppText.secondary.copyWith(color: AppColors.brown),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('dose-given-now'),
          onPressed: _busy ? null : () => _record(CareLogStatus.done),
          style: wide,
          icon: const AppIcon(Icons.check_rounded),
          label: Text(l10n.givenNowAt(format.time(now))),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('dose-given-other'),
          onPressed: _busy ? null : _givenAtAnotherTime,
          style: wideOutlined,
          icon: const AppIcon(Icons.schedule_rounded),
          label: Text(l10n.givenAtAnotherTime),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('dose-not-given'),
          onPressed: _busy ? null : () => _record(CareLogStatus.skipped),
          style: wideOutlined,
          icon: const AppIcon(Icons.close_rounded),
          label: Text(l10n.notGiven),
        ),
        Center(
          child: HealthLink(
            l10n.notSure,
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
          decoration: InputDecoration(
            labelText: l10n.noteOptional,
            hintText: l10n.doseNoteHint,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error is String ? error : format.error(error),
            style: AppText.body.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FinePrint(
          name.isEmpty ? l10n.doseFinePrintYou : l10n.doseFinePrintNamed(name),
        ),
      ],
    );
  }
}
