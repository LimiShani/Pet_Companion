import '../../../access/access_provider.dart';
import '../../../platform/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../state/ordered_writes.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/community/data/audience.dart';
import '../../../services/community/data/feed_repository.dart';
import '../safety/safety_providers.dart';

/// No automatic retries: a failed load shows an error block with a "Try
/// again" button instead of retrying behind the user's back.
Duration? noRetry(int retryCount, Object error) => null;

/// What the member narrowed the feed to: a kind of post, words in it.
class FeedFilter {
  const FeedFilter({this.kind, this.search = ''});

  final PostKind? kind;
  final String search;
}

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => const FeedFilter();

  void kind(PostKind? kind) =>
      state = FeedFilter(kind: kind, search: state.search);

  void search(String words) =>
      state = FeedFilter(kind: state.kind, search: words.trim());
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(
  FeedFilterNotifier.new,
);

/// The feed's query: the filter, and the animal chosen in the Dogs / Cats /
/// Everything chips (shared with Chat and Guides). Posts for everyone show
/// under every animal.
final feedQueryProvider = Provider<FeedQuery>((ref) {
  final filter = ref.watch(feedFilterProvider);
  final scope = ref.watch(communityScopeProvider);
  return FeedQuery(
    kind: filter.kind,
    search: filter.search,
    audiences: switch (scope) {
      CommunityScope.dogs => const {Audience.everyone, Audience.dogs},
      CommunityScope.cats => const {Audience.everyone, Audience.cats},
      CommunityScope.everything => null,
    },
  );
});

/// The posts of the feed for the signed-in user, newest first, one page at
/// a time ([loadMore]).
///
/// Actions update the list in place and throw a [CommunityException] when
/// the backend refuses, so the screen can show a snack bar.
class FeedController extends SessionSafeAsyncNotifier<List<Post>> {
  FeedRepository get _repo => ref.read(feedRepositoryProvider);

  AppUser get _viewer {
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      throw const CommunityException(CommunityFailure.signInAgain);
    }
    return user;
  }

  List<Post> get _posts => state.value ?? const [];

  /// Every post of the query is loaded: no more pages.
  bool get exhausted => _exhausted;
  var _exhausted = false;
  var _loadingMore = false;
  FeedQuery _query = const FeedQuery();

  @override
  Future<List<Post>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('community.feed.view'))) {
      _exhausted = true;
      return const <Post>[];
    }

    final repo = ref.watch(feedRepositoryProvider);
    // Reload for a different account, but not on every token refresh.
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    _query = ref.watch(feedQueryProvider);
    if (viewerId == null) {
      _exhausted = true;
      return const [];
    }
    final page = await repo.fetchPosts(viewer: _viewer, query: _query);
    _exhausted = page.length < feedPageSize;
    return page;
  }

  /// Pull to refresh: keeps the current list on screen while loading.
  Future<void> refresh() async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.view');
      final page = await _repo.fetchPosts(viewer: _viewer, query: _query);
      _exhausted = page.length < feedPageSize;
      state = AsyncData(page);
    });
  }

  /// Loads the next page, below the posts already shown.
  Future<void> loadMore() async {
    if (_exhausted || _loadingMore || !state.hasValue || _posts.isEmpty) {
      return;
    }
    _loadingMore = true;
    try {
      await sessionOperation(ref, () async {
        final query = _query;
        final page = await _repo.fetchPosts(
          viewer: _viewer,
          query: query,
          before: _posts.last.createdAt,
        );
        if (!identical(query, _query) && query != _query) return;
        _exhausted = page.length < feedPageSize;
        final known = {for (final p in _posts) p.id};
        state = AsyncData([
          ..._posts,
          for (final p in page)
            if (!known.contains(p.id)) p,
        ]);
      });
    } finally {
      _loadingMore = false;
    }
  }

  /// Quick taps on one heart reach the backend in the order they were made.
  final _likeWrites = OrderedWrites();

  /// Per post with a like on its way: whether the backend has it liked,
  /// and its like count then, as far as the app knows.
  final _storedLike = <String, ({bool liked, int count})>{};

  /// The number of the newest tap per post, so only its outcome counts.
  final _latestTap = <String, int>{};

  /// Likes or unlikes a post. The heart reacts at once; if the backend
  /// refuses the newest tap, the heart and the count show what the backend
  /// has and this throws. A failed tap already overruled by a newer one
  /// changes nothing and does not throw.
  ///
  /// [known] is the post as shown, for one the feed has not loaded (on a
  /// member's page): it is kept beside the feed from then on.
  Future<void> setLiked(
    String postId, {
    required bool liked,
    Post? known,
  }) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.post');
      if (_lookup(postId) == null && known != null) keep(known);
      final before = _lookup(postId);
      if (before == null || before.likedByMe == liked) return;
      final original = before;
      if (!_likeWrites.busy(postId)) {
        _storedLike[postId] = (
          liked: original.likedByMe,
          count: original.likeCount,
        );
      }
      final tap = (_latestTap[postId] ?? 0) + 1;
      _latestTap[postId] = tap;
      final viewer = _viewer;

      // Optimistic: the heart reacts at once.
      _replace(
        original.copyWith(
          likedByMe: liked,
          likeCount: original.likeCount + (liked ? 1 : -1),
        ),
      );
      try {
        await _likeWrites.run(
          postId,
          () => _repo.setLiked(viewer: viewer, postId: postId, liked: liked),
        );
        final stored = _storedLike[postId];
        if (stored != null && stored.liked != liked) {
          _storedLike[postId] = (
            liked: liked,
            count: stored.count + (liked ? 1 : -1),
          );
        }
      } catch (_) {
        if (_latestTap[postId] != tap) return;
        final stored = _storedLike[postId];
        final current = _lookup(postId);
        if (stored != null && current != null && ref.mounted) {
          _replace(
            current.copyWith(likedByMe: stored.liked, likeCount: stored.count),
          );
        }
        rethrow;
      }
    });
  }

  Future<void> create({
    required String text,
    String? petName,
    PickedPhoto? photo,
    PostKind kind = PostKind.moment,
    Audience audience = Audience.everyone,
  }) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.post');
      final post = await _repo.createPost(
        author: _viewer,
        text: text,
        petName: petName,
        photo: photo,
        kind: kind,
        audience: audience,
      );
      state = AsyncData([post, ..._posts]);
    });
  }

  /// Changes the text and kind of one of the viewer's posts.
  Future<void> edit(Post post, {required String text, required PostKind kind}) {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.edit');
      _replace(
        await _repo.updatePost(
          viewer: _viewer,
          post: post,
          text: text,
          kind: kind,
        ),
      );
    });
  }

  /// Marks the helpful answer to the viewer's question, or clears it.
  Future<void> setHelpful(String postId, String? commentId) {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.edit');
      await _repo.setHelpful(
        viewer: _viewer,
        postId: postId,
        commentId: commentId,
      );
      final post = _lookup(postId);
      if (post != null) {
        _replace(post.copyWith(helpfulCommentId: () => commentId));
      }
    });
  }

  /// A post opened from outside the feed (a profile, the activity page):
  /// kept beside the feed so liking it and its comments work the same.
  Future<Post?> open(String postId) {
    return sessionOperation(ref, () async {
      final known = _lookup(postId);
      if (known != null) return known;
      final post = await _repo.fetchPost(viewer: _viewer, postId: postId);
      if (post != null) ref.read(outsidePostsProvider.notifier).put(post);
      return post;
    });
  }

  /// Keeps [post] beside the feed when the feed does not hold it.
  void keep(Post post) {
    if (_lookup(post.id) == null) {
      ref.read(outsidePostsProvider.notifier).put(post);
    }
  }

  Post? _lookup(String postId) {
    for (final p in _posts) {
      if (p.id == postId) return p;
    }
    return ref.read(outsidePostsProvider)[postId];
  }

  Future<void> delete(String postId) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.edit');
      await _repo.deletePost(viewer: _viewer, postId: postId);
      _remove(postId);
    });
  }

  Future<void> report(String postId, ReportReason reason) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.post');
      await _repo.reportPost(viewer: _viewer, postId: postId, reason: reason);
      _remove(postId);
    });
  }

  /// Keeps the comment count of a post in step after a comment was added.
  void commentAdded(String postId) {
    final post = _lookup(postId);
    if (post != null) {
      _replace(post.copyWith(commentCount: post.commentCount + 1));
    }
  }

  void _replace(Post post) {
    final outside = ref.read(outsidePostsProvider.notifier);
    if (ref.read(outsidePostsProvider).containsKey(post.id)) outside.put(post);
    if (!state.hasValue) return;
    state = AsyncData([
      for (final p in _posts)
        if (p.id == post.id) post else p,
    ]);
  }

  void _remove(String postId) {
    ref.read(outsidePostsProvider.notifier).remove(postId);
    if (!state.hasValue) return;
    state = AsyncData(_posts.where((p) => p.id != postId).toList());
  }
}

/// Posts opened from outside the feed, by id (see [FeedController.open]).
class OutsidePosts extends Notifier<Map<String, Post>> {
  @override
  Map<String, Post> build() {
    ref.watch(sessionEpochProvider);
    return const {};
  }

  void put(Post post) => state = {...state, post.id: post};

  void remove(String postId) {
    if (!state.containsKey(postId)) return;
    state = {...state}..remove(postId);
  }
}

final outsidePostsProvider = NotifierProvider<OutsidePosts, Map<String, Post>>(
  OutsidePosts.new,
);

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, List<Post>>(
      FeedController.new,
      retry: noRetry,
    );

/// One post of the loaded feed, or `null` when it is gone (deleted,
/// reported, or the feed is not loaded).
final postProvider = Provider.autoDispose.family<Post?, String>((ref, postId) {
  final posts = ref.watch(visiblePostsProvider) ?? const <Post>[];
  for (final p in posts) {
    if (p.id == postId) return p;
  }
  final outside = ref.watch(outsidePostsProvider)[postId];
  if (outside != null &&
      !ref.watch(blockedIdsProvider).contains(outside.authorId)) {
    return outside;
  }
  return null;
});

/// The loaded feed without the posts of members the viewer blocked;
/// `null` while it has not loaded.
final visiblePostsProvider = Provider.autoDispose<List<Post>?>((ref) {
  final posts = ref.watch(feedControllerProvider).value;
  if (posts == null) return null;
  final blocked = ref.watch(blockedIdsProvider);
  if (blocked.isEmpty) return posts;
  return [
    for (final p in posts)
      if (!blocked.contains(p.authorId)) p,
  ];
});

/// The comments under one post, oldest first.
class CommentsController extends SessionSafeAsyncNotifier<List<Comment>> {
  CommentsController(this.postId);

  final String postId;

  @override
  Future<List<Comment>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('community.feed.view'))) {
      return const <Comment>[];
    }
    return ref.watch(feedRepositoryProvider).fetchComments(postId: postId);
  }

  Future<void> add(String text) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.post');
      final author = ref.read(authControllerProvider).value;
      if (author == null) {
        throw const CommunityException(CommunityFailure.signInAgain);
      }
      final comment = await ref
          .read(feedRepositoryProvider)
          .addComment(author: author, postId: postId, text: text);
      state = AsyncData([...?state.value, comment]);
      ref.read(feedControllerProvider.notifier).commentAdded(postId);
    });
  }

  /// Reports a comment; it disappears for the viewer at once.
  Future<void> report(String commentId, ReportReason reason) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.feed.post');
      final viewer = ref.read(authControllerProvider).value;
      if (viewer == null) {
        throw const CommunityException(CommunityFailure.signInAgain);
      }
      await ref
          .read(communitySafetyRepositoryProvider)
          .reportComment(viewer: viewer, commentId: commentId, reason: reason);
      state = AsyncData([
        for (final c in state.value ?? const <Comment>[])
          if (c.id != commentId) c,
      ]);
    });
  }
}

final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsController, List<Comment>, String>(
      CommentsController.new,
      retry: noRetry,
    );
