import 'package:flutter/material.dart';

import '../../platform/feature_module.dart';
import '../../platform/feature_ui.dart';
import '../../services/safety/state/safety_providers.dart';
import 'food_check_screen.dart';
import 'lost_mode_screens.dart';
import 'urgent_signs_screen.dart';

/// The safety tools of the Emergency sheet (`docs/safety.md`,
/// `docs/lost_mode.md`): "Is it urgent?", "Can they eat this?" and Lost
/// mode. Their content and data live in `lib/services/safety/`; the sheet
/// (Health) shows a tool's row once this module answers its action for the
/// account:
///
/// * `safety-urgent`, `safety-food`: the two lists (`safety.lists`);
/// * `lost-mode`: starting an alert (`safety.lost`);
/// * `lost-alert`: the open alert, values {'alert': LostAlert}
///   (`safety.view`).
final safetyModule = FeatureModule(
  id: 'safety',
  actions: {
    'safety-urgent': FeatureAction.task(
      capability: SafetyCapabilities.lists,
      open: (c, r) => _push(c, UrgentSignsScreen(pet: requestPet(c, r))),
    ),
    'safety-food': FeatureAction.task(
      capability: SafetyCapabilities.lists,
      open: (c, r) => _push(c, FoodCheckScreen(pet: requestPet(c, r))),
    ),
    'lost-mode': FeatureAction.task(
      capability: SafetyCapabilities.lost,
      open: (c, r) => _push(c, LostStartScreen(pet: requestPet(c, r))),
    ),
    'lost-alert': FeatureAction.task(
      capability: SafetyCapabilities.view,
      open: (c, r) {
        final alert = r.value<LostAlert>('alert');
        if (alert == null) return Future.value();
        return _push(
          c,
          LostAlertScreen(pet: requestPet(c, r), alertId: alert.id),
        );
      },
    ),
  },
);

/// Over the whole app, above the bottom bar.
Future<void> _push(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true)
        .push<void>(MaterialPageRoute(builder: (_) => page));
