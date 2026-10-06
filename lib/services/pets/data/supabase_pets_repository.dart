import '../../../platform/session.dart';
import '../../../platform/storage_cleanup.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../models/pet.dart';
import 'pets_repository.dart';

/// [PetsRepository] backed by `public.pets` (0001 plus `0005_pets.sql`) and
/// the private `pet-photos` bucket.
///
/// Row level security does the enforcing: a user only ever sees and writes
/// their own rows, and only files under their own folder.
class SupabasePetsRepository implements PetsRepository {
  SupabasePetsRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  static const _table = 'pets';
  static const photoBucket = 'pet-photos';

  /// How long a link to a photo stays valid. The photo itself is cached on
  /// the phone under its path, so a new link is only needed once per launch.
  static const _signedUrlSeconds = 24 * 60 * 60;

  // Real accounts always fetch: there is nothing to show before that.
  @override
  List<Pet>? cachedPets(String? ownerId) => ownerId == null ? const [] : null;

  @override
  Future<List<Pet>> fetchPets(String ownerId) =>
      _guard(PetsFailure.load, () async {
        if (_client.auth.currentUser?.id != ownerId) {
          throw PetsException.of(PetsFailure.signInAgain);
        }
        final rows = await _client.rpc('get_my_pet_context') as List;
        return [
          for (final row in rows)
            petFromRow(Map<String, dynamic>.from(row as Map)),
        ];
      });

  @override
  Future<Pet> savePet(String ownerId, Pet pet) =>
      _guard(PetsFailure.save, () async {
        final row = await _client
            .from(_table)
            .upsert(petToRow(ownerId, pet))
            .select()
            .single();
        // Today's feeding, activity and health events are not stored in
        // this table: keep what the app had.
        final stored = petFromRow(row);
        if (stored.photoPath != null) {
          try {
            await StorageCleanup(
              _client,
            ).attached(photoBucket, stored.photoPath!);
          } catch (_) {}
        }
        return stored.copyWith(
          feeding: FeedingStatus(
            caloriesToday: pet.feeding.caloriesToday,
            dailyGoal: stored.feeding.dailyGoal,
            nextFeeding: pet.feeding.nextFeeding,
          ),
          activity: pet.activity,
          healthEvents: pet.healthEvents,
        );
      });

  @override
  Future<void> deletePet(String ownerId, Pet pet) => _guard(
    PetsFailure.delete,
    () async {
      // The row first: if deleting it fails, the pet keeps its pictures.
      final folder = '$ownerId/${pet.id}';
      final files = await _client.storage.from(photoBucket).list(path: folder);
      await _client
          .from(_table)
          .delete()
          .eq('id', pet.id)
          .eq('owner_id', ownerId);
      if (files.isEmpty) return;
      try {
        await _client.storage.from(photoBucket).remove([
          for (final file in files) '$folder/${file.name}',
        ]);
      } catch (_) {
        // The pet is gone; a leftover picture in its own folder harms
        // nothing, and the delete the owner asked for has happened.
      }
    },
  );

  @override
  Future<String> uploadPhoto(
    String ownerId,
    String petId,
    Uint8List jpeg,
  ) => _guard(PetsFailure.photoSave, () async {
    // A new name for every photo, so a cached older one is never shown.
    final path =
        '$ownerId/$petId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await StorageCleanup(_client).reserve(photoBucket, path);
    await _client.storage
        .from(photoBucket)
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const sb.FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '31536000',
          ),
        );
    return path;
  });

  @override
  Future<void> deletePhoto(String path) =>
      _guard(PetsFailure.photoRemove, () async {
        await StorageCleanup(_client).enqueue(photoBucket, path);
        await StorageCleanup(_client).drain();
      });

  @override
  Future<PetPhotoData> loadPhoto(String path) =>
      _guard(PetsFailure.photoLoad, () async {
        final url = await _client.storage
            .from(photoBucket)
            .createSignedUrl(path, _signedUrlSeconds);
        return PetPhotoData.url(Uri.parse(url));
      });

  /// Runs [action], turning backend failures into a [PetsException] that
  /// says why. [during] is the reason to give when the backend says
  /// nothing more specific.
  Future<T> _guard<T>(PetsFailure during, Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } catch (e) {
      throw petsExceptionFor(e, during: during);
    }
  }

  static const _timeout = Duration(seconds: 25);
}

/// Why the backend failed, as a [PetsException]: a reason the screen can
/// put into words, never a raw error. [during] is what was being done
/// ([PetsFailure.save], [PetsFailure.load]...), used when the backend gives
/// no more specific reason.
PetsException petsExceptionFor(
  Object error, {
  PetsFailure during = PetsFailure.save,
}) {
  if (error is PetsException) return error;
  if (error is sb.PostgrestException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (code == '42501' || message.contains('row-level security')) {
      return PetsException.of(PetsFailure.notYours);
    }
    if (code == '23514') return PetsException.of(PetsFailure.invalid);
    if (code == '42703' || code == 'PGRST204') {
      return PetsException.of(PetsFailure.databaseOutdated);
    }
    if (code == 'PGRST301' || message.contains('jwt')) {
      return PetsException.of(PetsFailure.signInAgain);
    }
    return PetsException.of(during);
  }
  if (error is sb.StorageException) {
    final message = error.message.toLowerCase();
    if (message.contains('size') ||
        message.contains('too large') ||
        error.statusCode == '413') {
      return PetsException.of(PetsFailure.photoTooLarge);
    }
    if (message.contains('mime')) {
      return PetsException.of(PetsFailure.photoUnsupported);
    }
    if (message.contains('not found')) {
      return PetsException.of(PetsFailure.photoGone);
    }
    if (message.contains('row-level security') || error.statusCode == '403') {
      return PetsException.of(PetsFailure.notYours);
    }
    return PetsException.of(during);
  }
  if (error is sb.AuthException) {
    return PetsException.of(PetsFailure.signInAgain);
  }
  if (error is TimeoutException) return PetsException.of(PetsFailure.offline);
  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('failed host lookup') ||
      text.contains('network')) {
    return PetsException.of(PetsFailure.offline);
  }
  return PetsException.of(PetsFailure.unknown);
}

/// A `pets` row as a [Pet].
Pet petFromRow(Map<String, dynamic> row) {
  DateTime? date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  final birth = date(row['birth_date']);
  return Pet(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    species: PetSpecies.fromName(row['species'] as String?),
    breed: _text(row['breed']),
    weightKg: (row['weight_kg'] as num?)?.toDouble(),
    birthDate: birth == null
        ? null
        : DateTime(birth.year, birth.month, birth.day),
    birthDateApprox: row['birth_date_approx'] == true,
    sex: PetSex.fromName(row['sex'] as String?),
    neutered: Neutered.fromName(row['neutered'] as String?),
    photoPath: _text(row['photo_path']),
    iconKey: _text(row['icon_key']),
    archivedAt: date(row['archived_at'])?.toLocal(),
    reminderSnoozedUntil: date(row['reminder_snoozed_until'])?.toLocal(),
    createdAt: date(row['created_at'])?.toLocal(),
    feeding: FeedingStatus(
      dailyGoal: (row['daily_calorie_goal'] as num?)?.toInt(),
    ),
  );
}

/// A [Pet] as a `pets` row owned by [ownerId].
Map<String, dynamic> petToRow(String ownerId, Pet pet) {
  final birth = pet.birthDate;
  final breed = pet.breed?.trim() ?? '';
  return {
    'id': pet.id,
    'owner_id': ownerId,
    'name': pet.name.trim(),
    'species': pet.species.name,
    'breed': breed.isEmpty ? null : breed,
    'birth_date': birth == null
        ? null
        : '${birth.year.toString().padLeft(4, '0')}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}',
    'birth_date_approx': birth != null && pet.birthDateApprox,
    // To the gram: the column is numeric(7, 3).
    'weight_kg': pet.weightKg == null
        ? null
        : (pet.weightKg! * 1000).round() / 1000,
    'sex': pet.sex?.name,
    'neutered': pet.neutered?.name,
    'photo_path': pet.photoPath,
    'icon_key': pet.iconKey,
    'archived_at': pet.archivedAt?.toUtc().toIso8601String(),
    'reminder_snoozed_until': pet.reminderSnoozedUntil
        ?.toUtc()
        .toIso8601String(),
    'daily_calorie_goal': pet.feeding.dailyGoal,
  };
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
