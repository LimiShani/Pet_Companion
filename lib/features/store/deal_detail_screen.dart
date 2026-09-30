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
import 'store_strings.dart';
import 'widgets/deal_badge.dart';
import 'widgets/deal_card.dart';
import 'widgets/deal_image.dart';
import 'widgets/save_deal_button.dart';
import 'widgets/store_messages.dart';

/// Everything about one deal, with the button that opens the seller's page.
class DealDetailScreen extends ConsumerStatefulWidget {
  const DealDetailScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends ConsumerState<DealDetailScreen> {
  // While the user's own deal is being deleted the page keeps showing it,
  // so it does not flash "This deal is gone" on its way out.
  Deal? _lastShown;
  bool _deleting = false;

  Future<void> _delete(Deal deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(StoreStrings.deleteDealTitle),
        content: const Text(StoreStrings.deleteDealMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(StoreStrings.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(StoreStrings.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(dealsProvider.notifier).delete(deal.id);
      if (mounted) navigator.pop();
      showStoreMessageOn(messenger, StoreStrings.dealDeleted);
    } catch (error) {
      if (mounted) setState(() => _deleting = false);
      showStoreMessageOn(messenger, storeErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final deals = ref.watch(dealsProvider);
    final current = ref.watch(dealByIdProvider(widget.dealId));
    if (current != null) _lastShown = current;
    final deal = current ?? (_deleting ? _lastShown : null);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(
            title: StoreStrings.dealTitle,
            showBack: true,
            actions: [if (deal != null) SaveDealButton(dealId: deal.id, inHeader: true)],
          ),
          Expanded(
            child: deal != null
                ? _DealBody(deal: deal, busy: _deleting, onDelete: () => _delete(deal))
                : deals.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : EmptyState(
                        icon: Icons.search_off_rounded,
                        title: StoreStrings.dealGoneTitle,
                        message: StoreStrings.dealGoneMessage,
                        actionLabel: StoreStrings.backToStore,
                        onAction: () => Navigator.of(context).maybePop(),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DealBody extends ConsumerWidget {
  const _DealBody({required this.deal, required this.busy, required this.onDelete});

  final Deal deal;

  /// The deal is being deleted: its actions are switched off.
  final bool busy;

  /// Asks to delete the deal. Only offered on the user's own deals.
  final VoidCallback onDelete;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(reportedDealIdsProvider.notifier).report(deal.id);
      showStoreMessageOn(messenger, StoreStrings.reportThanks);
    } catch (error) {
      showStoreMessageOn(messenger, storeErrorMessage(error));
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final uri = safeDealLink(deal.link);
    final opened = uri != null && await ref.read(linkOpenerProvider).open(uri);
    if (!opened && context.mounted) showStoreMessage(context, StoreStrings.couldNotOpenOffer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(storeClockProvider)();
    final userId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final expired = deal.isExpired(now);
    final host = safeDealLink(deal.link)?.host;
    final mine = deal.isSharedBy(userId);
    final reported = ref.watch(reportedDealIdsProvider.select((ids) => ids.value?.contains(deal.id) ?? false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 16, AppSpacing.screen, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  child: Stack(
                    children: [
                      AspectRatio(aspectRatio: 16 / 9, child: DealImage(deal: deal, discSize: 92, faded: expired)),
                      PositionedDirectional(
                        start: 14,
                        top: 14,
                        child: DealBadge(deal: deal, expired: expired, large: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(label: deal.category.label, color: AppColors.yellow),
                    AnimalsTag(
                      key: const Key('deal-animals'),
                      label: StoreStrings.forAnimals(deal.speciesInOrder),
                      color: AppColors.sage,
                      large: true,
                    ),
                    _Pill(label: _origin(deal, userId)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(deal.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                if (expired) ...[
                  const SizedBox(height: 14),
                  _Notice(text: StoreStrings.dealEndedOn(StoreFormat.date(deal.expiresAt!))),
                ] else if (deal.isPriceStale(now)) ...[
                  const SizedBox(height: 14),
                  const _Notice(key: Key('deal-price-stale'), text: StoreStrings.priceMayHaveChanged),
                ],
                const SizedBox(height: 14),
                _PriceCard(deal: deal),
                const SizedBox(height: AppSpacing.cardGap),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.surfaceRadius),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.storefront_rounded,
                        label: StoreStrings.sellerLabel,
                        value: deal.sellerName,
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.verified_outlined,
                        label: StoreStrings.priceCheckedLabel,
                        value: StoreFormat.checked(deal.priceChecked, now),
                      ),
                      const Divider(),
                      _InfoRow(
                        icon: Icons.schedule_rounded,
                        label: StoreStrings.postedLabel,
                        value: StoreFormat.timeAgo(deal.postedAt, now),
                      ),
                      if (!expired) ...[
                        const Divider(),
                        _InfoRow(
                          icon: Icons.event_rounded,
                          label: StoreStrings.endsLabel,
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
                // A deal that is already marked as over needs no report.
                if (!expired) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: reported
                        ? const _ReportedNote()
                        : TextButton.icon(
                            onPressed: busy ? null : () => _report(context, ref),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text(StoreStrings.reportExpired),
                            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                          ),
                  ),
                ],
                if (mine) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text(StoreStrings.deleteMyDeal),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 8, AppSpacing.screen, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _open(context, ref),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                iconAlignment: IconAlignment.end,
                label: const Text(StoreStrings.openOffer),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: AppText.button(16),
                ),
              ),
              if (host != null) ...[
                const SizedBox(height: 6),
                Text(
                  StoreStrings.opensInBrowser(host),
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
    if (deal.isCurated) return StoreStrings.pickOfTheApp;
    if (deal.isSharedBy(userId)) return StoreStrings.sharedByYou;
    final name = deal.sharedByName?.trim() ?? '';
    return name.isEmpty ? StoreStrings.sharedByMember : StoreStrings.sharedBy(name);
  }
}

/// The sage card with everything about the price: now and before, the
/// saving and, when the deal carries them, the unit price, the package, the
/// delivery cost and the final price.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final size = deal.package;
    final unitPrice = deal.unitPrice;
    final delivery = deal.deliveryCost;
    final finalPrice = deal.finalPrice;
    // A deal with neither a package size nor a delivery cost looks as it
    // did before these existed.
    final hasBreakdown = size != null || delivery != null;
    final line = Divider(height: 1, thickness: 1, color: AppColors.ink.withValues(alpha: 0.22));

    String money(double amount) => StoreFormat.money(amount, deal.currency);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DealPrices(deal: deal, large: true),
          if (deal.amountSaved > 0) ...[
            const SizedBox(height: 4),
            Text(
              StoreStrings.youSave(money(deal.amountSaved), deal.discountPercent),
              style: AppText.body.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          if (hasBreakdown) ...[
            const SizedBox(height: 12),
            line,
            const SizedBox(height: 4),
            if (unitPrice != null)
              _PriceLine(
                label: StoreStrings.unitPriceLabel,
                value: StoreFormat.unitPrice(unitPrice, deal.currency),
              ),
            if (size != null) _PriceLine(label: StoreStrings.packageLabel, value: StoreFormat.package(size)),
            _PriceLine(
              label: StoreStrings.deliveryLabel,
              value: delivery == null
                  ? StoreStrings.deliveryNotGiven
                  : delivery == 0
                      ? StoreStrings.deliveryFree
                      : StoreStrings.deliveryPlus(money(delivery)),
              note: delivery == null ? StoreStrings.deliveryAskSeller : null,
            ),
            if (finalPrice != null) ...[
              const SizedBox(height: 4),
              line,
              const SizedBox(height: 4),
              _PriceLine(label: StoreStrings.finalPriceLabel, value: money(finalPrice), strong: true),
            ],
          ],
        ],
      ),
    );
  }
}

/// A label at the start and its value at the end. Wraps when they do not
/// fit on one line.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value, this.note, this.strong = false});

  final String label;
  final String value;

  /// A small remark under the value.
  final String? note;

  /// The line that matters most: the final price.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(label, style: AppText.body.copyWith(fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
              Text(
                value,
                style: strong ? AppText.pillValue : AppText.body.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (note != null)
            Text(
              note!,
              style: AppText.label.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
        ],
      ),
    );
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

class _ReportedNote extends StatelessWidget {
  const _ReportedNote();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.brown),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              StoreStrings.reportedExpired,
              style: AppText.body.copyWith(color: AppColors.brown, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// A butter-coloured line with a clock: the deal has ended, or its price
/// was checked a while ago.
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text});

  final String text;

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
          Expanded(child: Text(text, style: AppText.body.copyWith(fontWeight: FontWeight.w700))),
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
