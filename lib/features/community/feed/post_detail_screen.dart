import '../../../access/feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../community_words.dart';
import '../../../services/community/data/community_models.dart';
import '../../../services/community/data/community_providers.dart';
import '../widgets/advice_notice.dart';
import '../widgets/author_avatar.dart';
import '../widgets/auto_direction_text.dart';
import '../widgets/message_bar.dart';
import '../widgets/section_state.dart';
import 'feed_controller.dart';
import '../../../access/access_provider.dart';
import '../../../auth/auth_controller.dart';
import '../../../widgets/app_icon.dart';
import '../safety/safety_flows.dart';
import '../safety/safety_providers.dart';
import '../widgets/small_tag.dart';
import 'post_actions.dart';
import 'post_card.dart';

/// One post with its comments and an add-comment field.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await ensureCommunityRules(context, ref)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    setState(() => _sending = true);
    try {
      await ref.read(commentsProvider(widget.postId).notifier).add(text);
      _comment.clear();
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final feed = ref.watch(feedControllerProvider);
    final post = ref.watch(postProvider(widget.postId));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoralHeader(title: l10n.postTitle, showBack: true),
          if (post == null)
            Expanded(
              child: feed.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SectionState(
                      icon: Icons.search_off_rounded,
                      title: l10n.postGoneTitle,
                      message: l10n.postGoneMessage,
                      actionLabel: l10n.backToFeed,
                      onAction: () => Navigator.of(context).maybePop(),
                    ),
            )
          else ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  16,
                  AppSpacing.screen,
                  16,
                ),
                children: [
                  PostCard(
                    post: post,
                    onRemoved: () {
                      if (mounted) Navigator.of(context).maybePop();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(
                      l10n.comments,
                      style: AppText.label.copyWith(
                        color: AppColors.brown,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const AdviceNotice(),
                  const SizedBox(height: 10),
                  _Comments(post: post),
                ],
              ),
            ),
            MessageBar(
              controller: _comment,
              hint: l10n.commentHint,
              sendTooltip: l10n.sendComment,
              sending: _sending,
              onSend: _send,
              inputFormatters: [
                LengthLimitingTextInputFormatter(CommunityLimits.commentLength),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Comments extends ConsumerWidget {
  const _Comments({required this.post});

  final Post post;

  String get postId => post.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeatureGate(
    capability: 'community.feed.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final comments = ref.watch(commentsProvider(postId));
    final now = ref.watch(communityClockProvider)();
    final blocked = ref.watch(blockedIdsProvider);
    // The helpful answer to a question comes first.
    final list =
        comments.value?.where((c) => !blocked.contains(c.authorId)).toList()
          ?..sort(
            (a, b) => (b.id == post.helpfulCommentId ? 1 : 0).compareTo(
              a.id == post.helpfulCommentId ? 1 : 0,
            ),
          );
    final viewerId = ref.watch(
      authControllerProvider.select((auth) => auth.value?.id),
    );
    final canMarkHelpful =
        post.kind == PostKind.question &&
        post.authorId == viewerId &&
        ref.watch(capabilityProvider('community.feed.edit'));

    if (list == null) {
      if (comments.isLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // What failed, then why: two whole messages.
              Text(
                l10n.commentsLoadFailed,
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              Text(
                communityErrorText(context, comments.error),
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              TextButton(
                onPressed: () => ref.invalidate(commentsProvider(postId)),
                child: Text(context.l10n.commonTryAgain),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          l10n.noComments,
          style: AppText.body.copyWith(color: AppColors.brown),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(),
              _CommentRow(
                comment: list[i],
                now: now,
                helpful: list[i].id == post.helpfulCommentId,
                canMarkHelpful: canMarkHelpful,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CommentAction { report, block, helpful }

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.now,
    this.helpful = false,
    this.canMarkHelpful = false,
  });

  final Comment comment;
  final DateTime now;

  /// The author of the question marked this comment as its helpful answer.
  final bool helpful;

  /// The reader asked the question: they may mark (or unmark) the answer.
  final bool canMarkHelpful;

  @override
  Widget build(BuildContext context) => FeatureGate(
    capability: 'community.feed.view',
    hidden: false,
    builder: (context) =>
        Consumer(builder: (context, ref, _) => _buildAuthorized(context, ref)),
  );

  Future<void> _options(BuildContext context, WidgetRef ref) async {
    final l10n = context.communityL10n;
    final messenger = ScaffoldMessenger.of(context);
    final errorWords = communityErrorWords(context);
    final name = l10n.inLine(l10n.memberName(comment.authorName));
    final canReport = ref.read(capabilityProvider('community.feed.post'));
    final action = await showModalBottomSheet<_CommentAction>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canMarkHelpful)
              ListTile(
                leading: const AppIcon(Icons.check_circle_outline_rounded),
                title: Text(helpful ? l10n.unmarkHelpful : l10n.markHelpful),
                onTap: () => Navigator.of(context).pop(_CommentAction.helpful),
              ),
            if (canReport)
              ListTile(
                leading: const AppIcon(Icons.flag_outlined),
                title: Text(l10n.report),
                onTap: () => Navigator.of(context).pop(_CommentAction.report),
              ),
            ListTile(
              leading: const AppIcon(Icons.block_rounded),
              title: Text(l10n.blockMember(name)),
              onTap: () => Navigator.of(context).pop(_CommentAction.block),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _CommentAction.helpful) {
      try {
        await ref
            .read(feedControllerProvider.notifier)
            .setHelpful(comment.postId, helpful ? null : comment.id);
        if (!helpful) showCommunitySnack(messenger, l10n.markedHelpful);
      } catch (e) {
        showCommunitySnack(messenger, errorWords(e));
      }
      return;
    }
    if (action == _CommentAction.block) {
      await blockMemberFlow(
        context,
        ref,
        memberId: comment.authorId,
        memberName: comment.authorName,
      );
      return;
    }
    final reason = await askReportReason(
      context,
      title: l10n.commentReportTitle,
      body: l10n.commentReportBody,
    );
    if (reason == null) return;
    try {
      await ref
          .read(commentsProvider(comment.postId).notifier)
          .report(comment.id, reason);
      showCommunitySnack(messenger, l10n.commentReportThanks);
    } catch (e) {
      showCommunitySnack(messenger, errorWords(e));
    }
  }

  Widget _buildAuthorized(BuildContext context, WidgetRef ref) {
    final l10n = context.communityL10n;
    final mine =
        comment.authorId ==
        ref.watch(authControllerProvider.select((auth) => auth.value?.id));
    final when = l10n.relativeTime(
      context.l10n,
      AppFormat.of(context),
      comment.createdAt,
      now,
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: l10n.openProfile(
              l10n.inLine(l10n.memberName(comment.authorName)),
            ),
            child: GestureDetector(
              onTap: () => openMember(context, comment.authorId),
              child: AuthorAvatar(
                name: comment.authorName,
                authorId: comment.authorId,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Who and when, set apart by a dot. A name in the other
                // script is kept as one unit, so it cannot reorder the line.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: l10n.inLine(l10n.memberName(comment.authorName)),
                        style: AppText.secondary.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      TextSpan(text: ' · $when'),
                    ],
                  ),
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
                const SizedBox(height: 2),
                AutoDirectionText(
                  comment.text,
                  style: AppText.body.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
          if (!mine)
            IconButton(
              onPressed: () => _options(context, ref),
              tooltip: l10n.commentOptions,
              icon: const AppIcon(
                Icons.more_horiz_rounded,
                size: 20,
                color: AppColors.brown,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
        ],
      ),
    );
    if (!helpful) return row;
    // The helpful answer, in a soft green frame with its tag.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmallTag(
            l10n.helpfulAnswer,
            color: AppColors.sage,
            icon: Icons.check_rounded,
          ),
          row,
        ],
      ),
    );
  }
}
