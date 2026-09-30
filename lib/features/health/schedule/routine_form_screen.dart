import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../health_format.dart';
import '../health_strings.dart';
import '../state/health_providers.dart';
import '../widgets/health_widgets.dart';
import 'schedule_form_widgets.dart';

/// Opens the add / edit routine page over the whole app. Returns the saved
/// routine, or `null` when the owner went back or deleted it.
Future<CarePlanItem?> openRoutineForm(BuildContext context, Pet pet, {CarePlanItem? item}) =>
    pushHealthPage<CarePlanItem>(context, RoutineFormScreen(pet: pet, item: item));

/// A daily routine (feeding, walk, grooming, cleaning...): a title, a time
/// and the weekdays. It is ticked with one tap in the Schedule and never
/// goes to "Needs review".
class RoutineFormScreen extends ConsumerStatefulWidget {
  const RoutineFormScreen({super.key, required this.pet, this.item});

  final Pet pet;

  /// The routine being edited, or `null` to add one.
  final CarePlanItem? item;

  @override
  ConsumerState<RoutineFormScreen> createState() => _RoutineFormScreenState();
}

class _RoutineFormScreenState extends ConsumerState<RoutineFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late CareKind _kind;
  late TimeOfDay _time;
  late Set<int> _days;
  late bool _active = widget.item?.active ?? true;

  // Once the owner chose a time or days, picking another kind leaves them.
  late bool _timeChosen = widget.item != null;
  late bool _daysChosen = widget.item != null;
  bool _saving = false;

  /// What is wrong: a message of the form, or what saving threw (worded
  /// when it is shown).
  Object? _error;

  bool get _editing => widget.item != null;
  String get _petId => widget.pet.id;
  SpeciesSettings get _settings => SpeciesSettings.of(widget.pet.species);

  /// The usual time and days a kind starts from.
  static (TimeOfDay, Set<int>) _usual(CareKind kind) => switch (kind) {
    CareKind.litterCleaning => (const TimeOfDay(hour: 20, minute: 0), CarePlanItem.everyDay),
    CareKind.litterChange || CareKind.cageCleaning => (const TimeOfDay(hour: 10, minute: 0), const {6}),
    _ => (const TimeOfDay(hour: 8, minute: 0), CarePlanItem.everyDay),
  };

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _kind = item?.kind ?? _settings.routineKinds.first;
    final (time, days) = _usual(_kind);
    _time = item?.time ?? time;
    _days = item?.days ?? days;
  }

  void _chooseKind(CareKind kind) {
    final l10n = context.healthL10n;
    setState(() {
      // The title follows the kind until the owner types one. It is filled
      // in the language of the screen, and stays as it was saved.
      final typed = _title.text.trim();
      if (typed.isEmpty || typed == l10n.routineKind(_settings, _kind)) _title.text = l10n.routineKind(_settings, kind);
      final (time, days) = _usual(kind);
      if (!_timeChosen) _time = time;
      if (!_daysChosen) _days = days;
      _kind = kind;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: context.healthL10n.timeOfRoutine,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _timeChosen = true;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_days.isEmpty) {
      setState(() => _error = context.healthL10n.chooseAtLeastOneDay);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final existing = widget.item;
    try {
      final saved = await ref
          .read(carePlanProvider(_petId).notifier)
          .saveRoutine(
            CarePlanItem(
              id: existing?.id ?? '',
              petId: _petId,
              kind: _kind,
              title: _title.text.trim(),
              time: _time,
              days: _days,
              startsOn: existing?.startsOn,
              endsOn: existing?.endsOn,
              active: _active,
            ),
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error;
        });
      }
    }
  }

  Future<void> _delete() async {
    final item = widget.item!;
    final confirmed = await confirmDelete(
      context,
      title: context.healthL10n.deleteRoutineTitle,
      message: context.healthL10n.deleteRoutineMessage(item.title),
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(carePlanProvider(_petId).notifier).deleteRoutine(item.id);
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
    final offered = _settings.routineKinds;
    final kinds = [...offered, if (!offered.contains(_kind)) _kind];
    final l10n = context.healthL10n;
    final format = HealthFormat.of(context);
    final error = _error;

    return HealthPage(
      petId: _petId,
      title: _editing ? l10n.editRoutine : l10n.newRoutine,
      actions: [
        if (_editing)
          CoralHeaderAction(
            icon: Icons.delete_outline_rounded,
            tooltip: l10n.deleteRoutine,
            onPressed: _saving ? null : _delete,
          ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormLabel(l10n.whatKindOfRoutine),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in kinds)
                  ChoiceChip(
                    key: ValueKey('routine-kind-${kind.name}'),
                    avatar: HealthIcon(careKindIcon(kind), size: 18, color: AppColors.ink),
                    label: Text(l10n.routineKind(_settings, kind)),
                    selected: kind == _kind,
                    showCheckmark: false,
                    onSelected: (_) => _chooseKind(kind),
                  ),
              ],
            ),
            FormLabel(l10n.details),
            TextFormField(
              key: const Key('routine-title'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.fieldTitle, hintText: l10n.routineTitleHint),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return l10n.validRoutineTitle;
                if (v.length > 80) return l10n.validTitleTooLong(80);
                return null;
              },
            ),
            const SizedBox(height: 10),
            PickerTile(
              key: const Key('routine-time'),
              icon: Icons.schedule_rounded,
              label: l10n.fieldTime,
              value: format.timeOfDay(_time),
              onTap: _pickTime,
            ),
            FormLabel(l10n.fieldDays),
            DaysPicker(
              days: _days,
              onChanged: (days) => setState(() {
                _days = days;
                _daysChosen = true;
              }),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('routine-active'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.showInSchedule, style: AppText.body.copyWith(color: AppColors.ink)),
              subtitle: Text(
                _active ? l10n.routineOn : l10n.routinePausedNote,
                style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error is String ? error : format.error(error),
                style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(label: l10n.saveRoutine, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
