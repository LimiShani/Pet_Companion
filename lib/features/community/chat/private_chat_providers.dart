import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../access/access_provider.dart';
import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../notifications/push.dart';
import '../../../platform/session.dart';
import '../../../services/community/data/chat_repository.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../community_routes.dart';
import '../community_words.dart';
import '../feed/feed_controller.dart' show noRetry;
import '../feed/post_actions.dart' show showCommunitySnack;
import '../members/members_providers.dart';
import '../safety/safety_providers.dart';
import 'chat_providers.dart';

/// The capability every private chat action needs.
const privateChatCapability = 'community.chat.private';

/// The private chats the member joined, most recently active first.
final privateChatsProvider = FutureProvider<List<PrivateChat>>((ref) {
  ref.watch(sessionEpochProvider);
  // A push notification arrived while the app is open: load again.
  ref.watch(pushArrivalsProvider);
  final viewerId = ref.watch(
    authControllerProvider.select((auth) => auth.value?.id),
  );
  final viewer = ref.read(authControllerProvider).value;
  if (viewerId == null ||
      viewer == null ||
      !ref.watch(capabilityProvider(privateChatCapability))) {
    return Future.value(const <PrivateChat>[]);
  }
  return ref.watch(chatRepositoryProvider).fetchPrivateChats(viewer: viewer);
}, retry: noRetry);

/// Invitations waiting for the member, newest first; none from someone
/// they blocked. The lists are still useful without them, so a failure
/// gives none.
final chatInvitationsProvider = FutureProvider<List<ChatInvitation>>((
  ref,
) async {
  ref.watch(sessionEpochProvider);
  ref.watch(pushArrivalsProvider);
  final viewerId = ref.watch(
    authControllerProvider.select((auth) => auth.value?.id),
  );
  final viewer = ref.read(authControllerProvider).value;
  if (viewerId == null ||
      viewer == null ||
      !ref.watch(capabilityProvider(privateChatCapability))) {
    return const [];
  }
  final blocked = ref.watch(blockedIdsProvider);
  try {
    final invitations = await ref
        .watch(chatRepositoryProvider)
        .fetchInvitations(viewer: viewer);
    return [
      for (final invitation in invitations)
        if (!blocked.contains(invitation.inviterId)) invitation,
    ];
  } catch (_) {
    return const [];
  }
}, retry: noRetry);

/// One private chat the member joined; `null` while the list loads, or
/// when it is not one of theirs.
final privateChatProvider = Provider.family<PrivateChat?, String>((ref, id) {
  for (final chat
      in ref.watch(privateChatsProvider).value ?? const <PrivateChat>[]) {
    if (chat.id == id) return chat;
  }
  return null;
});

/// The invitation to [id] waiting for the member, if there is one.
final chatInvitationProvider = Provider.family<ChatInvitation?, String>((
  ref,
  id,
) {
  for (final invitation
      in ref.watch(chatInvitationsProvider).value ?? const <ChatInvitation>[]) {
    if (invitation.channelId == id) return invitation;
  }
  return null;
});

/// People the member can start a chat with, for [search] (empty: the
/// people they talked with recently, then everyone). Without the members
/// they blocked.
final chatPeopleProvider = FutureProvider.autoDispose
    .family<List<ChatPerson>, String>((ref, search) async {
      ref.watch(sessionEpochProvider);
      final viewer = ref.watch(authControllerProvider).value;
      if (viewer == null ||
          !ref.watch(capabilityProvider(privateChatCapability))) {
        return const [];
      }
      final blocked = ref.watch(blockedIdsProvider);
      final people = await ref
          .watch(chatRepositoryProvider)
          .fetchPeople(viewer: viewer, search: search);
      return [
        for (final person in people)
          if (!blocked.contains(person.id)) person,
      ];
    }, retry: noRetry);

/// Whether the member muted [chat]: on the server (no pushes) or on this
/// phone (no unread count). The chat details switch sets both.
bool privateChatMuted(WidgetRef ref, PrivateChat chat) =>
    chat.muted || ref.watch(mutedRoomsProvider).contains(chat.id);

/// What a member does with private chats. Each action reloads the lists.
class PrivateChatController extends Notifier<void> {
  @override
  void build() {}

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  Future<T> _run<T>(Future<T> Function(AppUser viewer) action) async {
    requireCapability(ref, privateChatCapability);
    final viewer = ref.read(authControllerProvider).value;
    if (viewer == null) {
      throw const CommunityException(CommunityFailure.signInAgain);
    }
    try {
      return await action(viewer);
    } finally {
      if (ref.mounted) {
        ref.invalidate(privateChatsProvider);
        ref.invalidate(chatInvitationsProvider);
        ref.invalidate(chatRoomSummariesProvider);
      }
    }
  }

  /// Starts a chat with [memberIds] and returns its id. One person and no
  /// [name]: the chat of the two, reopened when it exists.
  Future<String> start(List<String> memberIds, {String name = ''}) => _run(
    (viewer) => _repo.createPrivateChat(
      viewer: viewer,
      memberIds: memberIds,
      name: name,
    ),
  );

  Future<void> invite(String channelId, List<String> memberIds) => _run(
    (viewer) => _repo.inviteToPrivateChat(
      viewer: viewer,
      channelId: channelId,
      memberIds: memberIds,
    ),
  );

  Future<void> answer(String channelId, {required bool accept}) => _run(
    (viewer) => _repo.answerInvitation(
      viewer: viewer,
      channelId: channelId,
      accept: accept,
    ),
  );

  Future<void> leave(String channelId) => _run(
    (viewer) => _repo.leavePrivateChat(viewer: viewer, channelId: channelId),
  );

  Future<void> remove(String channelId, String memberId) => _run(
    (viewer) => _repo.removeFromPrivateChat(
      viewer: viewer,
      channelId: channelId,
      memberId: memberId,
    ),
  );

  Future<void> makeAdmin(String channelId, String memberId) => _run(
    (viewer) => _repo.makePrivateChatAdmin(
      viewer: viewer,
      channelId: channelId,
      memberId: memberId,
    ),
  );

  Future<void> rename(String channelId, String name) => _run(
    (viewer) => _repo.renamePrivateChat(
      viewer: viewer,
      channelId: channelId,
      name: name,
    ),
  );

  /// Mutes [channelId] on the server (no pushes) and on this phone (no
  /// unread count), or unmutes it in both places.
  Future<void> setMuted(String channelId, {required bool muted}) async {
    await _run(
      (viewer) => _repo.setPrivateChatMuted(
        viewer: viewer,
        channelId: channelId,
        muted: muted,
      ),
    );
    if (!ref.mounted) return;
    final rooms = ref.read(mutedRoomsProvider.notifier);
    if (ref.read(mutedRoomsProvider).contains(channelId) != muted) {
      await rooms.toggle(channelId);
    }
  }
}

final privateChatControllerProvider =
    NotifierProvider<PrivateChatController, void>(PrivateChatController.new);

/// What a chat's message field starts with, passed to its route.
class ChatDraft {
  const ChatDraft(this.text);

  final String text;
}

/// Opens the conversation [channelId], with [draft] in its message field.
void openChat(BuildContext context, String channelId, {String? draft}) =>
    GoRouter.of(context).push(
      CommunityRoutes.chat(channelId),
      extra: draft == null ? null : ChatDraft(draft),
    );

// ---------------------------------------------------------------------------
// For other features (meetups): start a chat and open it.
// ---------------------------------------------------------------------------

/// Finds or creates the private chat of the signed-in member and [userId]
/// (a chat of two is never made twice), then opens it with [draft] ready
/// in the message field. The other person sees the chat once they accept
/// the invitation, and then reads everything from the moment they were
/// invited, the first message included. Failures are said in a snack bar.
/// Returns the chat's id, `null` when it could not be opened.
Future<String?> openDirectChat(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  String? draft,
}) => _startAndOpen(context, ref, [userId], draft: draft);

/// Creates a group chat named [name] with [userIds] invited, then opens it
/// with [draft] ready in the message field. Same rules and failures as
/// [openDirectChat] (at most 30 people, no one blocked either way).
Future<String?> openGroupChat(
  BuildContext context,
  WidgetRef ref, {
  required List<String> userIds,
  required String name,
  String? draft,
}) => _startAndOpen(context, ref, userIds, name: name, draft: draft);

Future<String?> _startAndOpen(
  BuildContext context,
  WidgetRef ref,
  List<String> userIds, {
  String name = '',
  String? draft,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final errorWords = communityErrorWords(context);
  try {
    final id = await ref
        .read(privateChatControllerProvider.notifier)
        .start(userIds, name: name);
    router.push(
      CommunityRoutes.chat(id),
      extra: draft == null ? null : ChatDraft(draft),
    );
    return id;
  } catch (e) {
    showCommunitySnack(messenger, errorWords(e));
    return null;
  }
}
