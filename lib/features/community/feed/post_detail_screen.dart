import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/coral_header.dart';
import '../../../widgets/empty_state.dart';
import '../community_time.dart';
import '../data/community_models.dart';
import '../data/community_providers.dart';
import '../widgets/author_avatar.dart';
import '../widgets/message_bar.dart';
import 'feed_controller.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref.read(commentsProvider(widget.postId).notifier).add(text);
      _comment.clear();
    } catch (e) {
      showCommunitySnack(messenger, communityErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedControllerProvider);
    final post = ref.watch(postProvider(widget.postId));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoralHeader(title: 'Post', showBack: true),
          if (post == null)
            Expanded(
              child: feed.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'This post is no longer available',
                      message: 'It may have been deleted.',
                      actionLabel: 'Back to the feed',
                      onAction: () => Navigator.of(context).maybePop(),
                    ),
            )
          else ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 16),
                children: [
                  PostCard(
                    post: post,
                    onRemoved: () {
                      if (mounted) Navigator.of(context).maybePop();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text('Comments', style: AppText.label.copyWith(color: AppColors.brown, fontSize: 13)),
                  ),
                  _Comments(postId: post.id),
                ],
              ),
            ),
            MessageBar(
              controller: _comment,
              hint: 'Add a comment',
              sendTooltip: 'Send comment',
              sending: _sending,
              onSend: _send,
              inputFormatters: [LengthLimitingTextInputFormatter(CommunityLimits.commentLength)],
            ),
          ],
        ],
      ),
    );
  }
}

class _Comments extends ConsumerWidget {
  const _Comments({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comments = ref.watch(commentsProvider(postId));
    final now = ref.watch(communityClockProvider)();
    final list = comments.value;

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
              Text(
                'Cannot load the comments. ${communityErrorMessage(comments.error ?? '')}',
                style: AppText.body.copyWith(color: AppColors.brown),
              ),
              TextButton(
                onPressed: () => ref.invalidate(commentsProvider(postId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text('No comments yet. Be the first.', style: AppText.body.copyWith(color: AppColors.brown)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(),
              _CommentRow(comment: list[i], now: now),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, required this.now});

  final Comment comment;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthorAvatar(name: comment.authorName, authorId: comment.authorId, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: comment.authorName,
                        style: AppText.secondary.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      TextSpan(text: ' · ${relativeTime(comment.createdAt, now)}'),
                    ],
                  ),
                  style: AppText.label.copyWith(color: AppColors.brown),
                ),
                const SizedBox(height: 2),
                Text(comment.text, style: AppText.body.copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
