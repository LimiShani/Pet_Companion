import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../care/care.dart' show CarePillButton;
import '../../store/store_routes.dart';
import '../basket/bought_again_dialog.dart';
import '../budget_screen.dart';
import '../budget_words.dart';
import '../state/basket_logic.dart';
import '../state/budget_providers.dart';
import 'budget_widgets.dart';

/// Home's two money cards, under the feeding, activity and health cards:
/// "This month's spending" (while the month has expenses) and "Running
/// low" (while a product runs out within a week). Each brings its own gap
/// above it, so nothing is left when neither shows.
class BudgetHomeCards extends StatelessWidget {
  const BudgetHomeCards({super.key});

  @override
  Widget build(BuildContext context) => const BudgetKeeper(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SpendingCard(), RunningLowCard()]),
  );
}

/// The whole home's spending this month: the total, the change from last
/// month and the top categories. Tapping it opens the budget.
class SpendingCard extends ConsumerWidget {
  const SpendingCard({super.key});

  static const cardKey = Key('home-spending');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(homeSpendingProvider).value;
    if (month == null || month.isEmpty) return const SizedBox.shrink();
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final change = month.change;
    final previous = format.month(month.previousMonth);
    final top = month.byCategory.entries
        .take(2)
        .map((e) => '${l10n.category(e.key)} ${format.money(e.value, month.currency)}')
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.cardGap),
      child: _MoneyCard(
        key: cardKey,
        color: AppColors.yellow,
        icon: Icons.account_balance_wallet_rounded,
        title: l10n.spendingTitle,
        trailing: l10n.allHome,
        tapLabel: l10n.openBudget,
        onTap: () {
          ref.read(budgetFilterProvider.notifier)
            ..setAllHome(true)
            ..showMonth(month.month);
          openBudget(context);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(format.money(month.total, month.currency), style: AppText.metric),
            if (change != null)
              Text(
                change > 0
                    ? l10n.changeUp(format.integer(change), previous)
                    : change < 0
                    ? l10n.changeDown(format.integer(-change), previous)
                    : l10n.changeSame(previous),
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            if (top.isNotEmpty) Text(top, style: AppText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// What runs out within a week, each with "Bought again". Tapping the card
/// opens the Store's "My basket".
class RunningLowCard extends ConsumerWidget {
  const RunningLowCard({super.key});

  static const cardKey = Key('home-running-low');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(runningLowProvider).value;
    if (lines == null || lines.isEmpty) return const SizedBox.shrink();
    final l10n = context.budgetL10n;
    final pets = ref.watch(petsProvider);
    final shown = lines.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.cardGap),
      child: _MoneyCard(
        key: cardKey,
        color: AppColors.sage,
        icon: Icons.shopping_basket_rounded,
        title: l10n.runningLowTitle,
        tapLabel: l10n.openBasket,
        onTap: () {
          ref.read(storeViewProvider.notifier).show(StoreView.basket);
          GoRouter.maybeOf(context)?.go(StoreRoutes.root);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 13, thickness: 1, color: AppColors.white.withValues(alpha: 0.55)),
              _LowRow(line: shown[i], pets: pets),
            ],
          ],
        ),
      ),
    );
  }
}

class _LowRow extends StatelessWidget {
  const _LowRow({required this.line, required this.pets});

  final BasketLine line;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.budgetL10n;
    final item = line.item;
    final pet = pets.firstWhere((p) => p.id == item.petId, orElse: () => Pet.none);
    final days = line.daysLeft!;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.name.isEmpty ? item.name : '${isolate(item.name)} · ${isolate(pet.name)}',
          style: AppText.cardTitle.copyWith(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(days < 0 ? l10n.ranOut : l10n.runsOutIn(days), style: AppText.body),
      ],
    );
    final pill = CarePillButton(
      key: ValueKey('home-bought-${item.id}'),
      label: l10n.boughtAgain,
      filled: true,
      onPressed: () => boughtAgain(context, item),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // The pill's text, padding and border, and room for a short name
        // beside it; on a narrow card (a small phone, large text) the pill
        // goes under the line instead.
        final label = TextPainter(
          text: TextSpan(text: l10n.boughtAgain, style: AppText.button(14)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final pillWidth = 31 + label.width;
        label.dispose();
        if (pillWidth + 8 + 90 <= constraints.maxWidth) {
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 8),
              pill,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text,
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerEnd, child: pill),
          ],
        );
      },
    );
  }
}

/// The shell of Home's cards, with a Material icon on a light disc where
/// the care cards have their drawings.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.child,
    required this.onTap,
    required this.tapLabel,
    this.trailing,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? trailing;
  final Widget child;
  final VoidCallback onTap;
  final String tapLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          onTapHint: tapLabel,
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.white.withValues(alpha: 0.6)),
                  child: AppIcon(icon, size: 30, color: AppColors.ink),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title, style: AppText.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                trailing!,
                                style: AppText.label.copyWith(fontWeight: FontWeight.w600),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
