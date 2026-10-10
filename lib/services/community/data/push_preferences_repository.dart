import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import '../../../platform/session.dart';
import 'supabase_community_support.dart';

/// What a member wants to hear about on their phones. The server decides
/// what to send from these (`push_preferences`, 0023_community_push.sql;
/// private chats from 0026_private_chats.sql).
@immutable
class PushPreferences {
  const PushPreferences({
    this.replies = true,
    this.comments = true,
    this.likes = false,
    this.privateMessages = true,
    this.chatInvites = true,
  });

  /// Answers to the member's chat messages.
  final bool replies;

  /// Comments on the member's posts.
  final bool comments;

  /// Likes of the member's posts (at most one notification per post an
  /// hour). Off unless switched on.
  final bool likes;

  /// Messages in the member's private chats (not the ones they muted);
  /// several from one chat count up in one notification.
  final bool privateMessages;

  /// Invitations to a private chat.
  final bool chatInvites;

  PushPreferences copyWith({
    bool? replies,
    bool? comments,
    bool? likes,
    bool? privateMessages,
    bool? chatInvites,
  }) => PushPreferences(
    replies: replies ?? this.replies,
    comments: comments ?? this.comments,
    likes: likes ?? this.likes,
    privateMessages: privateMessages ?? this.privateMessages,
    chatInvites: chatInvites ?? this.chatInvites,
  );

  @override
  bool operator ==(Object other) =>
      other is PushPreferences &&
      other.replies == replies &&
      other.comments == comments &&
      other.likes == likes &&
      other.privateMessages == privateMessages &&
      other.chatInvites == chatInvites;

  @override
  int get hashCode =>
      Object.hash(replies, comments, likes, privateMessages, chatInvites);
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
        // All columns: the private chat ones arrive with 0026.
        final row = await _client
            .from('push_preferences')
            .select()
            .eq('user_id', viewer.id)
            .maybeSingle();
        if (row == null) return const PushPreferences();
        return PushPreferences(
          replies: row['replies'] as bool? ?? true,
          comments: row['comments'] as bool? ?? true,
          likes: row['likes'] as bool? ?? false,
          privateMessages: row['private_messages'] as bool? ?? true,
          chatInvites: row['chat_invites'] as bool? ?? true,
        );
      });

  @override
  Future<void> save({
    required AppUser viewer,
    required PushPreferences preferences,
  }) => guardCommunity(() async {
    final row = {
      'user_id': viewer.id,
      'replies': preferences.replies,
      'comments': preferences.comments,
      'likes': preferences.likes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final table = _client.from('push_preferences');
    try {
      await table.upsert({
        ...row,
        'private_messages': preferences.privateMessages,
        'chat_invites': preferences.chatInvites,
      }, onConflict: 'user_id');
    } on sb.PostgrestException catch (e) {
      // Before 0026_private_chats.sql the private chat columns are not
      // there: the other choices are still saved.
      if (e.code != 'PGRST204') rethrow;
      await table.upsert(row, onConflict: 'user_id');
    }
  });
}
