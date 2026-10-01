/// Arithmetic on calendar days.
///
/// A local day is not always 24 hours long: on the days the clocks change
/// it has 23 or 25. Adding or subtracting whole-day [Duration]s to a local
/// midnight, or counting a gap between two dates in elapsed hours, then
/// lands on the wrong date. These work on the dates themselves.
library;

/// Midnight of the day [days] calendar days after [day] (before it, when
/// negative), whatever the clock does in between.
DateTime addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

/// How many calendar days [to] is after [from]: 1 for the next day, -1 for
/// the day before, 0 for the same day. The times of day do not count.
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
