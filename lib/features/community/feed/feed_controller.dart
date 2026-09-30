import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../data/community_models.dart';
import '../data/community_providers.dart';
import '../data/feed_repository.dart';

/// No automatic retries: a failed load shows an error block with a "Try
/// again" button instead of retrying behind the user's back.
Duration? noRetry(int retryCount, Object error) => null;

/// The posts of the feed for the signed-in user, newest first.
///
/// Actions update the list in place and throw a [CommunityException] when
/// the backend refuses, so the screen can show a snack bar.
class FeedController extends AsyncNotifier<List<Post>> {
  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  AppUser get _viewer {
    final user = ref.read(authControllerProvider).value;
    if (user == null) throw const CommunityException(CommunityFailure.signInAgain);
    return user;
  }

  List<Post> get _posts => state.value ?? const [];

  @override
  Future<List<Post>> build() async {
    final repo = ref.watch(feedRepositoryProvider);
    // Reload for a different account, but not on every token refresh.
    final viewerId = ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    if (viewerId == null) return const [];
    return repo.fetchPosts(viewer: _viewer);
  }

  /// Pull to refresh: keeps the current list on screen while loading.
  Future<void> refresh() async {
    state = AsyncData(await _repo.fetchPosts(viewer: _viewer));
  }

  Future<void> setLiked(String postId, {required bool liked}) async {
    Post? before;
    for (final p in _posts) {
      if (p.id == postId) before = p;
    }
    if (before == null || before.likedByMe == liked) return;
    final original = before;

    // Optimistic: the heart reacts at once and is put back if saving fails.
    _replace(original.copyWith(likedByMe: liked, likeCount: original.likeCount + (liked ? 1 : -1)));
    try {
      await _repo.setLiked(viewer: _viewer, postId: postId, liked: liked);
    } catch (_) {
      _replace(original);
      rethrow;
    }
  }

  Future<void> create({required String text, String? petName, PickedPhoto? photo}) async {
    final post = await _repo.createPost(author: _viewer, text: text, petName: petName, photo: photo);
    state = AsyncData([post, ..._posts]);
  }

  Future<void> delete(String postId) async {
    await _repo.deletePost(viewer: _viewer, postId: postId);
    _remove(postId);
  }

  Future<void> report(String postId, ReportReason reason) async {
    await _repo.reportPost(viewer: _viewer, postId: postId, reason: reason);
    _remove(postId);
  }

  /// Keeps the comment count of a post in step after a comment was added.
  void commentAdded(String postId) {
    for (final p in _posts) {
      if (p.id == postId) _replace(p.copyWith(commentCount: p.commentCount + 1));
    }
  }

  void _replace(Post post) {
    if (!state.hasValue) return;
    state = AsyncData([
      for (final p in _posts)
        if (p.id == post.id) post else p,
    ]);
  }

  void _remove(String postId) {
    if (!state.hasValue) return;
    state = AsyncData(_posts.where((p) => p.id != postId).toList());
  }
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, List<Post>>(FeedController.new, retry: noRetry);

/// One post of the loaded feed, or `null` when it is gone (deleted,
/// reported, or the feed is not loaded).
final postProvider = Provider.autoDispose.family<Post?, String>((ref, postId) {
  final posts = ref.watch(feedControllerProvider).value ?? const <Post>[];
  for (final p in posts) {
    if (p.id == postId) return p;
  }
  return null;
});

/// The comments under one post, oldest first.
class CommentsController extends AsyncNotifier<List<Comment>> {
  CommentsController(this.postId);

  final String postId;

  @override
  Future<List<Comment>> build() => ref.watch(feedRepositoryProvider).fetchComments(postId: postId);

  Future<void> add(String text) async {
    final author = ref.read(authControllerProvider).value;
    if (author == null) throw const CommunityException(CommunityFailure.signInAgain);
    final comment = await ref.read(feedRepositoryProvider).addComment(author: author, postId: postId, text: text);
    state = AsyncData([...?state.value, comment]);
    ref.read(feedControllerProvider.notifier).commentAdded(postId);
  }
}

final commentsProvider = AsyncNotifierProvider.autoDispose.family<CommentsController, List<Comment>, String>(
  CommentsController.new,
  retry: noRetry,
);
