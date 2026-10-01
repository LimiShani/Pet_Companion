import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/auth/auth_controller.dart';
import 'package:pet_companion/auth/fake_auth_repository.dart';
import 'package:pet_companion/features/community/data/community_models.dart';
import 'package:pet_companion/features/community/data/community_providers.dart';
import 'package:pet_companion/features/community/data/fake_feed_repository.dart';
import 'package:pet_companion/features/community/feed/feed_controller.dart';

/// A backend where the first like request is slow, and can fail.
class _SlowFirstTap extends FakeFeedRepository {
  _SlowFirstTap({this.firstFails = false}) : super(latency: Duration.zero);

  final bool firstFails;
  int _calls = 0;

  /// The choices in the order they reached the backend.
  final sent = <bool>[];

  @override
  Future<void> setLiked({required AppUser viewer, required String postId, required bool liked}) async {
    final first = _calls++ == 0;
    if (first) await Future<void>.delayed(const Duration(milliseconds: 30));
    sent.add(liked);
    if (first && firstFails) throw const CommunityException(CommunityFailure.unreachable);
    return super.setLiked(viewer: viewer, postId: postId, liked: liked);
  }
}

Future<(ProviderContainer, AppUser)> _signedIn(FakeFeedRepository repository) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(latency: Duration.zero)),
      feedRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(feedControllerProvider, (_, _) {});
  await container
      .read(authControllerProvider.notifier)
      .signIn(email: FakeAuthRepository.demoEmail, password: FakeAuthRepository.demoPassword);
  await container.read(feedControllerProvider.future);
  return (container, container.read(authControllerProvider).value!);
}

Post _post(ProviderContainer container, String id) =>
    container.read(feedControllerProvider).value!.firstWhere((p) => p.id == id);

void main() {
  test('a like and a quick unlike reach the backend in order, so the unlike stays', () async {
    final repository = _SlowFirstTap();
    final (container, viewer) = await _signedIn(repository);
    final post = container.read(feedControllerProvider).value!.firstWhere((p) => !p.likedByMe);
    final feed = container.read(feedControllerProvider.notifier);

    final like = feed.setLiked(post.id, liked: true);
    final unlike = feed.setLiked(post.id, liked: false);
    await Future.wait([like, unlike]);

    expect(repository.sent, [true, false]);
    final stored = (await repository.fetchPosts(viewer: viewer)).firstWhere((p) => p.id == post.id);
    expect(stored.likedByMe, isFalse);
    expect(stored.likeCount, post.likeCount);
    expect(_post(container, post.id).likedByMe, isFalse);
    expect(_post(container, post.id).likeCount, post.likeCount);
  });

  test('an older like that fails does not undo the newer taps, and raises no error', () async {
    final repository = _SlowFirstTap(firstFails: true);
    final (container, viewer) = await _signedIn(repository);
    final post = container.read(feedControllerProvider).value!.firstWhere((p) => !p.likedByMe);
    final feed = container.read(feedControllerProvider.notifier);

    final like = feed.setLiked(post.id, liked: true); // fails
    final unlike = feed.setLiked(post.id, liked: false); // works
    final likeAgain = feed.setLiked(post.id, liked: true); // works
    await Future.wait([like, unlike, likeAgain]);

    final stored = (await repository.fetchPosts(viewer: viewer)).firstWhere((p) => p.id == post.id);
    expect(stored.likedByMe, isTrue);
    expect(_post(container, post.id).likedByMe, isTrue);
    expect(_post(container, post.id).likeCount, post.likeCount + 1);
  });

  test('when the newest tap fails, the heart and the count show what the backend has', () async {
    final repository = FakeFeedRepository(latency: Duration.zero);
    final (container, _) = await _signedIn(repository);
    final post = container.read(feedControllerProvider).value!.firstWhere((p) => !p.likedByMe);
    final feed = container.read(feedControllerProvider.notifier);

    await feed.setLiked(post.id, liked: true);
    repository.failing = true;
    await expectLater(feed.setLiked(post.id, liked: false), throwsA(isA<CommunityException>()));

    expect(_post(container, post.id).likedByMe, isTrue);
    expect(_post(container, post.id).likeCount, post.likeCount + 1);
  });
}
