import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../pet_records/state/health_providers.dart';
import 'first_days_providers.dart';
import '../../../access/access_provider.dart';

class ArrivalController extends ChangeNotifier {
  ArrivalController({required DateTime today})
    : _day = DateTime(today.year, today.month, today.day);

  /// Starts on today by the app's clock (the sample data's day in the demo).
  factory ArrivalController.today(WidgetRef ref) =>
      ArrivalController(today: ref.read(healthClockProvider)());

  bool? _arrived;
  DateTime _day;

  /// The arrival day stored by the last [apply], or `null` when no path is
  /// stored from this flow.
  DateTime? _stored;

  /// `true` for "Yes", `false` for "No", `null` while not answered.
  bool? get arrived => _arrived;
  set arrived(bool? value) {
    _arrived = value;
    notifyListeners();
  }

  DateTime get day => _day;
  set day(DateTime value) {
    _day = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  /// Starts the first 30 days of the pet with [petId] when the answer is
  /// "Yes" (or moves it to a new day), and takes back the path started by
  /// an earlier [apply] when the answer is no longer "Yes". Throws a
  /// `HealthException` when it is not stored.
  Future<void> apply(WidgetRef ref, String petId) async {
    if (!ref.read(capabilityProvider('firstdays.edit'))) return;
    final wanted = _arrived == true ? _day : null;
    if (wanted == _stored) return;
    // Kept alive for the call: nothing may be showing it yet.
    final keep = ref.listenManual(firstDaysProvider(petId), (_, _) {});
    try {
      final paths = ref.read(firstDaysProvider(petId).notifier);
      if (wanted == null) {
        await paths.forget();
      } else {
        await paths.start(wanted);
      }
      _stored = wanted;
    } finally {
      keep.close();
    }
  }
}
