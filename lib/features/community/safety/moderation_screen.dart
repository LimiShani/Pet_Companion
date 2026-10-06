import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../access/feature_gate.dart';
import '../../../l10n/l10n.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../chat/chat_providers.dart';
import '../community_words.dart';
import '../feed/post_actions.dart' show showCommunitySnack;
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/post_photo_view.dart';
import '../widgets/section_state.dart';
import '../widgets/small_tag.dart';
import 'safety_providers.dart';

/// The moderators' review: what members reported, newest report first.
/// Keep shows it again (and starts a fresh count); Remove deletes it.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.moderate',
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final queue = ref.watch(moderationQueueProvider);
    final list = queue.value;

    final Widget body;
    if (list == null) {
      body = queue.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SectionState(
              icon: Icons.cloud_off_rounded,
              title: l10n.reviewLoadFailed,
              message: communityErrorText(context, queue.error),
              actionLabel: context.l10n.commonTryAgain,
              onAction: () => ref.invalidate(moderationQueueProvider),
            );
    } else if (list.isEmpty) {
      body = SectionState(
        icon: Icons.verified_rounded,
        title: l10n.reviewEmptyTitle,
        message: l10n.reviewEmptyMessage,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moderationQueueProvider);
          await ref.read(moderationQueueProvider.future);
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            16,
            AppSpacing.screen,
            24,
          ),
          itemCount: list.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.cardGap),
          itemBuilder: (context, index) => _ItemCard(
            key: ValueKey('${list[index].kind.name}-${list[index].id}'),
            item: list[index],
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.reviewReports, showBack: true),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerStatefulWidget {
  const _ItemCard({super.key, required this.item});

  final ModerationItem item;

  @override
  ConsumerState<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<_ItemCard> {
  var _busy = false;

  Future<void> _decide(ModerationDecision decision) async {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    if (decision == ModerationDecision.remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.removeItemTitle),
          content: Text(l10n.removeItemBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(app.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.removeItem),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(moderationQueueProvider.notifier)
          .decide(widget.item, decision);
      showCommunitySnack(
        messenger,
        decision == ModerationDecision.keep ? l10n.keptDone : l10n.removedDone,
      );
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.communityL10n;
    final app = context.l10n;
    final item = widget.item;
    final now = ref.watch(communityClockProvider)();
    String? where;
    if (item.kind == ModerationKind.message && item.context != null) {
      final channels = ref.watch(chatChannelsProvider).value ?? const [];
      for (final c in channels) {
        if (c.id == item.context) where = l10n.inRoom(l10n.roomName(c));
      }
    }
    final reasons = [for (final r in item.reasons) l10n.reportReason(r)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SmallTag(
                  l10n.moderationKind(item.kind),
                  color: AppColors.yellow,
                ),
                if (item.hidden)
                  SmallTag(l10n.hiddenTag, color: AppColors.peach),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                AuthorAvatar(
                  name: item.authorName,
                  authorId: item.authorId,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AutoDirectionText(
                        l10n.memberName(item.authorName),
                        style: AppText.secondary.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dotted([
                          l10n.relativeTime(
                            app,
                            AppFormat.of(context),
                            item.createdAt,
                            now,
                          ),
                          ?where,
                        ]),
                        style: AppText.label.copyWith(color: AppColors.brown),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              AutoDirectionText(
                item.text,
                style: AppText.body.copyWith(height: 1.4),
              ),
            ],
            if (item.photo != null) ...[
              const SizedBox(height: 10),
              PostPhotoView(photo: item.photo!),
            ],
            const SizedBox(height: 10),
            Text(
              dotted([l10n.reportCountLine(item.reportCount), ...reasons]),
              style: AppText.secondary.copyWith(
                color: AppColors.coralDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _decide(ModerationDecision.keep),
                    child: Text(l10n.keepItem),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _decide(ModerationDecision.remove),
                    child: Text(l10n.removeItem),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
