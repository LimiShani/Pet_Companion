import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../config/app_config.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../data/fake_health_repository.dart';
import '../data/health_models.dart';
import '../data/health_repository.dart';
import '../data/reminder_scheduler.dart';
import 'schedule_logic.dart';

/// The day the sample data lives on: the home dashboard shows "General
/// check 12.06.25" and "Medicine 27.07.25" as upcoming, so the sample
/// records only make sense around this date.
final sampleDataDay = DateTime(2025, 6, 10);

/// [sampleDataDay] at the real time of day, so "what is next today" stays
/// alive while the dates stay in step with the sample data.
DateTime sampleDataNow() {
  final now = DateTime.now();
  return DateTime(sampleDataDay.year, sampleDataDay.month, sampleDataDay.day, now.hour, now.minute, now.second);
}

/// "Now" for everything time-related in Health. Real accounts use the real
/// clock; the sample data uses [sampleDataNow]. Tests override it with a
/// fixed instant.
final healthClockProvider = Provider<DateTime Function()>(
  (ref) => AppConfig.hasSupabase ? DateTime.now : sampleDataNow,
);

/// The health backend: the in-memory sample data.
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => FakeHealthRepository(now: ref.watch(healthClockProvider)),
);

/// User-facing text for a Health failure.
String healthErrorMessage(Object error) =>
    error is HealthException ? error.message : 'Something went wrong. Please try again.';

// Riverpod retries failed providers on its own by default; Health shows the
// failure with a "Try again" button instead.
Duration? _noRetry(int retryCount, Object error) => null;

String? _watchUserId(Ref ref) => ref.watch(authControllerProvider.select((auth) => auth.value?.id));

/// The name recorded next to a logged dose.
String _userName(Ref ref) {
  final name = ref.read(authControllerProvider).value?.displayName.trim() ?? '';
  return name.isEmpty ? 'You' : name;
}

Pet? _pet(Ref ref, String petId) {
  for (final pet in ref.read(petsProvider)) {
    if (pet.id == petId) return pet;
  }
  return null;
}

/// Hands the pet's current plan to the [ReminderScheduler]. Called whenever
/// the care plan or the planned records are loaded or change.
///
/// A controller passes its own new state ([plan] or [records]); the other
/// half is read only if that provider is already alive.
void _syncReminders(Ref ref, String petId, {CarePlan? plan, List<HealthRecord>? records}) {
  plan ??= ref.exists(carePlanProvider(petId)) ? ref.read(carePlanProvider(petId)).value : null;
  records ??= ref.exists(healthRecordsProvider(petId)) ? ref.read(healthRecordsProvider(petId)).value : null;
  final now = ref.read(healthClockProvider)();
  final scheduler = ref.read(reminderSchedulerProvider);
  scheduler.sync(
    ReminderPlan(
      petId: petId,
      petName: _pet(ref, petId)?.name ?? '',
      items: [
        for (final item in plan?.items ?? const <CarePlanItem>[])
          if (item.active) item,
      ],
      upcoming: [
        for (final record in records ?? const <HealthRecord>[])
          if (!record.isDone && record.scheduledAt.isAfter(now)) record,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Which section of the tab is showing
// ---------------------------------------------------------------------------

/// The Health tab's four sections, in the order of the switcher.
enum HealthSection {
  overview('Overview'),
  schedule('Schedule'),
  history('History'),
  insights('Insights');

  const HealthSection(this.label);

  final String label;
}

class HealthSectionController extends Notifier<HealthSection> {
  @override
  HealthSection build() => HealthSection.overview;

  void show(HealthSection section) => state = section;
}

final healthSectionProvider = NotifierProvider<HealthSectionController, HealthSection>(HealthSectionController.new);

/// What the History timeline is narrowed to.
class HistoryFilter {
  const HistoryFilter({this.kind, this.documentsOnly = false, this.query = ''});

  /// Only this kind, or every kind when `null`.
  final RecordKind? kind;

  /// Only records that carry a file.
  final bool documentsOnly;
  final String query;

  bool get isEmpty => kind == null && !documentsOnly && query.trim().isEmpty;

  /// Whether [record] passes the filter. [hasFiles]: a photo or a PDF is
  /// attached to it. The search looks at everything the owner typed.
  bool matches(HealthRecord record, {required bool hasFiles}) {
    if (kind != null && record.kind != kind) return false;
    if (documentsOnly && !hasFiles && record.kind != RecordKind.document) return false;
    final words = query.trim().toLowerCase();
    if (words.isEmpty) return true;
    final text = [
      record.title,
      record.notes,
      record.clinic,
      record.productName,
      record.kind.label,
    ].join(' | ').toLowerCase();
    return words.split(RegExp(r'\s+')).every(text.contains);
  }
}

class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() {
    // A different pet starts unfiltered.
    ref.watch(selectedPetIdProvider);
    return const HistoryFilter();
  }

  void showAll() => state = HistoryFilter(query: state.query);
  void showKind(RecordKind kind) => state = HistoryFilter(kind: kind, query: state.query);
  void showDocuments() => state = HistoryFilter(documentsOnly: true, query: state.query);
  void search(String query) =>
      state = HistoryFilter(kind: state.kind, documentsOnly: state.documentsOnly, query: query);
  void clear() => state = const HistoryFilter();
}

final historyFilterProvider = NotifierProvider<HistoryFilterController, HistoryFilter>(HistoryFilterController.new);

// ---------------------------------------------------------------------------
// Health records and their documents
// ---------------------------------------------------------------------------

/// A pet's health records: the history and the planned ones.
class RecordsController extends AsyncNotifier<List<HealthRecord>> {
  RecordsController(this.petId);

  final String petId;

  HealthRepository get _repo => ref.read(healthRepositoryProvider);

  @override
  Future<List<HealthRecord>> build() {
    listenSelf((_, next) {
      if (next.hasValue) _syncReminders(ref, petId, records: next.value);
    });
    return ref.watch(healthRepositoryProvider).fetchRecords(petId);
  }

  void _put(HealthRecord record) {
    if (!ref.mounted) return;
    final current = state.value ?? const <HealthRecord>[];
    state = AsyncData([
      for (final r in current)
        if (r.id != record.id) r,
      record,
    ]);
  }

  void _drop(String id) {
    if (!ref.mounted) return;
    state = AsyncData([
      for (final r in state.value ?? const <HealthRecord>[])
        if (r.id != id) r,
    ]);
  }

  /// Creates or updates a record, and keeps the planned follow-up of its
  /// "next due" date in step. Throws a [HealthException] on failure.
  Future<HealthRecord> save(HealthRecord record) async {
    final saved = await _repo.saveRecord(record);
    _put(saved);
    await _syncFollowUp(saved);
    return saved;
  }

  /// A done vaccination or preventive treatment with a "next due" date has
  /// one planned record on that date, so it shows in the Schedule.
  Future<void> _syncFollowUp(HealthRecord saved) async {
    HealthRecord? planned;
    for (final r in state.value ?? const <HealthRecord>[]) {
      if (r.followUpOf == saved.id && !r.isDone) planned = r;
    }
    final due = saved.isDone && saved.kind.hasNextDue ? saved.nextDueOn : null;
    if (due == null) {
      if (planned != null) {
        await _repo.deleteRecord(planned.id);
        _drop(planned.id);
      }
      return;
    }
    if (planned == null) {
      _put(
        await _repo.saveRecord(
          HealthRecord(
            id: '',
            petId: petId,
            kind: saved.kind,
            title: saved.title,
            scheduledAt: DateTime(due.year, due.month, due.day, 9),
            clinic: saved.clinic,
            productName: saved.productName,
            followUpOf: saved.id,
          ),
        ),
      );
    } else if (!isSameDay(planned.scheduledAt, due)) {
      final at = planned.scheduledAt;
      _put(
        await _repo.saveRecord(
          planned.copyWith(scheduledAt: DateTime(due.year, due.month, due.day, at.hour, at.minute)),
        ),
      );
    }
  }

  /// Marks a planned record as done at [at], or plans it again (`null`).
  Future<HealthRecord> setDone(HealthRecord record, DateTime? at) => save(record.withDone(at));

  /// Deletes a record, its documents and its planned follow-up.
  Future<void> delete(HealthRecord record) async {
    final followUps = [
      for (final r in state.value ?? const <HealthRecord>[])
        if (r.followUpOf == record.id && !r.isDone) r,
    ];
    await _repo.deleteRecord(record.id);
    _drop(record.id);
    for (final followUp in followUps) {
      await _repo.deleteRecord(followUp.id);
      _drop(followUp.id);
    }
    if (ref.mounted) ref.invalidate(healthDocumentsProvider(petId));
  }
}

final healthRecordsProvider = AsyncNotifierProvider.autoDispose.family<RecordsController, List<HealthRecord>, String>(
  RecordsController.new,
  retry: _noRetry,
);

/// The files attached to a pet's records.
class DocumentsController extends AsyncNotifier<List<HealthDocument>> {
  DocumentsController(this.petId);

  final String petId;

  @override
  Future<List<HealthDocument>> build() => ref.watch(healthRepositoryProvider).fetchDocuments(petId);

  /// Attaches [file] to a record. Throws a [HealthException] when the file
  /// is not allowed or cannot be stored.
  Future<HealthDocument> add(String recordId, PickedFile file) async {
    final problem = file.problem;
    if (problem != null) throw HealthException(problem);
    final doc = await ref.read(healthRepositoryProvider).addDocument(petId: petId, recordId: recordId, file: file);
    if (ref.mounted) state = AsyncData([...?state.value, doc]);
    return doc;
  }

  Future<void> remove(HealthDocument document) async {
    await ref.read(healthRepositoryProvider).deleteDocument(document);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final d in state.value ?? const <HealthDocument>[])
        if (d.id != document.id) d,
    ]);
  }
}

final healthDocumentsProvider = AsyncNotifierProvider.autoDispose
    .family<DocumentsController, List<HealthDocument>, String>(DocumentsController.new, retry: _noRetry);

// ---------------------------------------------------------------------------
// Vets and the health profile
// ---------------------------------------------------------------------------

/// The signed-in owner's vets, shared by all their pets.
class VetsController extends AsyncNotifier<List<Vet>> {
  @override
  Future<List<Vet>> build() {
    _watchUserId(ref);
    return ref.watch(healthRepositoryProvider).fetchVets();
  }

  Future<Vet> save(Vet vet) async {
    final saved = await ref.read(healthRepositoryProvider).saveVet(vet);
    if (ref.mounted) {
      state = AsyncData([
        for (final v in state.value ?? const <Vet>[])
          if (v.id != saved.id) v,
        saved,
      ]);
    }
    return saved;
  }

  /// Deletes a vet; pets that used it have no vet afterwards.
  Future<void> delete(String vetId) async {
    await ref.read(healthRepositoryProvider).deleteVet(vetId);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final v in state.value ?? const <Vet>[])
        if (v.id != vetId) v,
    ]);
    ref.invalidate(healthProfileProvider);
  }
}

final vetsProvider = AsyncNotifierProvider.autoDispose<VetsController, List<Vet>>(VetsController.new, retry: _noRetry);

/// One pet's health profile (an empty one until something is saved).
class ProfileController extends AsyncNotifier<HealthProfile> {
  ProfileController(this.petId);

  final String petId;

  @override
  Future<HealthProfile> build() => ref.watch(healthRepositoryProvider).fetchProfile(petId);

  Future<HealthProfile> save(HealthProfile profile) async {
    final saved = await ref.read(healthRepositoryProvider).saveProfile(profile);
    if (ref.mounted) state = AsyncData(saved);
    return saved;
  }

  /// Points the pet at [vetId] for [role]; `null` removes the link.
  Future<HealthProfile> setVet(VetRole role, String? vetId) async {
    final current = state.value ?? await future;
    return save(current.withVet(role, vetId));
  }
}

final healthProfileProvider = AsyncNotifierProvider.autoDispose.family<ProfileController, HealthProfile, String>(
  ProfileController.new,
  retry: _noRetry,
);

/// A pet's two vets, resolved from its profile and the owner's vets.
class PetVets {
  const PetVets({this.regular, this.emergency, this.saved = const []});

  final Vet? regular;
  final Vet? emergency;

  /// Every vet the owner has saved (for "use a saved vet").
  final List<Vet> saved;

  Vet? of(VetRole role) => role == VetRole.regular ? regular : emergency;
  bool get isEmpty => regular == null && emergency == null;
}

Vet? _vetById(List<Vet> vets, String? id) {
  if (id == null) return null;
  for (final vet in vets) {
    if (vet.id == id) return vet;
  }
  return null;
}

final petVetsProvider = FutureProvider.autoDispose.family<PetVets, String>((ref, petId) async {
  final vetsFuture = ref.watch(vetsProvider.future);
  final profileFuture = ref.watch(healthProfileProvider(petId).future);
  final vets = await vetsFuture;
  final profile = await profileFuture;
  return PetVets(
    regular: _vetById(vets, profile.regularVetId),
    emergency: _vetById(vets, profile.emergencyVetId),
    saved: vets,
  );
}, retry: _noRetry);

// ---------------------------------------------------------------------------
// Medicines, routines and the log of what was done
// ---------------------------------------------------------------------------

/// How far back the log of done / given entries is loaded.
const _logWindowDays = 45;

class CarePlanController extends AsyncNotifier<CarePlan> {
  CarePlanController(this.petId);

  final String petId;

  HealthRepository get _repo => ref.read(healthRepositoryProvider);

  @override
  Future<CarePlan> build() async {
    listenSelf((_, next) {
      if (next.hasValue) _syncReminders(ref, petId, plan: next.value);
    });
    final repo = ref.watch(healthRepositoryProvider);
    final today = dateOnly(ref.watch(healthClockProvider)());
    // Waited for together, so a failure of one never leaves the others
    // failing unobserved.
    final results = await Future.wait<Object>([
      repo.fetchMedications(petId),
      repo.fetchPlanItems(petId),
      repo.fetchLogs(petId, from: today.subtract(const Duration(days: _logWindowDays))),
    ]);
    return CarePlan(
      medications: results[0] as List<Medication>,
      items: results[1] as List<CarePlanItem>,
      logs: results[2] as List<CareLog>,
    );
  }

  CarePlan get _plan => state.value ?? const CarePlan();

  void _set(CarePlan plan) {
    if (ref.mounted) state = AsyncData(plan);
  }

  /// Creates or updates a medicine and makes its reminders match [times]
  /// on [days]. An empty [times] is a medicine given only when needed.
  Future<Medication> saveMedication(
    Medication medication, {
    required List<TimeOfDay> times,
    Set<int> days = CarePlanItem.everyDay,
  }) async {
    final saved = await _repo.saveMedication(medication);
    final today = dateOnly(ref.read(healthClockProvider)());
    final existing = _plan.itemsOf(saved.id);
    final wanted = {for (final t in times) minutesOf(t): t};
    final kept = <CarePlanItem>[];

    for (final item in existing) {
      final minutes = minutesOf(item.time);
      if (!wanted.containsKey(minutes)) {
        await _repo.deletePlanItem(item.id);
        continue;
      }
      wanted.remove(minutes);
      final same = item.title == saved.name && item.days.length == days.length && item.days.containsAll(days);
      kept.add(same ? item : await _repo.savePlanItem(item.copyWith(title: saved.name, days: days)));
    }
    for (final time in wanted.values) {
      kept.add(
        await _repo.savePlanItem(
          CarePlanItem(
            id: '',
            petId: petId,
            kind: CareKind.medication,
            title: saved.name,
            time: time,
            days: days,
            medicationId: saved.id,
            // Reminders count from the day they are set up, so an older start
            // date of the medicine never creates reminders "needing review".
            startsOn: today,
          ),
        ),
      );
    }

    final plan = _plan;
    _set(
      plan.copyWith(
        medications: [
          for (final m in plan.medications)
            if (m.id != saved.id) m,
          saved,
        ],
        items: [
          for (final i in plan.items)
            if (i.medicationId != saved.id) i,
          ...kept,
        ],
      ),
    );
    return saved;
  }

  /// Deletes a medicine with its reminders and its dose log.
  Future<void> deleteMedication(String medicationId) async {
    await _repo.deleteMedication(medicationId);
    final plan = _plan;
    _set(
      CarePlan(
        medications: [
          for (final m in plan.medications)
            if (m.id != medicationId) m,
        ],
        items: [
          for (final i in plan.items)
            if (i.medicationId != medicationId) i,
        ],
        logs: [
          for (final l in plan.logs)
            if (l.medicationId != medicationId) l,
        ],
      ),
    );
  }

  /// Creates or updates a routine (feeding, walk...).
  Future<CarePlanItem> saveRoutine(CarePlanItem item) async {
    final today = dateOnly(ref.read(healthClockProvider)());
    final saved = await _repo.savePlanItem(item.isNew ? item.copyWith(startsOn: today) : item);
    final plan = _plan;
    _set(
      plan.copyWith(
        items: [
          for (final i in plan.items)
            if (i.id != saved.id) i,
          saved,
        ],
      ),
    );
    return saved;
  }

  Future<void> deleteRoutine(String itemId) async {
    await _repo.deletePlanItem(itemId);
    final plan = _plan;
    _set(
      plan.copyWith(
        items: [
          for (final i in plan.items)
            if (i.id != itemId) i,
        ],
      ),
    );
  }

  /// Records the owner's answer for one occurrence of [item] due on
  /// [dueOn], or a dose of an "as needed" [medication] (no [item]). The
  /// signed-in user's name and the current time are stored with it.
  Future<CareLog> record({
    CarePlanItem? item,
    Medication? medication,
    required DateTime dueOn,
    required CareLogStatus status,
    DateTime? doneAt,
    String note = '',
  }) async {
    assert(item != null || medication != null, 'A log needs a plan item or a medicine.');
    final now = ref.read(healthClockProvider)();
    final saved = await _repo.saveLog(
      CareLog(
        id: '',
        petId: petId,
        planItemId: item?.id,
        medicationId: item?.medicationId ?? medication?.id,
        title: item?.title ?? medication?.name ?? '',
        dueOn: dateOnly(dueOn),
        dueTime: item?.time,
        status: status,
        doneAt: status == CareLogStatus.done ? (doneAt ?? now) : null,
        note: note.trim(),
        loggedByName: _userName(ref),
        loggedAt: now,
      ),
    );
    final plan = _plan;
    _set(
      plan.copyWith(
        logs: [
          for (final l in plan.logs)
            if (l.id != saved.id &&
                !(saved.planItemId != null && l.planItemId == saved.planItemId && isSameDay(l.dueOn, saved.dueOn)))
              l,
          saved,
        ],
      ),
    );
    return saved;
  }

  /// Removes an answer, so the occurrence is open again.
  Future<void> removeLog(CareLog log) async {
    await _repo.deleteLog(log.id);
    final plan = _plan;
    _set(
      plan.copyWith(
        logs: [
          for (final l in plan.logs)
            if (l.id != log.id) l,
        ],
      ),
    );
  }
}

final carePlanProvider = AsyncNotifierProvider.autoDispose.family<CarePlanController, CarePlan, String>(
  CarePlanController.new,
  retry: _noRetry,
);

// ---------------------------------------------------------------------------
// Observations (the Quick log journal, including weight)
// ---------------------------------------------------------------------------

class ObservationsController extends AsyncNotifier<List<Observation>> {
  ObservationsController(this.petId);

  final String petId;

  @override
  Future<List<Observation>> build() => ref.watch(healthRepositoryProvider).fetchObservations(petId);

  Future<Observation> save(Observation observation) async {
    final saved = await ref.read(healthRepositoryProvider).saveObservation(observation);
    if (ref.mounted) {
      state = AsyncData([
        for (final o in state.value ?? const <Observation>[])
          if (o.id != saved.id) o,
        saved,
      ]);
      _syncPetWeight();
    }
    return saved;
  }

  Future<void> delete(String observationId) async {
    await ref.read(healthRepositoryProvider).deleteObservation(observationId);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final o in state.value ?? const <Observation>[])
        if (o.id != observationId) o,
    ]);
    _syncPetWeight();
  }

  /// Keeps the weight on the pet's profile (the Home dashboard's pill) in
  /// step with the latest weigh-in.
  void _syncPetWeight() {
    final weights = weightEntries(state.value ?? const []);
    if (weights.isEmpty) return;
    final latest = weights.last.value!;
    final pet = _pet(ref, petId);
    if (pet == null || pet.weightKg == latest) return;
    ref.read(petsProvider.notifier).update(pet.copyWith(weightKg: latest));
  }
}

final observationsProvider = AsyncNotifierProvider.autoDispose
    .family<ObservationsController, List<Observation>, String>(ObservationsController.new, retry: _noRetry);

// ---------------------------------------------------------------------------
// The summary used by the Emergency card, the message to the vet and the PDF
// ---------------------------------------------------------------------------

/// The essentials about one pet, gathered from every part of Health.
class HealthSummary {
  const HealthSummary({
    required this.pet,
    required this.profile,
    this.ownerName = '',
    this.regularVet,
    this.emergencyVet,
    this.medications = const [],
    this.weightKg,
  });

  final Pet pet;
  final HealthProfile profile;

  /// The signed-in owner's name, for the greeting of a message.
  final String ownerName;
  final Vet? regularVet;
  final Vet? emergencyVet;

  /// Medicines being given today.
  final List<Medication> medications;

  /// The latest weigh-in, or the weight on the pet's profile.
  final double? weightKg;
}

final healthSummaryProvider = FutureProvider.autoDispose.family<HealthSummary, String>((ref, petId) async {
  final pet = ref.watch(
    petsProvider.select((pets) {
      for (final p in pets) {
        if (p.id == petId) return p;
      }
      return null;
    }),
  );
  if (pet == null) throw const HealthException('That pet is no longer in your list.');
  final owner = ref.watch(authControllerProvider.select((auth) => auth.value?.displayName ?? ''));
  final today = ref.watch(healthClockProvider)();

  final vetsFuture = ref.watch(petVetsProvider(petId).future);
  final profileFuture = ref.watch(healthProfileProvider(petId).future);
  final planFuture = ref.watch(carePlanProvider(petId).future);
  final observationsFuture = ref.watch(observationsProvider(petId).future);

  final vets = await vetsFuture;
  final profile = await profileFuture;
  final plan = await planFuture;
  final weights = weightEntries(await observationsFuture);

  return HealthSummary(
    pet: pet,
    profile: profile,
    ownerName: owner.trim(),
    regularVet: vets.regular,
    emergencyVet: vets.emergency,
    medications: plan.activeMedications(today),
    weightKg: weights.isEmpty ? pet.weightKg : weights.last.value,
  );
}, retry: _noRetry);

// ---------------------------------------------------------------------------
// Everything about one pet, for the tab's four sections
// ---------------------------------------------------------------------------

class PetHealthData {
  const PetHealthData({
    required this.records,
    required this.documents,
    required this.plan,
    required this.observations,
    required this.vets,
    required this.profile,
  });

  final List<HealthRecord> records;
  final List<HealthDocument> documents;
  final CarePlan plan;
  final List<Observation> observations;
  final PetVets vets;
  final HealthProfile profile;

  /// Nothing has been entered for this pet yet (the vets aside).
  bool get isEmpty => records.isEmpty && plan.isEmpty && observations.isEmpty;

  /// The documents attached to one record.
  List<HealthDocument> documentsOf(String recordId) => [
    for (final d in documents)
      if (d.recordId == recordId) d,
  ];
}

final petHealthDataProvider = FutureProvider.autoDispose.family<PetHealthData, String>((ref, petId) async {
  final records = ref.watch(healthRecordsProvider(petId).future);
  final documents = ref.watch(healthDocumentsProvider(petId).future);
  final plan = ref.watch(carePlanProvider(petId).future);
  final observations = ref.watch(observationsProvider(petId).future);
  final vets = ref.watch(petVetsProvider(petId).future);
  final profile = ref.watch(healthProfileProvider(petId).future);
  return PetHealthData(
    records: await records,
    documents: await documents,
    plan: await plan,
    observations: await observations,
    vets: await vets,
    profile: await profile,
  );
}, retry: _noRetry);

/// Removes every stored health file of a pet (photos and PDFs attached to
/// its records). Call it before deleting a pet: the database removes the
/// pet's rows by itself, but not its files. Throws a [HealthException] on
/// failure.
final removeHealthFilesForPetProvider = Provider<Future<void> Function(String petId)>((ref) {
  return (petId) async {
    await ref.read(healthRepositoryProvider).deleteFilesForPet(petId);
    if (ref.exists(healthDocumentsProvider(petId))) ref.invalidate(healthDocumentsProvider(petId));
  };
});

/// Loads everything about a pet again (the "Try again" button).
void refreshHealth(WidgetRef ref, String petId) {
  ref.invalidate(healthRecordsProvider(petId));
  ref.invalidate(healthDocumentsProvider(petId));
  ref.invalidate(carePlanProvider(petId));
  ref.invalidate(observationsProvider(petId));
  ref.invalidate(vetsProvider);
  ref.invalidate(healthProfileProvider(petId));
}
