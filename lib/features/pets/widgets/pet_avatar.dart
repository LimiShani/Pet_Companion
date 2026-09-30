import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pet.dart';
import '../data/pets_repository.dart';
import '../data/pets_repository_provider.dart';
import '../icons/pet_icon_bank.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// What to show for the photo stored at a path of the `pet-photos` bucket.
/// Kept for the session, so a photo is fetched once however many avatars
/// show it; a new photo always gets a new path.
final petPhotoProvider = FutureProvider.family<PetPhotoData, String>(
  (ref, path) => ref.watch(petsRepositoryProvider).loadPhoto(path),
  retry: _noRetry,
);

/// The pet's round picture: its photo, its icon from the bank, or the
/// default icon of its kind. Handles loading and a failed photo itself (the
/// icon shows meanwhile).
class PetAvatar extends ConsumerWidget {
  const PetAvatar({
    super.key,
    required this.pet,
    this.size = 56,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
    this.dimmed = false,
  });

  final Pet pet;

  /// Diameter, the border included.
  final double size;
  final VoidCallback? onTap;

  /// A ring around the picture ([borderWidth] wide), e.g. coral on a profile.
  final Color? borderColor;
  final double borderWidth;

  /// Faded, for an archived pet.
  final bool dimmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = pet.photoPath;
    final photo = path == null ? null : ref.watch(petPhotoProvider(path)).value;
    final fallback = PetIconChoice.parse(pet.iconKey, species: pet.species);

    final label = pet.name.trim().isEmpty ? 'Pet picture' : "${pet.name}'s picture";
    Widget circle = PetPictureCircle(
      size: size,
      icon: fallback,
      asset: path == null ? pet.photoAsset : null,
      bytes: photo?.bytes,
      url: photo?.url,
      cacheKey: path,
      borderColor: borderColor,
      borderWidth: borderWidth,
    );
    if (dimmed) circle = Opacity(opacity: 0.55, child: circle);

    return Semantics(
      image: true,
      button: onTap != null,
      label: label,
      child: onTap == null
          ? circle
          : Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: circle),
            ),
    );
  }
}

/// A round picture from whatever is at hand: photo bytes, a link, a bundled
/// asset, or an icon of the bank on its background. The first one given
/// wins; the icon also stands in while a photo loads or when it fails.
class PetPictureCircle extends StatelessWidget {
  const PetPictureCircle({
    super.key,
    required this.size,
    required this.icon,
    this.bytes,
    this.url,
    this.cacheKey,
    this.asset,
    this.borderColor,
    this.borderWidth = 0,
  });

  final double size;
  final PetIconChoice icon;
  final Uint8List? bytes;
  final Uri? url;

  /// The storage path of [url]: the link changes, the photo under it not.
  final String? cacheKey;
  final String? asset;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final inner = size - 2 * borderWidth;
    final iconSize = inner * (inner <= 24 ? 0.86 : 0.78);
    final drawn = ColoredBox(
      color: icon.background.color,
      child: Center(child: PetIconImage(icon.icon, size: iconSize)),
    );

    Widget picture = drawn;
    if (bytes != null) {
      picture = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => drawn,
      );
    } else if (url != null) {
      picture = CachedNetworkImage(
        imageUrl: url.toString(),
        cacheKey: cacheKey,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        placeholder: (_, _) => drawn,
        errorWidget: (_, _, _) => drawn,
      );
    } else if (asset != null) {
      picture = Image.asset(
        asset!,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => drawn,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: icon.background.color,
        border: borderWidth > 0 && borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
      ),
      child: ClipOval(child: SizedBox.square(dimension: inner, child: picture)),
    );
  }
}
