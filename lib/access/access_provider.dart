import '../composition/modules.g.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_controller.dart';
import '../config/app_config.dart';
import '../platform/session.dart';
import 'access_repository.dart';

export 'access_repository.dart';

final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => AppConfig.hasSupabase
      ? SupabaseAccessRepository(Supabase.instance.client)
      : FakeAccessRepository(),
);

class AccessController extends AsyncNotifier<AccessSnapshot> {
  int _request = 0;
  @override
  FutureOr<AccessSnapshot> build() {
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final repository = ref.watch(accessRepositoryProvider);
    if (AppConfig.hasSupabase) {
      final timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => refresh(),
      );
      ref.onDispose(timer.cancel);
    }
    return repository is FakeAccessRepository
        ? repository.snapshot(userId)
        : repository.fetch(userId);
  }

  Future<void> refresh() async {
    final request = ++_request;
    final ticket = SessionTicket(ref);
    try {
      final result = await ref
          .read(accessRepositoryProvider)
          .fetch(ref.read(authControllerProvider).value?.id);
      if (ticket.current && request == _request) state = AsyncData(result);
    } catch (error, stack) {
      // Do not retain a stale grant when its bounded refresh fails.
      if (ticket.current && request == _request) {
        state = AsyncError(error, stack);
      }
    }
  }
}

final accessProvider = AsyncNotifierProvider<AccessController, AccessSnapshot>(
  AccessController.new,
  retry: (_, _) => null,
);

/// Overridden by the generated build composition. Client permissions are
/// always intersected with the implementations installed in this build.
final installedFeaturesProvider = Provider<Set<String>>(
  (ref) =>
      const String.fromEnvironment(
            'PETLOOP_MODULES',
            defaultValue:
                'pets,care,health,community,store,budget,basket,firstdays,findvet,access',
          )
          .split(',')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .intersection(builtInFeatureIds)
        ..add('access'),
);

bool canUse(Ref ref, String capability) {
  if (capability.contains('|')) {
    return capability.split('|').any((c) => canUse(ref, c));
  }
  if (!ref.read(installedFeaturesProvider).contains(featureOf(capability))) {
    return false;
  }
  final value = ref.read(accessProvider);
  final snapshot = value.hasError || value.isLoading ? null : value.value;
  return snapshot?.userId == ref.read(authControllerProvider).value?.id &&
      snapshot?.can(capability) == true;
}

final capabilityProvider = Provider.family<bool, String>((ref, capability) {
  ref.watch(accessProvider);
  ref.watch(installedFeaturesProvider);
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return canUse(ref, capability);
});

class FeatureDenied implements Exception {
  const FeatureDenied(this.capability);
  final String capability;
  @override
  String toString() => 'This feature is not available for your account.';
}

void requireCapability(Ref ref, String capability) {
  checkSession();
  if (!canUse(ref, capability)) throw FeatureDenied(capability);
}
