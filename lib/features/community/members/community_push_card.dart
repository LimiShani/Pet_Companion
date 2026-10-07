import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../notifications/push.dart';
import '../../../platform/session.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../services/community/data/push_preferences_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../community_words.dart';
import '../feed/feed_controller.dart' show noRetry;
import '../feed/post_actions.dart' show showCommunitySnack;

/// The member's push choices, saved on the server. A switch moves at once
/// and goes back if saving fails.
class PushPreferencesController
    extends SessionSafeAsyncNotifier<PushPreferences> {
  @override
  Future<PushPreferences> build() async {
    ref.watch(sessionEpochProvider);
    final viewer = ref.watch(authControllerProvider).value;
    if (viewer == null) return const PushPreferences();
    return ref.watch(pushPreferencesRepositoryProvider).fetch(viewer: viewer);
  }

  Future<void> change(PushPreferences next) async {
    return sessionOperation(ref, () async {
      final viewer = ref.read(authControllerProvider).value;
      if (viewer == null) {
        throw const CommunityException(CommunityFailure.signInAgain);
      }
      final before = state.value ?? const PushPreferences();
      state = AsyncData(next);
      try {
        await ref
            .read(pushPreferencesRepositoryProvider)
            .save(viewer: viewer, preferences: next);
      } catch (_) {
        state = AsyncData(before);
        rethrow;
      }
    });
  }
}

final pushPreferencesProvider =
    AsyncNotifierProvider<PushPreferencesController, PushPreferences>(
      PushPreferencesController.new,
      retry: noRetry,
    );

/// Settings > Notifications: what the community may notify this member
/// about. Shown only when the app can receive push notifications.
class CommunityPushCard extends ConsumerWidget {
  const CommunityPushCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(pushMessagingProvider) == null) {
      return const SizedBox.shrink();
    }
    final l10n = context.communityL10n;
    final preferences = ref.watch(pushPreferencesProvider);
    final value = preferences.value;

    Future<void> change(PushPreferences next) async {
      final messenger = ScaffoldMessenger.of(context);
      final errorWords = communityErrorWords(context);
      try {
        await ref.read(pushPreferencesProvider.notifier).change(next);
      } catch (e) {
        showCommunitySnack(messenger, errorWords(e));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.pushTitle,
                style: AppText.cardTitle.copyWith(fontWeight: FontWeight.w800),
              ),
              if (value == null && preferences.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.pushLoadFailed,
                    style: AppText.body.copyWith(color: AppColors.brown),
                  ),
                )
              else ...[
                SwitchListTile(
                  key: const ValueKey('push-replies'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pushReplies),
                  value: value?.replies ?? true,
                  onChanged: value == null
                      ? null
                      : (on) => change(value.copyWith(replies: on)),
                ),
                SwitchListTile(
                  key: const ValueKey('push-comments'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pushComments),
                  value: value?.comments ?? true,
                  onChanged: value == null
                      ? null
                      : (on) => change(value.copyWith(comments: on)),
                ),
                SwitchListTile(
                  key: const ValueKey('push-likes'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.pushLikes),
                  subtitle: Text(l10n.pushLikesNote),
                  value: value?.likes ?? false,
                  onChanged: value == null
                      ? null
                      : (on) => change(value.copyWith(likes: on)),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  l10n.pushNote,
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
