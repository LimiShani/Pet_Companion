import '../../health/data/health_models.dart';
import 'care_models.dart';

/// Where a pet's food and daily goals are kept. The meals and walks
/// themselves are Health's care log (`CarePlanController.record`), so that
/// Home and the Health schedule always agree.
///
/// Failures are [HealthException]s, worded on screen by `healthErrorOf`.
abstract class CareRepository {
  /// The pet's settings; an empty `CareSettings(petId: petId)` when the
  /// owner set nothing yet.
  Future<CareSettings> fetchSettings(String petId);

  /// Stores [settings] and returns what is stored.
  Future<CareSettings> saveSettings(CareSettings settings);
}

/// In memory, for the demo and the tests. Seeded with Kelly's food.
class FakeCareRepository implements CareRepository {
  FakeCareRepository({this.latency = const Duration(milliseconds: 300), bool seeded = true}) {
    if (seeded) {
      _settings['kelly'] = const CareSettings(
        petId: 'kelly',
        foodName: 'Adult dry food',
        kcalPer100g: 360,
        gramsPerCup: 100,
        portionGrams: 140,
      );
    }
  }

  final Duration latency;
  final _settings = <String, CareSettings>{};

  Future<void> _wait() => Future<void>.delayed(latency);

  @override
  Future<CareSettings> fetchSettings(String petId) async {
    await _wait();
    return _settings[petId] ?? CareSettings(petId: petId);
  }

  @override
  Future<CareSettings> saveSettings(CareSettings settings) async {
    await _wait();
    return _settings[settings.petId] = settings;
  }
}
