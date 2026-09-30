import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import 'data/deal.dart';
import 'state/store_providers.dart';
import 'store_strings.dart';
import 'widgets/deal_grid.dart';

/// The deals the signed-in user saved with the heart. Never narrowed to
/// one pet: what was saved for the cat stays in view while shopping for
/// the dog.
class SavedDealsScreen extends ConsumerWidget {
  const SavedDealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedDealsProvider);
    final savedIds = ref.watch(savedDealIdsProvider);

    final loading = (saved.isLoading && !saved.hasValue) || (savedIds.isLoading && !savedIds.hasValue);
    final failed = !loading && ((saved.hasError && !saved.hasValue) || (savedIds.hasError && !savedIds.hasValue));
    final deals = saved.value ?? const <Deal>[];

    final Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (failed) {
      body = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: StoreStrings.couldNotLoadSaved,
        message: storeErrorMessage((saved.error ?? savedIds.error)!),
        actionLabel: StoreStrings.tryAgain,
        onAction: () {
          ref.invalidate(savedDealIdsProvider);
          ref.read(dealsProvider.notifier).refresh();
        },
      );
    } else if (deals.isEmpty) {
      body = EmptyState(
        icon: Icons.favorite_border_rounded,
        title: StoreStrings.noSavedDealsTitle,
        message: StoreStrings.noSavedDealsMessage,
        actionLabel: StoreStrings.browseDeals,
        onAction: () => Navigator.of(context).maybePop(),
      );
    } else {
      body = CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 16, AppSpacing.screen, 12),
              child: Text(
                StoreStrings.savedCount(deals.length),
                style: AppText.secondary.copyWith(color: AppColors.brown, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverDealGrid(deals: deals, showAnimals: true),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoralHeader(title: StoreStrings.savedDealsTitle, showBack: true),
          Expanded(child: body),
        ],
      ),
    );
  }
}
