import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pet.dart';

/// The owner's pets. Seeded with sample data until a backend exists.
class PetsNotifier extends Notifier<List<Pet>> {
  @override
  List<Pet> build() => _samplePets;

  void add(Pet pet) => state = [...state, pet];

  void update(Pet pet) => state = [
        for (final p in state)
          if (p.id == pet.id) pet else p,
      ];
}

final petsProvider = NotifierProvider<PetsNotifier, List<Pet>>(PetsNotifier.new);

/// Id of the pet shown on the dashboard.
class SelectedPetNotifier extends Notifier<String> {
  @override
  String build() => ref.read(petsProvider).first.id;

  void select(String id) => state = id;
}

final selectedPetIdProvider = NotifierProvider<SelectedPetNotifier, String>(SelectedPetNotifier.new);

/// The selected [Pet], falling back to the first one if the id is stale.
final selectedPetProvider = Provider<Pet>((ref) {
  final pets = ref.watch(petsProvider);
  final id = ref.watch(selectedPetIdProvider);
  return pets.firstWhere((p) => p.id == id, orElse: () => pets.first);
});

final _samplePets = <Pet>[
  Pet(
    id: 'kelly',
    name: 'Kelly',
    breed: 'Mix',
    ageYears: 13.6,
    weightKg: 23,
    photoAsset: 'assets/images/kelly.png',
    feeding: const FeedingStatus(
      caloriesToday: 375,
      dailyGoal: 900,
      nextFeeding: TimeOfDay(hour: 19, minute: 30),
    ),
    activity: const ActivityStatus(
      steps: 2569,
      activeTime: Duration(hours: 1, minutes: 32),
      nextWalk: TimeOfDay(hour: 18, minute: 30),
    ),
    healthEvents: [
      HealthEvent(title: 'Medicine', when: DateTime(2025, 7, 27, 19, 30), kind: HealthEventKind.medicine),
      HealthEvent(title: 'General check', when: DateTime(2025, 6, 12, 18, 20), kind: HealthEventKind.checkup),
    ],
  ),
  const Pet(id: 'soya', name: 'Soya'),
];
