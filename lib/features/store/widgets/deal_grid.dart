import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_theme.dart';
import '../data/deal.dart';
import '../state/store_providers.dart';
import '../store_routes.dart';
import 'deal_card.dart';
import 'save_deal_button.dart';

/// A responsive grid of deal cards, as a sliver: two columns on a phone,
/// more on wider screens. Cards in a row share the height of the tallest,
/// and no card has a fixed height, so long titles and wrapped prices fit.
class SliverDealGrid extends StatelessWidget {
  const SliverDealGrid({super.key, required this.deals});

  final List<Deal> deals;

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
                              ? _GridCard(key: ValueKey('deal-card-${deals[start + i].id}'), deal: deals[start + i])
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

/// A [DealCard] wired up for the grid: it opens the deal's page and carries
/// the save button.
class _GridCard extends ConsumerWidget {
  const _GridCard({super.key, required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(storeClockProvider)();
    return DealCard(
      deal: deal,
      expired: deal.isExpired(now),
      onTap: () => context.push(StoreRoutes.deal(deal.id)),
      corner: SaveDealButton(key: ValueKey('save-${deal.id}'), dealId: deal.id),
    );
  }
}
