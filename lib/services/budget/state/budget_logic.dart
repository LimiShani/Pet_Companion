import '../../../utils/calendar.dart';
import '../../pet_records/costs.dart';
import '../data/budget_models.dart';

/// Where a line of the budget comes from.
enum EntrySource { manual, basket, health }

/// One payment in a month: an expense (or one month's payment of a
/// recurring one), or a cost entered on a health record.
class BudgetEntry {
  const BudgetEntry({
    required this.date,
    required this.amount,
    required this.currency,
    required this.category,
    required this.title,
    required this.petId,
    required this.source,
    this.expense,
    this.healthCost,
  });

  final DateTime date;
  final double amount;
  final String currency;
  final ExpenseCategory category;

  /// The owner's note, the product's name or the health record's title;
  /// empty when there is none (the screen then names the category).
  final String title;

  /// `null`: the whole home.
  final String? petId;
  final EntrySource source;

  /// The stored expense, for manual and basket lines.
  final Expense? expense;
  final HealthCost? healthCost;

  bool get isEditable => expense != null;
}

/// Everything the budget page shows for one month and one choice of pet.
class BudgetMonth {
  const BudgetMonth({
    required this.month,
    required this.currency,
    required this.total,
    required this.previousTotal,
    required this.average,
    required this.byCategory,
    required this.entries,
    this.healthMissing = false,
  });

  /// The first day of the month.
  final DateTime month;
  final String currency;
  final double total;
  final double previousTotal;

  /// The monthly average over the last twelve months up to this one (fewer
  /// when the data starts later); a yearly expense counts as 1/12 of its
  /// amount in every month.
  final double average;

  /// Only the categories with an amount, largest first.
  final Map<ExpenseCategory, double> byCategory;

  /// Newest first.
  final List<BudgetEntry> entries;

  /// Health's costs could not be loaded, so they are not in the numbers.
  final bool healthMissing;

  bool get isEmpty => entries.isEmpty;

  /// How much more (or less, negative) than the month before, in whole
  /// percent; `null` when the month before had nothing to compare with.
  int? get change => previousTotal <= 0
      ? null
      : ((total - previousTotal) / previousTotal * 100).round();

  /// The month before [month].
  DateTime get previousMonth => DateTime(month.year, month.month - 1);
}

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// [month] moved by [months] months.
DateTime addMonths(DateTime month, int months) =>
    DateTime(month.year, month.month + months);

int _daysIn(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _day(int year, int month, int day) =>
    DateTime(year, month, day.clamp(1, _daysIn(year, month)));

/// The day [expense] is paid in [month] (any day of it), or `null` when it
/// is not paid in that month.
///
/// A one-off expense is paid on its date. A recurring one is paid on its
/// date, then on the same day of every later month (every month) or of the
/// same month of every later year (every year); the 31st falls on the
/// last day of a shorter month. A later payment counts only once its day
/// has come ([today]) and only up to the day it was stopped
/// ([Expense.endedOn]).
DateTime? paymentIn(Expense expense, DateTime month, DateTime today) {
  final start = DateTime(
    expense.spentOn.year,
    expense.spentOn.month,
    expense.spentOn.day,
  );
  final m = monthOf(month);
  final first = monthOf(start);
  if (m.isBefore(first)) return null;
  if (m == first) return start;
  final DateTime date;
  switch (expense.frequency) {
    case ExpenseFrequency.once:
      return null;
    case ExpenseFrequency.monthly:
      date = _day(m.year, m.month, start.day);
    case ExpenseFrequency.yearly:
      if (m.month != start.month) return null;
      date = _day(m.year, m.month, start.day);
  }
  if (daysBetween(today, date) > 0) return null;
  final end = expense.endedOn;
  if (end != null && daysBetween(end, date) > 0) return null;
  return date;
}

bool _forPet(String? entryPet, String? petId) =>
    petId == null || entryPet == petId;

/// The lines of [month]: the payments of [expenses] in it and the health
/// costs dated in it, of [currency] only, for one pet ([petId]) or for the
/// whole home (`null`: every pet and what belongs to no pet). Newest first.
List<BudgetEntry> entriesOf({
  required List<Expense> expenses,
  required List<HealthCost> health,
  required DateTime month,
  required DateTime today,
  required String currency,
  String? petId,
}) {
  final m = monthOf(month);
  final entries = <BudgetEntry>[
    for (final e in expenses)
      if (e.currency == currency && _forPet(e.petId, petId))
        if (paymentIn(e, m, today) case final date?)
          BudgetEntry(
            date: date,
            amount: e.amount,
            currency: e.currency,
            category: e.category,
            title: e.note,
            petId: e.petId,
            source: e.source == ExpenseSource.basket
                ? EntrySource.basket
                : EntrySource.manual,
            expense: e,
          ),
    for (final c in health)
      if (c.currency == currency &&
          _forPet(c.petId, petId) &&
          monthOf(c.date) == m)
        BudgetEntry(
          date: c.date,
          amount: c.amount,
          currency: c.currency,
          category: ExpenseCategory.vet,
          title: c.title,
          petId: c.petId,
          source: EntrySource.health,
          healthCost: c,
        ),
  ];
  entries.sort((a, b) {
    final byDate = DateTime(
      b.date.year,
      b.date.month,
      b.date.day,
    ).compareTo(DateTime(a.date.year, a.date.month, a.date.day));
    return byDate != 0 ? byDate : a.title.compareTo(b.title);
  });
  return entries;
}

/// Adds in whole cents, so 0.1 + 0.2 stays 0.3.
double sumOf(Iterable<double> amounts) =>
    amounts.fold(0, (sum, a) => sum + (a * 100).round()) / 100;

/// The budget of [month]; see [BudgetMonth].
BudgetMonth budgetMonth({
  required List<Expense> expenses,
  required List<HealthCost> health,
  required DateTime month,
  required DateTime today,
  required String currency,
  String? petId,
  bool healthMissing = false,
}) {
  final m = monthOf(month);
  List<BudgetEntry> linesOf(DateTime month) => entriesOf(
    expenses: expenses,
    health: health,
    month: month,
    today: today,
    currency: currency,
    petId: petId,
  );

  final entries = linesOf(m);
  final previous = linesOf(addMonths(m, -1));

  final categories = <ExpenseCategory, double>{};
  for (final category in ExpenseCategory.values) {
    final amount = sumOf(
      entries.where((e) => e.category == category).map((e) => e.amount),
    );
    if (amount > 0) categories[category] = amount;
  }
  final byCategory = Map.fromEntries(
    categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );

  return BudgetMonth(
    month: m,
    currency: currency,
    total: sumOf(entries.map((e) => e.amount)),
    previousTotal: sumOf(previous.map((e) => e.amount)),
    average: monthlyAverage(
      expenses: expenses,
      health: health,
      month: m,
      today: today,
      currency: currency,
      petId: petId,
    ),
    byCategory: byCategory,
    entries: entries,
    healthMissing: healthMissing,
  );
}

/// What a month costs on average, up to and including [month].
///
/// The window is the last twelve months, or fewer when the first expense
/// or health cost is more recent. Every payment in the window counts once,
/// except a yearly expense's: a yearly expense still running in [month]
/// counts as 1/12 of its amount instead, so a ₪600 insurance adds ₪50 to
/// every month rather than ₪600 to one of them.
double monthlyAverage({
  required List<Expense> expenses,
  required List<HealthCost> health,
  required DateTime month,
  required DateTime today,
  required String currency,
  String? petId,
}) {
  final m = monthOf(month);
  final starts = [
    for (final e in expenses)
      if (e.currency == currency && _forPet(e.petId, petId)) monthOf(e.spentOn),
    for (final c in health)
      if (c.currency == currency && _forPet(c.petId, petId)) monthOf(c.date),
  ].where((start) => !start.isAfter(m)).toList();
  if (starts.isEmpty) return 0;
  final earliest = starts.reduce((a, b) => a.isBefore(b) ? a : b);
  final windowStart = [
    addMonths(m, -11),
    earliest,
  ].reduce((a, b) => a.isAfter(b) ? a : b);
  final months =
      (m.year - windowStart.year) * 12 + m.month - windowStart.month + 1;

  final spread = <double>[];
  for (var i = 0; i < months; i++) {
    final lines = entriesOf(
      expenses: expenses,
      health: health,
      month: addMonths(windowStart, i),
      today: today,
      currency: currency,
      petId: petId,
    );
    spread.addAll([
      for (final line in lines)
        if (line.expense?.frequency != ExpenseFrequency.yearly) line.amount,
    ]);
  }
  final monthEnd = addDays(addMonths(m, 1), -1);
  final yearly = [
    for (final e in expenses)
      if (e.frequency == ExpenseFrequency.yearly &&
          e.currency == currency &&
          _forPet(e.petId, petId) &&
          !e.spentOn.isAfter(monthEnd) &&
          (e.endedOn == null || !e.endedOn!.isBefore(m)))
        e.amount / 12,
  ];
  return ((sumOf(spread) / months + yearly.fold(0.0, (a, b) => a + b)) * 100)
          .round() /
      100;
}
