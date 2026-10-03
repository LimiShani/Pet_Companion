import '../../health/data/health_models.dart';
import 'first_days_models.dart';

/// Where a pet's "first 30 days" path is kept: at most one per pet.
///
/// Failures are [HealthException]s, worded on screen by `healthErrorOf`,
/// like the rest of the pet's care data.
abstract class FirstDaysRepository {
  /// The pet's path, or `null` when none was ever started.
  Future<FirstDaysPath?> fetch(String petId);

  /// Stores [path] (creating or replacing the pet's one) and returns what
  /// is stored.
  Future<FirstDaysPath> save(FirstDaysPath path);

  /// Forgets the pet's path, as if it had never been started.
  Future<void> delete(String petId);
}

/// In memory, for the demo and the tests.
///
/// Seeded so the demo shows the Home card: Soya, the sample dog with
/// almost nothing filled in, arrived home on 1 June 2025 (the sample data
/// lives on 10 June, day 10) and two tasks are ticked.
class FakeFirstDaysRepository implements FirstDaysRepository {
  FakeFirstDaysRepository({this.latency = const Duration(milliseconds: 300), bool seeded = true}) {
    if (seeded) {
      _paths[soyaId] = FirstDaysPath(
        petId: soyaId,
        arrivedOn: DateTime(2025, 6, 1),
        doneTasks: const {'dog-rest-spot', 'dog-name-tag'},
      );
    }
  }

  static const soyaId = 'soya';

  final Duration latency;
  final _paths = <String, FirstDaysPath>{};

  /// Test hook: while true every call fails, as if the server were down.
  bool failing = false;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) throw HealthException.of(HealthFailure.offline);
  }

  @override
  Future<FirstDaysPath?> fetch(String petId) async {
    await _wait();
    return _paths[petId];
  }

  @override
  Future<FirstDaysPath> save(FirstDaysPath path) async {
    await _wait();
    return _paths[path.petId] = path;
  }

  @override
  Future<void> delete(String petId) async {
    await _wait();
    _paths.remove(petId);
  }
}
