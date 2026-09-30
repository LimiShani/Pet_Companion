import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health_models.dart';
import 'health_providers.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// What the owner last wrote for a pet's lost card (`null`: never written).
class LostCardController extends AsyncNotifier<LostPetCard?> {
  LostCardController(this.petId);

  final String petId;

  @override
  Future<LostPetCard?> build() => ref.watch(healthRepositoryProvider).fetchLostCard(petId);

  /// Stores the card. Throws a [HealthException] when it cannot be stored.
  Future<LostPetCard> save(LostPetCard card) async {
    final saved = await ref.read(healthRepositoryProvider).saveLostCard(card);
    if (ref.mounted) state = AsyncData(saved);
    return saved;
  }
}

final lostCardProvider = AsyncNotifierProvider.autoDispose.family<LostCardController, LostPetCard?, String>(
  LostCardController.new,
  retry: _noRetry,
);
