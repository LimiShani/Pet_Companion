import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/community_models.dart';

/// The picture of a post: rounded, 4:3, whatever its source.
class PostPhotoView extends StatelessWidget {
  const PostPhotoView({super.key, required this.photo, this.aspectRatio = 4 / 3});

  final PostPhoto photo;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.communityL10n.photoLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: switch (photo) {
            AssetPostPhoto(:final asset) => Image.asset(
                asset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => const _PhotoFallback(),
              ),
            PlaceholderPostPhoto(:final color, :final icon) => ColoredBox(
                color: color,
                child: Center(child: Icon(icon, size: 72, color: AppColors.ink.withValues(alpha: 0.55))),
              ),
            MemoryPostPhoto(:final bytes) => Image.memory(
                bytes,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => const _PhotoFallback(),
              ),
            RemotePostPhoto(:final url, :final cacheKey) => CachedNetworkImage(
                imageUrl: url,
                cacheKey: cacheKey,
                fit: BoxFit.cover,
                placeholder: (context, url) => const _PhotoFallback(loading: true),
                errorWidget: (context, url, error) => const _PhotoFallback(),
              ),
          },
        ),
      ),
    );
  }
}

/// Shown while a picture loads and when it cannot be shown.
class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Center(
        child: Icon(
          loading ? Icons.image_rounded : Icons.broken_image_rounded,
          size: 48,
          color: AppColors.brown.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
