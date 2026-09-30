import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'health_models.dart';

/// Lets the owner choose a photo or a PDF to attach to a record. Behind an
/// interface so tests never open the camera or a file dialog.
///
/// Each method returns `null` when the owner cancels, and throws a
/// [HealthException] when the device cannot do it.
abstract class AttachmentPicker {
  Future<PickedFile?> takePhoto();
  Future<PickedFile?> pickPhoto();
  Future<PickedFile?> pickPdf();
}

/// [AttachmentPicker] on `image_picker` (photos) and `file_picker` (PDFs).
class DeviceAttachmentPicker implements AttachmentPicker {
  const DeviceAttachmentPicker();

  // Photos are scaled down so they stay far below the bucket's 5 MB limit.
  static const _maxSide = 2000.0;
  static const _quality = 85;

  Future<PickedFile?> _photo(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      if (file == null) return null;
      final name = file.name.isEmpty ? 'photo.jpg' : file.name;
      return PickedFile(
        name: name,
        mimeType: file.mimeType ?? PickedFile.mimeTypeFor(name) ?? 'image/jpeg',
        bytes: await file.readAsBytes(),
      );
    } catch (_) {
      throw HealthException(
        source == ImageSource.camera ? 'Could not open the camera.' : 'Could not open your photos.',
      );
    }
  }

  @override
  Future<PickedFile?> takePhoto() => _photo(ImageSource.camera);

  @override
  Future<PickedFile?> pickPhoto() => _photo(ImageSource.gallery);

  @override
  Future<PickedFile?> pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      final file = result == null || result.files.isEmpty ? null : result.files.first;
      if (file == null) return null;
      final bytes = file.bytes;
      if (bytes == null) throw const HealthException('Could not read that file.');
      return PickedFile(name: file.name, mimeType: 'application/pdf', bytes: bytes);
    } on HealthException {
      rethrow;
    } catch (_) {
      throw const HealthException('Could not open your files.');
    }
  }
}

final attachmentPickerProvider = Provider<AttachmentPicker>((ref) => const DeviceAttachmentPicker());

/// A file handed to another app.
class SharedFile {
  const SharedFile({required this.name, required this.mimeType, required this.bytes, this.subject = ''});

  final String name;
  final String mimeType;
  final Uint8List bytes;

  /// Shown by apps that have a subject line (mail).
  final String subject;
}

/// Hands files and links to other apps: the phone's share sheet, or the
/// system viewer. Behind an interface so tests never touch the platform.
/// Both methods return whether the hand-over happened.
abstract class FileSharer {
  /// Opens the share sheet with [file].
  Future<bool> share(SharedFile file);

  /// Opens [link] (a document's short-lived address) in the system viewer.
  Future<bool> openLink(Uri link);
}

/// [FileSharer] on `share_plus` and `url_launcher`.
class DeviceFileSharer implements FileSharer {
  const DeviceFileSharer();

  @override
  Future<bool> share(SharedFile file) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(file.bytes, name: file.name, mimeType: file.mimeType)],
          fileNameOverrides: [file.name],
          subject: file.subject.isEmpty ? null : file.subject,
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLink(Uri link) async {
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final fileSharerProvider = Provider<FileSharer>((ref) => const DeviceFileSharer());
