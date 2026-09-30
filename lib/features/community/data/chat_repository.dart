import '../../../auth/app_user.dart';
import 'community_models.dart';

/// Topic chat rooms. Failures surface as [CommunityException].
abstract class ChatRepository {
  /// The channels, in display order.
  Future<List<ChatChannel>> fetchChannels();

  /// The messages of a channel, oldest first. Emits the current list on
  /// listen and again whenever it changes.
  Stream<List<ChatMessage>> watchMessages(String channelId);

  Future<void> sendMessage({required AppUser author, required String channelId, required String text});
}
