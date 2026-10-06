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

/// The two short groups the Quick log's categories are shown in. [label]
/// is its English name, for logs and tests; a screen says it with
/// `HealthWords.quickLogGroup`.
enum QuickLogGroup {
  /// Weight, appetite, coat... how the body is doing.
  body('Body'),

  /// Sleep, barking or meowing, biting... what the pet does.
  behaviour('Behaviour');

  const QuickLogGroup(this.label);

  final String label;
}

/// What a Quick log category is called. [english] is the name for logs and
/// tests; a screen says it in its own language with
/// `HealthWords.quickLogCategory`.
enum QuickLogName {
  weight('Weight'),
  appetite('Appetite'),
  energy('Energy'),
  mobility('Mobility'),
  digestion('Digestion'),
  skinCoat('Skin or coat'),
  dental('Dental'),
  drinking('Drinking'),
  diet('Diet'),
  droppings('Droppings'),
  feathers('Feathers'),
  activity('Activity'),
  environment('Environment'),
  eating('Eating'),
  feeding('Feeding'),
  shedding('Shedding'),
  temperature('Temperature'),
  humidity('Humidity'),
  lighting('Lighting'),
  other('Other'),
  sleep('Sleep'),
  barking('Barking'),
  meowing('Meowing'),
  vocalisation('Vocalisation'),
  biting('Biting'),
  bitingScratching('Biting or scratching'),
  leftAlone('When left alone'),
  litterBox('Litter box use'),
  otherBehaviour('Other behaviour');

  const QuickLogName(this.english);

  final String english;
}

/// One thing the owner can log about a pet.
class QuickLogCategory {
  const QuickLogCategory(
    this.key,
    QuickLogName this.name,
    this.icon,
    this.scale, [
    this.group = QuickLogGroup.body,
  ]) : _madeUpLabel = null;

  /// A category the app has no name for (a key logged by a newer version):
  /// it is called what its key says.
  const QuickLogCategory.unnamed(this.key, String label, this.icon, this.scale)
    : name = null,
      _madeUpLabel = label,
      group = QuickLogGroup.body;

  /// Stored in `health_observations.category`.
  final String key;

  /// What it is called, or `null` for a category the app does not know.
  final QuickLogName? name;
  final String? _madeUpLabel;
  final IconData icon;
  final QuickLogScale scale;
  final QuickLogGroup group;

  /// The name in English, for logs and tests.
  String get label => name?.english ?? _madeUpLabel ?? '';

  List<ObservationLevel> get levels => switch (scale) {
    QuickLogScale.weight => const [],
    QuickLogScale.amount => const [
      ObservationLevel.usual,
      ObservationLevel.less,
      ObservationLevel.more,
      ObservationLevel.unsure,
    ],
    QuickLogScale.appearance => const [
      ObservationLevel.usual,
      ObservationLevel.different,
      ObservationLevel.unsure,
    ],
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
    this.cageIsEnclosure = false,
  });

  /// Every record kind, the most relevant for the species first.
  final List<RecordKind> recordKinds;

  /// The Quick log categories: the body group first, then behaviour.
  final List<QuickLogCategory> quickLog;

  /// Routine kinds offered in the routine form (never [CareKind.medication]).
  final List<CareKind> routineKinds;

  /// Small animals are weighed in grams; the value is still stored in kg.
  final bool weightInGrams;

  /// A reptile lives in an enclosure: "Cage cleaning" is called
  /// "Enclosure cleaning" for it.
  final bool cageIsEnclosure;

  /// The Quick log categories of one group, in the order they are offered.
  List<QuickLogCategory> quickLogIn(QuickLogGroup group) => [
    for (final c in quickLog)
      if (c.group == group) c,
  ];

  /// "Cage cleaning", or "Enclosure cleaning" for a reptile: the English
  /// name, for logs and tests. A screen says it with
  /// `HealthWords.routineKind`.
  String routineLabel(CareKind kind) =>
      kind == CareKind.cageCleaning && cageIsEnclosure
      ? 'Enclosure cleaning'
      : kind.label;

  /// The category for [key], or a generic one for keys logged under
  /// another species or an older version.
  QuickLogCategory category(String key) {
    for (final c in quickLog) {
      if (c.key == key) return c;
    }
    for (final c in _allCategories) {
      if (c.key == key) return c;
    }
    if (key.isEmpty) {
      return QuickLogCategory(
        key,
        QuickLogName.other,
        Icons.edit_note_rounded,
        QuickLogScale.appearance,
      );
    }
    final label =
        '${key[0].toUpperCase()}${key.substring(1).replaceAll('_', ' ')}';
    return QuickLogCategory.unnamed(
      key,
      label,
      Icons.edit_note_rounded,
      QuickLogScale.appearance,
    );
  }

  static SpeciesSettings of(PetSpecies species) =>
      _settings[species] ?? _settings[PetSpecies.other]!;
}

const _weight = QuickLogCategory(
  Observation.weightCategory,
  QuickLogName.weight,
  Icons.monitor_weight_rounded,
  QuickLogScale.weight,
);
const _appetite = QuickLogCategory(
  'appetite',
  QuickLogName.appetite,
  Icons.restaurant_rounded,
  QuickLogScale.amount,
);
const _energy = QuickLogCategory(
  'energy',
  QuickLogName.energy,
  Icons.bolt_rounded,
  QuickLogScale.amount,
);
const _mobility = QuickLogCategory(
  'mobility',
  QuickLogName.mobility,
  Icons.pets_rounded,
  QuickLogScale.amount,
);
const _digestion = QuickLogCategory(
  'digestion',
  QuickLogName.digestion,
  Icons.water_drop_rounded,
  QuickLogScale.appearance,
);
const _skin = QuickLogCategory(
  'skin_coat',
  QuickLogName.skinCoat,
  Icons.auto_awesome_rounded,
  QuickLogScale.appearance,
);
const _dental = QuickLogCategory(
  'dental',
  QuickLogName.dental,
  Icons.mood_rounded,
  QuickLogScale.appearance,
);
const _drinking = QuickLogCategory(
  'drinking',
  QuickLogName.drinking,
  Icons.local_drink_rounded,
  QuickLogScale.amount,
);
const _diet = QuickLogCategory(
  'diet',
  QuickLogName.diet,
  Icons.restaurant_rounded,
  QuickLogScale.amount,
);
const _droppings = QuickLogCategory(
  'droppings',
  QuickLogName.droppings,
  Icons.water_drop_rounded,
  QuickLogScale.appearance,
);
const _feathers = QuickLogCategory(
  'feathers',
  QuickLogName.feathers,
  Icons.flutter_dash_rounded,
  QuickLogScale.appearance,
);
const _activity = QuickLogCategory(
  'activity',
  QuickLogName.activity,
  Icons.bolt_rounded,
  QuickLogScale.amount,
);
const _environment = QuickLogCategory(
  'environment',
  QuickLogName.environment,
  Icons.thermostat_rounded,
  QuickLogScale.appearance,
);
const _eating = QuickLogCategory(
  'eating',
  QuickLogName.eating,
  Icons.restaurant_rounded,
  QuickLogScale.amount,
);
const _feeding = QuickLogCategory(
  'feeding',
  QuickLogName.feeding,
  Icons.restaurant_rounded,
  QuickLogScale.amount,
);
const _shedding = QuickLogCategory(
  'shedding',
  QuickLogName.shedding,
  Icons.auto_awesome_rounded,
  QuickLogScale.appearance,
);
const _temperature = QuickLogCategory(
  'temperature',
  QuickLogName.temperature,
  Icons.thermostat_rounded,
  QuickLogScale.appearance,
);
const _humidity = QuickLogCategory(
  'humidity',
  QuickLogName.humidity,
  Icons.water_drop_rounded,
  QuickLogScale.appearance,
);
const _lighting = QuickLogCategory(
  'lighting',
  QuickLogName.lighting,
  Icons.light_mode_rounded,
  QuickLogScale.appearance,
);
const _other = QuickLogCategory(
  'other',
  QuickLogName.other,
  Icons.edit_note_rounded,
  QuickLogScale.appearance,
);

// Behaviour. The app records what the owner noticed and never interprets
// it. A key is shared by every species; the label follows the animal
// ("Barking" for a dog, "Meowing" for a cat).
const _behave = QuickLogGroup.behaviour;
const _sleep = QuickLogCategory(
  'sleep',
  QuickLogName.sleep,
  Icons.bedtime_rounded,
  QuickLogScale.amount,
  _behave,
);
const _barking = QuickLogCategory(
  'vocalisation',
  QuickLogName.barking,
  Icons.volume_up_rounded,
  QuickLogScale.amount,
  _behave,
);
const _meowing = QuickLogCategory(
  'vocalisation',
  QuickLogName.meowing,
  Icons.volume_up_rounded,
  QuickLogScale.amount,
  _behave,
);
const _vocalisation = QuickLogCategory(
  'vocalisation',
  QuickLogName.vocalisation,
  Icons.volume_up_rounded,
  QuickLogScale.amount,
  _behave,
);
const _biting = QuickLogCategory(
  'biting',
  QuickLogName.biting,
  Icons.warning_amber_rounded,
  QuickLogScale.amount,
  _behave,
);
const _bitingScratching = QuickLogCategory(
  'biting',
  QuickLogName.bitingScratching,
  Icons.warning_amber_rounded,
  QuickLogScale.amount,
  _behave,
);
// "More than usual" says nothing here, so the answers are usual / different.
const _leftAlone = QuickLogCategory(
  'left_alone',
  QuickLogName.leftAlone,
  Icons.door_front_door_rounded,
  QuickLogScale.appearance,
  _behave,
);
// How much the box is used. An entry logged earlier as "Different from
// usual" keeps that answer.
const _litter = QuickLogCategory(
  'litter_box',
  QuickLogName.litterBox,
  Icons.inbox_rounded,
  QuickLogScale.amount,
  _behave,
);
const _behaviour = QuickLogCategory(
  'behaviour',
  QuickLogName.otherBehaviour,
  Icons.psychology_rounded,
  QuickLogScale.appearance,
  _behave,
);

const _allCategories = [
  _weight,
  _appetite,
  _energy,
  _mobility,
  _digestion,
  _skin,
  _dental,
  _drinking,
  _litter,
  _behaviour,
  _diet, //
  _droppings,
  _feathers,
  _activity,
  _vocalisation,
  _environment,
  _eating,
  _feeding,
  _shedding,
  _temperature, //
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
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.vaccination,
      RecordKind.preventive,
      RecordKind.medicine,
    ]),
    quickLog: const [
      _weight,
      _appetite,
      _energy,
      _mobility,
      _digestion,
      _skin,
      _dental,
      _other, //
      _sleep, _barking, _biting, _leftAlone, _behaviour,
    ],
    routineKinds: const [
      CareKind.feeding,
      CareKind.walk,
      CareKind.grooming,
      CareKind.other,
    ],
  ),
  PetSpecies.cat: SpeciesSettings(
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.vaccination,
      RecordKind.preventive,
      RecordKind.medicine,
    ]),
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
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.document,
      RecordKind.other,
    ]),
    quickLog: const [
      _weight, _diet, _droppings, _feathers, _activity, _environment, _other, //
      _sleep, _vocalisation, _biting,
    ],
    routineKinds: const [
      CareKind.feeding,
      CareKind.cageCleaning,
      CareKind.other,
    ],
    weightInGrams: true,
  ),
  PetSpecies.rabbit: SpeciesSettings(
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.vaccination,
      RecordKind.other,
    ]),
    quickLog: const [
      _weight,
      _eating,
      _droppings,
      _dental,
      _other,
      _sleep,
      _biting,
      _behaviour,
    ],
    routineKinds: const [
      CareKind.feeding,
      CareKind.cageCleaning,
      CareKind.grooming,
      CareKind.other,
    ],
  ),
  PetSpecies.reptile: SpeciesSettings(
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.document,
      RecordKind.other,
    ]),
    quickLog: const [
      _weight,
      _feeding,
      _shedding,
      _temperature,
      _humidity,
      _lighting,
      _other,
    ],
    routineKinds: const [
      CareKind.feeding,
      CareKind.cageCleaning,
      CareKind.other,
    ],
    weightInGrams: true,
    cageIsEnclosure: true,
  ),
  PetSpecies.other: SpeciesSettings(
    recordKinds: _kinds(const [
      RecordKind.checkup,
      RecordKind.document,
      RecordKind.other,
    ]),
    quickLog: const [_weight, _appetite, _energy, _other, _sleep, _behaviour],
    routineKinds: const [
      CareKind.feeding,
      CareKind.cageCleaning,
      CareKind.other,
    ],
  ),
};
