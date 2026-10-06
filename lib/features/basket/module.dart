import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import 'basket_screen.dart';
import 'basket_view.dart';
import 'running_low_card.dart';
import '../../presentation/budget_widgets.dart';

final basketModule = FeatureModule(
  id: 'basket',
  home: [
    FeatureContribution(
      id: 'running-low',
      capability: 'basket.view',
      order: 35,
      builder: (_, _) => const BudgetKeeper(child: RunningLowCard()),
    ),
  ],
  actions: {
    'basket': FeatureAction.task(
      capability: 'basket.view',
      open: (c, r) => openBasket(c),
    ),
  },
  slots: {
    'basket-view': FeatureSlot(
      capability: 'basket.view',
      build: (c, r) => const BasketView(),
    ),
  },
);
