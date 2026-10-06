import 'dart:typed_data';
import 'health_models.dart';

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
