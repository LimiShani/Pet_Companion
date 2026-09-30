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
  SupabasePetsRepository(this._client);

  final sb.SupabaseClient _client;

  static const _table = 'pets';
  static const photoBucket = 'pet-photos';

  /// How long a link to a photo stays valid. The photo itself is cached on
  /// the phone under its path, so a new link is only needed once per launch.
  static const _signedUrlSeconds = 24 * 60 * 60;

  // Real accounts always fetch: there is nothing to show before that.
  @override
  List<Pet>? cachedPets(String? ownerId) => ownerId == null ? const [] : null;

  @override
  Future<List<Pet>> fetchPets(String ownerId) => _guard('load your pets', () async {
        final rows = await _client.from(_table).select().eq('owner_id', ownerId).order('created_at');
        return [for (final row in rows) petFromRow(row)];
      });

  @override
  Future<Pet> savePet(String ownerId, Pet pet) => _guard('save your pet', () async {
        final row = await _client.from(_table).upsert(petToRow(ownerId, pet)).select().single();
        // Today's feeding, activity and health events are not stored in
        // this table: keep what the app had.
        final stored = petFromRow(row);
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
  Future<void> deletePet(String ownerId, Pet pet) => _guard('delete your pet', () async {
        // Files first: once the row is gone nothing points at them any more.
        final folder = '$ownerId/${pet.id}';
        final files = await _client.storage.from(photoBucket).list(path: folder);
        if (files.isNotEmpty) {
          await _client.storage.from(photoBucket).remove([for (final file in files) '$folder/${file.name}']);
        }
        await _client.from(_table).delete().eq('id', pet.id).eq('owner_id', ownerId);
      });

  @override
  Future<String> uploadPhoto(String ownerId, String petId, Uint8List jpeg) => _guard('save the photo', () async {
        // A new name for every photo, so a cached older one is never shown.
        final path = '$ownerId/$petId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _client.storage.from(photoBucket).uploadBinary(
              path,
              jpeg,
              fileOptions: const sb.FileOptions(contentType: 'image/jpeg', cacheControl: '31536000'),
            );
        return path;
      });

  @override
  Future<void> deletePhoto(String path) => _guard('remove the photo', () async {
        await _client.storage.from(photoBucket).remove([path]);
      });

  @override
  Future<PetPhotoData> loadPhoto(String path) => _guard('load the photo', () async {
        final url = await _client.storage.from(photoBucket).createSignedUrl(path, _signedUrlSeconds);
        return PetPhotoData.url(Uri.parse(url));
      });

  /// Runs [action], turning backend failures into a [PetsException] with
  /// copy that fits the app's tone. [doing] finishes "Could not …".
  Future<T> _guard<T>(String doing, Future<T> Function() action) async {
    try {
      return await action().timeout(_timeout);
    } catch (e) {
      throw petsExceptionFor(e, doing: doing);
    }
  }

  static const _timeout = Duration(seconds: 25);
}

const _offline = 'Cannot reach the server. Check your connection and try again.';

/// What to tell the owner when the backend failed while [doing] something
/// ("save your pet", "load your pets"): plain words, never a raw error.
PetsException petsExceptionFor(Object error, {String doing = 'save your pet'}) {
  if (error is PetsException) return error;
  if (error is sb.PostgrestException) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    if (code == '42501' || message.contains('row-level security')) {
      return const PetsException('You can only change your own pets. Please sign in again.');
    }
    if (code == '23514') {
      return const PetsException('Some of that information is not valid. Please check it and try again.');
    }
    if (code == '42703' || code == 'PGRST204') {
      return const PetsException('The database is not up to date for pets yet (migration 0005 has not been run).');
    }
    if (code == 'PGRST301' || message.contains('jwt')) return const PetsException('Please sign in again.');
    return PetsException('Could not $doing. Please try again.');
  }
  if (error is sb.StorageException) {
    final message = error.message.toLowerCase();
    if (message.contains('size') || message.contains('too large') || error.statusCode == '413') {
      return const PetsException('That photo is too large.');
    }
    if (message.contains('mime')) return const PetsException('That kind of picture is not supported.');
    if (message.contains('not found')) return const PetsException('That photo is no longer available.');
    if (message.contains('row-level security') || error.statusCode == '403') {
      return const PetsException('You can only change your own pets. Please sign in again.');
    }
    return PetsException('Could not $doing. Please try again.');
  }
  if (error is sb.AuthException) return const PetsException('Please sign in again.');
  if (error is TimeoutException) return const PetsException(_offline);
  final text = error.toString().toLowerCase();
  if (text.contains('socket') || text.contains('failed host lookup') || text.contains('network')) {
    return const PetsException(_offline);
  }
  return const PetsException('Something went wrong. Please try again.');
}

/// A `pets` row as a [Pet].
Pet petFromRow(Map<String, dynamic> row) {
  DateTime? date(Object? value) => value is String ? DateTime.tryParse(value) : null;
  final birth = date(row['birth_date']);
  return Pet(
    id: row['id'] as String,
    name: (row['name'] as String?) ?? '',
    species: PetSpecies.fromName(row['species'] as String?),
    breed: _text(row['breed']),
    weightKg: (row['weight_kg'] as num?)?.toDouble(),
    birthDate: birth == null ? null : DateTime(birth.year, birth.month, birth.day),
    birthDateApprox: row['birth_date_approx'] == true,
    sex: PetSex.fromName(row['sex'] as String?),
    neutered: Neutered.fromName(row['neutered'] as String?),
    photoPath: _text(row['photo_path']),
    iconKey: _text(row['icon_key']),
    archivedAt: date(row['archived_at'])?.toLocal(),
    reminderSnoozedUntil: date(row['reminder_snoozed_until'])?.toLocal(),
    createdAt: date(row['created_at'])?.toLocal(),
    feeding: FeedingStatus(dailyGoal: (row['daily_calorie_goal'] as num?)?.toInt()),
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
    'weight_kg': pet.weightKg == null ? null : (pet.weightKg! * 1000).round() / 1000,
    'sex': pet.sex?.name,
    'neutered': pet.neutered?.name,
    'photo_path': pet.photoPath,
    'icon_key': pet.iconKey,
    'archived_at': pet.archivedAt?.toUtc().toIso8601String(),
    'reminder_snoozed_until': pet.reminderSnoozedUntil?.toUtc().toIso8601String(),
    'daily_calorie_goal': pet.feeding.dailyGoal,
  };
}

String? _text(Object? value) => value is String && value.trim().isNotEmpty ? value : null;
