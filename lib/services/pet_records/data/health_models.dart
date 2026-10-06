import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../config/app_config.dart';

export '../../../utils/calendar.dart' show addDays, daysBetween;

/// Why something in Health failed. The repositories and services report
/// the reason; the screen puts it into words in the app's language (see
/// `healthErrorText` in `health_strings.dart`). [english] is the same in
/// plain English, for logs.
enum HealthFailure {
  offline('Could not reach the server. Check your connection and try again.'),
  sessionEnded('Your session has ended. Please sign in again.'),
  notAllowed('You are not allowed to do that. Please sign in again.'),
  invalid(
    'Some of the details are not valid. Please check them and try again.',
  ),
  petNotStored(
    'This pet is not saved to your account yet, so nothing can be stored for it.',
  ),
  petGone('That pet is no longer in your list.'),
  itemGone('That item no longer exists. Go back and open it again.'),
  recordGone('That record no longer exists.'),
  vetGone('That vet no longer exists.'),
  medicineGone('That medicine no longer exists.'),
  reminderGone('That reminder no longer exists.'),
  entryGone('That entry no longer exists.'),
  fileType('Only photos (JPEG, PNG, WebP) and PDF files can be attached.'),
  fileEmpty('That file is empty.'),
  fileTooLarge('That file is larger than 5 MB. Please choose a smaller one.'),
  fileGone('That file is no longer available.'),
  fileNotStored('The file could not be stored. Please try again.'),
  fileUnreadable('Could not read that file.'),
  camera('Could not open the camera.'),
  photos('Could not open your photos.'),
  files('Could not open your files.'),
  pdf('Could not prepare the PDF. Please try again.'),
  lostCard('Could not prepare the card. Please try again.'),

  /// Anything the app has no words of its own for.
  unknown('Something went wrong. Please try again.');

  const HealthFailure(this.english);

  final String english;
}

/// Thrown by a `HealthRepository` and the Health services. [failure] says
/// what went wrong; [message] is the same in plain English, for logs and
/// for a [HealthFailure.unknown] failure, where it is whatever explanation
/// there is.
class HealthException implements Exception {
  const HealthException(this.message, [this.failure = HealthFailure.unknown]);

  /// The failure [failure], with its English words as the message.
  HealthException.of(this.failure) : message = failure.english;

  final String message;
  final HealthFailure failure;

  @override
  String toString() => message;
}

/// Thrown when a record was saved but keeping its planned follow-up (the
/// "next due" date in the Schedule) in step failed. [saved] is the record
/// as stored, so a second try updates it instead of adding another one;
/// [cause] is why the follow-up failed.
class FollowUpNotSaved implements Exception {
  const FollowUpNotSaved(this.saved, this.cause);

  final HealthRecord saved;
  final Object cause;

  @override
  String toString() =>
      'Record ${saved.id} saved; its follow-up was not: $cause';
}

/// Thrown when a medicine was saved but setting up its reminders failed
/// part of the way. [saved] is the medicine as stored, so a second try
/// updates it instead of adding another one; [cause] is why it failed.
class RemindersNotSaved implements Exception {
  const RemindersNotSaved(this.saved, this.cause);

  final Medication saved;
  final Object cause;

  @override
  String toString() =>
      'Medicine ${saved.id} saved; its reminders were not: $cause';
}

/// Midnight of [d]: the app treats "a day" as a local calendar date.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Minutes since midnight, for sorting and comparing times of day.
int minutesOf(TimeOfDay t) => t.hour * 60 + t.minute;

/// [day] at [time].
DateTime atTime(DateTime day, TimeOfDay time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute);

// ---------------------------------------------------------------------------
// Health records (the history, and planned appointments / due dates)
// ---------------------------------------------------------------------------

/// What a health record is about. [dbValue] is the `health_events.kind`
/// column; anything unknown reads back as [other].
///
/// [label] and [plural] are English names for logs and tests; a screen
/// says them in its own language with `HealthWords` (`health_strings.dart`).
/// The same holds for the `label` of every other enum in this file.
enum RecordKind {
  checkup('checkup', 'Vet visit', 'Vet visits'),
  vaccination('vaccination', 'Vaccination', 'Vaccinations'),
  preventive('preventive', 'Preventive', 'Preventive'),
  procedure('procedure', 'Procedure', 'Procedures'),
  medicine('medicine', 'Medicine', 'Medicine'),
  document('document', 'Document', 'Documents'),
  other('other', 'Note', 'Notes');

  const RecordKind(this.dbValue, this.label, this.plural);

  final String dbValue;
  final String label;

  /// Label of the filter chip in the history.
  final String plural;

  /// Vaccinations, preventive treatments and medicine name a product.
  bool get hasProduct =>
      this == vaccination || this == preventive || this == medicine;

  /// Vaccinations and preventive treatments have a "next due" date, which
  /// the owner copies from the vet's instructions.
  bool get hasNextDue => this == vaccination || this == preventive;

  static RecordKind fromDb(String? value) => RecordKind.values.firstWhere(
    (k) => k.dbValue == value,
    orElse: () => RecordKind.other,
  );
}

/// One entry of a pet's medical record.
///
/// A record that is not done yet ([doneAt] is `null`) is a planned
/// appointment or a due date and lives in the Schedule; a done record is
/// part of the History.
class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.scheduledAt,
    this.notes = '',
    this.doneAt,
    this.clinic = '',
    this.productName = '',
    this.nextDueOn,
    this.followUpOf,
    this.costAmount,
    this.costCurrency = AppConfig.defaultCurrency,
  });

  /// Empty until the repository has stored the record.
  final String id;
  final String petId;
  final RecordKind kind;
  final String title;
  final String notes;

  /// When it is planned for (or, for a done record, when it was planned).
  final DateTime scheduledAt;

  /// When it actually happened, or `null` while it is still planned.
  final DateTime? doneAt;

  /// Vet or clinic, as the owner typed it.
  final String clinic;

  /// Product name, batch... for vaccinations, preventive treatments, medicine.
  final String productName;

  /// The next due date the vet gave, or `null`. Never computed by the app.
  final DateTime? nextDueOn;

  /// Id of the record whose "next due" date created this planned record.
  final String? followUpOf;

  /// What the owner paid (or, for a planned record, expects to pay), or
  /// `null` when no cost was entered. Never part of what is shared with a vet.
  final double? costAmount;

  /// ISO 4217 code of [costAmount].
  final String costCurrency;

  bool get hasCost => costAmount != null;

  bool get isNew => id.isEmpty;
  bool get isDone => doneAt != null;

  /// The date the record is shown and sorted by.
  DateTime get when => doneAt ?? scheduledAt;

  HealthRecord copyWith({
    String? id,
    RecordKind? kind,
    String? title,
    String? notes,
    DateTime? scheduledAt,
    String? clinic,
    String? productName,
    String? followUpOf,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      petId: petId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      doneAt: doneAt,
      clinic: clinic ?? this.clinic,
      productName: productName ?? this.productName,
      nextDueOn: nextDueOn,
      followUpOf: followUpOf ?? this.followUpOf,
      costAmount: costAmount,
      costCurrency: costCurrency,
    );
  }

  /// The same record, done at [at] (or planned again when `null`).
  HealthRecord withDone(DateTime? at) => HealthRecord(
    id: id,
    petId: petId,
    kind: kind,
    title: title,
    notes: notes,
    scheduledAt: scheduledAt,
    doneAt: at,
    clinic: clinic,
    productName: productName,
    nextDueOn: nextDueOn,
    followUpOf: followUpOf,
    costAmount: costAmount,
    costCurrency: costCurrency,
  );

  /// The same record with another "next due" date (`null` clears it).
  HealthRecord withNextDue(DateTime? day) => HealthRecord(
    id: id,
    petId: petId,
    kind: kind,
    title: title,
    notes: notes,
    scheduledAt: scheduledAt,
    doneAt: doneAt,
    clinic: clinic,
    productName: productName,
    nextDueOn: day == null ? null : dateOnly(day),
    followUpOf: followUpOf,
    costAmount: costAmount,
    costCurrency: costCurrency,
  );
}

/// A file attached to a health record: a photo or a PDF.
class HealthDocument {
  const HealthDocument({
    required this.id,
    required this.petId,
    required this.recordId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.storagePath = '',
  });

  final String id;
  final String petId;
  final String recordId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Where the file lives in the documents bucket (empty for sample data).
  final String storagePath;

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
}

/// A file the owner just chose, before it is stored.
class PickedFile {
  const PickedFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  /// The documents bucket accepts these and nothing else.
  static const allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  };

  /// The bucket's size limit per file.
  static const maxBytes = 5 * 1024 * 1024;

  /// Why this file cannot be attached, or `null` when it can.
  HealthFailure? get failure {
    if (!allowedMimeTypes.contains(mimeType)) return HealthFailure.fileType;
    if (bytes.isEmpty) return HealthFailure.fileEmpty;
    if (bytes.length > maxBytes) return HealthFailure.fileTooLarge;
    return null;
  }

  /// [failure] in plain English, for logs; `null` when the file is fine.
  String? get problem => failure?.english;

  /// Mime type for a file name, or `null` when the type is not supported.
  static String? mimeTypeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }
}

// ---------------------------------------------------------------------------
// Vets and the health profile
// ---------------------------------------------------------------------------

/// A vet or clinic. Saved once per owner and shared by their pets.
class Vet {
  const Vet({
    required this.id,
    required this.name,
    this.phone = '',
    this.onWhatsApp = false,
    this.address = '',
    this.openingHours = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String phone;

  /// The owner marked [phone] as a WhatsApp number.
  final bool onWhatsApp;
  final String address;

  /// Free text, as the owner typed it.
  final String openingHours;
  final String notes;

  bool get isNew => id.isEmpty;
  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasAddress => address.trim().isNotEmpty;

  Vet copyWith({
    String? id,
    String? name,
    String? phone,
    bool? onWhatsApp,
    String? address,
    String? openingHours,
    String? notes,
  }) {
    return Vet(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      onWhatsApp: onWhatsApp ?? this.onWhatsApp,
      address: address ?? this.address,
      openingHours: openingHours ?? this.openingHours,
      notes: notes ?? this.notes,
    );
  }
}

/// Which of a pet's two vets.
enum VetRole {
  regular('Regular vet'),
  emergency('Emergency vet (24 h)');

  const VetRole(this.label);

  final String label;
}

/// Identification and standing medical facts of one pet, plus who to
/// contact. Every field is optional.
class HealthProfile {
  const HealthProfile({
    required this.petId,
    this.microchip = '',
    this.notChipped = false,
    this.allergies = const [],
    this.allergiesNoneKnown = false,
    this.conditions = const [],
    this.conditionsNoneKnown = false,
    this.contactName = '',
    this.contactPhone = '',
    this.notes = '',
    this.regularVetId,
    this.emergencyVetId,
  });

  final String petId;
  final String microchip;

  /// The owner answered "not chipped": an answer, not a gap.
  final bool notChipped;
  final List<String> allergies;

  /// The owner answered "none known": an answer, not a gap.
  final bool allergiesNoneKnown;
  final List<String> conditions;
  final bool conditionsNoneKnown;

  /// The emergency contact person.
  final String contactName;
  final String contactPhone;
  final String notes;
  final String? regularVetId;
  final String? emergencyVetId;

  bool get hasContact =>
      contactName.trim().isNotEmpty || contactPhone.trim().isNotEmpty;

  /// A number, or "not chipped".
  bool get microchipAnswered => microchip.trim().isNotEmpty || notChipped;

  /// Whether the owner has said anything about allergies: a list, or
  /// "none known".
  bool get allergiesAnswered => allergies.isNotEmpty || allergiesNoneKnown;
  bool get conditionsAnswered => conditions.isNotEmpty || conditionsNoneKnown;

  String? vetId(VetRole role) =>
      role == VetRole.regular ? regularVetId : emergencyVetId;

  HealthProfile copyWith({
    String? microchip,
    bool? notChipped,
    List<String>? allergies,
    bool? allergiesNoneKnown,
    List<String>? conditions,
    bool? conditionsNoneKnown,
    String? contactName,
    String? contactPhone,
    String? notes,
  }) {
    return HealthProfile(
      petId: petId,
      microchip: microchip ?? this.microchip,
      notChipped: notChipped ?? this.notChipped,
      allergies: allergies ?? this.allergies,
      allergiesNoneKnown: allergiesNoneKnown ?? this.allergiesNoneKnown,
      conditions: conditions ?? this.conditions,
      conditionsNoneKnown: conditionsNoneKnown ?? this.conditionsNoneKnown,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      notes: notes ?? this.notes,
      regularVetId: regularVetId,
      emergencyVetId: emergencyVetId,
    );
  }

  /// The same profile pointing at [vetId] for [role] (`null` clears it).
  HealthProfile withVet(VetRole role, String? vetId) => HealthProfile(
    petId: petId,
    microchip: microchip,
    notChipped: notChipped,
    allergies: allergies,
    allergiesNoneKnown: allergiesNoneKnown,
    conditions: conditions,
    conditionsNoneKnown: conditionsNoneKnown,
    contactName: contactName,
    contactPhone: contactPhone,
    notes: notes,
    regularVetId: role == VetRole.regular ? vetId : regularVetId,
    emergencyVetId: role == VetRole.emergency ? vetId : emergencyVetId,
  );
}

// ---------------------------------------------------------------------------
// Medicines, the care plan and what was actually done
// ---------------------------------------------------------------------------

/// A medicine with the vet's instructions, stored exactly as the owner
/// typed them. The app never interprets or suggests a dose.
class Medication {
  const Medication({
    required this.id,
    required this.petId,
    required this.name,
    this.strength = '',
    this.dose = '',
    this.route = '',
    this.frequency = '',
    this.startsOn,
    this.endsOn,
    this.prescribedBy = '',
    this.instructions = '',
  });

  final String id;
  final String petId;
  final String name;
  final String strength;
  final String dose;

  /// How it is given ("By mouth", "In the ear"...).
  final String route;

  /// How often, in the vet's words.
  final String frequency;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String prescribedBy;
  final String instructions;

  bool get isNew => id.isEmpty;

  /// "Joint tablets 50 mg".
  String get displayName =>
      strength.trim().isEmpty ? name : '$name ${strength.trim()}';

  /// "1 tablet by mouth, twice a day with food": what the owner typed,
  /// joined. Empty when nothing was entered.
  String get instructionLine {
    final how = [
      if (dose.trim().isNotEmpty) dose.trim(),
      if (route.trim().isNotEmpty)
        dose.trim().isEmpty ? route.trim() : route.trim().toLowerCase(),
    ].join(' ');
    final often = frequency.trim();
    if (how.isEmpty) return often;
    if (often.isEmpty) return how;
    return '$how, ${often[0].toLowerCase()}${often.substring(1)}';
  }

  /// Whether the medicine is being given on [day].
  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    final start = startsOn;
    final end = endsOn;
    if (start != null && d.isBefore(dateOnly(start))) return false;
    if (end != null && d.isAfter(dateOnly(end))) return false;
    return true;
  }

  Medication copyWith({String? id}) => Medication(
    id: id ?? this.id,
    petId: petId,
    name: name,
    strength: strength,
    dose: dose,
    route: route,
    frequency: frequency,
    startsOn: startsOn,
    endsOn: endsOn,
    prescribedBy: prescribedBy,
    instructions: instructions,
  );
}

/// What a recurring care item is. [dbValue] is `care_plan_items.kind`.
enum CareKind {
  medication('medication', 'Medicine'),
  feeding('feeding', 'Feeding'),
  walk('walk', 'Walk'),
  grooming('grooming', 'Grooming'),
  cleaning('cleaning', 'Cleaning'),

  /// Scooping the litter box (cats).
  litterCleaning('litter_cleaning', 'Litter box cleaning'),

  /// Replacing the litter (cats).
  litterChange('litter_change', 'Litter change'),

  /// Cleaning the cage, hutch, tank or enclosure (cage animals).
  cageCleaning('cage_cleaning', 'Cage cleaning'),
  other('other', 'Other');

  const CareKind(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static CareKind fromDb(String? value) => CareKind.values.firstWhere(
    (k) => k.dbValue == value,
    orElse: () => CareKind.other,
  );
}

/// One recurring reminder: a routine (feeding, walk...) or one reminder
/// time of a medicine. It repeats at [time] on the weekdays in [days].
class CarePlanItem {
  const CarePlanItem({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.time,
    this.days = everyDay,
    this.medicationId,
    this.startsOn,
    this.endsOn,
    this.active = true,
  });

  static const everyDay = {1, 2, 3, 4, 5, 6, 7};

  final String id;
  final String petId;
  final CareKind kind;
  final String title;
  final TimeOfDay time;

  /// ISO weekdays: Monday = 1 ... Sunday = 7.
  final Set<int> days;

  /// The medicine this reminder belongs to, for [CareKind.medication].
  final String? medicationId;

  /// First day the reminder counts from: earlier days never "need review".
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// Paused reminders stay in the plan but are not due.
  final bool active;

  bool get isNew => id.isEmpty;
  bool get isMedication => kind == CareKind.medication;

  /// Whether the item is due on [day].
  bool occursOn(DateTime day) {
    if (!active || !days.contains(day.weekday)) return false;
    final d = dateOnly(day);
    final start = startsOn;
    final end = endsOn;
    if (start != null && d.isBefore(dateOnly(start))) return false;
    if (end != null && d.isAfter(dateOnly(end))) return false;
    return true;
  }

  CarePlanItem copyWith({
    String? id,
    CareKind? kind,
    String? title,
    TimeOfDay? time,
    Set<int>? days,
    String? medicationId,
    DateTime? startsOn,
    bool? active,
  }) {
    return CarePlanItem(
      id: id ?? this.id,
      petId: petId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      time: time ?? this.time,
      days: days ?? this.days,
      medicationId: medicationId ?? this.medicationId,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn,
      active: active ?? this.active,
    );
  }
}

/// The owner's answer for one occurrence. [dbValue] is `care_logs.status`.
enum CareLogStatus {
  /// Done, or for a medicine: the dose was given.
  done('done'),

  /// Deliberately not done / not given.
  skipped('skipped'),

  /// The owner does not know. Recorded so the reminder stops asking,
  /// without claiming anything about the dose.
  unknown('unknown');

  const CareLogStatus(this.dbValue);

  final String dbValue;

  static CareLogStatus fromDb(String? value) => CareLogStatus.values.firstWhere(
    (s) => s.dbValue == value,
    orElse: () => CareLogStatus.unknown,
  );
}

/// What actually happened for one occurrence of a care plan item, or a
/// dose of an "as needed" medicine ([planItemId] is `null`). Kept separate
/// from the reminder: a reminder nobody answered has no log, and is never
/// treated as a missed dose.
class CareLog {
  const CareLog({
    required this.id,
    required this.petId,
    required this.title,
    required this.dueOn,
    required this.status,
    required this.loggedAt,
    this.planItemId,
    this.medicationId,
    this.dueTime,
    this.doneAt,
    this.note = '',
    this.loggedByName = '',
    this.kind,
    this.amountGrams,
    this.calories,
    this.minutes,
  });

  final String id;
  final String petId;
  final String? planItemId;
  final String? medicationId;

  /// What an entry without a reminder is: an extra meal
  /// ([CareKind.feeding]) or an extra walk or play ([CareKind.walk]).
  /// `null` for a reminder's answer and for a medicine dose.
  final CareKind? kind;

  /// How much a meal was, and its calories, when the owner said.
  final double? amountGrams;
  final int? calories;

  /// How long a walk or a play session lasted, in minutes.
  final int? minutes;

  /// The item's title when it was logged (kept if the item is deleted).
  final String title;

  /// The day the occurrence was due.
  final DateTime dueOn;
  final TimeOfDay? dueTime;
  final CareLogStatus status;

  /// When it was actually done / given, for [CareLogStatus.done].
  final DateTime? doneAt;
  final String note;

  /// Who recorded it, and when.
  final String loggedByName;
  final DateTime loggedAt;

  bool get isNew => id.isEmpty;

  CareLog copyWith({String? id}) => CareLog(
    id: id ?? this.id,
    petId: petId,
    planItemId: planItemId,
    medicationId: medicationId,
    title: title,
    dueOn: dueOn,
    dueTime: dueTime,
    status: status,
    doneAt: doneAt,
    note: note,
    loggedByName: loggedByName,
    loggedAt: loggedAt,
    kind: kind,
    amountGrams: amountGrams,
    calories: calories,
    minutes: minutes,
  );
}

// ---------------------------------------------------------------------------
// Observations (the Quick log journal; weight is one of them)
// ---------------------------------------------------------------------------

/// The owner's simple answer. [dbValue] is `health_observations.level`.
enum ObservationLevel {
  usual('usual', 'Usual'),
  less('less', 'Less than usual'),
  more('more', 'More than usual'),
  different('different', 'Different from usual'),
  unsure('unsure', 'Not sure');

  const ObservationLevel(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static ObservationLevel? fromDb(String? value) {
    for (final level in ObservationLevel.values) {
      if (level.dbValue == value) return level;
    }
    return null;
  }
}

/// Something the owner noticed and logged. A weight measurement is the
/// observation with category [weightCategory] and a [value] in kilograms.
class Observation {
  const Observation({
    required this.id,
    required this.petId,
    required this.category,
    required this.observedAt,
    this.level,
    this.value,
    this.note = '',
  });

  static const weightCategory = 'weight';

  final String id;
  final String petId;

  /// A category key from the species settings ("appetite", "feathers"...).
  final String category;
  final ObservationLevel? level;

  /// A measurement. For weight: kilograms, whatever unit is displayed.
  final double? value;
  final String note;
  final DateTime observedAt;

  bool get isNew => id.isEmpty;
  bool get isWeight => category == weightCategory && value != null;

  Observation copyWith({String? id}) => Observation(
    id: id ?? this.id,
    petId: petId,
    category: category,
    level: level,
    value: value,
    note: note,
    observedAt: observedAt,
  );
}

// ---------------------------------------------------------------------------
// The emergency kit: what is ready for a siren or for leaving in a hurry
// ---------------------------------------------------------------------------

/// One line of a pet's emergency kit. [dbValue] is `emergency_kit_items.item`.
enum KitItem {
  /// A carrier, crate or travel cage (and the lead, for a dog).
  carrier('carrier'),
  foodWater('food_water'),
  documents('documents'),
  microchip('microchip'),

  /// Only part of the kit while the pet has an active medicine.
  medicines('medicines'),

  /// The plan for the protected room during sirens.
  shelterPlan('shelter_plan');

  const KitItem(this.dbValue);

  final String dbValue;

  static KitItem? fromDb(String? value) {
    for (final item in KitItem.values) {
      if (item.dbValue == value) return item;
    }
    return null;
  }
}

/// The owner's answer for one kit item: ticked (and when), and a note.
class KitCheck {
  const KitCheck({
    required this.petId,
    required this.item,
    this.checkedAt,
    this.note = '',
  });

  final String petId;
  final KitItem item;

  /// When the owner ticked it, or `null` while it is not ready.
  final DateTime? checkedAt;

  /// Free text; used for the plan for the protected room.
  final String note;

  bool get isReady => checkedAt != null;
}

// ---------------------------------------------------------------------------
// The "my pet is lost" card
// ---------------------------------------------------------------------------

/// The language of the card's few fixed words. The card is read by
/// neighbours, not by the app's user, so it has its own language.
/// [code] is `lost_pet_cards.language`.
enum LostCardLanguage {
  hebrew('he', 'Hebrew'),
  english('en', 'English');

  const LostCardLanguage(this.code, this.label);

  final String code;

  /// Its English name, for logs. The switch on the page names a language
  /// in its own letters (`nativeLanguageName`).
  final String label;

  static LostCardLanguage fromCode(String? code) => LostCardLanguage.values
      .firstWhere((l) => l.code == code, orElse: () => LostCardLanguage.hebrew);
}

/// What the owner wrote for a pet's lost card, kept so nothing is retyped.
/// The app never posts it anywhere: it only builds a picture to share.
class LostPetCard {
  const LostPetCard({
    required this.petId,
    this.description = '',
    this.area = '',
    this.lastSeenAt,
    this.phone = '',
    this.extra = '',
    this.language = LostCardLanguage.hebrew,
    this.foundAt,
  });

  final String petId;

  /// What the pet looks like, in the owner's words.
  final String description;

  /// A general area, typed by the owner. Never filled from a saved address.
  final String area;
  final DateTime? lastSeenAt;

  /// The owner's phone number, shown on the card only after they confirm it.
  final String phone;

  /// One more line ("needs a daily medicine").
  final String extra;
  final LostCardLanguage language;

  /// When the pet came back home, or `null` while it is still looked for.
  final DateTime? foundAt;
}
