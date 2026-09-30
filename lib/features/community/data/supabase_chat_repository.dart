import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import 'chat_repository.dart';
import 'community_models.dart';
import 'supabase_community_support.dart';

/// [ChatRepository] backed by Supabase: rooms in `chat_channels`, messages
/// in `chat_messages`, live through Supabase Realtime (the table is in the
/// `supabase_realtime` publication, see `0003_community.sql`).
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client) : _names = ProfileNames(_client);

  final sb.SupabaseClient _client;
  final ProfileNames _names;

  /// How many of the latest messages a conversation shows.
  static const historySize = 200;

  @override
  Future<List<ChatChannel>> fetchChannels() => guardCommunity(() async {
        final rows = await _client
            .from('chat_channels')
            .select('id, name, description')
            .order('sort_order', ascending: true)
            .order('name', ascending: true);
        return [
          for (final row in rows)
            ChatChannel(
              id: row['id'] as String,
              name: row['name'] as String,
              description: row['description'] as String? ?? '',
            ),
        ];
      });

  @override
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    // `.stream` loads the latest rows, then keeps the list current from
    // Realtime inserts, updates and deletes. Newest first from the server
    // so the limit keeps the latest; the screen wants oldest first.
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('created_at', ascending: false)
        .limit(historySize)
        .asyncMap(_toMessages)
        .transform(
          StreamTransformer<List<ChatMessage>, List<ChatMessage>>.fromHandlers(
            handleError: (error, stackTrace, sink) => sink.addError(communityExceptionFrom(error), stackTrace),
          ),
        );
  }

  @override
  Future<void> sendMessage({required AppUser author, required String channelId, required String text}) =>
      guardCommunity(() async {
        final body = text.trim();
        if (body.isEmpty) throw const CommunityException('Write something before sending.');
        _names.remember(author.id, author.displayName);
        await _client.from('chat_messages').insert({'channel_id': channelId, 'author_id': author.id, 'body': body});
      });

  /// Realtime rows carry only ids, so author names come from profiles.
  Future<List<ChatMessage>> _toMessages(List<Map<String, dynamic>> rows) async {
    final names = await _names.resolve([for (final row in rows) row['author_id'] as String]);
    return [
      for (final row in rows.reversed)
        ChatMessage(
          id: row['id'] as String,
          channelId: row['channel_id'] as String,
          authorId: row['author_id'] as String,
          authorName: names[row['author_id']] ?? fallbackAuthorName,
          text: row['body'] as String,
          sentAt: parseTimestamp(row['created_at']),
        ),
    ];
  }
}
