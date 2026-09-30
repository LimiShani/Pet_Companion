import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'community_models.dart';

enum PhotoSource { gallery, camera }

/// Lets the user choose a picture for a post. Behind an interface so
/// widget tests can inject a fake instead of the platform picker.
abstract class PhotoPicker {
  /// The chosen picture, or `null` when the user backed out.
  Future<PickedPhoto?> pick(PhotoSource source);
}

/// [PhotoPicker] backed by the `image_picker` plugin. Pictures are scaled
/// down and re-encoded on the device so uploads stay small.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Longest side of an uploaded picture, in pixels.
  static const maxDimension = 1600.0;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: 82,
      );
      if (file == null) return null;
      return PickedPhoto(bytes: await file.readAsBytes(), name: file.name, mimeType: file.mimeType);
    } on PlatformException {
      throw CommunityException(
        source == PhotoSource.camera ? CommunityFailure.cameraNotAllowed : CommunityFailure.photosNotAllowed,
      );
    }
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePickerPhotoPicker());
