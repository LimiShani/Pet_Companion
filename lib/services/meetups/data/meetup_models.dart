import '../../../models/pet.dart';
import '../../community/data/audience.dart';
import '../../findvet/regions/regions.dart';
import '../../outdoors/data/park_models.dart';

/// Walk and play partners (Community > Outside > Partners): the ads and
/// what they are made of. The database is `0028_meetups.sql`; design in
/// docs/meetups.md.

/// What the ad is for.
enum MeetupKind { walk, play }

/// The part of the day of a recurring ad.
enum DayPart { morning, noon, evening }

/// A dog's size: what an ad suits, and the size of the ad's dog.
enum PetSize {
  small,
  medium,
  large;

  /// From the weight: under 10 kg small, under 25 kg medium, else large.
  /// Only dogs have a size here; the server works it out the same way.
  static PetSize? of(PetSpecies species, double? weightKg) {
    if (species != PetSpecies.dog || weightKg == null) return null;
    if (weightKg < 10) return small;
    if (weightKg < 25) return medium;
    return large;
  }

  static PetSize? parse(Object? value) => values.asNameMap()['$value'];
}

enum MeetupStatus { open, closed }

/// The limits the server holds (and the fake follows).
abstract final class MeetupLimits {
  static const note = 200;
  static const place = 80;
  static const newPerDay = 3;
  static const open = 5;

  /// A recurring ad is up for this long, then can be renewed.
  static const recurringDays = 30;

  /// Ads that ended longer ago than this are deleted.
  static const keepDays = 90;

  /// A one-off meeting lasts at most this long...
  static const maxHours = 12;

  /// ...and starts at most this far ahead.
  static const aheadDays = 60;
}

/// The public facts of the ad's pet, as they were when the ad was saved
/// (other members cannot read a pet's own record).
class MeetupPet {
  const MeetupPet({
    this.petId,
    required this.name,
    required this.species,
    this.breed,
    this.bornOn,
    this.bornApprox = false,
    this.size,
    this.iconKey,
  });

  /// The pet of the app, from the owner's pet.
  factory MeetupPet.of(Pet pet) => MeetupPet(
    petId: pet.id,
    name: pet.name,
    species: pet.species,
    breed: pet.breed,
    bornOn: pet.birthDate,
    bornApprox: pet.birthDateApprox,
    size: PetSize.of(pet.species, pet.weightKg),
    iconKey: pet.iconKey,
  );

  /// The owner's pet id; only the ad's author gets it.
  final String? petId;
  final String name;
  final PetSpecies species;
  final String? breed;
  final DateTime? bornOn;
  final bool bornApprox;
  final PetSize? size;
  final String? iconKey;

  /// A [Pet] holding these facts, for the shared pet widgets and words
  /// (avatar, "Dog · Mixed · about 3 years").
  Pet get asPet => Pet(
    id: petId ?? '',
    name: name,
    species: species,
    breed: breed,
    birthDate: bornOn,
    birthDateApprox: bornApprox,
    iconKey: iconKey,
  );
}

/// When: one meeting, or every week on some days.
sealed class MeetupTime {
  const MeetupTime();

  /// Whether it happens on the (local) day of [day].
  bool occursOn(DateTime day);

  /// Whether it happens within the seven days from [now]'s day.
  bool occursWithinWeek(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 7; i++) {
      if (occursOn(DateTime(today.year, today.month, today.day + i))) {
        return true;
      }
    }
    return false;
  }

  /// The first day from [now]'s day on which it happens (within a week for
  /// a recurring ad); `null` when none.
  DateTime? nextDay(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      OneOffTime(:final start) => DateTime(start.year, start.month, start.day),
      RecurringTime() => () {
        for (var i = 0; i < 7; i++) {
          final day = DateTime(today.year, today.month, today.day + i);
          if (occursOn(day)) return day;
        }
        return null;
      }(),
    };
  }
}

class OneOffTime extends MeetupTime {
  const OneOffTime(this.start, this.end);

  /// Local times.
  final DateTime start;
  final DateTime end;

  @override
  bool occursOn(DateTime day) =>
      start.year == day.year && start.month == day.month && start.day == day.day;
}

class RecurringTime extends MeetupTime {
  const RecurringTime(this.weekdays, this.part);

  /// ISO weekdays, 1 = Monday ... 7 = Sunday.
  final Set<int> weekdays;
  final DayPart part;

  @override
  bool occursOn(DateTime day) => weekdays.contains(day.weekday);
}

/// The locality of [code] in the bundled list, or `null`.
Locality? localityOfCode(String? code) {
  if (code == null) return null;
  for (final region in vetRegions) {
    final locality = region.localityByCode(code);
    if (locality != null) return locality;
  }
  return null;
}

/// An ad.
class Meetup {
  const Meetup({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.kind,
    required this.localityCode,
    required this.time,
    required this.createdAt,
    required this.expiresAt,
    this.pet,
    this.parkId,
    this.park,
    this.placeText,
    this.suits = const {},
    this.note = '',
    this.status = MeetupStatus.open,
    this.answerCount = 0,
    this.hidden = false,
    this.answered = false,
  });

  final String id;
  final String authorId;

  /// As stored; empty for an account without a name.
  final String authorName;
  final MeetupKind kind;
  final MeetupPet? pet;

  /// The park, when the ad is at one. [park] is `null` when the reader
  /// cannot see the park (removed, or no access to parks).
  final String? parkId;
  final DogPark? park;

  /// The city (a code of the bundled localities list).
  final String localityCode;

  /// "Yarkon Park, by the boats": the public place when not at a park.
  final String? placeText;
  final MeetupTime time;

  /// The sizes it suits; empty: every size.
  final Set<PetSize> suits;
  final String note;
  final MeetupStatus status;
  final int answerCount;

  /// Hidden by reports until a moderator decides (its author still sees it).
  final bool hidden;

  /// Whether the reader answered it.
  final bool answered;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool get isRecurring => time is RecurringTime;

  /// Which animal chips show it: its pet's kind, or every chip without a
  /// pet (as posts do).
  Audience get audience => pet == null
      ? Audience.everyone
      : audienceOfSpecies(pet!.species);

  /// Shown on the board at [now]: open, not ended, not hidden.
  bool isLiveAt(DateTime now) =>
      status == MeetupStatus.open && expiresAt.isAfter(now) && !hidden;

  /// Ended by its time (not closed by its author).
  bool hasEndedAt(DateTime now) =>
      status == MeetupStatus.open && !expiresAt.isAfter(now);

  /// Where distances are measured to: the park, else the city's centre.
  GeoPoint? get point => park?.point ?? localityOfCode(localityCode)?.point;

  Meetup copyWith({
    MeetupStatus? status,
    int? answerCount,
    bool? answered,
    bool? hidden,
    DateTime? expiresAt,
  }) => Meetup(
    id: id,
    authorId: authorId,
    authorName: authorName,
    kind: kind,
    localityCode: localityCode,
    time: time,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    pet: pet,
    parkId: parkId,
    park: park,
    placeText: placeText,
    suits: suits,
    note: note,
    status: status ?? this.status,
    answerCount: answerCount ?? this.answerCount,
    hidden: hidden ?? this.hidden,
    answered: answered ?? this.answered,
  );
}

/// What the form sends: a new ad, or the new text of an open one.
class MeetupDraft {
  const MeetupDraft({
    required this.kind,
    required this.time,
    this.pet,
    this.parkId,
    this.park,
    this.localityCode,
    this.placeText,
    this.suits = const {},
    this.note = '',
  });

  final MeetupKind kind;

  /// The author's pet (its id goes to the server, which copies the facts
  /// itself); `null`: no pet.
  final MeetupPet? pet;

  /// A park ([park] for showing it at once), or a city and a place.
  final String? parkId;
  final DogPark? park;
  final String? localityCode;
  final String? placeText;
  final MeetupTime time;
  final Set<PetSize> suits;
  final String note;

  /// The city of the ad: the park's, else the chosen one.
  String? get city => park?.localityCode ?? localityCode;
}

/// Someone who answered the author's ad.
class MeetupResponder {
  const MeetupResponder({
    required this.id,
    required this.name,
    required this.answeredAt,
  });

  final String id;
  final String name;
  final DateTime answeredAt;
}

enum MeetupFailure {
  /// Three new ads today already.
  rateLimited,

  /// Five open ads already.
  tooManyOpen,

  /// The ad is closed, ended or hidden.
  notOpen,

  /// A block between the two members.
  blocked,

  /// The server refused what was sent (a park no longer shown, a time
  /// already over).
  invalid,

  /// No connection, or the server is down.
  unavailable,

  /// Anything else (no access).
  other,
}

class MeetupException implements Exception {
  const MeetupException(this.failure);
  final MeetupFailure failure;

  @override
  String toString() => 'MeetupException(${failure.name})';
}

/// The problems of a [draft] the form points at before sending (the server
/// checks the same). Empty when it can be sent at [now].
Set<MeetupDraftProblem> draftProblems(MeetupDraft draft, DateTime now) => {
  if (draft.parkId == null &&
      (draft.localityCode == null || (draft.placeText ?? '').trim().isEmpty))
    MeetupDraftProblem.place,
  if ((draft.placeText ?? '').trim().length > MeetupLimits.place)
    MeetupDraftProblem.place,
  if (draft.note.trim().length > MeetupLimits.note) MeetupDraftProblem.note,
  ...switch (draft.time) {
    OneOffTime(:final start, :final end) => {
      if (!end.isAfter(start) ||
          end.difference(start) > const Duration(hours: MeetupLimits.maxHours))
        MeetupDraftProblem.hours,
      if (!end.isAfter(now)) MeetupDraftProblem.past,
      if (start.isAfter(now.add(const Duration(days: MeetupLimits.aheadDays))))
        MeetupDraftProblem.tooFar,
    },
    RecurringTime(:final weekdays) => {
      if (weekdays.isEmpty) MeetupDraftProblem.days,
    },
  },
};

enum MeetupDraftProblem { place, note, hours, past, tooFar, days }
