import '../../../auth/app_user.dart';
import 'community_models.dart';

/// Topic chat rooms and private chats. Failures surface as
/// [CommunityException].
///
/// [viewerId] names the member a call is made for: it decides which
/// reactions are "mine" and hides what they reported. Messages of members
/// the viewer blocked are left out by the backend where it can (Supabase
/// does, by row level security); the screens filter them as well.
abstract class ChatRepository {
  /// The channels, in display order.
  Future<List<ChatChannel>> fetchChannels();

  /// Each room's latest message and unread count, by room id. Rooms without
  /// messages may be missing.
  Future<Map<String, ChatRoomSummary>> fetchRoomSummaries({
    required AppUser viewer,
  });

  /// Records that [viewer] has read [channelId] up to now.
  Future<void> markRead({required AppUser viewer, required String channelId});

  /// The latest messages of a channel, oldest first. Emits the current list
  /// on listen and again whenever it changes (new, deleted, reactions).
  Stream<List<ChatMessage>> watchMessages(String channelId, {String? viewerId});

  /// Up to [limit] messages sent before [before], oldest first: the history
  /// above what [watchMessages] holds.
  Future<List<ChatMessage>> fetchOlder(
    String channelId, {
    required DateTime before,
    String? viewerId,
    int limit = 50,
  });

  /// Sends a message: text, a photo, or both, optionally answering
  /// [replyToId]. Returns it as stored.
  Future<ChatMessage> sendMessage({
    required AppUser author,
    required String channelId,
    required String text,
    PickedPhoto? photo,
    String? replyToId,
  });

  /// Deletes one of the viewer's own messages.
  Future<void> deleteMessage({
    required AppUser viewer,
    required String messageId,
  });

  /// Adds or removes [viewer]'s [emoji] under a message.
  Future<void> setReaction({
    required AppUser viewer,
    required String messageId,
    required String emoji,
    required bool on,
  });

  /// Records a report for moderation and hides the message from [viewer].
  Future<void> reportMessage({
    required AppUser viewer,
    required String messageId,
    required ReportReason reason,
  });

  // -------------------------------------------------------------------
  // Private chats (0026_private_chats.sql). Their messages go through the
  // calls above, by the chat's id; the summaries include them.
  // -------------------------------------------------------------------

  /// The private chats [viewer] joined, most recently active first.
  Future<List<PrivateChat>> fetchPrivateChats({required AppUser viewer});

  /// Invitations waiting for [viewer], newest first.
  Future<List<ChatInvitation>> fetchInvitations({required AppUser viewer});

  /// People [viewer] can start a chat with, the ones they talked with
  /// recently first; [search] narrows them by name. Never the viewer,
  /// anyone blocked either way, or anyone without private chats.
  Future<List<ChatPerson>> fetchPeople({
    required AppUser viewer,
    String search = '',
  });

  /// Starts a chat with [memberIds] and returns its id. One person and no
  /// [name]: the chat of the two, reopened when it exists.
  Future<String> createPrivateChat({
    required AppUser viewer,
    required List<String> memberIds,
    String name = '',
  });

  /// An admin invites more people to a group chat.
  Future<void> inviteToPrivateChat({
    required AppUser viewer,
    required String channelId,
    required List<String> memberIds,
  });

  /// Joins a chat [viewer] was invited to, or drops the invitation.
  Future<void> answerInvitation({
    required AppUser viewer,
    required String channelId,
    required bool accept,
  });

  /// Leaves a chat: [viewer] loses all of it.
  Future<void> leavePrivateChat({
    required AppUser viewer,
    required String channelId,
  });

  /// An admin removes a member, or takes back an invitation.
  Future<void> removeFromPrivateChat({
    required AppUser viewer,
    required String channelId,
    required String memberId,
  });

  /// An admin makes a joined member admin too.
  Future<void> makePrivateChatAdmin({
    required AppUser viewer,
    required String channelId,
    required String memberId,
  });

  /// An admin renames a group chat.
  Future<void> renamePrivateChat({
    required AppUser viewer,
    required String channelId,
    required String name,
  });

  /// Mutes a chat's push notifications for [viewer], or unmutes them.
  Future<void> setPrivateChatMuted({
    required AppUser viewer,
    required String channelId,
    required bool muted,
  });
}
