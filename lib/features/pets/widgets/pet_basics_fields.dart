import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../pet_words.dart';
import 'pets_widgets.dart';

/// The unit of an approximate age: "about 3 years", "about 4 months".
enum AgeUnit { years, months }

/// The parts of the "about the pet" form.
enum BasicsSection { age, weight, sex, neutered, breed }

/// Holds the answers of the "about the pet" form while it is on screen:
/// birthday or approximate age, weight, sex, neutering and breed. Used by
/// step 2 of the add-a-pet flow, the pet profile and the one-field sheets.
///
/// Only what the owner actually changed is written back ([applyTo]); the
/// rest follows the stored pet ([refresh]). So an answer given elsewhere
/// while the form is open (a weight added from the checklist, say) is never
/// overwritten by a form that still shows the old value.
class PetBasicsController extends ChangeNotifier {
  PetBasicsController({required Pet pet, required DateTime now}) : _species = pet.species {
    for (final section in BasicsSection.values) {
      _load(section, pet, now);
    }
  }

  final ageAmount = TextEditingController();
  final weight = TextEditingController();
  final breed = TextEditingController();

  /// The parts the owner changed since they were loaded or saved.
  final _touched = <BasicsSection>{};

  PetSpecies _species;
  bool _ageApprox = true;
  DateTime? _birthDate;
  AgeUnit _ageUnit = AgeUnit.years;
  PetSex? _sex;
  Neutered? _neutered;
  bool _mixedBreed = false;

  bool get ageApprox => _ageApprox;
  DateTime? get birthDate => _birthDate;
  AgeUnit get ageUnit => _ageUnit;
  PetSex? get sex => _sex;
  Neutered? get neutered => _neutered;
  bool get mixedBreed => _mixedBreed;
  bool get weightInGrams => petWeighsInGrams(_species);

  static String _weightText(double kg, PetSpecies species) =>
      petWeighsInGrams(species) ? trimmedNumber(kg * 1000, 0) : trimmedNumber(kg, 3);

  static void _show(TextEditingController field, String text) {
    if (field.text != text) field.text = text;
  }

  /// Shows what [pet] has for [section].
  void _load(BasicsSection section, Pet pet, DateTime now) {
    switch (section) {
      case BasicsSection.age:
        _ageApprox = true;
        _birthDate = null;
        _ageUnit = AgeUnit.years;
        var amount = '';
        final born = pet.birthDate;
        if (born != null && !pet.birthDateApprox) {
          _ageApprox = false;
          _birthDate = born;
        } else if (born != null) {
          var months = (now.year - born.year) * 12 + now.month - born.month;
          if (now.day < born.day) months--;
          if (months < 0) months = 0;
          if (months >= 24 || (months >= 12 && months % 12 == 0)) {
            amount = '${months ~/ 12}';
          } else {
            _ageUnit = AgeUnit.months;
            amount = '$months';
          }
        } else if (pet.ageYears != null) {
          // An age given directly (the sample pets): shown, and kept as it
          // is unless the owner changes it.
          amount = trimmedNumber(pet.ageYears!, 1);
        }
        _show(ageAmount, amount);
      case BasicsSection.weight:
        final kg = pet.weightKg;
        _show(weight, kg == null ? '' : _weightText(kg, _species));
      case BasicsSection.sex:
        _sex = pet.sex;
      case BasicsSection.neutered:
        _neutered = pet.neutered;
      case BasicsSection.breed:
        final text = pet.breed?.trim() ?? '';
        _mixedBreed = text.toLowerCase() == kMixedBreed.toLowerCase();
        _show(breed, _mixedBreed ? '' : text);
    }
  }

  /// Follows the stored [pet] for everything the owner has not changed
  /// here: call it when the pet changes while the form is open.
  void refresh(Pet pet, DateTime now) {
    _species = pet.species;
    for (final section in BasicsSection.values) {
      if (!_touched.contains(section)) _load(section, pet, now);
    }
    notifyListeners();
  }

  /// The form was saved: from here on it follows the stored pet again.
  void markSaved() => _touched.clear();

  /// The owner typed in the field of [section].
  void touch(BasicsSection section) => _touched.add(section);

  /// The kind decides the weight unit; a typed weight keeps its meaning
  /// when the unit changes.
  set species(PetSpecies value) {
    if (value == _species) return;
    final before = petWeighsInGrams(_species);
    final kg = weightKg;
    _species = value;
    if (before != petWeighsInGrams(value) && kg != null) weight.text = _weightText(kg, value);
    notifyListeners();
  }

  // Switching between the two ways of answering changes nothing by itself:
  // only a typed number or a picked date replaces the age.
  set ageApprox(bool value) {
    if (value == _ageApprox) return;
    _ageApprox = value;
    notifyListeners();
  }

  set birthDate(DateTime? value) {
    _birthDate = value;
    _touched.add(BasicsSection.age);
    notifyListeners();
  }

  set ageUnit(AgeUnit value) {
    if (value == _ageUnit) return;
    _ageUnit = value;
    _touched.add(BasicsSection.age);
    notifyListeners();
  }

  set sex(PetSex? value) {
    _sex = value;
    _touched.add(BasicsSection.sex);
    notifyListeners();
  }

  set neutered(Neutered? value) {
    _neutered = value;
    _touched.add(BasicsSection.neutered);
    notifyListeners();
  }

  set mixedBreed(bool value) {
    _mixedBreed = value;
    if (value) breed.clear();
    _touched.add(BasicsSection.breed);
    notifyListeners();
  }

  static double? _number(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    return cleaned.isEmpty ? null : double.tryParse(cleaned);
  }

  /// The typed weight in kg, or `null` when the field is empty or not a
  /// number.
  double? get weightKg {
    final value = _number(weight.text);
    if (value == null || value <= 0) return null;
    return petWeighsInGrams(_species) ? value / 1000 : value;
  }

  /// What is wrong with the typed weight, in the words of [l10n]; `null`
  /// when it is fine (or empty: every field may be left out).
  String? validateWeight(PetsL10n l10n, String? text) {
    if ((text ?? '').trim().isEmpty) return null;
    final value = _number(text!);
    if (value == null || value <= 0) return l10n.enterANumberLike(weightInGrams ? 35 : 18);
    final kg = weightInGrams ? value / 1000 : value;
    if (kg > 2000) return l10n.tooHeavy;
    return null;
  }

  String? validateAgeAmount(PetsL10n l10n, String? text) {
    if (!_ageApprox || (text ?? '').trim().isEmpty) return null;
    final value = _number(text!);
    if (value == null || value <= 0) return l10n.enterANumber;
    final years = _ageUnit == AgeUnit.years ? value : value / 12;
    if (years > 120) return l10n.checkTheNumber;
    return null;
  }

  /// The answer to the age question at [now]: a birthday, exact or worked
  /// out from "about 3 years"; `null` when it is not answered.
  ///
  /// The way of answering that is on screen wins. When it is empty, what
  /// was entered the other way still counts: switching to "I know the date"
  /// without picking one does not throw away a typed "about 3 years".
  ({DateTime date, bool approx})? ageAnswer(DateTime now) {
    final picked = _birthDate;
    final exact = picked == null ? null : (date: picked, approx: false);

    ({DateTime date, bool approx})? rough;
    final value = _number(ageAmount.text);
    if (value != null && value > 0) {
      final months = (_ageUnit == AgeUnit.years ? value * 12 : value).round();
      // Never past the 28th, so that the day exists in every month.
      final day = now.day > 28 ? 28 : now.day;
      rough = (date: DateTime(now.year, now.month - months, day), approx: true);
    }
    return _ageApprox ? rough ?? exact : exact ?? rough;
  }

  /// [pet] with what the owner changed in the form; with [only], just those
  /// parts. A changed field left empty is stored as "not answered". What
  /// the owner did not touch stays exactly as [pet] has it.
  Pet applyTo(Pet pet, {required DateTime now, String? name, PetSpecies? species, Set<BasicsSection>? only}) {
    bool changed(BasicsSection section) =>
        _touched.contains(section) && (only == null || only.contains(section));
    final age = ageAnswer(now);
    final breedText = _mixedBreed ? kMixedBreed : breed.text.trim();
    return pet.withBasics(
      name: name ?? pet.name,
      species: species ?? pet.species,
      breed: changed(BasicsSection.breed) ? (breedText.isEmpty ? null : breedText) : pet.breed,
      weightKg: changed(BasicsSection.weight) ? weightKg : pet.weightKg,
      sex: changed(BasicsSection.sex) ? _sex : pet.sex,
      neutered: changed(BasicsSection.neutered) ? _neutered : pet.neutered,
      birthDate: age?.date,
      birthDateApprox: age?.approx ?? false,
      keepAge: !changed(BasicsSection.age),
    );
  }

  @override
  void dispose() {
    ageAmount.dispose();
    weight.dispose();
    breed.dispose();
    super.dispose();
  }
}

/// The fields of the "about the pet" form, driven by a
/// [PetBasicsController]. Put it inside a [Form] to get its validation.
class PetBasicsFields extends StatelessWidget {
  const PetBasicsFields({
    super.key,
    required this.controller,
    required this.now,
    this.sections = const {
      BasicsSection.age,
      BasicsSection.weight,
      BasicsSection.sex,
      BasicsSection.neutered,
      BasicsSection.breed,
    },
    this.showLabels = true,
  });

  final PetBasicsController controller;
  final DateTime now;
  final Set<BasicsSection> sections;

  /// Off for a one-field sheet, whose title already names the field.
  final bool showLabels;

  static final _numberInput = FilteringTextInputFormatter.allow(RegExp('[0-9.,]'));
  static final _date = DateFormat('dd.MM.yyyy');

  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.birthDate ?? today,
      firstDate: DateTime(today.year - 120),
      lastDate: today,
      helpText: context.petsL10n.birthday,
    );
    if (picked != null) controller.birthDate = picked;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final l10n = context.petsL10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sections.contains(BasicsSection.age)) ...[
              if (showLabels) PetsLabel(l10n.birthdayOrAge, level: FieldLevel.essential),
              TwoWaySwitch(
                first: l10n.iKnowTheDate,
                second: l10n.aboutEllipsis,
                secondSelected: c.ageApprox,
                onChanged: (approx) => c.ageApprox = approx,
              ),
              const SizedBox(height: 8),
              if (c.ageApprox) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: TextFormField(
                        key: const Key('pet-age-amount'),
                        controller: c.ageAmount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [_numberInput],
                        decoration: InputDecoration(labelText: l10n.aboutField, errorMaxLines: 3),
                        validator: (text) => c.validateAgeAmount(l10n, text),
                        onChanged: (_) => c.touch(BasicsSection.age),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ChoiceChips<AgeUnit>(
                          options: AgeUnit.values,
                          labelOf: (unit) => unit == AgeUnit.years ? l10n.unitYears : l10n.unitMonths,
                          selected: c.ageUnit,
                          allowClear: false,
                          onSelected: (unit) => c.ageUnit = unit!,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                PetsFinePrint(l10n.ageGuessNote),
              ] else
                _DateField(
                  key: const Key('pet-age-date'),
                  text: c.birthDate == null ? null : _date.format(c.birthDate!),
                  onTap: () => _pickDate(context),
                ),
            ],
            if (sections.contains(BasicsSection.weight)) ...[
              if (showLabels) PetsLabel(l10n.itemWeight, level: FieldLevel.essential),
              TextFormField(
                key: const Key('pet-weight'),
                controller: c.weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_numberInput],
                decoration: InputDecoration(
                  labelText: l10n.hintWeight,
                  suffixText: c.weightInGrams ? l10n.unitG : l10n.unitKg,
                  errorMaxLines: 3,
                ),
                validator: (text) => c.validateWeight(l10n, text),
                onChanged: (_) => c.touch(BasicsSection.weight),
              ),
            ],
            if (sections.contains(BasicsSection.sex)) ...[
              if (showLabels) PetsLabel(l10n.sex),
              ChoiceChips<PetSex>(
                options: PetSex.values,
                labelOf: (sex) => petSexText(l10n, sex),
                selected: c.sex,
                onSelected: (sex) => c.sex = sex,
              ),
            ],
            if (sections.contains(BasicsSection.neutered)) ...[
              if (showLabels) PetsLabel(l10n.neuteredOrSpayed),
              ChoiceChips<Neutered>(
                options: Neutered.values,
                labelOf: (neutered) => petNeuteredText(l10n, neutered),
                selected: c.neutered,
                onSelected: (neutered) => c.neutered = neutered,
              ),
            ],
            if (sections.contains(BasicsSection.breed)) ...[
              if (showLabels) PetsLabel(l10n.itemBreed),
              TextFormField(
                key: const Key('pet-breed'),
                controller: c.breed,
                enabled: !c.mixedBreed,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: c.mixedBreed ? l10n.mixedOrNotSure : l10n.breedOptional,
                  hintText: l10n.breedExample,
                  errorMaxLines: 3,
                ),
                validator: (text) => (text?.trim().length ?? 0) > 60 ? l10n.breedTooLong(60) : null,
                onChanged: (_) => c.touch(BasicsSection.breed),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  label: Text(l10n.mixedOrNotSure),
                  selected: c.mixedBreed,
                  showCheckmark: false,
                  onSelected: (mixed) => c.mixedBreed = mixed,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A field that opens the date picker.
class _DateField extends StatelessWidget {
  const _DateField({super.key, required this.text, required this.onTap});

  final String? text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: context.petsL10n.birthday,
            suffixIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.brown),
          ),
          child: Text(
            text ?? context.petsL10n.chooseTheDate,
            style: AppText.body.copyWith(
              fontSize: 16,
              color: text == null ? AppColors.brown.withValues(alpha: 0.7) : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
