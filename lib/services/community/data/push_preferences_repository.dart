import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import '../../../platform/session.dart';
import 'supabase_community_support.dart';

/// What a member wants to hear about on their phones. The server decides
/// what to send from these (`push_preferences`, 0023_community_push.sql).
@immutable
class PushPreferences {
  const PushPreferences({
    this.replies = true,
    this.comments = true,
    this.likes = false,
  });

  /// Answers to the member's chat messages.
  final bool replies;

  /// Comments on the member's posts.
  final bool comments;

  /// Likes of the member's posts (at most one notification per post an
  /// hour). Off unless switched on.
  final bool likes;

  PushPreferences copyWith({bool? replies, bool? comments, bool? likes}) =>
      PushPreferences(
        replies: replies ?? this.replies,
        comments: comments ?? this.comments,
        likes: likes ?? this.likes,
      );

  @override
  bool operator ==(Object other) =>
      other is PushPreferences &&
      other.replies == replies &&
      other.comments == comments &&
      other.likes == likes;

  @override
  int get hashCode => Object.hash(replies, comments, likes);
}

/// Failures surface as `CommunityException`.
abstract class PushPreferencesRepository {
  /// The member's choices; the defaults when they never changed them.
  Future<PushPreferences> fetch({required AppUser viewer});

  Future<void> save({
    required AppUser viewer,
    required PushPreferences preferences,
  });
}

class FakePushPreferencesRepository implements PushPreferencesRepository {
  FakePushPreferencesRepository({this.latency = Duration.zero});

  final Duration latency;
  final saved = <String, PushPreferences>{};

  @override
  Future<PushPreferences> fetch({required AppUser viewer}) async {
    await Future<void>.delayed(latency);
    return saved[viewer.id] ?? const PushPreferences();
  }

  @override
  Future<void> save({
    required AppUser viewer,
    required PushPreferences preferences,
  }) async {
    await Future<void>.delayed(latency);
    saved[viewer.id] = preferences;
  }
}

class SupabasePushPreferencesRepository implements PushPreferencesRepository {
  SupabasePushPreferencesRepository(this._backend);

  final sb.SupabaseClient _backend;
  sb.SupabaseClient get _client {
    checkSession();
    return _backend;
  }

  @override
  Future<PushPreferences> fetch({required AppUser viewer}) =>
      guardCommunity(() async {
        final row = await _client
            .from('push_preferences')
            .select('replies, comments, likes')
            .eq('user_id', viewer.id)
            .maybeSingle();
        if (row == null) return const PushPreferences();
        return PushPreferences(
          replies: row['replies'] as bool? ?? true,
          comments: row['comments'] as bool? ?? true,
          likes: row['likes'] as bool? ?? false,
        );
      });

  @override
  Future<void> save({
    required AppUser viewer,
    required PushPreferences preferences,
  }) => guardCommunity(() async {
    await _client.from('push_preferences').upsert({
      'user_id': viewer.id,
      'replies': preferences.replies,
      'comments': preferences.comments,
      'likes': preferences.likes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  });
}
