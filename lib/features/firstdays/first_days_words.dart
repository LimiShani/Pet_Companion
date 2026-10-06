import '../../l10n/l10n.dart';
import '../../services/firstdays/data/first_days_tasks.dart';

/// The words of the task with [id], in the language of [l10n]. An unknown
/// id (a task of another kind of animal, stored before the pet's kind was
/// changed) is never on screen, so it has no words.
String firstDaysTaskText(FirstDaysL10n l10n, String id) => switch (id) {
  'dog-basics' => l10n.taskDogBasics,
  'dog-rest-spot' => l10n.taskDogRestSpot,
  'food' => l10n.taskFood,
  'meal-times' => l10n.taskMealTimes,
  'walk-times' => l10n.taskWalkTimes,
  'dog-name-tag' => l10n.taskDogNameTag,
  'first-vet' => l10n.taskFirstVet,
  'dog-guide' => l10n.taskDogGuide,
  'microchip' => l10n.taskMicrochip,
  'vaccines' => l10n.taskVaccines,
  'dog-first-walks' => l10n.taskDogFirstWalks,
  'dog-house-rules' => l10n.taskDogHouseRules,
  'cat-basics' => l10n.taskCatBasics,
  'cat-safe-room' => l10n.taskCatSafeRoom,
  'cat-guide' => l10n.taskCatGuide,
  'cat-scratching' => l10n.taskCatScratching,
  'cat-explore' => l10n.taskCatExplore,
  'cat-play' => l10n.taskCatPlay,
  'other-home' => l10n.taskOtherHome,
  'other-quiet' => l10n.taskOtherQuiet,
  'cleaning' => l10n.taskCleaning,
  'guides' => l10n.taskGuides,
  _ => '',
};

/// The label of the pill that opens the screen of [kind].
String firstDaysActionLabel(FirstDaysL10n l10n, FirstDaysActionKind kind) =>
    switch (kind) {
      FirstDaysActionKind.store => l10n.actionDeals,
      FirstDaysActionKind.foodSettings => l10n.actionFood,
      FirstDaysActionKind.feeding => l10n.actionFeeding,
      FirstDaysActionKind.activity => l10n.actionActivity,
      FirstDaysActionKind.addCheckup => l10n.actionAddVisit,
      FirstDaysActionKind.healthProfile => l10n.actionMicrochip,
      FirstDaysActionKind.schedule => l10n.actionSchedule,
      FirstDaysActionKind.routine => l10n.actionRoutine,
      FirstDaysActionKind.guide => l10n.actionRead,
      FirstDaysActionKind.guides => l10n.actionGuides,
    };
