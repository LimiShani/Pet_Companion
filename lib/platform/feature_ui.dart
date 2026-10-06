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

Pet requestPet(BuildContext context, FeatureRequest request) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(petsStoreProvider).byId(request.petId) ??
    Pet.none;
