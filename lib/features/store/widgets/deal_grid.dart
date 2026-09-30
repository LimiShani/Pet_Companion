import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../data/deal.dart';

/// Builds the card of one deal in a [SliverDealGrid].
typedef DealCardBuilder = Widget Function(BuildContext context, Deal deal);

/// A responsive grid of deal cards, as a sliver: two columns on a phone,
/// more on wider screens. Cards in a row share the height of the tallest,
/// and no card has a fixed height, so long titles and wrapped prices fit.
class SliverDealGrid extends StatelessWidget {
  const SliverDealGrid({super.key, required this.deals, required this.cardBuilder});

  final List<Deal> deals;
  final DealCardBuilder cardBuilder;

  /// A card is never narrower than this (except with the minimum of two
  /// columns on a very small phone).
  static const _minCardWidth = 165.0;
  static const _gap = AppSpacing.cardGap;

  static int columnsFor(double width) {
    final usable = width - AppSpacing.screen * 2;
    return ((usable + _gap) / (_minCardWidth + _gap)).floor().clamp(2, 6);
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.crossAxisExtent);
        final rows = (deals.length / columns).ceil();
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          sliver: SliverList.builder(
            itemCount: rows,
            itemBuilder: (context, row) {
              final start = row * columns;
              return Padding(
                padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : _gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < columns; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: start + i < deals.length
                              ? cardBuilder(context, deals[start + i])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
