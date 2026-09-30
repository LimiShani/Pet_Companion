import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'health_models.dart';
import 'health_repository.dart';

/// In-memory health data for development and tests. Nothing persists
/// across restarts.
///
/// Used automatically when the app is built without Supabase configuration.
/// Seeded for the sample pet `kelly` so it agrees with the home dashboard
/// (General check 12.06.25 18:20, Medicine 27.07.25 19:30, 23 kg, dinner at
/// 19:30, walk at 18:30); `soya` is left empty so the getting-started and
/// no-vet states show.
class FakeHealthRepository implements HealthRepository {
  FakeHealthRepository({this.latency = const Duration(milliseconds: 300), DateTime Function()? now, bool seeded = true})
    : _now = now ?? DateTime.now {
    if (seeded) _seed();
  }

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final DateTime Function() _now;

  /// Test hook: while true every call fails, as if the server were down.
  bool failing = false;

  static const kellyId = 'kelly';

  final _records = <HealthRecord>[];
  final _documents = <HealthDocument>[];
  final _documentBytes = <String, Uint8List>{};
  final _vets = <Vet>[];
  final _profiles = <String, HealthProfile>{};
  final _medications = <Medication>[];
  final _planItems = <CarePlanItem>[];
  final _logs = <CareLog>[];
  final _observations = <Observation>[];
  var _nextId = 1;

  String _id(String prefix) => '$prefix${_nextId++}';

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) throw const HealthException('Could not reach the server. Check your connection and try again.');
  }

  // --------------------------------------------------------------- records

  @override
  Future<List<HealthRecord>> fetchRecords(String petId) async {
    await _wait();
    return [
      for (final r in _records)
        if (r.petId == petId) r,
    ];
  }

  @override
  Future<HealthRecord> saveRecord(HealthRecord record) async {
    await _wait();
    if (record.isNew) {
      final stored = record.copyWith(id: _id('r'));
      _records.add(stored);
      return stored;
    }
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index < 0) throw const HealthException('That record no longer exists.');
    _records[index] = record;
    return record;
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await _wait();
    _records.removeWhere((r) => r.id == recordId);
    final gone = [
      for (final d in _documents)
        if (d.recordId == recordId) d.id,
    ];
    _documents.removeWhere((d) => d.recordId == recordId);
    gone.forEach(_documentBytes.remove);
  }

  // ------------------------------------------------------------- documents

  @override
  Future<List<HealthDocument>> fetchDocuments(String petId) async {
    await _wait();
    return [
      for (final d in _documents)
        if (d.petId == petId) d,
    ];
  }

  @override
  Future<HealthDocument> addDocument({
    required String petId,
    required String recordId,
    required PickedFile file,
  }) async {
    await _wait();
    final problem = file.problem;
    if (problem != null) throw HealthException(problem);
    final doc = HealthDocument(
      id: _id('d'),
      petId: petId,
      recordId: recordId,
      fileName: file.name,
      mimeType: file.mimeType,
      sizeBytes: file.bytes.length,
    );
    _documents.add(doc);
    _documentBytes[doc.id] = file.bytes;
    return doc;
  }

  @override
  Future<void> deleteDocument(HealthDocument document) async {
    await _wait();
    _documents.removeWhere((d) => d.id == document.id);
    _documentBytes.remove(document.id);
  }

  @override
  Future<Uint8List> documentBytes(HealthDocument document) async {
    await _wait();
    final bytes = _documentBytes[document.id];
    if (bytes == null) throw const HealthException('That file is no longer available.');
    return bytes;
  }

  @override
  Future<Uri?> documentLink(HealthDocument document) async {
    await _wait();
    return null;
  }

  @override
  Future<void> deleteFilesForPet(String petId) async {
    await _wait();
    final gone = [
      for (final d in _documents)
        if (d.petId == petId) d.id,
    ];
    _documents.removeWhere((d) => d.petId == petId);
    gone.forEach(_documentBytes.remove);
  }

  // ------------------------------------------------------ vets and profile

  @override
  Future<List<Vet>> fetchVets() async {
    await _wait();
    return [..._vets];
  }

  @override
  Future<Vet> saveVet(Vet vet) async {
    await _wait();
    if (vet.isNew) {
      final stored = vet.copyWith(id: _id('v'));
      _vets.add(stored);
      return stored;
    }
    final index = _vets.indexWhere((v) => v.id == vet.id);
    if (index < 0) throw const HealthException('That vet no longer exists.');
    _vets[index] = vet;
    return vet;
  }

  @override
  Future<void> deleteVet(String vetId) async {
    await _wait();
    _vets.removeWhere((v) => v.id == vetId);
    for (final entry in _profiles.entries.toList()) {
      var profile = entry.value;
      if (profile.regularVetId == vetId) profile = profile.withVet(VetRole.regular, null);
      if (profile.emergencyVetId == vetId) profile = profile.withVet(VetRole.emergency, null);
      _profiles[entry.key] = profile;
    }
  }

  @override
  Future<HealthProfile> fetchProfile(String petId) async {
    await _wait();
    return _profiles[petId] ?? HealthProfile(petId: petId);
  }

  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) async {
    await _wait();
    _profiles[profile.petId] = profile;
    return profile;
  }

  // ------------------------------------------------- medicines, plan, logs

  @override
  Future<List<Medication>> fetchMedications(String petId) async {
    await _wait();
    return [
      for (final m in _medications)
        if (m.petId == petId) m,
    ];
  }

  @override
  Future<Medication> saveMedication(Medication medication) async {
    await _wait();
    if (medication.isNew) {
      final stored = medication.copyWith(id: _id('m'));
      _medications.add(stored);
      return stored;
    }
    final index = _medications.indexWhere((m) => m.id == medication.id);
    if (index < 0) throw const HealthException('That medicine no longer exists.');
    _medications[index] = medication;
    return medication;
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _wait();
    _medications.removeWhere((m) => m.id == medicationId);
    _planItems.removeWhere((p) => p.medicationId == medicationId);
    _logs.removeWhere((l) => l.medicationId == medicationId);
  }

  @override
  Future<List<CarePlanItem>> fetchPlanItems(String petId) async {
    await _wait();
    return [
      for (final p in _planItems)
        if (p.petId == petId) p,
    ];
  }

  @override
  Future<CarePlanItem> savePlanItem(CarePlanItem item) async {
    await _wait();
    if (item.isNew) {
      final stored = item.copyWith(id: _id('p'));
      _planItems.add(stored);
      return stored;
    }
    final index = _planItems.indexWhere((p) => p.id == item.id);
    if (index < 0) throw const HealthException('That reminder no longer exists.');
    _planItems[index] = item;
    return item;
  }

  @override
  Future<void> deletePlanItem(String itemId) async {
    await _wait();
    _planItems.removeWhere((p) => p.id == itemId);
  }

  @override
  Future<List<CareLog>> fetchLogs(String petId, {required DateTime from}) async {
    await _wait();
    final start = dateOnly(from);
    return [
      for (final l in _logs)
        if (l.petId == petId && !l.dueOn.isBefore(start)) l,
    ];
  }

  @override
  Future<CareLog> saveLog(CareLog log) async {
    await _wait();
    if (log.isNew) {
      // One answer per reminder per day: a new answer replaces the old one.
      if (log.planItemId != null) {
        _logs.removeWhere((l) => l.planItemId == log.planItemId && isSameDay(l.dueOn, log.dueOn));
      }
      final stored = log.copyWith(id: _id('l'));
      _logs.add(stored);
      return stored;
    }
    final index = _logs.indexWhere((l) => l.id == log.id);
    if (index < 0) throw const HealthException('That entry no longer exists.');
    _logs[index] = log;
    return log;
  }

  @override
  Future<void> deleteLog(String logId) async {
    await _wait();
    _logs.removeWhere((l) => l.id == logId);
  }

  // ---------------------------------------------------------- observations

  @override
  Future<List<Observation>> fetchObservations(String petId) async {
    await _wait();
    return [
      for (final o in _observations)
        if (o.petId == petId) o,
    ];
  }

  @override
  Future<Observation> saveObservation(Observation observation) async {
    await _wait();
    if (observation.isNew) {
      final stored = observation.copyWith(id: _id('o'));
      _observations.add(stored);
      return stored;
    }
    final index = _observations.indexWhere((o) => o.id == observation.id);
    if (index < 0) throw const HealthException('That entry no longer exists.');
    _observations[index] = observation;
    return observation;
  }

  @override
  Future<void> deleteObservation(String observationId) async {
    await _wait();
    _observations.removeWhere((o) => o.id == observationId);
  }

  // ------------------------------------------------------------ sample data

  void _seed() {
    const pet = kellyId;
    const clinic = 'Park Vet Clinic';

    // Vets are the owner's; Kelly uses both.
    _vets.addAll(const [
      Vet(
        id: 'v-park',
        name: 'Dr. Levi, Park Vet Clinic',
        phone: '+972 3 555 0142',
        onWhatsApp: true,
        address: '12 Park Street, Tel Aviv',
        openingHours: 'Sun to Thu 08:00-19:00, Fri 08:00-13:00',
        notes: 'Parking behind the building. Kelly is nervous in the waiting room.',
      ),
      Vet(
        id: 'v-city',
        name: 'City Animal Hospital',
        phone: '+972 3 555 0199',
        address: '80 Harbour Road, Tel Aviv',
        openingHours: 'Open 24 hours',
      ),
    ]);
    _profiles[pet] = const HealthProfile(
      petId: pet,
      microchip: '985 112 004 567 321',
      allergies: ['Chicken (skin reaction)'],
      conditions: ['Arthritis in the hips'],
      contactName: 'Dana (sister)',
      contactPhone: '+972 50 555 0117',
      regularVetId: 'v-park',
      emergencyVetId: 'v-city',
    );

    HealthRecord done(
      String id,
      RecordKind kind,
      String title,
      DateTime when, {
      String notes = '',
      String clinic = '',
      String product = '',
      DateTime? nextDue,
    }) => HealthRecord(
      id: id,
      petId: pet,
      kind: kind,
      title: title,
      notes: notes,
      scheduledAt: when,
      doneAt: when,
      clinic: clinic,
      productName: product,
      nextDueOn: nextDue,
    );

    _records.addAll([
      // Planned: these two are the home dashboard's "Upcoming".
      HealthRecord(
        id: 'r-check',
        petId: pet,
        kind: RecordKind.checkup,
        title: 'General check',
        notes: 'Yearly check at the vet. Bring the vaccination booklet.',
        scheduledAt: DateTime(2025, 6, 12, 18, 20),
        clinic: clinic,
      ),
      HealthRecord(
        id: 'r-medicine',
        petId: pet,
        kind: RecordKind.medicine,
        title: 'Medicine',
        notes: 'Flea and tick tablet.',
        scheduledAt: DateTime(2025, 7, 27, 19, 30),
        followUpOf: 'r-flea',
      ),
      HealthRecord(
        id: 'r-rabies-due',
        petId: pet,
        kind: RecordKind.vaccination,
        title: 'Rabies booster',
        scheduledAt: DateTime(2026, 3, 14, 9),
        clinic: 'Dr. Levi, $clinic',
        followUpOf: 'r-rabies',
      ),
      // History.
      done(
        'r-flea',
        RecordKind.preventive,
        'Flea and tick tablet',
        DateTime(2025, 5, 27, 19, 30),
        nextDue: DateTime(2025, 7, 27),
      ),
      done(
        'r-limp',
        RecordKind.checkup,
        'Limping after a long walk',
        DateTime(2025, 5, 2, 8, 15),
        clinic: clinic,
        notes: 'Arthritis in the hips. Started joint tablets.',
      ),
      done('r-worm', RecordKind.preventive, 'Worming tablet', DateTime(2025, 4, 10, 9)),
      done(
        'r-rabies',
        RecordKind.vaccination,
        'Rabies booster',
        DateTime(2025, 3, 14, 10),
        clinic: 'Dr. Levi, $clinic',
        product: 'Rabies vaccine, 1 year, batch A1234',
        nextDue: DateTime(2026, 3, 14),
        notes: 'A little sleepy that evening, fine the next morning.',
      ),
      done(
        'r-food',
        RecordKind.other,
        'Started senior food',
        DateTime(2025, 2, 1, 8),
        notes: 'Switched over one week. No tummy trouble.',
      ),
      done('r-dental', RecordKind.procedure, 'Dental cleaning', DateTime(2025, 1, 20, 9), clinic: clinic),
      done('r-blood', RecordKind.document, 'Blood test results', DateTime(2025, 1, 20, 11)),
      done(
        'r-ear',
        RecordKind.checkup,
        'Ear infection',
        DateTime(2024, 11, 3, 16, 30),
        clinic: clinic,
        notes: 'Ear drops for ten days.',
      ),
      done('r-senior', RecordKind.checkup, 'Senior wellness check', DateTime(2024, 9, 18, 10), clinic: clinic),
      done(
        'r-dhpp',
        RecordKind.vaccination,
        'DHPP booster',
        DateTime(2024, 9, 18, 10, 15),
        clinic: clinic,
        product: 'DHPP vaccine',
      ),
      done('r-cough', RecordKind.vaccination, 'Kennel cough vaccine', DateTime(2024, 9, 18, 10, 20), clinic: clinic),
      done('r-yearly', RecordKind.checkup, 'Yearly check', DateTime(2024, 6, 12, 18), clinic: clinic),
    ]);

    void attach(String id, String recordId, String name, String mime, Uint8List bytes) {
      _documents.add(
        HealthDocument(id: id, petId: pet, recordId: recordId, fileName: name, mimeType: mime, sizeBytes: bytes.length),
      );
      _documentBytes[id] = bytes;
    }

    attach('d-rabies', 'r-rabies', 'vaccination-booklet.png', 'image/png', samplePng);
    attach('d-limp', 'r-limp', 'vet-letter.png', 'image/png', samplePng);
    attach('d-blood-1', 'r-blood', 'blood-test.pdf', 'application/pdf', samplePdf);
    attach('d-blood-2', 'r-blood', 'blood-test-page-2.png', 'image/png', samplePng);

    // One medicine with two daily reminders, and the daily routines.
    final started = DateTime(2025, 5, 2);
    _medications.add(
      Medication(
        id: 'm-joint',
        petId: pet,
        name: 'Joint tablets',
        strength: '50 mg',
        dose: '1 tablet',
        route: 'By mouth',
        frequency: 'Twice a day with food',
        startsOn: started,
        prescribedBy: 'Dr. Levi, $clinic',
      ),
    );
    _planItems.addAll([
      CarePlanItem(
        id: 'p-joint-am',
        petId: pet,
        kind: CareKind.medication,
        title: 'Joint tablets',
        time: const TimeOfDay(hour: 8, minute: 0),
        medicationId: 'm-joint',
        startsOn: started,
      ),
      CarePlanItem(
        id: 'p-joint-pm',
        petId: pet,
        kind: CareKind.medication,
        title: 'Joint tablets',
        time: const TimeOfDay(hour: 20, minute: 0),
        medicationId: 'm-joint',
        startsOn: started,
      ),
      const CarePlanItem(
        id: 'p-breakfast',
        petId: pet,
        kind: CareKind.feeding,
        title: 'Breakfast',
        time: TimeOfDay(hour: 7, minute: 30),
      ),
      const CarePlanItem(
        id: 'p-walk',
        petId: pet,
        kind: CareKind.walk,
        title: 'Evening walk',
        time: TimeOfDay(hour: 18, minute: 30),
      ),
      const CarePlanItem(
        id: 'p-dinner',
        petId: pet,
        kind: CareKind.feeding,
        title: 'Dinner',
        time: TimeOfDay(hour: 19, minute: 30),
      ),
      const CarePlanItem(
        id: 'p-brush',
        petId: pet,
        kind: CareKind.grooming,
        title: 'Brush coat',
        time: TimeOfDay(hour: 10, minute: 0),
        days: {6},
      ),
    ]);

    // The dose log of the past week: every dose given, except yesterday
    // evening's reminder, which nobody answered ("Needs review").
    final now = _now();
    final today = dateOnly(now);
    void given(String itemId, DateTime day, TimeOfDay due, {String title = 'Joint tablets', String? med = 'm-joint'}) {
      final at = atTime(day, due).add(const Duration(minutes: 5));
      _logs.add(
        CareLog(
          id: _id('l'),
          petId: pet,
          planItemId: itemId,
          medicationId: med,
          title: title,
          dueOn: day,
          dueTime: due,
          status: CareLogStatus.done,
          doneAt: at,
          loggedByName: 'Alex',
          loggedAt: at,
        ),
      );
    }

    const am = TimeOfDay(hour: 8, minute: 0);
    const pm = TimeOfDay(hour: 20, minute: 0);
    for (var back = 7; back >= 1; back--) {
      final day = today.subtract(Duration(days: back));
      given('p-joint-am', day, am);
      if (back != 1) given('p-joint-pm', day, pm);
    }
    // Today, only what is already behind "now".
    if (!now.isBefore(atTime(today, const TimeOfDay(hour: 7, minute: 35)))) {
      given('p-breakfast', today, const TimeOfDay(hour: 7, minute: 30), title: 'Breakfast', med: null);
    }
    if (!now.isBefore(atTime(today, const TimeOfDay(hour: 8, minute: 5)))) given('p-joint-am', today, am);

    Observation weight(String id, DateTime day, double kg, [String note = '']) =>
        Observation(id: id, petId: pet, category: Observation.weightCategory, value: kg, note: note, observedAt: day);
    _observations.addAll([
      weight('o-w1', DateTime(2024, 9, 18, 10), 24.1, 'Weighed at the vet'),
      weight('o-w2', DateTime(2024, 12, 5, 9), 23.8),
      weight('o-w3', DateTime(2025, 1, 20, 9), 23.9, 'Weighed at the vet'),
      weight('o-w4', DateTime(2025, 3, 14, 10), 23.4, 'Weighed at the vet'),
      weight('o-w5', DateTime(2025, 5, 2, 8, 30), 23.2, 'After the limping week'),
      weight('o-w6', DateTime(2025, 6, 1, 9), 23, 'Weighed at home'),
      Observation(
        id: 'o-energy',
        petId: pet,
        category: 'energy',
        level: ObservationLevel.less,
        note: 'Short walk only',
        observedAt: DateTime(2025, 5, 30, 19),
      ),
      Observation(
        id: 'o-appetite',
        petId: pet,
        category: 'appetite',
        level: ObservationLevel.usual,
        observedAt: DateTime(2025, 6, 5, 20),
      ),
      Observation(
        id: 'o-mobility',
        petId: pet,
        category: 'mobility',
        level: ObservationLevel.less,
        note: 'Stiff getting up in the morning',
        observedAt: DateTime(2025, 6, 8, 7, 30),
      ),
    ]);
  }

  /// A 1 x 1 pixel PNG standing in for a photo in the sample data.
  static final Uint8List samplePng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  /// A one-page PDF standing in for a lab report in the sample data.
  static final Uint8List samplePdf = Uint8List.fromList(
    latin1.encode(
      '%PDF-1.4\n'
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 200]/Contents 4 0 R'
      '/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
      '4 0 obj<</Length 58>>stream\n'
      'BT /F1 16 Tf 30 120 Td (Blood test results: sample) Tj ET\n'
      'endstream endobj\n'
      '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
      'trailer<</Root 1 0 R/Size 6>>\n'
      '%%EOF\n',
    ),
  );
}
