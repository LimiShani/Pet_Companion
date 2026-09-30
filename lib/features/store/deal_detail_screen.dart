import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import 'data/deal.dart';
import 'data/link_opener.dart';
import 'state/store_providers.dart';
import 'store_format.dart';
import 'widgets/deal_badge.dart';
import 'widgets/deal_card.dart';
import 'widgets/deal_image.dart';
import 'widgets/save_deal_button.dart';
import 'widgets/store_messages.dart';

/// Everything about one deal, with the button that opens the seller's page.
class DealDetailScreen extends ConsumerWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(dealsProvider);
    final deal = ref.watch(dealByIdProvider(dealId));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: 'Deal',
            showBack: true,
            actions: [if (deal != null) SaveDealButton(dealId: deal.id, inHeader: true)],
          ),
          Expanded(
            child: deal != null
                ? _DealBody(deal: deal)
                : deals.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'This deal is gone',
                        message: 'It may have been removed by the person who shared it.',
                        actionLabel: 'Back to the Store',
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DealBody extends ConsumerWidget {
  const _DealBody({required this.deal});

  final Deal deal;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final uri = safeDealLink(deal.link);
    final opened = uri != null && await ref.read(linkOpenerProvider).open(uri);
    if (!opened && context.mounted) showStoreMessage(context, 'Could not open the offer. Please try again.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(storeClockProvider)();
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final expired = deal.isExpired(now);
    final host = safeDealLink(deal.link)?.host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Stack(
                    children: [
                      AspectRatio(aspectRatio: 16 / 9, child: DealImage(deal: deal, discSize: 92, faded: expired)),
                      Positioned(left: 14, top: 14, child: DealBadge(deal: deal, expired: expired, large: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(label: deal.category.label, color: AppColors.yellow),
                    _Pill(label: _origin(deal, userId)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(deal.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                if (expired) ...[
                  const SizedBox(height: 14),
                  _EndedNotice(endedOn: deal.expiresAt!),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DealPrices(deal: deal, large: true),
                      if (deal.amountSaved > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'You save ${StoreFormat.money(deal.amountSaved, deal.currency)} (${deal.discountPercent}%)',
                          style: AppText.body.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.storefront_rounded, label: 'Seller', value: deal.sellerName),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        label: 'Posted',
                        value: StoreFormat.timeAgo(deal.postedAt, now),
                      ),
                      if (!expired) ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.event_rounded,
                          label: 'Ends',
                          value: StoreFormat.ends(deal.expiresAt, now),
                        ),
                      ],
                    ],
                  ),
                ),
                if (deal.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(deal.description, style: AppText.body.copyWith(height: 1.5)),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 8, AppSpacing.screen, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => _open(context, ref),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                iconAlignment: IconAlignment.end,
                label: const Text('Open offer'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (host != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Opens $host in your browser',
                  style: AppText.label.copyWith(color: AppColors.brown, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _origin(Deal deal, String? userId) {
    if (deal.isCurated) return 'Pet Companion pick';
    if (deal.isSharedBy(userId)) return 'Shared by you';
    final name = deal.sharedByName?.trim() ?? '';
    return name.isEmpty ? 'Shared by a member' : 'Shared by $name';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.color});

  final String label;

  /// Fill colour; a white outlined pill when `null`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        borderRadius: BorderRadius.circular(999),
        border: color == null ? Border.all(color: Theme.of(context).colorScheme.outlineVariant) : null,
      ),
      child: Text(label, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _EndedNotice extends StatelessWidget {
  const _EndedNotice({required this.endedOn});

  final DateTime endedOn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This deal ended on ${StoreFormat.date(endedOn)}',
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.brown),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label.copyWith(color: AppColors.brown)),
                Text(value, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
