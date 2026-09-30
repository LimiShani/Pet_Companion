import 'package:flutter/material.dart';

/// A pet owned by the signed-in user.
///
/// Optional fields are `null` until the owner fills them in; the UI shows a
/// placeholder rather than inventing a value.
class Pet {
  const Pet({
    required this.id,
    required this.name,
    this.species = PetSpecies.dog,
    this.breed,
    double? ageYears,
    this.weightKg,
    this.photoAsset,
    this.feeding = const FeedingStatus(),
    this.activity = const ActivityStatus(),
    this.healthEvents = const [],
    this.birthDate,
    this.birthDateApprox = false,
    this.sex,
    this.neutered,
    this.photoPath,
    this.iconKey,
    this.archivedAt,
    this.reminderSnoozedUntil,
    this.createdAt,
  }) : _ageYears = ageYears;

  /// Stands in for "no pet" while the owner has none. The first-pet welcome
  /// is on screen then, so no tab ever shows it.
  static const none = Pet(id: '', name: '');

  final String id;
  final String name;

  /// What kind of animal this is. Drives species-specific health features.
  final PetSpecies species;
  final String? breed;
  final double? weightKg;

  /// Asset path of a bundled profile photo (the sample pets), or `null`.
  final String? photoAsset;

  final FeedingStatus feeding;
  final ActivityStatus activity;
  final List<HealthEvent> healthEvents;

  /// The birthday, or the day worked out from "about 3 years" when
  /// [birthDateApprox] is set, so the age keeps counting either way.
  final DateTime? birthDate;
  final bool birthDateApprox;

  /// `null` until answered; [PetSex.unknown] is the answer "Not sure".
  final PetSex? sex;

  /// `null` until answered; [Neutered.unknown] is the answer "Not sure".
  final Neutered? neutered;

  /// Path of the cropped profile photo in the `pet-photos` bucket.
  final String? photoPath;

  /// An icon from the bank and its background, e.g. `dog_floppy:sage`.
  final String? iconKey;

  /// Set when the owner archived the pet: hidden from the app, nothing lost.
  final DateTime? archivedAt;

  /// "Not now" on the essentials reminder hides it until this moment.
  final DateTime? reminderSnoozedUntil;
  final DateTime? createdAt;

  /// An age given directly (the sample pets) rather than by a birthday.
  final double? _ageYears;

  bool get isArchived => archivedAt != null;

  /// A photo was chosen (an icon does not count).
  bool get hasPhoto => photoPath != null || photoAsset != null;

  /// The owner answered the age question, exactly or roughly.
  bool get hasAge => _ageYears != null || birthDate != null;

  /// Age in years, from the birthday when there is one.
  double? get ageYears => ageYearsAt(DateTime.now());

  double? ageYearsAt(DateTime now) {
    if (_ageYears != null) return _ageYears;
    final born = birthDate;
    if (born == null) return null;
    final days = now.difference(born).inDays;
    return days <= 0 ? 0 : days / 365.25;
  }

  /// The age in words: "3 years", "4 months", "About 3 years"; `null` when
  /// the age is not known.
  String? get ageLabel => ageLabelAt(DateTime.now());

  String? ageLabelAt(DateTime now) {
    final explicit = _ageYears;
    if (explicit != null) return _count(_trim(explicit), explicit == 1, 'year');
    final born = birthDate;
    if (born == null) return null;
    var months = (now.year - born.year) * 12 + now.month - born.month;
    if (now.day < born.day) months--;
    if (months < 0) months = 0;
    final String text;
    if (months < 1) {
      final weeks = now.difference(born).inDays ~/ 7;
      text = weeks < 1 ? 'under a week' : _count('$weeks', weeks == 1, 'week');
    } else if (months < 24) {
      text = _count('$months', months == 1, 'month');
    } else {
      final years = months ~/ 12;
      text = _count('$years', years == 1, 'year');
    }
    if (birthDateApprox) return 'About $text';
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  static String _count(String count, bool one, String unit) => '$count $unit${one ? '' : 's'}';

  /// A copy with the given fields replaced; `null` keeps the current value.
  /// To clear a field use [withBasics] or [withPicture].
  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    double? ageYears,
    double? weightKg,
    String? photoAsset,
    FeedingStatus? feeding,
    ActivityStatus? activity,
    List<HealthEvent>? healthEvents,
    DateTime? birthDate,
    bool? birthDateApprox,
    PetSex? sex,
    Neutered? neutered,
    DateTime? createdAt,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      // A new birthday replaces an age that was given directly.
      ageYears: ageYears ?? (birthDate != null ? null : _ageYears),
      weightKg: weightKg ?? this.weightKg,
      photoAsset: photoAsset ?? this.photoAsset,
      feeding: feeding ?? this.feeding,
      activity: activity ?? this.activity,
      healthEvents: healthEvents ?? this.healthEvents,
      birthDate: birthDate ?? this.birthDate,
      birthDateApprox: birthDateApprox ?? this.birthDateApprox,
      sex: sex ?? this.sex,
      neutered: neutered ?? this.neutered,
      photoPath: photoPath,
      iconKey: iconKey,
      archivedAt: archivedAt,
      reminderSnoozedUntil: reminderSnoozedUntil,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// A copy with the answers of the "about the pet" form, exactly as given:
  /// here `null` means "not answered" and clears the field. With [keepAge]
  /// the current age is left alone.
  Pet withBasics({
    required String name,
    required PetSpecies species,
    required String? breed,
    required double? weightKg,
    required PetSex? sex,
    required Neutered? neutered,
    DateTime? birthDate,
    bool birthDateApprox = false,
    bool keepAge = false,
  }) {
    return Pet(
      id: id,
      name: name,
      species: species,
      breed: breed,
      ageYears: keepAge ? _ageYears : null,
      weightKg: weightKg,
      photoAsset: photoAsset,
      feeding: feeding,
      activity: activity,
      healthEvents: healthEvents,
      birthDate: keepAge ? this.birthDate : birthDate,
      birthDateApprox: keepAge ? this.birthDateApprox : birthDate != null && birthDateApprox,
      sex: sex,
      neutered: neutered,
      photoPath: photoPath,
      iconKey: iconKey,
      archivedAt: archivedAt,
      reminderSnoozedUntil: reminderSnoozedUntil,
      createdAt: createdAt,
    );
  }

  /// A copy showing exactly this picture: a photo in storage, an icon from
  /// the bank, or (both `null`) the default icon of its kind.
  Pet withPicture({String? photoPath, String? iconKey}) =>
      _with(photoPath: photoPath, iconKey: iconKey, keepAsset: false);

  /// A copy that is archived at [at], or restored when [at] is `null`.
  Pet withArchivedAt(DateTime? at) => _with(photoPath: photoPath, iconKey: iconKey, archivedAt: at, setArchived: true);

  /// A copy whose reminder is postponed until [until] (`null`: not postponed).
  Pet withReminderSnoozedUntil(DateTime? until) =>
      _with(photoPath: photoPath, iconKey: iconKey, snoozedUntil: until, setSnoozed: true);

  Pet _with({
    required String? photoPath,
    required String? iconKey,
    bool keepAsset = true,
    DateTime? archivedAt,
    bool setArchived = false,
    DateTime? snoozedUntil,
    bool setSnoozed = false,
  }) {
    return Pet(
      id: id,
      name: name,
      species: species,
      breed: breed,
      ageYears: _ageYears,
      weightKg: weightKg,
      photoAsset: keepAsset ? photoAsset : null,
      feeding: feeding,
      activity: activity,
      healthEvents: healthEvents,
      birthDate: birthDate,
      birthDateApprox: birthDateApprox,
      sex: sex,
      neutered: neutered,
      photoPath: photoPath,
      iconKey: iconKey,
      archivedAt: setArchived ? archivedAt : this.archivedAt,
      reminderSnoozedUntil: setSnoozed ? snoozedUntil : reminderSnoozedUntil,
      createdAt: createdAt,
    );
  }
}

/// Stored in `pets.sex` by [name]. [unknown] is the honest answer "Not sure".
enum PetSex {
  male('Male'),
  female('Female'),
  unknown('Not sure');

  const PetSex(this.label);

  final String label;

  static PetSex? fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// Stored in `pets.neutered` by [name]. [unknown] is the answer "Not sure".
enum Neutered {
  yes('Yes'),
  no('No'),
  unknown('Not sure');

  const Neutered(this.label);

  final String label;

  static Neutered? fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// The kinds of animal the app knows about. Stored in the `pets.species`
/// column by [name]; anything unknown reads back as [other].
enum PetSpecies {
  dog('Dog'),
  cat('Cat'),
  bird('Bird'),
  rabbit('Rabbit'),
  reptile('Reptile'),
  other('Other');

  const PetSpecies(this.label);

  /// Display name, e.g. on the pet's profile line.
  final String label;

  static PetSpecies fromName(String? name) =>
      PetSpecies.values.firstWhere((s) => s.name == name, orElse: () => PetSpecies.other);
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
