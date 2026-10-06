import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access_provider.dart';
import 'feature_ui.dart';
import '../composition/modules.g.dart';
import 'package:go_router/go_router.dart';
import '../widgets/petloop_icon.dart';

/// Feature implementations register contributions here. The app shell
/// consumes this contract and never constructs an optional feature itself.
class FeatureContribution {
  const FeatureContribution({
    required this.id,
    required this.capability,
    required this.builder,
    this.order = 0,
  });
  final String id;
  final String capability;
  final int order;
  final Widget Function(BuildContext context, String petId) builder;
}

class FeatureModule {
  const FeatureModule({
    required this.id,
    this.home = const [],
    this.menu = const [],
    this.actions = const {},
    this.slots = const {},
    this.routes = const [],
    this.tab,
  });
  final String id;
  final List<FeatureContribution> home;
  final List<FeatureContribution> menu;
  final Map<String, FeatureAction> actions;
  final Map<String, FeatureSlot> slots;
  final FeatureTab? tab;
  final List<RouteBase> routes;
}

class FeatureTab {
  const FeatureTab({
    required this.capability,
    required this.glyph,
    required this.label,
    required this.routes,
  });
  final String capability;
  final PetLoopGlyph glyph;
  final String Function(BuildContext context) label;
  final List<RouteBase> routes;
}

final featureModulesProvider = Provider<List<FeatureModule>>(
  (ref) => builtInFeatureModules,
);

class FeatureContributions extends ConsumerWidget {
  const FeatureContributions({
    super.key,
    required this.petId,
    this.menu = false,
  });
  final String petId;
  final bool menu;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accessProvider);
    final contributions = [
      for (final module in ref.watch(featureModulesProvider))
        for (final item in menu ? module.menu : module.home)
          if (ref.watch(capabilityProvider(item.capability))) item,
    ]..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in contributions)
          KeyedSubtree(
            key: ValueKey(item.id),
            child: item.builder(context, petId),
          ),
      ],
    );
  }
}
