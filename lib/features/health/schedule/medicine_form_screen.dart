import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/unsaved_changes_guard.dart';
import '../data/health_models.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'schedule_form_widgets.dart';

/// Opens the add / edit medicine page over the whole app. Returns the
/// saved medicine, or `null` when the owner went back or deleted it.
Future<Medication?> openMedicineForm(BuildContext context, Pet pet, {Medication? medication}) =>
    pushHealthPage<Medication>(context, MedicineFormScreen(pet: pet, medication: medication));

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

  /// The fields as the page opened, to tell whether anything changed.
  late final List<Object?> _initial;

  /// What is wrong: a message of the form, or what saving threw (worded
  /// when it is shown).
  Object? _error;

  /// The id of the medicine this form has stored: the edited medicine's,
  /// or a new medicine's once it was saved and only its reminders failed,
  /// so that saving again updates it instead of storing it twice.
  late String _storedId = widget.medication?.id ?? '';

  bool get _editing => widget.medication != null;
  String get _petId => widget.pet.id;
  DateTime get _now => ref.read(healthClockProvider)();

  @override
  void initState() {
    super.initState();
    final medication = widget.medication;
    if (medication == null) {
      _start = dateOnly(_now);
    } else {
      _start = medication.startsOn;
      _end = medication.endsOn;
      final items = ref.read(carePlanProvider(_petId)).value?.itemsOf(medication.id) ?? const <CarePlanItem>[];
      _times = [for (final item in items) item.time];
      if (items.isNotEmpty) _days = items.first.days;
    }
    _initial = _fields();
  }

  List<Object?> _fields() => [
    for (final c in [_name, _strength, _dose, _frequency, _prescribedBy]) c.text,
    _route,
    _start,
    _end,
    _times.map(minutesOf).join(','),
    ([..._days]..sort()).join(','),
  ];

  bool get _dirty => !_saving && !listEquals(_fields(), _initial);

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
      helpText: context.healthL10n.firstDayOfMedicine,
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
      helpText: context.healthL10n.lastDayOfMedicine,
    );
    if (picked != null && mounted) setState(() => _end = dateOnly(picked));
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times.isEmpty ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 20, minute: 0),
      helpText: context.healthL10n.reminderTime,
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
      setState(() => _error = context.healthL10n.validLastBeforeFirst);
      return;
    }
    if (_times.isNotEmpty && _days.isEmpty) {
      setState(() => _error = context.healthL10n.validReminderDays);
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
              id: _storedId,
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
      if (error is RemindersNotSaved) _storedId = error.saved.id;
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _delete() async {
    final medication = widget.medication!;
    final confirmed = await confirmDelete(
      context,
      title: context.healthL10n.deleteMedicineTitle,
      message: context.healthL10n.deleteMedicineMessage(medication.name),
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
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medication = widget.medication;
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final error = _error;
    final routes = [...medicineRoutes, if (_route.isNotEmpty && !medicineRoutes.contains(_route)) _route];
    final logs = medication == null
        ? const <CareLog>[]
        : ([
            for (final log in ref.watch(carePlanProvider(_petId)).value?.logs ?? const <CareLog>[])
              if (log.medicationId == medication.id) log,
          ]..sort((a, b) => (b.doneAt ?? b.loggedAt).compareTo(a.doneAt ?? a.loggedAt)));

    final page = HealthPage(
      petId: _petId,
      title: _editing ? l10n.editMedicine : l10n.newMedicine,
      actions: [
        if (_editing)
          CoralHeaderAction(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.deleteMedicine,
            onPressed: _saving ? null : _delete,
          ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel(l10n.fromVetInstructions),
            TextFormField(
              key: const Key('medicine-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.fieldName),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return l10n.validMedicineName;
                if (v.length > 120) return l10n.validNameTooLong(120);
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-strength'),
              controller: _strength,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.strengthOptional, hintText: l10n.strengthHint),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-dose'),
              controller: _dose,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.doseOptional, hintText: l10n.doseHint),
            ),
            FormLabel(l10n.howItIsGiven),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final route in routes)
                  ChoiceChip(
                    key: ValueKey('route-$route'),
                    label: Text(l10n.medicineRoute(route)),
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
              decoration: InputDecoration(labelText: l10n.howOftenOptional, hintText: l10n.howOftenHint),
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('medicine-start'),
              icon: Icons.event_rounded,
              label: l10n.fieldStart,
              value: _start == null ? l10n.notSet : format.date(_start!),
              placeholder: _start == null,
              onTap: _pickStart,
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('medicine-end'),
              icon: Icons.event_busy_rounded,
              label: l10n.endOptional,
              value: _end == null ? l10n.noEnd : format.date(_end!),
              placeholder: _end == null,
              onTap: _pickEnd,
              onClear: _end == null ? null : () => setState(() => _end = null),
            ),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('medicine-prescribed-by'),
              controller: _prescribedBy,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.prescribedByOptional),
            ),
            FormLabel(l10n.reminders),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final time in _times)
                  InputChip(
                    key: ValueKey('time-${format.timeOfDay(time)}'),
                    label: Text(format.timeOfDay(time)),
                    onDeleted: () => setState(() => _times = [..._times]..remove(time)),
                    deleteButtonTooltipMessage: l10n.removeNamed(format.timeOfDay(time)),
                  ),
                ActionChip(
                  key: const Key('medicine-add-time'),
                  avatar: const AppIcon(Icons.add_rounded, size: 18),
                  label: Text(l10n.addATime),
                  onPressed: _addTime,
                ),
              ],
            ),
            if (_times.isNotEmpty) ...[
              const SizedBox(height: 8),
              DaysPicker(days: _days, onChanged: (days) => setState(() => _days = days)),
            ],
            const SizedBox(height: 6),
            FinePrint(_times.isEmpty ? l10n.medicineNoTimesNote : l10n.medicineReminderNote, center: false),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error is String ? error : format.error(error),
                style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: l10n.saveMedicine, loading: _saving, onPressed: _save),
            const SizedBox(height: 12),
            FinePrint(l10n.medicineFinePrint),
            if (medication != null) ...[
              const SizedBox(height: 12),
              HealthSectionTitle(l10n.doseLog, count: logs.isEmpty ? null : logs.length),
              if (logs.isEmpty)
                Text(l10n.noDoseRecordedYet, style: AppText.secondary.copyWith(color: AppColors.brown))
              else
                for (final log in logs.take(30))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 8),
                    child: _DoseLogRow(log: log),
                  ),
            ],
          ],
        ),
      ),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _strength, _dose, _frequency, _prescribedBy]),
      builder: (context, child) => UnsavedChangesGuard(dirty: _dirty, child: child!),
      child: page,
    );
  }
}

class _DoseLogRow extends StatelessWidget {
  const _DoseLogRow({required this.log});

  final CareLog log;

  @override
  Widget build(BuildContext context) {
    final due = log.dueTime;
    final by = log.loggedByName.trim();
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    return HealthCard(
      radius: AppSpacing.fieldRadius,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The question mark reads the same in every language: it is never
          // mirrored (see HealthIcon).
          HealthIcon(switch (log.status) {
            CareLogStatus.done => Icons.check_circle_rounded,
            CareLogStatus.skipped => Icons.cancel_outlined,
            CareLogStatus.unknown => Icons.help_outline_rounded,
          }, color: AppColors.brown),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(format.doseStatus(log), style: AppText.cardTitle),
                Text(
                  format.dots([
                    format.date(log.dueOn),
                    if (due != null) l10n.doseLogReminder(format.timeOfDay(due)) else l10n.doseLogWhenNeeded,
                    // No name was stored (or, by an older version, the word
                    // "You"): the owner's own entry.
                    by.isEmpty || by == 'You' ? l10n.doseLoggedByYou : l10n.doseLoggedBy(by),
                  ]),
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
                if (log.note.isNotEmpty) TypedText(log.note, style: AppText.secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
