import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../data/deal.dart';

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
        expired ? 'Expired' : '-${deal.discountPercent}%',
        style: TextStyle(fontSize: large ? 15 : 12, fontWeight: FontWeight.w800, color: AppColors.white),
      ),
    );
  }
}
