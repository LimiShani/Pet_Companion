import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/pet_selector.dart';
import '../state/budget_providers.dart';

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
    void keep<T>(ProviderListenable<T> provider) =>
        _subscriptions.add(container.listen<T>(provider, (_, _) {}, onError: (_, _) {}));
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

/// The pet pills of a coral header followed by an "All the home" pill. A
/// pet pill selects that pet for the whole app and narrows the budget to
/// it; "All the home" shows everything and leaves no pet highlighted.
class BudgetPetScope extends StatefulWidget {
  const BudgetPetScope({super.key, required this.allHome, required this.onChanged});

  final bool allHome;
  final ValueChanged<bool> onChanged;

  @override
  State<BudgetPetScope> createState() => _BudgetPetScopeState();
}

class _BudgetPetScopeState extends State<BudgetPetScope> {
  final _allHomeKey = GlobalKey();
  Offset? _pressedAt;

  bool _isOnAllHome(Offset position) {
    final box = _allHomeKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(position);
  }

  @override
  Widget build(BuildContext context) {
    // The selector only reports a change of pet, so a tap on the pet that
    // is already selected would go unnoticed: a tap on the row (not a
    // scroll, not on "All the home") is what leaves "All the home".
    return Listener(
      onPointerDown: (event) => _pressedAt = event.position,
      onPointerCancel: (_) => _pressedAt = null,
      onPointerUp: (event) {
        final pressedAt = _pressedAt;
        _pressedAt = null;
        if (!widget.allHome || pressedAt == null) return;
        if ((event.position - pressedAt).distance > kTouchSlop) return;
        if (_isOnAllHome(event.position)) return;
        widget.onChanged(false);
      },
      child: PetSelector(
        highlightSelected: !widget.allHome,
        trailing: _AllHomePill(key: _allHomeKey, selected: widget.allHome, onTap: () => widget.onChanged(true)),
      ),
    );
  }
}

/// Drawn to match the pet pills of [PetSelector], with a house for a
/// picture.
class _AllHomePill extends StatelessWidget {
  const _AllHomePill({super.key, required this.selected, required this.onTap});

  static const pillKey = Key('budget-all-home');

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        key: pillKey,
        color: selected ? AppColors.yellow : AppColors.onCoralPill,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.yellow : AppColors.onCoralOutline, width: 2)),
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
                  child: AppIcon(Icons.home_rounded, size: 13, color: selected ? AppColors.white : AppColors.coralDark),
                ),
                const SizedBox(width: 8),
                Text(
                  context.budgetL10n.allHome,
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

/// "‹ June 2025 ›". The arrows point the way the months go on the screen:
/// back is at the start side (the left in English, the right in Hebrew).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onPrevious, required this.onNext});

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
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: AppText.secondary.copyWith(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w700),
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
