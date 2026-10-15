import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../access/access_provider.dart';
import '../../auth/auth_controller.dart';
import '../../platform/usage.dart';
import '../../state/pets_provider.dart';
import '../budget/state/basket_logic.dart';
import '../budget/state/budget_providers.dart';
import '../care/data/care_models.dart';
import '../care/state/care_providers.dart';
import '../firstdays/state/first_days_logic.dart';
import '../firstdays/state/first_days_providers.dart';
import '../household/data/household_models.dart';
import '../household/state/household_providers.dart';
import '../pet_records/data/health_models.dart';
import '../pet_records/state/health_providers.dart';
import '../pet_records/state/schedule_logic.dart';
import '../pets/state/pet_completeness.dart';
import 'today_logic.dart';

export 'today_logic.dart';

/// Home's Today list: every pet's rows of the day, in order.
class TodayDay {
  const TodayDay({
    required this.now,
    required this.items,
    required this.petCount,
  });

  /// The moment the list was worked out (the health clock).
  final DateTime now;
  final List<TodayItem> items;

  /// How many pets the account has: a row names its pet only when there
  /// is more than one.
  final int petCount;

  bool get isEmpty => items.isEmpty;
}

/// Today's rows for all the account's pets (not only the one selected on
/// Home): the care plan's meals, walks, routines and medicine doses, the
/// basket products running low, the first 30 days' next step and the
/// essentials reminder.
///
/// Loading while any pet's care plan loads; failed when one failed (Home
/// offers to try again). The other sources add their rows once they have
/// them and leave them out when not allowed.
final todayProvider = Provider.autoDispose<AsyncValue<TodayDay>>((ref) {
  ref.watch(currentDayProvider);
  final now = ref.watch(healthClockProvider)();
  final me = ref.watch(authControllerProvider.select((a) => a.value?.id));
  final pets = [
    for (final pet in ref.watch(petsProvider))
      if (pet.id.isNotEmpty) pet,
  ];

  // Everything is watched before any early return, so it all loads
  // together rather than one source after the other.
  final plans = <String, CarePlan>{};
  AsyncValue<CarePlan>? failed;
  var loading = false;
  for (final pet in pets) {
    final value = ref.watch(carePlanProvider(pet.id));
    if (value.hasError) {
      failed ??= value;
    } else if (value.hasValue) {
      plans[pet.id] = value.requireValue;
    } else {
      loading = true;
    }
  }

  final settings = <String, CareSettings>{};
  final carers = <String, List<HouseholdMember>>{};
  final firstDays = <String, FirstDaysView?>{};
  final essentials = <String, PetCompleteness>{};
  final firstDaysAllowed = ref.watch(capabilityProvider('firstdays.view'));
  final petsAllowed = ref.watch(capabilityProvider('pets.view'));
  for (final pet in pets) {
    final food = ref.watch(careSettingsProvider(pet.id)).value;
    if (food != null) settings[pet.id] = food;
    carers[pet.id] = ref.watch(petCarersProvider(pet.id));
    if (firstDaysAllowed) {
      firstDays[pet.id] = ref.watch(firstDaysViewProvider(pet.id)).value;
    }
    if (petsAllowed) {
      essentials[pet.id] = ref.watch(petCompletenessProvider(pet.id));
    }
  }
  final low = ref.watch(capabilityProvider('basket.view'))
      ? ref.watch(runningLowProvider).value ?? const <BasketLine>[]
      : const <BasketLine>[];

  if (failed != null) {
    return AsyncError(failed.error!, failed.stackTrace ?? StackTrace.current);
  }
  if (loading) return const AsyncLoading();
  return AsyncData(
    TodayDay(
      now: now,
      petCount: pets.length,
      items: todayItems(
        pets: pets,
        plans: plans,
        now: now,
        settings: settings,
        low: low,
        firstDays: firstDays,
        essentials: essentials,
        me: me,
        carers: carers,
      ),
    ),
  );
});

/// Loads the care plans behind the Today list again after a failure.
void retryToday(WidgetRef ref) {
  for (final pet in ref.read(petsProvider)) {
    if (pet.id.isNotEmpty) ref.invalidate(carePlanProvider(pet.id));
  }
}

/// A Today tick, through the same paths as the rest of the app: a meal as
/// the feeding card's "Fed" (the planned meal, the usual portion), a walk
/// as the walk sheet (the planned walk, [todayWalkMinutes]), a routine as
/// the Schedule's tick, a dose as "Given now" in "Record dose". Undo takes
/// the answer back as the feeding page and the Schedule do.
///
/// Failures are the care plan's own (`HealthException`, `FeatureDenied`),
/// worded on screen by `healthErrorOf`.
class TodayController extends Notifier<void> {
  @override
  void build() {}

  Future<CareLog?> tick(TodayItem item) async {
    final entry = item.entry;
    if (entry == null || item.isDone) return null;
    final plan = ref.read(carePlanProvider(item.petId).notifier);
    final now = ref.read(healthClockProvider)();
    final log = await switch (item.kind) {
      TodayKind.meal => plan.record(
        item: entry.item,
        dueOn: entry.due,
        status: CareLogStatus.done,
        doneAt: now,
        amountGrams: item.portionGrams,
        calories: item.portionCalories,
      ),
      // The walk sheet's time: when it was planned, unless that is still
      // ahead.
      TodayKind.walk => plan.record(
        item: entry.item,
        dueOn: entry.due,
        status: CareLogStatus.done,
        doneAt: entry.due.isAfter(now) ? now : entry.due,
        minutes: todayWalkMinutes,
      ),
      TodayKind.dose => plan.record(
        item: entry.item,
        medication: entry.medication,
        dueOn: dateOnly(entry.due),
        status: CareLogStatus.done,
      ),
      TodayKind.routine => plan.record(
        item: entry.item,
        dueOn: entry.due,
        status: CareLogStatus.done,
      ),
      _ => Future<CareLog?>.value(),
    };
    if (log != null) ref.read(usageProvider).count(UsageKind.todayTick);
    return log;
  }

  /// Takes back the answer of a done row (see [TodayItem.canUndo]).
  Future<void> undo(TodayItem item) async {
    final log = item.log;
    if (log == null) return;
    await ref.read(carePlanProvider(item.petId).notifier).removeLog(log);
  }
}

final todayControllerProvider = NotifierProvider<TodayController, void>(
  TodayController.new,
);
