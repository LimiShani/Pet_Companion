import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../services/budget/state/budget_providers.dart';

/// Keeps the budget's and the basket's data active while [child] is
/// mounted, for the reason given on `HealthKeeper`: Home stays below the
/// budget page, the Store's basket below the product form, the budget page
/// below the expense form, and their numbers must follow what is saved
/// there without being rebuilt in the middle of a frame.
class BudgetKeeper extends StatefulWidget {
  const BudgetKeeper({super.key, required this.child, this.page = false});

  final Widget child;

  /// Also keep what the budget page shows.
  final bool page;

  @override
  State<BudgetKeeper> createState() => _BudgetKeeperState();
}

class _BudgetKeeperState extends State<BudgetKeeper> {
  ProviderContainer? _container;
  final _subscriptions = <ProviderSubscription<Object?>>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final container = ProviderScope.containerOf(context);
    if (!identical(container, _container)) {
      _container = container;
      _listen();
    }
  }

  @override
  void didUpdateWidget(BudgetKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) _listen();
  }

  void _listen() {
    final old = [..._subscriptions];
    _subscriptions.clear();
    final container = _container!;
    void keep<T>(ProviderListenable<T> provider) => _subscriptions.add(
      container.listen<T>(provider, (_, _) {}, onError: (_, _) {}),
    );
    keep(expensesProvider);
    keep(basketProvider);
    keep(homeHealthCostsProvider);
    keep(homeSpendingProvider);
    keep(basketLinesProvider);
    keep(runningLowProvider);
    if (widget.page) keep(budgetPageProvider);
    for (final sub in old) {
      sub.close();
    }
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.close();
    }
    _subscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "‹ June 2025 ›". The arrows point the way the months go on the screen:
/// back is at the start side (the left in English, the right in Hebrew).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  static const previousKey = Key('budget-previous-month');
  static const nextKey = Key('budget-next-month');

  final DateTime month;
  final VoidCallback onPrevious;

  /// `null` on the current month: the future has no expenses yet.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.budgetL10n;
    // Material's chevrons mirror by themselves on a right-to-left screen.
    return Row(
      children: [
        IconButton(
          key: previousKey,
          tooltip: l10n.previousMonth,
          onPressed: onPrevious,
          icon: const AppIcon(Icons.chevron_left_rounded, size: 30),
          color: AppColors.coralDark,
        ),
        Expanded(
          child: Text(
            AppFormat.of(context).monthYear(month),
            textAlign: TextAlign.center,
            style: AppText.cardTitle.copyWith(fontSize: 19),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: nextKey,
          tooltip: l10n.nextMonth,
          onPressed: onNext,
          icon: const AppIcon(Icons.chevron_right_rounded, size: 30),
          color: AppColors.coralDark,
          disabledColor: AppColors.brown.withValues(alpha: 0.25),
        ),
      ],
    );
  }
}

/// A small rounded tag: "from Health", "every month".
class BudgetTag extends StatelessWidget {
  const BudgetTag(this.text, {super.key, this.color = AppColors.cream});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: AppText.secondary.copyWith(
        fontSize: 12,
        color: AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// Shows a short message at the bottom of the screen.
void showBudgetMessage(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
