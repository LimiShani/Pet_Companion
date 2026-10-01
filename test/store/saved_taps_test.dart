import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/store/data/fake_store_repository.dart';
import 'package:pet_companion/features/store/data/store_repository.dart';
import 'package:pet_companion/features/store/state/store_providers.dart';

const _deal = 'deal-1';

/// A backend where the first save of the heart is slow, and can fail.
class _SlowFirstTap extends FakeStoreRepository {
  _SlowFirstTap({this.firstFails = false}) : super(latency: Duration.zero);

  final bool firstFails;
  int _calls = 0;

  /// The choices in the order they reached the backend.
  final sent = <bool>[];

  @override
  Future<void> setSaved({required String userId, required String dealId, required bool saved}) async {
    final first = _calls++ == 0;
    if (first) await Future<void>.delayed(const Duration(milliseconds: 30));
    sent.add(saved);
    if (first && firstFails) throw const StoreException(StoreFailure.network);
    return super.setSaved(userId: userId, dealId: dealId, saved: saved);
  }
}

Future<(ProviderContainer, String)> _signedIn(FakeStoreRepository repository) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
      storeRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(savedDealIdsProvider, (_, _) {});
  await container
      .read(authControllerProvider.notifier)
      .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword);
  await container.read(savedDealIdsProvider.future);
  return (container, container.read(authControllerProvider).value!.id);
}

void main() {
  test('two quick taps reach the backend in order, so the last choice is what stays', () async {
    final repository = _SlowFirstTap();
    final (container, userId) = await _signedIn(repository);
    final hearts = container.read(savedDealIdsProvider.notifier);

    final first = hearts.toggle(_deal); // save
    final second = hearts.toggle(_deal); // unsave
    expect(await first, isTrue);
    expect(await second, isTrue);

    expect(repository.sent, [true, false]);
    expect(await repository.fetchSavedDealIds(userId: userId), isEmpty);
    expect(container.read(savedDealIdsProvider).value, isEmpty);
  });

  test('an older tap that fails does not undo the newer one', () async {
    final repository = _SlowFirstTap(firstFails: true);
    final (container, userId) = await _signedIn(repository);
    final hearts = container.read(savedDealIdsProvider.notifier);

    final first = hearts.toggle(_deal); // save: fails
    final second = hearts.toggle(_deal); // unsave: works
    final third = hearts.toggle(_deal); // save again: works
    await Future.wait([first, second, third]);

    expect(await repository.fetchSavedDealIds(userId: userId), {_deal});
    expect(container.read(savedDealIdsProvider).value, {_deal});
  });

  test('when the newest tap fails, the heart shows what the backend has', () async {
    final repository = FakeStoreRepository(latency: Duration.zero);
    final (container, userId) = await _signedIn(repository);
    final hearts = container.read(savedDealIdsProvider.notifier);

    expect(await hearts.toggle(_deal), isTrue);
    repository.failWrites = true;
    expect(await hearts.toggle(_deal), isFalse);

    expect(await repository.fetchSavedDealIds(userId: userId), {_deal});
    expect(container.read(savedDealIdsProvider).value, {_deal});
  });
}
