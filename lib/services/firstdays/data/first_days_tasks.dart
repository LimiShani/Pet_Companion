import '../../../models/pet.dart';
import '../../pet_records/data/health_models.dart' show CareKind;
import '../../store/data/deal.dart' show DealCategory;

/// Where a task sits on the page.
enum FirstDaysWeek {
  /// Days 1 to 7.
  first,

  /// Days 8 to 30.
  later,
}

/// What the app can see by itself, so a task ticks without the owner.
enum FirstDaysAutoCheck {
  /// A Health record of kind "vet visit" dated on or after the arrival day.
  vetVisit,

  /// The health profile has a microchip number, or "not chipped".
  microchip,

  /// An active feeding routine (meal times).
  mealTimes,

  /// The pet's food is set (its calories are known).
  food,

  /// An active walk routine (walk times).
  walkTimes,

  /// An active cage cleaning routine.
  cleaningRoutine,
}

/// The screen a task's pill opens.
enum FirstDaysActionKind {
  /// The Store tab, on the deals that suit the pet ([FirstDaysAction.category]).
  store,

  /// The food and portion page.
  foodSettings,

  /// The feeding page (today's meals, meal times).
  feeding,

  /// The activity page (walks or play, walk times).
  activity,

  /// Health: a new "vet visit" record.
  addCheckup,

  /// Health: the pet's health profile (the microchip).
  healthProfile,

  /// The Health tab, on its Schedule.
  schedule,

  /// Health: a new routine of [FirstDaysAction.careKind].
  routine,

  /// Community: one guide ([FirstDaysAction.guideId]).
  guide,

  /// Community: the guides library.
  guides,
}

class FirstDaysAction {
  const FirstDaysAction(
    this.kind, {
    this.category,
    this.guideId,
    this.careKind,
  });

  final FirstDaysActionKind kind;
  final DealCategory? category;
  final String? guideId;
  final CareKind? careKind;
}

/// One step of the path. The words are in the strings files, by [id]
/// (see `first_days_words.dart`); ids are stored, so they never change.
class FirstDaysTask {
  const FirstDaysTask(this.id, this.week, {this.action, this.auto});

  final String id;
  final FirstDaysWeek week;

  /// The screen that does it, or `null` for something done away from the
  /// app (a quiet corner, a name tag).
  final FirstDaysAction? action;

  /// How the app ticks it by itself, or `null` when only the owner can.
  final FirstDaysAutoCheck? auto;
}

const _food = FirstDaysTask(
  'food',
  FirstDaysWeek.first,
  action: FirstDaysAction(FirstDaysActionKind.foodSettings),
  auto: FirstDaysAutoCheck.food,
);
const _mealTimes = FirstDaysTask(
  'meal-times',
  FirstDaysWeek.first,
  action: FirstDaysAction(FirstDaysActionKind.feeding),
  auto: FirstDaysAutoCheck.mealTimes,
);
const _firstVet = FirstDaysTask(
  'first-vet',
  FirstDaysWeek.first,
  action: FirstDaysAction(FirstDaysActionKind.addCheckup),
  auto: FirstDaysAutoCheck.vetVisit,
);
const _microchip = FirstDaysTask(
  'microchip',
  FirstDaysWeek.later,
  action: FirstDaysAction(FirstDaysActionKind.healthProfile),
  auto: FirstDaysAutoCheck.microchip,
);
const _vaccines = FirstDaysTask(
  'vaccines',
  FirstDaysWeek.later,
  action: FirstDaysAction(FirstDaysActionKind.schedule),
);

const _dogTasks = <FirstDaysTask>[
  FirstDaysTask(
    'dog-basics',
    FirstDaysWeek.first,
    action: FirstDaysAction(FirstDaysActionKind.store),
  ),
  FirstDaysTask('dog-rest-spot', FirstDaysWeek.first),
  _food,
  _mealTimes,
  FirstDaysTask(
    'walk-times',
    FirstDaysWeek.first,
    action: FirstDaysAction(FirstDaysActionKind.activity),
    auto: FirstDaysAutoCheck.walkTimes,
  ),
  FirstDaysTask('dog-name-tag', FirstDaysWeek.first),
  _firstVet,
  FirstDaysTask(
    'dog-guide',
    FirstDaysWeek.first,
    action: FirstDaysAction(FirstDaysActionKind.guide, guideId: 'first-week'),
  ),
  _microchip,
  _vaccines,
  FirstDaysTask('dog-first-walks', FirstDaysWeek.later),
  FirstDaysTask('dog-house-rules', FirstDaysWeek.later),
];

const _catTasks = <FirstDaysTask>[
  FirstDaysTask(
    'cat-basics',
    FirstDaysWeek.first,
    action: FirstDaysAction(FirstDaysActionKind.store),
  ),
  FirstDaysTask('cat-safe-room', FirstDaysWeek.first),
  _food,
  _mealTimes,
  _firstVet,
  FirstDaysTask(
    'cat-guide',
    FirstDaysWeek.first,
    action: FirstDaysAction(
      FirstDaysActionKind.guide,
      guideId: 'cat-first-week',
    ),
  ),
  _microchip,
  _vaccines,
  FirstDaysTask(
    'cat-scratching',
    FirstDaysWeek.later,
    action: FirstDaysAction(
      FirstDaysActionKind.store,
      category: DealCategory.toys,
    ),
  ),
  FirstDaysTask('cat-explore', FirstDaysWeek.later),
  FirstDaysTask(
    'cat-play',
    FirstDaysWeek.later,
    action: FirstDaysAction(FirstDaysActionKind.activity),
  ),
];

/// Birds, rabbits, reptiles and any other animal: the shorter list.
const _otherTasks = <FirstDaysTask>[
  FirstDaysTask(
    'other-home',
    FirstDaysWeek.first,
    action: FirstDaysAction(FirstDaysActionKind.store),
  ),
  FirstDaysTask('other-quiet', FirstDaysWeek.first),
  _food,
  _mealTimes,
  _firstVet,
  FirstDaysTask(
    'cleaning',
    FirstDaysWeek.later,
    action: FirstDaysAction(
      FirstDaysActionKind.routine,
      careKind: CareKind.cageCleaning,
    ),
    auto: FirstDaysAutoCheck.cleaningRoutine,
  ),
  FirstDaysTask(
    'guides',
    FirstDaysWeek.later,
    action: FirstDaysAction(FirstDaysActionKind.guides),
  ),
];

/// The tasks of a pet of [species], in the order of the page: the first
/// week, then weeks 2 to 4.
List<FirstDaysTask> firstDaysTasksFor(PetSpecies species) => switch (species) {
  PetSpecies.dog => _dogTasks,
  PetSpecies.cat => _catTasks,
  _ => _otherTasks,
};

/// Every task id there is, for the strings check.
Set<String> get allFirstDaysTaskIds => {
  for (final list in [_dogTasks, _catTasks, _otherTasks])
    for (final task in list) task.id,
};
