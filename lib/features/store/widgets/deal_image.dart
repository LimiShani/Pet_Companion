import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_icon.dart';
import '../data/deal.dart';

/// The colour and icon that stand for a category: on a deal without a
/// picture, and wherever a category needs a small visual.
extension DealCategoryStyle on DealCategory {
  Color get tileColor => switch (this) {
        DealCategory.food => AppColors.sage,
        DealCategory.treats => const Color(0xFFF6CDB9),
        DealCategory.litterAndCleaning => const Color(0xFFE0E6D3),
        DealCategory.toys => AppColors.yellow,
        DealCategory.health => const Color(0xFFE0E6D3),
        DealCategory.grooming => AppColors.sage,
        DealCategory.accessories => const Color(0xFFFBE9BD),
        DealCategory.bedsAndCrates => AppColors.peach,
      };

  IconData get icon => switch (this) {
        DealCategory.food => Icons.restaurant_rounded,
        DealCategory.treats => Icons.cookie_rounded,
        DealCategory.litterAndCleaning => Icons.cleaning_services_rounded,
        DealCategory.toys => Icons.sports_baseball_rounded,
        DealCategory.health => Icons.medical_services_rounded,
        DealCategory.grooming => Icons.content_cut_rounded,
        DealCategory.accessories => Icons.pets_rounded,
        DealCategory.bedsAndCrates => Icons.bed_rounded,
      };
}

/// A deal's picture, filling its parent. Falls back to a coloured tile with
/// the category's icon when the deal has no picture or it cannot be loaded.
class DealImage extends StatelessWidget {
  const DealImage({super.key, required this.deal, this.discSize = 60, this.faded = false});

  final Deal deal;

  /// Diameter of the white disc behind the category icon.
  final double discSize;

  /// Dims the picture, for a deal that is over.
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final tile = _CategoryTile(category: deal.category, discSize: discSize, faded: faded);
    final url = deal.imageUrl;
    if (url == null || url.isEmpty) return tile;
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => tile,
        errorWidget: (context, url, error) => tile,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.discSize, required this.faded});

  final DealCategory category;
  final double discSize;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: category.tileColor,
      child: Center(
        child: Opacity(
          opacity: faded ? 0.55 : 1,
          child: Container(
            width: discSize,
            height: discSize,
            decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.72), shape: BoxShape.circle),
            child: AppIcon(category.icon, size: discSize / 2, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
