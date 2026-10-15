import '../../models/pet.dart';
import '../budget/state/basket_logic.dart';
import '../care/data/care_models.dart';
import '../firstdays/state/first_days_logic.dart';
import '../household/data/household_models.dart';
import '../pet_records/data/health_models.dart';
import '../pet_records/state/schedule_logic.dart';
import '../pets/state/pet_completeness.dart';

/// What a row of Home's Today list is about. The order of the values is
/// the order of the undated rows.
enum TodayKind {
  /// A planned meal (a feeding routine).
  meal,

  /// A planned walk, or play for a pet that does not go for walks.
  walk,

  /// Any other care routine: grooming, cleaning, the litter box...
  routine,

  /// A medicine reminder.
  dose,

  /// A basket product that runs out soon (or already did).
  runsOut,

  /// The next step of a pet's first 30 days.
  firstDays,

  /// A pet whose essentials are still missing.
  essentials,
}

/// A done row can be ticked off again for this long after it was logged.
const todayUndoWindow = Duration(hours: 1);

/// More done rows than this fold into one "N done" row.
const todayFoldAfter = 5;

/// A tick on a walk records this many minutes: a plan item has no length,
/// and this is what the walk sheet starts on.
const todayWalkMinutes = 30;

/// One row of the Today list.
class TodayItem {
  const TodayItem({
    required this.id,
    required this.kind,
    required this.petId,
    this.title = '',
    this.time,
    this.entry,
    this.doneBy,
    this.doneByMe = true,
    this.portionGrams,
    this.portionCalories,
    this.line,
    this.firstDays,
    this.essentials,
  });

  /// Unique within the day (also the row's key).
  final String id;
  final TodayKind kind;

  /// The pet it is for; empty for a basket product of the whole home.
  final String petId;

  /// The plan item's or the product's name, as the owner typed it. Empty
  /// for the first days and the essentials rows, which word themselves.
  final String title;

  /// When it is due today; `null` for the undated rows (runs out, first
  /// days, essentials).
  final DateTime? time;

  /// Today's occurrence of a meal, walk, routine or medicine reminder, with
  /// its answer once there is one.
  final ScheduleEntry? entry;

  /// Who answered it, when that was somebody else: their name (empty when
  /// unknown). `null` when it was the signed-in account, or not answered.
  final String? doneBy;

  /// The answer was the signed-in account's.
  final bool doneByMe;

  /// What a tick on a meal logs: the usual portion and its calories.
  final double? portionGrams;
  final int? portionCalories;

  final BasketLine? line;
  final FirstDaysView? firstDays;
  final PetCompleteness? essentials;

  CareLog? get log => entry?.log;

  /// A row with a tick (a meal, walk, routine or dose); the others only
  /// open a page.
  bool get isTickable => entry != null;
  bool get isDated => time != null;
  bool get isDone => log != null;

  /// Answered, but not as done ("Not eaten", "Not given").
  bool get isSkipped => log != null && log!.status != CareLogStatus.done;

  /// When it was done (or answered).
  DateTime? get doneAt => log?.doneAt ?? log?.loggedAt;

  bool isOverdue(DateTime now) => !isDone && time != null && time!.isBefore(now);

  /// A tick on the done row takes the answer back: only the account's own
  /// answer, and only within [todayUndoWindow] of logging it.
  bool canUndo(DateTime now) {
    final logged = log?.loggedAt;
    if (logged == null || !doneByMe) return false;
    return now.difference(logged) < todayUndoWindow;
  }
}

/// How many of today's tickable rows are answered, of how many.
({int done, int total}) todayProgress(Iterable<TodayItem> items) {
  var done = 0;
  var total = 0;
  for (final item in items) {
    if (!item.isTickable) continue;
    total++;
    if (item.isDone) done++;
  }
  return (done: done, total: total);
}

/// Whether [doneCount] done rows fold into one "N done" row.
bool todayFoldsDone(int doneCount) => doneCount > todayFoldAfter;

/// Who answered [log]: `(null, true)` for the signed-in account [me] (and
/// for a log that names no account: stored before households, or on a
/// backend without them), else the member's name as the household knows it
/// now, or the name stored with the log.
(String?, bool) todayWhoDid(
  CareLog log,
  String? me,
  List<HouseholdMember> carers,
) {
  final by = log.loggedBy;
  if (by == null || by == me) return (null, true);
  for (final member in carers) {
    if (member.userId == by && member.name.trim().isNotEmpty) {
      return (member.name.trim(), false);
    }
  }
  return (log.loggedByName.trim(), false);
}

TodayKind _kindOf(CarePlanItem item) {
  if (item.isMedication) return TodayKind.dose;
  return switch (item.kind) {
    CareKind.feeding => TodayKind.meal,
    CareKind.walk => TodayKind.walk,
    _ => TodayKind.routine,
  };
}

/// Today's rows for every pet in [pets], in the order of the list.
///
/// [plans] holds each pet's care plan (meals, walks, routines and
/// medicine reminders); [settings] its food, for what a meal tick logs.
/// [low] is the basket's running-low products, [firstDays] each pet's
/// first 30 days, [essentials] what each pet's profile is missing; any of
/// them may lack a pet that is still loading or not allowed.
List<TodayItem> todayItems({
  required List<Pet> pets,
  required Map<String, CarePlan> plans,
  required DateTime now,
  Map<String, CareSettings> settings = const {},
  List<BasketLine> low = const [],
  Map<String, FirstDaysView?> firstDays = const {},
  Map<String, PetCompleteness> essentials = const {},
  String? me,
  Map<String, List<HouseholdMember>> carers = const {},
}) {
  final ids = {for (final pet in pets) pet.id};
  final items = <TodayItem>[];
  for (final pet in pets) {
    final plan = plans[pet.id];
    if (plan == null) continue;
    final food = settings[pet.id];
    for (final entry in entriesOn(plan, now)) {
      final kind = _kindOf(entry.item);
      final log = entry.log;
      final (doneBy, byMe) = log == null
          ? (null, true)
          : todayWhoDid(log, me, carers[pet.id] ?? const []);
      final grams = kind == TodayKind.meal ? food?.portionGrams : null;
      items.add(
        TodayItem(
          id: '${pet.id}:${entry.item.id}',
          kind: kind,
          petId: pet.id,
          title: entry.item.title,
          time: entry.due,
          entry: entry,
          doneBy: doneBy,
          doneByMe: byMe,
          portionGrams: grams,
          portionCalories: grams == null ? null : food?.caloriesOf(grams),
        ),
      );
    }
  }
  for (final line in low) {
    final petId = line.item.petId;
    if (petId.isNotEmpty && !ids.contains(petId)) continue;
    items.add(
      TodayItem(
        id: 'basket:${line.item.id}',
        kind: TodayKind.runsOut,
        petId: petId,
        title: line.item.name,
        line: line,
      ),
    );
  }
  for (final pet in pets) {
    final view = firstDays[pet.id];
    if (view != null && view.isRunning && view.next != null) {
      items.add(
        TodayItem(
          id: 'firstdays:${pet.id}',
          kind: TodayKind.firstDays,
          petId: pet.id,
          firstDays: view,
        ),
      );
    }
    final info = essentials[pet.id];
    if (info != null && info.shouldRemind && info.next != null) {
      items.add(
        TodayItem(
          id: 'essentials:${pet.id}',
          kind: TodayKind.essentials,
          petId: pet.id,
          essentials: info,
        ),
      );
    }
  }
  return orderToday(items, petOrder: [for (final pet in pets) pet.id]);
}

/// [items] in the order of the list: what is still to do and has a time,
/// earliest first (so whatever is overdue comes first); then the undated
/// rows (runs out, first days, essentials); then what is done, by time.
/// Ties go by the pets' order ([petOrder]) and then by title.
List<TodayItem> orderToday(
  Iterable<TodayItem> items, {
  List<String> petOrder = const [],
}) {
  int group(TodayItem item) => item.isDone
      ? 2
      : item.isDated
      ? 0
      : 1;
  int petIndex(TodayItem item) {
    final i = petOrder.indexOf(item.petId);
    return i < 0 ? petOrder.length : i;
  }

  int compare(TodayItem a, TodayItem b) {
    final byGroup = group(a).compareTo(group(b));
    if (byGroup != 0) return byGroup;
    final at = a.time;
    final bt = b.time;
    if (at != null && bt != null) {
      final byTime = at.compareTo(bt);
      if (byTime != 0) return byTime;
    } else if (at != null || bt != null) {
      return at == null ? 1 : -1;
    } else {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      final days = (a.line?.daysLeft ?? 0).compareTo(b.line?.daysLeft ?? 0);
      if (days != 0) return days;
    }
    final byPet = petIndex(a).compareTo(petIndex(b));
    if (byPet != 0) return byPet;
    final byTitle = a.title.compareTo(b.title);
    return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
  }

  // A stable sort: equal rows keep the order they came in.
  final indexed = items.toList().asMap().entries.toList()
    ..sort((a, b) {
      final c = compare(a.value, b.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}
