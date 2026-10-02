import 'dart:math' as math;

import '../../../models/pet.dart';

/// A pet's food and daily goals, behind Home's feeding and activity cards.
///
/// Everything is optional: a pet whose owner set nothing has
/// `CareSettings(petId: id)`, and the cards invite the owner to fill it in
/// rather than show zeros.
class CareSettings {
  const CareSettings({
    required this.petId,
    this.foodName = '',
    this.kcalPer100g,
    this.gramsPerCup,
    this.portionGrams,
    this.calorieGoal,
    this.activityGoalMinutes,
  });

  final String petId;
  final String foodName;

  /// As printed on the bag.
  final double? kcalPer100g;

  /// How many grams of this food fill the owner's cup; `null` when the
  /// owner weighs in grams.
  final double? gramsPerCup;

  /// The usual amount of one meal.
  final double? portionGrams;

  /// The owner's own daily goal; `null` means the app's estimate (see
  /// [estimatedCalorieGoal]).
  final int? calorieGoal;

  /// The owner's daily activity goal; `null` means [defaultActivityGoal].
  final int? activityGoalMinutes;

  /// Calories can be counted: the food's calories are known.
  bool get hasFood => kcalPer100g != null;

  /// The calories of [grams] of this food, or `null` without a food.
  int? caloriesOf(double grams) {
    final kcal = kcalPer100g;
    return kcal == null ? null : (grams * kcal / 100).round();
  }

  /// The portion in the owner's cups, when they use cups.
  double? get portionCups {
    final cup = gramsPerCup;
    final portion = portionGrams;
    return cup == null || portion == null ? null : portion / cup;
  }

  CareSettings copyWith({
    String? foodName,
    double? kcalPer100g,
    double? gramsPerCup,
    double? portionGrams,
    int? activityGoalMinutes,
  }) => CareSettings(
    petId: petId,
    foodName: foodName ?? this.foodName,
    kcalPer100g: kcalPer100g ?? this.kcalPer100g,
    gramsPerCup: gramsPerCup ?? this.gramsPerCup,
    portionGrams: portionGrams ?? this.portionGrams,
    calorieGoal: calorieGoal,
    activityGoalMinutes: activityGoalMinutes ?? this.activityGoalMinutes,
  );

  /// A copy with the owner's own calorie goal, or the estimate (`null`).
  CareSettings withCalorieGoal(int? goal) => CareSettings(
    petId: petId,
    foodName: foodName,
    kcalPer100g: kcalPer100g,
    gramsPerCup: gramsPerCup,
    portionGrams: portionGrams,
    calorieGoal: goal,
    activityGoalMinutes: activityGoalMinutes,
  );
}

/// Minutes of activity a day the activity card aims at until the owner
/// sets a goal: an hour for a dog, half an hour of play for anyone else.
int defaultActivityGoal(PetSpecies species) => species == PetSpecies.dog ? 60 : 30;

/// Dogs go for walks; for any other pet the activity card counts play.
bool walksPet(PetSpecies species) => species == PetSpecies.dog;

/// Why there is no calorie estimate for a pet.
enum NoEstimate {
  /// Only dogs and cats have the usual formula.
  species,

  /// The weight is not known.
  weight,
}

/// The app's estimate of a pet's daily calories, with what it is based on.
class CalorieEstimate {
  const CalorieEstimate({required this.calories, required this.weightKg, required this.factor});

  final int calories;
  final double weightKg;

  /// The life-stage factor the resting energy was multiplied by.
  final double factor;
}

/// The usual veterinary estimate of a dog's or a cat's daily calories:
/// the resting energy, 70 × weight (kg)^0.75, times a factor for the life
/// stage (young, adult neutered or not, senior). Rounded to tens: it is a
/// starting point, and the owner's vet can give an exact goal.
///
/// Returns the reason instead when there is no estimate.
Object estimatedCalorieGoal(Pet pet, DateTime now) {
  if (pet.species != PetSpecies.dog && pet.species != PetSpecies.cat) return NoEstimate.species;
  final kg = pet.weightKg;
  if (kg == null || kg <= 0) return NoEstimate.weight;
  final years = pet.ageYearsAt(now);
  final neutered = pet.neutered != Neutered.no;
  final double factor;
  if (pet.species == PetSpecies.dog) {
    factor = switch (years) {
      null => neutered ? 1.6 : 1.8,
      < 4 / 12 => 3.0,
      < 1 => 2.0,
      >= 8 => 1.4,
      _ => neutered ? 1.6 : 1.8,
    };
  } else {
    factor = switch (years) {
      null => neutered ? 1.2 : 1.4,
      < 1 => 2.5,
      >= 11 => 1.1,
      _ => neutered ? 1.2 : 1.4,
    };
  }
  final resting = 70 * math.pow(kg, 0.75);
  return CalorieEstimate(calories: ((resting * factor) / 10).round() * 10, weightKg: kg, factor: factor);
}
