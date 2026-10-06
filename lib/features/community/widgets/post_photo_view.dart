import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../services/community/data/community_models.dart';

/// The picture of a post or a chat message: rounded, 4:3, whatever its
/// source. With [aspectRatio] `null` it takes its own shape (the full
/// screen photo viewer, with [fit] `BoxFit.contain`).
class PostPhotoView extends StatelessWidget {
  const PostPhotoView({
    super.key,
    required this.photo,
    this.aspectRatio = 4 / 3,
    this.fit = BoxFit.cover,
    this.rounded = true,
  });

  final PostPhoto photo;
  final double? aspectRatio;
  final BoxFit fit;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.communityL10n.photoLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          rounded ? AppSpacing.fieldRadius : 0,
        ),
        child: _shaped(
          switch (photo) {
            AssetPostPhoto(:final asset) => Image.asset(
              asset,
              fit: fit,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) => const _PhotoFallback(),
            ),
            PlaceholderPostPhoto(:final color, :final icon) => ColoredBox(
              color: color,
              child: Center(
                child: AppIcon(
                  icon,
                  size: 72,
                  color: AppColors.ink.withValues(alpha: 0.55),
                ),
              ),
            ),
            MemoryPostPhoto(:final bytes) => Image.memory(
              bytes,
              fit: fit,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) => const _PhotoFallback(),
            ),
            RemotePostPhoto(:final url, :final cacheKey) => CachedNetworkImage(
              imageUrl: url,
              cacheKey: cacheKey,
              fit: fit,
              placeholder: (context, url) =>
                  const _PhotoFallback(loading: true),
              errorWidget: (context, url, error) => const _PhotoFallback(),
            ),
          },
        ),
      ),
    );
  }

  Widget _shaped(Widget child) => aspectRatio == null
      ? child
      : AspectRatio(aspectRatio: aspectRatio!, child: child);
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
        child: AppIcon(
          loading ? Icons.image_rounded : Icons.broken_image_rounded,
          size: 48,
          color: AppColors.brown.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
