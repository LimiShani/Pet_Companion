import 'package:flutter/material.dart';

import '../../../models/pet.dart';
import 'health_models.dart';

/// How a Quick log category is answered.
enum QuickLogScale {
  /// A number: the weight.
  weight,

  /// Usual / Less than usual / More than usual / Not sure.
  amount,

  /// Usual / Different from usual / Not sure.
  appearance,
}

/// The two short groups the Quick log's categories are shown in.
enum QuickLogGroup {
  /// Weight, appetite, coat... how the body is doing.
  body('Body'),

  /// Sleep, barking or meowing, biting... what the pet does.
  behaviour('Behaviour');

  const QuickLogGroup(this.label);

  final String label;
}

/// One thing the owner can log about a pet.
class QuickLogCategory {
  const QuickLogCategory(this.key, this.label, this.icon, this.scale, [this.group = QuickLogGroup.body]);

  /// Stored in `health_observations.category`.
  final String key;
  final String label;
  final IconData icon;
  final QuickLogScale scale;
  final QuickLogGroup group;

  List<ObservationLevel> get levels => switch (scale) {
    QuickLogScale.weight => const [],
    QuickLogScale.amount => const [
      ObservationLevel.usual,
      ObservationLevel.less,
      ObservationLevel.more,
      ObservationLevel.unsure,
    ],
    QuickLogScale.appearance => const [ObservationLevel.usual, ObservationLevel.different, ObservationLevel.unsure],
  };
}

/// What the Health tab offers for one species. The navigation is the same
/// for every pet; only these lists change.
class SpeciesSettings {
  const SpeciesSettings({
    required this.recordKinds,
    required this.quickLog,
    required this.routineKinds,
    this.weightInGrams = false,
    this.routineLabels = const {},
  });

  /// Every record kind, the most relevant for the species first.
  final List<RecordKind> recordKinds;

  /// The Quick log categories: the body group first, then behaviour.
  final List<QuickLogCategory> quickLog;

  /// Routine kinds offered in the routine form (never [CareKind.medication]).
  final List<CareKind> routineKinds;

  /// Small animals are weighed in grams; the value is still stored in kg.
  final bool weightInGrams;

  /// What a routine kind is called for this species, where it differs.
  final Map<CareKind, String> routineLabels;

  /// The Quick log categories of one group, in the order they are offered.
  List<QuickLogCategory> quickLogIn(QuickLogGroup group) => [
    for (final c in quickLog)
      if (c.group == group) c,
  ];

  /// "Cage cleaning", or "Enclosure cleaning" for a reptile.
  String routineLabel(CareKind kind) => routineLabels[kind] ?? kind.label;

  /// The category for [key], or a generic one for keys logged under
  /// another species or an older version.
  QuickLogCategory category(String key) {
    for (final c in quickLog) {
      if (c.key == key) return c;
    }
    for (final c in _allCategories) {
      if (c.key == key) return c;
    }
    final label = key.isEmpty ? 'Other' : '${key[0].toUpperCase()}${key.substring(1).replaceAll('_', ' ')}';
    return QuickLogCategory(key, label, Icons.edit_note_rounded, QuickLogScale.appearance);
  }

  static SpeciesSettings of(PetSpecies species) => _settings[species] ?? _settings[PetSpecies.other]!;
}

const _weight = QuickLogCategory(
  Observation.weightCategory,
  'Weight',
  Icons.monitor_weight_rounded,
  QuickLogScale.weight,
);
const _appetite = QuickLogCategory('appetite', 'Appetite', Icons.restaurant_rounded, QuickLogScale.amount);
const _energy = QuickLogCategory('energy', 'Energy', Icons.bolt_rounded, QuickLogScale.amount);
const _mobility = QuickLogCategory('mobility', 'Mobility', Icons.pets_rounded, QuickLogScale.amount);
const _digestion = QuickLogCategory('digestion', 'Digestion', Icons.water_drop_rounded, QuickLogScale.appearance);
const _skin = QuickLogCategory('skin_coat', 'Skin or coat', Icons.auto_awesome_rounded, QuickLogScale.appearance);
const _dental = QuickLogCategory('dental', 'Dental', Icons.mood_rounded, QuickLogScale.appearance);
const _drinking = QuickLogCategory('drinking', 'Drinking', Icons.local_drink_rounded, QuickLogScale.amount);
const _diet = QuickLogCategory('diet', 'Diet', Icons.restaurant_rounded, QuickLogScale.amount);
const _droppings = QuickLogCategory('droppings', 'Droppings', Icons.water_drop_rounded, QuickLogScale.appearance);
const _feathers = QuickLogCategory('feathers', 'Feathers', Icons.flutter_dash_rounded, QuickLogScale.appearance);
const _activity = QuickLogCategory('activity', 'Activity', Icons.bolt_rounded, QuickLogScale.amount);
const _environment = QuickLogCategory('environment', 'Environment', Icons.thermostat_rounded, QuickLogScale.appearance);
const _eating = QuickLogCategory('eating', 'Eating', Icons.restaurant_rounded, QuickLogScale.amount);
const _feeding = QuickLogCategory('feeding', 'Feeding', Icons.restaurant_rounded, QuickLogScale.amount);
const _shedding = QuickLogCategory('shedding', 'Shedding', Icons.auto_awesome_rounded, QuickLogScale.appearance);
const _temperature = QuickLogCategory('temperature', 'Temperature', Icons.thermostat_rounded, QuickLogScale.appearance);
const _humidity = QuickLogCategory('humidity', 'Humidity', Icons.water_drop_rounded, QuickLogScale.appearance);
const _lighting = QuickLogCategory('lighting', 'Lighting', Icons.light_mode_rounded, QuickLogScale.appearance);
const _other = QuickLogCategory('other', 'Other', Icons.edit_note_rounded, QuickLogScale.appearance);

// Behaviour. The app records what the owner noticed and never interprets
// it. A key is shared by every species; the label follows the animal
// ("Barking" for a dog, "Meowing" for a cat).
const _behave = QuickLogGroup.behaviour;
const _sleep = QuickLogCategory('sleep', 'Sleep', Icons.bedtime_rounded, QuickLogScale.amount, _behave);
const _barking = QuickLogCategory('vocalisation', 'Barking', Icons.volume_up_rounded, QuickLogScale.amount, _behave);
const _meowing = QuickLogCategory('vocalisation', 'Meowing', Icons.volume_up_rounded, QuickLogScale.amount, _behave);
const _vocalisation = QuickLogCategory(
  'vocalisation',
  'Vocalisation',
  Icons.volume_up_rounded,
  QuickLogScale.amount,
  _behave,
);
const _biting = QuickLogCategory('biting', 'Biting', Icons.warning_amber_rounded, QuickLogScale.amount, _behave);
const _bitingScratching = QuickLogCategory(
  'biting',
  'Biting or scratching',
  Icons.warning_amber_rounded,
  QuickLogScale.amount,
  _behave,
);
// "More than usual" says nothing here, so the answers are usual / different.
const _leftAlone = QuickLogCategory(
  'left_alone',
  'When left alone',
  Icons.door_front_door_rounded,
  QuickLogScale.appearance,
  _behave,
);
// How much the box is used. An entry logged earlier as "Different from
// usual" keeps that answer.
const _litter = QuickLogCategory('litter_box', 'Litter box use', Icons.inbox_rounded, QuickLogScale.amount, _behave);
const _behaviour = QuickLogCategory(
  'behaviour',
  'Other behaviour',
  Icons.psychology_rounded,
  QuickLogScale.appearance,
  _behave,
);

const _allCategories = [
  _weight, _appetite, _energy, _mobility, _digestion, _skin, _dental, _drinking, _litter, _behaviour, _diet, //
  _droppings, _feathers, _activity, _vocalisation, _environment, _eating, _feeding, _shedding, _temperature, //
  _humidity, _lighting, _other, _sleep, _biting, _leftAlone,
];

const _k = RecordKind.values;

/// [first] in that order, then every other kind.
List<RecordKind> _kinds(List<RecordKind> first) => [
  ...first,
  for (final kind in _k)
    if (!first.contains(kind)) kind,
];

final _settings = <PetSpecies, SpeciesSettings>{
  PetSpecies.dog: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.vaccination, RecordKind.preventive, RecordKind.medicine]),
    quickLog: const [
      _weight, _appetite, _energy, _mobility, _digestion, _skin, _dental, _other, //
      _sleep, _barking, _biting, _leftAlone, _behaviour,
    ],
    routineKinds: const [CareKind.feeding, CareKind.walk, CareKind.grooming, CareKind.other],
  ),
  PetSpecies.cat: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.vaccination, RecordKind.preventive, RecordKind.medicine]),
    quickLog: const [
      _weight, _appetite, _drinking, _dental, _other, //
      _sleep, _meowing, _bitingScratching, _leftAlone, _litter, _behaviour,
    ],
    routineKinds: const [
      CareKind.feeding,
      CareKind.litterCleaning,
      CareKind.litterChange,
      CareKind.grooming,
      CareKind.other,
    ],
  ),
  PetSpecies.bird: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.document, RecordKind.other]),
    quickLog: const [
      _weight, _diet, _droppings, _feathers, _activity, _environment, _other, //
      _sleep, _vocalisation, _biting,
    ],
    routineKinds: const [CareKind.feeding, CareKind.cageCleaning, CareKind.other],
    weightInGrams: true,
  ),
  PetSpecies.rabbit: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.vaccination, RecordKind.other]),
    quickLog: const [_weight, _eating, _droppings, _dental, _other, _sleep, _biting, _behaviour],
    routineKinds: const [CareKind.feeding, CareKind.cageCleaning, CareKind.grooming, CareKind.other],
  ),
  PetSpecies.reptile: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.document, RecordKind.other]),
    quickLog: const [_weight, _feeding, _shedding, _temperature, _humidity, _lighting, _other],
    routineKinds: const [CareKind.feeding, CareKind.cageCleaning, CareKind.other],
    weightInGrams: true,
    routineLabels: const {CareKind.cageCleaning: 'Enclosure cleaning'},
  ),
  PetSpecies.other: SpeciesSettings(
    recordKinds: _kinds(const [RecordKind.checkup, RecordKind.document, RecordKind.other]),
    quickLog: const [_weight, _appetite, _energy, _other, _sleep, _behaviour],
    routineKinds: const [CareKind.feeding, CareKind.cageCleaning, CareKind.other],
  ),
};
