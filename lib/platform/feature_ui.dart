import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../access/access_provider.dart';
import '../models/pet.dart';
import '../state/pets_provider.dart';
import 'feature_module.dart';

class FeatureRequest {
  const FeatureRequest(this.petId, [this.values = const {}]);
  final String petId;
  final Map<String, Object?> values;
  T? value<T>(String key) => values[key] as T?;
}

class FeatureAction {
  const FeatureAction({required this.capability, required this.open});
  final String capability;
  final Future<Object?> Function(BuildContext context, FeatureRequest request)
  open;
  factory FeatureAction.task({
    required String capability,
    required Future<void> Function(BuildContext, FeatureRequest) open,
  }) => FeatureAction(
    capability: capability,
    open: (context, request) async {
      await open(context, request);
      return null;
    },
  );
}

class FeatureSlot {
  const FeatureSlot({required this.capability, required this.build});
  final String capability;
  final Widget Function(BuildContext context, FeatureRequest request) build;
}

/// The tabs with a "+" button, the keys of [FeatureModule.add]. Home has
/// none.
abstract final class AddTab {
  static const health = 'health';
  static const community = 'community';
  static const outside = 'outside';
  static const store = 'store';
}

/// One row of a tab's Add sheet: a disc in its [area]'s colour, a label
/// and maybe one quieter line. Tapping it closes the sheet and calls
/// [open] with the tab's pet. Rows the account lacks [capability] for are
/// not shown; rows sort by [order].
class AddEntry {
  const AddEntry({
    required this.id,
    required this.capability,
    required this.area,
    required this.icon,
    required this.label,
    required this.open,
    this.subtitle,
    this.order = 0,
  });

  /// Names the row (its key is `add-<id>`).
  final String id;
  final String capability;
  final AppArea area;
  final IconData icon;
  final String Function(BuildContext context) label;
  final String Function(BuildContext context)? subtitle;
  final int order;
  final Future<void> Function(BuildContext context, FeatureRequest request)
  open;
}

/// The rows of [tab]'s Add sheet the account may use, in order. Watches
/// the modules and the capabilities, so a widget rebuilds when they
/// change.
List<AddEntry> addEntriesFor(WidgetRef ref, String tab) => [
  for (final module in ref.watch(featureModulesProvider))
    for (final entry in module.add[tab] ?? const <AddEntry>[])
      if (ref.watch(capabilityProvider(entry.capability))) entry,
]..sort((a, b) => a.order.compareTo(b.order));

/// [addEntriesFor] read once, outside a build (opening the sheet).
List<AddEntry> readAddEntries(BuildContext context, String tab) {
  final container = ProviderScope.containerOf(context, listen: false);
  return [
    for (final module in container.read(featureModulesProvider))
      for (final entry in module.add[tab] ?? const <AddEntry>[])
        if (container.read(capabilityProvider(entry.capability))) entry,
  ]..sort((a, b) => a.order.compareTo(b.order));
}

/// Whether an installed module the account may use answers [name].
bool canOpenFeature(BuildContext context, String name) {
  final container = ProviderScope.containerOf(context, listen: false);
  for (final module in container.read(featureModulesProvider)) {
    final action = module.actions[name];
    if (action != null &&
        container.read(capabilityProvider(action.capability))) {
      return true;
    }
  }
  return false;
}

Future<T?> openFeature<T>(
  BuildContext context,
  String name,
  String petId, [
  Map<String, Object?> values = const {},
]) async {
  final container = ProviderScope.containerOf(context, listen: false);
  for (final module in container.read(featureModulesProvider)) {
    final action = module.actions[name];
    if (action == null ||
        !container.read(capabilityProvider(action.capability))) {
      continue;
    }
    return await action.open(context, FeatureRequest(petId, values)) as T?;
  }
  return null;
}

Widget featureSlot(
  String name,
  String petId, [
  Map<String, Object?> values = const {},
]) => _FeatureSlot(name, FeatureRequest(petId, values));

class _FeatureSlot extends ConsumerWidget {
  const _FeatureSlot(this.name, this.request);
  final String name;
  final FeatureRequest request;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final module in ref.watch(featureModulesProvider)) {
      final slot = module.slots[name];
      if (slot != null && ref.watch(capabilityProvider(slot.capability))) {
        return slot.build(context, request);
      }
    }
    return const SizedBox.shrink();
  }
}

/// The pet [request] is for: one of the pets the tabs show, else any pet
/// the store holds (an archived one), else [Pet.none].
Pet requestPet(BuildContext context, FeatureRequest request) {
  final container = ProviderScope.containerOf(context, listen: false);
  for (final pet in container.read(petsProvider)) {
    if (pet.id == request.petId) return pet;
  }
  return container.read(petsStoreProvider).byId(request.petId) ?? Pet.none;
}
