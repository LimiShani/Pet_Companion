import 'package:flutter/material.dart';

/// A pet owned by the signed-in user.
///
/// Optional fields are `null` until the owner fills them in; the UI shows a
/// placeholder rather than inventing a value.
class Pet {
  const Pet({
    required this.id,
    required this.name,
    this.breed,
    this.ageYears,
    this.weightKg,
    this.photoAsset,
    this.feeding = const FeedingStatus(),
    this.activity = const ActivityStatus(),
    this.healthEvents = const [],
  });

  final String id;
  final String name;
  final String? breed;
  final double? ageYears;
  final double? weightKg;

  /// Asset path of the profile photo, or `null` for the paw placeholder.
  final String? photoAsset;

  final FeedingStatus feeding;
  final ActivityStatus activity;
  final List<HealthEvent> healthEvents;

  Pet copyWith({
    String? name,
    String? breed,
    double? ageYears,
    double? weightKg,
    String? photoAsset,
    FeedingStatus? feeding,
    ActivityStatus? activity,
    List<HealthEvent>? healthEvents,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      ageYears: ageYears ?? this.ageYears,
      weightKg: weightKg ?? this.weightKg,
      photoAsset: photoAsset ?? this.photoAsset,
      feeding: feeding ?? this.feeding,
      activity: activity ?? this.activity,
      healthEvents: healthEvents ?? this.healthEvents,
    );
  }
}

/// Today's feeding progress for one pet.
class FeedingStatus {
  const FeedingStatus({this.caloriesToday = 0, this.dailyGoal, this.nextFeeding});

  final int caloriesToday;

  /// Daily calorie goal, or `null` when not set yet.
  final int? dailyGoal;
  final TimeOfDay? nextFeeding;

  /// 0..1 fraction of the goal, or `null` when there is no goal.
  double? get progress {
    final goal = dailyGoal;
    if (goal == null || goal <= 0) return null;
    return (caloriesToday / goal).clamp(0.0, 1.0);
  }
}

/// Today's activity for one pet.
class ActivityStatus {
  const ActivityStatus({this.steps = 0, this.activeTime = Duration.zero, this.nextWalk});

  final int steps;
  final Duration activeTime;
  final TimeOfDay? nextWalk;
}

/// A scheduled or past health event (medicine, vet visit, vaccination...).
class HealthEvent {
  const HealthEvent({required this.title, required this.when, this.kind = HealthEventKind.other});

  final String title;
  final DateTime when;
  final HealthEventKind kind;
}

enum HealthEventKind { medicine, checkup, vaccination, other }
