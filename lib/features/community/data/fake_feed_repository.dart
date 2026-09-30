import 'package:flutter/material.dart';

import '../../../auth/app_user.dart';
import 'community_models.dart';
import 'feed_repository.dart';

/// In-memory feed for development and tests. Nothing persists across
/// restarts.
///
/// Seeded with sample posts, one of them by the demo account (`demo`), so
/// "delete my post" can be tried straight away. Pass `seeded: false` for an
/// empty feed.
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    bool seeded = true,
  }) : _now = now ?? DateTime.now {
    if (seeded) _seed();
  }

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final DateTime Function() _now;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  final _posts = <_PostRecord>[];

  /// Reports received so far (what a moderator would review).
  final reports = <({String postId, String reporterId, ReportReason reason})>[];

  var _nextId = 1;

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) throw const CommunityException('Cannot reach the community right now. Please try again.');
  }

  _PostRecord _find(String postId) => _posts.firstWhere(
        (p) => p.id == postId,
        orElse: () => throw const CommunityException('This post is no longer available.'),
      );

  @override
  Future<List<Post>> fetchPosts({required AppUser viewer}) async {
    await _wait();
    final visible = _posts.where((p) => !p.reportedBy.contains(viewer.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [for (final p in visible) p.toPost(viewer.id)];
  }

  @override
  Future<Post> createPost({
    required AppUser author,
    required String text,
    String? petName,
    PickedPhoto? photo,
  }) async {
    await _wait();
    final body = text.trim();
    if (body.isEmpty) throw const CommunityException('Write something before posting.');
    final pet = petName?.trim() ?? '';
    final record = _PostRecord(
      id: 'p${_nextId++}',
      authorId: author.id,
      authorName: authorNameOrFallback(author.displayName),
      petName: pet.isEmpty ? null : pet,
      text: body,
      photo: photo == null ? null : MemoryPostPhoto(photo.bytes),
      createdAt: _now(),
    );
    _posts.add(record);
    return record.toPost(author.id);
  }

  @override
  Future<void> deletePost({required AppUser viewer, required String postId}) async {
    await _wait();
    final record = _find(postId);
    if (record.authorId != viewer.id) throw const CommunityException('You can only delete your own posts.');
    _posts.remove(record);
  }

  @override
  Future<void> setLiked({required AppUser viewer, required String postId, required bool liked}) async {
    await _wait();
    final record = _find(postId);
    if (liked) {
      record.likedBy.add(viewer.id);
    } else {
      record.likedBy.remove(viewer.id);
    }
  }

  @override
  Future<void> reportPost({required AppUser viewer, required String postId, required ReportReason reason}) async {
    await _wait();
    final record = _find(postId);
    if (record.reportedBy.add(viewer.id)) {
      reports.add((postId: postId, reporterId: viewer.id, reason: reason));
    }
  }

  @override
  Future<List<Comment>> fetchComments({required String postId}) async {
    await _wait();
    return List.unmodifiable(_find(postId).comments);
  }

  @override
  Future<Comment> addComment({required AppUser author, required String postId, required String text}) async {
    await _wait();
    final body = text.trim();
    if (body.isEmpty) throw const CommunityException('Write something before sending.');
    final record = _find(postId);
    final comment = Comment(
      id: 'c${_nextId++}',
      postId: postId,
      authorId: author.id,
      authorName: authorNameOrFallback(author.displayName),
      text: body,
      createdAt: _now(),
    );
    record.comments.add(comment);
    return comment;
  }

  // ---------------------------------------------------------------------
  // Sample content.
  // ---------------------------------------------------------------------

  void _seed() {
    final now = _now();

    _PostRecord post({
      required String authorId,
      required String authorName,
      required Duration ago,
      required String text,
      String? petName,
      PostPhoto? photo,
      int otherLikes = 0,
      List<(String authorId, String authorName, Duration ago, String text)> comments = const [],
    }) {
      final id = 'p${_nextId++}';
      return _PostRecord(
        id: id,
        authorId: authorId,
        authorName: authorName,
        petName: petName,
        text: text,
        photo: photo,
        createdAt: now.subtract(ago),
        otherLikes: otherLikes,
      )..comments.addAll([
          for (final c in comments)
            Comment(
              id: 'c${_nextId++}',
              postId: id,
              authorId: c.$1,
              authorName: c.$2,
              text: c.$4,
              createdAt: now.subtract(c.$3),
            ),
        ]);
    }

    _posts.addAll([
      post(
        authorId: 'u-maya',
        authorName: 'Maya',
        petName: 'Biscuit',
        ago: const Duration(minutes: 12),
        text: 'First full night without a toilet trip! Four months old and we both finally slept. '
            'Taking him out right before bed made all the difference.',
        otherLikes: 14,
        comments: [
          ('u-jonas', 'Jonas', Duration(minutes: 9), 'Well done Biscuit! The early weeks are the hardest part.'),
          ('u-priya', 'Priya', Duration(minutes: 4), 'Same trick worked for us. Enjoy the sleep!'),
        ],
      ),
      post(
        authorId: 'demo',
        authorName: 'Alex',
        petName: 'Kelly',
        ago: const Duration(hours: 2),
        text: 'Kelly is thirteen and still insists on carrying the biggest stick in the park. '
            'Slower walks these days, same big ambitions.',
        photo: const AssetPostPhoto('assets/images/kelly.png'),
        otherLikes: 23,
        comments: [
          ('u-sam', 'Sam', Duration(hours: 1, minutes: 40), 'What a lovely face. Thirteen and thriving!'),
        ],
      ),
      post(
        authorId: 'u-jonas',
        authorName: 'Jonas',
        petName: 'Luna',
        ago: const Duration(hours: 5),
        text: 'Rainy day plan: a towel rolled up with treats inside. Luna spent twenty happy minutes '
            'working it out and then slept the whole afternoon.',
        photo: const PlaceholderPostPhoto(Color(0xFFCDD29B), icon: Icons.umbrella_rounded),
        otherLikes: 9,
      ),
      post(
        authorId: 'u-dana',
        authorName: 'Dana',
        petName: 'Luli',
        ago: const Duration(hours: 9),
        text: 'Luli finally scratched the new post instead of the sofa. All it took was moving the post '
            'right next to the sofa.',
        photo: const PlaceholderPostPhoto(Color(0xFFFFD98B), icon: Icons.pets_rounded),
        otherLikes: 12,
        comments: [
          ('u-noa', 'Noa', Duration(hours: 8), 'Same trick worked on Shoko. Cats and their rules.'),
        ],
      ),
      post(
        authorId: 'u-priya',
        authorName: 'Priya',
        ago: const Duration(hours: 22),
        text: 'Does anyone have tips for a dog who pulls towards every other dog on the lead? '
            'We have started turning around each time, but progress is slow.',
        otherLikes: 5,
        comments: [
          ('u-maya', 'Maya', Duration(hours: 20), 'More distance helped us: reward calm looks from far away first.'),
          ('u-sam', 'Sam', Duration(hours: 19), 'The loose lead guide in the Guides section is worth a read.'),
          ('demo', 'Alex', Duration(hours: 18), 'It took Kelly a few weeks. Keep going, it does click.'),
        ],
      ),
      post(
        authorId: 'u-sam',
        authorName: 'Sam',
        petName: 'Pepper',
        ago: const Duration(days: 2, hours: 3),
        text: 'Pepper met the sea for the first time today. She barked at every single wave.',
        photo: const PlaceholderPostPhoto(Color(0xFFE8AC73), icon: Icons.waves_rounded),
        otherLikes: 31,
      ),
      post(
        authorId: 'u-noa',
        authorName: 'Noa',
        petName: 'Milo',
        ago: const Duration(days: 6),
        text: 'One year since we adopted Milo from the shelter. He was scared of the stairs for a month '
            'and now he races us to the top.',
        otherLikes: 47,
      ),
    ]);
  }
}

class _PostRecord {
  _PostRecord({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.petName,
    this.photo,
    this.otherLikes = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? petName;
  final String text;
  final PostPhoto? photo;
  final DateTime createdAt;

  /// Likes from sample users who are not real accounts.
  final int otherLikes;
  final likedBy = <String>{};
  final reportedBy = <String>{};
  final comments = <Comment>[];

  Post toPost(String viewerId) => Post(
        id: id,
        authorId: authorId,
        authorName: authorName,
        petName: petName,
        text: text,
        photo: photo,
        createdAt: createdAt,
        likeCount: otherLikes + likedBy.length,
        likedByMe: likedBy.contains(viewerId),
        commentCount: comments.length,
      );
}
