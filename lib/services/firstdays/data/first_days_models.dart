/// How long the path lasts: day 1 is the arrival day, day 30 the last one.
const firstDaysLength = 30;

/// A pet's "first 30 days" path: the day it arrived home, the tasks the
/// owner ticked by hand, and when the owner closed it early.
///
/// The tasks themselves are bundled with the app (see
/// `first_days_tasks.dart`); only the ids of the ticked ones are stored.
class FirstDaysPath {
  FirstDaysPath({
    required this.petId,
    required DateTime arrivedOn,
    this.closedAt,
    this.doneTasks = const {},
  }) : arrivedOn = DateTime(arrivedOn.year, arrivedOn.month, arrivedOn.day);

  final String petId;

  /// The arrival day (a date, no time).
  final DateTime arrivedOn;

  /// When the owner ended the path before day 30, or `null`.
  final DateTime? closedAt;

  /// Ids of the tasks ticked by hand.
  final Set<String> doneTasks;

  bool get isClosed => closedAt != null;

  /// A copy with [taskId] ticked ([done]) or not.
  FirstDaysPath withTask(String taskId, {required bool done}) => FirstDaysPath(
    petId: petId,
    arrivedOn: arrivedOn,
    closedAt: closedAt,
    doneTasks: {
      for (final id in doneTasks)
        if (id != taskId) id,
      if (done) taskId,
    },
  );

  /// The same path started again on [day] (open again, ticks kept).
  FirstDaysPath restartedOn(DateTime day) =>
      FirstDaysPath(petId: petId, arrivedOn: day, doneTasks: doneTasks);

  FirstDaysPath closed(DateTime at) => FirstDaysPath(
    petId: petId,
    arrivedOn: arrivedOn,
    closedAt: at,
    doneTasks: doneTasks,
  );
}

/// The day number of [now] on a path that started on [arrivedOn]: 1 on the
/// arrival day, 2 the day after... Counted in calendar days, so a change of
/// clocks (summer time) never skips or repeats a day. 0 or less before the
/// arrival.
int firstDaysDayNumber(DateTime arrivedOn, DateTime now) {
  final start = DateTime.utc(arrivedOn.year, arrivedOn.month, arrivedOn.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  return today.difference(start).inDays + 1;
}

/// The earliest arrival day the path accepts at [now]: far enough back
/// that today is still one of the 30 days.
DateTime earliestArrival(DateTime now) =>
    DateTime(now.year, now.month, now.day - (firstDaysLength - 1));
