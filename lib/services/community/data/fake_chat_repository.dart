import 'dart:async';

import 'package:flutter/material.dart';

import '../../../auth/app_user.dart';
import 'audience.dart';
import 'chat_repository.dart';
import 'community_models.dart';

/// In-memory chat for development and tests. Each channel's live updates
/// go through a broadcast [StreamController]. Nothing persists across
/// restarts.
///
/// Private chats follow the database's rules (0026): an invitee sees
/// nothing until they join, history starts when a member was brought in,
/// only admins invite, rename, remove and make admins, the last admin
/// leaving makes the earliest-joined member admin, the last member leaving
/// deletes the chat, and a chat of two with a block in [blocks] is closed.
/// The sample data gives the demo account (`demo`) a chat with Maya, a
/// group walk and an invitation from Dana.
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

  /// Private chats by id.
  final _private = <String, _PrivateChat>{};

  /// Blocks, as (blocker, blocked): no invitations either way, and a chat
  /// of the two is closed. Tests add to it.
  final blocks = <(String, String)>{};

  /// Accounts whose private chats are switched off. Tests add to it.
  final privateChatsOff = <String>{};

  /// The members the fake knows, by id: (name, city).
  final _people = <String, (String, String)>{
    for (final (id, name, city) in samplePeople) id: (name, city),
  };

  /// Sample community members (the same as the fake members repository).
  static const samplePeople = [
    ('demo', 'Alex', 'Tel Aviv'),
    ('u-maya', 'Maya', 'Haifa'),
    ('u-sam', 'Sam', 'Herzliya'),
    ('u-noa', 'Noa', 'Jerusalem'),
    ('u-jonas', 'Jonas', ''),
    ('u-priya', 'Priya', 'Ramat Gan'),
    ('u-dana', 'Dana', 'Beersheba'),
    ('u-omer', 'Omer', ''),
  ];

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

  bool _visible(_Stored m, String? viewerId) {
    if (viewerId != null && (_reported[viewerId]?.contains(m.id) ?? false)) {
      return false;
    }
    final chat = _private[m.channelId];
    if (chat == null) return true;
    final member = chat.members[viewerId];
    return member != null &&
        member.joined &&
        !privateChatsOff.contains(viewerId) &&
        !m.sentAt.isBefore(member.invitedAt);
  }

  List<_Stored> _visibleIn(String channelId, String? viewerId) => [
    for (final m in _messages[channelId] ?? const <_Stored>[])
      if (_visible(m, viewerId)) m,
  ];

  String _nameOf(String userId) => _people[userId]?.$1 ?? '';

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
      system: m.system?.withNames({
        for (final id in m.system!.userIds) id: _nameOf(id),
      }),
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
    for (final id in [for (final c in _channels) c.id, ..._private.keys]) {
      final list = _visibleIn(id, viewer.id);
      if (list.isEmpty) continue;
      final last = list.last;
      final since =
          _reads[viewer.id]?[id] ?? now.subtract(const Duration(days: 3));
      final unread = list
          .where(
            (m) =>
                m.system == null &&
                m.authorId != viewer.id &&
                m.sentAt.isAfter(since),
          )
          .length;
      summaries[id] = ChatRoomSummary(
        channelId: id,
        lastAuthorId: last.authorId,
        lastAuthorName: last.authorName,
        lastText: last.text,
        lastHasPhoto: last.photo != null,
        lastMessageAt: last.sentAt,
        unread: unread > 100 ? 100 : unread,
        lastSystem: last.system?.withNames({
          for (final userId in last.system!.userIds) userId: _nameOf(userId),
        }),
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
    if (_private.containsKey(channelId) && !_joined(channelId, viewer.id)) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
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
    if (_private[channelId] case final chat?) {
      if (!_joined(channelId, author.id) ||
          privateChatsOff.contains(author.id)) {
        throw const CommunityException(CommunityFailure.notAllowed);
      }
      if (_closed(chat)) {
        throw const CommunityException(CommunityFailure.chatClosed);
      }
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
    if (m.authorId != viewer.id || m.system != null) {
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
    if (!_visible(m, viewer.id)) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
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
    if (!_visible(m, viewer.id)) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
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

  /// Answers by others to the messages of [viewerId], as activity.
  List<ActivityItem> repliesTo(String viewerId) => [
    for (final list in _messages.values)
      for (final m in list)
        if (m.replyToId != null &&
            m.authorId != viewerId &&
            _visible(m, viewerId))
          if (_find(m.replyToId!) case final replied?
              when replied.authorId == viewerId)
            ActivityItem(
              kind: ActivityKind.reply,
              id: m.id,
              targetId: m.channelId,
              actorId: m.authorId,
              actorName: m.authorName,
              preview: m.text,
              at: m.sentAt,
            ),
  ];

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
  // Private chats.
  // ---------------------------------------------------------------------

  /// The sample chats' ids, for tests.
  static const mayaChatId = 'pc-maya';
  static const walksChatId = 'pc-walks';
  static const kittensChatId = 'pc-kittens';

  var _nextChat = 1;

  bool _joined(String channelId, String? userId) =>
      _private[channelId]?.members[userId]?.joined ?? false;

  bool _blockedBetween(String a, String b) =>
      blocks.contains((a, b)) || blocks.contains((b, a));

  bool _closed(_PrivateChat chat) {
    final key = chat.directKey;
    if (key == null) return false;
    final (a, b) = key;
    return _blockedBetween(a, b);
  }

  void _requireChats(AppUser viewer) {
    if (privateChatsOff.contains(viewer.id)) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
  }

  _PrivateChat _chatAsAdmin(AppUser viewer, String channelId) {
    _requireChats(viewer);
    final chat = _private[channelId];
    final me = chat?.members[viewer.id];
    if (chat == null || me == null || !me.joined) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    if (me.role != ChatRole.admin) {
      throw const CommunityException(CommunityFailure.notChatAdmin);
    }
    return chat;
  }

  void _line(String channelId, String actorId, ChatSystemLine line) {
    _append(
      _Stored(
        id: 'm${_nextId++}',
        channelId: channelId,
        authorId: actorId,
        authorName: _nameOf(actorId),
        text: '',
        sentAt: _now(),
        system: line,
      ),
    );
  }

  /// Checks and adds invitations; returns who was invited.
  List<String> _invite(
    _PrivateChat chat,
    String inviterId,
    Iterable<String> memberIds,
  ) {
    final invited = <String>[];
    for (final id in memberIds) {
      if (id == inviterId ||
          invited.contains(id) ||
          chat.members.containsKey(id)) {
        continue;
      }
      if (!_people.containsKey(id) ||
          privateChatsOff.contains(id) ||
          _blockedBetween(inviterId, id)) {
        throw const CommunityException(CommunityFailure.cannotInvite);
      }
      invited.add(id);
    }
    if (chat.members.length + invited.length > PrivateChatLimits.participants) {
      throw const CommunityException(CommunityFailure.chatFull);
    }
    final now = _now();
    for (final id in invited) {
      chat.members[id] = _ChatMember(invitedBy: inviterId, invitedAt: now);
    }
    return invited;
  }

  /// After someone is gone: no joined member left deletes the chat; no
  /// admin left makes the earliest-joined member admin.
  void _afterGone(_PrivateChat chat) {
    final joined = [
      for (final e in chat.members.entries)
        if (e.value.joined) e,
    ];
    if (joined.isEmpty) {
      _private.remove(chat.id);
      _messages.remove(chat.id);
      return;
    }
    if (!joined.any((e) => e.value.role == ChatRole.admin)) {
      joined.sort((a, b) => a.value.joinedAt!.compareTo(b.value.joinedAt!));
      joined.first.value.role = ChatRole.admin;
    }
  }

  DateTime _activeAt(_PrivateChat chat, String viewerId) {
    var at = chat.createdAt;
    final mine = chat.members[viewerId]?.invitedAt;
    if (mine != null && mine.isAfter(at)) at = mine;
    final visible = _visibleIn(chat.id, viewerId);
    if (visible.isNotEmpty && visible.last.sentAt.isAfter(at)) {
      at = visible.last.sentAt;
    }
    return at;
  }

  PrivateChat _toChat(_PrivateChat chat, String viewerId) {
    final entries = chat.members.entries.toList()
      ..sort((a, b) {
        if (a.value.joined != b.value.joined) return a.value.joined ? -1 : 1;
        final at = a.value.joinedAt ?? a.value.invitedAt;
        final bt = b.value.joinedAt ?? b.value.invitedAt;
        return at.compareTo(bt);
      });
    final key = chat.directKey;
    return PrivateChat(
      id: chat.id,
      name: chat.name,
      createdBy: chat.createdBy,
      createdAt: chat.createdAt,
      directWith: key == null ? null : (key.$1 == viewerId ? key.$2 : key.$1),
      directName: key == null
          ? ''
          : _nameOf(key.$1 == viewerId ? key.$2 : key.$1),
      muted: chat.members[viewerId]?.muted ?? false,
      closed: _closed(chat),
      members: [
        for (final e in entries)
          PrivateChatMember(
            userId: e.key,
            name: _nameOf(e.key),
            role: e.value.role,
            joined: e.value.joined,
            invitedBy: e.value.invitedBy,
            invitedAt: e.value.invitedAt,
            joinedAt: e.value.joinedAt,
          ),
      ],
    );
  }

  @override
  Future<List<PrivateChat>> fetchPrivateChats({required AppUser viewer}) async {
    await _wait();
    if (privateChatsOff.contains(viewer.id)) return const [];
    final mine =
        [
          for (final chat in _private.values)
            if (chat.members[viewer.id]?.joined ?? false) chat,
        ]..sort(
          (a, b) => _activeAt(b, viewer.id).compareTo(_activeAt(a, viewer.id)),
        );
    return [for (final chat in mine) _toChat(chat, viewer.id)];
  }

  @override
  Future<List<ChatInvitation>> fetchInvitations({
    required AppUser viewer,
  }) async {
    await _wait();
    if (privateChatsOff.contains(viewer.id)) return const [];
    final invitations = <ChatInvitation>[
      for (final chat in _private.values)
        if (chat.members[viewer.id] case final me? when !me.joined)
          if (!blocks.contains((viewer.id, me.invitedBy)))
            ChatInvitation(
              channelId: chat.id,
              name: chat.name,
              direct: chat.directKey != null,
              inviterId: me.invitedBy,
              inviterName: _nameOf(me.invitedBy),
              participantCount: chat.members.length,
              invitedAt: me.invitedAt,
            ),
    ]..sort((a, b) => b.invitedAt.compareTo(a.invitedAt));
    return invitations;
  }

  @override
  Future<List<ChatPerson>> fetchPeople({
    required AppUser viewer,
    String search = '',
  }) async {
    await _wait();
    _requireChats(viewer);
    final recent = <String, DateTime>{};
    for (final chat in _private.values) {
      if (!(chat.members[viewer.id]?.joined ?? false)) continue;
      final at = _activeAt(chat, viewer.id);
      for (final id in chat.members.keys) {
        if (id == viewer.id) continue;
        if (recent[id] == null || recent[id]!.isBefore(at)) recent[id] = at;
      }
    }
    final words = search.trim().toLowerCase();
    final people =
        [
          for (final MapEntry(key: id, value: (name, city)) in _people.entries)
            if (id != viewer.id &&
                !_blockedBetween(viewer.id, id) &&
                !privateChatsOff.contains(id) &&
                (words.isEmpty || name.toLowerCase().contains(words)))
              ChatPerson(
                id: id,
                name: name,
                city: city,
                recent: recent.containsKey(id),
              ),
        ]..sort((a, b) {
          final at = recent[a.id];
          final bt = recent[b.id];
          if (at != null && bt != null) return bt.compareTo(at);
          if (at != null) return -1;
          if (bt != null) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    return people;
  }

  @override
  Future<String> createPrivateChat({
    required AppUser viewer,
    required List<String> memberIds,
    String name = '',
  }) async {
    await _wait();
    _requireChats(viewer);
    _people.putIfAbsent(
      viewer.id,
      () => (storedAuthorName(viewer.displayName), ''),
    );
    final people = {...memberIds}..remove(viewer.id);
    final title = name.trim();
    if (people.isEmpty) {
      throw const CommunityException(CommunityFailure.unknown);
    }
    if (title.length > PrivateChatLimits.nameLength) {
      throw const CommunityException(CommunityFailure.textInvalid);
    }
    if (people.length + 1 > PrivateChatLimits.participants) {
      throw const CommunityException(CommunityFailure.chatFull);
    }
    final now = _now();
    (String, String)? key;
    if (people.length == 1 && title.isEmpty) {
      final other = people.single;
      key = viewer.id.compareTo(other) < 0
          ? (viewer.id, other)
          : (other, viewer.id);
      for (final chat in _private.values) {
        if (chat.directKey != key) continue;
        if (_blockedBetween(viewer.id, other)) {
          throw const CommunityException(CommunityFailure.cannotInvite);
        }
        final me = chat.members[viewer.id];
        if (me == null) {
          chat.members[viewer.id] = _ChatMember(
            role: ChatRole.admin,
            invitedBy: viewer.id,
            invitedAt: now,
            joinedAt: now,
          );
        } else if (!me.joined) {
          me.joinedAt = now;
        }
        _invite(chat, viewer.id, [other]);
        _changed(chat.id);
        return chat.id;
      }
    }
    final chat = _PrivateChat(
      id: 'pc-new-${_nextChat++}',
      name: key == null ? title : '',
      createdBy: viewer.id,
      createdAt: now,
      directKey: key,
    );
    chat.members[viewer.id] = _ChatMember(
      role: ChatRole.admin,
      invitedBy: viewer.id,
      invitedAt: now,
      joinedAt: now,
    );
    final added = _invite(chat, viewer.id, people);
    _private[chat.id] = chat;
    if (key == null) {
      _line(chat.id, viewer.id, const ChatSystemLine(event: ChatEvent.created));
      _line(
        chat.id,
        viewer.id,
        ChatSystemLine(event: ChatEvent.added, userIds: added),
      );
    }
    return chat.id;
  }

  @override
  Future<void> inviteToPrivateChat({
    required AppUser viewer,
    required String channelId,
    required List<String> memberIds,
  }) async {
    await _wait();
    final chat = _chatAsAdmin(viewer, channelId);
    if (chat.directKey != null) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    final added = _invite(chat, viewer.id, memberIds);
    if (added.isNotEmpty) {
      _line(
        channelId,
        viewer.id,
        ChatSystemLine(event: ChatEvent.added, userIds: added),
      );
    }
  }

  @override
  Future<void> answerInvitation({
    required AppUser viewer,
    required String channelId,
    required bool accept,
  }) async {
    await _wait();
    _requireChats(viewer);
    final chat = _private[channelId];
    final me = chat?.members[viewer.id];
    if (chat == null || me == null || me.joined) {
      throw const CommunityException(CommunityFailure.gone);
    }
    if (!accept) {
      chat.members.remove(viewer.id);
      _afterGone(chat);
      return;
    }
    me.joinedAt = _now();
    if (chat.directKey == null) {
      _line(
        channelId,
        viewer.id,
        const ChatSystemLine(event: ChatEvent.joined),
      );
    } else {
      _changed(channelId);
    }
  }

  @override
  Future<void> leavePrivateChat({
    required AppUser viewer,
    required String channelId,
  }) async {
    await _wait();
    final chat = _private[channelId];
    final me = chat?.members[viewer.id];
    if (chat == null || me == null) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    if (me.joined) {
      _line(channelId, viewer.id, const ChatSystemLine(event: ChatEvent.left));
    }
    chat.members.remove(viewer.id);
    _reads[viewer.id]?.remove(channelId);
    _afterGone(chat);
    _changed(channelId);
  }

  @override
  Future<void> removeFromPrivateChat({
    required AppUser viewer,
    required String channelId,
    required String memberId,
  }) async {
    await _wait();
    final chat = _chatAsAdmin(viewer, channelId);
    if (memberId == viewer.id || chat.directKey != null) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    final member = chat.members[memberId];
    if (member == null) return;
    if (member.joined) {
      _line(
        channelId,
        viewer.id,
        ChatSystemLine(event: ChatEvent.removed, userIds: [memberId]),
      );
    }
    chat.members.remove(memberId);
    _reads[memberId]?.remove(channelId);
    _afterGone(chat);
    _changed(channelId);
  }

  @override
  Future<void> makePrivateChatAdmin({
    required AppUser viewer,
    required String channelId,
    required String memberId,
  }) async {
    await _wait();
    final chat = _chatAsAdmin(viewer, channelId);
    final member = chat.members[memberId];
    if (member == null || !member.joined) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    if (member.role == ChatRole.admin) return;
    member.role = ChatRole.admin;
    _line(
      channelId,
      viewer.id,
      ChatSystemLine(event: ChatEvent.admin, userIds: [memberId]),
    );
  }

  @override
  Future<void> renamePrivateChat({
    required AppUser viewer,
    required String channelId,
    required String name,
  }) async {
    await _wait();
    final chat = _chatAsAdmin(viewer, channelId);
    final title = name.trim();
    if (chat.directKey != null) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    if (title.isEmpty || title.length > PrivateChatLimits.nameLength) {
      throw const CommunityException(CommunityFailure.textInvalid);
    }
    if (title == chat.name) return;
    chat.name = title;
    _line(
      channelId,
      viewer.id,
      ChatSystemLine(event: ChatEvent.renamed, name: title),
    );
  }

  @override
  Future<void> setPrivateChatMuted({
    required AppUser viewer,
    required String channelId,
    required bool muted,
  }) async {
    await _wait();
    _requireChats(viewer);
    final me = _private[channelId]?.members[viewer.id];
    if (me == null || !me.joined) {
      throw const CommunityException(CommunityFailure.notAllowed);
    }
    me.muted = muted;
  }

  /// Whether [userId] muted [channelId] on the server, for tests.
  bool mutedOnServer(String channelId, String userId) =>
      _private[channelId]?.members[userId]?.muted ?? false;

  /// Simulates someone inviting [userId] to a new group chat (for tests
  /// and demos). Returns the chat's id.
  String inviteAs({
    required String inviterId,
    required String userId,
    required String name,
    List<String> others = const [],
  }) {
    final now = _now();
    final chat = _PrivateChat(
      id: 'pc-new-${_nextChat++}',
      name: name,
      createdBy: inviterId,
      createdAt: now,
    );
    chat.members[inviterId] = _ChatMember(
      role: ChatRole.admin,
      invitedBy: inviterId,
      invitedAt: now,
      joinedAt: now,
    );
    _private[chat.id] = chat;
    final added = _invite(chat, inviterId, [userId, ...others]);
    _line(chat.id, inviterId, const ChatSystemLine(event: ChatEvent.created));
    _line(
      chat.id,
      inviterId,
      ChatSystemLine(event: ChatEvent.added, userIds: added),
    );
    return chat.id;
  }

  /// Simulates [userId] answering an invitation (for tests and demos).
  void answerAs(String channelId, String userId, {bool accept = true}) {
    final chat = _private[channelId]!;
    final member = chat.members[userId]!;
    if (!accept) {
      chat.members.remove(userId);
      _afterGone(chat);
      _changed(channelId);
      return;
    }
    member.joinedAt = _now();
    _line(channelId, userId, const ChatSystemLine(event: ChatEvent.joined));
  }

  // ---------------------------------------------------------------------
  // Sample content.
  // ---------------------------------------------------------------------

  /// The demo account's private chats: one with Maya, a group walk with
  /// Noa and Jonas (Sam is still invited), and Dana's invitation to her
  /// kitten playdates.
  void _seedPrivate(DateTime now) {
    void say(
      String channelId,
      String authorId,
      DateTime at,
      String text, {
      ChatSystemLine? system,
    }) {
      _messages
          .putIfAbsent(channelId, () => [])
          .add(
            _Stored(
              id: 'm${_nextId++}',
              channelId: channelId,
              authorId: authorId,
              authorName: _nameOf(authorId),
              text: text,
              sentAt: at,
              system: system,
            ),
          );
    }

    _ChatMember joined(String by, DateTime invited, DateTime at) =>
        _ChatMember(invitedBy: by, invitedAt: invited, joinedAt: at);

    // A chat of two with Maya.
    final mayaStart = now.subtract(const Duration(days: 2));
    final maya = _PrivateChat(
      id: mayaChatId,
      name: '',
      createdBy: 'u-maya',
      createdAt: mayaStart,
      directKey: ('demo', 'u-maya'),
    );
    maya.members['u-maya'] = joined('u-maya', mayaStart, mayaStart)
      ..role = ChatRole.admin;
    maya.members['demo'] = joined(
      'u-maya',
      mayaStart,
      mayaStart.add(const Duration(minutes: 10)),
    );
    _private[maya.id] = maya;
    final yesterday = now.subtract(const Duration(days: 1));
    say(
      maya.id,
      'u-maya',
      yesterday,
      'Hi Alex! Is Kelly up for a walk on the beach this weekend?',
    );
    say(
      maya.id,
      'demo',
      yesterday.add(const Duration(minutes: 20)),
      'Kelly would love that. Saturday morning?',
    );
    say(
      maya.id,
      'u-maya',
      now.subtract(const Duration(minutes: 40)),
      'Saturday at 8 by the lifeguard tower then 🐾',
    );
    _reads.putIfAbsent('demo', () => {})[maya.id] = yesterday.add(
      const Duration(minutes: 21),
    );

    // A group walk: Noa started it, Jonas joined, Sam has not answered.
    final walksStart = now.subtract(const Duration(days: 3));
    final walks = _PrivateChat(
      id: walksChatId,
      name: 'Morning walks in the park',
      createdBy: 'u-noa',
      createdAt: walksStart,
    );
    walks.members['u-noa'] = joined('u-noa', walksStart, walksStart)
      ..role = ChatRole.admin;
    walks.members['demo'] = joined(
      'u-noa',
      walksStart,
      walksStart.add(const Duration(hours: 1)),
    );
    walks.members['u-jonas'] = joined(
      'u-noa',
      walksStart,
      now.subtract(const Duration(days: 2)),
    );
    walks.members['u-sam'] = _ChatMember(
      invitedBy: 'u-noa',
      invitedAt: yesterday,
    );
    _private[walks.id] = walks;
    say(
      walks.id,
      'u-noa',
      walksStart,
      '',
      system: const ChatSystemLine(event: ChatEvent.created),
    );
    say(
      walks.id,
      'u-noa',
      walksStart,
      '',
      system: const ChatSystemLine(
        event: ChatEvent.added,
        userIds: ['demo', 'u-jonas'],
      ),
    );
    say(
      walks.id,
      'demo',
      walksStart.add(const Duration(hours: 1)),
      '',
      system: const ChatSystemLine(event: ChatEvent.joined),
    );
    say(
      walks.id,
      'u-jonas',
      now.subtract(const Duration(days: 2)),
      '',
      system: const ChatSystemLine(event: ChatEvent.joined),
    );
    say(
      walks.id,
      'u-noa',
      now.subtract(const Duration(hours: 20)),
      'We start at 7 from the north gate. Who is coming tomorrow?',
    );
    say(
      walks.id,
      'u-jonas',
      now.subtract(const Duration(hours: 19)),
      'Luna and I are in.',
    );
    say(
      walks.id,
      'u-noa',
      yesterday,
      '',
      system: const ChatSystemLine(event: ChatEvent.added, userIds: ['u-sam']),
    );
    say(
      walks.id,
      'u-noa',
      now.subtract(const Duration(hours: 2)),
      'Lovely walk today, thank you all!',
    );
    _reads['demo']![walks.id] = now.subtract(const Duration(hours: 19));

    // Dana invites the demo account to her kitten playdates.
    final kittensStart = yesterday;
    final kittens = _PrivateChat(
      id: kittensChatId,
      name: 'Kitten playdates',
      createdBy: 'u-dana',
      createdAt: kittensStart,
    );
    kittens.members['u-dana'] = joined('u-dana', kittensStart, kittensStart)
      ..role = ChatRole.admin;
    kittens.members['u-omer'] = joined(
      'u-dana',
      kittensStart,
      now.subtract(const Duration(hours: 20)),
    );
    kittens.members['demo'] = _ChatMember(
      invitedBy: 'u-dana',
      invitedAt: now.subtract(const Duration(hours: 2)),
    );
    _private[kittens.id] = kittens;
    say(
      kittens.id,
      'u-dana',
      kittensStart,
      '',
      system: const ChatSystemLine(event: ChatEvent.created),
    );
    say(
      kittens.id,
      'u-dana',
      kittensStart,
      '',
      system: const ChatSystemLine(event: ChatEvent.added, userIds: ['u-omer']),
    );
    say(
      kittens.id,
      'u-dana',
      now.subtract(const Duration(hours: 5)),
      'Saturday afternoon at my place? Mitzi needs friends.',
    );
    say(
      kittens.id,
      'u-dana',
      now.subtract(const Duration(hours: 2)),
      '',
      system: const ChatSystemLine(event: ChatEvent.added, userIds: ['demo']),
    );
  }

  void _seed() {
    _channels.addAll(defaultChannels);
    final now = _now();
    _seedPrivate(now);

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

/// A private chat as the fake keeps it.
class _PrivateChat {
  _PrivateChat({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.directKey,
  });

  final String id;
  String name;
  final String createdBy;
  final DateTime createdAt;

  /// The two accounts of a chat of two, in order.
  final (String, String)? directKey;
  final members = <String, _ChatMember>{};
}

class _ChatMember {
  _ChatMember({
    required this.invitedBy,
    required this.invitedAt,
    this.role = ChatRole.member,
    this.joinedAt,
  });

  ChatRole role;
  final String invitedBy;
  final DateTime invitedAt;
  DateTime? joinedAt;
  bool muted = false;

  bool get joined => joinedAt != null;
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
    this.system,
  });

  final String id;
  final String channelId;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime sentAt;
  final PostPhoto? photo;
  final String? replyToId;
  final ChatSystemLine? system;
  final reactions = <String, Set<String>>{};
}
