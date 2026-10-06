import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'audience.dart';

/// Why something in the community failed. Repositories and controllers
/// report the reason; the screen puts it into words in the app's language
/// (see `communityErrorText` in `community_words.dart`).
enum CommunityFailure {
  /// The feed's backend did not answer.
  unreachable,

  /// The chat's backend did not answer.
  chatUnreachable,

  /// No connection to the server.
  offline,
  postGone,
  emptyPost,

  /// An empty comment or chat message.
  emptyMessage,
  notYourPost,
  signInAgain,

  /// Refused by the database's access rules.
  notAllowed,

  /// A text the database's length checks refuse.
  textInvalid,

  /// The post or room was deleted meanwhile.
  gone,

  /// The database has no community tables yet (a migration has not run).
  notSetUp,
  photoTooLarge,
  photoUnsupported,
  photoUpload,
  cameraNotAllowed,
  photosNotAllowed,

  /// Too many posts, comments or messages in a short time.
  slowDown,

  /// Only moderators may do this.
  notModerator,

  /// Anything the app has no words of its own for.
  unknown,
}

/// Thrown by the community repositories and controllers. [failure] says
/// what went wrong; the words shown to the user come from the strings
/// files. [detail] is for logs only (the backend's own explanation).
class CommunityException implements Exception {
  const CommunityException(this.failure, [this.detail]);

  final CommunityFailure failure;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'CommunityException(${failure.name})'
      : 'CommunityException(${failure.name}: $detail)';
}

/// Limits shared by the UI, the fakes and the database checks.
abstract final class CommunityLimits {
  static const postLength = 2000;
  static const commentLength = 1000;
  static const messageLength = 1000;
  static const petNameLength = 60;
}

/// Where a post's picture comes from. The UI renders each kind differently
/// (see `PostPhotoView`).
sealed class PostPhoto {
  const PostPhoto();
}

/// A picture bundled with the app (sample content).
class AssetPostPhoto extends PostPhoto {
  const AssetPostPhoto(this.asset);

  final String asset;
}

/// A flat coloured tile with an icon: stands in for a photo in sample
/// content so the fakes never need the network.
class PlaceholderPostPhoto extends PostPhoto {
  const PlaceholderPostPhoto(this.color, {this.icon = Icons.pets_rounded});

  final Color color;
  final IconData icon;
}

/// A picture held in memory: one the user has just picked.
class MemoryPostPhoto extends PostPhoto {
  const MemoryPostPhoto(this.bytes);

  final Uint8List bytes;
}

/// A picture in remote storage. [url] may be short-lived (a signed URL), so
/// [cacheKey] (the storage path) identifies the picture for caching.
class RemotePostPhoto extends PostPhoto {
  const RemotePostPhoto({required this.url, required this.cacheKey});

  final String url;
  final String cacheKey;
}

/// A picture chosen from the gallery or the camera, ready to upload.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name, this.mimeType});

  final Uint8List bytes;

  /// Original file name; only its extension matters.
  final String name;
  final String? mimeType;
}

/// What a post is: the chips of the composer and of the feed. [key] is
/// what the database stores.
enum PostKind {
  moment('moment'),
  question('question'),
  tip('tip'),
  recommendation('recommendation'),
  lostFound('lost_found');

  const PostKind(this.key);

  final String key;

  /// Posts written before kinds existed are moments.
  static PostKind fromKey(String? key) =>
      values.firstWhere((k) => k.key == key, orElse: () => moment);
}

/// What the feed is asked for: one kind of post, the posts about some
/// animals, words in the text, one member's posts. Empty means everything.
class FeedQuery {
  const FeedQuery({this.kind, this.audiences, this.search = '', this.authorId});

  final PostKind? kind;

  /// `null` for every animal.
  final Set<Audience>? audiences;
  final String search;
  final String? authorId;

  /// Whether the member narrowed the feed themselves (a kind or words);
  /// the animal follows the selected pet and does not count.
  bool get narrowed => kind != null || search.trim().isNotEmpty;

  bool matches(Post post) {
    if (kind != null && post.kind != kind) return false;
    if (audiences != null && !audiences!.contains(post.audience)) return false;
    if (authorId != null && post.authorId != authorId) return false;
    final words = search.trim().toLowerCase();
    return words.isEmpty || post.text.toLowerCase().contains(words);
  }

  @override
  bool operator ==(Object other) =>
      other is FeedQuery &&
      other.kind == kind &&
      other.search == search &&
      other.authorId == authorId &&
      _sameSet(other.audiences, audiences);

  @override
  int get hashCode => Object.hash(
    kind,
    search,
    authorId,
    audiences == null ? null : Object.hashAllUnordered(audiences!),
  );

  static bool _sameSet(Set<Audience>? a, Set<Audience>? b) => a == null
      ? b == null
      : b != null && a.length == b.length && a.containsAll(b);
}

/// One entry of the community feed.
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.petName,
    this.photo,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    this.kind = PostKind.moment,
    this.audience = Audience.everyone,
    this.editedAt,
    this.helpfulCommentId,
  });

  final String id;
  final String authorId;
  final String authorName;

  /// The pet the post is about, when the author named one.
  final String? petName;
  final String text;
  final PostPhoto? photo;
  final DateTime createdAt;
  final int likeCount;

  /// Whether the viewer the post was fetched for has liked it.
  final bool likedByMe;
  final int commentCount;
  final PostKind kind;

  /// Which animal the post is about (from the pet it was written about).
  final Audience audience;

  /// When the author last changed the text; `null` when never.
  final DateTime? editedAt;

  /// The comment the author of a question marked as the helpful answer.
  final String? helpfulCommentId;

  String get authorInitial => initialOf(authorName);

  Post copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    String? text,
    PostKind? kind,
    DateTime? editedAt,
    String? Function()? helpfulCommentId,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      petName: petName,
      text: text ?? this.text,
      photo: photo,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
      kind: kind ?? this.kind,
      audience: audience,
      editedAt: editedAt ?? this.editedAt,
      helpfulCommentId: helpfulCommentId == null
          ? this.helpfulCommentId
          : helpfulCommentId(),
    );
  }
}

/// A reply under a [Post].
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  String get authorInitial => initialOf(authorName);
}

/// Why a post was reported. [name] is what is stored; the words are in the
/// strings files (`reportReasonText`).
enum ReportReason { spam, abusive, inappropriate, other }

/// A topic room in the Chat section.
class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.description,
    this.audience = Audience.everyone,
  });

  /// A stable slug such as `general` or `puppies`.
  final String id;

  /// The room's name and description as stored (English for the rooms the
  /// app ships with). The screen shows the rooms it knows by [id] in its
  /// own language (`roomNameText`) and any other room as stored.
  final String name;
  final String description;

  /// Which animal's owners the room is for.
  final Audience audience;
}

/// The reactions a chat message can carry, in the order the picker shows
/// them. The database accepts exactly these.
const chatReactions = ['👍', '❤️', '😂', '😮', '😢', '🐾'];

/// One emoji under a message: how many members chose it, and whether the
/// viewer is one of them.
class ChatReaction {
  const ChatReaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;
}

/// What a reply shows of the message it answers.
class ChatReplyPreview {
  const ChatReplyPreview({
    required this.messageId,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.hasPhoto = false,
  });

  final String messageId;
  final String authorId;
  final String authorName;
  final String text;
  final bool hasPhoto;
}

/// One message in a [ChatChannel].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.sentAt,
    this.photo,
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
  });

  final String id;
  final String channelId;
  final String authorId;
  final String authorName;

  /// May be empty when the message is a photo.
  final String text;
  final DateTime sentAt;
  final PostPhoto? photo;

  /// The message this one answers, by id: set even when that message is
  /// gone or hidden from the viewer ([replyTo] is then `null`).
  final String? replyToId;
  final ChatReplyPreview? replyTo;
  final List<ChatReaction> reactions;

  ChatReplyPreview asReplyPreview() => ChatReplyPreview(
    messageId: id,
    authorId: authorId,
    authorName: authorName,
    text: text,
    hasPhoto: photo != null,
  );
}

/// A room's line in the room list: its latest message and how many
/// messages from others arrived since the viewer last read it.
class ChatRoomSummary {
  const ChatRoomSummary({
    required this.channelId,
    this.lastAuthorId,
    this.lastAuthorName = '',
    this.lastText = '',
    this.lastHasPhoto = false,
    this.lastMessageAt,
    this.unread = 0,
  });

  final String channelId;
  final String? lastAuthorId;
  final String lastAuthorName;
  final String lastText;
  final bool lastHasPhoto;

  /// `null` for a room without messages.
  final DateTime? lastMessageAt;
  final int unread;
}

/// A member the viewer blocked: shown in the list where they can be
/// unblocked.
class BlockedMember {
  const BlockedMember({required this.id, required this.name});

  final String id;

  /// As stored; empty for an account without a name.
  final String name;
}

/// What a moderator reviews.
enum ModerationKind { post, comment, message }

/// Something members reported, waiting for a moderator.
class ModerationItem {
  const ModerationItem({
    required this.kind,
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.reportCount,
    required this.reasons,
    required this.hidden,
    this.photo,
    this.context,
  });

  final ModerationKind kind;
  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final PostPhoto? photo;
  final DateTime createdAt;
  final int reportCount;
  final List<ReportReason> reasons;

  /// Hidden from members until a decision (three reports or more).
  final bool hidden;

  /// The room of a message, or the post of a comment.
  final String? context;
}

/// A moderator's decision on a [ModerationItem].
enum ModerationDecision { keep, remove }

/// What other members see of a member.
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.name,
    this.bio = '',
    this.city = '',
    this.memberSince,
    this.postCount = 0,
  });

  final String id;

  /// As stored; empty for an account without a name.
  final String name;
  final String bio;
  final String city;
  final DateTime? memberSince;
  final int postCount;
}

/// What happened to the member's posts and messages.
enum ActivityKind { comment, like, reply }

class ActivityItem {
  const ActivityItem({
    required this.kind,
    required this.id,
    required this.targetId,
    required this.actorId,
    required this.actorName,
    required this.preview,
    required this.at,
  });

  final ActivityKind kind;
  final String id;

  /// The post (comment, like) or the room (reply) it happened in.
  final String targetId;
  final String actorId;
  final String actorName;

  /// The comment, the answer, or the liked post's text.
  final String preview;
  final DateTime at;
}

/// A member's display name as stored: trimmed, and empty when the account
/// has none. The screen shows a friendly fallback in its own language for
/// an empty one (`memberNameText`).
String storedAuthorName(String? displayName) => displayName?.trim() ?? '';

/// One upper-case letter for an avatar.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
