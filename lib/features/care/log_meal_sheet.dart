import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../health/data/health_models.dart';
import '../health/health_strings.dart';
import '../health/state/health_providers.dart';
import '../health/widgets/health_widgets.dart';
import 'data/care_models.dart';
import 'state/care_logic.dart';
import 'state/care_providers.dart';

/// Opens the "Log a meal" sheet. [entry] is the meal to start on; without
/// one the sheet picks the open meal closest to now, or an extra meal.
Future<void> showLogMealSheet(BuildContext context, Pet pet, {CareEntry? entry}) =>
    showHealthSheet<void>(context, LogMealSheet(pet: pet, entry: entry));

enum _Amount { whole, half, notEaten, custom }

class LogMealSheet extends ConsumerStatefulWidget {
  const LogMealSheet({super.key, required this.pet, this.entry});

  static const saveKey = Key('log-meal-save');
  static const extraKey = Key('log-meal-extra');
  static const lessKey = Key('log-meal-less');
  static const moreKey = Key('log-meal-more');

  final Pet pet;
  final CareEntry? entry;

  @override
  ConsumerState<LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends ConsumerState<LogMealSheet> {
  /// The planned meal chosen, or `null` for an extra meal.
  CareEntry? _meal;
  bool _chosen = false;
  _Amount _amount = _Amount.whole;
  double? _grams;
  TimeOfDay? _time;
  bool _saving = false;
  Object? _error;

  String get _petId => widget.pet.id;

  void _init(FeedingDay day, DateTime now) {
    if (_chosen) return;
    _chosen = true;
    _meal = widget.entry ?? day.suggested(now);
    _grams = day.settings.portionGrams;
    _time = TimeOfDay.fromDateTime(now);
  }

  double? _gramsFor(CareSettings settings) {
    final portion = settings.portionGrams;
    return switch (_amount) {
      _Amount.whole => portion ?? _grams,
      _Amount.half => portion == null ? _grams : portion / 2,
      _Amount.notEaten => null,
      _Amount.custom => _grams,
    };
  }

  void _step(CareSettings settings, double delta) {
    final current = _gramsFor(settings) ?? settings.portionGrams ?? 100;
    setState(() {
      _amount = _Amount.custom;
      _grams = (current + delta).clamp(5, 5000).toDouble();
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _save(FeedingDay day) async {
    final settings = day.settings;
    final now = ref.read(healthClockProvider)();
    final meal = _meal;
    final eaten = _amount != _Amount.notEaten;
    final grams = eaten ? _gramsFor(settings) : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(carePlanProvider(_petId).notifier)
          .record(
            item: meal?.item,
            kind: meal == null ? CareKind.feeding : null,
            title: meal == null ? context.careL10n.mealTitleExtra : null,
            dueOn: meal?.time ?? now,
            status: eaten ? CareLogStatus.done : CareLogStatus.skipped,
            doneAt: atTime(now, _time ?? TimeOfDay.fromDateTime(now)),
            amountGrams: grams,
            calories: grams == null ? null : settings.caloriesOf(grams),
          );
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
    final l10n = context.careL10n;
    final value = ref.watch(feedingDayProvider(_petId));
    final day = value.value;
    if (day == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final now = ref.watch(healthClockProvider)();
    _init(day, now);
    final format = AppFormat.of(context);
    final settings = day.settings;
    final grams = _gramsFor(settings);
    final calories = grams == null ? null : settings.caloriesOf(grams);
    final planned = [
      for (final m in day.meals)
        if (m.isPlanned) m,
    ];
    final error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(l10n.logMealTitle, subtitle: widget.pet.name),
        const SizedBox(height: 14),
        _Label(l10n.whichMeal),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in planned)
              ChoiceChip(
                // A meal already logged shows a tick; choosing it again
                // replaces what was logged.
                avatar: m.isAnswered ? const Icon(Icons.check_circle_rounded, color: AppColors.sage) : null,
                label: Text('${isolate(m.title)} · ${isolate(format.time(m.time))}'),
                selected: _meal?.item?.id == m.item!.id,
                onSelected: (_) => setState(() => _meal = m),
              ),
            ChoiceChip(
              key: LogMealSheet.extraKey,
              label: Text(l10n.extra),
              selected: _meal == null,
              onSelected: (_) => setState(() => _meal = null),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Label(l10n.howMuch),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (settings.portionGrams != null) ...[
              ChoiceChip(
                label: Text(l10n.wholePortion),
                selected: _amount == _Amount.whole,
                onSelected: (_) => setState(() => _amount = _Amount.whole),
              ),
              ChoiceChip(
                label: Text(l10n.halfPortion),
                selected: _amount == _Amount.half,
                onSelected: (_) => setState(() => _amount = _Amount.half),
              ),
            ],
            if (_meal != null)
              ChoiceChip(
                label: Text(l10n.notEaten),
                selected: _amount == _Amount.notEaten,
                onSelected: (_) => setState(() => _amount = _Amount.notEaten),
              ),
          ],
        ),
        if (_amount != _Amount.notEaten) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            ),
            child: Row(
              children: [
                IconButton(
                  key: LogMealSheet.lessKey,
                  tooltip: l10n.less,
                  onPressed: () => _step(settings, -10),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Text(
                    grams == null ? '–' : l10n.gramsValue(format.decimal(grams)),
                    textAlign: TextAlign.center,
                    style: AppText.metricSmall,
                  ),
                ),
                IconButton(
                  key: LogMealSheet.moreKey,
                  tooltip: l10n.more,
                  onPressed: () => _step(settings, 10),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            calories == null
                ? l10n.addFoodToCount
                : '${l10n.equalsCalories(format.integer(calories))}'
                      '${settings.foodName.isEmpty ? '' : ' · ${settings.foodName}'}',
            textAlign: TextAlign.center,
            style: AppText.secondary,
          ),
        ],
        const SizedBox(height: 10),
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
            title: Text(l10n.time, style: AppText.body),
            trailing: Text(format.timeOfDay(_time!), style: AppText.cardTitle.copyWith(fontSize: 16)),
            onTap: _pickTime,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(healthErrorOf(context, error), style: AppText.body.copyWith(color: AppColors.coralDark)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(key: LogMealSheet.saveKey, label: l10n.save, loading: _saving, onPressed: () => _save(day)),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppText.label.copyWith(color: AppColors.brown)),
  );
}
