import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../l10n/l10n.dart';
import '../../widgets/petloop_icon.dart';
import '../../services/store/data/deal.dart';
import '../../services/store/state/store_providers.dart';
import 'store_routes.dart';

final storeModule = FeatureModule(
  id: 'store',
  tab: FeatureTab(
    capability: 'store.deals.view',
    glyph: PetLoopGlyph.shop,
    label: (c) => c.l10n.navStore,
    routes: storeRoutes,
  ),
  actions: {
    'store-category': FeatureAction.task(
      capability: 'store.deals.view',
      open: (c, r) async {
        ProviderScope.containerOf(
            c,
            listen: false,
          ).read(storeFilterProvider.notifier)
          ..clear()
          ..setAllAnimals(false)
          ..setCategory(r.value<DealCategory>('category'));
        Navigator.of(c).maybePop();
        GoRouter.maybeOf(c)?.go(StoreRoutes.root);
      },
    ),
  },
);
