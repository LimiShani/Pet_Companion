import '../../../services/pets/data/pets_repository.dart';
import '../../../services/pets/data/pets_repository_provider.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/pet.dart';
import '../../../services/pet_records/data/health_models.dart';

/// Finds the picture that goes on a pet's lost card. Behind an interface so
/// tests never load a photo.
abstract class LostCardPhotoSource {
  /// The pet's own photo, or `null` when it has none (or it cannot be
  /// loaded): the card then simply has no picture.
  Future<ImageProvider?> photoOf(Pet pet);
}

/// [LostCardPhotoSource] on the pet's profile: the stored photo of a real
/// pet, or the bundled one of a sample pet. A pet that only has an icon has
/// no photo.
class PetProfilePhotoSource implements LostCardPhotoSource {
  const PetProfilePhotoSource(this._load);

  /// Loads the photo stored at a path of the pets' photo bucket.
  final Future<PetPhotoData> Function(String path) _load;

  @override
  Future<ImageProvider?> photoOf(Pet pet) async {
    final path = pet.photoPath;
    if (path != null) {
      try {
        final photo = await _load(path);
        final bytes = photo.bytes;
        if (bytes != null) return MemoryImage(bytes);
        final url = photo.url;
        if (url != null) {
          return CachedNetworkImageProvider(url.toString(), cacheKey: path);
        }
      } catch (_) {
        // No picture is better than no card.
      }
      return null;
    }
    final asset = pet.photoAsset;
    return asset == null ? null : AssetImage(asset);
  }
}

final lostCardPhotoSourceProvider = Provider<LostCardPhotoSource>(
  (ref) => PetProfilePhotoSource(
    (path) => ref.read(petsRepositoryProvider).loadPhoto(path),
  ),
);

/// Turns the card on screen into files to share. Behind an interface so
/// tests do not depend on the drawing engine.
///
/// Both methods throw a [HealthException] when the file cannot be made.
abstract class LostCardRenderer {
  /// The widget under [boundary] (a [RepaintBoundary]'s key) as a PNG about
  /// [width] pixels wide.
  Future<Uint8List> png(GlobalKey boundary, {double width = 1080});

  /// One printable A4 page with [png] on it.
  Future<Uint8List> pdf(Uint8List png, {required String title});
}

/// [LostCardRenderer] that photographs the card exactly as the page shows
/// it, so every script and the phone's own fonts come out right.
class WidgetLostCardRenderer implements LostCardRenderer {
  const WidgetLostCardRenderer();

  static final _failed = HealthException.of(HealthFailure.lostCard);

  @override
  Future<Uint8List> png(GlobalKey boundary, {double width = 1080}) async {
    try {
      final render = boundary.currentContext?.findRenderObject();
      if (render is! RenderRepaintBoundary || render.size.isEmpty) {
        throw _failed;
      }
      final image = await render.toImage(pixelRatio: width / render.size.width);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw _failed;
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on HealthException {
      rethrow;
    } catch (_) {
      throw _failed;
    }
  }

  @override
  Future<Uint8List> pdf(Uint8List png, {required String title}) async {
    try {
      final doc = pw.Document(title: title, creator: 'PetLoop');
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => pw.Center(
            child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        ),
      );
      return await doc.save();
    } catch (_) {
      throw _failed;
    }
  }
}

final lostCardRendererProvider = Provider<LostCardRenderer>(
  (ref) => const WidgetLostCardRenderer(),
);
