import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../models/pet.dart';
import '../../../state/pets_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../../care/widgets/care_widgets.dart';
import '../../store/store_strings.dart';
import '../budget_words.dart';
import '../data/budget_models.dart';
import '../state/basket_logic.dart';
import '../state/budget_providers.dart';
import '../widgets/budget_widgets.dart';
import 'basket_item_form_screen.dart';
import 'bought_again_dialog.dart';

/// The Store's "My basket": the products the owner buys again and again,
/// what is left of each, when it runs out, the Store's deals on it, and
/// "Bought again".
class BasketView extends ConsumerWidget {
  const BasketView({super.key});

  static const viewKey = Key('basket-view');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final value = ref.watch(basketLinesProvider);
    final pets = ref.watch(petsProvider);
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;

    final Widget child;
    if (value.hasValue && !value.hasError) {
      final lines = value.requireValue;
      if (lines.isEmpty) {
        child = ListView(
          padding: EdgeInsets.only(bottom: bottom),
          children: [
            EmptyState(
              icon: Icons.shopping_basket_rounded,
              title: l10n.basketEmptyTitle,
              message: l10n.basketEmptyMessage,
              actionLabel: l10n.regularProduct,
              onAction: () => openBasketItemForm(context),
            ),
          ],
        );
      } else {
        child = ListView(
          padding: EdgeInsetsDirectional.fromSTEB(AppSpacing.screen, 14, AppSpacing.screen, bottom),
          children: [
            for (final line in lines) BasketLineTile(line: line, pets: pets),
            CareAddLine(label: l10n.regularProduct, onTap: () => openBasketItemForm(context)),
          ],
        );
      }
    } else if (value.hasError) {
      child = ListView(
        padding: EdgeInsets.only(bottom: bottom),
        children: [
          EmptyState(
            icon: Icons.cloud_off_rounded,
            title: l10n.loadFailed,
            message: budgetErrorText(context, value.error!),
            actionLabel: context.l10n.commonTryAgain,
            onAction: () => ref.invalidate(basketProvider),
          ),
        ],
      );
    } else {
      child = const Center(child: CircularProgressIndicator());
    }
    return BudgetKeeper(
      child: KeyedSubtree(key: viewKey, child: child),
    );
  }
}

/// One product: its name and pet, a bar of what is left, "bought 08.09 ·
/// ₪240 · runs out 07.10", a link to the Store's deals on it, and
/// "Bought again".
class BasketLineTile extends ConsumerWidget {
  const BasketLineTile({super.key, required this.line, required this.pets});

  final BasketLine line;
  final List<Pet> pets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.budgetL10n;
    final format = AppFormat.of(context);
    final item = line.item;
    final pet = pets.firstWhere((p) => p.id == item.petId, orElse: () => Pet.none);
    final bought = item.lastBoughtOn;
    final runsOut = line.runsOutOn;
    final left = line.left;
    final price = item.lastPrice;
    final details = [
      bought == null ? l10n.notBoughtYet : l10n.boughtOn(format.dayMonth(bought)),
      if (price != null) format.money(price, item.currency),
      if (runsOut != null)
        line.daysLeft! < 0 ? l10n.ranOutOn(format.dayMonth(runsOut)) : l10n.runsOutOn(format.dayMonth(runsOut)),
    ];
    final rate = line.rate;
    final category = dealCategoryOf(item.kind);
    final deals = category == null ? 0 : ref.watch(basketDealCountProvider((category, pet.species)));

    return CareBox(
      key: ValueKey('basket-${item.id}'),
      onTap: () => openBasketItemForm(context, item: item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: isolate(item.name)),
                if (pet.name.isNotEmpty) TextSpan(text: ' · ${isolate(pet.name)}', style: AppText.secondary),
              ],
            ),
            style: AppText.cardTitle.copyWith(fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (left != null) ...[
            const SizedBox(height: 8),
            CareProgress(value: left, color: line.isLow ? AppColors.coral : AppColors.sage),
          ],
          const SizedBox(height: 6),
          Text(details.join(' · '), style: AppText.secondary),
          if (rate != null) Text(l10n.byFeeding(format.integer(rate.gramsPerDay.round())), style: AppText.secondary),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (category != null && deals > 0)
                  TextButton(
                    key: ValueKey('basket-deals-${item.id}'),
                    onPressed: () => showDealsFor(ref, petId: item.petId, category: category),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.coralDark,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: AppText.body.copyWith(fontWeight: FontWeight.w800),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(_dealsText(context, item.kind, deals, pet.species))),
                        const AppIcon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                CarePillButton(
                  key: ValueKey('basket-bought-${item.id}'),
                  label: l10n.boughtAgain,
                  onPressed: () => boughtAgain(context, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _dealsText(BuildContext context, BasketKind kind, int count, PetSpecies species) {
    final l10n = context.budgetL10n;
    final animals = context.storeL10n.animalsInSentence(species);
    return kind == BasketKind.food ? l10n.dealsOnFood(count, animals) : l10n.dealsOnLitter(count, animals);
  }
}
