import '../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/pet.dart';
import '../../state/pets_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../presentation/care_widgets.dart' show CarePillButton;
import '../../platform/feature_ui.dart';
import 'bought_again_dialog.dart';
import '../../services/budget/state/basket_logic.dart';
import '../../services/budget/state/budget_providers.dart';

import '../../presentation/money_card.dart';

class RunningLowCard extends ConsumerWidget {
  const RunningLowCard({super.key});

  static const cardKey = Key('home-running-low');

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'basket.view',
    hidden: true,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _authorized(context, ref)),
  );
  Widget _authorized(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(runningLowProvider).value;
    if (lines == null || lines.isEmpty) return const SizedBox.shrink();
    final l10n = context.budgetL10n;
    final pets = ref.watch(petsProvider);
    final shown = lines.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.cardGap),
      child: MoneyCard(
        key: cardKey,
        color: AppColors.sage,
        icon: Icons.shopping_basket_rounded,
        title: l10n.runningLowTitle,
        tapLabel: l10n.openBasket,
        onTap: () {
          ref.read(storeViewProvider.notifier).show(StoreView.basket);
          openFeature<Object>(
            context,
            'basket',
            ref.read(selectedPetProvider).id,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 13,
                  thickness: 1,
                  color: AppColors.white.withValues(alpha: 0.55),
                ),
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
    final pet = pets.firstWhere(
      (p) => p.id == item.petId,
      orElse: () => Pet.none,
    );
    final days = line.daysLeft!;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.name.isEmpty
              ? item.name
              : '${isolate(item.name)} · ${isolate(pet.name)}',
          style: AppText.cardTitle.copyWith(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          days < 0 ? l10n.ranOut : l10n.runsOutIn(days),
          style: AppText.body,
        ),
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
