import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/primary_button.dart';
import '../data/health_models.dart';
import '../data/species_settings.dart';
import '../emergency/emergency_sheet.dart';
import '../health_format.dart';
import '../state/health_providers.dart';
import '../state/schedule_logic.dart';
import '../widgets/health_widgets.dart';

/// Opens the Quick log: pick a category suited to the species, pick a
/// simple answer (or type the weight), save. Notes are optional.
///
/// [category] preselects a category key (the weight, from "Log weight").
/// With [observation] the sheet edits or deletes an existing entry.
Future<void> showQuickLog(BuildContext context, Pet pet, {String? category, Observation? observation}) =>
    showHealthSheet<void>(context, QuickLogSheet(pet: pet, category: category, observation: observation));

class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key, required this.pet, this.category, this.observation});

  final Pet pet;
  final String? category;
  final Observation? observation;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  final _weight = TextEditingController();
  final _note = TextEditingController();
  QuickLogCategory? _category;
  ObservationLevel? _level;
  late DateTime _at;
  bool _busy = false;
  String? _error;

  SpeciesSettings get _settings => SpeciesSettings.of(widget.pet.species);
  bool get _grams => _settings.weightInGrams;
  bool get _editing => widget.observation != null;
  String get _petId => widget.pet.id;
  DateTime get _now => ref.read(healthClockProvider)();

  @override
  void initState() {
    super.initState();
    final observation = widget.observation;
    _at = observation?.observedAt ?? _now;
    final key = observation?.category ?? widget.category;
    if (key != null) _category = _settings.category(key);
    if (observation != null) {
      _level = observation.level;
      _note.text = observation.note;
      final value = observation.value;
      if (value != null) {
        _weight.text = _grams ? formatNumber(value * 1000, decimals: 0) : formatNumber(value, decimals: 2);
      }
    }
    _weight.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isWeight => _category?.scale == QuickLogScale.weight;

  /// The typed weight in kilograms, or `null` while it is not a number.
  double? get _kilograms {
    final typed = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (typed == null || typed <= 0) return null;
    return _grams ? typed / 1000 : typed;
  }

  bool get _ready => _category != null && (_isWeight ? _kilograms != null : _level != null);

  Future<void> _pickWhen() async {
    final now = _now;
    final day = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      currentDate: now,
      helpText: 'When did you notice it?',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at), helpText: 'Time');
    if (!mounted) return;
    final picked = atTime(day, time ?? TimeOfDay.fromDateTime(_at));
    setState(() => _at = picked.isAfter(now) ? now : picked);
  }

  Future<void> _save() async {
    final category = _category;
    if (category == null) return;
    final kilograms = _kilograms;
    if (_isWeight && (kilograms == null || kilograms > 500)) {
      setState(() => _error = 'That weight does not look right. Please check the number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(observationsProvider(_petId).notifier)
          .save(
            Observation(
              id: widget.observation?.id ?? '',
              petId: _petId,
              category: category.key,
              level: _isWeight ? null : _level,
              value: _isWeight ? kilograms : null,
              note: _note.text.trim(),
              observedAt: _at,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      showHealthSnack(context, _editing ? 'Entry updated.' : 'Saved to the journal.');
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Delete this entry?',
      message: 'It is removed from the journal. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(observationsProvider(_petId).notifier).delete(widget.observation!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = healthErrorMessage(error);
        });
      }
    }
  }

  void _urgent() {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    showEmergencySheet(navigator.context, _petId);
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final category = _category;
    final now = ref.watch(healthClockProvider)();
    Observation? lastWeight;
    if (_isWeight) {
      final weights = weightEntries(ref.watch(observationsProvider(_petId)).value ?? const []);
      for (final w in weights) {
        if (w.id != widget.observation?.id) lastWeight = w;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetTitle(
          _editing ? 'Edit entry' : 'Quick log for ${pet.name}',
          subtitle: _editing ? category?.label : 'What did you notice?',
        ),
        if (!_editing) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in _settings.quickLog)
                ChoiceChip(
                  key: ValueKey('quick-${c.key}'),
                  avatar: Icon(c.icon, size: 18, color: AppColors.ink),
                  label: Text(c.label),
                  selected: c.key == category?.key,
                  showCheckmark: false,
                  onSelected: (_) => setState(() {
                    if (_category?.key != c.key) _level = null;
                    _category = c;
                    _error = null;
                  }),
                ),
            ],
          ),
        ],
        if (category != null) ...[
          if (_isWeight) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('quick-weight'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
              decoration: InputDecoration(
                labelText: _grams ? 'Weight in grams' : 'Weight in kilograms',
                suffixText: _grams ? 'g' : 'kg',
              ),
            ),
            if (lastWeight != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
                child: Text(
                  'Last time: ${formatWeight(lastWeight.value!, grams: _grams)} on ${formatDate(lastWeight.observedAt)}',
                  style: AppText.secondary.copyWith(color: AppColors.brown),
                ),
              ),
          ] else ...[
            FormLabel(category.label),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final level in category.levels)
                  ChoiceChip(
                    key: ValueKey('level-${level.dbValue}'),
                    label: Text(level.label),
                    selected: level == _level,
                    onSelected: (_) => setState(() => _level = level),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PickerTile(
            key: const Key('quick-when'),
            icon: Icons.schedule_rounded,
            label: 'When',
            value: '${formatRelativeDay(_at, now)} · ${formatTime(_at)}',
            onTap: _pickWhen,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('quick-note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.body.copyWith(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(
          label: _editing ? 'Save changes' : 'Save to journal',
          loading: _busy,
          onPressed: _ready ? _save : null,
        ),
        if (_editing)
          Center(
            child: HealthLink(
              'Delete this entry',
              key: const Key('quick-delete'),
              icon: Icons.delete_outline_rounded,
              onPressed: _busy ? null : _delete,
            ),
          ),
        Center(
          child: HealthLink(
            'Looks urgent? Contact the vet',
            key: const Key('quick-urgent'),
            icon: emergencyIcon,
            onPressed: _urgent,
          ),
        ),
        const FinePrint('A record of what you noticed. The app does not interpret it.'),
      ],
    );
  }
}
