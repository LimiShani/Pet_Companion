import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/unsaved_changes_guard.dart';
import '../health/health_strings.dart';
import '../health/state/health_providers.dart';
import '../health/widgets/health_widgets.dart';
import 'data/care_models.dart';
import 'state/care_providers.dart';
import 'widgets/care_widgets.dart';

/// Opens the "Food and portion" page of [pet].
Future<void> openFoodSettings(BuildContext context, Pet pet) =>
    pushHealthPage<void>(context, FoodSettingsScreen(pet: pet));

/// The food (calories per 100 g, grams in a cup), the usual portion, and
/// the daily calorie goal: the app's estimate or the owner's own.
class FoodSettingsScreen extends ConsumerWidget {
  const FoodSettingsScreen({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CarePage(
      petId: pet.id,
      title: context.careL10n.foodAndPortion,
      child: CareAsync(
        value: ref.watch(careSettingsProvider(pet.id)),
        petId: pet.id,
        builder: (settings) => _FoodForm(pet: pet, settings: settings),
      ),
    );
  }
}

class _FoodForm extends ConsumerStatefulWidget {
  const _FoodForm({required this.pet, required this.settings});

  final Pet pet;
  final CareSettings settings;

  @override
  ConsumerState<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends ConsumerState<_FoodForm> {
  static const saveKey = Key('food-save');

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.settings.foodName);
  late final _kcal = TextEditingController(text: _text(widget.settings.kcalPer100g));
  late final _cup = TextEditingController(text: _text(widget.settings.gramsPerCup));
  late final _portion = TextEditingController(text: _text(widget.settings.portionGrams));
  late final _goal = TextEditingController(text: widget.settings.calorieGoal?.toString() ?? '');
  late bool _ownGoal = widget.settings.calorieGoal != null;
  bool _saving = false;
  Object? _error;

  /// The fields as the page opened, to tell whether anything changed.
  late final List<Object?> _initial;

  static String _text(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _initial = _fields();
    for (final c in [_portion, _cup]) {
      c.addListener(() => setState(() {}));
    }
  }

  List<Object?> _fields() => [for (final c in [_name, _kcal, _cup, _portion, _goal]) c.text, _ownGoal];

  bool get _dirty => !_saving && !listEquals(_fields(), _initial);

  @override
  void dispose() {
    for (final c in [_name, _kcal, _cup, _portion, _goal]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _number(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  /// A validator for an optional number between [min] and [max].
  FormFieldValidator<String> _range(num min, num max, {bool required = false}) => (text) {
    final value = text ?? '';
    if (value.trim().isEmpty && !required) return null;
    final number = _number(value);
    if (number == null || number < min || number > max) {
      final format = AppFormat.of(context);
      return context.careL10n.numberRange(format.integer(min.toInt()), format.integer(max.toInt()));
    }
    return null;
  };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Without an estimate the goal field is the only goal there is.
    final canEstimate = estimatedCalorieGoal(widget.pet, ref.read(healthClockProvider)()) is CalorieEstimate;
    final ownGoal = _ownGoal || !canEstimate;
    final settings = CareSettings(
      petId: widget.pet.id,
      foodName: _name.text.trim(),
      kcalPer100g: _number(_kcal.text),
      gramsPerCup: _number(_cup.text),
      portionGrams: _number(_portion.text),
      calorieGoal: ownGoal ? _number(_goal.text)?.round() : null,
      activityGoalMinutes: widget.settings.activityGoalMinutes,
    );
    try {
      await ref.read(careSettingsProvider(widget.pet.id).notifier).save(settings);
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
    final format = AppFormat.of(context);
    final estimate = estimatedCalorieGoal(widget.pet, ref.watch(healthClockProvider)());
    final portion = _number(_portion.text);
    final cup = _number(_cup.text);
    final error = _error;
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

    final String goalNote;
    if (estimate is CalorieEstimate) {
      goalNote = l10n.goalEstimateNote(format.decimal(estimate.weightKg));
    } else if (estimate == NoEstimate.weight) {
      goalNote = l10n.goalNoWeight;
    } else {
      goalNote = l10n.goalNoSpecies;
    }
    final canEstimate = estimate is CalorieEstimate;
    final ownGoal = _ownGoal || !canEstimate;

    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(labelText: l10n.foodName, hintText: l10n.foodNameHint, counterText: ''),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('food-kcal'),
                  controller: _kcal,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numbers,
                  validator: _range(1, 2000),
                  decoration: InputDecoration(labelText: l10n.kcalPer100g),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _cup,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: numbers,
                  validator: _range(1, 2000),
                  decoration: InputDecoration(labelText: l10n.gramsPerCup),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, top: 4),
            child: Text(l10n.foodBagNote, style: AppText.secondary),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('food-portion'),
            controller: _portion,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: numbers,
            validator: _range(1, 100000),
            decoration: InputDecoration(
              labelText: l10n.portion,
              helperText: portion != null && cup != null && cup > 0
                  ? l10n.portionCups(format.decimal(portion / cup))
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          CareBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.dailyGoal, style: AppText.cardTitle.copyWith(fontSize: 17))),
                    if (canEstimate && !ownGoal)
                      Text(format.integer(estimate.calories), style: AppText.metricSmall.copyWith(fontSize: 22)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(goalNote, style: AppText.secondary),
                if (canEstimate) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.goalByEstimate),
                        selected: !_ownGoal,
                        onSelected: (_) => setState(() => _ownGoal = false),
                      ),
                      ChoiceChip(
                        key: const Key('food-own-goal'),
                        label: Text(l10n.goalOwn),
                        selected: _ownGoal,
                        onSelected: (_) => setState(() => _ownGoal = true),
                      ),
                    ],
                  ),
                ],
                if (ownGoal) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('food-goal'),
                    controller: _goal,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _range(1, 100000),
                    decoration: InputDecoration(labelText: l10n.caloriesADay),
                  ),
                ],
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(healthErrorOf(context, error), style: AppText.body.copyWith(color: AppColors.coralDark)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(key: saveKey, label: l10n.save, loading: _saving, onPressed: _save),
        ],
      ),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([_name, _kcal, _cup, _portion, _goal]),
      builder: (context, child) => UnsavedChangesGuard(dirty: _dirty, child: child!),
      child: form,
    );
  }
}
