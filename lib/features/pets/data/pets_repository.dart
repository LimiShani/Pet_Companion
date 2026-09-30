import 'dart:typed_data';

import '../../../models/pet.dart';

/// Thrown by a [PetsRepository] with a message safe to show to the owner.
class PetsException implements Exception {
  const PetsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where a pet's cropped photo comes from: bytes already at hand (the
/// sample data) or a short-lived link to the private bucket.
class PetPhotoData {
  const PetPhotoData.bytes(Uint8List this.bytes) : url = null;
  const PetPhotoData.url(Uri this.url) : bytes = null;

  final Uint8List? bytes;
  final Uri? url;
}

/// The owner's pets and their profile photos. The app talks only to this
/// interface: an in-memory implementation serves the sample data and a
/// Supabase one serves real accounts.
///
/// Every method throws a [PetsException] when it fails.
abstract class PetsRepository {
  /// The pets of [ownerId] when they are at hand without waiting (the
  /// sample data), or `null` when they have to be fetched first.
  List<Pet>? cachedPets(String? ownerId);

  /// Every pet of the owner, archived ones included, oldest first.
  Future<List<Pet>> fetchPets(String ownerId);

  /// Creates the pet, or updates the one with the same id. Returns it as
  /// stored.
  Future<Pet> savePet(String ownerId, Pet pet);

  /// Removes the pet and its photos for good.
  Future<void> deletePet(String ownerId, Pet pet);

  /// Stores a cropped profile photo (JPEG) and returns its storage path.
  Future<String> uploadPhoto(String ownerId, String petId, Uint8List jpeg);

  Future<void> deletePhoto(String path);

  /// What to show for the photo stored at [path].
  Future<PetPhotoData> loadPhoto(String path);
}
