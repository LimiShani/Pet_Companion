import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../data/pets_repository_provider.dart';
import '../data/photo_services.dart';
import '../icons/pet_icon_bank.dart';
import '../widgets/pets_widgets.dart';
import 'icon_bank_screen.dart';

/// A picture the owner chose for a pet.
sealed class PetPicture {
  const PetPicture();
}

/// A cropped photo: a square JPEG, not stored yet.
class PhotoPicture extends PetPicture {
  const PhotoPicture(this.jpeg);

  final Uint8List jpeg;
}

/// An icon from the bank on a background.
class IconPicture extends PetPicture {
  const IconPicture(this.choice);

  final PetIconChoice choice;
}

/// No picture: the default icon of the pet's kind.
class NoPicture extends PetPicture {
  const NoPicture();
}

enum _PictureAction { camera, gallery, icon, remove }

/// Lets the owner choose a picture: a bottom sheet with "Take a photo",
/// "Choose from your photos", "Pick an icon" and, when there is a picture
/// ([canRemove]), "Remove picture". A photo goes on to the crop step, an
/// icon to the bank.
///
/// Returns what was chosen, or `null` when the owner backed out. Nothing is
/// saved here: see [savePetPicture].
Future<PetPicture?> choosePetPicture(
  BuildContext context, {
  required String petName,
  required PetSpecies species,
  required bool canRemove,
  PetIconChoice? currentIcon,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final action = await showPetsSheet<_PictureAction>(
    context,
    _PictureSheet(petName: petName, species: species, canRemove: canRemove),
  );
  if (action == null || !context.mounted) return null;

  switch (action) {
    case _PictureAction.remove:
      return const NoPicture();
    case _PictureAction.icon:
      final choice = await pushPetsPage<PetIconChoice>(
        context,
        IconBankScreen(species: species, initial: currentIcon),
      );
      return choice == null ? null : IconPicture(choice);
    case _PictureAction.camera:
    case _PictureAction.gallery:
      final source = action == _PictureAction.camera ? PetPhotoSource.camera : PetPhotoSource.gallery;
      try {
        // "Choose another" on the crop step comes back here.
        while (true) {
          final photo = await container.read(petPhotoPickerProvider).pick(source);
          if (photo == null || !context.mounted) return null;
          final outcome = await container.read(petPhotoCropperProvider).crop(context, photo);
          if (outcome.jpeg != null) return PhotoPicture(outcome.jpeg!);
          if (!outcome.another || !context.mounted) return null;
        }
      } catch (e) {
        if (context.mounted) showPetsSnack(context, petsErrorMessage(e));
        return null;
      }
  }
}

/// Makes [picture] the picture of [pet] and saves it: a photo is uploaded
/// first, and the photo it replaces is removed afterwards. Returns the pet
/// as stored. Throws a `PetsException` when that fails; the pet keeps its
/// old picture then.
Future<Pet> savePetPicture(PetsStore store, Pet pet, PetPicture picture) async {
  final oldPath = pet.photoPath;
  final Pet next;
  switch (picture) {
    case PhotoPicture(:final jpeg):
      next = pet.withPicture(photoPath: await store.uploadPhoto(pet.id, jpeg));
    case IconPicture(:final choice):
      next = pet.withPicture(iconKey: choice.key);
    case NoPicture():
      next = pet.withPicture();
  }
  final stored = await store.save(next);
  if (oldPath != null && oldPath != stored.photoPath) await store.deletePhoto(oldPath);
  return stored;
}

class _PictureSheet extends StatelessWidget {
  const _PictureSheet({required this.petName, required this.species, required this.canRemove});

  final String petName;
  final PetSpecies species;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    void choose(_PictureAction action) => Navigator.of(context).pop(action);
    final name = petName.trim();
    const chevron = Icon(Icons.chevron_right_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PetsHeading(name.isEmpty ? "Your pet's picture" : "$name's picture"),
        const SizedBox(height: 14),
        PetsRow(
          leading: const PetsDisc(Icons.photo_camera_rounded),
          title: 'Take a photo',
          subtitle: 'Opens the camera',
          trailing: chevron,
          onTap: () => choose(_PictureAction.camera),
        ),
        const SizedBox(height: 8),
        PetsRow(
          leading: const PetsDisc(Icons.image_rounded),
          title: 'Choose from your photos',
          subtitle: 'Then fit it into the circle',
          trailing: chevron,
          onTap: () => choose(_PictureAction.gallery),
        ),
        const SizedBox(height: 8),
        PetsRow(
          leading: const PetsDisc(Icons.emoji_emotions_rounded),
          title: 'Pick an icon',
          subtitle: '${PetIcon.values.length} animals in the app\'s colours',
          trailing: chevron,
          onTap: () => choose(_PictureAction.icon),
        ),
        if (canRemove) ...[
          const SizedBox(height: 8),
          PetsRow(
            leading: const PetsDisc(Icons.delete_outline_rounded),
            title: 'Remove picture',
            subtitle: 'Back to the default ${species == PetSpecies.other ? '' : '${species.label.toLowerCase()} '}icon',
            onTap: () => choose(_PictureAction.remove),
          ),
        ],
      ],
    );
  }
}
