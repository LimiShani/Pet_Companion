import 'dart:typed_data';

import '../../../models/pet.dart';
import 'pets_repository.dart';
import 'sample_pets.dart';

/// In-memory pets for development and tests. Nothing persists across
/// restarts.
///
/// The demo account (and an app with nobody signed in, so screens pumped on
/// their own keep working) owns the sample pets Kelly and Soya; every other
/// account starts with none, like a new account on the real backend.
class FakePetsRepository implements PetsRepository {
  FakePetsRepository({
    this.latency = const Duration(milliseconds: 300),
    this.instant = true,
    bool seeded = true,
  }) {
    if (seeded) _pets[demoOwner] = samplePets();
  }

  /// The id of the seeded demo account (see `FakeAuthRepository`).
  static const demoOwner = 'demo';

  /// Simulated network delay so loading states are visible.
  final Duration latency;

  /// With `true` the pets are at hand at once ([cachedPets]); with `false`
  /// they have to be fetched like on a real backend.
  final bool instant;

  /// When set, every call fails with this message (to test error states).
  String? failure;

  final _pets = <String, List<Pet>>{};
  final _photos = <String, Uint8List>{};
  int _photoCount = 0;

  /// The photos currently stored, by path (for tests).
  Map<String, Uint8List> get photos => Map.unmodifiable(_photos);

  // No timer at all at zero latency, so widget tests leave none pending.
  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final message = failure;
    if (message != null) throw PetsException(message);
  }

  List<Pet> _of(String? ownerId) => _pets.putIfAbsent(ownerId ?? demoOwner, () => []);

  @override
  List<Pet>? cachedPets(String? ownerId) => instant ? List.of(_of(ownerId)) : null;

  @override
  Future<List<Pet>> fetchPets(String ownerId) async {
    await _wait();
    return List.of(_of(ownerId));
  }

  @override
  Future<Pet> savePet(String ownerId, Pet pet) async {
    await _wait();
    if (pet.name.trim().isEmpty) throw PetsException.of(PetsFailure.nameMissing);
    final pets = _of(ownerId);
    final index = pets.indexWhere((p) => p.id == pet.id);
    if (index < 0) {
      pets.add(pet);
    } else {
      pets[index] = pet;
    }
    return pet;
  }

  @override
  Future<void> deletePet(String ownerId, Pet pet) async {
    await _wait();
    _of(ownerId).removeWhere((p) => p.id == pet.id);
    _photos.removeWhere((path, _) => path.startsWith('$ownerId/${pet.id}/'));
  }

  @override
  Future<String> uploadPhoto(String ownerId, String petId, Uint8List jpeg) async {
    await _wait();
    final path = '$ownerId/$petId/avatar_${++_photoCount}.jpg';
    _photos[path] = jpeg;
    return path;
  }

  @override
  Future<void> deletePhoto(String path) async {
    await _wait();
    _photos.remove(path);
  }

  @override
  Future<PetPhotoData> loadPhoto(String path) async {
    await _wait();
    final bytes = _photos[path];
    if (bytes == null) throw PetsException.of(PetsFailure.photoGone);
    return PetPhotoData.bytes(bytes);
  }
}
