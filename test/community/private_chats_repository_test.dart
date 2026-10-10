import 'package:flutter_test/flutter_test.dart';
import 'package:pet_companion/auth/app_user.dart';
import 'package:pet_companion/services/community/data/community_models.dart';
import 'package:pet_companion/services/community/data/fake_chat_repository.dart';

/// The rules of private chats, as the in-memory fake keeps them (the
/// database keeps the same ones: supabase/tests/private_chats_test.sql).
void main() {
  final now = DateTime(2026, 5, 14, 9, 41);
  const alex = AppUser(
    id: 'demo',
    email: 'demo@petloop.app',
    displayName: 'Alex',
  );
  const noa = AppUser(
    id: 'u-noa',
    email: 'noa@example.test',
    displayName: 'Noa',
  );
  const jonas = AppUser(
    id: 'u-jonas',
    email: 'jonas@example.test',
    displayName: 'Jonas',
  );
  const sam = AppUser(
    id: 'u-sam',
    email: 'sam@example.test',
    displayName: 'Sam',
  );
  late FakeChatRepository repo;

  setUp(
    () => repo = FakeChatRepository(latency: Duration.zero, now: () => now),
  );

  Future<List<ChatMessage>> messages(String channelId, String viewerId) =>
      repo.watchMessages(channelId, viewerId: viewerId).first;

  Future<CommunityFailure?> failure(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on CommunityException catch (e) {
      return e.failure;
    }
  }

  test(
    'the demo account has a chat with Maya, a group walk and an invitation',
    () async {
      final chats = await repo.fetchPrivateChats(viewer: alex);
      expect(
        [for (final c in chats) c.id],
        [FakeChatRepository.mayaChatId, FakeChatRepository.walksChatId],
      );
      expect(chats.first.direct, isTrue);
      expect(chats.first.directName, 'Maya');
      final walks = chats.last;
      expect(walks.name, 'Morning walks in the park');
      expect(walks.isAdmin('u-noa'), isTrue);
      expect(walks.member('u-sam')!.joined, isFalse);
      expect(walks.participantCount, 4);

      final invitations = await repo.fetchInvitations(viewer: alex);
      expect(invitations, hasLength(1));
      expect(invitations.single.name, 'Kitten playdates');
      expect(invitations.single.inviterName, 'Dana');
      expect(invitations.single.participantCount, 3);

      final summaries = await repo.fetchRoomSummaries(viewer: alex);
      expect(summaries[FakeChatRepository.mayaChatId]!.unread, 1);
      // System lines are not unread messages.
      expect(summaries[FakeChatRepository.walksChatId]!.unread, 1);
      expect(summaries.containsKey(FakeChatRepository.kittensChatId), isFalse);
    },
  );

  test(
    'an invitee sees nothing until they join, then from their invitation on',
    () async {
      const kittens = FakeChatRepository.kittensChatId;
      expect(await messages(kittens, 'demo'), isEmpty);
      expect(
        await failure(
          () => repo.sendMessage(author: alex, channelId: kittens, text: 'Hi'),
        ),
        CommunityFailure.notAllowed,
      );

      await repo.answerInvitation(
        viewer: alex,
        channelId: kittens,
        accept: true,
      );
      final seen = await messages(kittens, 'demo');
      // Dana's message came before the invitation; the line adding Alex and
      // the line saying Alex joined come after.
      expect(
        seen.map((m) => m.text),
        isNot(contains('Saturday afternoon at my place? Mitzi needs friends.')),
      );
      expect(
        [for (final m in seen) m.system?.event],
        [ChatEvent.added, ChatEvent.joined],
      );
      expect(seen.first.system!.userNames, {'demo': 'Alex'});
      expect(await repo.fetchInvitations(viewer: alex), isEmpty);
      await repo.sendMessage(
        author: alex,
        channelId: kittens,
        text: 'Count us in',
      );
    },
  );

  test('saying no thanks drops the invitation', () async {
    await repo.answerInvitation(
      viewer: alex,
      channelId: FakeChatRepository.kittensChatId,
      accept: false,
    );
    expect(await repo.fetchInvitations(viewer: alex), isEmpty);
    expect(
      (await repo.fetchPrivateChats(viewer: alex)).map((c) => c.id),
      isNot(contains(FakeChatRepository.kittensChatId)),
    );
  });

  test(
    'a new group: the creator is admin, the others are invited, lines say so',
    () async {
      final id = await repo.createPrivateChat(
        viewer: alex,
        memberIds: ['u-sam', 'u-omer'],
        name: '  Beach day ',
      );
      final chat = (await repo.fetchPrivateChats(
        viewer: alex,
      )).firstWhere((c) => c.id == id);
      expect(chat.name, 'Beach day');
      expect(chat.isAdmin('demo'), isTrue);
      expect(
        [for (final m in chat.members) (m.userId, m.joined)],
        [('demo', true), ('u-sam', false), ('u-omer', false)],
      );
      final lines = await messages(id, 'demo');
      expect(
        [for (final m in lines) m.system?.event],
        [ChatEvent.created, ChatEvent.added],
      );
      expect(lines.last.system!.userIds, ['u-sam', 'u-omer']);
      // Sam is also still invited to the sample walk.
      expect((await repo.fetchInvitations(viewer: sam)).map((i) => i.name), [
        'Beach day',
        'Morning walks in the park',
      ]);
    },
  );

  test('a chat of two is reopened, never made twice', () async {
    final id = await repo.createPrivateChat(
      viewer: alex,
      memberIds: ['u-maya'],
    );
    expect(id, FakeChatRepository.mayaChatId);
    final other = await repo.createPrivateChat(
      viewer: alex,
      memberIds: ['u-priya'],
    );
    expect(
      await repo.createPrivateChat(viewer: alex, memberIds: ['u-priya']),
      other,
    );
    // No lines in a chat of two, and Priya is invited.
    expect(await messages(other, 'demo'), isEmpty);
    expect(
      (await repo.fetchPrivateChats(
        viewer: alex,
      )).firstWhere((c) => c.id == other).directName,
      'Priya',
    );
    // The first message reaches Priya once she joins.
    await repo.sendMessage(author: alex, channelId: other, text: 'Hi Priya');
    const priya = AppUser(
      id: 'u-priya',
      email: 'priya@example.test',
      displayName: 'Priya',
    );
    await repo.answerInvitation(viewer: priya, channelId: other, accept: true);
    expect((await messages(other, 'u-priya')).single.text, 'Hi Priya');
  });

  test('only admins invite, rename, remove and make admins', () async {
    const walks = FakeChatRepository.walksChatId;
    expect(
      await failure(
        () => repo.inviteToPrivateChat(
          viewer: alex,
          channelId: walks,
          memberIds: ['u-priya'],
        ),
      ),
      CommunityFailure.notChatAdmin,
    );
    expect(
      await failure(
        () => repo.renamePrivateChat(
          viewer: alex,
          channelId: walks,
          name: 'Mine',
        ),
      ),
      CommunityFailure.notChatAdmin,
    );
    expect(
      await failure(
        () => repo.removeFromPrivateChat(
          viewer: alex,
          channelId: walks,
          memberId: 'u-jonas',
        ),
      ),
      CommunityFailure.notChatAdmin,
    );

    await repo.makePrivateChatAdmin(
      viewer: noa,
      channelId: walks,
      memberId: 'demo',
    );
    await repo.renamePrivateChat(
      viewer: alex,
      channelId: walks,
      name: 'Park walks',
    );
    await repo.inviteToPrivateChat(
      viewer: alex,
      channelId: walks,
      memberIds: ['u-priya'],
    );
    await repo.removeFromPrivateChat(
      viewer: alex,
      channelId: walks,
      memberId: 'u-jonas',
    );
    final chat = (await repo.fetchPrivateChats(
      viewer: alex,
    )).firstWhere((c) => c.id == walks);
    expect(chat.name, 'Park walks');
    expect(chat.member('u-priya')!.joined, isFalse);
    expect(chat.member('u-jonas'), isNull);
    final events = [
      for (final m in await messages(walks, 'demo')) m.system?.event,
    ];
    expect(
      events,
      containsAllInOrder([
        ChatEvent.admin,
        ChatEvent.renamed,
        ChatEvent.added,
        ChatEvent.removed,
      ]),
    );
    // Jonas lost the whole chat.
    expect(await messages(walks, 'u-jonas'), isEmpty);
  });

  test(
    'the last admin leaving hands over; the last member leaving deletes the chat',
    () async {
      const walks = FakeChatRepository.walksChatId;
      await repo.leavePrivateChat(viewer: noa, channelId: walks);
      var chat = (await repo.fetchPrivateChats(
        viewer: alex,
      )).firstWhere((c) => c.id == walks);
      // Alex joined before Jonas.
      expect(chat.isAdmin('demo'), isTrue);
      expect(chat.member('u-noa'), isNull);
      expect(
        (await messages(walks, 'demo')).last.system!.event,
        ChatEvent.left,
      );

      await repo.leavePrivateChat(viewer: alex, channelId: walks);
      expect(await messages(walks, 'demo'), isEmpty);
      chat = (await repo.fetchPrivateChats(
        viewer: jonas,
      )).firstWhere((c) => c.id == walks);
      expect(chat.isAdmin('u-jonas'), isTrue);
      await repo.leavePrivateChat(viewer: jonas, channelId: walks);
      // Sam's invitation went with the chat.
      expect(await repo.fetchInvitations(viewer: sam), isEmpty);
    },
  );

  test('a block closes a chat of two and keeps people apart', () async {
    repo.blocks.add(('demo', 'u-maya'));
    final maya = (await repo.fetchPrivateChats(viewer: alex)).first;
    expect(maya.closed, isTrue);
    expect(
      await failure(
        () => repo.sendMessage(author: alex, channelId: maya.id, text: 'Hi'),
      ),
      CommunityFailure.chatClosed,
    );
    final people = await repo.fetchPeople(viewer: alex);
    expect(people.map((p) => p.id), isNot(contains('u-maya')));
    expect(
      await failure(
        () => repo.createPrivateChat(
          viewer: alex,
          memberIds: ['u-maya', 'u-sam'],
          name: 'Walk',
        ),
      ),
      CommunityFailure.cannotInvite,
    );
  });

  test(
    'people: recent first, then by name; search by name; never oneself',
    () async {
      final people = await repo.fetchPeople(viewer: alex);
      expect(people.map((p) => p.id), isNot(contains('demo')));
      final recent = [
        for (final p in people)
          if (p.recent) p.id,
      ];
      expect(recent.first, 'u-maya');
      expect(recent, containsAll(['u-noa', 'u-jonas', 'u-sam']));
      expect(people.indexWhere((p) => !p.recent), recent.length);
      expect(
        (await repo.fetchPeople(viewer: alex, search: 'pri')).single.name,
        'Priya',
      );
    },
  );

  test('at most 30 people, and switched-off accounts are left out', () async {
    expect(
      await failure(
        () => repo.createPrivateChat(
          viewer: alex,
          memberIds: [for (var i = 0; i < 30; i++) 'x$i'],
          name: 'Crowd',
        ),
      ),
      CommunityFailure.chatFull,
    );
    repo.privateChatsOff.add('u-sam');
    expect(
      (await repo.fetchPeople(viewer: alex)).map((p) => p.id),
      isNot(contains('u-sam')),
    );
    expect(
      await failure(
        () => repo.createPrivateChat(viewer: alex, memberIds: ['u-sam']),
      ),
      CommunityFailure.cannotInvite,
    );
  });

  test('muting is kept on the server', () async {
    await repo.setPrivateChatMuted(
      viewer: alex,
      channelId: FakeChatRepository.mayaChatId,
      muted: true,
    );
    expect(repo.mutedOnServer(FakeChatRepository.mayaChatId, 'demo'), isTrue);
    expect((await repo.fetchPrivateChats(viewer: alex)).first.muted, isTrue);
  });
}
