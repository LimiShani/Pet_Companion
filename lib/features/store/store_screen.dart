import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import 'data/deal.dart';
import 'data/deal_filters.dart';
import 'state/store_providers.dart';
import 'store_routes.dart';
import 'widgets/deal_card.dart';
import 'widgets/deal_grid.dart';
import 'widgets/store_messages.dart';

/// The Store tab: a marketplace of bargain pet products. Each deal links
/// out to its seller; nothing is bought inside the app.
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  late final _search = TextEditingController(text: ref.read(storeFilterProvider).query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ok = await ref.read(dealsProvider.notifier).refresh();
    if (!ok && mounted) showStoreMessage(context, 'Could not refresh the deals. Please try again.');
  }

  void _clearFilters() {
    _search.clear();
    ref.read(storeFilterProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(storeFilterProvider);
    final deals = ref.watch(visibleDealsProvider);
    final now = ref.watch(storeClockProvider)();
    // Load the user's saved and reported deals together with the catalogue,
    // without rebuilding the whole tab when they change.
    ref.listen(savedDealIdsProvider, (_, _) {});
    ref.listen(reportedDealIdsProvider, (_, _) {});

    final loading = deals.isLoading && !deals.hasValue;
    final failed = !loading && deals.hasError && !deals.hasValue;
    final shown = deals.value ?? const <Deal>[];

    return Scaffold(
      key: const Key('store-screen'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: 'Store',
            bottom: _SearchField(
              controller: _search,
              onChanged: ref.read(storeFilterProvider.notifier).setQuery,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.coralDark,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (failed)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load deals',
                        message: storeErrorMessage(deals.error!),
                        actionLabel: 'Try again',
                        onAction: () => ref.read(dealsProvider.notifier).refresh(),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _CategoryChips(
                        selected: filter.category,
                        onSelected: ref.read(storeFilterProvider.notifier).setCategory,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SortRow(
                        count: shown.length,
                        sort: filter.sort,
                        onSort: ref.read(storeFilterProvider.notifier).setSort,
                      ),
                    ),
                    if (shown.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoDeals(filter: filter, onClear: _clearFilters),
                      )
                    else
                      SliverDealGrid(
                        deals: shown,
                        cardBuilder: (context, deal) => DealCard(
                          key: ValueKey('deal-card-${deal.id}'),
                          deal: deal,
                          expired: deal.isExpired(now),
                          onTap: () => context.push(StoreRoutes.deal(deal.id)),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppText.body.copyWith(fontSize: 16, color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search deals',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.brown),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, color: AppColors.brown),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final DealCategory? selected;
  final ValueChanged<DealCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, DealCategory? category) {
      final on = selected == category;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          selectedColor: AppColors.sage,
          side: on ? const BorderSide(color: AppColors.sage) : null,
          onSelected: (_) => onSelected(category),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen - 8, 0),
      child: Row(
        children: [
          chip('All', null),
          for (final category in DealCategory.values) chip(category.label, category),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.count, required this.sort, required this.onSort});

  final int count;
  final DealSort sort;
  final ValueChanged<DealSort> onSort;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 6, AppSpacing.screen, 10),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              count == 1 ? '1 deal' : '$count deals',
              style: AppText.secondary.copyWith(color: AppColors.brown, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<DealSort>(
              tooltip: 'Sort deals',
              initialValue: sort,
              onSelected: onSort,
              color: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
              itemBuilder: (context) => [
                for (final option in DealSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option.label,
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: option == sort ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        sort.label,
                        style: AppText.secondary.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.brown),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDeals extends StatelessWidget {
  const _NoDeals({required this.filter, required this.onClear});

  final StoreFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (!filter.isNarrowed) {
      return const EmptyState(
        icon: Icons.shopping_bag_rounded,
        title: 'No deals yet',
        message: 'New bargains will show up here. Found one yourself? Share it with other pet owners.',
      );
    }
    final query = filter.query.trim();
    final category = filter.category?.label;
    final String message;
    if (query.isEmpty) {
      message = 'There are no deals in $category right now. Try a different category.';
    } else if (category == null) {
      message = 'Nothing matches "$query". Try another word.';
    } else {
      message = 'Nothing matches "$query" in $category. Try another word or a different category.';
    }
    return EmptyState(
      icon: Icons.search_rounded,
      title: 'No deals found',
      message: message,
      actionLabel: 'Clear filters',
      onAction: onClear,
    );
  }
}
