import 'dart:typed_data';

import '../../../models/pet.dart';

/// Why something about pets failed. Repositories and services report the
/// reason; the screen puts it into words in the app's language (see
/// `petsErrorText` in `pet_words.dart`). [english] is the same in plain
/// English, for logs.
enum PetsFailure {
  notYours('You can only change your own pets. Please sign in again.'),
  invalid('Some of that information is not valid. Please check it and try again.'),
  databaseOutdated('The database is not up to date for pets yet (migration 0005 has not been run).'),
  signInAgain('Please sign in again.'),
  save('Could not save your pet. Please try again.'),
  load('Could not load your pets. Please try again.'),
  delete('Could not delete your pet. Please try again.'),
  photoSave('Could not save the photo. Please try again.'),
  photoRemove('Could not remove the photo. Please try again.'),
  photoLoad('Could not load the photo. Please try again.'),
  photoTooLarge('That photo is too large.'),
  photoUnsupported('That kind of picture is not supported.'),
  photoUnsupportedChooseAnother('That kind of picture is not supported. Please choose another one.'),
  photoGone('That photo is no longer available.'),
  offline('Cannot reach the server. Check your connection and try again.'),
  cameraNotAllowed('Cannot open the camera. Check that Pet Companion is allowed to use it.'),
  photosNotAllowed('Cannot open your photos. Check that Pet Companion is allowed to see them.'),
  camera('Could not open the camera.'),
  photos('Could not open your photos.'),
  nameMissing('A pet needs a name.'),

  /// Anything the app has no words of its own for.
  unknown('Something went wrong. Please try again.');

  const PetsFailure(this.english);

  final String english;
}

/// Thrown by a [PetsRepository] and the photo services. [failure] says what
/// went wrong; [message] is the same in plain English, for logs and for a
/// [PetsFailure.unknown] failure, where it is whatever explanation there is.
class PetsException implements Exception {
  const PetsException(this.message, [this.failure = PetsFailure.unknown]);

  /// The failure [failure], with its English words as the message.
  PetsException.of(this.failure) : message = failure.english;

  final String message;
  final PetsFailure failure;

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
