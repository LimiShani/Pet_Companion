import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/app_user.dart';
import 'audience.dart';
import 'chat_repository.dart';
import 'community_models.dart';

/// In-memory chat for development and tests. Each channel's live updates
/// go through a broadcast [StreamController]. Nothing persists across
/// restarts.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? now,
    bool seeded = true,
  }) : _now = now ?? DateTime.now {
    if (seeded) _seed();
  }

  /// The channels the app ships with, in display order (the migrations
  /// seed the same ones): shared rooms first and last, dogs, then cats.
  /// Names and descriptions are as the database stores them; the screen
  /// shows these rooms in its own language, by id.
  static const defaultChannels = [
    ChatChannel(
      id: 'general',
      name: 'General',
      description: 'Say hello and share your day',
    ),
    ChatChannel(
      id: 'puppies',
      name: 'Puppies',
      description: 'First weeks, teething and sleep',
      audience: Audience.dogs,
    ),
    ChatChannel(
      id: 'training',
      name: 'Training tips',
      description: 'What works, one small step at a time',
      audience: Audience.dogs,
    ),
    ChatChannel(
      id: 'seniors',
      name: 'Senior dogs',
      description: 'Comfort and care for older friends',
      audience: Audience.dogs,
    ),
    ChatChannel(
      id: 'kittens',
      name: 'Kittens',
      description: 'First weeks, litter habits and play',
      audience: Audience.cats,
    ),
    ChatChannel(
      id: 'cat-litter',
      name: 'Litter and cleaning',
      description: 'Litter, smell and how many boxes',
      audience: Audience.cats,
    ),
    ChatChannel(
      id: 'cat-behaviour',
      name: 'Cat behaviour and play',
      description: 'Scratching, night-time energy, a second cat',
      audience: Audience.cats,
    ),
    ChatChannel(
      id: 'senior-cats',
      name: 'Senior cats',
      description: 'Comfort and care for older cats',
      audience: Audience.cats,
    ),
    ChatChannel(
      id: 'health',
      name: 'Health questions',
      description: 'Ask other owners. For anything urgent, call your vet',
    ),
  ];

  /// How many of the latest messages [watchMessages] holds; older ones
  /// come from [fetchOlder], as on Supabase.
  static const historySize = 200;

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final DateTime Function() _now;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  /// While true only sending fails, to exercise retries.
  bool sendFailing = false;

  final _channels = <ChatChannel>[];
  final _messages = <String, List<_Stored>>{};
  final _updates = <String, StreamController<void>>{};

  /// Member id -> room id -> when they last read it.
  final _reads = <String, Map<String, DateTime>>{};

  /// Member id -> ids of the messages they reported.
  final _reported = <String, Set<String>>{};

  /// Every report filed, for tests.
  final reports =
      <({String messageId, String reporterId, ReportReason reason})>[];
  var _nextId = 1;

  static const _unreachable = CommunityException(
    CommunityFailure.chatUnreachable,
  );

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) throw _unreachable;
  }

  StreamController<void> _hub(String channelId) =>
      _updates.putIfAbsent(channelId, StreamController<void>.broadcast);

  void _changed(String channelId) => _hub(channelId).add(null);

  _Stored? _find(String messageId) {
    for (final list in _messages.values) {
      for (final m in list) {
        if (m.id == messageId) return m;
      }
    }
    return null;
  }

  bool _visible(_Stored m, String? viewerId) =>
      viewerId == null || !(_reported[viewerId]?.contains(m.id) ?? false);

  List<_Stored> _visibleIn(String channelId, String? viewerId) => [
    for (final m in _messages[channelId] ?? const <_Stored>[])
      if (_visible(m, viewerId)) m,
  ];

  ChatMessage _toMessage(_Stored m, String? viewerId) {
    final replied = m.replyToId == null ? null : _find(m.replyToId!);
    return ChatMessage(
      id: m.id,
      channelId: m.channelId,
      authorId: m.authorId,
      authorName: m.authorName,
      text: m.text,
      sentAt: m.sentAt,
      photo: m.photo,
      replyToId: m.replyToId,
      replyTo: replied == null || !_visible(replied, viewerId)
          ? null
          : ChatReplyPreview(
              messageId: replied.id,
              authorId: replied.authorId,
              authorName: replied.authorName,
              text: replied.text,
              hasPhoto: replied.photo != null,
            ),
      reactions: [
        for (final emoji in chatReactions)
          if (m.reactions[emoji]?.isNotEmpty ?? false)
            ChatReaction(
              emoji: emoji,
              count: m.reactions[emoji]!.length,
              mine: m.reactions[emoji]!.contains(viewerId),
            ),
      ],
    );
  }

  List<ChatMessage> _latest(String channelId, String? viewerId) {
    final all = _visibleIn(channelId, viewerId);
    final start = all.length > historySize ? all.length - historySize : 0;
    return List.unmodifiable([
      for (final m in all.sublist(start)) _toMessage(m, viewerId),
    ]);
  }

  _Stored _append(_Stored message) {
    _messages.putIfAbsent(message.channelId, () => []).add(message);
    _changed(message.channelId);
    return message;
  }

  @override
  Future<List<ChatChannel>> fetchChannels() async {
    await _wait();
    return List.unmodifiable(_channels);
  }

  @override
  Future<Map<String, ChatRoomSummary>> fetchRoomSummaries({
    required AppUser viewer,
  }) async {
    await _wait();
    final now = _now();
    final summaries = <String, ChatRoomSummary>{};
    for (final channel in _channels) {
      final list = _visibleIn(channel.id, viewer.id);
      if (list.isEmpty) continue;
      final last = list.last;
      final since =
          _reads[viewer.id]?[channel.id] ??
          now.subtract(const Duration(days: 3));
      final unread = list
          .where((m) => m.authorId != viewer.id && m.sentAt.isAfter(since))
          .length;
      summaries[channel.id] = ChatRoomSummary(
        channelId: channel.id,
        lastAuthorId: last.authorId,
        lastAuthorName: last.authorName,
        lastText: last.text,
        lastHasPhoto: last.photo != null,
        lastMessageAt: last.sentAt,
        unread: unread > 100 ? 100 : unread,
      );
    }
    return summaries;
  }

  @override
  Future<void> markRead({
    required AppUser viewer,
    required String channelId,
  }) async {
    await _wait();
    _reads.putIfAbsent(viewer.id, () => {})[channelId] = _now();
  }

  /// When [viewerId] last read [channelId], for tests.
  DateTime? lastRead(String viewerId, String channelId) =>
      _reads[viewerId]?[channelId];

  @override
  Stream<List<ChatMessage>> watchMessages(
    String channelId, {
    String? viewerId,
  }) {
    StreamSubscription<void>? live;
    late final StreamController<List<ChatMessage>> out;
    out = StreamController<List<ChatMessage>>(
      onListen: () async {
        try {
          await _wait();
        } on CommunityException catch (e) {
          if (!out.isClosed) out.addError(e);
          return;
        }
        if (out.isClosed) return;
        out.add(_latest(channelId, viewerId));
        live = _hub(channelId).stream.listen((_) {
          if (!out.isClosed) out.add(_latest(channelId, viewerId));
        });
      },
      onCancel: () async {
        await live?.cancel();
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
  }) async {
    await _wait();
    final older = _visibleIn(
      channelId,
      viewerId,
    ).where((m) => m.sentAt.isBefore(before)).toList();
    final start = older.length > limit ? older.length - limit : 0;
    return [for (final m in older.sublist(start)) _toMessage(m, viewerId)];
  }

  @override
  Future<ChatMessage> sendMessage({
    required AppUser author,
    required String channelId,
    required String text,
    PickedPhoto? photo,
    String? replyToId,
  }) async {
    await _wait();
    if (sendFailing) throw _unreachable;
    final body = text.trim();
    if (body.isEmpty && photo == null) {
      throw const CommunityException(CommunityFailure.emptyMessage);
    }
    final stored = _append(
      _Stored(
        id: 'm${_nextId++}',
        channelId: channelId,
        authorId: author.id,
        authorName: storedAuthorName(author.displayName),
        text: body,
        sentAt: _now(),
        photo: photo == null ? null : MemoryPostPhoto(photo.bytes),
        replyToId: replyToId,
      ),
    );
    return _toMessage(stored, author.id);
  }

  @override
  Future<void> deleteMessage({
    required AppUser viewer,
    required String messageId,
  }) async {
    await _wait();
    final m = _find(messageId);
    if (m == null) throw const CommunityException(CommunityFailure.gone);
    if (m.authorId != viewer.id) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    _messages[m.channelId]!.remove(m);
    _changed(m.channelId);
  }

  @override
  Future<void> setReaction({
    required AppUser viewer,
    required String messageId,
    required String emoji,
    required bool on,
  }) async {
    await _wait();
    final m = _find(messageId);
    if (m == null) throw const CommunityException(CommunityFailure.gone);
    final who = m.reactions.putIfAbsent(emoji, () => <String>{});
    if (on) {
      who.add(viewer.id);
    } else {
      who.remove(viewer.id);
    }
    _changed(m.channelId);
  }

  @override
  Future<void> reportMessage({
    required AppUser viewer,
    required String messageId,
    required ReportReason reason,
  }) async {
    await _wait();
    final m = _find(messageId);
    if (m == null) throw const CommunityException(CommunityFailure.gone);
    _reported.putIfAbsent(viewer.id, () => {}).add(messageId);
    reports.add((messageId: messageId, reporterId: viewer.id, reason: reason));
    _changed(m.channelId);
  }

  /// Simulates a message arriving from someone else (for tests and demos).
  /// Returns its id.
  String receive({
    required String channelId,
    required String authorId,
    required String authorName,
    required String text,
    String? replyToId,
    DateTime? sentAt,
  }) {
    return _append(
      _Stored(
        id: 'm${_nextId++}',
        channelId: channelId,
        authorId: authorId,
        authorName: authorName,
        text: text,
        sentAt: sentAt ?? _now(),
        replyToId: replyToId,
      ),
    ).id;
  }

  /// Simulates someone else reacting (for tests and demos).
  void reactAs(String userId, String messageId, String emoji) {
    final m = _find(messageId)!;
    m.reactions.putIfAbsent(emoji, () => <String>{}).add(userId);
    _changed(m.channelId);
  }

  /// The id of the first message in [channelId] that reads [text].
  String idOf(String channelId, String text) =>
      _messages[channelId]!.firstWhere((m) => m.text == text).id;

  // ---------------------------------------------------------------------
  // Sample content.
  // ---------------------------------------------------------------------

  void _seed() {
    _channels.addAll(defaultChannels);
    final now = _now();

    String say(
      String channelId,
      String authorId,
      String authorName,
      Duration ago,
      String text, {
      String? replyTo,
      PostPhoto? photo,
    }) {
      final m = _Stored(
        id: 'm${_nextId++}',
        channelId: channelId,
        authorId: authorId,
        authorName: authorName,
        text: text,
        sentAt: now.subtract(ago),
        replyToId: replyTo,
        photo: photo,
      );
      _messages.putIfAbsent(channelId, () => []).add(m);
      return m.id;
    }

    say(
      'general',
      'u-maya',
      'Maya',
      const Duration(hours: 3),
      'Morning everyone! Biscuit says hi.',
    );
    final pepper = say(
      'general',
      'u-sam',
      'Sam',
      const Duration(hours: 2, minutes: 48),
      'Hi Maya! Pepper is already asleep again after her walk.',
    );
    _find(pepper)!.reactions['😂'] = {'u-maya', 'u-noa'};
    final vacuum = say(
      'general',
      'u-noa',
      'Noa',
      const Duration(minutes: 35),
      'Anyone else have a dog who hides when the vacuum comes out?',
    );
    say(
      'general',
      'u-jonas',
      'Jonas',
      const Duration(minutes: 21),
      'Luna barks at it from behind the sofa. Very brave.',
      replyTo: vacuum,
    );
    say(
      'general',
      'u-jonas',
      'Jonas',
      const Duration(minutes: 20),
      'Here she is, guarding the living room.',
      photo: const PlaceholderPostPhoto(Color(0xFFA7B882)),
    );

    say(
      'puppies',
      'u-maya',
      'Maya',
      const Duration(hours: 6),
      'How long did teething last for yours? Biscuit is chewing everything.',
    );
    say(
      'puppies',
      'u-priya',
      'Priya',
      const Duration(hours: 5, minutes: 30),
      'Until about six months for us. Frozen carrot sticks were a big help.',
    );

    say(
      'training',
      'u-priya',
      'Priya',
      const Duration(days: 1, hours: 2),
      'Short sessions are working much better than one long one.',
    );
    say(
      'training',
      'u-jonas',
      'Jonas',
      const Duration(days: 1),
      'Same here: five minutes before dinner, every day.',
    );

    say(
      'seniors',
      'u-noa',
      'Noa',
      const Duration(days: 2),
      'A ramp for the car was the best thing we bought this year.',
    );

    say(
      'kittens',
      'u-dana',
      'Dana',
      const Duration(hours: 7),
      'Ten weeks old and she has discovered the curtains. Any tips?',
    );
    say(
      'kittens',
      'u-omer',
      'Omer',
      const Duration(hours: 6, minutes: 40),
      'A tall scratching post next to them saved ours. And lots of play before bed.',
    );

    say(
      'cat-litter',
      'u-dana',
      'Dana',
      const Duration(hours: 4),
      'Two cats, one covered box, and the smell is getting to us. What worked for you?',
    );
    say(
      'cat-litter',
      'u-omer',
      'Omer',
      const Duration(hours: 3, minutes: 30),
      'A second box in another room made the biggest difference for us.',
    );

    say(
      'cat-behaviour',
      'u-noa',
      'Noa',
      const Duration(days: 1, hours: 5),
      'Shoko does laps of the flat at four in the morning. Please tell me this passes.',
    );
    say(
      'cat-behaviour',
      'u-dana',
      'Dana',
      const Duration(days: 1, hours: 4),
      'It got much better for us with a long play session before the last meal.',
    );

    say(
      'senior-cats',
      'u-omer',
      'Omer',
      const Duration(days: 3),
      'Low-sided litter box for our sixteen year old. She uses it happily again.',
    );

    say(
      'health',
      'u-sam',
      'Sam',
      const Duration(hours: 9),
      'How often do you all brush teeth? We manage about three times a week.',
    );
    say(
      'health',
      'u-maya',
      'Maya',
      const Duration(hours: 8),
      'Our vet suggested daily if the dog accepts it. We are building up slowly.',
    );
  }
}

/// A message as the fake keeps it: reactions by emoji, as member ids.
class _Stored {
  _Stored({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.sentAt,
    this.photo,
    this.replyToId,
  });

  final String id;
  final String channelId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime sentAt;
  final PostPhoto? photo;
  final String? replyToId;
  final reactions = <String, Set<String>>{};
}
