import '../../../platform/session.dart';
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../auth/app_user.dart';
import 'audience.dart';
import 'chat_repository.dart';
import 'community_models.dart';
import 'supabase_community_support.dart';

/// [ChatRepository] backed by Supabase: rooms in `chat_channels`, messages
/// in `chat_messages` and reactions in `chat_message_reactions`, both live
/// through Supabase Realtime; read markers through `mark_chat_read` and the
/// room list from `chat_room_summaries` (`0003_community.sql`,
/// `0021_community_chat_safety.sql`).
///
/// Row level security leaves out messages of blocked members, messages the
/// viewer reported and messages hidden by reports.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(sb.SupabaseClient client)
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

  /// Messages a reply points at that were not in the same batch.
  final _replyRows = <String, Map<String, dynamic>?>{};

  /// How many of the latest messages a conversation shows.
  static const historySize = 200;

  @override
  Future<List<ChatChannel>> fetchChannels() => guardCommunity(() async {
    // All columns rather than a list: `audience` arrives with
    // 0007_community_phase1.sql, and rooms must still load before it
    // is run (every room then counts as shared).
    final rows = await _client
        .from('chat_channels')
        .select()
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return [
      for (final row in rows)
        ChatChannel(
          id: row['id'] as String,
          name: row['name'] as String,
          description: row['description'] as String? ?? '',
          audience: Audience.fromKey(row['audience'] as String?),
        ),
    ];
  });

  @override
  Future<Map<String, ChatRoomSummary>> fetchRoomSummaries({
    required AppUser viewer,
  }) => guardCommunity(() async {
    final rows = await _client.from('chat_room_summaries').select();
    return {
      for (final row in rows)
        if (row['last_message_id'] != null)
          row['channel_id'] as String: ChatRoomSummary(
            channelId: row['channel_id'] as String,
            lastAuthorId: row['last_author_id'] as String?,
            lastAuthorName: storedAuthorName(
              row['last_author_name'] as String?,
            ),
            lastText: row['last_body'] as String? ?? '',
            lastHasPhoto: row['last_has_photo'] as bool? ?? false,
            lastMessageAt: parseTimestamp(row['last_message_at']),
            unread: (row['unread_count'] as num?)?.toInt() ?? 0,
          ),
    };
  });

  @override
  Future<void> markRead({required AppUser viewer, required String channelId}) =>
      guardCommunity(() async {
        await _client.rpc('mark_chat_read', params: {'p_channel': channelId});
      });

  @override
  Stream<List<ChatMessage>> watchMessages(
    String channelId, {
    String? viewerId,
  }) {
    final viewer = viewerId ?? _backend.auth.currentUser?.id;
    StreamSubscription<List<Map<String, dynamic>>>? messages;
    StreamSubscription<List<Map<String, dynamic>>>? reactions;
    List<Map<String, dynamic>>? messageRows;
    List<Map<String, dynamic>>? reactionRows;
    var generation = 0;
    late final StreamController<List<ChatMessage>> out;

    Future<void> emit() async {
      final rows = messageRows;
      final reacted = reactionRows;
      if (rows == null || reacted == null) return;
      final mine = ++generation;
      try {
        // Newest first from the server, so the limit keeps the latest; the
        // screen wants oldest first.
        final list = await _toMessages(rows.reversed.toList(), reacted, viewer);
        if (mine == generation && !out.isClosed) out.add(list);
      } catch (e, stackTrace) {
        if (!out.isClosed) out.addError(communityExceptionFrom(e), stackTrace);
      }
    }

    out = StreamController<List<ChatMessage>>(
      onListen: () {
        // `.stream` loads the latest rows, then keeps the list current from
        // Realtime inserts, updates and deletes.
        messages = _client
            .from('chat_messages')
            .stream(primaryKey: ['id'])
            .eq('channel_id', channelId)
            .order('created_at', ascending: false)
            .limit(historySize)
            .listen(
              (rows) {
                messageRows = rows;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!out.isClosed) {
                  out.addError(communityExceptionFrom(error), stackTrace);
                }
              },
            );
        reactions = _client
            .from('chat_message_reactions')
            .stream(primaryKey: ['message_id', 'user_id', 'emoji'])
            .eq('channel_id', channelId)
            .limit(2000)
            .listen(
              (rows) {
                reactionRows = rows;
                emit();
              },
              // Reactions are a nicety: a room still works without them
              // (before 0021 is run, or when Realtime drops them).
              onError: (Object error, StackTrace stackTrace) {
                reactionRows ??= const [];
                emit();
              },
            );
      },
      onCancel: () async {
        await messages?.cancel();
        await reactions?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  @override
  Future<List<ChatMessage>> fetchOlder(
    String channelId, {
    required DateTime before,
    String? viewerId,
    int limit = 50,
  }) => guardCommunity(() async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('channel_id', channelId)
        .lt('created_at', before.toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(limit);
    if (rows.isEmpty) return const <ChatMessage>[];
    List<Map<String, dynamic>> reacted;
    try {
      reacted = await _client.from('chat_message_reactions').select().inFilter(
        'message_id',
        [for (final row in rows) row['id']],
      );
    } catch (_) {
      reacted = const [];
    }
    return _toMessages(
      rows.reversed.toList(),
      reacted,
      viewerId ?? _backend.auth.currentUser?.id,
    );
  });

  @override
  Future<ChatMessage> sendMessage({
    required AppUser author,
    required String channelId,
    required String text,
    PickedPhoto? photo,
    String? replyToId,
  }) => guardCommunity(() async {
    final body = text.trim();
    if (body.isEmpty && photo == null) {
      throw const CommunityException(CommunityFailure.emptyMessage);
    }
    _names.remember(author.id, author.displayName);
    final photoPath = photo == null
        ? null
        : await _photos.upload(author.id, photo);
    final Map<String, dynamic> row;
    try {
      row = await _client
          .from('chat_messages')
          .insert({
            'channel_id': channelId,
            'author_id': author.id,
            'body': body,
            // Only sent when used, so text messages still work before
            // 0021_community_chat_safety.sql has run.
            'reply_to': ?replyToId,
            'photo_path': ?photoPath,
          })
          .select('id, created_at')
          .single();
    } catch (_) {
      if (photoPath != null) await _photos.remove(photoPath);
      rethrow;
    }
    if (photoPath != null) await _photos.attached(photoPath);
    return ChatMessage(
      id: row['id'] as String,
      channelId: channelId,
      authorId: author.id,
      authorName: storedAuthorName(author.displayName),
      text: body,
      sentAt: parseTimestamp(row['created_at']),
      photo: photo == null ? null : MemoryPostPhoto(photo.bytes),
      replyToId: replyToId,
    );
  });

  @override
  Future<void> deleteMessage({
    required AppUser viewer,
    required String messageId,
  }) => guardCommunity(() async {
    final deleted = await _client
        .from('chat_messages')
        .delete()
        .eq('id', messageId)
        .eq('author_id', viewer.id)
        .select('photo_path');
    if (deleted.isEmpty) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    // The database queued the photo for clean-up; remove it now.
    if (deleted.first['photo_path'] case final String path) {
      await _photos.remove(path);
    }
  });

  @override
  Future<void> setReaction({
    required AppUser viewer,
    required String messageId,
    required String emoji,
    required bool on,
  }) => guardCommunity(() async {
    final table = _client.from('chat_message_reactions');
    if (on) {
      // The room is filled in by the database from the message.
      await table.upsert(
        {'message_id': messageId, 'user_id': viewer.id, 'emoji': emoji},
        onConflict: 'message_id,user_id,emoji',
        ignoreDuplicates: true,
      );
    } else {
      await table
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', viewer.id)
          .eq('emoji', emoji);
    }
  });

  @override
  Future<void> reportMessage({
    required AppUser viewer,
    required String messageId,
    required ReportReason reason,
  }) => guardCommunity(() async {
    await _client
        .from('chat_message_reports')
        .upsert(
          {
            'message_id': messageId,
            'reporter_id': viewer.id,
            'reason': reason.name,
          },
          onConflict: 'message_id,reporter_id',
          ignoreDuplicates: true,
        );
  });

  /// Rows, oldest first, as messages: author names from profiles (Realtime
  /// rows carry only ids), photo links, the messages replies point at, and
  /// reactions grouped by emoji.
  Future<List<ChatMessage>> _toMessages(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> reactionRows,
    String? viewerId,
  ) async {
    final byId = {for (final row in rows) row['id'] as String: row};

    final missingReplies = {
      for (final row in rows)
        if (row['reply_to'] case final String id
            when !byId.containsKey(id) && !_replyRows.containsKey(id))
          id,
    }.toList();
    if (missingReplies.isNotEmpty) {
      try {
        final found = await _client
            .from('chat_messages')
            .select('id, author_id, body, photo_path')
            .inFilter('id', missingReplies);
        for (final id in missingReplies) {
          _replyRows[id] = null;
        }
        for (final row in found) {
          _replyRows[row['id'] as String] = row;
        }
      } catch (_) {
        // The reply shows without its quote.
      }
    }
    Map<String, dynamic>? repliedRow(String? id) =>
        id == null ? null : byId[id] ?? _replyRows[id];

    final names = await _names.resolve([
      for (final row in rows) row['author_id'] as String,
      for (final row in rows)
        if (repliedRow(row['reply_to'] as String?) case final replied?)
          replied['author_id'] as String,
    ]);
    final links = await _photos.links([
      for (final row in rows)
        if (row['photo_path'] case final String path) path,
    ]);

    final reactions = <String, Map<String, Set<String>>>{};
    for (final row in reactionRows) {
      reactions
          .putIfAbsent(row['message_id'] as String, () => {})
          .putIfAbsent(row['emoji'] as String, () => {})
          .add(row['user_id'] as String);
    }

    return [
      for (final row in rows)
        () {
          final id = row['id'] as String;
          final path = row['photo_path'] as String?;
          final url = path == null ? null : links[path];
          final replyId = row['reply_to'] as String?;
          final replied = repliedRow(replyId);
          final mine = reactions[id] ?? const <String, Set<String>>{};
          return ChatMessage(
            id: id,
            channelId: row['channel_id'] as String,
            authorId: row['author_id'] as String,
            authorName: names[row['author_id']] ?? '',
            text: row['body'] as String? ?? '',
            sentAt: parseTimestamp(row['created_at']),
            photo: path == null || url == null
                ? null
                : RemotePostPhoto(url: url, cacheKey: path),
            replyToId: replyId,
            replyTo: replied == null
                ? null
                : ChatReplyPreview(
                    messageId: replied['id'] as String,
                    authorId: replied['author_id'] as String,
                    authorName: names[replied['author_id']] ?? '',
                    text: replied['body'] as String? ?? '',
                    hasPhoto: replied['photo_path'] != null,
                  ),
            reactions: [
              for (final emoji in chatReactions)
                if (mine[emoji] case final who? when who.isNotEmpty)
                  ChatReaction(
                    emoji: emoji,
                    count: who.length,
                    mine: who.contains(viewerId),
                  ),
            ],
          );
        }(),
    ];
  }
}
