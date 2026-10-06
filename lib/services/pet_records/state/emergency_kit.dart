import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_models.dart';
import '../../../state/ordered_writes.dart';
import 'health_providers.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// The answers saved for a pet's emergency kit.
class KitController extends SessionSafeAsyncNotifier<List<KitCheck>> {
  KitController(this.petId);

  final String petId;
  final _writes = OrderedWrites();

  @override
  Future<List<KitCheck>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('health.emergency.view'))) {
      return const <KitCheck>[];
    }
    return ref.watch(emergencyRepositoryProvider).fetchKit(petId);
  }

  KitCheck _current(KitItem item) {
    for (final check in state.value ?? const <KitCheck>[]) {
      if (check.item == item) return check;
    }
    return KitCheck(petId: petId, item: item);
  }

  /// Shows [check] at once and stores it; puts the old answer back, and
  /// throws a [HealthException], when it cannot be stored.
  Future<void> _put(KitItem item, KitCheck Function(KitCheck) change) async {
    return sessionOperation(
      ref,
      () => _writes.run(item, () async {
        checkSession();
        requireCapability(ref, 'health.emergency.edit');
        final before = _current(item);
        final check = change(before);
        void replace(KitCheck value) {
          if (!ref.mounted) return;
          state = AsyncData([
            for (final c in state.value ?? const <KitCheck>[])
              if (c.item != value.item) c,
            value,
          ]);
        }

        replace(check);
        try {
          await ref.read(emergencyRepositoryProvider).saveKitCheck(check);
          checkSession();
        } catch (_) {
          checkSession();
          replace(before);
          rethrow;
        }
      }),
    );
  }

  /// Ticks [item] (remembering today) or clears the tick. The note stays.
  Future<void> setReady(KitItem item, bool ready) {
    return _put(
      item,
      (current) => KitCheck(
        petId: petId,
        item: item,
        checkedAt: ready ? ref.read(healthClockProvider)() : null,
        note: current.note,
      ),
    );
  }

  /// Saves the note of [item] (the plan for the protected room).
  Future<void> setNote(KitItem item, String note) {
    return _put(
      item,
      (current) => KitCheck(
        petId: petId,
        item: item,
        checkedAt: current.checkedAt,
        note: note.trim(),
      ),
    );
  }
}

final kitChecksProvider = AsyncNotifierProvider.autoDispose
    .family<KitController, List<KitCheck>, String>(
      KitController.new,
      retry: _noRetry,
    );

/// One line of a pet's kit as it is shown.
class KitEntry {
  const KitEntry({required this.item, this.checkedAt, this.note = ''});

  final KitItem item;
  final DateTime? checkedAt;
  final String note;

  bool get isReady => checkedAt != null;
}

/// A pet's emergency kit: the items that apply to it and what is ready.
class EmergencyKit {
  const EmergencyKit({
    required this.petId,
    required this.entries,
    this.medicines = const [],
  });

  final String petId;

  /// In the order of the checklist. "Medicines" is only among them while
  /// the pet has an active medicine.
  final List<KitEntry> entries;

  /// The active medicines the "Medicines" item is about.
  final List<Medication> medicines;

  int get total => entries.length;
  int get ready => entries.where((e) => e.isReady).length;
  bool get isComplete => ready == total;
}

/// A pet's emergency kit: how many items are ready out of how many.
///
/// Loading is `AsyncLoading`; a kit nobody touched is data with nothing
/// ready (never an error); it refreshes by itself when an item is ticked
/// or a medicine starts or ends.
final emergencyKitProvider = FutureProvider.autoDispose
    .family<EmergencyKit, String>((ref, petId) async {
      final checksFuture = ref.watch(kitChecksProvider(petId).future);
      final planFuture = ref.watch(carePlanProvider(petId).future);
      final now = ref.watch(healthClockProvider)();
      final checks = {
        for (final check in await checksFuture) check.item: check,
      };
      final medicines = (await planFuture).activeMedications(now);
      return EmergencyKit(
        petId: petId,
        medicines: medicines,
        entries: [
          for (final item in KitItem.values)
            if (item != KitItem.medicines || medicines.isNotEmpty)
              KitEntry(
                item: item,
                checkedAt: checks[item]?.checkedAt,
                note: checks[item]?.note ?? '',
              ),
        ],
      );
    }, retry: _noRetry);
