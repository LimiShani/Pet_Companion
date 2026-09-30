import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/deal.dart';
import '../store_format.dart';
import 'deal_badge.dart';
import 'deal_image.dart';

/// One deal in the grid: picture, discount badge, title, the price with the
/// old price struck through, and the seller.
class DealCard extends StatelessWidget {
  const DealCard({super.key, required this.deal, required this.expired, this.onTap, this.corner});

  final Deal deal;

  /// The deal is over: it is dimmed and badged "Expired".
  final bool expired;
  final VoidCallback? onTap;

  /// Shown on the picture's top right corner (the save button).
  final Widget? corner;

  @override
  Widget build(BuildContext context) {
    final textColor = expired ? AppColors.brown : AppColors.ink;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(aspectRatio: 4 / 3, child: DealImage(deal: deal, faded: expired)),
                Positioned(left: 10, top: 10, child: DealBadge(deal: deal, expired: expired)),
                if (corner != null) Positioned(right: 4, top: 4, child: corner!),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deal.title,
                    style: AppText.cardTitle.copyWith(color: textColor, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  DealPrices(deal: deal, color: textColor),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: AppColors.brown),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          deal.sellerName,
                          style: AppText.label.copyWith(color: AppColors.brown),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "₪179  ₪299": the price now, then the old price struck through. Wraps
/// onto two lines when they do not fit side by side.
class DealPrices extends StatelessWidget {
  const DealPrices({super.key, required this.deal, this.color = AppColors.ink, this.large = false});

  final Deal deal;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final showOriginal = deal.originalPrice > deal.price;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          StoreFormat.money(deal.price, deal.currency),
          style: (large ? AppText.metric : AppText.pillValue).copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (showOriginal)
          Text(
            StoreFormat.money(deal.originalPrice, deal.currency),
            style: (large ? AppText.cardTitle : AppText.secondary).copyWith(
              color: large ? AppColors.ink : AppColors.brown,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
