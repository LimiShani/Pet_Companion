import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'schedule_form_widgets.dart';

/// Opens the add / edit medicine page over the whole app. Returns the
/// saved medicine, or `null` when the owner went back or deleted it.
Future<Medication?> openMedicineForm(BuildContext context, Pet pet, {Medication? medication}) =>
    pushHealthPage<Medication>(context, MedicineFormScreen(pet: pet, medication: medication));

/// The ways a medicine is given, offered as chips.
const medicineRoutes = ['By mouth', 'On the skin', 'In the eye', 'In the ear', 'Injection', 'Other'];

/// A medicine with the vet's instructions, stored exactly as typed, and
/// its reminder times. Only the name is required; without reminder times
/// it is a medicine given only when needed. When editing, the page also
/// shows the log of recorded doses.
class MedicineFormScreen extends ConsumerStatefulWidget {
  const MedicineFormScreen({super.key, required this.pet, this.medication});

  final Pet pet;

  /// The medicine being edited, or `null` to add one.
  final Medication? medication;

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.medication?.name ?? '');
  late final _strength = TextEditingController(text: widget.medication?.strength ?? '');
  late final _dose = TextEditingController(text: widget.medication?.dose ?? '');
  late final _frequency = TextEditingController(text: widget.medication?.frequency ?? '');
  late final _prescribedBy = TextEditingController(text: widget.medication?.prescribedBy ?? '');
  late String _route = widget.medication?.route ?? '';
  DateTime? _start;
  DateTime? _end;
  var _times = <TimeOfDay>[];
  var _days = CarePlanItem.everyDay;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.medication != null;
  String get _petId => widget.pet.id;
  DateTime get _now => ref.read(healthClockProvider)();

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    if (medication == null) {
      _start = dateOnly(_now);
      return;
    }
    _start = medication.startsOn;
    _end = medication.endsOn;
    final items = ref.read(carePlanProvider(_petId)).value?.itemsOf(medication.id) ?? const <CarePlanItem>[];
    _times = [for (final item in items) item.time];
    if (items.isNotEmpty) _days = items.first.days;
  }

  @override
  void dispose() {
    for (final c in [_name, _strength, _dose, _frequency, _prescribedBy]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = _now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? dateOnly(now),
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5, 12, 31),
      currentDate: now,
      helpText: 'First day of the medicine',
    );
    if (picked != null && mounted) setState(() => _start = dateOnly(picked));
  }

  Future<void> _pickEnd() async {
    final now = _now;
    final first = _start ?? DateTime(now.year - 20);
    final current = _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : dateOnly(now).isBefore(first)
          ? first
          : dateOnly(now),
      firstDate: first,
      lastDate: DateTime(now.year + 10, 12, 31),
      currentDate: now,
      helpText: 'Last day of the medicine',
    );
    if (picked != null && mounted) setState(() => _end = dateOnly(picked));
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isEmpty ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 20, minute: 0),
      helpText: 'Reminder time',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _times = [
        for (final t in _times)
          if (minutesOf(t) != minutesOf(picked)) t,
        picked,
      ]..sort((a, b) => minutesOf(a).compareTo(minutesOf(b)));
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final start = _start;
    final end = _end;
    if (start != null && end != null && end.isBefore(start)) {
      setState(() => _error = 'The last day should not be before the first day.');
      return;
    }
    if (_times.isNotEmpty && _days.isEmpty) {
      setState(() => _error = 'Choose at least one day for the reminders.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final existing = widget.medication;
    try {
      final saved = await ref
          .read(carePlanProvider(_petId).notifier)
          .saveMedication(
            Medication(
              id: existing?.id ?? '',
              petId: _petId,
              name: _name.text.trim(),
              strength: _strength.text.trim(),
              dose: _dose.text.trim(),
              route: _route,
              frequency: _frequency.text.trim(),
              startsOn: start,
              endsOn: end,
              prescribedBy: _prescribedBy.text.trim(),
              instructions: existing?.instructions ?? '',
            ),
            times: _times,
            days: _days,
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final medication = widget.medication!;
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this medicine?',
      message: '"${medication.name}", its reminders and its dose log will be removed. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(carePlanProvider(_petId).notifier).deleteMedication(medication.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medication = widget.medication;
    final routes = [...medicineRoutes, if (_route.isNotEmpty && !medicineRoutes.contains(_route)) _route];
    final logs = medication == null
        ? const <CareLog>[]
        : ([
            for (final log in ref.watch(carePlanProvider(_petId)).value?.logs ?? const <CareLog>[])
              if (log.medicationId == medication.id) log,
          ]..sort((a, b) => (b.doneAt ?? b.loggedAt).compareTo(a.doneAt ?? a.loggedAt)));

    return HealthPage(
      petId: _petId,
      title: _editing ? 'Edit medicine' : 'New medicine',
      actions: [
        if (_editing)
          CoralHeaderAction(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete medicine',
            onPressed: _saving ? null : _delete,
          ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FormLabel("From the vet's instructions"),
            TextFormField(
              key: const Key('medicine-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Enter the name of the medicine.';
                if (v.length > 120) return 'Keep the name under 120 characters.';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-strength'),
              controller: _strength,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Strength (optional)', hintText: '50 mg'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-dose'),
              controller: _dose,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Dose (optional)', hintText: '1 tablet'),
            ),
            const FormLabel('How it is given'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final route in routes)
                  ChoiceChip(
                    key: ValueKey('route-$route'),
                    label: Text(route),
                    selected: route == _route,
                    onSelected: (selected) => setState(() => _route = selected ? route : ''),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('medicine-frequency'),
              controller: _frequency,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'How often (optional)', hintText: 'Twice a day, with food'),
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('medicine-start'),
              icon: Icons.event_rounded,
              label: 'Start',
              value: _start == null ? 'Not set' : formatDate(_start!),
              placeholder: _start == null,
              onTap: _pickStart,
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('medicine-end'),
              icon: Icons.event_busy_rounded,
              label: 'End (optional)',
              value: _end == null ? 'No end' : formatDate(_end!),
              placeholder: _end == null,
              onTap: _pickEnd,
              onClear: _end == null ? null : () => setState(() => _end = null),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-prescribed-by'),
              controller: _prescribedBy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prescribed by (optional)'),
            ),
            const FormLabel('Reminders'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final time in _times)
                  InputChip(
                    key: ValueKey('time-${formatTimeOfDay(time)}'),
                    label: Text(formatTimeOfDay(time)),
                    onDeleted: () => setState(() => _times = [..._times]..remove(time)),
                    deleteButtonTooltipMessage: 'Remove ${formatTimeOfDay(time)}',
                  ),
                ActionChip(
                  key: const Key('medicine-add-time'),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add a time'),
                  onPressed: _addTime,
                ),
              ],
            ),
            if (_times.isNotEmpty) ...[
              const SizedBox(height: 8),
              DaysPicker(days: _days, onChanged: (days) => setState(() => _days = days)),
            ],
            const SizedBox(height: 6),
            FinePrint(
              _times.isEmpty
                  ? 'No reminder times: a medicine given only when needed.'
                  : 'A reminder nobody answers waits under Needs review. It is never counted as missed.',
              center: false,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: 'Save medicine', loading: _saving, onPressed: _save),
            const SizedBox(height: 12),
            const FinePrint('The app stores what you enter. It never suggests a dose.'),
            if (medication != null) ...[
              const SizedBox(height: 12),
              HealthSectionTitle('Dose log', count: logs.isEmpty ? null : logs.length),
              if (logs.isEmpty)
                Text('No dose recorded yet.', style: AppText.secondary.copyWith(color: AppColors.brown))
              else
                for (final log in logs.take(30))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DoseLogRow(log: log),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Given 08:05", "Not given" or "Not sure", for the dose log and the
/// Schedule's "Done today".
String doseStatusLabel(CareLog log) => switch (log.status) {
  CareLogStatus.done => log.doneAt == null ? 'Given' : 'Given ${formatTime(log.doneAt!)}',
  CareLogStatus.skipped => 'Not given',
  CareLogStatus.unknown => 'Not sure',
};

class _DoseLogRow extends StatelessWidget {
  const _DoseLogRow({required this.log});

  final CareLog log;

  @override
  Widget build(BuildContext context) {
    final due = log.dueTime;
    final by = log.loggedByName.trim();
    return HealthCard(
      radius: AppSpacing.fieldRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(switch (log.status) {
            CareLogStatus.done => Icons.check_circle_rounded,
            CareLogStatus.skipped => Icons.cancel_outlined,
            CareLogStatus.unknown => Icons.help_outline_rounded,
          }, color: AppColors.brown),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doseStatusLabel(log), style: AppText.cardTitle),
                Text(
                  [
                    formatDate(log.dueOn),
                    if (due != null) 'reminder ${formatTimeOfDay(due)}' else 'when needed',
                    if (by.isNotEmpty) 'logged by $by',
                  ].join(' · '),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                if (log.note.isNotEmpty) Text(log.note, style: AppText.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
