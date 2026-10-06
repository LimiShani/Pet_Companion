import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_models.dart';
import 'health_providers.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// What the owner last wrote for a pet's lost card (`null`: never written).
class LostCardController extends SessionSafeAsyncNotifier<LostPetCard?> {
  LostCardController(this.petId);

  final String petId;

  @override
  Future<LostPetCard?> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('health.emergency.view'))) return null;
    return ref.watch(emergencyRepositoryProvider).fetchLostCard(petId);
  }

  /// Stores the card. Throws a [HealthException] when it cannot be stored.
  Future<LostPetCard> save(LostPetCard card) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'health.emergency.edit');
      final saved = await ref
          .read(emergencyRepositoryProvider)
          .saveLostCard(card);
      if (ref.mounted) state = AsyncData(saved);
      return saved;
    });
  }
}

final lostCardProvider = AsyncNotifierProvider.autoDispose
    .family<LostCardController, LostPetCard?, String>(
      LostCardController.new,
      retry: _noRetry,
    );
