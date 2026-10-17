import 'dart:typed_data';
import 'health_models.dart';
import 'issue_models.dart';

abstract interface class MedicalRecordsRepository {
  Future<List<HealthRecord>> fetchRecords(String petId);
  Future<HealthRecord> saveRecord(HealthRecord record);
  Future<void> deleteRecord(String recordId);
  Future<List<HealthDocument>> fetchDocuments(String petId);
  Future<HealthDocument> addDocument({
    required String petId,
    required String recordId,
    required PickedFile file,
  });
  Future<void> deleteDocument(HealthDocument document);
  Future<Uint8List> documentBytes(HealthDocument document);
  Future<Uri?> documentLink(HealthDocument document);
  Future<Future<void> Function()> prepareDeletingPet(String petId);
}

abstract interface class EmergencyRepository {
  Future<List<Vet>> fetchVets();
  Future<Vet> saveVet(Vet vet);
  Future<void> deleteVet(String vetId);
  Future<HealthProfile> fetchProfile(String petId);
  Future<HealthProfile> saveProfile(HealthProfile profile);
  Future<List<KitCheck>> fetchKit(String petId);
  Future<KitCheck> saveKitCheck(KitCheck check);
  Future<LostPetCard?> fetchLostCard(String petId);
  Future<LostPetCard> saveLostCard(LostPetCard card);
}

abstract interface class ScheduleRepository {
  Future<List<Medication>> fetchMedications(String petId);
  Future<Medication> saveMedication(Medication medication);
  Future<void> deleteMedication(String medicationId);
  Future<List<CarePlanItem>> fetchPlanItems(String petId);
  Future<CarePlanItem> savePlanItem(CarePlanItem item);
  Future<void> deletePlanItem(String itemId);
  Future<List<CareLog>> fetchLogs(String petId, {required DateTime from});
  Future<CareLog> saveLog(CareLog log);
  Future<void> deleteLog(String logId);
}

abstract interface class ObservationsRepository {
  Future<List<Observation>> fetchObservations(String petId);
  Future<Observation> saveObservation(Observation observation);
  Future<void> deleteObservation(String observationId);
}

/// Problems followed over time (0033): a problem, its Quick log entries
/// (observations with an `issueId`) and the entries' photos.
abstract interface class HealthIssuesRepository {
  /// Every problem of the pet, open and resolved.
  Future<List<HealthIssue>> fetchIssues(String petId);

  /// Starts following a problem ([issue] is new) or changes it: its title,
  /// start day, body area, or resolved / open again. Throws a
  /// [HealthException] with [HealthFailure.tooManyIssues] past
  /// [HealthIssue.maxNewPerDay] new problems of one pet in a day.
  Future<HealthIssue> saveIssue(HealthIssue issue);

  /// Stops following a problem. Its entries and their photos stay, no
  /// longer part of any problem.
  Future<void> deleteIssue(String issueId);

  /// The entries of a problem, oldest first.
  Future<List<Observation>> fetchIssueEntries(String petId, String issueId);

  /// Makes [entry] part of the problem [issueId], or of none (`null`).
  Future<Observation> linkEntry(Observation entry, String? issueId);

  /// The photos of every entry of the pet.
  Future<List<HealthDocument>> fetchEntryPhotos(String petId);

  /// Adds a photo to an entry: JPEG, PNG or WebP, the 5 MB limit, at most
  /// [HealthIssue.maxPhotosPerEntry] per entry.
  Future<HealthDocument> addEntryPhoto({
    required String petId,
    required String observationId,
    required PickedFile file,
  });

  Future<void> deleteEntryPhoto(HealthDocument photo);
  Future<Uint8List> entryPhotoBytes(HealthDocument photo);
}
