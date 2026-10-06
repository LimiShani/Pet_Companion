import '../../../platform/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import 'audience.dart';
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

  @override
  Future<List<Post>> fetchPosts({
    required AppUser viewer,
    FeedQuery query = const FeedQuery(),
    DateTime? before,
    int limit = feedPageSize,
  }) => guardCommunity(() async {
    // The view adds the author's name, the counts and "liked by me";
    // posts the viewer reported, hidden posts and blocked members' posts
    // are filtered out by the select policies. Filters are only sent when
    // used, so the feed still loads before 0022 is run.
    var request = _client.from('community_feed').select();
    if (query.kind case final kind?) request = request.eq('kind', kind.key);
    if (query.audiences case final audiences?) {
      request = request.inFilter('audience', [
        for (final a in audiences) a.key,
      ]);
    }
    if (query.authorId case final author?) {
      request = request.eq('author_id', author);
    }
    final words = query.search.trim();
    if (words.isNotEmpty) {
      request = request.ilike('body', '%${_escapeLike(words)}%');
    }
    if (before != null) {
      request = request.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await request
        .order('created_at', ascending: false)
        .limit(limit);
    final urls = await _photos.links([
      for (final row in rows)
        if (row['photo_path'] case final String path) path,
    ]);
    return [for (final row in rows) _toPost(row, urls)];
  });

  @override
  Future<Post?> fetchPost({required AppUser viewer, required String postId}) =>
      guardCommunity(() async {
        final row = await _client
            .from('community_feed')
            .select()
            .eq('id', postId)
            .maybeSingle();
        if (row == null) return null;
        final urls = await _photos.links([
          if (row['photo_path'] case final String path) path,
        ]);
        return _toPost(row, urls);
      });

  @override
  Future<Post> updatePost({
    required AppUser viewer,
    required Post post,
    required String text,
    required PostKind kind,
  }) => guardCommunity(() async {
    final body = text.trim();
    if (body.isEmpty) {
      throw const CommunityException(CommunityFailure.emptyPost);
    }
    final rows = await _client
        .from('community_posts')
        .update({'body': body, 'kind': kind.key})
        .eq('id', post.id)
        .eq('author_id', viewer.id)
        .select('edited_at');
    if (rows.isEmpty) {
      throw const CommunityException(CommunityFailure.notYourPost);
    }
    final edited = rows.first['edited_at'];
    return post.copyWith(
      text: body,
      kind: kind,
      editedAt: edited == null ? null : parseTimestamp(edited),
    );
  });

  @override
  Future<void> setHelpful({
    required AppUser viewer,
    required String postId,
    String? commentId,
  }) => guardCommunity(() async {
    final rows = await _client
        .from('community_posts')
        .update({'helpful_comment_id': commentId})
        .eq('id', postId)
        .eq('author_id', viewer.id)
        .select('id');
    if (rows.isEmpty) {
      throw const CommunityException(CommunityFailure.notYourPost);
    }
  });

  /// [words] as a literal inside an `ilike` pattern.
  static String _escapeLike(String words) => words
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  @override
  Future<Post> createPost({
    required AppUser author,
    required String text,
    String? petName,
    PickedPhoto? photo,
    PostKind kind = PostKind.moment,
    Audience audience = Audience.everyone,
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
            // Only sent when used, so posting still works before 0022.
            if (kind != PostKind.moment) 'kind': kind.key,
            if (audience != Audience.everyone) 'audience': audience.key,
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
      kind: kind,
      audience: audience,
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
      kind: PostKind.fromKey(row['kind'] as String?),
      audience: Audience.fromKey(row['audience'] as String?),
      editedAt: row['edited_at'] == null
          ? null
          : parseTimestamp(row['edited_at']),
      helpfulCommentId: row['helpful_comment_id'] as String?,
    );
  }
}
