import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pet_selector.dart';
import 'data/deal.dart';
import 'data/deal_filters.dart';
import 'share_deal_screen.dart';
import 'state/store_providers.dart';
import 'store_routes.dart';
import 'store_strings.dart';
import 'widgets/deal_grid.dart';
import 'widgets/store_messages.dart';

/// The Store tab: a marketplace of bargain pet products. Each deal links
/// out to its seller; nothing is bought inside the app.
///
/// It opens on what suits the selected pet; "All animals" in the header
/// shows the deals for every kind of animal.
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
    if (!ok && mounted) showStoreMessage(context, context.storeL10n.couldNotRefresh);
  }

  Future<void> _shareDeal() async {
    final deal = await Navigator.of(context, rootNavigator: true).push<Deal>(
      MaterialPageRoute(fullscreenDialog: true, builder: (context) => const ShareDealScreen()),
    );
    if (deal != null && mounted) showStoreMessage(context, context.storeL10n.dealIsLive);
  }

  void _clearFilters() {
    _search.clear();
    ref.read(storeFilterProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    final filter = ref.watch(storeFilterProvider);
    final deals = ref.watch(visibleDealsProvider);
    final species = ref.watch(storePetSpeciesProvider);
    // Load the user's saved and reported deals together with the catalogue,
    // without rebuilding the whole tab when they change.
    ref.listen(savedDealIdsProvider, (_, _) {});
    ref.listen(reportedDealIdsProvider, (_, _) {});
    // Picking another pet, here or on any other tab, is a choice to shop
    // for that pet: "All animals" gives way to it.
    ref.listen(selectedPetProvider.select((pet) => pet.id), (previous, next) {
      if (previous != next) ref.read(storeFilterProvider.notifier).setAllAnimals(false);
    });

    final loading = deals.isLoading && !deals.hasValue;
    final failed = !loading && deals.hasError && !deals.hasValue;
    final shown = deals.value ?? const <Deal>[];
    final filters = ref.read(storeFilterProvider.notifier);

    return Scaffold(
      key: const Key('store-screen'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _shareDeal,
        icon: const AppIcon(Icons.add_rounded),
        label: Text(l10n.shareADeal),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: l10n.tabTitle,
            actions: [
              CoralHeaderAction(
                icon: Icons.favorite_border_rounded,
                tooltip: l10n.savedDeals,
                onPressed: () => context.push(StoreRoutes.saved),
              ),
            ],
            bottom: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PetScope(allAnimals: filter.allAnimals, onChanged: filters.setAllAnimals),
                const SizedBox(height: 10),
                _SearchField(controller: _search, onChanged: filters.setQuery),
              ],
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
                        title: l10n.couldNotLoadDeals,
                        message: storeErrorText(context, deals.error!),
                        actionLabel: context.l10n.commonTryAgain,
                        onAction: () => ref.read(dealsProvider.notifier).refresh(),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _CategoryChips(selected: filter.category, onSelected: filters.setCategory),
                    ),
                    SliverToBoxAdapter(
                      child: _SortRow(
                        countText: filter.allAnimals
                            ? l10n.dealCount(shown.length)
                            : l10n.dealsFor(shown.length, species),
                        sort: filter.sort,
                        onSort: filters.setSort,
                      ),
                    ),
                    if (shown.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoDeals(
                          filter: filter,
                          species: species,
                          onClear: _clearFilters,
                          onShowAllAnimals: () => filters.setAllAnimals(true),
                        ),
                      )
                    else
                      SliverDealGrid(deals: shown, showAnimals: filter.allAnimals),
                    // Room for the floating button below the last row.
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
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

/// Who the Store is shopping for: the shared row of pet pills, followed by
/// an "All animals" pill. A pet pill selects that pet for the whole app and
/// narrows the Store to its kind; "All animals" shows every deal and leaves
/// no pet highlighted.
class _PetScope extends StatefulWidget {
  const _PetScope({required this.allAnimals, required this.onChanged});

  final bool allAnimals;
  final ValueChanged<bool> onChanged;

  @override
  State<_PetScope> createState() => _PetScopeState();
}

class _PetScopeState extends State<_PetScope> {
  final _allAnimalsKey = GlobalKey();
  Offset? _pressedAt;

  bool _isOnAllAnimals(Offset position) {
    final box = _allAnimalsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(position);
  }

  @override
  Widget build(BuildContext context) {
    // The selector handles taps on its pet pills itself and only reports a
    // change of pet, so tapping the pet that is already selected would not
    // be noticed. Watching for a tap on the row (not a scroll, not on "All
    // animals") catches every way back from "All animals" to a pet.
    return Listener(
      onPointerDown: (event) => _pressedAt = event.position,
      onPointerCancel: (_) => _pressedAt = null,
      onPointerUp: (event) {
        final pressedAt = _pressedAt;
        _pressedAt = null;
        if (!widget.allAnimals || pressedAt == null) return;
        if ((event.position - pressedAt).distance > kTouchSlop) return;
        if (_isOnAllAnimals(event.position)) return;
        widget.onChanged(false);
      },
      child: PetSelector(
        highlightSelected: !widget.allAnimals,
        trailing: _AllAnimalsPill(
          key: _allAnimalsKey,
          selected: widget.allAnimals,
          onTap: () => widget.onChanged(true),
        ),
      ),
    );
  }
}

/// Drawn to match the pet pills of [PetSelector], with a paw for a picture.
class _AllAnimalsPill extends StatelessWidget {
  const _AllAnimalsPill({super.key, required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.yellow : AppColors.onCoralPill,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.yellow : AppColors.onCoralOutline, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.coral : AppColors.white.withValues(alpha: 0.55),
                  ),
                  child: AppIcon(
                    Icons.pets_rounded,
                    size: 13,
                    color: selected ? AppColors.white : AppColors.coralDark,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.storeL10n.allAnimals,
                  style: AppText.cardTitle.copyWith(color: selected ? AppColors.ink : AppColors.white),
                ),
              ],
            ),
          ),
        ),
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
          hintText: context.storeL10n.searchHint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: const AppIcon(Icons.search_rounded, color: AppColors.brown),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.storeL10n.clearSearch,
                  icon: const AppIcon(Icons.close_rounded, color: AppColors.brown),
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
    final l10n = context.storeL10n;

    Widget chip(String label, DealCategory? category) {
      final on = selected == category;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
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
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 12, AppSpacing.screen - 8, 0),
      child: Row(
        children: [
          chip(l10n.allCategories, null),
          for (final category in DealCategory.values) chip(l10n.category(category), category),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.countText, required this.sort, required this.onSort});

  /// "23 deals for dogs", or "36 deals" when every animal is shown.
  final String countText;
  final DealSort sort;
  final ValueChanged<DealSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = context.storeL10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 6, AppSpacing.screen, 10),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              countText,
              key: const Key('store-deal-count'),
              style: AppText.secondary.copyWith(color: AppColors.brown, fontWeight: FontWeight.w700),
            ),
            PopupMenuButton<DealSort>(
              tooltip: l10n.sortTooltip,
              initialValue: sort,
              onSelected: onSort,
              color: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.fieldRadius)),
              itemBuilder: (context) => [
                for (final option in DealSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      l10n.sort(option),
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: option == sort ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 10, 6),
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
                        l10n.sort(sort),
                        style: AppText.secondary.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const AppIcon(Icons.expand_more_rounded, size: 20, color: AppColors.brown),
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

/// What the grid's place shows when there is nothing to list.
class _NoDeals extends ConsumerWidget {
  const _NoDeals({
    required this.filter,
    required this.species,
    required this.onClear,
    required this.onShowAllAnimals,
  });

  final StoreFilter filter;
  final PetSpecies species;
  final VoidCallback onClear;
  final VoidCallback onShowAllAnimals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.storeL10n;
    final query = filter.query.trim();
    final picked = filter.category;
    final category = picked == null ? null : l10n.category(picked);

    // Nothing for this pet, but other animals have deals here: the way out
    // is "All animals", not clearing the search.
    final others = filter.allAnimals ? 0 : ref.watch(allAnimalsDealCountProvider);
    if (others > 0) {
      return EmptyState(
        icon: Icons.pets_rounded,
        title: l10n.noDealsForTitle(species),
        message: l10n.noDealsForMessage(
          species: species,
          query: query,
          category: category,
          othersCount: others,
        ),
        actionLabel: l10n.showAllAnimals,
        onAction: onShowAllAnimals,
      );
    }

    if (!filter.isNarrowed) {
      return EmptyState(
        icon: Icons.shopping_bag_rounded,
        title: l10n.noDealsYetTitle,
        message: l10n.noDealsYetMessage,
      );
    }
    final String message;
    if (query.isEmpty) {
      message = l10n.noDealsInCategory(category!);
    } else if (category == null) {
      message = l10n.nothingMatches(query);
    } else {
      message = l10n.nothingMatchesInCategory(query, category);
    }
    return EmptyState(
      icon: Icons.search_rounded,
      title: l10n.noDealsFoundTitle,
      message: message,
      actionLabel: l10n.clearFilters,
      onAction: onClear,
    );
  }
}
