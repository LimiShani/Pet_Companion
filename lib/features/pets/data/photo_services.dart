import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../picture/crop_photo_screen.dart';
import 'pets_repository.dart';

enum PetPhotoSource { camera, gallery }

/// Lets the owner take or choose a photo of a pet. Behind an interface so
/// tests never open the camera or the photo library.
abstract class PetPhotoPicker {
  /// The chosen photo, or `null` when the owner backed out. Throws a
  /// [PetsException] when the device cannot do it.
  Future<Uint8List?> pick(PetPhotoSource source);
}

/// [PetPhotoPicker] on the `image_picker` plugin. The photo is scaled down
/// on the device, so cropping stays quick.
class DevicePetPhotoPicker implements PetPhotoPicker {
  const DevicePetPhotoPicker();

  /// Longest side handed to the crop screen, in pixels.
  static const maxSide = 1600.0;

  @override
  Future<Uint8List?> pick(PetPhotoSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source == PetPhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: 90,
      );
      return file == null ? null : await file.readAsBytes();
    } on PlatformException {
      throw PetsException.of(
        source == PetPhotoSource.camera ? PetsFailure.cameraNotAllowed : PetsFailure.photosNotAllowed,
      );
    } catch (_) {
      throw PetsException.of(source == PetPhotoSource.camera ? PetsFailure.camera : PetsFailure.photos);
    }
  }
}

final petPhotoPickerProvider = Provider<PetPhotoPicker>((ref) => const DevicePetPhotoPicker());

/// How the crop step ended.
class CropOutcome {
  /// The owner chose "Use photo": [jpeg] is the square profile picture.
  const CropOutcome.cropped(Uint8List this.jpeg) : another = false;

  /// The owner chose "Choose another".
  const CropOutcome.another()
      : jpeg = null,
        another = true;

  /// The owner went back.
  const CropOutcome.cancelled()
      : jpeg = null,
        another = false;

  final Uint8List? jpeg;
  final bool another;
}

/// Lets the owner fit a photo into the round profile shape. Behind an
/// interface so tests need no gestures and no image decoding.
abstract class PetPhotoCropper {
  Future<CropOutcome> crop(BuildContext context, Uint8List photo);
}

/// [PetPhotoCropper] that opens [CropPhotoScreen].
class ScreenPetPhotoCropper implements PetPhotoCropper {
  const ScreenPetPhotoCropper();

  @override
  Future<CropOutcome> crop(BuildContext context, Uint8List photo) async {
    // The crop screen could only wait forever on a file it cannot read.
    if (!isReadablePhoto(photo)) {
      throw PetsException.of(PetsFailure.photoUnsupportedChooseAnother);
    }
    final outcome = await Navigator.of(context, rootNavigator: true).push<CropOutcome>(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => CropPhotoScreen(photo: photo),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    return outcome ?? const CropOutcome.cancelled();
  }
}

final petPhotoCropperProvider = Provider<PetPhotoCropper>((ref) => const ScreenPetPhotoCropper());

/// Whether [bytes] look like a picture the app can crop (JPEG, PNG, WebP,
/// GIF, BMP…). Only the file's header is read.
bool isReadablePhoto(Uint8List bytes) {
  try {
    return img.findDecoderForData(bytes) != null;
  } catch (_) {
    return false;
  }
}

/// Side of the stored profile picture, in pixels.
const kPetPhotoSide = 512;

/// Shrinks a cropped picture to a [kPetPhotoSide] square JPEG (about 60 KB).
/// Throws a [PetsException] when [cropped] is not a picture.
Uint8List squarePetPhoto(Uint8List cropped) {
  img.Image? image;
  try {
    image = img.decodeImage(cropped);
  } catch (_) {
    // Not a picture at all: reported below.
  }
  if (image == null) throw PetsException.of(PetsFailure.photoUnsupported);
  final resized = img.copyResize(
    image,
    width: kPetPhotoSide,
    height: kPetPhotoSide,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(resized, quality: 85);
}

/// [squarePetPhoto] off the main thread.
Future<Uint8List> squarePetPhotoInBackground(Uint8List cropped) => compute(squarePetPhoto, cropped);
