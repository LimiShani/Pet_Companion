import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../budget_screen.dart';
import '../../../presentation/budget_words.dart';
import '../../../services/budget/state/budget_providers.dart';

import '../../../presentation/money_card.dart';

class SpendingCard extends ConsumerWidget {
  const SpendingCard({super.key});

  static const cardKey = Key('home-spending');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'budget.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _authorized(context, ref)),
  );
  Widget _authorized(BuildContext context, WidgetRef ref) {
    final month = ref.watch(homeSpendingProvider).value;
    if (month == null || month.isEmpty) return const SizedBox.shrink();
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final change = month.change;
    final previous = format.month(month.previousMonth);
    final top = month.byCategory.entries
        .take(2)
        .map(
          (e) =>
              '${l10n.category(e.key)} ${format.money(e.value, month.currency)}',
        )
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.cardGap),
      child: MoneyCard(
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
            Text(
              format.money(month.total, month.currency),
              style: AppText.metric,
            ),
            if (change != null)
              Text(
                change > 0
                    ? l10n.changeUp(format.integer(change), previous)
                    : change < 0
                    ? l10n.changeDown(format.integer(-change), previous)
                    : l10n.changeSame(previous),
                style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              ),
            if (top.isNotEmpty)
              Text(
                top,
                style: AppText.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
