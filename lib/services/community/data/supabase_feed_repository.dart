import '../../../platform/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import 'community_models.dart';
import 'feed_repository.dart';
import 'supabase_community_support.dart';

/// [FeedRepository] backed by Supabase (tables and policies in
/// `supabase/migrations/0003_community.sql`).
///
/// Row level security holds every write to `auth.uid()`, so the user
/// passed to a call must be the signed-in one.
class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(sb.SupabaseClient client)
    : _backend = client,
      _names = ProfileNames(client) {
    _photos = CommunityPhotos(() => _client);
  }

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  final ProfileNames _names;
  late final CommunityPhotos _photos;

  static const photoBucket = CommunityPhotos.bucket;

  /// How many posts the feed loads.
  static const pageSize = 50;

  @override
  Future<List<Post>> fetchPosts({required AppUser viewer}) =>
      guardCommunity(() async {
        // The view adds the author's name, the counts and "liked by me";
        // posts the viewer reported are filtered out by the select policy.
        final rows = await _client
            .from('community_feed')
            .select()
            .order('created_at', ascending: false)
            .limit(pageSize);
        final urls = await _photos.links([
          for (final row in rows)
            if (row['photo_path'] case final String path) path,
        ]);
        return [for (final row in rows) _toPost(row, urls)];
      });

  @override
  Future<Post> createPost({
    required AppUser author,
    required String text,
    String? petName,
    PickedPhoto? photo,
  }) => guardCommunity(() async {
    final body = text.trim();
    if (body.isEmpty) {
      throw const CommunityException(CommunityFailure.emptyPost);
    }
    final pet = petName?.trim() ?? '';

    final photoPath = photo == null
        ? null
        : await _photos.upload(author.id, photo);

    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('community_posts')
          .insert({
            'author_id': author.id,
            'body': body,
            'pet_name': pet.isEmpty ? null : pet,
            'photo_path': photoPath,
          })
          .select('id, created_at')
          .single();
    } catch (_) {
      // Do not leave an orphan picture behind.
      if (photoPath != null) await _photos.remove(photoPath);
      rethrow;
    }

    if (photoPath != null) await _photos.attached(photoPath);
    return Post(
      id: row['id'] as String,
      authorId: author.id,
      authorName: storedAuthorName(author.displayName),
      petName: pet.isEmpty ? null : pet,
      text: body,
      // Shown from memory until the next fetch brings a signed link.
      photo: photo == null ? null : MemoryPostPhoto(photo.bytes),
      createdAt: parseTimestamp(row['created_at']),
    );
  });

  @override
  Future<void> deletePost({required AppUser viewer, required String postId}) =>
      guardCommunity(() async {
        final deleted = await _client
            .from('community_posts')
            .delete()
            .eq('id', postId)
            .eq('author_id', viewer.id)
            .select('photo_path');
        if (deleted.isEmpty) {
          throw const CommunityException(CommunityFailure.notYourPost);
        }
        if (deleted.first['photo_path'] case final String path) {
          await _photos.remove(path);
        }
      });

  @override
  Future<void> setLiked({
    required AppUser viewer,
    required String postId,
    required bool liked,
  }) => guardCommunity(() async {
    final likes = _client.from('community_post_likes');
    if (liked) {
      // The primary key allows one like per member per post; liking
      // twice is simply ignored.
      await likes.upsert(
        {'post_id': postId, 'user_id': viewer.id},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    } else {
      await likes.delete().eq('post_id', postId).eq('user_id', viewer.id);
    }
  });

  @override
  Future<void> reportPost({
    required AppUser viewer,
    required String postId,
    required ReportReason reason,
  }) => guardCommunity(() async {
    await _client
        .from('community_reports')
        .upsert(
          {'post_id': postId, 'reporter_id': viewer.id, 'reason': reason.name},
          onConflict: 'post_id,reporter_id',
          ignoreDuplicates: true,
        );
  });

  @override
  Future<List<Comment>> fetchComments({required String postId}) =>
      guardCommunity(() async {
        final rows = await _client
            .from('community_comments')
            .select('id, post_id, author_id, body, created_at')
            .eq('post_id', postId)
            .order('created_at', ascending: true)
            .limit(500);
        final names = await _names.resolve([
          for (final row in rows) row['author_id'] as String,
        ]);
        return [
          for (final row in rows)
            Comment(
              id: row['id'] as String,
              postId: row['post_id'] as String,
              authorId: row['author_id'] as String,
              authorName: names[row['author_id']] ?? '',
              text: row['body'] as String,
              createdAt: parseTimestamp(row['created_at']),
            ),
        ];
      });

  @override
  Future<Comment> addComment({
    required AppUser author,
    required String postId,
    required String text,
  }) => guardCommunity(() async {
    final body = text.trim();
    if (body.isEmpty) {
      throw const CommunityException(CommunityFailure.emptyMessage);
    }
    final row = await _client
        .from('community_comments')
        .insert({'post_id': postId, 'author_id': author.id, 'body': body})
        .select('id, created_at')
        .single();
    _names.remember(author.id, author.displayName);
    return Comment(
      id: row['id'] as String,
      postId: postId,
      authorId: author.id,
      authorName: storedAuthorName(author.displayName),
      text: body,
      createdAt: parseTimestamp(row['created_at']),
    );
  });

  Post _toPost(Map<String, dynamic> row, Map<String, String> photoUrls) {
    final path = row['photo_path'] as String?;
    final url = path == null ? null : photoUrls[path];
    return Post(
      id: row['id'] as String,
      authorId: row['author_id'] as String,
      authorName: storedAuthorName(row['author_name'] as String?),
      petName: row['pet_name'] as String?,
      text: row['body'] as String,
      photo: path == null || url == null
          ? null
          : RemotePostPhoto(url: url, cacheKey: path),
      createdAt: parseTimestamp(row['created_at']),
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      likedByMe: row['liked_by_me'] as bool? ?? false,
      commentCount: (row['comment_count'] as num?)?.toInt() ?? 0,
    );
  }
}
