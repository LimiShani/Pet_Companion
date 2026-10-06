import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/access_provider.dart';
import '../../../auth/app_user.dart';
import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/session.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/community/data/safety_repository.dart';
import '../feed/feed_controller.dart' show noRetry;

AppUser _signedIn(Ref ref) {
  final user = ref.read(authControllerProvider).value;
  if (user == null) {
    throw const CommunityException(CommunityFailure.signInAgain);
  }
  return user;
}

/// The members the signed-in user blocked, most recent first. Blocking or
/// unblocking updates the list at once; every community list filters by
/// [blockedIdsProvider].
class BlockedMembersController
    extends SessionSafeAsyncNotifier<List<BlockedMember>> {
  CommunitySafetyRepository get _repo =>
      ref.read(communitySafetyRepositoryProvider);

  @override
  Future<List<BlockedMember>> build() async {
    ref.watch(sessionEpochProvider);
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final community =
        ref.watch(capabilityProvider('community.feed.view')) ||
        ref.watch(capabilityProvider('community.chat.view'));
    if (viewerId == null || !community) return const [];
    return ref
        .watch(communitySafetyRepositoryProvider)
        .fetchBlocked(viewer: _signedIn(ref));
  }

  Future<void> block(BlockedMember member) async {
    return sessionOperation(ref, () async {
      await _repo.block(viewer: _signedIn(ref), member: member);
      state = AsyncData([
        member,
        for (final m in state.value ?? const <BlockedMember>[])
          if (m.id != member.id) m,
      ]);
    });
  }

  Future<void> unblock(String memberId) async {
    return sessionOperation(ref, () async {
      await _repo.unblock(viewer: _signedIn(ref), memberId: memberId);
      state = AsyncData([
        for (final m in state.value ?? const <BlockedMember>[])
          if (m.id != memberId) m,
      ]);
    });
  }
}

final blockedMembersProvider =
    AsyncNotifierProvider<BlockedMembersController, List<BlockedMember>>(
      BlockedMembersController.new,
      retry: noRetry,
    );

/// The ids of the blocked members; empty while the list loads or when it
/// could not load (the backend still hides them where it can).
final blockedIdsProvider = Provider<Set<String>>(
  (ref) => {
    for (final m in ref.watch(blockedMembersProvider).value ?? const []) m.id,
  },
);

/// What members reported, for moderators. Loaded while a review screen is
/// open.
class ModerationQueueController
    extends SessionSafeAsyncNotifier<List<ModerationItem>> {
  @override
  Future<List<ModerationItem>> build() async {
    ref.watch(sessionEpochProvider);
    if (!ref.watch(capabilityProvider('community.moderate'))) {
      return const [];
    }
    return ref.watch(communitySafetyRepositoryProvider).fetchModerationQueue();
  }

  Future<void> decide(ModerationItem item, ModerationDecision decision) async {
    return sessionOperation(ref, () async {
      requireCapability(ref, 'community.moderate');
      await ref
          .read(communitySafetyRepositoryProvider)
          .moderate(item: item, decision: decision);
      state = AsyncData([
        for (final i in state.value ?? const <ModerationItem>[])
          if (i.id != item.id || i.kind != item.kind) i,
      ]);
    });
  }
}

final moderationQueueProvider =
    AsyncNotifierProvider.autoDispose<
      ModerationQueueController,
      List<ModerationItem>
    >(ModerationQueueController.new, retry: noRetry);

/// Whether the signed-in member agreed to the community rules on this
/// phone. Asked once, before their first post, comment or message.
class CommunityRulesController extends Notifier<bool> {
  String? get _key {
    final id = ref.read(authControllerProvider).value?.id;
    return id == null ? null : 'community.rules.$id';
  }

  @override
  bool build() {
    final id = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    if (id == null) return false;
    return ref.watch(settingsStoreProvider).read('community.rules.$id') == '1';
  }

  Future<void> accept() async {
    final key = _key;
    if (key == null) return;
    state = true;
    await ref.read(settingsStoreProvider).write(key, '1');
  }
}

final communityRulesProvider = NotifierProvider<CommunityRulesController, bool>(
  CommunityRulesController.new,
);
