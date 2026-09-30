import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/pet.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import 'pets_widgets.dart';

/// Birds and reptiles are weighed in grams; the value is still stored in kg
/// (as in Health).
bool petWeighsInGrams(PetSpecies species) => species == PetSpecies.bird || species == PetSpecies.reptile;

String _trimmed(double value, int decimals) {
  final text = value.toStringAsFixed(decimals);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

/// "18 kg", "4.25 kg", or "35 g" for an animal weighed in grams.
String formatPetWeight(double kg, PetSpecies species) =>
    petWeighsInGrams(species) ? '${_trimmed(kg * 1000, 0)} g' : '${_trimmed(kg, 2)} kg';

/// "Dog · Mixed · about 3 years": the kind, then what is known. The age is
/// counted at [now] (today when not given).
String petSummaryLine(Pet pet, {DateTime? now}) {
  final breed = pet.breed?.trim() ?? '';
  final age = pet.ageLabelAt(now ?? DateTime.now());
  return [
    pet.species.label,
    if (breed.isNotEmpty) breed,
    if (age != null) '${age[0].toLowerCase()}${age.substring(1)}',
  ].join(' · ');
}

/// What "Mixed or not sure" stores as the breed.
const kMixedBreed = 'Mixed';

enum AgeUnit {
  years('years'),
  months('months');

  const AgeUnit(this.label);

  final String label;
}

/// The parts of the "about the pet" form.
enum BasicsSection { age, weight, sex, neutered, breed }

/// Holds the answers of the "about the pet" form while it is on screen:
/// birthday or approximate age, weight, sex, neutering and breed. Used by
/// step 2 of the add-a-pet flow, the pet profile and the one-field sheets.
class PetBasicsController extends ChangeNotifier {
  PetBasicsController({required Pet pet, required DateTime now}) : _species = pet.species {
    final born = pet.birthDate;
    if (born != null && !pet.birthDateApprox) {
      _ageApprox = false;
      _birthDate = born;
    } else if (born != null) {
      var months = (now.year - born.year) * 12 + now.month - born.month;
      if (now.day < born.day) months--;
      if (months < 0) months = 0;
      if (months >= 24 || (months >= 12 && months % 12 == 0)) {
        ageAmount.text = '${months ~/ 12}';
      } else {
        _ageUnit = AgeUnit.months;
        ageAmount.text = '$months';
      }
    } else if (pet.ageYears != null) {
      // An age given directly (the sample pets): shown, and kept as it is
      // unless the owner changes it.
      ageAmount.text = _trimmed(pet.ageYears!, 1);
    }

    final kg = pet.weightKg;
    if (kg != null) weight.text = petWeighsInGrams(_species) ? _trimmed(kg * 1000, 0) : _trimmed(kg, 2);

    _sex = pet.sex;
    _neutered = pet.neutered;
    final breedText = pet.breed?.trim() ?? '';
    if (breedText.toLowerCase() == kMixedBreed.toLowerCase()) {
      _mixedBreed = true;
    } else {
      breed.text = breedText;
    }
  }

  final ageAmount = TextEditingController();
  final weight = TextEditingController();
  final breed = TextEditingController();

  PetSpecies _species;
  bool _ageApprox = true;
  bool _ageTouched = false;
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

  /// The kind decides the weight unit; a typed weight keeps its meaning
  /// when the unit changes.
  set species(PetSpecies value) {
    if (value == _species) return;
    final before = petWeighsInGrams(_species);
    final kg = weightKg;
    _species = value;
    if (before != petWeighsInGrams(value) && kg != null) {
      weight.text = petWeighsInGrams(value) ? _trimmed(kg * 1000, 0) : _trimmed(kg, 2);
    }
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
    _ageTouched = true;
    notifyListeners();
  }

  set ageUnit(AgeUnit value) {
    if (value == _ageUnit) return;
    _ageUnit = value;
    _ageTouched = true;
    notifyListeners();
  }

  void ageAmountChanged() => _ageTouched = true;

  set sex(PetSex? value) {
    _sex = value;
    notifyListeners();
  }

  set neutered(Neutered? value) {
    _neutered = value;
    notifyListeners();
  }

  set mixedBreed(bool value) {
    _mixedBreed = value;
    if (value) breed.clear();
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

  String? validateWeight(String? text) {
    if ((text ?? '').trim().isEmpty) return null;
    final value = _number(text!);
    if (value == null || value <= 0) return 'Enter a number, for example ${weightInGrams ? '35' : '18'}.';
    final kg = weightInGrams ? value / 1000 : value;
    if (kg > 2000) return 'That looks too heavy. Please check the number.';
    return null;
  }

  String? validateAgeAmount(String? text) {
    if (!_ageApprox || (text ?? '').trim().isEmpty) return null;
    final value = _number(text!);
    if (value == null || value <= 0) return 'Enter a number.';
    final years = _ageUnit == AgeUnit.years ? value : value / 12;
    if (years > 120) return 'Please check the number.';
    return null;
  }

  /// The answer to the age question at [now]: a birthday, exact or worked
  /// out from "about 3 years"; `null` when it is not answered.
  ({DateTime date, bool approx})? ageAnswer(DateTime now) {
    if (!_ageApprox) {
      final date = _birthDate;
      return date == null ? null : (date: date, approx: false);
    }
    final value = _number(ageAmount.text);
    if (value == null || value <= 0) return null;
    final months = (_ageUnit == AgeUnit.years ? value * 12 : value).round();
    // Never past the 28th, so that the day exists in every month.
    final day = now.day > 28 ? 28 : now.day;
    return (date: DateTime(now.year, now.month - months, day), approx: true);
  }

  /// [pet] with the form's answers. Anything left empty is stored as "not
  /// answered". An age the owner did not touch is kept exactly as it was.
  Pet applyTo(Pet pet, {required DateTime now, String? name, PetSpecies? species, Set<BasicsSection>? only}) {
    bool has(BasicsSection section) => only == null || only.contains(section);
    final age = ageAnswer(now);
    final breedText = _mixedBreed ? kMixedBreed : breed.text.trim();
    return pet.withBasics(
      name: name ?? pet.name,
      species: species ?? pet.species,
      breed: has(BasicsSection.breed) ? (breedText.isEmpty ? null : breedText) : pet.breed,
      weightKg: has(BasicsSection.weight) ? weightKg : pet.weightKg,
      sex: has(BasicsSection.sex) ? _sex : pet.sex,
      neutered: has(BasicsSection.neutered) ? _neutered : pet.neutered,
      birthDate: age?.date,
      birthDateApprox: age?.approx ?? false,
      keepAge: !has(BasicsSection.age) || !_ageTouched,
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
      helpText: 'Birthday',
    );
    if (picked != null) controller.birthDate = picked;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sections.contains(BasicsSection.age)) ...[
              if (showLabels) const PetsLabel('Birthday or age', level: FieldLevel.essential),
              TwoWaySwitch(
                first: 'I know the date',
                second: 'About…',
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
                        decoration: const InputDecoration(labelText: 'About', errorMaxLines: 3),
                        validator: c.validateAgeAmount,
                        onChanged: (_) => c.ageAmountChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ChoiceChips<AgeUnit>(
                          options: AgeUnit.values,
                          labelOf: (unit) => unit.label,
                          selected: c.ageUnit,
                          allowClear: false,
                          onSelected: (unit) => c.ageUnit = unit!,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const PetsFinePrint('A guess is fine. Shown as "About 3 years", and it keeps counting.'),
              ] else
                _DateField(
                  key: const Key('pet-age-date'),
                  text: c.birthDate == null ? null : _date.format(c.birthDate!),
                  onTap: () => _pickDate(context),
                ),
            ],
            if (sections.contains(BasicsSection.weight)) ...[
              if (showLabels) const PetsLabel('Weight', level: FieldLevel.essential),
              TextFormField(
                key: const Key('pet-weight'),
                controller: c.weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_numberInput],
                decoration: InputDecoration(
                  labelText: 'A rough number is fine',
                  suffixText: c.weightInGrams ? 'g' : 'kg',
                  errorMaxLines: 3,
                ),
                validator: c.validateWeight,
              ),
            ],
            if (sections.contains(BasicsSection.sex)) ...[
              if (showLabels) const PetsLabel('Sex'),
              ChoiceChips<PetSex>(
                options: PetSex.values,
                labelOf: (sex) => sex.label,
                selected: c.sex,
                onSelected: (sex) => c.sex = sex,
              ),
            ],
            if (sections.contains(BasicsSection.neutered)) ...[
              if (showLabels) const PetsLabel('Neutered or spayed'),
              ChoiceChips<Neutered>(
                options: Neutered.values,
                labelOf: (neutered) => neutered.label,
                selected: c.neutered,
                onSelected: (neutered) => c.neutered = neutered,
              ),
            ],
            if (sections.contains(BasicsSection.breed)) ...[
              if (showLabels) const PetsLabel('Breed'),
              TextFormField(
                key: const Key('pet-breed'),
                controller: c.breed,
                enabled: !c.mixedBreed,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: c.mixedBreed ? 'Mixed or not sure' : 'Breed (optional)',
                  hintText: 'e.g. Labrador',
                  errorMaxLines: 3,
                ),
                validator: (text) => (text?.trim().length ?? 0) > 60 ? 'Keep the breed under 60 characters.' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilterChip(
                  label: const Text('Mixed or not sure'),
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
          decoration: const InputDecoration(
            labelText: 'Birthday',
            suffixIcon: Icon(Icons.calendar_month_rounded, color: AppColors.brown),
          ),
          child: Text(
            text ?? 'Choose the date',
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
