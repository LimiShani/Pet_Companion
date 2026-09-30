import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../features/pets/data/pets_repository.dart';
import '../features/pets/data/pets_repository_provider.dart';
import '../models/pet.dart';

/// Where loading the owner's pets stands.
enum PetsStatus { loading, ready, failed }

/// Every pet of the signed-in owner, archived ones included.
class PetsState {
  PetsState({required this.status, this.all = const [], this.error})
      : visible = [
          for (final pet in all)
            if (!pet.isArchived) pet,
        ],
        archived = [
          for (final pet in all)
            if (pet.isArchived) pet,
        ];

  final PetsStatus status;

  /// Oldest first, as the repository returns them.
  final List<Pet> all;

  /// The pets the app shows: everything that is not archived.
  final List<Pet> visible;
  final List<Pet> archived;

  /// Why loading failed, in words safe to show; set when [status] is
  /// [PetsStatus.failed].
  final String? error;

  Pet? byId(String id) {
    for (final pet in all) {
      if (pet.id == id) return pet;
    }
    return null;
  }
}

/// Loads the owner's pets once after sign-in and keeps them, saving every
/// change through the [PetsRepository].
///
/// The tabs read [petsProvider] and [selectedPetProvider], which stay
/// synchronous; the router holds the tabs back until [PetsState.status] is
/// ready and there is at least one pet (see [petsGateProvider]).
class PetsStore extends Notifier<PetsState> {
  String? _ownerId;
  int _load = 0;

  @override
  PetsState build() {
    final ownerId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final repository = ref.watch(petsRepositoryProvider);
    _ownerId = ownerId;
    final load = ++_load;

    final cached = repository.cachedPets(ownerId);
    if (cached != null || ownerId == null) return PetsState(status: PetsStatus.ready, all: cached ?? const []);

    _fetch(repository, ownerId, load);
    return PetsState(status: PetsStatus.loading);
  }

  Future<void> _fetch(PetsRepository repository, String ownerId, int load) async {
    PetsState next;
    try {
      next = PetsState(status: PetsStatus.ready, all: await repository.fetchPets(ownerId));
    } catch (e) {
      next = PetsState(status: PetsStatus.failed, error: petsErrorMessage(e));
    }
    // Another owner signed in, or the app closed, while this was on its way.
    if (!ref.mounted || load != _load) return;
    state = next;
  }

  /// Loads the pets again after a failure.
  void retry() => ref.invalidateSelf();

  /// Creates [pet], or replaces the one with the same id, and saves it.
  /// Returns the pet as stored. Throws a [PetsException] when saving fails;
  /// nothing changes then.
  Future<Pet> save(Pet pet) async {
    final ownerId = _ownerId;
    final stored = ownerId == null ? pet : await ref.read(petsRepositoryProvider).savePet(ownerId, pet);
    if (ref.mounted && ownerId == _ownerId) _put(stored);
    return stored;
  }

  /// Removes [pet] and its photos for good. Throws a [PetsException] when
  /// that fails; the pet stays then.
  Future<void> delete(Pet pet) async {
    final ownerId = _ownerId;
    if (ownerId != null) await ref.read(petsRepositoryProvider).deletePet(ownerId, pet);
    if (!ref.mounted || ownerId != _ownerId) return;
    state = PetsState(
      status: state.status,
      all: [
        for (final p in state.all)
          if (p.id != pet.id) p,
      ],
    );
  }

  /// Stores a cropped profile photo for the pet with [petId] and returns its
  /// storage path. Throws a [PetsException] when that fails.
  Future<String> uploadPhoto(String petId, Uint8List jpeg) async {
    final ownerId = _ownerId;
    if (ownerId == null) throw const PetsException('Please sign in again.');
    return ref.read(petsRepositoryProvider).uploadPhoto(ownerId, petId, jpeg);
  }

  /// Removes a stored photo. A failure is ignored: a leftover file does no
  /// harm and is removed with the pet.
  Future<void> deletePhoto(String path) async {
    try {
      await ref.read(petsRepositoryProvider).deletePhoto(path);
    } catch (_) {}
  }

  /// Shows [pet] at once and saves it in the background: what
  /// `petsProvider.notifier.add` and `.update` do. A pet the owner does not
  /// have is only added with [add].
  ///
  /// When the save fails the change is taken back, so the app never shows
  /// something the backend does not have (the essentials reminder then asks
  /// for it again, and that path reports the failure to the owner).
  void putAndSave(Pet pet, {bool add = false}) {
    final before = state.byId(pet.id);
    if (!add && before == null) return;
    _put(pet);
    final ownerId = _ownerId;
    if (ownerId == null) return;
    ref.read(petsRepositoryProvider).savePet(ownerId, pet).then((_) {}, onError: (Object e) {
      debugPrint('Pet Companion: could not save ${pet.name}: $e');
      // Only if nothing newer replaced it meanwhile.
      if (!ref.mounted || ownerId != _ownerId || !identical(state.byId(pet.id), pet)) return;
      if (before != null) {
        _put(before);
      } else {
        state = PetsState(
          status: state.status,
          all: [
            for (final p in state.all)
              if (p.id != pet.id) p,
          ],
        );
      }
    });
  }

  void _put(Pet pet) {
    final known = state.byId(pet.id) != null;
    state = PetsState(
      status: state.status,
      all: [
        for (final p in state.all)
          if (p.id == pet.id) pet else p,
        if (!known) pet,
      ],
    );
  }
}

final petsStoreProvider = NotifierProvider<PetsStore, PetsState>(PetsStore.new);

/// The owner's pets as the tabs see them: loaded, and without the archived
/// ones. Empty only while the first-pet welcome is on screen.
class PetsNotifier extends Notifier<List<Pet>> {
  @override
  List<Pet> build() => ref.watch(petsStoreProvider.select((pets) => pets.visible));

  /// Adds [pet] and saves it.
  void add(Pet pet) {
    state = [...state, pet];
    ref.read(petsStoreProvider.notifier).putAndSave(pet, add: true);
  }

  /// Replaces the pet with the same id and saves it.
  void update(Pet pet) {
    state = [
      for (final p in state)
        if (p.id == pet.id) pet else p,
    ];
    ref.read(petsStoreProvider.notifier).putAndSave(pet);
  }
}

final petsProvider = NotifierProvider<PetsNotifier, List<Pet>>(PetsNotifier.new);

/// The owner's archived pets: hidden from the app, shown only on "My pets".
final archivedPetsProvider = Provider<List<Pet>>((ref) => ref.watch(petsStoreProvider.select((pets) => pets.archived)));

/// What the router shows a signed-in owner.
enum PetsGate {
  /// The pets are on their way: the splash.
  loading,

  /// Loading failed: "Could not load your pets".
  failed,

  /// No pet yet: the first-pet welcome.
  empty,

  /// At least one pet: the tabs.
  ready,
}

final petsGateProvider = Provider<PetsGate>((ref) {
  final status = ref.watch(petsStoreProvider.select((pets) => pets.status));
  return switch (status) {
    PetsStatus.loading => PetsGate.loading,
    PetsStatus.failed => PetsGate.failed,
    PetsStatus.ready => ref.watch(petsProvider.select((pets) => pets.isEmpty)) ? PetsGate.empty : PetsGate.ready,
  };
});

/// Id of the pet shown on the dashboard. A new owner starts on their first
/// pet.
class SelectedPetNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final pets = ref.read(petsProvider);
    return pets.isEmpty ? '' : pets.first.id;
  }

  void select(String id) => state = id;
}

final selectedPetIdProvider = NotifierProvider<SelectedPetNotifier, String>(SelectedPetNotifier.new);

/// The selected [Pet], falling back to the first one if the id is stale.
/// [Pet.none] only while the owner has no pet at all, when the first-pet
/// welcome is on screen instead of the tabs.
final selectedPetProvider = Provider<Pet>((ref) {
  final pets = ref.watch(petsProvider);
  final id = ref.watch(selectedPetIdProvider);
  return pets.firstWhere((p) => p.id == id, orElse: () => pets.isEmpty ? Pet.none : pets.first);
});
