import '../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/coral_header.dart';
import '../../widgets/empty_state.dart';
import '../../presentation/care_widgets.dart';
import '../../presentation/budget_words.dart';
import '../../services/budget/data/budget_models.dart';
import 'expense_form_screen.dart';
import '../../services/budget/state/budget_logic.dart';
import '../../services/budget/state/budget_providers.dart';
import '../../presentation/budget_widgets.dart';

/// Opens the budget page over the whole app.
Future<void> openBudget(BuildContext context) => Navigator.of(
  context,
  rootNavigator: true,
).push<void>(MaterialPageRoute(builder: (_) => const BudgetScreen()));

/// What the pets cost: one month at a time, for one pet or the whole home,
/// with the month before, the monthly average, the categories and every
/// expense.
///
/// Nothing here compares the owner with anybody else: published "average
/// costs" are personal cases, not a yardstick.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  static const screenKey = Key('budget-screen');
  static const totalKey = Key('budget-total');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'budget.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final filter = ref.watch(budgetFilterProvider);
    final scope = ref.watch(budgetScopeProvider);
    final current = ref.watch(currentMonthProvider);
    final value = ref.watch(budgetPageProvider);
    final filters = ref.read(budgetFilterProvider.notifier);

    final Widget body;
    if (value.hasValue && !value.hasError) {
      body = _MonthBody(month: value.requireValue, petId: scope.petId);
    } else if (value.hasError) {
      body = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: l10n.loadFailed,
        message: budgetErrorText(context, value.error!),
        actionLabel: context.l10n.commonTryAgain,
        onAction: () => ref.invalidate(expensesProvider),
      );
    } else {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return BudgetKeeper(
      page: true,
      child: Scaffold(
        key: screenKey,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoralHeader(
              title: l10n.budgetTitle,
              showBack: true,
              bottom: BudgetPetScope(
                allHome: filter.allHome,
                onChanged: filters.setAllHome,
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsetsDirectional.fromSTEB(
                  AppSpacing.screen,
                  8,
                  AppSpacing.screen,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  MonthSwitcher(
                    month: scope.month,
                    onPrevious: () =>
                        filters.showMonth(addMonths(scope.month, -1)),
                    onNext: scope.month.isBefore(current)
                        ? () => filters.showMonth(addMonths(scope.month, 1))
                        : null,
                  ),
                  const SizedBox(height: 4),
                  body,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthBody extends ConsumerWidget {
  const _MonthBody({required this.month, required this.petId});

  final BudgetMonth month;
  final String? petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'budget.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final pets = ref.watch(petsProvider);
    String money(double amount) => format.money(amount, month.currency);
    final previousName = format.month(month.previousMonth);
    final change = month.change;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CareBox(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.spentLabel,
                style: AppText.label.copyWith(color: AppColors.brown),
              ),
              Text(
                money(month.total),
                key: BudgetScreen.totalKey,
                style: AppText.metric,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.previousMonthLine(
                  previousName,
                  money(month.previousTotal),
                ),
                style: AppText.body,
              ),
              if (change != null)
                Text(
                  change > 0
                      ? l10n.changeUp(format.integer(change), previousName)
                      : change < 0
                      ? l10n.changeDown(format.integer(-change), previousName)
                      : l10n.changeSame(previousName),
                  style: AppText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 10),
              Text(
                l10n.averageLine(money(month.average.roundToDouble())),
                style: AppText.body,
              ),
              Text(l10n.averageNote, style: AppText.secondary),
            ],
          ),
        ),
        if (month.healthMissing)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text(l10n.healthMissing, style: AppText.secondary),
          ),
        if (month.byCategory.isNotEmpty) ...[
          CareSectionLabel(l10n.byCategory),
          CareBox(child: _CategoryBars(month: month)),
        ],
        CareSectionLabel(l10n.expensesTitle),
        CareAddLine(
          label: l10n.addExpense,
          onTap: () => openExpenseForm(context, petId: petId),
        ),
        if (month.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: Text(l10n.noExpenses, style: AppText.secondary),
          ),
        for (final entry in month.entries)
          BudgetEntryTile(entry: entry, pets: pets),
      ],
    );
  }
}

/// One bar per category, longest first.
class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.month});

  final BudgetMonth month;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'budget.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final top = month.byCategory.values.fold<double>(
      0,
      (a, b) => a > b ? a : b,
    );
    return Column(
      children: [
        for (final MapEntry(key: category, value: amount)
            in month.byCategory.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                AppIcon(
                  categoryIcon(category),
                  size: 20,
                  color: AppColors.brown,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.category(category),
                              style: AppText.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            format.money(amount, month.currency),
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      CareProgress(
                        value: top <= 0 ? 0 : amount / top,
                        color: categoryColor(category),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One line of the month: what it was, when, for whom and where it came
/// from, and the amount. Expenses open their form; a cost from Health is
/// read only (it is changed on its health record).
class BudgetEntryTile extends StatelessWidget {
  const BudgetEntryTile({super.key, required this.entry, required this.pets});

  final BudgetEntry entry;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'budget.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final expense = entry.expense;
    final title = entry.title.trim().isEmpty
        ? l10n.category(entry.category)
        : entry.title;
    final petName = entry.petId == null
        ? l10n.wholeHome
        : pets.where((p) => p.id == entry.petId).map((p) => p.name).firstOrNull;

    return CareBox(
      onTap: expense == null
          ? null
          : () => openExpenseForm(context, expense: expense),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: categoryColor(entry.category).withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              categoryIcon(entry.category),
              size: 20,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.cardTitle.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: directionOfText(
                    title,
                    fallback: Directionality.of(context),
                  ),
                ),
                Text(
                  [format.date(entry.date), ?petName].join(' · '),
                  style: AppText.secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    BudgetTag(l10n.source(entry.source)),
                    if (expense != null && expense.isRecurring)
                      BudgetTag(
                        expense.frequency == ExpenseFrequency.monthly
                            ? l10n.tagEveryMonth
                            : l10n.tagEveryYear,
                        color: AppColors.yellow.withValues(alpha: 0.55),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            format.money(entry.amount, entry.currency),
            style: AppText.cardTitle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
