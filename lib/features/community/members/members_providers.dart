import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../notifications/push.dart';
import '../../../platform/session.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../feed/feed_controller.dart' show noRetry;
import '../safety/safety_providers.dart';

/// A member's public profile; `null` when the account is gone.
final memberProfileProvider = FutureProvider.autoDispose
    .family<MemberProfile?, String>((ref, memberId) {
      ref.watch(sessionEpochProvider);
      return ref
          .watch(communityMembersRepositoryProvider)
          .fetchMember(memberId);
    }, retry: noRetry);

/// A member's latest posts, without them when the viewer blocked them.
final memberPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, memberId) async {
      ref.watch(sessionEpochProvider);
      final viewer = ref.watch(authControllerProvider).value;
      if (viewer == null ||
          !ref.watch(capabilityProvider('community.feed.view')) ||
          ref.watch(blockedIdsProvider).contains(memberId)) {
        return const [];
      }
      return ref
          .watch(feedRepositoryProvider)
          .fetchPosts(
            viewer: viewer,
            query: FeedQuery(authorId: memberId),
            limit: 50,
          );
    }, retry: noRetry);

/// What happened to the signed-in member's posts and messages, newest
/// first. Blocked members' doings are left out.
final activityProvider = FutureProvider<List<ActivityItem>>((ref) async {
  ref.watch(sessionEpochProvider);
  // A push notification arrived while the app is open: load again.
  ref.watch(pushArrivalsProvider);
  final viewer = ref.watch(authControllerProvider).value;
  final community =
      ref.watch(capabilityProvider('community.feed.view')) ||
      ref.watch(capabilityProvider('community.chat.view'));
  if (viewer == null || !community) return const [];
  final blocked = ref.watch(blockedIdsProvider);
  final items = await ref
      .watch(communityMembersRepositoryProvider)
      .fetchActivity(viewer: viewer);
  return [
    for (final item in items)
      if (!blocked.contains(item.actorId)) item,
  ];
}, retry: noRetry);

/// When the member last opened the activity page, on this phone.
class ActivitySeen extends Notifier<DateTime?> {
  String? get _key {
    final id = ref.read(authControllerProvider).value?.id;
    return id == null ? null : 'community.activity.seen.$id';
  }

  @override
  DateTime? build() {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    if (id == null) return null;
    final stored = ref
        .watch(settingsStoreProvider)
        .read('community.activity.seen.$id');
    return stored == null ? null : DateTime.tryParse(stored);
  }

  Future<void> markSeen(DateTime when) async {
    final key = _key;
    if (key == null) return;
    state = when;
    await ref.read(settingsStoreProvider).write(key, when.toIso8601String());
  }
}

final activitySeenProvider = NotifierProvider<ActivitySeen, DateTime?>(
  ActivitySeen.new,
);

/// Something happened since the activity page was last opened.
final hasNewActivityProvider = Provider<bool>((ref) {
  final items = ref.watch(activityProvider).value ?? const <ActivityItem>[];
  final seen = ref.watch(activitySeenProvider);
  return items.any((item) => seen == null || item.at.isAfter(seen));
});

/// The rooms the member muted on this phone: no unread count for them.
class MutedRooms extends Notifier<Set<String>> {
  String? get _key {
    final id = ref.read(authControllerProvider).value?.id;
    return id == null ? null : 'community.muted.$id';
  }

  @override
  Set<String> build() {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    if (id == null) return const {};
    final stored = ref.watch(settingsStoreProvider).read('community.muted.$id');
    if (stored == null || stored.isEmpty) return const {};
    return stored.split(',').toSet();
  }

  /// Mutes or unmutes [roomId]; returns whether it is muted now.
  Future<bool> toggle(String roomId) async {
    final muted = !state.contains(roomId);
    state = muted ? {...state, roomId} : ({...state}..remove(roomId));
    final key = _key;
    if (key != null) {
      await ref.read(settingsStoreProvider).write(key, state.join(','));
    }
    return muted;
  }
}

final mutedRoomsProvider = NotifierProvider<MutedRooms, Set<String>>(
  MutedRooms.new,
);
