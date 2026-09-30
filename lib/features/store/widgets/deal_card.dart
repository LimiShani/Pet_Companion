import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../data/deal.dart';
import '../store_format.dart';
import '../store_strings.dart';
import 'deal_badge.dart';
import 'deal_image.dart';

/// One deal in the grid: picture, discount badge, title, the price with the
/// old price struck through, the unit price and delivery when they are
/// known, and the seller.
class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.deal,
    required this.expired,
    this.onTap,
    this.corner,
    this.showAnimals = false,
  });

  final Deal deal;

  /// The deal is over: it is dimmed and badged "Expired".
  final bool expired;
  final VoidCallback? onTap;

  /// Shown on the picture's top end corner (the save button).
  final Widget? corner;

  /// Tags a deal that is for some kinds of animal only ("Cats"). Used where
  /// deals for every animal are listed together.
  final bool showAnimals;

  @override
  Widget build(BuildContext context) {
    final textColor = expired ? AppColors.brown : AppColors.ink;
    final unitPrice = deal.unitPrice;
    final delivery = deal.deliveryCost;

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
                PositionedDirectional(start: 10, top: 10, child: DealBadge(deal: deal, expired: expired)),
                if (corner != null) PositionedDirectional(end: 4, top: 4, child: corner!),
                if (showAnimals && !deal.isForEveryPet)
                  PositionedDirectional(
                    start: 10,
                    end: 10,
                    bottom: 8,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AnimalsTag(
                        key: ValueKey('animals-${deal.id}'),
                        label: StoreStrings.animalsTag(deal.speciesInOrder),
                        color: AppColors.white.withValues(alpha: 0.94),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 12),
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
                  if (unitPrice != null) ...[
                    const SizedBox(height: 5),
                    _UnitPricePill(text: StoreFormat.unitPrice(unitPrice, deal.currency), color: textColor),
                  ],
                  if (delivery != null) ...[
                    const SizedBox(height: 5),
                    _SmallLine(
                      icon: Icons.local_shipping_outlined,
                      text: delivery == 0
                          ? StoreStrings.freeDelivery
                          : StoreStrings.plusDelivery(StoreFormat.money(delivery, deal.currency)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _SmallLine(icon: Icons.storefront_rounded, text: deal.sellerName),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "₪18.90 per kg": the number shoppers compare, set apart in a pale pill.
class _UnitPricePill extends StatelessWidget {
  const _UnitPricePill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFE4E7C3), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: AppText.label.copyWith(color: color, fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A small brown line with an icon: the seller, the delivery cost.
class _SmallLine extends StatelessWidget {
  const _SmallLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.brown),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppText.label.copyWith(color: AppColors.brown),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
