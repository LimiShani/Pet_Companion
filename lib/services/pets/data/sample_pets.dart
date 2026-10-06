import 'package:flutter/material.dart';

import '../../../models/pet.dart';

/// The demo account's pets. Kelly is filled in; Soya has only a name, so
/// the demo shows the essentials reminder too. Their ids are what the
/// Health sample data is keyed by.
List<Pet> samplePets() => [
  Pet(
    id: 'kelly',
    name: 'Kelly',
    breed: 'Mix',
    ageYears: 13.6,
    weightKg: 23,
    photoAsset: 'assets/images/kelly.png',
    sex: PetSex.female,
    neutered: Neutered.yes,
    createdAt: DateTime(2025, 1, 1),
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
      HealthEvent(
        title: 'Medicine',
        when: DateTime(2025, 7, 27, 19, 30),
        kind: HealthEventKind.medicine,
      ),
      HealthEvent(
        title: 'General check',
        when: DateTime(2025, 6, 12, 18, 20),
        kind: HealthEventKind.checkup,
      ),
    ],
  ),
  Pet(id: 'soya', name: 'Soya', createdAt: DateTime(2025, 1, 2)),
];
