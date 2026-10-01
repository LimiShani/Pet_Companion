import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import 'data/health_models.dart';
import 'data/species_settings.dart';
import 'state/health_costs.dart';

/// The bridge between Health's values and its words.
///
/// The words themselves live in `l10n/health_en.arb` and `l10n/health_he.arb`
/// (see `lib/l10n/GLOSSARY.md`); in a widget they are `context.healthL10n`.
/// What is stored in the database (a kind of record, a kind of routine, an
/// answer, a reason for failure) stays a key, and is put into words here in
/// the language on screen.
extension HealthWords on HealthL10n {
  /// "Vet visit", "Vaccination"...: one record.
  String recordKind(RecordKind kind) => switch (kind) {
    RecordKind.checkup => kindCheckup,
    RecordKind.vaccination => kindVaccination,
    RecordKind.preventive => kindPreventive,
    RecordKind.procedure => kindProcedure,
    RecordKind.medicine => kindMedicine,
    RecordKind.document => kindDocument,
    RecordKind.other => kindOther,
  };

  /// "Vet visits", "Vaccinations"...: the filter chip of the History.
  String recordKinds(RecordKind kind) => switch (kind) {
    RecordKind.checkup => vetVisits,
    RecordKind.vaccination => vaccinations,
    RecordKind.preventive => kindsPreventive,
    RecordKind.procedure => kindsProcedure,
    RecordKind.medicine => kindsMedicine,
    RecordKind.document => documents,
    RecordKind.other => notes,
  };

  /// What a health cost was for (for a Budget module).
  String costCategory(HealthCostCategory category) => switch (category) {
    HealthCostCategory.vetVisit => vetVisits,
    HealthCostCategory.vaccination => vaccinations,
    HealthCostCategory.preventive => kindsPreventive,
    HealthCostCategory.procedure => kindsProcedure,
    HealthCostCategory.medicine => kindsMedicine,
    HealthCostCategory.other => careOther,
  };

  /// "Feeding", "Walk"...: a kind of routine.
  String careKind(CareKind kind) => switch (kind) {
    CareKind.medication => medicine,
    CareKind.feeding => careFeeding,
    CareKind.walk => careWalk,
    CareKind.grooming => careGrooming,
    CareKind.cleaning => careCleaning,
    CareKind.litterCleaning => careLitterCleaning,
    CareKind.litterChange => careLitterChange,
    CareKind.cageCleaning => careCageCleaning,
    CareKind.other => careOther,
  };

  /// What a kind of routine is called for one species: "Cage cleaning", or
  /// "Enclosure cleaning" for a reptile.
  String routineKind(SpeciesSettings settings, CareKind kind) =>
      kind == CareKind.cageCleaning && settings.cageIsEnclosure ? careEnclosureCleaning : careKind(kind);

  /// "Regular vet", "Emergency vet (24 h)".
  String vetRole(VetRole role) => switch (role) {
    VetRole.regular => vetRoleRegular,
    VetRole.emergency => vetRoleEmergency,
  };

  /// "Usual", "Less than usual"...: the owner's answer in the Quick log.
  String level(ObservationLevel level) => switch (level) {
    ObservationLevel.usual => levelUsual,
    ObservationLevel.less => levelLess,
    ObservationLevel.more => levelMore,
    ObservationLevel.different => levelDifferent,
    ObservationLevel.unsure => notSure,
  };

  String quickLogGroup(QuickLogGroup group) => switch (group) {
    QuickLogGroup.body => groupBody,
    QuickLogGroup.behaviour => groupBehaviour,
  };

  /// "Appetite", "Barking"...: a category of the Quick log. A category the
  /// app has no name for (its key was logged by another version) is called
  /// what its key says.
  String quickLogCategory(QuickLogCategory category) => switch (category.name) {
    null => category.label,
    QuickLogName.weight => weight,
    QuickLogName.appetite => logAppetite,
    QuickLogName.energy => logEnergy,
    QuickLogName.mobility => logMobility,
    QuickLogName.digestion => logDigestion,
    QuickLogName.skinCoat => logSkinCoat,
    QuickLogName.dental => logDental,
    QuickLogName.drinking => logDrinking,
    QuickLogName.diet => logDiet,
    QuickLogName.droppings => logDroppings,
    QuickLogName.feathers => logFeathers,
    QuickLogName.activity => logActivity,
    QuickLogName.environment => logEnvironment,
    QuickLogName.eating => logEating,
    QuickLogName.feeding => logFeeding,
    QuickLogName.shedding => logShedding,
    QuickLogName.temperature => logTemperature,
    QuickLogName.humidity => logHumidity,
    QuickLogName.lighting => logLighting,
    QuickLogName.other => logOther,
    QuickLogName.sleep => logSleep,
    QuickLogName.barking => logBarking,
    QuickLogName.meowing => logMeowing,
    QuickLogName.vocalisation => logVocalisation,
    QuickLogName.biting => logBiting,
    QuickLogName.bitingScratching => logBitingScratching,
    QuickLogName.leftAlone => logLeftAlone,
    QuickLogName.litterBox => logLitterBox,
    QuickLogName.otherBehaviour => logOtherBehaviour,
  };

  /// How a medicine is given. One of the offered ways is stored under its
  /// English name ([medicineRoutes]) and said in the language on screen;
  /// anything else is what the owner typed, and is shown as typed.
  String medicineRoute(String stored) => switch (stored) {
    'By mouth' => routeByMouth,
    'On the skin' => routeOnSkin,
    'In the eye' => routeInEye,
    'In the ear' => routeInEar,
    'Injection' => routeInjection,
    'Other' => routeOther,
    _ => stored,
  };

  /// A short day name for a chip or a list of days: "Mon" / "ב׳". [weekday]
  /// is an ISO weekday (1 = Monday ... 7 = Sunday).
  String dayChip(int weekday) => switch (weekday) {
    DateTime.monday => dayMon,
    DateTime.tuesday => dayTue,
    DateTime.wednesday => dayWed,
    DateTime.thursday => dayThu,
    DateTime.friday => dayFri,
    DateTime.saturday => daySat,
    _ => daySun,
  };

  /// "3 of 6 ready", or "All 6 ready".
  String kitCount({required int ready, required int total}) =>
      ready == total ? kitAllReady(total) : kitSomeReady(ready, total);

  /// "Given 08:05", "Not given" or "Not sure", for the dose log. [givenAt]
  /// is the time already formatted, when there is one.
  String doseStatus(CareLogStatus status, {String? givenAtTime}) => switch (status) {
    CareLogStatus.done => givenAtTime == null ? given : givenAt(givenAtTime),
    CareLogStatus.skipped => notGiven,
    CareLogStatus.unknown => notSure,
  };

  /// The reason a failure gives, in words.
  String failure(HealthFailure failure, AppL10n app) => switch (failure) {
    HealthFailure.offline => errOffline,
    HealthFailure.sessionEnded => errSessionEnded,
    HealthFailure.notAllowed => errNotAllowed,
    HealthFailure.invalid => errInvalid,
    HealthFailure.petNotStored => errPetNotStored,
    HealthFailure.petGone => errPetGone,
    HealthFailure.itemGone => errItemGone,
    HealthFailure.recordGone => errRecordGone,
    HealthFailure.vetGone => errVetGone,
    HealthFailure.medicineGone => errMedicineGone,
    HealthFailure.reminderGone => errReminderGone,
    HealthFailure.entryGone => errEntryGone,
    HealthFailure.fileType => errFileType,
    HealthFailure.fileEmpty => errFileEmpty,
    HealthFailure.fileTooLarge => errFileTooLarge,
    HealthFailure.fileGone => errFileGone,
    HealthFailure.fileNotStored => errFileNotStored,
    HealthFailure.fileUnreadable => errFileUnreadable,
    HealthFailure.camera => errCamera,
    HealthFailure.photos => errPhotos,
    HealthFailure.files => errFiles,
    HealthFailure.pdf => errPdf,
    HealthFailure.lostCard => errLostCard,
    HealthFailure.unknown => app.errorGeneric,
  };
}

/// The ways a medicine is given, offered as chips. These English names are
/// what is stored; `HealthWords.medicineRoute` says them on screen.
const medicineRoutes = ['By mouth', 'On the skin', 'In the eye', 'In the ear', 'Injection', 'Other'];

/// What to tell the owner about a Health failure, in the language of the
/// given strings. The repositories only report the reason (see
/// [HealthFailure]); the words are put here.
String healthErrorText(HealthL10n l10n, AppL10n app, Object? error) {
  if (error is FollowUpNotSaved) {
    return l10n.savedButNextDueNotPlanned(healthErrorText(l10n, app, error.cause));
  }
  if (error is! HealthException) return app.errorGeneric;
  if (error.failure != HealthFailure.unknown) return l10n.failure(error.failure, app);
  // Words from elsewhere (another feature, a test) are in English: shown as
  // they are on an English screen, replaced by a plain line otherwise.
  return l10n.localeName == 'en' ? error.message : app.errorGeneric;
}

/// [healthErrorText] in the language of the screen [context] is on.
String healthErrorOf(BuildContext context, Object? error) => healthErrorText(context.healthL10n, context.l10n, error);
