import '../../../auth/app_user.dart';
import 'community_models.dart';

/// The community feed: posts, likes, comments and reports.
///
/// Screens talk only to this interface. Every call names the signed-in
/// user it is made for, so the in-memory fake needs no global session; the
/// Supabase implementation is additionally held to `auth.uid()` by row
/// level security. Failures surface as a [CommunityException] that names
/// the reason.
abstract class FeedRepository {
  /// Posts for [viewer], newest first, without the ones they reported.
  Future<List<Post>> fetchPosts({required AppUser viewer});

  /// Publishes a post and returns it as the author sees it.
  Future<Post> createPost({
    required AppUser author,
    required String text,
    String? petName,
    PickedPhoto? photo,
  });

  /// Deletes a post. Only its author may.
  Future<void> deletePost({required AppUser viewer, required String postId});

  /// Adds or removes [viewer]'s like. At most one like per user per post.
  Future<void> setLiked({
    required AppUser viewer,
    required String postId,
    required bool liked,
  });

  /// Records a report for moderation and hides the post from [viewer].
  Future<void> reportPost({
    required AppUser viewer,
    required String postId,
    required ReportReason reason,
  });

  /// Comments under a post, oldest first.
  Future<List<Comment>> fetchComments({required String postId});

  Future<Comment> addComment({
    required AppUser author,
    required String postId,
    required String text,
  });
}
