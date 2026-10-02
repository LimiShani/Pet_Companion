import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_icon.dart';
import '../data/deal.dart';
import '../store_format.dart';

/// The pill on a deal's picture: "-40%", or "Expired" once the deal is
/// over. White text on a dark pill, so it reads on every tile colour.
class DealBadge extends StatelessWidget {
  const DealBadge({super.key, required this.deal, required this.expired, this.large = false});

  final Deal deal;
  final bool expired;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (!expired && deal.discountPercent <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 13 : 9, vertical: large ? 6 : 4),
      decoration: BoxDecoration(
        color: expired ? AppColors.ink : AppColors.coralDark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        expired ? context.storeL10n.expired : StoreFormat.of(context).discount(deal.discountPercent),
        style: TextStyle(fontSize: large ? 15 : 12, fontWeight: FontWeight.w800, color: AppColors.white),
      ),
    );
  }
}

/// Who a deal is for, with a paw: "Cats" on a card's picture, "For dogs and
/// cats" on the deal page.
class AnimalsTag extends StatelessWidget {
  const AnimalsTag({super.key, required this.label, this.color = AppColors.white, this.large = false});

  final String label;
  final Color color;

  /// The size of the pills on the deal page rather than the tag on a card.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(large ? 10 : 7, large ? 5 : 3, large ? 12 : 9, large ? 5 : 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(Icons.pets_rounded, size: large ? 13 : 11, color: AppColors.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: large ? 12 : 11, fontWeight: large ? FontWeight.w700 : FontWeight.w800, color: AppColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
