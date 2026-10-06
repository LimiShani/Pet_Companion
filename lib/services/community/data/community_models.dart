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

  String get authorInitial => initialOf(authorName);

  Post copyWith({int? likeCount, bool? likedByMe, int? commentCount}) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      petName: petName,
      text: text,
      photo: photo,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
      commentCount: commentCount ?? this.commentCount,
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

/// One message in a [ChatChannel].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String channelId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime sentAt;
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
