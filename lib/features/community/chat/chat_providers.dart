import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../access/access_provider.dart';
import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../platform/session.dart';

import '../../../services/community/data/chat_repository.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../feed/feed_controller.dart' show noRetry;
import '../safety/safety_providers.dart';

/// How many of the latest messages a room's live list holds (both chat
/// backends keep this many); older ones are loaded on demand.
const chatLiveWindow = 200;

/// How many older messages one "load more" brings.
const chatOlderPage = 50;

/// The chat rooms, in display order.
final chatChannelsProvider = FutureProvider<List<ChatChannel>>((ref) {
  ref.watch(sessionEpochProvider);
  if (!ref.watch(capabilityProvider('community.chat.view'))) {
    return Future.value(const <ChatChannel>[]);
  }
  return ref.watch(chatRepositoryProvider).fetchChannels();
}, retry: noRetry);

/// Each room's latest message and unread count, by room id. The room list
/// is still useful without them, so a failure gives an empty map.
final chatRoomSummariesProvider = FutureProvider<Map<String, ChatRoomSummary>>((
  ref,
) async {
  ref.watch(sessionEpochProvider);
  final viewerId = ref.watch(
    authControllerProvider.select((auth) => auth.value?.id),
  );
  final viewer = ref.read(authControllerProvider).value;
  if (viewerId == null ||
      viewer == null ||
      !ref.watch(capabilityProvider('community.chat.view'))) {
    return const {};
  }
  try {
    return await ref
        .watch(chatRepositoryProvider)
        .fetchRoomSummaries(viewer: viewer);
  } catch (_) {
    return const {};
  }
}, retry: noRetry);

/// The live messages of one room, oldest first. Subscribed only while a
/// conversation screen is open.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, channelId) {
      ref.watch(sessionEpochProvider);
      if (!ref.watch(capabilityProvider('community.chat.view'))) {
        return Stream.value(const <ChatMessage>[]);
      }
      final viewerId = ref.watch(
        authControllerProvider.select((auth) => auth.value?.id),
      );
      return ref
          .watch(chatRepositoryProvider)
          .watchMessages(channelId, viewerId: viewerId);
    }, retry: noRetry);

/// A message on its way: shown at once, then replaced by the stored one.
class PendingMessage {
  const PendingMessage({
    required this.localId,
    required this.text,
    required this.createdAt,
    this.photo,
    this.reply,
    this.failed = false,
    this.error,
  });

  final String localId;
  final String text;
  final DateTime createdAt;
  final PickedPhoto? photo;
  final ChatReplyPreview? reply;

  /// Sending failed; the member can try again or discard it.
  final bool failed;
  final Object? error;

  PendingMessage copyWith({bool? failed, Object? error}) => PendingMessage(
    localId: localId,
    text: text,
    createdAt: createdAt,
    photo: photo,
    reply: reply,
    failed: failed ?? this.failed,
    error: error,
  );
}

/// What a room keeps beside its live list.
class ChatRoomState {
  const ChatRoomState({
    this.older = const [],
    this.loadingOlder = false,
    this.reachedStart = false,
    this.pending = const [],
    this.sent = const [],
    this.hidden = const {},
  });

  /// Messages before the live list, oldest first.
  final List<ChatMessage> older;
  final bool loadingOlder;

  /// Nothing older exists.
  final bool reachedStart;

  /// Messages on their way, in the order they were written.
  final List<PendingMessage> pending;

  /// Sent messages the live list does not hold yet.
  final List<ChatMessage> sent;

  /// Messages the member reported or deleted here: gone at once, whatever
  /// the live list still says.
  final Set<String> hidden;

  ChatRoomState copyWith({
    List<ChatMessage>? older,
    bool? loadingOlder,
    bool? reachedStart,
    List<PendingMessage>? pending,
    List<ChatMessage>? sent,
    Set<String>? hidden,
  }) => ChatRoomState(
    older: older ?? this.older,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    reachedStart: reachedStart ?? this.reachedStart,
    pending: pending ?? this.pending,
    sent: sent ?? this.sent,
    hidden: hidden ?? this.hidden,
  );
}

/// One room's actions and the state around its live list.
class ChatRoomController extends Notifier<ChatRoomState> {
  ChatRoomController(this.channelId);

  final String channelId;
  var _nextLocal = 1;
  String? _lastReadId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  AppUser get _viewer {
    final user = ref.read(authControllerProvider).value;
    if (user == null) {
      throw const CommunityException(CommunityFailure.signInAgain);
    }
    return user;
  }

  @override
  ChatRoomState build() {
    ref.watch(sessionEpochProvider);
    // A sent message is shown from [ChatRoomState.sent] until the live
    // list brings it.
    ref.listen(chatMessagesProvider(channelId), (_, next) {
      final live = next.value;
      if (live == null || state.sent.isEmpty) return;
      final ids = {for (final m in live) m.id};
      final waiting = [
        for (final m in state.sent)
          if (!ids.contains(m.id)) m,
      ];
      if (waiting.length != state.sent.length) {
        state = state.copyWith(sent: waiting);
      }
    });
    return const ChatRoomState();
  }

  /// Sends a message: it shows at once and is marked if it fails. Returns
  /// the failure, `null` when it went.
  Future<Object?> send({
    required String text,
    PickedPhoto? photo,
    ChatReplyPreview? reply,
  }) async {
    requireCapability(ref, 'community.chat.send');
    final pending = PendingMessage(
      localId: 'local-${_nextLocal++}',
      text: text.trim(),
      createdAt: ref.read(communityClockProvider)(),
      photo: photo,
      reply: reply,
    );
    state = state.copyWith(pending: [...state.pending, pending]);
    return _deliver(pending);
  }

  /// Tries a failed message again. Returns the failure, `null` when it
  /// went.
  Future<Object?> retry(String localId) async {
    final pending = _pending(localId);
    if (pending == null) return null;
    _updatePending(pending.copyWith(failed: false));
    return _deliver(pending);
  }

  /// Forgets a message that could not be sent.
  void discard(String localId) {
    state = state.copyWith(
      pending: [
        for (final p in state.pending)
          if (p.localId != localId) p,
      ],
    );
  }

  Future<Object?> _deliver(PendingMessage pending) async {
    final ticket = SessionTicket(ref);
    try {
      final sent = await _repo.sendMessage(
        author: _viewer,
        channelId: channelId,
        text: pending.text,
        photo: pending.photo,
        replyToId: pending.reply?.messageId,
      );
      if (!ticket.current) return null;
      final live = ref.read(chatMessagesProvider(channelId)).value ?? const [];
      state = state.copyWith(
        pending: [
          for (final p in state.pending)
            if (p.localId != pending.localId) p,
        ],
        sent: live.any((m) => m.id == sent.id)
            ? state.sent
            : [...state.sent, sent],
      );
      return null;
    } catch (e) {
      if (!ticket.current) return null;
      _updatePending(pending.copyWith(failed: true, error: e));
      return e;
    }
  }

  PendingMessage? _pending(String localId) {
    for (final p in state.pending) {
      if (p.localId == localId) return p;
    }
    return null;
  }

  void _updatePending(PendingMessage pending) {
    state = state.copyWith(
      pending: [
        for (final p in state.pending)
          if (p.localId == pending.localId) pending else p,
      ],
    );
  }

  /// Loads the messages before the earliest one on screen.
  Future<void> loadOlder() async {
    if (state.loadingOlder || state.reachedStart) return;
    final live = ref.read(chatMessagesProvider(channelId)).value;
    final earliest = state.older.isNotEmpty
        ? state.older.first
        : (live == null || live.isEmpty ? null : live.first);
    if (earliest == null) return;
    final ticket = SessionTicket(ref);
    state = state.copyWith(loadingOlder: true);
    try {
      final older = await _repo.fetchOlder(
        channelId,
        before: earliest.sentAt,
        viewerId: _viewer.id,
        limit: chatOlderPage,
      );
      if (!ticket.current) return;
      state = state.copyWith(
        older: [...older, ...state.older],
        loadingOlder: false,
        reachedStart: older.length < chatOlderPage,
      );
    } catch (e) {
      if (!ticket.current) return;
      state = state.copyWith(loadingOlder: false);
      rethrow;
    }
  }

  /// Records that the member read the room up to [latestId]; once per
  /// newest message. Refreshes the room list. Best effort.
  Future<void> markRead(String latestId) async {
    if (_lastReadId == latestId) return;
    _lastReadId = latestId;
    try {
      await _repo.markRead(viewer: _viewer, channelId: channelId);
      if (ref.mounted) ref.invalidate(chatRoomSummariesProvider);
    } catch (_) {}
  }

  Future<void> toggleReaction(ChatMessage message, String emoji) async {
    requireCapability(ref, 'community.chat.send');
    final mine = message.reactions.any((r) => r.emoji == emoji && r.mine);
    await _repo.setReaction(
      viewer: _viewer,
      messageId: message.id,
      emoji: emoji,
      on: !mine,
    );
  }

  Future<void> delete(ChatMessage message) async {
    requireCapability(ref, 'community.chat.send');
    await _repo.deleteMessage(viewer: _viewer, messageId: message.id);
    if (ref.mounted) _hide(message.id);
  }

  Future<void> report(ChatMessage message, ReportReason reason) async {
    requireCapability(ref, 'community.chat.view');
    await _repo.reportMessage(
      viewer: _viewer,
      messageId: message.id,
      reason: reason,
    );
    if (ref.mounted) _hide(message.id);
  }

  void _hide(String messageId) {
    state = state.copyWith(hidden: {...state.hidden, messageId});
  }
}

final chatRoomProvider = NotifierProvider.autoDispose
    .family<ChatRoomController, ChatRoomState, String>(ChatRoomController.new);

/// One line of a conversation: a message, and whether it is still on its
/// way or failed to go.
class ChatEntry {
  const ChatEntry(this.message, {this.pending});

  final ChatMessage message;
  final PendingMessage? pending;

  bool get sending => pending != null && !pending!.failed;
  bool get failed => pending?.failed ?? false;
}

/// A room as the screen shows it.
class ChatConversation {
  const ChatConversation({
    required this.entries,
    required this.canLoadOlder,
    required this.loadingOlder,
  });

  /// Oldest first.
  final List<ChatEntry> entries;
  final bool canLoadOlder;
  final bool loadingOlder;
}

/// The conversation of one room: older history, the live list, sent and
/// pending messages, without what the member blocked, reported or
/// deleted. Replies whose quote the backend did not bring get it from the
/// conversation itself.
final chatConversationProvider = Provider.autoDispose
    .family<AsyncValue<ChatConversation>, String>((ref, channelId) {
      final live = ref.watch(chatMessagesProvider(channelId));
      final room = ref.watch(chatRoomProvider(channelId));
      final blocked = ref.watch(blockedIdsProvider);
      final viewer = ref.watch(authControllerProvider).value;

      ChatConversation build(List<ChatMessage> list) {
        final seen = <String>{};
        final stored = <ChatMessage>[];
        void add(ChatMessage m) {
          if (!seen.add(m.id)) return;
          if (blocked.contains(m.authorId) || room.hidden.contains(m.id)) {
            return;
          }
          stored.add(m);
        }

        room.older.forEach(add);
        list.forEach(add);
        room.sent.forEach(add);
        // In time order; equal times keep their arrival order.
        final indexed = stored.indexed.toList()
          ..sort((a, b) {
            final byTime = a.$2.sentAt.compareTo(b.$2.sentAt);
            return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
          });
        final byId = {for (final m in stored) m.id: m};
        ChatMessage withQuote(ChatMessage m) {
          if (m.replyTo != null || m.replyToId == null) return m;
          final replied = byId[m.replyToId];
          if (replied == null) return m;
          return ChatMessage(
            id: m.id,
            channelId: m.channelId,
            authorId: m.authorId,
            authorName: m.authorName,
            text: m.text,
            sentAt: m.sentAt,
            photo: m.photo,
            replyToId: m.replyToId,
            replyTo: replied.asReplyPreview(),
            reactions: m.reactions,
          );
        }

        return ChatConversation(
          entries: [
            for (final (_, m) in indexed) ChatEntry(withQuote(m)),
            for (final p in room.pending)
              ChatEntry(
                ChatMessage(
                  id: p.localId,
                  channelId: channelId,
                  authorId: viewer?.id ?? '',
                  authorName: storedAuthorName(viewer?.displayName),
                  text: p.text,
                  sentAt: p.createdAt,
                  photo: p.photo == null
                      ? null
                      : MemoryPostPhoto(p.photo!.bytes),
                  replyToId: p.reply?.messageId,
                  replyTo: p.reply,
                ),
                pending: p,
              ),
          ],
          canLoadOlder:
              !room.reachedStart &&
              (room.older.isNotEmpty || list.length >= chatLiveWindow),
          loadingOlder: room.loadingOlder,
        );
      }

      return switch (live) {
        AsyncData(:final value) => AsyncData(build(value)),
        AsyncError(:final error, :final stackTrace) => AsyncError(
          error,
          stackTrace,
        ),
        _ => const AsyncLoading(),
      };
    });

/// Icon of a room, by its id. Rooms added later get the default.
IconData chatChannelIcon(String channelId) => switch (channelId) {
  'general' => Icons.chat_bubble_rounded,
  'puppies' => Icons.pets_rounded,
  'training' => Icons.school_rounded,
  'seniors' => Icons.favorite_rounded,
  'kittens' => Icons.pets_rounded,
  'cat-litter' => Icons.cleaning_services_rounded,
  'cat-behaviour' => Icons.toys_rounded,
  'senior-cats' => Icons.favorite_rounded,
  'health' => Icons.medical_services_rounded,
  _ => Icons.forum_rounded,
};
