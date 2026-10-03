import '../../../models/pet.dart';
import '../../care/data/care_models.dart';
import '../../health/data/health_models.dart';
import '../../health/state/schedule_logic.dart';
import '../data/first_days_models.dart';
import '../data/first_days_tasks.dart';

/// What the app knows about the pet that can tick a task by itself. Every
/// part may be missing (still loading, or it failed): nothing is ticked
/// from a missing part.
class FirstDaysFacts {
  const FirstDaysFacts({this.records, this.profile, this.plan, this.settings});

  final List<HealthRecord>? records;
  final HealthProfile? profile;
  final CarePlan? plan;
  final CareSettings? settings;

  bool _hasRoutine(CareKind kind) => plan?.items.any((item) => item.kind == kind && item.active) ?? false;

  /// Whether [check] is met for a pet that arrived on [arrivedOn].
  bool meets(FirstDaysAutoCheck check, DateTime arrivedOn) => switch (check) {
    FirstDaysAutoCheck.vetVisit =>
      records?.any((r) => r.kind == RecordKind.checkup && !dateOnly(r.when).isBefore(arrivedOn)) ?? false,
    FirstDaysAutoCheck.microchip => profile?.microchipAnswered ?? false,
    FirstDaysAutoCheck.mealTimes => _hasRoutine(CareKind.feeding),
    FirstDaysAutoCheck.food => settings?.hasFood ?? false,
    FirstDaysAutoCheck.walkTimes => _hasRoutine(CareKind.walk),
    FirstDaysAutoCheck.cleaningRoutine => _hasRoutine(CareKind.cageCleaning),
  };
}

/// One task as the page shows it.
class FirstDaysItem {
  const FirstDaysItem({required this.task, required this.ticked, required this.autoDone});

  final FirstDaysTask task;

  /// Ticked by hand.
  final bool ticked;

  /// What the app sees says it is done.
  final bool autoDone;

  bool get isDone => ticked || autoDone;

  /// The tick is the app's alone: unticking by hand would change nothing.
  bool get onlyAuto => autoDone && !ticked;
}

/// How the path stands.
enum FirstDaysStage {
  /// Day 1 to 30, open, something left to do: the Home card shows.
  running,

  /// Every task is done before day 30. The page still accepts changes.
  finished,

  /// The owner closed it early.
  closed,

  /// Day 30 is over.
  over,
}

/// A pet's path on a given day: its tasks, which are done, and what is next.
class FirstDaysView {
  const FirstDaysView({required this.pet, required this.path, required this.day, required this.items});

  final Pet pet;
  final FirstDaysPath path;

  /// 1 on the arrival day; past [firstDaysLength] once the path is over.
  final int day;
  final List<FirstDaysItem> items;

  int get doneCount => items.where((i) => i.isDone).length;
  int get total => items.length;
  double get progress => total == 0 ? 0 : doneCount / total;

  FirstDaysStage get stage {
    if (path.isClosed) return FirstDaysStage.closed;
    if (day > firstDaysLength) return FirstDaysStage.over;
    if (doneCount == total) return FirstDaysStage.finished;
    return FirstDaysStage.running;
  }

  /// The Home card shows: day 1 to 30, not closed, not finished.
  bool get isRunning => stage == FirstDaysStage.running;

  /// Closed or over: the page is a read-only summary.
  bool get hasEnded => stage == FirstDaysStage.closed || stage == FirstDaysStage.over;

  /// The day shown, kept within 1 to 30.
  int get shownDay => day.clamp(1, firstDaysLength);

  /// The first task not done yet, in the order of the page.
  FirstDaysItem? get next {
    for (final item in items) {
      if (!item.isDone) return item;
    }
    return null;
  }

  List<FirstDaysItem> itemsOf(FirstDaysWeek week) => [
    for (final item in items)
      if (item.task.week == week) item,
  ];
}

/// The path of [pet] at [now], with the tasks of its kind ticked from the
/// owner's ticks and from [facts].
FirstDaysView firstDaysView({
  required Pet pet,
  required FirstDaysPath path,
  required DateTime now,
  FirstDaysFacts facts = const FirstDaysFacts(),
}) {
  return FirstDaysView(
    pet: pet,
    path: path,
    day: firstDaysDayNumber(path.arrivedOn, now),
    items: [
      for (final task in firstDaysTasksFor(pet.species))
        FirstDaysItem(
          task: task,
          ticked: path.doneTasks.contains(task.id),
          autoDone: task.auto != null && facts.meets(task.auto!, path.arrivedOn),
        ),
    ],
  );
}
