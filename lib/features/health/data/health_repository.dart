import 'dart:typed_data';

import 'health_models.dart';

/// Everything the Health tab reads and writes. The screens talk only to
/// this interface: an in-memory implementation serves the sample data and
/// a Supabase one serves real accounts.
///
/// "Save" methods create the item when its id is empty and update it
/// otherwise, and return the stored item. Every method throws a
/// [HealthException] with a message safe to show when it fails.
abstract class HealthRepository {
  // Health records: the history and planned appointments / due dates.
  Future<List<HealthRecord>> fetchRecords(String petId);
  Future<HealthRecord> saveRecord(HealthRecord record);

  /// Also removes the record's documents.
  Future<void> deleteRecord(String recordId);

  // Documents attached to records.
  Future<List<HealthDocument>> fetchDocuments(String petId);
  Future<HealthDocument> addDocument({required String petId, required String recordId, required PickedFile file});
  Future<void> deleteDocument(HealthDocument document);

  /// The file's content, to show a photo or to hand a PDF to another app.
  Future<Uint8List> documentBytes(HealthDocument document);

  /// A short-lived link the system viewer can open, or `null` when the
  /// backend has none (the sample data).
  Future<Uri?> documentLink(HealthDocument document);

  /// Gets a pet's stored files ready to go with the pet. Call it before the
  /// pet is deleted: it notes which files the pet has, and throws a
  /// [HealthException] when it cannot (then do not delete the pet). Call
  /// the function it returns once the pet's row is gone (its health rows
  /// go with it): that removes the files, and never throws. A file it
  /// cannot remove is tried again with a later removal; nothing points at
  /// it any more, so nothing is lost.
  ///
  /// In this order a failed delete never leaves a pet whose files are gone.
  Future<Future<void> Function()> prepareDeletingPet(String petId);

  // Vets belong to the owner, not to a pet.
  Future<List<Vet>> fetchVets();
  Future<Vet> saveVet(Vet vet);

  /// Pets that pointed at the vet simply have no vet afterwards.
  Future<void> deleteVet(String vetId);

  /// The pet's profile; an empty one when nothing was saved yet.
  Future<HealthProfile> fetchProfile(String petId);
  Future<HealthProfile> saveProfile(HealthProfile profile);

  // Medicines, the care plan and what was actually done.
  Future<List<Medication>> fetchMedications(String petId);
  Future<Medication> saveMedication(Medication medication);

  /// Also removes the medicine's reminders and its dose log.
  Future<void> deleteMedication(String medicationId);

  Future<List<CarePlanItem>> fetchPlanItems(String petId);
  Future<CarePlanItem> savePlanItem(CarePlanItem item);

  /// Keeps the logs of what was done.
  Future<void> deletePlanItem(String itemId);

  /// Logs whose occurrence was due on or after [from].
  Future<List<CareLog>> fetchLogs(String petId, {required DateTime from});
  Future<CareLog> saveLog(CareLog log);
  Future<void> deleteLog(String logId);

  // Observations: the Quick log journal, including weight.
  Future<List<Observation>> fetchObservations(String petId);
  Future<Observation> saveObservation(Observation observation);
  Future<void> deleteObservation(String observationId);

  // The emergency kit checklist.

  /// The answers saved for a pet's kit; an item never answered has none.
  Future<List<KitCheck>> fetchKit(String petId);

  /// Stores the pet's answer for one item, replacing the one before.
  Future<KitCheck> saveKitCheck(KitCheck check);

  // The "my pet is lost" card.

  /// What was last written for the pet's card, or `null` when there is none.
  Future<LostPetCard?> fetchLostCard(String petId);

  /// Stores the pet's card, replacing the one before.
  Future<LostPetCard> saveLostCard(LostPetCard card);
}
