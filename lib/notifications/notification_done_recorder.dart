import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../services/care/state/care_providers.dart';
import '../services/pet_records/data/health_models.dart';
import '../services/pet_records/state/health_providers.dart';
import '../state/pets_provider.dart';
import 'notification_done.dart';
import 'notification_platform.dart';
import 'notifications.dart' show notificationPlatformProvider;

/// Where "Done" presses wait to be recorded. In memory unless `main.dart`
/// sets the phone's preferences (tests and the web never have a press
/// from the background).
final notificationDoneQueueProvider = Provider<DoneQueue>(
  (ref) => DoneQueue(MemoryDoneQueueStore()),
);

/// How long a walk recorded with "Done" lasted: the walk sheet's own
/// default, since a planned walk has no length of its own.
const doneWalkMinutes = 30;

/// What became of one "Done".
enum DoneOutcome {
  /// Logged now.
  recorded,

  /// The occurrence already had an answer (ticked in the app first, or
  /// recorded from this notification before): nothing is logged twice.
  alreadyAnswered,

  /// The pet, the item or that day's occurrence no longer exists.
  gone,

  /// Pressed more than [DoneQueue.maxAge] ago.
  expired,

  /// Not stored (offline, no access): tried again at the next flush.
  failed,
}

/// Records the "Done" presses of reminder notifications as the app's own
/// tick would, as the signed-in account:
///
/// - a meal: the planned meal with the usual portion (and its calories),
///   like "Fed" on Home;
/// - a walk: the planned walk, [walkMinutes] long;
/// - a medicine time: the dose given at the moment of the press, like
///   "Given now" in the Record dose sheet;
/// - any other routine: done.
///
/// Every press goes through the [DoneQueue] first ([handle]) and is
/// recorded by [flush], which runs once the account and its pets are
/// loaded: at start-up before the reminders are planned again (the
/// `ReminderCoordinator` waits for it), when the app comes back, and at
/// once for a press while the app runs. Each is recorded with the moment
/// it was pressed. A press older than [DoneQueue.maxAge], for a pet or an
/// item that is gone, or for an occurrence that already has an answer in
/// the day's log is dropped without logging. Afterwards the reminder of
/// that occurrence and its "In 15 min" copy are cancelled; the plan, now
/// answered, plans no other.
class NotificationDoneRecorder {
  NotificationDoneRecorder(
    this._container, {
    DateTime Function() now = DateTime.now,
    this.walkMinutes = doneWalkMinutes,
  }) : _now = now;

  final ProviderContainer _container;
  final DateTime Function() _now;
  final int walkMinutes;

  /// Presses of this run, in case the queue could not keep them.
  final _inMemory = <String, DoneAction>{};

  Future<void> _done = Future.value();
  Future<void>? _queued;

  DoneQueue get _queue => _container.read(notificationDoneQueueProvider);

  /// "Done" pressed: kept, then recorded as soon as the app can.
  Future<void> handle(DoneAction action) async {
    _inMemory[action.occurrenceKey] = action;
    try {
      await _queue.add(action);
    } catch (error) {
      debugPrint('PetLoop: could not keep a "Done": $error');
    }
    return flush();
  }

  /// Records what waits; does nothing until the account and its pets are
  /// loaded. Calls made while a pass runs make one more pass after it.
  Future<void> flush() => _queued ??= _run(() {
    _queued = null;
    return _flush();
  });

  Future<void> _run(Future<void> Function() task) {
    final next = _done.then((_) => task()).catchError((Object error) {
      debugPrint('PetLoop: could not record a "Done": $error');
    });
    _done = next;
    return next;
  }

  bool get _ready {
    final auth = _container.read(authControllerProvider);
    return !auth.isLoading &&
        !auth.hasError &&
        auth.value != null &&
        _container.read(petsGateProvider) == PetsGate.ready;
  }

  Future<void> _flush() async {
    if (!_ready) return;
    final queue = _queue;
    final pending = <String, DoneAction>{
      for (final action in await queue.pending()) action.occurrenceKey: action,
      ..._inMemory,
    };
    if (pending.isEmpty) return;
    final handled = await queue.handled();
    final pets = {for (final pet in _container.read(petsProvider)) pet.id};
    final actions = pending.values.toList()
      ..sort((a, b) => a.actedAt.compareTo(b.actedAt));
    for (final action in actions) {
      if (!_ready) return;
      final key = action.occurrenceKey;
      final now = _now();
      final outcome = now.difference(action.actedAt) > DoneQueue.maxAge
          ? DoneOutcome.expired
          : handled.containsKey(key)
          ? DoneOutcome.alreadyAnswered
          : !pets.contains(action.done.petId)
          ? DoneOutcome.gone
          : await _record(action);
      if (outcome == DoneOutcome.failed) continue;
      _inMemory.remove(key);
      await queue.remove(action);
      if (outcome == DoneOutcome.recorded) {
        handled[key] = now;
        await queue.markHandled(key, now);
      }
      if (outcome == DoneOutcome.recorded ||
          outcome == DoneOutcome.alreadyAnswered) {
        await _cancel(action);
      }
    }
  }

  Future<DoneOutcome> _record(DoneAction action) async {
    final done = action.done;
    final petId = done.petId;
    final plan = _container.listen(
      carePlanProvider(petId),
      (_, _) {},
      onError: (_, _) {},
    );
    ProviderSubscription<Object?>? settings;
    try {
      final care = await _container.read(carePlanProvider(petId).future);
      final day = dateOnly(done.dueOn);
      final item = care.items.where((i) => i.id == done.itemId).firstOrNull;
      if (item == null || !item.occursOn(day)) return DoneOutcome.gone;
      if (care.logs.any(
        (log) => log.planItemId == item.id && isSameDay(log.dueOn, day),
      )) {
        return DoneOutcome.alreadyAnswered;
      }
      final at = action.actedAt;
      // In the demo the plan lives on another day than the phone.
      final doneAt = DateTime(
        at.year,
        at.month,
        at.day - done.shiftDays,
        at.hour,
        at.minute,
        at.second,
      );
      double? grams;
      int? calories;
      int? minutes;
      if (item.medicationId == null && item.kind == CareKind.feeding) {
        settings = _container.listen(
          careSettingsProvider(petId),
          (_, _) {},
          onError: (_, _) {},
        );
        final food = await _container.read(careSettingsProvider(petId).future);
        grams = food.portionGrams;
        calories = grams == null ? null : food.caloriesOf(grams);
      } else if (item.medicationId == null && item.kind == CareKind.walk) {
        minutes = walkMinutes;
      }
      await _container
          .read(carePlanProvider(petId).notifier)
          .record(
            item: item,
            dueOn: day,
            status: CareLogStatus.done,
            doneAt: doneAt,
            amountGrams: grams,
            calories: calories,
            minutes: minutes,
          );
      return DoneOutcome.recorded;
    } catch (error) {
      debugPrint('PetLoop: could not record a "Done": $error');
      return DoneOutcome.failed;
    } finally {
      plan.close();
      settings?.close();
    }
  }

  /// Takes the reminder of the occurrence off the phone, with its "In 15
  /// min" copy.
  Future<void> _cancel(DoneAction action) async {
    final platform = _container.read(notificationPlatformProvider);
    if (platform == null || action.group.isEmpty || action.key.isEmpty) return;
    try {
      await platform.cancel(notificationIdOf(action.group, action.key));
      await platform.cancel(
        notificationIdOf(action.group, action.key, snoozed: true),
      );
    } catch (error) {
      debugPrint('PetLoop: could not cancel a reminder: $error');
    }
  }
}
