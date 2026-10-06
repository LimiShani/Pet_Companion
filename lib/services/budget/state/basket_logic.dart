import '../../../notifications/notification_sink.dart';
import '../../care/data/care_models.dart';
import '../../pet_records/data/health_models.dart';
import '../../pet_records/state/schedule_logic.dart' show CarePlan;
import '../data/budget_models.dart';

/// How fast a pet eats, from its feeding page: the usual portion times the
/// meals a day.
class FeedingRate {
  const FeedingRate({required this.portionGrams, required this.mealsPerDay});

  final double portionGrams;

  /// The active feeding routines per day, on average over a week: 2 for
  /// breakfast and dinner every day; a routine on weekends only adds 2/7.
  final double mealsPerDay;

  double get gramsPerDay => portionGrams * mealsPerDay;
}

/// The pet's [FeedingRate], or `null` while the portion or the meal times
/// are not set.
///
/// The meals are the feeding routines of the care plan that are active on
/// [today]: one that runs every day counts 1, one that runs on some
/// weekdays counts its share of the week.
FeedingRate? feedingRateOf({
  required CarePlan plan,
  required CareSettings settings,
  required DateTime today,
}) {
  final portion = settings.portionGrams;
  if (portion == null || portion <= 0) return null;
  final day = dateOnly(today);
  var weekly = 0;
  for (final item in plan.items) {
    if (item.kind != CareKind.feeding || !item.active) continue;
    final end = item.endsOn;
    if (end != null && dateOnly(end).isBefore(day)) continue;
    weekly += item.days.length;
  }
  if (weekly == 0) return null;
  return FeedingRate(portionGrams: portion, mealsPerDay: weekly / 7);
}

/// Who said how long a package lasts.
enum LastsBy {
  /// The owner's own "lasts about N days".
  owner,

  /// Worked out from the pet's feeding.
  feeding,

  /// Nobody: no run-out date.
  unknown,
}

/// A basket product with how long it lasts and when it runs out.
class BasketLine {
  const BasketLine({
    required this.item,
    required this.lastsDays,
    required this.by,
    required this.runsOutOn,
    required this.daysLeft,
    this.rate,
  });

  final BasketItem item;
  final int? lastsDays;
  final LastsBy by;

  /// The feeding the run-out date is worked out from ([LastsBy.feeding]).
  final FeedingRate? rate;

  /// `null` without a purchase date or without [lastsDays].
  final DateTime? runsOutOn;

  /// Days from today to [runsOutOn]: 0 today, negative once it ran out.
  final int? daysLeft;

  /// What is left of the package, 0..1, or `null` when unknown.
  double? get left {
    final lasts = lastsDays;
    final days = daysLeft;
    if (lasts == null || days == null || lasts <= 0) return null;
    return (days / lasts).clamp(0.0, 1.0);
  }

  /// Runs out within [runningLowDays] days (or already has).
  bool get isLow => daysLeft != null && daysLeft! <= runningLowDays;
}

/// "Running low" means running out within this many days.
const runningLowDays = 7;

/// The reminder comes this many days before a product runs out.
const reminderDaysBefore = 5;

/// The hour of the day the reminder comes.
const reminderHour = 10;

/// [item] with its run-out date on [today]. [rate] is its pet's feeding,
/// used for food when the owner did not say how long a package lasts and
/// the package size is a weight.
BasketLine basketLine(
  BasketItem item, {
  FeedingRate? rate,
  required DateTime today,
}) {
  int? lasts = item.lastsDays;
  var by = lasts == null ? LastsBy.unknown : LastsBy.owner;
  FeedingRate? usedRate;
  if (lasts == null &&
      item.kind == BasketKind.food &&
      rate != null &&
      rate.gramsPerDay > 0) {
    final grams = item.unit.grams(item.packageSize);
    if (grams != null) {
      lasts = (grams / rate.gramsPerDay).floor();
      by = LastsBy.feeding;
      usedRate = rate;
    }
  }
  final bought = item.lastBoughtOn;
  final runsOut = bought == null || lasts == null
      ? null
      : addDays(dateOnly(bought), lasts);
  return BasketLine(
    item: item,
    lastsDays: lasts,
    by: by,
    rate: usedRate,
    runsOutOn: runsOut,
    daysLeft: runsOut == null ? null : daysBetween(today, runsOut),
  );
}

/// The products running low, soonest first.
List<BasketLine> runningLow(Iterable<BasketLine> lines) =>
    lines.where((l) => l.isLow).toList()
      ..sort((a, b) => a.daysLeft!.compareTo(b.daysLeft!));

/// The reminders of one pet's basket: [reminderDaysBefore] days before
/// each product runs out, at [reminderHour]:00, for the ones still ahead of
/// [now] (the real clock). [title] and [body] put a line into words.
List<PlannedNotification> basketReminders({
  required String petId,
  required Iterable<BasketLine> lines,
  required DateTime now,
  required String Function(BasketLine line) title,
  required String Function(BasketLine line) body,
}) {
  final reminders = <PlannedNotification>[];
  for (final line in lines) {
    final runsOut = line.runsOutOn;
    if (runsOut == null || line.item.petId != petId) continue;
    final day = addDays(runsOut, -reminderDaysBefore);
    final at = DateTime(day.year, day.month, day.day, reminderHour);
    if (!at.isAfter(now)) continue;
    reminders.add(
      PlannedNotification(
        key:
            '${line.item.id}@${runsOut.year}-${runsOut.month.toString().padLeft(2, '0')}-${runsOut.day.toString().padLeft(2, '0')}',
        kind: NotificationKind.basket,
        at: at,
        title: title(line),
        body: body(line),
        payload: basketPayload(petId),
      ),
    );
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders;
}

/// The notification group of a pet's basket reminders.
String basketGroup(String petId) => 'basket:$petId';

/// What tapping a basket reminder opens: the Store's "My basket".
String basketPayload(String petId) => 'basket:$petId';
