import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import 'basket_screen.dart';
import 'basket_item_form_screen.dart';
import 'basket_view.dart';

final basketModule = FeatureModule(
  id: 'basket',
  actions: {
    'basket': FeatureAction.task(
      capability: 'basket.view',
      open: (c, r) => openBasket(c),
    ),
  },
  // The Store tab's "+": a product bought again and again.
  add: {
    AddTab.store: [
      AddEntry(
        id: 'regular-product',
        capability: 'basket.edit',
        area: AppArea.store,
        icon: Icons.shopping_basket_rounded,
        label: (c) => c.budgetL10n.regularProduct,
        order: 10,
        open: (c, r) => openBasketItemForm(c),
      ),
    ],
  },
  slots: {
    'basket-view': FeatureSlot(
      capability: 'basket.view',
      build: (c, r) => const BasketView(inStoreTab: true),
    ),
  },
);
