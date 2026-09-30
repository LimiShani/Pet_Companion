import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import 'health_models.dart';
import 'health_repository.dart';
import 'health_rows.dart';

/// [HealthRepository] backed by the tables and the `pet-documents` bucket
/// of `supabase/migrations/0002_health.sql`.
///
/// Row level security does the enforcing: a signed-in user only ever sees
/// and changes rows of their own, and only for pets that belong to them.
/// `owner_id` is never sent: every table defaults it to the signed-in user.
class SupabaseHealthRepository implements HealthRepository {
  SupabaseHealthRepository(this._client);

  final sb.SupabaseClient _client;

  static const _records = 'health_events';
  static const _documents = 'health_documents';
  static const _vets = 'vets';
  static const _profiles = 'health_profiles';
  static const _medications = 'medications';
  static const _planItems = 'care_plan_items';
  static const _logs = 'care_logs';
  static const _observations = 'health_observations';
  static const _kit = 'emergency_kit_items';
  static const _lostCards = 'lost_pet_cards';
  static const _bucket = 'pet-documents';

  /// How long a link to a document stays valid: long enough to open it.
  static const _linkSeconds = 600;

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  /// Whether [id] can be a row of this backend. The sample pets (`kelly`,
  /// `soya`) are not: they have no health data here, rather than an error.
  static bool isStored(String id) => _uuid.hasMatch(id);

  static void _requireStored(String petId) {
    if (!isStored(petId)) {
      throw const HealthException('This pet is not saved to your account yet, so nothing can be stored for it.');
    }
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const HealthException('Your session has ended. Please sign in again.');
    return id;
  }

  sb.StorageFileApi get _files => _client.storage.from(_bucket);

  Future<List<T>> _list<T>(String table, String petId, T Function(Row row) read, {String? orderBy}) => _guard(() async {
    if (!isStored(petId)) return <T>[];
    final query = _client.from(table).select().eq('pet_id', petId);
    final rows = orderBy == null ? await query : await query.order(orderBy);
    return [for (final row in rows) read(row)];
  });

  /// Inserts ([id] empty) or updates a row and returns what is stored.
  /// [petId]: the pet the row belongs to, which must be a stored one.
  Future<T> _save<T>(
    String table,
    String id,
    Row row,
    T Function(Row row) read, {
    required String gone,
    String? petId,
  }) => _guard(() async {
    if (petId != null) _requireStored(petId);
    if (id.isEmpty) return read(await _client.from(table).insert(row).select().single());
    final updated = await _client.from(table).update(row).eq('id', id).select().maybeSingle();
    if (updated == null) throw HealthException(gone);
    return read(updated);
  });

  Future<void> _delete(String table, String id) => _guard(() async {
    if (!isStored(id)) return;
    await _client.from(table).delete().eq('id', id);
  });

  // --------------------------------------------------------------- records

  @override
  Future<List<HealthRecord>> fetchRecords(String petId) =>
      _list(_records, petId, recordFromRow, orderBy: 'scheduled_at');

  @override
  Future<HealthRecord> saveRecord(HealthRecord record) => _save(
    _records,
    record.id,
    recordToRow(record),
    recordFromRow,
    gone: 'That record no longer exists.',
    petId: record.petId,
  );

  @override
  Future<void> deleteRecord(String recordId) => _guard(() async {
    if (!isStored(recordId)) return;
    // The rows of its documents go with the record; the files do not.
    final rows = await _client.from(_documents).select('storage_path').eq('record_id', recordId);
    await _removeFiles([for (final row in rows) row['storage_path'] as String]);
    await _client.from(_records).delete().eq('id', recordId);
  });

  // ------------------------------------------------------------- documents

  @override
  Future<List<HealthDocument>> fetchDocuments(String petId) =>
      _list(_documents, petId, documentFromRow, orderBy: 'created_at');

  static String _extension(String mimeType) => switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'pdf',
  };

  @override
  Future<HealthDocument> addDocument({required String petId, required String recordId, required PickedFile file}) {
    return _guard(() async {
      _requireStored(petId);
      final problem = file.problem;
      if (problem != null) throw HealthException(problem);
      // <user id>/<pet id>/<record id>/<random>.<ext>: the bucket's policies
      // key off the first folder.
      final path = '$_userId/$petId/$recordId/${const Uuid().v4()}.${_extension(file.mimeType)}';
      await _files.uploadBinary(path, file.bytes, fileOptions: sb.FileOptions(contentType: file.mimeType));
      try {
        final row = await _client
            .from(_documents)
            .insert({
              'pet_id': petId,
              'record_id': recordId,
              'storage_path': path,
              'file_name': file.name,
              'mime_type': file.mimeType,
              'size_bytes': file.bytes.length,
            })
            .select()
            .single();
        return documentFromRow(row);
      } catch (_) {
        // Never leave a file nobody points to.
        await _removeFiles([path]);
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteDocument(HealthDocument document) => _guard(() async {
    await _removeFiles([document.storagePath]);
    await _client.from(_documents).delete().eq('id', document.id);
  });

  @override
  Future<Uint8List> documentBytes(HealthDocument document) => _guard(() => _files.download(document.storagePath));

  @override
  Future<Uri?> documentLink(HealthDocument document) => _guard(() async {
    if (document.storagePath.isEmpty) return null;
    return Uri.tryParse(await _files.createSignedUrl(document.storagePath, _linkSeconds));
  });

  @override
  Future<void> deleteFilesForPet(String petId) => _guard(() async {
    if (!isStored(petId)) return;
    final rows = await _client.from(_documents).select('storage_path').eq('pet_id', petId);
    await _removeFiles([for (final row in rows) row['storage_path'] as String]);
    await _client.from(_documents).delete().eq('pet_id', petId);
  });

  Future<void> _removeFiles(List<String> paths) async {
    final stored = [
      for (final path in paths)
        if (path.isNotEmpty) path,
    ];
    // The storage API takes the paths in one request; keep each one small.
    for (var start = 0; start < stored.length; start += 100) {
      final end = start + 100 > stored.length ? stored.length : start + 100;
      await _files.remove(stored.sublist(start, end));
    }
  }

  // ------------------------------------------------------ vets and profile

  @override
  Future<List<Vet>> fetchVets() => _guard(() async {
    final rows = await _client.from(_vets).select().order('created_at');
    return [for (final row in rows) vetFromRow(row)];
  });

  @override
  Future<Vet> saveVet(Vet vet) => _save(_vets, vet.id, vetToRow(vet), vetFromRow, gone: 'That vet no longer exists.');

  @override
  Future<void> deleteVet(String vetId) => _delete(_vets, vetId);

  @override
  Future<HealthProfile> fetchProfile(String petId) => _guard(() async {
    if (!isStored(petId)) return HealthProfile(petId: petId);
    final row = await _client.from(_profiles).select().eq('pet_id', petId).maybeSingle();
    return row == null ? HealthProfile(petId: petId) : profileFromRow(row);
  });

  @override
  Future<HealthProfile> saveProfile(HealthProfile profile) {
    return _guard(() async {
      _requireStored(profile.petId);
      final row = await _client.from(_profiles).upsert(profileToRow(profile), onConflict: 'pet_id').select().single();
      return profileFromRow(row);
    });
  }

  // ------------------------------------------------- medicines, plan, logs

  @override
  Future<List<Medication>> fetchMedications(String petId) =>
      _list(_medications, petId, medicationFromRow, orderBy: 'created_at');

  @override
  Future<Medication> saveMedication(Medication medication) => _save(
    _medications,
    medication.id,
    medicationToRow(medication),
    medicationFromRow,
    gone: 'That medicine no longer exists.',
    petId: medication.petId,
  );

  /// Its reminders and its dose log go with it (the database cascades).
  @override
  Future<void> deleteMedication(String medicationId) => _delete(_medications, medicationId);

  @override
  Future<List<CarePlanItem>> fetchPlanItems(String petId) =>
      _list(_planItems, petId, planItemFromRow, orderBy: 'time_of_day');

  @override
  Future<CarePlanItem> savePlanItem(CarePlanItem item) => _save(
    _planItems,
    item.id,
    planItemToRow(item),
    planItemFromRow,
    gone: 'That reminder no longer exists.',
    petId: item.petId,
  );

  /// The logs stay: the database only clears their link to the item.
  @override
  Future<void> deletePlanItem(String itemId) => _delete(_planItems, itemId);

  @override
  Future<List<CareLog>> fetchLogs(String petId, {required DateTime from}) => _guard(() async {
    if (!isStored(petId)) return <CareLog>[];
    final rows = await _client
        .from(_logs)
        .select()
        .eq('pet_id', petId)
        .gte('due_on', dayToDb(from))
        .order('due_on')
        .order('logged_at');
    return [for (final row in rows) logFromRow(row)];
  });

  @override
  Future<CareLog> saveLog(CareLog log) {
    final row = logToRow(log);
    if (!log.isNew) {
      return _save(_logs, log.id, row, logFromRow, gone: 'That entry no longer exists.', petId: log.petId);
    }
    return _guard(() async {
      _requireStored(log.petId);
      // One answer per reminder per day: a new answer replaces the old one.
      final stored = log.planItemId == null
          ? await _client.from(_logs).insert(row).select().single()
          : await _client.from(_logs).upsert(row, onConflict: 'plan_item_id,due_on').select().single();
      return logFromRow(stored);
    });
  }

  @override
  Future<void> deleteLog(String logId) => _delete(_logs, logId);

  // ---------------------------------------------------------- observations

  @override
  Future<List<Observation>> fetchObservations(String petId) =>
      _list(_observations, petId, observationFromRow, orderBy: 'observed_at');

  @override
  Future<Observation> saveObservation(Observation observation) => _save(
    _observations,
    observation.id,
    observationToRow(observation),
    observationFromRow,
    gone: 'That entry no longer exists.',
    petId: observation.petId,
  );

  @override
  Future<void> deleteObservation(String observationId) => _delete(_observations, observationId);

  // --------------------------------------------------------- emergency kit

  @override
  Future<List<KitCheck>> fetchKit(String petId) => _guard(() async {
    if (!isStored(petId)) return <KitCheck>[];
    final rows = await _client.from(_kit).select().eq('pet_id', petId);
    return [for (final row in rows) ?kitCheckFromRow(row)];
  });

  @override
  Future<KitCheck> saveKitCheck(KitCheck check) => _guard(() async {
    _requireStored(check.petId);
    final row = await _client.from(_kit).upsert(kitCheckToRow(check), onConflict: 'pet_id,item').select().single();
    return kitCheckFromRow(row) ?? check;
  });

  // ------------------------------------------------------------- lost card

  @override
  Future<LostPetCard?> fetchLostCard(String petId) => _guard(() async {
    if (!isStored(petId)) return null;
    final row = await _client.from(_lostCards).select().eq('pet_id', petId).maybeSingle();
    return row == null ? null : lostCardFromRow(row);
  });

  @override
  Future<LostPetCard> saveLostCard(LostPetCard card) => _guard(() async {
    _requireStored(card.petId);
    final row = await _client.from(_lostCards).upsert(lostCardToRow(card), onConflict: 'pet_id').select().single();
    return lostCardFromRow(row);
  });

  // ---------------------------------------------------------------- errors

  /// Runs [action], turning backend failures into a [HealthException] with
  /// copy that fits the app's tone.
  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on HealthException {
      rethrow;
    } on sb.PostgrestException catch (e) {
      throw HealthException(_friendly(e));
    } on sb.StorageException catch (e) {
      throw HealthException(_friendlyStorage(e));
    } catch (_) {
      // No connection, a timeout, or a response that was not what we expect.
      throw const HealthException('Could not reach the server. Check your connection and try again.');
    }
  }

  static String _friendly(sb.PostgrestException e) {
    final message = e.message.toLowerCase();
    // 42501: refused by row level security. 23514: a check constraint.
    // 23503: a row it points to is gone. 22P02: an id that is not an id.
    if (e.code == '42501' || message.contains('row-level security')) {
      return 'You are not allowed to do that. Please sign in again.';
    }
    if (e.code == 'PGRST301' || message.contains('jwt')) return 'Your session has ended. Please sign in again.';
    if (e.code == '23514') return 'Some of the details are not valid. Please check them and try again.';
    if (e.code == '23503') return 'That item no longer exists. Go back and open it again.';
    if (e.code == '22P02') return 'This pet is not saved to your account yet, so nothing can be stored for it.';
    return 'Something went wrong. Please try again.';
  }

  static String _friendlyStorage(sb.StorageException e) {
    final message = e.message.toLowerCase();
    if (e.statusCode == '413' || message.contains('exceeded') || message.contains('too large')) {
      return 'That file is larger than 5 MB. Please choose a smaller one.';
    }
    if (e.statusCode == '415' || message.contains('mime')) {
      return 'Only photos (JPEG, PNG, WebP) and PDF files can be attached.';
    }
    if (e.statusCode == '404' || message.contains('not found')) return 'That file is no longer available.';
    if (e.statusCode == '401' || e.statusCode == '403' || message.contains('row-level security')) {
      return 'You are not allowed to do that. Please sign in again.';
    }
    return 'The file could not be stored. Please try again.';
  }
}
