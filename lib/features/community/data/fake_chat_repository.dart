import 'dart:async';

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
    ChatChannel(id: 'general', name: 'General', description: 'Say hello and share your day'),
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
    ChatChannel(id: 'health', name: 'Health questions', description: 'Ask other owners. For anything urgent, call your vet'),
  ];

  /// Simulated network delay so loading states are visible.
  final Duration latency;
  final DateTime Function() _now;

  /// While true every call fails, to exercise error states.
  bool failing = false;

  final _channels = <ChatChannel>[];
  final _messages = <String, List<ChatMessage>>{};
  final _updates = <String, StreamController<List<ChatMessage>>>{};
  var _nextId = 1;

  static const _unreachable = CommunityException(CommunityFailure.chatUnreachable);

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failing) throw _unreachable;
  }

  StreamController<List<ChatMessage>> _hub(String channelId) =>
      _updates.putIfAbsent(channelId, StreamController<List<ChatMessage>>.broadcast);

  List<ChatMessage> _snapshot(String channelId) => List.unmodifiable(_messages[channelId] ?? const <ChatMessage>[]);

  void _append(ChatMessage message) {
    _messages.putIfAbsent(message.channelId, () => []).add(message);
    _hub(message.channelId).add(_snapshot(message.channelId));
  }

  @override
  Future<List<ChatChannel>> fetchChannels() async {
    await _wait();
    return List.unmodifiable(_channels);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String channelId) {
    StreamSubscription<List<ChatMessage>>? live;
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
        out.add(_snapshot(channelId));
        live = _hub(channelId).stream.listen(out.add);
      },
      onCancel: () async {
        await live?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  @override
  Future<void> sendMessage({required AppUser author, required String channelId, required String text}) async {
    await _wait();
    final body = text.trim();
    if (body.isEmpty) throw const CommunityException(CommunityFailure.emptyMessage);
    _append(ChatMessage(
      id: 'm${_nextId++}',
      channelId: channelId,
      authorId: author.id,
      authorName: storedAuthorName(author.displayName),
      text: body,
      sentAt: _now(),
    ));
  }

  /// Simulates a message arriving from someone else (for tests and demos).
  void receive({
    required String channelId,
    required String authorId,
    required String authorName,
    required String text,
  }) {
    _append(ChatMessage(
      id: 'm${_nextId++}',
      channelId: channelId,
      authorId: authorId,
      authorName: authorName,
      text: text,
      sentAt: _now(),
    ));
  }

  // ---------------------------------------------------------------------
  // Sample content.
  // ---------------------------------------------------------------------

  void _seed() {
    _channels.addAll(defaultChannels);
    final now = _now();

    void say(String channelId, String authorId, String authorName, Duration ago, String text) {
      _messages.putIfAbsent(channelId, () => []).add(ChatMessage(
            id: 'm${_nextId++}',
            channelId: channelId,
            authorId: authorId,
            authorName: authorName,
            text: text,
            sentAt: now.subtract(ago),
          ));
    }

    say('general', 'u-maya', 'Maya', const Duration(hours: 3), 'Morning everyone! Biscuit says hi.');
    say('general', 'u-sam', 'Sam', const Duration(hours: 2, minutes: 48), 'Hi Maya! Pepper is already asleep again after her walk.');
    say('general', 'u-noa', 'Noa', const Duration(minutes: 35), 'Anyone else have a dog who hides when the vacuum comes out?');
    say('general', 'u-jonas', 'Jonas', const Duration(minutes: 21), 'Luna barks at it from behind the sofa. Very brave.');

    say('puppies', 'u-maya', 'Maya', const Duration(hours: 6), 'How long did teething last for yours? Biscuit is chewing everything.');
    say('puppies', 'u-priya', 'Priya', const Duration(hours: 5, minutes: 30), 'Until about six months for us. Frozen carrot sticks were a big help.');

    say('training', 'u-priya', 'Priya', const Duration(days: 1, hours: 2), 'Short sessions are working much better than one long one.');
    say('training', 'u-jonas', 'Jonas', const Duration(days: 1), 'Same here: five minutes before dinner, every day.');

    say('seniors', 'u-noa', 'Noa', const Duration(days: 2), 'A ramp for the car was the best thing we bought this year.');

    say('kittens', 'u-dana', 'Dana', const Duration(hours: 7), 'Ten weeks old and she has discovered the curtains. Any tips?');
    say('kittens', 'u-omer', 'Omer', const Duration(hours: 6, minutes: 40), 'A tall scratching post next to them saved ours. And lots of play before bed.');

    say('cat-litter', 'u-dana', 'Dana', const Duration(hours: 4), 'Two cats, one covered box, and the smell is getting to us. What worked for you?');
    say('cat-litter', 'u-omer', 'Omer', const Duration(hours: 3, minutes: 30), 'A second box in another room made the biggest difference for us.');

    say('cat-behaviour', 'u-noa', 'Noa', const Duration(days: 1, hours: 5), 'Shoko does laps of the flat at four in the morning. Please tell me this passes.');
    say('cat-behaviour', 'u-dana', 'Dana', const Duration(days: 1, hours: 4), 'It got much better for us with a long play session before the last meal.');

    say('senior-cats', 'u-omer', 'Omer', const Duration(days: 3), 'Low-sided litter box for our sixteen year old. She uses it happily again.');

    say('health', 'u-sam', 'Sam', const Duration(hours: 9), 'How often do you all brush teeth? We manage about three times a week.');
    say('health', 'u-maya', 'Maya', const Duration(hours: 8), 'Our vet suggested daily if the dog accepts it. We are building up slowly.');
  }
}
